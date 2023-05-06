---
layout: single
title: Delivery - Hack The Box
excerpt: "Esta fue una máquina bastante interesante, lo que hicimos fue, analizar el puerto HTTP para descubrir que usan Virtual Hosting, registramos los dominios y aprovechamos un bug que nos crea un correo temporal en OS Ticket, con esto, usaremos el servicio Mattermost para crear una cuenta y obtener un correo de autenticación en el correo del OS Ticket. Una vez dentro de Mattermost, vemos mensajes del Root, que nos indican el usuario y contraseña del servicio SSH y nos dan una pista, siendo que debemos ir a la base de datos de Mattermost dentro del SSH y obtener el hash del Root para poder usar un ataque de reglas de hashcat para poder crackearlo y con esto, autenticarnos como Root."
date: 2023-05-05
classes: wide
header:
  teaser: /assets/images/htb-writeup-delivery/delivery_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - OS Ticket
  - Mattermost
  - Virtual Hosting
  - Abussing Support Ticket System
  - Information Leakage
  - MySQL Enumeration
  - Cracking Hash
  - Hashcat
  - OSCP Style
---
![](/assets/images/htb-writeup-delivery/delivery_logo.png)
Esta fue una máquina bastante interesante, lo que hicimos fue, analizar el puerto HTTP para descubrir que usan Virtual Hosting, registramos los dominios y aprovechamos un bug que nos crea un correo temporal en OS Ticket, con esto, usaremos el servicio Mattermost para crear una cuenta y obtener un correo de autenticación en el correo del OS Ticket. Una vez dentro de Mattermost, vemos mensajes del Root, que nos indican el usuario y contraseña del servicio SSH y nos dan una pista, siendo que debemos ir a la base de datos de Mattermost dentro del SSH y obtener el hash del Root para poder usar un ataque de reglas de hashcat para poder crackearlo y con esto, autenticarnos como Root.


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
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Matter">Analizando Servicio Mattermost</a></li>				
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Matter2">Buscando Hashes del Servicio Mattermost</a></li>
                                <li><a href="#Mysql">Enumeración Base de Datos MySQL</a></li>
				<li><a href="#Hash">Crackeando Hash</a></li>
				<li><a href="#Root">Escalando a Root</a></li>
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
ping -c 4 10.10.10.222
PING 10.10.10.222 (10.10.10.222) 56(84) bytes of data.
64 bytes from 10.10.10.222: icmp_seq=1 ttl=63 time=131 ms
64 bytes from 10.10.10.222: icmp_seq=2 ttl=63 time=131 ms
64 bytes from 10.10.10.222: icmp_seq=3 ttl=63 time=132 ms
64 bytes from 10.10.10.222: icmp_seq=4 ttl=63 time=132 ms

--- 10.10.10.222 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3008ms
rtt min/avg/max/mdev = 130.588/131.581/132.319/0.666 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.222 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-05 12:22 CST
Initiating SYN Stealth Scan at 12:22
Scanning 10.10.10.222 [65535 ports]
Discovered open port 80/tcp on 10.10.10.222
Discovered open port 22/tcp on 10.10.10.222
Discovered open port 8065/tcp on 10.10.10.222
Completed SYN Stealth Scan at 12:23, 35.87s elapsed (65535 total ports)
Nmap scan report for 10.10.10.222
Host is up, received user-set (0.41s latency).
Scanned at 2023-05-05 12:22:53 CST for 35s
Not shown: 39964 filtered tcp ports (no-response), 25568 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT     STATE SERVICE REASON
22/tcp   open  ssh     syn-ack ttl 63
80/tcp   open  http    syn-ack ttl 63
8065/tcp open  unknown syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 35.97 seconds
           Raw packets sent: 172589 (7.594MB) | Rcvd: 26071 (1.077MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Hay 3 puertos abiertos, pero se me hace que todo se va a basar en el puerto HTTP, hagamos un escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p22,80,8065 10.10.10.222 -oN targeted                      
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-05 12:25 CST
Nmap scan report for 10.10.10.222
Host is up (0.13s latency).

PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.9p1 Debian 10+deb10u2 (protocol 2.0)
| ssh-hostkey: 
|   2048 9c40fa859b01acac0ebc0c19518aee27 (RSA)
|   256 5a0cc03b9b76552e6ec4f4b95d761709 (ECDSA)
|_  256 b79df7489da2f27630fd42d3353a808c (ED25519)
80/tcp   open  http    nginx 1.14.2
|_http-server-header: nginx/1.14.2
|_http-title: Welcome
8065/tcp open  unknown
| fingerprint-strings: 
|   GenericLines, Help, RTSPRequest, SSLSessionReq, TerminalServerCookie: 
|     HTTP/1.1 400 Bad Request
|     Content-Type: text/plain; charset=utf-8
|     Connection: close
|     Request
|   GetRequest: 
|     HTTP/1.0 200 OK
|     Accept-Ranges: bytes
|     Cache-Control: no-cache, max-age=31556926, public
|     Content-Length: 3108
|     Content-Security-Policy: frame-ancestors 'self'; script-src 'self' cdn.rudderlabs.com
|     Content-Type: text/html; charset=utf-8
|     Last-Modified: Fri, 05 May 2023 18:17:51 GMT
|     X-Frame-Options: SAMEORIGIN
|     X-Request-Id: ngd3jjncpiyr8gg7rxozrixk1w
|     X-Version-Id: 5.30.0.5.30.1.57fb31b889bf81d99d8af8176d4bbaaa.false
|     Date: Fri, 05 May 2023 18:25:24 GMT
|     <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=0"><meta name="robots" content="noindex, nofollow"><meta name="referrer" content="no-referrer"><title>Mattermost</title><meta name="mobile-web-app-capable" content="yes"><meta name="application-name" content="Mattermost"><meta name="format-detection" content="telephone=no"><link re
|   HTTPOptions: 
|     HTTP/1.0 405 Method Not Allowed
|     Date: Fri, 05 May 2023 18:25:24 GMT
|_    Content-Length: 0
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port8065-TCP:V=7.93%I=7%D=5/5%Time=64554A11%P=x86_64-pc-linux-gnu%r(Gen
SF:ericLines,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Type:\x20te
SF:xt/plain;\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x20Bad\x2
SF:0Request")%r(GetRequest,DF3,"HTTP/1\.0\x20200\x20OK\r\nAccept-Ranges:\x
SF:20bytes\r\nCache-Control:\x20no-cache,\x20max-age=31556926,\x20public\r
SF:\nContent-Length:\x203108\r\nContent-Security-Policy:\x20frame-ancestor
SF:s\x20'self';\x20script-src\x20'self'\x20cdn\.rudderlabs\.com\r\nContent
SF:-Type:\x20text/html;\x20charset=utf-8\r\nLast-Modified:\x20Fri,\x2005\x
SF:20May\x202023\x2018:17:51\x20GMT\r\nX-Frame-Options:\x20SAMEORIGIN\r\nX
SF:-Request-Id:\x20ngd3jjncpiyr8gg7rxozrixk1w\r\nX-Version-Id:\x205\.30\.0
SF:\.5\.30\.1\.57fb31b889bf81d99d8af8176d4bbaaa\.false\r\nDate:\x20Fri,\x2
SF:005\x20May\x202023\x2018:25:24\x20GMT\r\n\r\n<!doctype\x20html><html\x2
SF:0lang=\"en\"><head><meta\x20charset=\"utf-8\"><meta\x20name=\"viewport\
SF:"\x20content=\"width=device-width,initial-scale=1,maximum-scale=1,user-
SF:scalable=0\"><meta\x20name=\"robots\"\x20content=\"noindex,\x20nofollow
SF:\"><meta\x20name=\"referrer\"\x20content=\"no-referrer\"><title>Matterm
SF:ost</title><meta\x20name=\"mobile-web-app-capable\"\x20content=\"yes\">
SF:<meta\x20name=\"application-name\"\x20content=\"Mattermost\"><meta\x20n
SF:ame=\"format-detection\"\x20content=\"telephone=no\"><link\x20re")%r(HT
SF:TPOptions,5B,"HTTP/1\.0\x20405\x20Method\x20Not\x20Allowed\r\nDate:\x20
SF:Fri,\x2005\x20May\x202023\x2018:25:24\x20GMT\r\nContent-Length:\x200\r\
SF:n\r\n")%r(RTSPRequest,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent
SF:-Type:\x20text/plain;\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n4
SF:00\x20Bad\x20Request")%r(Help,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\
SF:nContent-Type:\x20text/plain;\x20charset=utf-8\r\nConnection:\x20close\
SF:r\n\r\n400\x20Bad\x20Request")%r(SSLSessionReq,67,"HTTP/1\.1\x20400\x20
SF:Bad\x20Request\r\nContent-Type:\x20text/plain;\x20charset=utf-8\r\nConn
SF:ection:\x20close\r\n\r\n400\x20Bad\x20Request")%r(TerminalServerCookie,
SF:67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Type:\x20text/plain;\
SF:x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x20Bad\x20Request");
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 100.00 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Ese puerto 8065 se me hace curioso, puede que estemos contra un Virtual Hosting, pero analicemos primero el puerto HTTP.

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
<img src="/assets/images/htb-writeup-delivery/Captura1.png">
</p>

Ok, veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura2.png">
</p>

Mmmmm **nginx** otra vez, tengámoslo en cuenta para más adelante. Mientras sigamos analizando la página.

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura3.png">
</p>

Si entramos en la sección **Contact**, vemos que podemos irnos a dos subpáginas, veamos que son:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura4.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura5.png">
</p>

No se ve nada, entonces vamos a registrar el dominio en el **/etc/hosts** y el subdominio del **helpdesk**:
```
nano /etc/hosts
10.10.10.222 delivery.htb, helpdesk.delivery.htb
```
Y recarguemos otra vez las páginas, ya deberían verse:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura6.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura7.png">
</p>

Vemos dos servicios, investiguemos un poquito que son:

* **OS Ticket**: es un sistema de tickets de asistencia de código abierto. Dirige las consultas creadas a través de correo electrónico, formularios web y llamadas telefónicas hacia una plataforma de asistencia al cliente sencilla, fácil de usar y multiusuario basada en la web.

* **Mattermost**: Mattermost es un servicio de chat en línea de código abierto y autohospedable con intercambio de archivos, búsqueda e integraciones. Está diseñado como un chat interno para organizaciones y empresas, y en su mayoría se comercializa como una alternativa de código abierto a Slack y Microsoft Teams.

Ahora lo que haremos, será probar lo que nos indica la página, el problema es que si queremos crear una cuenta, nos piden verificar la cuenta aprobando un correo que ellos nos manden, esto no nos funcionara, por lo que tenemos que investigar más que podemos hacer.

Tratemos de abrir un nuevo ticket, para ver que pasa:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura8.png">
</p>

Y nos da este resultado, **OJO**, el número de ticket es diferente porque don pendejo, ósea yo, no guarde las capturas cuando lo hice bien, lo menciono para que no se confundan:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura9.png">
</p>

Intentemos ver nuestro ticket como lo indica la imagen:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura10.png">
</p>

Mmmmm nos da error, hagámoslo con nuestro usuario a ver si se puede:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura11.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura12.png">
</p>

Se pudo, lo que veo, es que nos creó un correo temporal, por lo que podemos usar este correo temporal para obtener mensajes, al menos podríamos intentar ver si esto se puede.

¿Ahora qué? Por lo que entiendo y lo que nos dice la página, si tenemos un usuario, podemos loguearnos en el servicio **Mattermost**, entonces vamos a crear un usuario con el mismo correo temporal que nos generó el **OS Ticket** para ver si nos llega el correo de autenticación, veamos que sucede:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura13.png">
</p>

Ok, ya se creó, pero igual nos pide que verifiquemos a través de un email. ¿Se abra enviado algo a la cuenta del ticket? Comprobemos:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura14.png">
</p>

Ufff, usemos el link que nos mandaron, quizá con eso ya autenticaremos la cuenta del servicio **Mattermost**:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura15.png">
</p>

¡Listo! Metemos la contraseña de prueba que hayas puesto y logueate:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura16.png">
</p>

Estamos dentro, ahora podemos investigar lo que hay dentro.


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


<h2 id="Matter">Analizando Servicio Mattermost</h2>

Bien, veamos que hay dentro una vez logueados:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura17.png">
</p>

Vamos a darle skip:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura18.png">
</p>

Mmmmm nos salen mensajes del root, si traducimos lo que nos menciona en el primer mensaje, nos dan un usuario y contraseña, que supongo son del servicio SSH. Pero antes, veamos la versión de **Mattermost** por si lo necesitamos después:

<p align="center">
<img src="/assets/images/htb-writeup-delivery/Captura19.png">
</p>

Ahora sí, entremos al servicio SSH:
```
ssh maildeliverer@10.10.10.222
maildeliverer@10.10.10.222's password:
maildeliverer@10.10.10.222's password: 
Linux Delivery 4.19.0-13-amd64 #1 SMP Debian 4.19.160-2 (2020-11-28) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri May  5 15:25:14 2023 from 10.10.14.16
maildeliverer@Delivery:~$ whoami
maildeliverer
```
¡Excelente! Busquemos la flag del usuario:
```
maildeliverer@Delivery:~$ ls
user.txt
maildeliverer@Delivery:~$ cat user.txt
...
```
Listo, ahora busquemos la forma de escalar privilegios.

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

Si vemos el segundo mensaje del Root, en el servicio **Mattermost**, veremos que mencionan que la contraseña **PleaseSubscribe!** no deberia estar en el **rockyou.txt**, lo curioso es que mencionan que si un hacker, puede obtener los hashes, de lo que supongo son del servicio **Mattermost**, pueden usar las **rules** de **hashcat** para crackear variaciones de esa contraseña.

Esto obviamente es una pista sobre lo que tenemos que hacer, que es buscar los hashes del servicio **Mattermost** y usar **hashcat** para crear un diccionario de variaciones de la contraseña **PleaseSubscribe!**.

<h2 id="Matter2">Buscando Hashes del Servicio Mattermost</h2>

Checa este blog sobre este servicio:
* https://www.drivemeca.com/mattermost-linux-server/

Hay un archivo llamado **config.json**, que se encuentra en **/opt/mattermost/**. Este puede contener información valiosa de la base de datos, vayamos a verla:
```
maildeliverer@Delivery:~$ cd /opt/mattermost
maildeliverer@Delivery:/opt/mattermost$ ls
bin     config  ENTERPRISE-EDITION-LICENSE.txt  i18n  manifest.txt  plugins              README.md
client  data    fonts                           logs  NOTICE.txt    prepackaged_plugins  templates
maildeliverer@Delivery:/opt/mattermost$ cd config/
maildeliverer@Delivery:/opt/mattermost/config$ ls
cloud_defaults.json  config.json  README.md
```
Veamos el interior:
```
maildeliverer@Delivery:/opt/mattermost/config$ cat config.json 
{
    "ServiceSettings": {
        "SiteURL": "",
        "WebsocketURL": "",
        "LicenseFileLocation": "",
        "ListenAddress": ":8065",
        "ConnectionSecurity": "",
        "TLSCertFile": "",
        "TLSKeyFile": "",
        "TLSMinVer": "1.2",
        "TLSStrictTransport": false,
...
```
Si usamos **grep**, buscando sql o mysql, nos dará un resultado más acertado de donde buscar:
```
maildeliverer@Delivery:/opt/mattermost/config$ cat config.json | grep sql
        "DriverName": "mysql",
```
Y buscando eso, encontramos algo crítico:
```
"SqlSettings": {
        "DriverName": "mysql",
        "DataSource": "mmuser:Crack_The_MM_Admin_PW@tcp(127.0.0.1:3306)/mattermost?charset=utf8mb4,utf8\u0026readTimeout=30s\u0026writeTimeout=30s",
        "DataSourceReplicas": [],
        "DataSourceSearchReplicas": [],
        "MaxIdleConns": 20,
        "ConnMaxLifetimeMilliseconds": 3600000,
        "MaxOpenConns": 300,
        "Trace": false,
        "AtRestEncryptKey": "n5uax3d4f919obtsp1pw1k5xetq1enez",
        "QueryTimeout": 30,
        "DisableDatabaseSearch": false
    },
```
Tenemos un usuario y contraseña, para conectarnos a la base de datos de **mysql**, checa este blog:
* https://help.dreamhost.com/hc/es/articles/214882998-Conectarse-a-una-base-de-datos-v%C3%ADa-SSH

Bien, conectémonos:
```
maildeliverer@Delivery:/opt/mattermost/config$ mysql -u mmuser -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 98
Server version: 10.3.27-MariaDB-0+deb10u1 Debian 10

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]>
```
Ahora investiguemos la base de datos.

<h2 id="Mysql">Enumeración Base de Datos MySQL</h2>

Veamos primero que bases de datos hay:
```
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mattermost         |
+--------------------+
2 rows in set (0.001 sec)
```
Usemos la BD **mattermost** y veamos su contenido:
```
MariaDB [(none)]> use mattermost
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [mattermost]> show tables;
+------------------------+
| Tables_in_mattermost   |
+------------------------+
| Audits                 |
| Bots                   |
| ChannelMemberHistory   |
| ChannelMembers         |
| Channels               |
| ClusterDiscovery       |
| CommandWebhooks        |
| Commands               |
| Compliances            |
| Emoji                  |
| FileInfo               |
| GroupChannels          |
| GroupMembers           |
| GroupTeams             |
| IncomingWebhooks       |
| Jobs                   |
| Licenses               |
| LinkMetadata           |
| OAuthAccessData        |
| OAuthApps              |
| OAuthAuthData          |
| OutgoingWebhooks       |
| PluginKeyValueStore    |
| Posts                  |
| Preferences            |
| ProductNoticeViewState |
| PublicChannels         |
| Reactions              |
| Roles                  |
| Schemes                |
| Sessions               |
| SidebarCategories      |
| SidebarChannels        |
| Status                 |
| Systems                |
| TeamMembers            |
| Teams                  |
| TermsOfService         |
| ThreadMemberships      |
| Threads                |
| Tokens                 |
| UploadSessions         |
| UserAccessTokens       |
| UserGroups             |
| UserTermsOfService     |
| Users                  |
+------------------------+
46 rows in set (0.000 sec)
```
Tenemos varias tablas, pero me llama la atención la de **Users**, veamos su contenido:
```
MariaDB [mattermost]> describe Users;
+--------------------+--------------+------+-----+---------+-------+
| Field              | Type         | Null | Key | Default | Extra |
+--------------------+--------------+------+-----+---------+-------+
| Id                 | varchar(26)  | NO   | PRI | NULL    |       |
| CreateAt           | bigint(20)   | YES  | MUL | NULL    |       |
| UpdateAt           | bigint(20)   | YES  | MUL | NULL    |       |
| DeleteAt           | bigint(20)   | YES  | MUL | NULL    |       |
| Username           | varchar(64)  | YES  | UNI | NULL    |       |
| Password           | varchar(128) | YES  |     | NULL    |       |
| AuthData           | varchar(128) | YES  | UNI | NULL    |       |
| AuthService        | varchar(32)  | YES  |     | NULL    |       |
| Email              | varchar(128) | YES  | UNI | NULL    |       |
| EmailVerified      | tinyint(1)   | YES  |     | NULL    |       |
| Nickname           | varchar(64)  | YES  |     | NULL    |       |
| FirstName          | varchar(64)  | YES  |     | NULL    |       |
| LastName           | varchar(64)  | YES  |     | NULL    |       |
| Position           | varchar(128) | YES  |     | NULL    |       |
| Roles              | text         | YES  |     | NULL    |       |
| AllowMarketing     | tinyint(1)   | YES  |     | NULL    |       |
| Props              | text         | YES  |     | NULL    |       |
| NotifyProps        | text         | YES  |     | NULL    |       |
| LastPasswordUpdate | bigint(20)   | YES  |     | NULL    |       |
| LastPictureUpdate  | bigint(20)   | YES  |     | NULL    |       |
| FailedAttempts     | int(11)      | YES  |     | NULL    |       |
| Locale             | varchar(5)   | YES  |     | NULL    |       |
| Timezone           | text         | YES  |     | NULL    |       |
| MfaActive          | tinyint(1)   | YES  |     | NULL    |       |
| MfaSecret          | varchar(128) | YES  |     | NULL    |       |
+--------------------+--------------+------+-----+---------+-------+
25 rows in set (0.001 sec)
```
Ahuevo, ahí están las credenciales, veamos si se pueden ver:
```
MariaDB [mattermost]> select Username, Password from Users;
+----------------------------------+--------------------------------------------------------------+
| Username                         | Password                                                     |
+----------------------------------+--------------------------------------------------------------+
| surveybot                        |                                                              |
| c3ecacacc7b94f909d04dbfd308a9b93 | $2a$10$u5815SIBe2Fq1FZlv9S8I.VjU3zeSPBrIEg9wvpiLaS7ImuiItEiK |
| 5b785171bfb34762a933e127630c4860 | $2a$10$3m0quqyvCE8Z/R1gFcCOWO6tEj6FtqtBn8fRAXQXmaKmg.HDGpS/G |
| root                             | $2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO |
| ff0a21fc6fc2488195e16ea854c963ee | $2a$10$RnJsISTLc9W3iUcUggl1KOG9vqADED24CQcQ8zvUm1Ir9pxS.Pduq |
| channelexport                    |                                                              |
| berserkw                         | $2a$10$z35SPIrJtjWwpEeBwfOE..IlOzRiHMkyIdWk2tvdeDBhikWQP06Iy |
| 9ecfb4be145d47fda0724f697f35ffaf | $2a$10$s.cLPSjAVgawGOJwB7vrqenPg2lrDtOECRtjwWahOzHfq1CoFyFqm |
| berserkwi                        | $2a$10$7RtDTF2AaEtm.ySNa7lJfO5Er93SZl0NXHreFaxZ/7Mqeva2mFm3O |
+----------------------------------+--------------------------------------------------------------+
9 rows in set (0.000 sec)
```
Excelente, tenemos la contraseña del Root, pero está encriptada por un tipo de hash que no conocemos, vamos a guardar el hash del Root y analicemoslo con unas herramientas para estos casos.

<h2 id="Hash">Crackeando Hash</h2>

Para crackear el hash, tenemos que saber el tipo de encriptado que se usó, para saberlo, usaremos la herramienta **hashid**:
```
hashid '$2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO'
Analyzing '$2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO'
[+] Blowfish(OpenBSD) 
[+] Woltlab Burning Board 4.x 
[+] bcrypt
```
El tipo de encriptado, es el que está al final. Por lo tanto, se encriptó usando **bcrypt**.

Ahora lo que haremos, será crear un diccionario, con variaciones de la contraseña que pide el Root, no se use más, hagámoslo por pasos

Guardemos esa contraseña en un archivo:
```
nano passwd
PleaseSubscribe!
```
Para usar hashcat, te recomiendo que leas el siguiente blog:
* https://jesux.es/cracking/passwords-cracking/

Ahí, hay un apartado llamado **Metodologia** donde se ven como usar las reglas de **hashcat**. Lo interesante es esto:

**El uso de reglas es uno de los puntos fuertes de hashcat, ya que nos permite generar mutaciones en nuestro diccionarios. Hashcat incluye diversos archivos de reglas. Podemos destacar el archivo best64 que obtiene un buen resultado con un pequeño número de reglas.**

Ahora usando **hashcat**, usaremos la regla **best64.rule** para crear variaciones de la contraseña, también usemos el parámetro **--stdout** para utilizar el archivo **passwd** y el resultado se guardará en **diccionario.txt**:
```
hashcat -r /usr/share/hashcat/rules/best64.rule --stdout passwd > diccionario.txt
ls
credentials.txt  diccionario.txt  flags.txt  hash  passwd
```
**--stdout  |    | Do not crack a hash, instead print candidates only**

Veamos el diccionario que se creó:
```
cat diccionario.txt 
PleaseSubscribe!
!ebircsbuSesaelP
PLEASESUBSCRIBE!
pleaseSubscribe!
PleaseSubscribe!0
PleaseSubscribe!1
PleaseSubscribe!2
PleaseSubscribe!3
PleaseSubscribe!4
PleaseSubscribe!5
PleaseSubscribe!6
PleaseSubscribe!7
PleaseSubscribe!8
PleaseSubscribe!9
PleaseSubscribe!00
PleaseSubscribe!01
PleaseSubscribe!02
PleaseSubscribe!11
PleaseSubscribe!12
PleaseSubscribe!13
PleaseSubscribe!21
PleaseSubscribe!22
PleaseSubscribe!23
PleaseSubscribe!69
PleaseSubscribe!77
PleaseSubscribe!88
PleaseSubscribe!99
PleaseSubscribe!123
PleaseSubscribe!e
PleaseSubscribe!s
PleaseSubscribea
PleaseSubscribs
PleaseSubscriba
PleaseSubscriber
PleaseSubscribie
PleaseSubscrio
PleaseSubscriy
PleaseSubscri123
PleaseSubscriman
PleaseSubscridog
1PleaseSubscribe!
thePleaseSubscribe!
dleaseSubscribe!
maeaseSubscribe!
PleaseSubscribe!
PleaseSubscr1be!
Pl3as3Subscrib3!
PlaseSubscribe!
PlseSubscribe!
PleseSubscribe!
PleaeSubscribe!
Ples
Pleas1
PleaseSubscribe
PleaseSubscrib
PleaseSubscri
PleaseSubscriPleaseSubscri
PeaseSubscri
ribe
bscribe!easeSu
PleaseSubscri!
dleaseSubscrib
be!PleaseSubscri
ibe!
ribe!
cribcrib
tlea
asPasP
XleaseSubscribe!
SaseSubscribe!
PleaSu
PlesPles
asP
PlcrPlcr
PcSu
PleasS
PeSubs
```

Por último, usemos la herramienta **John** para crackear al fin, el hash del Root:
```
john -w=diccionario.txt hash                                                     
Using default input encoding: UTF-8
Loaded 1 password hash (bcrypt [Blowfish 32/64 X3])
Cost 1 (iteration count) is 1024 for all loaded hashes
Press 'q' or Ctrl-C to abort, almost any other key for status
PleaseSubscribe!21 (?)     
1g 0:00:00:07 DONE (2023-05-05 14:22) 0.1324g/s 2.781p/s 2.781c/s 2.781C/s PleaseSubscribe!12..PleaseSubscribe!21
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```
Listo, ahora accedamos como Root.

<h2 id="Root">Escalando a Root</h2>

Usemos la contraseña crackeada para ser Root:
```
ssh maildeliverer@10.10.10.222
maildeliverer@10.10.10.222's password: 
Linux Delivery 4.19.0-13-amd64 #1 SMP Debian 4.19.160-2 (2020-11-28) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri May  5 15:51:38 2023 from 10.10.14.16
maildeliverer@Delivery:~$ su
Password: 
root@Delivery:/home/maildeliverer# whoami
root
```

Por último, buscamos la flag:
```
root@Delivery:/home/maildeliverer# cd /root
root@Delivery:~# ls
mail.sh  note.txt  py-smtp.py  root.txt
root@Delivery:~# cat root.txt
...
```
Ya con esto, completamos la máquina. Pero ojito porque hay una nota, veámosla:
```
root@Delivery:~# cat note.txt 
I hope you enjoyed this box, the attack may seem silly but it demonstrates a pretty high risk vulnerability I've seen several times.  The inspiration for the box is here: 

- https://medium.com/intigriti/how-i-hacked-hundreds-of-companies-through-their-helpdesk-b7680ddc2d4c 

Keep on hacking! And please don't forget to subscribe to all the security streamers out there.

- ippsec
```
Suscribete a su canal, gran maestro **Ippsec**

<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://forum.mattermost.com/t/solved-how-to-check-currently-installed-mattermost-server-version/3543
* https://www.drivemeca.com/mattermost-linux-server/
* https://help.dreamhost.com/hc/es/articles/214882998-Conectarse-a-una-base-de-datos-v%C3%ADa-SSH
* https://www.dragonjar.org/identificando-el-tipo-de-hash.xhtml
* https://ciberseguridad.com/herramientas/hashcat/#Crea_un_diccionario_con_hashes_MBD5
* https://jesux.es/cracking/passwords-cracking/


<br>
# FIN
