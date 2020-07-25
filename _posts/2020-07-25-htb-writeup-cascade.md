---
layout: single
title: Cascade - Hack The Box
excerpt: "Cascade was a simple and straightforward enumeration-focused Windows box. We find the credentials for the initial account in a custom LDAP attibute then enumerate SMB shares, finding VNC credentials which can be decrypted. With those creds we find an SQlite database that contains encrypted credentials for yet another user. To decrypt the password we have to reverse a simple .NET application located on one of the shares. The final privesc involves getting the admin password from tombstone, a feature in AD that keeps deleted objects for a period of time."
date: 2020-07-25
classes: wide
header:
  teaser: /assets/images/htb-writeup-cascade/cascade_logo.png
  teaser_home_page: true
  icon: /assets/images/hackthebox.webp
categories:
  - hackthebox
  - infosec
tags:
  - ldap
  - smb  
  - vnc
  - reversing
  - crypto
  - tombstone
---

![](/assets/images/htb-writeup-cascade/cascade_logo.png)

Cascade was a simple and straightforward enumeration-focused Windows box. We find the credentials for the initial account in a custom LDAP attibute then enumerate SMB shares, finding VNC credentials which can be decrypted. With those creds we find an SQlite database that contains encrypted credentials for yet another user. To decrypt the password we have to reverse a simple .NET application located on one of the shares. The final privesc involves getting the admin password from tombstone, a feature in AD that keeps deleted objects for a period of time.

## Summary

- Get a list of users from the LDAP directory
- Find the password for user r.thompson in the cascadeLegacyPwd LDAP attribute
- Enumerate Data SMB share, find VNC encrypted password for user s.smith
- Decrypt VNC password, log in and find an SQlite database with the encrypted password for ArkSvc user
- Download the .NET crypto application, reverse it, find cipher, key and IV then decrypt the ArkAvc password
- Log in as ArkSvc, recover old deleted TempAdmin account password then log in as Administrator

## Portscan

![](/assets/images/htb-writeup-cascade/nmap.png)

## SMB recon

We can use crackmapexec to check out the domain name on the machine and check if there are any SMB shares accessible. There doesn't seem to to be anything accessible on SMB at the moment with our guest user or a null session.

![](/assets/images/htb-writeup-cascade/crackmapexec.png)

## User enumeration

Anonymous LDAP bind sessions are allowed on this domain controller so any unauthenticated user can retrieve the user and group list from the DC. The first thing I did was list only the **sAMAccountName** attributes to see if there any accounts name that contain **adm**, **svc** or any other string that might indicate a potentially high privilege account.

![](/assets/images/htb-writeup-cascade/windapsearch1.png)

There's a **arksvc** and **BackupSvc** account in there. Service accounts are a juicy target because they often hold elevated privileges in the domain. In real life, some products don't provide proper documentation about the minimum rights required by their service accounts so domain admins will sometimes put service accounts in the "Domain Admins" group. Combined with a weak password policy this can provide a quick way to DA.

Next we'll look at the full attributes list of the users to see if there's any custom attribute added or credentials that might have been added in a description field or something like that. Here we see that the **r.thompson** user has a custom attribute **cascadeLegacyPwd** with a base64 encoded string.

![](/assets/images/htb-writeup-cascade/legacypwd.png)

The base64 value appears to contain the plaintext password value.

![](/assets/images/htb-writeup-cascade/legacypwd2.png)

We can validate the credentials by using crackmapexec and we see that the credentials are valid.

![](/assets/images/htb-writeup-cascade/ryan.png)

## SMB share enumeration and s.smith user escalation

User **r.thompson** can't log in with WinRM but has read-only access to a **Data** share. We can mount the CIFS filesystem so it'll be easier to look around, grep files, etc.

![](/assets/images/htb-writeup-cascade/smbenum1.png)

We'll look for credentials by searching for files that contain **password**. Because this is a Windows machine, some of the files may be using UTF-16 encoding so if we just use the standard Linux grep program there's a good chance we might miss some stuff. Instead I'll use Powershell for Linux and it'll automatically scan for both UTF-8 and UTF-16 encoded strings when using the **Select-String** function.

![](/assets/images/htb-writeup-cascade/smbenum2.png)

We found two things here: The first is an email with the minutes from a meeting in 2018 with a **TempAdmin** account. The email says the password is the same as the normal admin account but we don't have it. The second hit is an encrypted VNC password for user **s.smith**.

VNC password are encrypted with a modified DES cipher and a static key. One tool we can use is [https://github.com/jeroennijhof/vncpwd](https://github.com/jeroennijhof/vncpwd). We just need to take the hex values and write them in binary format to a file that can be read by the decrypt tool.

![](/assets/images/htb-writeup-cascade/vncpasswd.png)

We'll use Crackmapexec again to check the credentials for user **s.smith**. We can see here that we have access to an **Audit$** share we couldn't previously access.

![](/assets/images/htb-writeup-cascade/smith.png)

That user is a member of the **Remote Management Users** group so we can log in remotely with WinRM.

![](/assets/images/htb-writeup-cascade/smith2.png)

## Finding the password for ArkSvc inside SQlite database

Inside the **Audit$** share we find an Audit database and a **CascAudit.exe** file.

![](/assets/images/htb-writeup-cascade/audit.png)

The executable is a .NET assembly (which means we can probably easily reverse it with DNSpy) and the DB file is an SQLite database.

![](/assets/images/htb-writeup-cascade/audit2.png)

To read the database file, we'll use the sqlite3 client then issue the `.tables` command to view the list of tables. The **Ldap** table contains a base64 value for what we can safely assume to be the **ArkSvc** account password.

![](/assets/images/htb-writeup-cascade/audit3.png)

Unfortunately the password appears to be encryped since we only get binary data after base64 decoding it.

![](/assets/images/htb-writeup-cascade/audit4.png)

With DNSpy it's easy to reverse the application **CascAudit.exe** that we found on the share. We can see here that it's using AES in CBS mode with an hardcoded Key and IV.

![](/assets/images/htb-writeup-cascade/casc1.png)

![](/assets/images/htb-writeup-cascade/casc2.png)

To decrypt the password from the SQlite database I'll use Cyberchef.

![](/assets/images/htb-writeup-cascade/cyberchef.png)

Finally, we'll use Crackmapexec again to verify that the credentials are valid:

![](/assets/images/htb-writeup-cascade/ark.png)

## Privesc

Arksvc can log in with WinRM and can see he's a member of the **AD Recycle Bin** group.

![](/assets/images/htb-writeup-cascade/privesc1.png)

This is pretty interesting because Active Directory keeps a copy of old deleted objects. Our user has access to view deleted objects. As mentionned in the meeting notes we found earlier on the **Data** share, there was at some point a **TempAdmin** user created for migration purposes. We can look for that old account with RSAT and by adding the `-IncludeDeletedObjects` flag to the command.

![](/assets/images/htb-writeup-cascade/privesc2.png)

Next, we'll look at the attributes of the deleted account and we see that it also has a **cascadeLegacyPwd** attribute like the first account we found on the machine.

![](/assets/images/htb-writeup-cascade/privesc3.png)

We'll decode the password and remembering the meeting notes, it says the TempAdmin password was the same as the regular admin password so we can just use Evil-WinRM to log in as Administrator and get the root flag.

![](/assets/images/htb-writeup-cascade/root.png)