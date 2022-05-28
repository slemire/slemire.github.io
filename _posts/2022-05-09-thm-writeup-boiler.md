---
layout: single
title: Couch
excerpt: "Hack into a vulnerable database server that collects and stores data in JSON-based document formats, in this semi-guided challenge."
date: 2022-05-08
classes: wide
header:
  teaser: /assets/images/thm-writeup-couch/couch_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - nmap
  - couchdb
  - Web
  - Privilege escalation
---


```cs
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn boil.local   
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-05-09 19:44 -05
Initiating SYN Stealth Scan at 19:44
Scanning boil.local (10.10.101.226) [65535 ports]
Discovered open port 80/tcp on 10.10.101.226
Discovered open port 21/tcp on 10.10.101.226
Discovered open port 10000/tcp on 10.10.101.226
Discovered open port 55007/tcp on 10.10.101.226
Completed SYN Stealth Scan at 19:44, 13.89s elapsed (65535 total ports)
Nmap scan report for boil.local (10.10.101.226)
Host is up, received user-set (0.16s latency).
Scanned at 2022-05-09 19:44:25 -05 for 14s
Not shown: 65531 closed tcp ports (reset)
PORT      STATE SERVICE          REASON
21/tcp    open  ftp              syn-ack ttl 63
80/tcp    open  http             syn-ack ttl 63
10000/tcp open  snet-sensor-mgmt syn-ack ttl 63
55007/tcp open  unknown          syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 13.97 seconds
           Raw packets sent: 67932 (2.989MB) | Rcvd: 67770 (2.711MB)

```


```cs
└─# nmap -sCV -T4 -p21,80,10000,5507 boil.local                            
Starting Nmap 7.92 ( https://nmap.org ) at 2022-05-09 19:45 -05
Nmap scan report for boil.local (10.10.101.226)
Host is up (0.16s latency).

PORT      STATE  SERVICE        VERSION
21/tcp    open   ftp            vsftpd 3.0.3
|_ftp-anon: Anonymous FTP login allowed (FTP code 230)
| ftp-syst: 
|   STAT: 
| FTP server status:
|      Connected to ::ffff:10.9.0.68
|      Logged in as ftp
|      TYPE: ASCII
|      No session bandwidth limit
|      Session timeout in seconds is 300
|      Control connection is plain text
|      Data connections will be plain text
|      At session startup, client count was 3
|      vsFTPd 3.0.3 - secure, fast, stable
|_End of status
80/tcp    open   http           Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Apache2 Ubuntu Default Page: It works
| http-robots.txt: 1 disallowed entry 
|_/
|_http-server-header: Apache/2.4.18 (Ubuntu)
5507/tcp  closed psl-management
10000/tcp open   http           MiniServ 1.930 (Webmin httpd)
|_http-title: Site doesn't have a title (text/html; Charset=iso-8859-1).
Service Info: OS: Unix
```

### 1. File extension after anon login

![ftp](/assets/images/thm-writeup-boil/boil.ftp_1.png)




```css
Testing Joomla CMS
==========

The current folder contains the Tests for Quality Assurance of the Joomla Content Management System.

* unit: contains the Joomla-cms unit tests based on PHPUnit
* javascript: contains the Joomla! javascript tests based on Jasmine and Karma

Find more details inside each folder.
~

```



![burp](/assets/images/thm-writeup-boil/boil.burp_0.png)

![burp](/assets/images/thm-writeup-boil/boil.cat_log.png)



![burp](/assets/images/thm-writeup-boil/boil.burp_1.png)


![burp](/assets/images/thm-writeup-boil/boil.burp_2.png)

