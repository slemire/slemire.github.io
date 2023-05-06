---
layout: single
title: Bandit - Over The Wire
excerpt: "Lo que haremos en esta ocasión, será resolver todos los niveles que se encuentran en la sección **Bandit**, esto como práctica de pentesting en entornos Linux."
date: 2023-05-04
classes: wide
header:
  teaser: /assets/images/otw-writeups/overthewire-logo.jpg
  teaser_home_page: true
  icon: /assets/images/otw-writeups/hacker.png
categories:
  - OverTheWire
  - Bandit
tags:
  - Linux
  - Comandos Basicos Linux
---
<p align="center">
<img src="/assets/images/otw-writeups/overthewire-logo2.jpg">
</p>

Lo que haremos en esta ocasión, será resolver todos los niveles que se encuentran en la sección **Bandit**, esto como práctica de pentesting en entornos Linux.

**RECOMENDACIÓN**:

Guarda las contraseñas que vayas encontrando, por si vas haciendo notas o por si continuaras haciendo niveles en otro dia o simplemente por si las dudas.


<br>
<hr>
<div id="Indice">
	<h1>Índice</h1>
	<ul>
		<li><a href="#Nivel0">Nivel 0 a 1</a></li>
		<li><a href="#Nivel1">Nivel 1 a 2</a></li>
                <li><a href="#Nivel2">Nivel 2 a 3</a></li>
                <li><a href="#Nivel3">Nivel 3 a 4</a></li>
                <li><a href="#Nivel4">Nivel 4 a 5</a></li>
                <li><a href="#Nivel5">Nivel 5 a 6</a></li>
                <li><a href="#Nivel6">Nivel 6 a 7</a></li>
                <li><a href="#Nivel7">Nivel 7 a 8</a></li>
                <li><a href="#Nivel8">Nivel 8 a 9</a></li>
                <li><a href="#Nivel9">Nivel 9 a 10</a></li>
                <li><a href="#Nivel10">Nivel 10 a 11</a></li>
                <li><a href="#Nivel11">Nivel 11 a 12</a></li>

		<li><a href="#Links">Links de Investigación</a></li>
	</ul>
</div>


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel0" style="text-align:center;">Nivel 0 a 1</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

El objetivo de este nivel es que inicies sesión en el juego mediante **SSH**. El host al que debe conectarse es **bandit.labs.overthewire.org**, en el **puerto 2220**. El nombre de usuario es **bandit0** y la contraseña es **bandit0**. Una vez que haya iniciado sesión, vaya a la página del Nivel 1 para averiguar cómo superar el Nivel 1.

La contraseña para el siguiente nivel se almacena en un archivo llamado **readme** ubicado en el directorio de inicio. Use esta contraseña para iniciar sesión en **bandit1** usando **SSH**. Siempre que encuentre una contraseña para un nivel, use **SSH** (en el puerto 2220) para iniciar sesión en ese nivel y continuar el juego.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit0@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit0@bandit.labs.overthewire.org's password:
```
Recuerda que la contraseña es **bandit0**

Es muy simple, la flag la encuentras solamente usando el comando **ls**:
```
bandit0@bandit:~$ whoami
bandit0
bandit0@bandit:~$ ls
readme
```
Y ya solo debes leer ese archivo:
```
bandit0@bandit:~$ cat readme
...
```
¡Listo! Ya tenemos la contraseña para el nivel 1. Para salir, solo usa el comando **exit**. Vayamos al siguiente nivel.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel1" style="text-align:center;">Nivel 1 a 2</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en un archivo llamado **-** ubicado en el directorio de inicio.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit1@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit1@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 0.

Ya nos indicaron donde se encuentra la contraseña para el siguiente nivel. El problema es qué el nombre del archivo es un simple guion y si intentamos leerlo, nos dará un error:
```
bandit1@bandit:~$ whoami
bandit1
bandit1@bandit:~$ ls
-
bandit1@bandit:~$ cat -
^C
```
Ni me saco un error, por eso tuve que cancelar la acción. Para resolver esto, Over The Wire nos da una página con una solución:
* https://www.webservertalk.com/dashed-filename

En resumen, para leer el archivo, simplemente usamos el siguiente signo: **<**. 

Intentémoslo:
```
bandit1@bandit:~$ cat < -
...
```
¡Muy bien! Ya tenemos la contraseña para el siguiente nivel. Sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel2" style="text-align:center;">Nivel 2 a 3</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en un archivo llamado **spaces**, ubicado en el directorio de inicio.

**SOLUCIÓN**:
Primero entremos al servicio SSH:
```
ssh bandit2@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit2@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 1.

Ya sabemos que hay un archivo llamado **spaces** que tiene la contraseña, vamos a verlo:
```
bandit2@bandit:~$ whoami
bandit2
bandit2@bandit:~$ ls
spaces in this filename
```
Para leerlo, simplemente escribe las primeras letras del nombre del archivo y oprime la tecla **TAB** para que automáticamente te rellene el nombre del archivo:
```
bandit2@bandit:~$ cat spaces

bandit2@bandit:~$ cat spaces\ in\ this\ filename
...
```
¡Excelente! Ya tenemos la contraseña del siguiente nivel, sal y entra en el que sigue.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel3" style="text-align:center;">Nivel 3 a 4</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en un archivo oculto en el directorio **inhere**.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit3@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit3@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 2.

Es muy sencillo, primero veamos qué hay:
```
bandit3@bandit:~$ whoami
bandit3
bandit3@bandit:~$ ls
inhere
bandit3@bandit:~$ cd inhere/
```
Entonces, el archivo que tiene la contraseña está almacenado en un archivo oculto, para verlo, agregamos los parámetros **-la** al comando **ls**:
```
bandit3@bandit:~/inhere$ ls -la
total 12
drwxr-xr-x 2 root    root    4096 Apr 23 18:04 .
drwxr-xr-x 3 root    root    4096 Apr 23 18:04 ..
-rw-r----- 1 bandit4 bandit3   33 Apr 23 18:04 .hidden
```
Y ya solo vemos el archivo con **cat**:
```
bandit3@bandit:~/inhere$ cat .hidden
...
```
¡Listo! Ya tenemos la contraseña para el siguiente nivel, sal y entra en el siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel4" style="text-align:center;">Nivel 4 a 5</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el único archivo legible por humanos en el directorio **inhere**. Consejo: si su terminal está desordenada, intente con el comando **"reset"**.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit4@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit4@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 3.

Nos dice que la contraseña, está en una archivo que solo lo pueden leer los humanos...bueno, veamos qué hay dentro:
```
bandit4@bandit:~$ ls
inhere
bandit4@bandit:~$ cd inhere/
bandit4@bandit:~/inhere$ ls -la
total 48
drwxr-xr-x 2 root    root    4096 Apr 23 18:04 .
drwxr-xr-x 3 root    root    4096 Apr 23 18:04 ..
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file00
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file01
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file02
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file03
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file04
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file05
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file06
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file07
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file08
-rw-r----- 1 bandit5 bandit4   33 Apr 23 18:04 -file09
```
Mmmmm, los permisos indican que no se pueden ni leer con **cat**, a menos que los ejecutemos como programas. Entonces, veamos qué tipo de archivos son con el comando **file**:
```
bandit4@bandit:~/inhere$ file ./-file*
./-file00: data
./-file01: data
./-file02: data
./-file03: data
./-file04: data
./-file05: data
./-file06: data
./-file07: ASCII text
./-file08: data
./-file09: Non-ISO extended-ASCII text, with no line terminators
```
Solamente hay un archivo que es de texto, vamos a verlo:
```
bandit4@bandit:~/inhere$ cat ./-file07
...
```
¡Excelente! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel5" style="text-align:center;">Nivel 5 a 6</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel, se almacena en un archivo en algún lugar del directorio **inhere** y tiene todas las siguientes propiedades:
* legible por humanos
* 1033 bytes de tamaño
* no ejecutable

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit5@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit5@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 4.

Hay varias condiciones que tiene el archivo que contiene la contraseña, para buscarlo, usaremos el comando **find** con varios argumentos. Te comparto unos links con ejemplos de como usar el comando **find** y sobre los permisos de archivos:
* https://itsfoss.com/es/comando-find-linux/#buscar-varios-archivos-con-varias-extensiones-o-condici%C3%B3n
* https://www.hostinger.mx/tutoriales/como-usar-comando-find-locate-en-linux/#Busqueda_por_tipo
* https://gospelidea.com/blog/que-son-los-permisos-chmod

Bien, ahora entremos:
```
bandit5@bandit:~$ ls
inhere
bandit5@bandit:~$ cd inhere/
bandit5@bandit:~/inhere$ ls -la
total 88
drwxr-x--- 22 root bandit5 4096 Apr 23 18:04 .
drwxr-xr-x  3 root root    4096 Apr 23 18:04 ..
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere00
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere01
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere02
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere03
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere04
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere05
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere06
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere07
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere08
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere09
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere10
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere11
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere12
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere13
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere14
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere15
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere16
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere17
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere18
drwxr-x---  2 root bandit5 4096 Apr 23 18:04 maybehere19
```
Demasiados directorios, prodríamos buscar nuestro archivo, pero eso no es óptimo, así que usemos el comando **find**. Le agregaremos los siguientes parámetros:
* -type f: Para que busque archivos.
* -size 1033c: Para que busque los archivos con 1033 bytes de tamaño. 
* -perm 640: Para que busque por archivos con permisos de no ejecución.
* grep ASCII: Para que con **grep**, busque archivos que sean legibles por humanos.

Quedaría así:
```
bandit5@bandit:~/inhere$ find . -type f -size 1033c -perm 640 | grep ASCII
./maybehere07/.file2
```
Ahora, veamos el contenido de ese archivo:
```
cat maybehere07/.file2
...
```
¡Listo! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel6" style="text-align:center;">Nivel 6 a 7</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en algún lugar del servidor y tiene todas las siguientes propiedades:
* propiedad del usuario bandit7
* propiedad del grupo bandit6
* 33 bytes de tamaño

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit6@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit6@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 5.

Hay varias condiciones, igual usaremos el comando **find** y usemos las mismas páginas de referencia que puse en el nivel anterior para guiarnos. Aunque me sirvió más esta página:
* https://www.ionos.mx/digitalguide/servidores/configuracion/comando-linux-find/

Veamos que hay dentro:
```
bandit6@bandit:~$ ls
bandit6@bandit:~$ ls -la
total 20
drwxr-xr-x  2 root root 4096 Apr 23 18:04 .
drwxr-xr-x 70 root root 4096 Apr 23 18:05 ..
-rw-r--r--  1 root root  220 Jan  6  2022 .bash_logout
-rw-r--r--  1 root root 3771 Jan  6  2022 .bashrc
-rw-r--r--  1 root root  807 Jan  6  2022 .profile
```
No hay nada, entonces vamos a buscar en todo el servidor como nos mencionan, usemos el comando **find**. Para buscar en todo el servidor, usamos un **/** en vez de un **.** :
```
bandit6@bandit:~$ find / -type f -user bandit7 -group bandit6 -size 33c
find: ‘/var/log’: Permission denied
find: ‘/var/crash’: Permission denied
find: ‘/var/spool/rsyslog’: Permission denied
find: ‘/var/spool/bandit24’: Permission denied
find: ‘/var/spool/cron/crontabs’: Permission denied
...
```
Salieron muchos, entonces vamos a redirigir los errores al **/dev/null** para que solo nos muestre los resultados correctos:
```
bandit6@bandit:~$ find / -type f -user bandit7 -group bandit6 -size 33c 2>/dev/null
/var/lib/dpkg/info/bandit7.password
```
Ahora veamos el contenido de ese archivo:
```
bandit6@bandit:~$ cat /var/lib/dpkg/info/bandit7.password
...
```
¡Listo! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel7" style="text-align:center;">Nivel 7 a 8</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el archivo **data.txt** junto a la palabra **millionth**.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit7@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit7@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 6.

Como nos dice, hay un archivo llamado **data.txt** y la contraseña se encuentra junto a la palabra **millionth**, para encontrar esa palabra usaremos el comando **grep**, aquí te dejo este link con información muy útil sobre **grep**:
* https://geekland.eu/uso-del-comando-grep-en-linux-y-unix-con-ejemplos/

Veamos que contiene ese archivo:
```
bandit7@bandit:~$ ls
data.txt
bandit7@bandit:~$ cat data.txt 
Worcester's     fyKdWWh7VVgusiIKPygHJe6TlkDHhLHl
arousal r8mfBurE2OvHu8NFQc7mJ2x14iNjwkin
counterespionage's      4jmzYqFkqwciprPrJleFCI9tyjbXBtdt
Willard's       ctbhPNPRDGAll4Whhsrz3Mwv6qJHM8Et
midwife Kk9VZkoTUNUfmIa031vovUN2UKksZ56S
...
```
Ahhhhh mucho texto, bueno, mejor ya usemos **grep**:
```
bandit7@bandit:~$ grep -E -w 'millionth' data.txt
millionth		...
```
Y ahí está, te suelta la contraseña. Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel8" style="text-align:center;">Nivel 8 a 9</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el archivo **data.txt** y es la única línea de texto que aparece una sola vez.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit8@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit8@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 7.

Hay que buscar una línea de texto que sea única de todas las que hay en el archivo **data.txt**, para esto, usaremos los comandos **sort** y **uniq**.

El comando **sort** ordenará las palabras por orden alfabético.

Y el comando **uniq** con el parámetro **-u**, va a mostrar la línea de texto unica.

Primero, veamos el contenido:
```
bandit8@bandit:~$ ls
data.txt
bandit8@bandit:~$ cat data.txt 
QWiiBJhqUoMj0lCD9XNrkTM1M94eIPMV
UkKkkIJoUVJG6Zd1TDfEkBdPJptq2Sn7
ITQY9WLlsn3q168qH29wYMLQjgPH9lNP
JddNHIO2SAqKPHrrCcL7yTzArusoNwrt
0dEKX1sDwYtc4vyjrKpGu30ecWBsDDa9
...
```
El contenido del archivo es demasiado, ahora usemos los comandos:
```
bandit8@bandit:~$ sort data.txt | uniq -u
...
```
¡Exacto! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel9" style="text-align:center;">Nivel 9 a 10</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el archivo **data.txt**, en una de las pocas cadenas legibles por humanos, precedida por varios caracteres **'='**.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit8@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit8@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 8.

Tendremos que ver los permisos del archivo y que contenga más de un signo **=**. El problema es que el archivo está compuesto de solo data:
```
bandit9@bandit:~$ file data.txt 
data.txt: data
```
Lo que tendremos que hacer, será convertir la data a strings, para que sean legibles y luego buscar la línea de texto que tenga más de 2 signos **"=="**.

El comando **strings** devuelve en forma de cadena alfanumérica la expresión de tipo numérico, Fecha, Hora, cadena o Booleana que se pasa en expresión. Si no pasa el parámetro opcional formato, la cadena se devuelve en el formato por defecto del tipo de datos correspondiente.

Hagámoslo:
```
strings data.txt | grep "==="
4========== the#
========== password
========== is
========== *****
```
¡Exacto! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel10" style="text-align:center;">Nivel 10 a 11</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el archivo data.txt, que contiene datos codificados en base64.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit10@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit10@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 9.

Si bien el archivo está en base64, lo único que debemos hacer, será decodificar esa base64. Lo haremos con el comando **base64** y el parámetro **-d** que sirve para decodificar esa base:
```
bandit10@bandit:~$ ls
data.txt
bandit10@bandit:~$ file data.txt 
data.txt: ASCII text
bandit10@bandit:~$ cat data.txt 
VGhlIHBhc3N3b3JkIGlzIDZ6UGV6aUxkUjJSS05kTllGTmI2blZDS3pwaGxYSEJNCg==
```
Como puedes observar, el hash pareciera que es la contraseña, pero no es así. Ahora, apliquemos el comando:
```
bandit10@bandit:~$ base64 -d data.txt 
The password is *****
```
¡Muy bien! Ya tenemos la contraseña, sal y entra al siguiente.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Nivel11" style="text-align:center;">Nivel 11 a 12</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>

**INSTRUCCIONES**:

La contraseña para el siguiente nivel se almacena en el archivo data.txt, donde todas las letras minúsculas (a-z) y mayúsculas (A-Z) se han rotado 13 posiciones.

**SOLUCIÓN**:

Primero entremos al servicio SSH:
```
ssh bandit11@bandit.labs.overthewire.org -p2220
                         _                     _ _ _   
                        | |__   __ _ _ __   __| (_) |_ 
                        | '_ \ / _` | '_ \ / _` | | __|
                        | |_) | (_| | | | | (_| | | |_ 
                        |_.__/ \__,_|_| |_|\__,_|_|\__|
                                                       
                      This is an OverTheWire game server. 
            More information on http://www.overthewire.org/wargames

bandit11@bandit.labs.overthewire.org's password:
```
La contraseña es la que encontraste en el nivel 10.

Ufff, ya se va complicando esto.

Para resolver esto, usaremos el comando **tr**.

El comando **tr** permite al Usuario definir explícitamente como estará compuesto el conjunto o bien provee de una colección de caracteres y conjuntos predefinidos, que puede ser utilizados a la hora de definirlos.

Entonces, con **tr** vamos a mover todas las letras a donde estaban originalmente. Primero, veamos como quedaron las letras:
* Cada letra se movió 13 posiciones, es decir, la letra **a**, ya no es la **a** sino otra letra.
* Si miras el alfabeto, cuenta de la letra a 13 posiciones, debería quedar en la letra **m**. Debes contar desde A a Z, no te saltes la A.
* Esto es muy similar al cifrado de cesar, en el que se rotaban las letras, de acuerdo a una clave para que el mensaje quede encriptado.
* También se le conoce como ROT13.

Ahora sí, hagámoslo:
```
bandit11@bandit:~$ ls
data.txt
bandit11@bandit:~$ cat data.txt 
Gur cnffjbeq vf WIAOOSFzMjXXBC0KoSKBbJ8puQm5lIEi
bandit11@bandit:~$ file data.txt 
data.txt: ASCII text
bandit11@bandit:~$ tr 'A-Za-z' 'N-ZA-Mn-za-m' < data.txt 
The password is
```
Si te fijas, lo que hicimos fue sustituir **'A-Za-z'** por **'N-ZA-Mn-za-m'**, en donde:
* A-Z = N-ZA-M
* a-z = n-za-m

¡Muy bien! Ya tenemos la contraseña, sal y entra al siguiente.

# CONTINUARA...

<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://overthewire.org/wargames/bandit/
* https://www.webservertalk.com/dashed-filename
* https://itsfoss.com/es/comando-find-linux/#buscar-varios-archivos-con-varias-extensiones-o-condici%C3%B3n
* https://www.hostinger.mx/tutoriales/como-usar-comando-find-locate-en-linux/#Busqueda_por_tipo
* https://gospelidea.com/blog/que-son-los-permisos-chmod
* https://www.ionos.mx/digitalguide/servidores/configuracion/comando-linux-find/
* https://geekland.eu/uso-del-comando-grep-en-linux-y-unix-con-ejemplos/
* https://geekland.eu/uso-del-comando-grep-en-linux-y-unix-con-ejemplos/


<br>
# FIN
