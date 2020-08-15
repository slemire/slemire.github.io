---
layout: single
title: Traceback - Hack The Box
excerpt: "Traceback was an easy box where you had to look for an existing webshell on the box, then use it to get the initial foothold. Then there was some typical sudo stuff with a LUA interpreter giving us access as another user then for privesc we find that we can write to  `/etc/update-motd.d` and those scripts get executed by root."
date: 2020-08-15
classes: wide
header:
  teaser: /assets/images/htb-writeup-traceback/traceback_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - webshell
  - lua
  - update-motd.d
---

![](/assets/images/htb-writeup-traceback/traceback_logo.png)

Traceback was an easy box where you had to look for an existing webshell on the box, then use it to get the initial foothold. Then there was some typical sudo stuff with a LUA interpreter giving us access as another user then for privesc we find that we can write to  `/etc/update-motd.d` and those scripts get executed by root.

## Summary

- Find a hint in the HTML comments of the mainpage about popular webshells
- Find hidden webshell by trying out popular webshells found by googling the HTML comments hint
- Get a reverse shell as user webadmin, and use LUA interpreter to get a shell as sysadmin
- Watching running process with pspy, find motd update process running as root
- Edit and log in by SSH again to trigger the script

## Portscan

```
root@kali:~/htb/traceback# nmap -T4 -sC -sV -p- 10.10.10.181
Starting Nmap 7.80 ( https://nmap.org ) at 2020-03-15 15:48 EDT
Nmap scan report for traceback.htb (10.10.10.181)
Host is up (0.018s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 96:25:51:8e:6c:83:07:48:ce:11:4b:1f:e5:6d:8a:28 (RSA)
|   256 54:bd:46:71:14:bd:b2:42:a1:b6:b0:2d:94:14:3b:0d (ECDSA)
|_  256 4d:c3:f8:52:b8:85:ec:9c:3e:4d:57:2c:4a:82:fd:86 (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Help us
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Finding the webshell

As we can see, the website has been defaced by some elite hacker named Xh4H.

![](/assets/images/htb-writeup-traceback/web1.png)

The HTML source code reveals a hint:

```html
<body>
	<center>
		<h1>This site has been owned</h1>
		<h2>I have left a backdoor for all the net. FREE INTERNETZZZ</h2>
		<h3> - Xh4H - </h3>
		<!--Some of the best web shells that you might need ;)-->
	</center>
</body>
```

Googling `Some of the best web shells that you might need`, I end up on [https://github.com/TheBinitGhimire/Web-Shells](https://github.com/TheBinitGhimire/Web-Shells).

I tried each webshell filename on the box and got a hit on `http://10.10.10.181/smevk.php`

![](/assets/images/htb-writeup-traceback/web2.png)

The creds are `admin / admin`.

![](/assets/images/htb-writeup-traceback/web3.png)

To get a shell, I simply use a common payload with the Execute function on the webshell:

![](/assets/images/htb-writeup-traceback/web4.png)

![](/assets/images/htb-writeup-traceback/shell1.png)

## Privesc from webadmin to sysadmin

First, I'll add my SSH key to the webadmin's authorized_keys file so I can log in with a proper SSH shell.

![](/assets/images/htb-writeup-traceback/shell2.png)

Looking at my home directory, I see a program called luvit owned by `sysadmin` and a `privesc.lua` file that writes an SSH key to the `sysadmin` folder

![](/assets/images/htb-writeup-traceback/shell3.png)

The note.txt file says:

```
webadmin@traceback:~$ cat note.txt 
- sysadmin -
I have left this tool to practice Lua. Contact me if you have any question.
```

So it's pretty clear we need to use the LUA interpreter to escalate to `sysadmin`.

We can run the interpreter as `sysadmin`:

```
webadmin@traceback:~$ sudo -l
Matching Defaults entries for webadmin on traceback:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User webadmin may run the following commands on traceback:
    (sysadmin) NOPASSWD: /home/webadmin/luvit
```

We just need to call `/bin/bash` to get a shell as `sysadmin`...

![](/assets/images/htb-writeup-traceback/shell4.png)

## Privesc from sysadmin to root

Again, let's dump our SSH key so we can get a real shell.

![](/assets/images/htb-writeup-traceback/shell5.png)

We can now read the flag:

```
$ cat user.txt
c2434970[...]
```

Using pspy, I can see that the `/bin/sh /etc/update-motd.d/80-esm` script gets executed by root every time someone logs in.

![](/assets/images/htb-writeup-traceback/root1.png)

There's a script that runs every 30 seconds to restore the original copies of files in `/etc/update-motd.d/` so it's obvious that this is the way in for this box.

![](/assets/images/htb-writeup-traceback/root2.png)

All the files are writable by `sysadmin` so it's game over at this point.

![](/assets/images/htb-writeup-traceback/root3.png)

We just need to change the `80-esm` file to something like this and it'll make bash suid so we can get root:

![](/assets/images/htb-writeup-traceback/root4.png)