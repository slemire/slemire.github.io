---
layout: single
title: EvilConneck CTF Challenge
excerpt: "TBA"
date: 2020-02-01
classes: wide
header:
  teaser: /assets/images/bbsctf-evilconneck/evilconneck.png
  teaser_home_page: true
categories:
  - ctf
  - infosec
tags:
  - websockets
---

![](/assets/images/bbsctf-evilconneck/evilconneck.png)

![](/assets/images/bbsctf-evilconneck/challenge.png)

![](/assets/images/bbsctf-evilconneck/objectives.png)

We heard about an evil organization - EvilConneck - that hacks for the bad reasons. Your role today is to infiltrate their system! Our intelligence knows that they are using a new-ish technology but their website seems static and without any security issues! Our intelligence officers also know that they are prone to make errors and not be the best at securing their network stats. We are then expecting you to succeed!

URL: http://18.222.220.65/evilconneck/

![](/assets/images/bbsctf-evilconneck/website1.png)

![](/assets/images/bbsctf-evilconneck/website2.png)

Checking the HTML source code, we can see that there are some comments about debug mode being turned off.

![](/assets/images/bbsctf-evilconneck/debug.png)

## Debug mode enabled

After enabling the debug mode we can see additional javascript being inserted in the page:

![](/assets/images/bbsctf-evilconneck/websocket1.png)

The code is supposed to establish a websocket connection but I'm getting a connection error message when looking at my Firefox console:

![](/assets/images/bbsctf-evilconneck/websocket2.png)

I added `evilconnect` to my local hostfile, resolving it to `18.222.220.65` and I was able to successfully connect after.

Within Burp I can see my client is sending the `uptime` string followed by some base64 encoded data.

![](/assets/images/bbsctf-evilconneck/websocket3.png)

And the response is always `49170.12` and never changes

![](/assets/images/bbsctf-evilconneck/websocket4.png)

## Figuring out the HMAC secret key

The first thing I did next was try to figure what that base64 content is all about and it just decodes to meaningless bytes. Interestingly, the length of the output is 32 bytes so this could be a a hash of some sort.

![](/assets/images/bbsctf-evilconneck/sig1.png)

I tried changing the `uptime` message to something or the content of the base64 and I got the following signature failure message everytime: `Signature failed! - Expected: 'b64(b85(passwd)),base64(hmac256)'`

So it's probably safe to assume at this point that `uptime` is the message for which the signature is calculated. Based on the error message, we know that it's using HMAC with SHA256 for the hash function and that HMAC secret is base85 encoded, then base64 encoded.

To test this theory, I used Python to try to generate the HMAC for the `uptime` message using a wordlist so I can bruteforce the HMAC secret key. At first, I used the following script but I wasn't able to find a match with any wordlist I used, such as `rockyou.txt`:

```python
#!/usr/bin/env python3

import base64
import hashlib, hmac
import progressbar
import sys

c = b"Ji/HQqLPH5KpqzZcYFXRdEHnyn2VI1fqU824IzTzAKs="

progressbar.streams.flush()

with open(sys.argv[1], encoding = "ISO-8859-1") as f:
    passwords = f.read().splitlines()

message = sys.argv[2]

with progressbar.ProgressBar(max_value=len(passwords)) as bar:
    for i, p in enumerate(passwords):        
        secret = base64.b64encode(base64.b85encode(p.strip().encode('utf-8')))
        m = hmac.new(secret, digestmod=hashlib.sha256)
        m.update(message.strip().encode('utf-8'))
        m_b64 = base64.b64encode(m.digest())        
        if c in m_b64:
            print(f"Found password: {p}")
            print(m_b64)
            sys.exit(0)
        bar.update(i)
```

I just enabled padding by adding the `pad=True` statement here:

```python
secret = base64.b64encode(base64.b85encode(p.strip().encode('utf-8'), pad=True))
```

Well, it turns out that secret is a simple one afterall: `secret`

![](/assets/images/bbsctf-evilconneck/secret.png)

## Getting access with websockets

```python3
#!/usr/bin/env python3

import asyncio
import base64
import hashlib, hmac
import readline
import sys
import websockets

secret = b'secret'
secret = base64.b64encode(base64.b85encode(secret, pad=True))

async def hello():
    uri = "ws://evilconneck:64480"
    async with websockets.connect(uri, origin='http://evilconneck') as websocket:
        cmd = input('> ')
        m = hmac.new(secret, digestmod=hashlib.sha256)
        m.update(cmd.encode('utf-8'))
        m_b64 = base64.b64encode(m.digest())        
        x = f"{cmd},{m_b64.decode('utf-8')}"
        await websocket.send(x)        
        r = await websocket.recv()
        print(f"{r.decode('utf-8')}")

while True:
    asyncio.get_event_loop().run_until_complete(hello())
```

Once I found the `help` command, I was quickly able to get the flag. I just needed to issue `hello` command as instructed then `getflag` spit out the flag.

![](/assets/images/bbsctf-evilconneck/flag.png)