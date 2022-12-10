---
layout: single
title: LazyAdmin - Try Hack Me
excerpt: "Máquina Linux de nivel fácil para practicar tus habilidades."
date: 2022-12-10
classes: wide
header:
  teaser: /assets/images/thm-writeup-lazyadmin/lazyadmin.png
  teaser_home_page: true
  icon: /assets/images/THMlogo.png
categories:
  - tryhackme
  - pentesting
  - ctf
tags:  
  - writeup
  - linux
  - easy
  - sweet rice
  - privilege escalation
---

![](/assets/images/thm-writeup-lazyadmin/lazyadmin.png)

Delivery is a quick and fun easy box where we have to create a MatterMost account and validate it by using automatic email accounts created by the OsTicket application. The admins on this platform have very poor security practices and put plaintext credentials in MatterMost. Once we get the initial shell with the creds from MatterMost we'll poke around MySQL and get a root password bcrypt hash. Using a hint left in the MatterMost channel about the password being a variation of PleaseSubscribe!, we'll use hashcat combined with rules to crack the password then get the root shell.

## Enumeración

Primeramente realicé  un escaneo con Nmap para buscar puertos abiertos.

```
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn lazyadmin.thm

# Nmap 7.92 scan initiated Sun Dec  4 13:48:34 2022 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG allports lazyadmin.thm
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.10.195.235 ()  Status: Up
Host: 10.10.195.235 ()  Ports: 22/open/tcp//ssh///, 80/open/tcp//http///    Ignored State: closed (65533)
# Nmap done at Sun Dec  4 13:48:48 2022 -- 1 IP address (1 host up) scanned in 14.08 seconds

```
El escaneo revela 2 puertos abiertos (puerto 80) y (puerto 22), realizo un escaneo nuevamente pero en este caso lo hago para obtener la versión de servicios de ambos puertos.

```

sudo nmap -sS -sV -p22,80 lazyadmin.thm

# Nmap 7.92 scan initiated Sun Dec  4 13:54:57 2022 as: nmap -sC -sV -p22,80 -oN targeted lazyadmin.thm
Nmap scan report for lazyadmin.thm (10.10.195.235)
Host is up (0.24s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.8 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 49:7c:f7:41:10:43:73:da:2c:e6:38:95:86:f8:e0:f0 (RSA)
|   256 2f:d7:c4:4c:e8:1b:5a:90:44:df:c0:63:8c:72:ae:55 (ECDSA)
|_  256 61:84:62:27:c6:c3:29:17:dd:27:45:9e:29:cb:90:5e (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Apache2 Ubuntu Default Page: It works
|_http-server-header: Apache/2.4.18 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sun Dec  4 13:55:12 2022 -- 1 IP address (1 host up) scanned in 15.40 seconds

```
El puerto 80 está ejecutando Apache, después de verofocar la página web en el puerto 80, obtuve la página web predeterminada de Apache.

Así que ejecuté Gobuster para obtener directorios.

```
gobuster dir -u http://lazyadmin.thm/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt   

===============================================================
Gobuster v3.1.0
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://lazyadmin.thm/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.1.0
[+] Timeout:                 10s
===============================================================
2022/12/04 15:21:47 Starting gobuster in directory enumeration mode
===============================================================
/content              (Status: 301) [Size: 316] [--> http://lazyadmin.thm/content/]
/server-status        (Status: 403) [Size: 278]                                    
                                                                                   
===============================================================
2022/12/04 16:47:58 Finished
===============================================================
```

Obtuve un directorio llamado "/content", por lo que verifico el directorio al navegar por él.

## Sitio Web

Al ingresar hay una página web de CMS SweetRice, es un sistema de administración de contenido para administrar sitios web. Así que ejecutamos Gobuster contra el directorio "/content".

![](/assets/images/thm-writeup-lazyadmin/cms.png)

```
gobuster dir -u http://lazyadmin.thm/content/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
===============================================================
Gobuster v3.1.0
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://lazyadmin.thm/content/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.1.0
[+] Timeout:                 10s
===============================================================
2022/12/05 23:23:03 Starting gobuster in directory enumeration mode
===============================================================
/images               (Status: 301) [Size: 323] [--> http://lazyadmin.thm/content/images/]
/js                   (Status: 301) [Size: 319] [--> http://lazyadmin.thm/content/js/]    
/inc                  (Status: 301) [Size: 320] [--> http://lazyadmin.thm/content/inc/]   
/as                   (Status: 301) [Size: 319] [--> http://lazyadmin.thm/content/as/]    
/_themes              (Status: 301) [Size: 324] [--> http://lazyadmin.thm/content/_themes/]
/attachment           (Status: 301) [Size: 327] [--> http://lazyadmin.thm/content/attachment/]

===============================================================
2022/12/04 16:47:58 Finished
===============================================================
```

Hay más directorios, el directorio "/as" contiene una página de inicio de sesión, pero no puedo acceder, ya que no tengo credenciales para iniciar sesión, así que reviso otros directorios, revisando el directorio "/inc".

![](/assets/images/thm-writeup-lazyadmin/inc.png)

## Credenciales de MySQL database

Veo que hay una carpeta "mysql_backup/", así que verifico esa carpeta.

![](/assets/images/thm-writeup-lazyadmin/mysqlbackup.png)

Veo que hay un archivo, procedo a descargar el archivo que podría contener información útil, por lo que verifico la base de datos de respaldo de MySQL.

![](/assets/images/thm-writeup-lazyadmin/backup.png)

## Cracking

En el archivo descargado, obtuve el nombre de usuario y la contraseña al buscar, pero la contraseña estaba en el hash, por lo que uso Hash-identifier para saber qué tipo de Hash es este.

![](/assets/images/thm-writeup-lazyadmin/hash.png)

Entonces, ahora que sé que se trata de un hash MD5, también puedo descifrar este hash usando crackstation, pero usamos la herramienta John the ripper, es una de las herramientas de descifrado de contraseñas más populares.

![](/assets/images/thm-writeup-lazyadmin/pass.png)

Ahora tengo un nombre de usuario y contraseña para que pueda intentar iniciar sesión en el directorio que encontré en "/as".

![](/assets/images/thm-writeup-lazyadmin/login.png)

Después de proporcionar las credenciales, puedo iniciar sesión en Dashboard of SweetRice.

![](/assets/images/thm-writeup-lazyadmin/ads.png)

## Reverse-Shell

En la sección Anuncios, puedo agregar un script para obtener una conexión inversa (reverse shell). He descargado un archivo de reverse-shell Php de https://pentestmonkey.net/tools/web-shells/php-reverse-shell, recuerden cambiar la dirección IP y el puerto en la script.

![](/assets/images/thm-writeup-lazyadmin/reverseads.png)

Hago clic en done, el script se cargó. Así que comienzo a escuchar peticiones mediante Netcat.

![](/assets/images/thm-writeup-lazyadmin/netcat.png)

Ahora tenemos que hacer clic en el script que subí para obtener una conexión.

![](/assets/images/thm-writeup-lazyadmin/incads.png)

![](/assets/images/thm-writeup-lazyadmin/incadsshell.png)

Después de hacer clic en shell.php, obtuve una reverse shell.

![](/assets/images/thm-writeup-lazyadmin/reverseshell.png)

Ahora puedo leer la flag de user con el comando "cat user.txt" que se encuentra en la ruta: "/home/itguy"

![](/assets/images/thm-writeup-lazyadmin/user.png)

También puedo actualizar esta shell con el siguiente comando:

python3 -c 'import pty;pty.spawn("/bin/bash")'

![](/assets/images/thm-writeup-lazyadmin/bash.png)

## Escalar Privilegios

Procedo a verificar que permiso tengo con el comando "sudo -l".

![](/assets/images/thm-writeup-lazyadmin/privilegios.png)

Veo que hay un archivo que puedo ejecutar con Perl con privilegios de root, así que verifico el archivo usando el comando "cat /home/itguy/backup.pl", veo que no tengo permisos para escribir, leo el archivo.

![](/assets/images/thm-writeup-lazyadmin/perl.png)

Este script ejecuta otro script en bash que se encuentra en "/etc/copy.sh", entonces reviso este otro archivo.

![](/assets/images/thm-writeup-lazyadmin/copy.png)

Ahora verifico los permisos, veo que puedo escribir en este archivo y ejecutar. Ya hay un script de reverse-shell presente, así que solo tengo que cambiar la dirección IP y el puerto. Me dará una conexión inversa. Intento editar el archivo usando los editores nano y vim pero no funcionó, así que utilizo el comando "echo".

![](/assets/images/thm-writeup-lazyadmin/ncrs.png)

Ahora inicio una escucha de peticiones de Netcat para obtener una reverse shell y ejecuto el archivo.

![](/assets/images/thm-writeup-lazyadmin/nc9999.png)

![](/assets/images/thm-writeup-lazyadmin/perlrs.png)

Bueno, ¡ahora soy root!

![](/assets/images/thm-writeup-lazyadmin/root.png)

Encontré la flag de root y lo leí con el comando "cat root.txt", la flag se encuentra en la ruta: "/root"

![](/assets/images/thm-writeup-lazyadmin/rootflag.png)

**:)**