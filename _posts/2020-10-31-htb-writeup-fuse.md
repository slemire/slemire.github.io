---
layout: single
title: Fuse - Hack The Box
excerpt: "To solve Fuse, we'll do some enumeration to gather potential usernames from the print jobs information then build a password list from the strings on the website. After successfully password spraying, we'll reset the expired password to a new one then use rpcclient to identify a printer service account and find its password in a description field. To priv esc, we'll use the ability of our user with Printer Operators right to load a malicous kernel driver and get SYSTEM."
date: 2020-10-31
classes: wide
header:
  teaser: /assets/images/htb-writeup-fuse/fuse_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - password spray
  - crackmapexec
  - smbpasswd
  - print operators
  - capcom
---

![](/assets/images/htb-writeup-fuse/fuse_logo.png)

To solve Fuse, we'll do some enumeration to gather potential usernames from the print jobs information then build a password list from the strings on the website. After successfully password spraying, we'll reset the expired password to a new one then use rpcclient to identify a printer service account and find its password in a description field. To priv esc, we'll use the ability of our user with Printer Operators right to load a malicous kernel driver and get SYSTEM.

## Summary

- Find usernames from the print logger website & build a small wordlist
- Password spray and find an expired password for three users
- Reset password for the user with smbpasswd then use rpcclient to find credentials for the svc-print account in a printer description
- Get a shell and identify that svc-print is a members of Print Operators and can load kernel drivers
- Use the Capcom.sys driver to gain code execution as SYSTEM

## Portscan

```
snowscan@kali:~$ sudo nmap -sC -sV -p- 10.10.10.193
Starting Nmap 7.80 ( https://nmap.org ) at 2020-06-13 20:50 EDT
Stats: 0:00:15 elapsed; 0 hosts completed (1 up), 1 undergoing SYN Stealth Scan
SYN Stealth Scan Timing: About 8.37% done; ETC: 20:53 (0:02:44 remaining)
Nmap scan report for fuse.htb (10.10.10.193)
Host is up (0.018s latency).
Not shown: 65514 filtered ports
PORT      STATE SERVICE      VERSION
53/tcp    open  domain?
| fingerprint-strings: 
|   DNSVersionBindReqTCP: 
|     version
|_    bind
80/tcp    open  http         Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: Site doesn't have a title (text/html).
88/tcp    open  kerberos-sec Microsoft Windows Kerberos (server time: 2020-06-14 01:07:26Z)
135/tcp   open  msrpc        Microsoft Windows RPC
139/tcp   open  netbios-ssn  Microsoft Windows netbios-ssn
389/tcp   open  ldap         Microsoft Windows Active Directory LDAP (Domain: fabricorp.local, Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds Windows Server 2016 Standard 14393 microsoft-ds (workgroup: FABRICORP)
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http   Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
3268/tcp  open  ldap         Microsoft Windows Active Directory LDAP (Domain: fabricorp.local, Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
5985/tcp  open  http         Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open  mc-nmf       .NET Message Framing
49666/tcp open  msrpc        Microsoft Windows RPC
49667/tcp open  msrpc        Microsoft Windows RPC
49669/tcp open  ncacn_http   Microsoft Windows RPC over HTTP 1.0
49670/tcp open  msrpc        Microsoft Windows RPC
49672/tcp open  msrpc        Microsoft Windows RPC
49690/tcp open  msrpc        Microsoft Windows RPC
49745/tcp open  msrpc        Microsoft Windows RPC
```

## Website recon

The PaperCut Print Logger application is running on the server. There's not much exposed by the application except some print jobs that contain the hostname, some usernames and the file names.

![](/assets/images/htb-writeup-fuse/image-20200613205151216.png)

![](/assets/images/htb-writeup-fuse/image-20201030163223157.png)

## Password spray

Based on the printer job information, we can assume that the following usernames are present on the domain/machine:

- pmerton
- tlavel
- sthompson
- bhult
- bnielson (From New Starter - bnielson.txt)

For passwords, we'll build a wordlist with the words found on from the papercut website. Here's the small wordlist I built:

```
backup_tapes
bnielson
Budget
Fabricorp01
IT
Meeting
mega_mountain_tape_request
Minutes
New
Notepad
offsite_dr_invocation
printing_issue_test
Starter
```

Using **crackmapexec** we'll password spray those passwords and we find 3 accounts with the `Fabricorp01` password but it's expired as we can see from the server response: `STATUS_PASSWORD_MUST_CHANGE`.

![](/assets/images/htb-writeup-fuse/image-20200613211345368.png)

##  Finding the printer service account credentials

Using **smbpasswd** we can reset the user's password, and then after poking around for a while with **rpcclient** we find that the printer has a description with the password.

![](/assets/images/htb-writeup-fuse/image-20200613211912843.png)

We can get the list of users with **rpcclient** and we see that there is an **svc-print** account so this is probably the account that uses the password we found earlier.

![](/assets/images/htb-writeup-fuse/image-20200613212151259.png)

Yup, this is our user. We can get a shell now with WinRM.

![](/assets/images/htb-writeup-fuse/image-20200613212328325.png)

## Privesc

The **svc-print** user is a member of **Print Operators**. This is very dangerous since members of this group can load Kernel Drivers and get code execution with SYSTEM privileges.

![](/assets/images/htb-writeup-fuse/image-20200613213352780.png)

![](/assets/images/htb-writeup-fuse/image-20200613213519478.png)

There's a nice blog post from Tarlogic that explains how to perform privilege escalation by loading drivers: [https://www.tarlogic.com/en/blog/abusing-seloaddriverprivilege-for-privilege-escalation/](https://www.tarlogic.com/en/blog/abusing-seloaddriverprivilege-for-privilege-escalation/)

We need the following in order to privesc:
- A way to load the kernel driver from our shell. We can use the following PoC: [https://github.com/TarlogicSecurity/EoPLoadDriver/](https://github.com/TarlogicSecurity/EoPLoadDriver/)
- The Capcom signed driver that contains the rootkit: [https://github.com/FuzzySecurity/Capcom-Rootkit/blob/master/Driver/Capcom.sys](https://github.com/FuzzySecurity/Capcom-Rootkit/blob/master/Driver/Capcom.sys)
- The Capcom rootkit PoC that will let us execute code with the driver: [https://github.com/tandasat/ExploitCapcom](https://github.com/tandasat/ExploitCapcom)

The kernel driver loader doesn't need any need modification and can be compiled as-is.

I modified the capcom exploit to run [xc](https://github.com/xct/xc):

![](/assets/images/htb-writeup-fuse/image-20200613220144218.png)

![](/assets/images/htb-writeup-fuse/image-20200613220610515.png)

We'll first load the Capcom driver:

![](/assets/images/htb-writeup-fuse/image-20200613220725179.png)

Then run the Capcom exploit, which will trigger code execution in the driver:

![](/assets/images/htb-writeup-fuse/image-20200613220831186.png)

Our xc reverse shell gets executed and we can finally get the last flag:

![](/assets/images/htb-writeup-fuse/image-20200613220855458.png)