---
layout: single
title: Couch
excerpt: "Hack into a vulnerable database server that collects and stores data in JSON-based document formats, in this semi-guided challenge."
date: 2022-05-08
classes: wide
header:
  teaser: /assets/images/thm-writeup-couch/couch_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - Burp
  - Cyberchef
  - hash
  - gobuster
  - Web
---

![nmap](/assets/images/thm-writeup-couch/couch_logo.png)

[Link](https://tryhackme.com/room/couch "Couch")

This is a simple challenge in which you need to exploit a vulnerable web application and root the machine. It is beginner oriented, some basic JavaScript knowledge would be helpful, but not mandatory. Feedback is always appreciated.

---

### 1. Scan the machine. How many ports are open?

- Con el siguiente comando podemos explorar de los **65535** puertos cuales están abiertos:

```cs
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn 10.10.245.171
```

![nmap](/assets/images/thm-writeup-couch/couch_nmap_1.png)

---

### 2. What is the database management system installed on the server?

- En la imagen anterior, se puede observar el administrador de bases de datos.

---

### 3. What port is the database management system running on?

- En la imagen del punto # 1 se observa el puerto de la base de datos.

---

### 4. What is the version of the management system installed on the server?

- Con el siguiente escaneo podemos obtener la información solicitada.

```cs
─# nmap -sCV -T4 -p22,5984 10.10.245.171

```

![nmap](/assets/images/thm-writeup-couch/couch_nmap_2.png)

---

### 5.  What is the path for the web administration tool for this database management system?

- Revisando en Google me encontré con la siguiente **url**, en la que se puede dar respuesta a esta pregunta -> <https://guide.couchdb.org/draft/tour.html>

![5](/assets/images/thm-writeup-couch/couch_utils.png)


### 6. What is the path to list all databases in the web browser of the database management system?

- Revisando en Google, me encontré con la siguiente **url** la que da respuesta a la pregunta -> <https://guide.couchdb.org/draft/tour.html>

![6](/assets/images/thm-writeup-couch/couch_allbd.png)

## 7. What are the credentials found in the web administration tool?

- Revisando en el panel de administrador encontramos la ruta **secret** cuyo nombre es muy revelador:

![6](/assets/images/thm-writeup-couch/couch_secret.png)

- Entramos en la ruta del punto anterior y encontramos unas credenciales que utilizamos vía **ssh** y logramos ingreso.

![6](/assets/images/thm-writeup-couch/couch_credentials.png)

![6](/assets/images/thm-writeup-couch/couch_ssh.png)

## 8. Compromise the machine and locate user.txt

> - En la ruta que estamos ubicados encotramos la bandera de usuario.

![6](/assets/images/thm-writeup-couch/couch_user.png)

## 9. Escalate privileges and obtain root.txt

`- Después de realizar varias consultas y ejecutar linpeas, encontré que con el siguiente comando se puede realizar una montura y luego realizar lectura del archivo **root.txt**:`

```cs
atena@ubuntu:~$ docker -H 127.0.0.1:2375 run --rm -it --privileged --net=host -v /:/mnt alpine
/ # whoami
root
/ # cat /mnt/root/root.txt
```

![9](/assets/images/thm-writeup-couch/couch_root1.png)

![9](/assets/images/thm-writeup-couch/couch_root3.png)

---

Fuentes:

- Guide couchdb

https://guide.couchdb.org/draft/tour.html

- HackTricks

<https://book.hacktricks.xyz/network-services-pentesting/5984-pentesting-couchdb>

