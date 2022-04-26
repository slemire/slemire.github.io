---
layout: single
title: Anonforce
excerpt: "boot2root machine for FIT and bsides guatemala CTF"
date: 2022-04-25
classes: wide
header:
  teaser: /assets/images/thm-writeup-anonforce/anonforce_logo.jpeg
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Nodejs
  - Deserialization
  - web
---

![logo](/assets/images/thm-writeup-anonforce/anonforce_logo.jpeg)

 [Link](https://tryhackme.com/room/bsidesgtanonforce "jason")

boot2root machine for FIT and bsides guatemala CTF. Read user.txt and root.txt


## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-anonforce/anonforce_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

- Whatweb nos da la siguiente información que nos indica que no hay una página http:

~~~css
whatweb {ip}
~~~

![whatweb](/assets/images/thm-writeup-anonforce/anonforce_whatweb.png)

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puerto de red con el siguiente comando:
  
~~~css
nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
~~~

![nmap](/assets/images/thm-writeup-anonforce/anonforce_nmap.png)

- Escaneo de vulnerabilidades:

~~~css
nmap -v -A -sC -sV -Pn 10.10.24.236 -p- --script vuln -oN Vuln
~~~

~~~CSS

                                                                     
~~~

## 2.1 FTP

- Conexión al protocolo FTP con el usuario anonymous:
  
---

~~~CSS
└─$ ftp anonymous@10.10.24.236
Connected to 10.10.24.236.
220 (vsFTPd 3.0.3)
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||30541|)
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 Aug 11  2019 bin
drwxr-xr-x    3 0        0            4096 Aug 11  2019 boot
drwxr-xr-x   17 0        0            3700 Apr 25 16:34 dev
drwxr-xr-x   85 0        0            4096 Aug 13  2019 etc
drwxr-xr-x    3 0        0            4096 Aug 11  2019 home
lrwxrwxrwx    1 0        0              33 Aug 11  2019 initrd.img -> boot/initrd.img-4.4.0-157-generic
lrwxrwxrwx    1 0        0              33 Aug 11  2019 initrd.img.old -> boot/initrd.img-4.4.0-142-generic
drwxr-xr-x   19 0        0            4096 Aug 11  2019 lib
drwxr-xr-x    2 0        0            4096 Aug 11  2019 lib64
drwx------    2 0        0           16384 Aug 11  2019 lost+found
drwxr-xr-x    4 0        0            4096 Aug 11  2019 media
drwxr-xr-x    2 0        0            4096 Feb 26  2019 mnt
drwxrwxrwx    2 1000     1000         4096 Aug 11  2019 notread
drwxr-xr-x    2 0        0            4096 Aug 11  2019 opt
dr-xr-xr-x   92 0        0               0 Apr 25 16:34 proc
drwx------    3 0        0            4096 Aug 11  2019 root
drwxr-xr-x   18 0        0             540 Apr 25 16:34 run
drwxr-xr-x    2 0        0           12288 Aug 11  2019 sbin
drwxr-xr-x    3 0        0            4096 Aug 11  2019 srv
dr-xr-xr-x   13 0        0               0 Apr 25 16:34 sys
drwxrwxrwt    9 0        0            4096 Apr 25 16:34 tmp
drwxr-xr-x   10 0        0            4096 Aug 11  2019 usr
drwxr-xr-x   11 0        0            4096 Aug 11  2019 var
lrwxrwxrwx    1 0        0              30 Aug 11  2019 vmlinuz -> boot/vmlinuz-4.4.0-157-generic
lrwxrwxrwx    1 0        0              30 Aug 11  2019 vmlinuz.old -> boot/vmlinuz-4.4.0-142-generic
226 Directory send OK.
~~~

## 3 Bandera de usuario

- Accedemos a la carpeta **home** y dentro de esta a la carpeta **melodias**, dentro de esta última encotramos el archivo **user.txt**, el cual procedemos a descargar con el comando **get** como se observa a continuación:

~~~CSS
ftp> cd home
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||43856|)
150 Here comes the directory listing.
drwxr-xr-x    4 1000     1000         4096 Aug 11  2019 melodias
226 Directory send OK.
ftp> cd melodias
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||7973|)
150 Here comes the directory listing.
-rw-rw-r--    1 1000     1000           33 Aug 11  2019 user.txt
226 Directory send OK.
ftp> get user.txt
local: user.txt remote: user.txt
229 Entering Extended Passive Mode (|||42302|)
150 Opening BINARY mode data connection for user.txt (33 bytes).
100% |******************************************************|    33      575.47 KiB/s    00:00 ETA
226 Transfer complete.
33 bytes received in 00:00 (0.18 KiB/s) 
~~~

- Revisando encontramos una carpeta con el siguiente nombre muy llamativo: **notread**, procedemos a descargar su contenido como se oberva a continuación:
  
~~~CSS
ftp> cd notread
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode (|||13508|)
150 Here comes the directory listing.
-rwxrwxrwx    1 1000     1000          524 Aug 11  2019 backup.pgp
-rwxrwxrwx    1 1000     1000         3762 Aug 11  2019 private.asc
226 Directory send OK.
ftp> get backup.pgp
local: backup.pgp remote: backup.pgp
229 Entering Extended Passive Mode (|||64112|)
150 Opening BINARY mode data connection for backup.pgp (524 bytes).
100% |******************************************************|   524        9.79 MiB/s    00:00 ETA
226 Transfer complete.
524 bytes received in 00:00 (3.06 KiB/s)
ftp> get private.asc
local: private.asc remote: private.asc
229 Entering Extended Passive Mode (|||30631|)
150 Opening BINARY mode data connection for private.asc (3762 bytes).
100% |******************************************************|  3762       59.79 MiB/s    00:00 ETA
226 Transfer complete.
3762 bytes received in 00:00 (21.99 KiB/s)
~~~

- Análizando los archivos descargados, en el **user.txt** encontramos la bandera de usuario:
  
![user_flag](/assets/images/thm-writeup-anonforce/anonforce_user.png)

## 3 Bandera root

- Analizando el archivo **private.asc** nos encotramos una llave privada:

![key](/assets/images/thm-writeup-anonforce/anonforce_key.png)

<https://hashcat.net/wiki/doku.php?id=example_hashes>

![hash_id](/assets/images/thm-writeup-anonforce/anonforce_hash_id.png)




