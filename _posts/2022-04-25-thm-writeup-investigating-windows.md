---
layout: single
title: Investigating Windows
excerpt: "A windows machine has been hacked, its your job to go investigate this windows machine and find clues to what the hacker might have done."
date: 2022-04-28
classes: wide
header:
  teaser: /assets/images/thm-writeup-investigating-windows/windows_logo.png
  teaser_home_page: true
  icon: /assets/images/thm_ico.png
categories:
  - TryHackMe
  - infosec
tags:
  - Security
  - Metasploit
  - Tomcat
  - nmap
  - wfuzz
---

![logo](/assets/images/thm-writeup-investigating-windows/windows_logo.png)

 [Link](https://tryhackme.com/room/investigatingwindows "Windows")

This is a challenge that is exactly what is says on the tin, there are a few challenges around investigating a windows machine that has been previously compromised.

---

## 1. Whats the version and year of the windows machine?

![logo](/assets/images/thm-writeup-investigating-windows/windows_1.png)

## 2. Which user logged in last?

~~~css
PS C:\Users\Administrator> whoami
ec2amaz-i8uho76\administrator
~~~

## 3. When did John log onto the system last? - Answer format: MM/DD/YYYY H:MM:SS AM/PM

~~~css

PS C:\Users\Administrator> net user john
User name                    John
Full Name                    John
Comment                      
User's comment               
Country/region code          000 (System Default)
Account active               Yes
Account expires              Never

Password last set            3/2/2019 5:48:19 PM
Password expires             Never
Password changeable          3/2/2019 5:48:19 PM
Password required            Yes
User may change password     Yes

Workstations allowed         All
Logon script                 
User profile                 
Home directory               
Last logon                   3/2/2019 5:48:32 PM

Logon hours allowed          All

Local Group Memberships      *Users                
Global Group memberships     *None                 
The command completed successfully.
~~~

## 3. What IP does the system connect to when it first starts?

- Ejecutamos ***ctrl + r*** y buscamos la siguiente ruta: ***HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run***

![3](/assets/images/thm-writeup-investigating-windows/windows_4.png)

## 4. What two accounts had administrative privileges (other than the Administrator user)?

~~~css
[Listamos usarios]
PS C:\Users\Administrator> net users

User accounts for \\EC2AMAZ-I8UHO76

-------------------------------------------------------------------------------
Administrator            DefaultAccount           Guest                    
Jenny                    John                     

[Consultamos a Jenny]

PS C:\Users\Administrator> net user Jenny
User name                    Jenny
Full Name                    Jenny
Comment                      
User's comment               
Country/region code          000 (System Default)
Account active               Yes
Account expires              Never

Password last set            3/2/2019 4:52:25 PM
Password expires             Never
Password changeable          3/2/2019 4:52:25 PM
Password required            Yes
User may change password     Yes

Workstations allowed         All
Logon script                 
User profile                 
Home directory               
Last logon                   Never

Logon hours allowed          All

Local Group Memberships      *Administrators       *Users                
Global Group memberships     *None                 
The command completed successfully.
~~~

~~~css
[Consultamos a Guest]

PS C:\Users\Administrator> net user Guest
User name                    Guest
Full Name                    
Comment                      Built-in account for guest access to the computer/domain
User's comment               
Country/region code          000 (System Default)
Account active               Yes
Account expires              Never

Password last set            3/2/2019 4:39:43 PM
Password expires             Never
Password changeable          3/2/2019 4:39:43 PM
Password required            No
User may change password     No

Workstations allowed         All
Logon script                 
User profile                 
Home directory               
Last logon                   Never

Logon hours allowed          All

Local Group Memberships      *Administrators       *Guests               
Global Group memberships     *None                 
The command completed successfully.
~~~

---

## 5. Whats the name of the scheduled task that is malicous.

- Abrimos ***Server Manager***, ***herramientas*** y ***task sheduler***, aca observamos que tarea se ejecuta a diario:

![5](/assets/images/thm-writeup-investigating-windows/windows_5.png)

---

## 6. What file was the task trying to run daily?

- Abrimos ***Server Manager***, ***herramientas*** y ***task sheduler***, aca observamos que tarea se ejecuta a diario:

![6](/assets/images/thm-writeup-investigating-windows/windows_6.png)

---

## 7. What port did this file listen locally for?

- En la parte final se ve el puerto.

![6](/assets/images/thm-writeup-investigating-windows/windows_6.png)

---

## 8. When did Jenny last logon?

~~~css
PS C:\Users\Administrator> net user Jenny
User name                    Jenny
Full Name                    Jenny
Comment                      
User's comment               
Country/region code          000 (System Default)
Account active               Yes
Account expires              Never

Password last set            3/2/2019 4:52:25 PM
Password expires             Never
Password changeable          3/2/2019 4:52:25 PM
Password required            Yes
User may change password     Yes

Workstations allowed         All
Logon script                 
User profile                 
Home directory               
Last logon                   Never

Logon hours allowed          All

Local Group Memberships      *Administrators       *Users                
Global Group memberships     *None                 
The command completed successfully.
~~~

---

## 9. At what date did the compromise take place? - Answer format: MM/DD/YYYY

![9](/assets/images/thm-writeup-investigating-windows/windows_7.png)

---

## 10. At what time did Windows first assign special privileges to a new logon? - Answer format: MM/DD/YYYY HH:MM:SS AM/PM

![9](/assets/images/thm-writeup-investigating-windows/windows_8.png)

---

## 11. What tool was used to get Windows passwords?

![Mimikatz](/assets/images/thm-writeup-investigating-windows/windows_mimikatz.png)

---

## 12. What was the attackers external control and command servers IP?

![Control](/assets/images/thm-writeup-investigating-windows/windows_control.png)

## 13. What was the extension name of the shell uploaded via the servers website?

- En la siguiente ruta encontramos las shells ***c:/inetpub/wwwroot***

![jsp](/assets/images/thm-writeup-investigating-windows/windows_jsp.png)

---

## 14. What was the last port the attacker opened?

![1337](/assets/images/thm-writeup-investigating-windows/windows_1337.png)

---

## 15. Check for DNS poisoning, what site was targeted?

![Control](/assets/images/thm-writeup-investigating-windows/windows_control.png)

---

Gracias!



