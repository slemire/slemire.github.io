---
layout: single
title: Traverxec - Hack The Box
excerpt: "Sometimes you need a break from the hard boxes that take forever to pwn. Traverxec is an easy box that start with a custom vulnerable webserver with an unauthenticated RCE  that we exploit to land an initial shell. After pivoting to another user by finding his SSH private key and cracking it, we get root through the less pager invoked by journalctl running as root through sudo."
date: 2020-04-11
classes: wide
header:
  teaser: /assets/images/htb-writeup-traverxec/traverxec_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - nostromo  
  - journalctl
  - gtfobins
---

![](/assets/images/htb-writeup-traverxec/traverxec_logo.png)

Sometimes you need a break from the hard boxes that take forever to pwn. Traverxec is an easy box that start with a custom vulnerable webserver with an unauthenticated RCE  that we exploit to land an initial shell. After pivoting to another user by finding his SSH private key and cracking it, we get root through the less pager invoked by journalctl running as root through sudo.

## Portscan

We start with our basic portscan of the box and the attack surface seems pretty limited as we only have a webserver running and the SSH daemon. Easy boxes often have vulnerabilities that are easily exploited through off-the-self exploit on Exploit-DB. We note here that the Server header returned is `nostromo 1.9.6`, not Apache or Nginx.

![](/assets/images/htb-writeup-traverxec/nmap.png)

## Exploiting Nostromo's webserver

The website is a simple static webpage template. There's a contact form at the bottom of the page but it's not doing anything.

![](/assets/images/htb-writeup-traverxec/website1.png)

Looking at the Exploit-DB database, we see there's an exploit matching the exact version we saw earlier on the nmap scan.

![](/assets/images/htb-writeup-traverxec/searchsploit.png)

The box has the netcat version with the -e flag so we can get a reverse shell that way.

![](/assets/images/htb-writeup-traverxec/revshell.png)

## Obtaining SSH keys for user David

Looking at the nostromo configuration, we see that home directories are enabled so local users on the box probably have a `/public_www` directory in their home folder.

![](/assets/images/htb-writeup-traverxec/nostromoconfig.png)

Looking at David's home directory, we can see that we don't have access to the directory itself but if we go one level deeper to `public_www` then we see that the webserver has access to it. Since the webserver is running as the `www-data` user, it makes sense that this user would have access to the directory hosting the webpage files for users.

![](/assets/images/htb-writeup-traverxec/david.png)

That backup ssh file looks promising so we'll copy this to our machine with netcat, extract it and then we see it contains the private and public SSH keys. The private key is encrypted so we'll have to crack it.

![](/assets/images/htb-writeup-traverxec/sshkey1.png)

Using John and the rockyou wordlists, we're able to find that the password is `hunter`

![](/assets/images/htb-writeup-traverxec/cracking.png)

We can now log in to the server as user `david` with his RSA private key.

![](/assets/images/htb-writeup-traverxec/user.png)

## Privesc

There's a `server-stats.sh` file in David's `bin` folder that sudo runs the `journalctl` command to view the last 5 log entries for the nostromo service.

![](/assets/images/htb-writeup-traverxec/journalctl1.png)

Looking at [GTFOBins](https://gtfobins.github.io/), we can see that the journalctl command can be used to execute arbitrary commands since it uses the `less` pager.

![](/assets/images/htb-writeup-traverxec/gtfo.png)

To exploit this, we must make the pager pause before listing the 5 entries in the log file, so we can type `!/bin/sh` and get a root shell. There's a couple of way to do this.

By resizing with Gnome Terminator windows manually, I can force the stty rows to be updated.

![](/assets/images/htb-writeup-traverxec/root1.png)

Or we can also resize the width of the terminal, this'll make less pause as well

![](/assets/images/htb-writeup-traverxec/root2.png)

Finally, we can also set the stty rows manually like this:

![](/assets/images/htb-writeup-traverxec/root3.png)