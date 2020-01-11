---
layout: single
title: Bitlab - Hack The Box
excerpt: "I solved this gitlab box the unintended way by exploiting the `git pull` command running as root and using git post-merge hooks to execute code as root. I was able to get a root shell using this method but I still had to get an initial shell by finding the gitlab credentials in some obfuscated javascript and modifying PHP code in the repo to get RCE."
date: 2020-01-11
classes: wide
header:
  teaser: /assets/images/htb-writeup-bitlab/bitlab_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - git
  - gitlab
  - javascript
  - obfuscated
  - unintended
---

![](/assets/images/htb-writeup-bitlab/bitlab_logo.png)

I solved this gitlab box the unintended way by exploiting the `git pull` command running as root and using git post-merge hooks to execute code as root. I was able to get a root shell using this method but I still had to get an initial shell by finding the gitlab credentials in some obfuscated javascript and modifying PHP code in the repo to get RCE.

## Summary

- Find javascript obfuscated credentials in bookmarks.html
- Use creds to gain access to the profile repo and modify it to get PHP RCE
- Get root access using the unintended method of git post-merge hooks

## Portscan

The portscan shows SSH and HTTP ports open along with entries from `robots.txt` indicating this is a Gitlab service. I'll check out a couple of the URIs mentioned below in the next section.

```
root@kali:~/htb/bitlab# nmap -sC -sV -T4 10.10.10.114
Starting Nmap 7.80 ( https://nmap.org ) at 2019-09-08 09:49 EDT
Nmap scan report for bitlab.htb (10.10.10.114)
Host is up (0.022s latency).
Not shown: 998 filtered ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 a2:3b:b0:dd:28:91:bf:e8:f9:30:82:31:23:2f:92:18 (RSA)
|   256 e6:3b:fb:b3:7f:9a:35:a8:bd:d0:27:7b:25:d4:ed:dc (ECDSA)
|_  256 c9:54:3d:91:01:78:03:ab:16:14:6b:cc:f0:b7:3a:55 (ED25519)
80/tcp open  http    nginx
| http-robots.txt: 55 disallowed entries (15 shown)
| / /autocomplete/users /search /api /admin /profile
| /dashboard /projects/new /groups/new /groups/*/edit /users /help
|_/s/ /snippets/new /snippets/*/edit
| http-title: Sign in \xC2\xB7 GitLab
|_Requested resource was http://bitlab.htb/users/sign_in
|_http-trane-info: Problem with XML parsing of /evox/about
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.33 seconds
```

## Gitlab enumeration

I already knew that the box was going to contain a Gitlab service based on the box name and the logo. The box was originally submitted as Gitlab but was renamed to Bitlab before launch.

![](/assets/images/htb-writeup-bitlab/Screenshot_1.png)

I clicked the Explore link at the bottom of the page to look for repos but I didn't see any repositories that are publicly accessible.

![](/assets/images/htb-writeup-bitlab/Screenshot_2.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_3.png)

I checked a few links from the `robots.txt` file and found a profile page for Clave:

![](/assets/images/htb-writeup-bitlab/Screenshot_11.png)

That's not a default page in Gitlab so I'll keep that in mind for later.

## Hardcoded Gitlab credentials

I initially skipped the Help section but when I went back and clicked on the link, I got the following page:

![](/assets/images/htb-writeup-bitlab/Screenshot_4.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_5.png)

The `Gitlab Login` link doesn't link to an HTTP URL but contains obfuscated javascript:

```javascript
javascript:(function(){ var _0x4b18=["\x76\x61\x6C\x75\x65","\x75\x73\x65\x72\x5F\x6C\x6F\x67\x69\x6E","\x67\x65\x74\x45\x6C\x65\x6D\x65\x6E\x74\x42\x79\x49\x64","\x63\x6C\x61\x76\x65","\x75\x73\x65\x72\x5F\x70\x61\x73\x73\x77\x6F\x72\x64","\x31\x31\x64\x65\x73\x30\x30\x38\x31\x78"];document[_0x4b18[2]](_0x4b18[1])[_0x4b18[0]]= _0x4b18[3];document[_0x4b18[2]](_0x4b18[4])[_0x4b18[0]]= _0x4b18[5]; })()
```

I executed the Javascript in NodeJS and found credentials for Clave:

![](/assets/images/htb-writeup-bitlab/Screenshot_8.png)

Credentials: `clave` / `11des0081x`

Also, if you copy/paste the entire Javascript code snippet in the Firefox dev console when you're on the Gitlab login page it'll auto populate both username and password field.

I can now log in to the Gitlab portal and I see two repositories that I have access to:

![](/assets/images/htb-writeup-bitlab/Screenshot_10.png)

I have read/write access to the `Profile` repo but only read access to `Deployer`.

As per Gitlab's documentation, these are the permissions available:
> Guest - No access to code
> Reporter - Read the repository
> Developer - Read/Write to the repository
> Maintainer - Read/Write to the repository + partial administrative capabilities
> Owner - Read/Write to the repository + full administrative capabilities

## Getting RCE through the Profile page

The Profile repository contains the webpage for the Profile page I found earlier. I see that it's running PHP so if I can modify this page I should be able to gain remote code execution by adding a reverse shell on the page.

![](/assets/images/htb-writeup-bitlab/Screenshot_12.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_13.png)

The Deployer repo code is a simple PHP script that expects a specific JSON message then does a `git pull`. I assume this'll be used to deploy the Profile page when I commit changes to the repo.

![](/assets/images/htb-writeup-bitlab/Screenshot_14.png)

The repo is deployed in the root of the directory and I can access it with `/deployer`:

![](/assets/images/htb-writeup-bitlab/Screenshot_15.png)

I'll add a PHP reverse shell in the Profile `index.php` page that triggers when I have a `shell` parameter present. Then I submit the merge request and merge it after.

![](/assets/images/htb-writeup-bitlab/Screenshot_16.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_17.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_18.png)

I'll craft the proper POST request with the Repeater function in Burp Suite. The JSON message has to match the exact format from the code I found in the repo.

![](/assets/images/htb-writeup-bitlab/Screenshot_19.png)

Now that the profile page has been updated, I can trigger the reverse shell by sending a request with the `shell` parameter:

![](/assets/images/htb-writeup-bitlab/Screenshot_20.png)

## Unintended privilege escalation to root

The `www-data` user can execute `git pull` as root:

```
$ sudo -l
Matching Defaults entries for www-data on bitlab:
    env_reset, exempt_group=sudo, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User www-data may run the following commands on bitlab:
    (root) NOPASSWD: /usr/bin/git pull
$
```

Git has hooks that can be used to execute code after commit, push, merge, etc. I'll use that to get remote execution as root through the `git pull` command. The [https://www.git-scm.com/docs/githooks#_post_merge](https://www.git-scm.com/docs/githooks#_post_merge) documentation says:

> This hook is invoked by git-merge[1], which happens when a git pull is done on a local repository.

First, I'll create two local repos: `foo` will be merged into the `bar` repo. I'll add a reverse shell in the `post-merge` hook of the `bar` repo where `bar` will be merged into.

![](/assets/images/htb-writeup-bitlab/Screenshot_21.png)

Then I'll do an initial commit in the `foo` repo and set up `bar` to pull from the `foo` repo:

![](/assets/images/htb-writeup-bitlab/Screenshot_22.png)

And finally I'll do a new commit in `foo` so I can initiate a merge from `foo` and trigger the reverse shell:

![](/assets/images/htb-writeup-bitlab/Screenshot_23.png)

![](/assets/images/htb-writeup-bitlab/Screenshot_24.png)