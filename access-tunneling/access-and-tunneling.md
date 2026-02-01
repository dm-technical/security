# SSH Tunneling and Networking Notes

## TYPES OF TARGETS

- **Ops Station**
  - We own it; fully trusted - no vetting required
  - Where you should be running all commands from

- **Listening Post (LP)**
  - Treated as an extension of your Ops Station but on the open web, so vet it first
  - Connection and scanning and commands may be run from here if required, safely

- **Redirector/External Router**
  - Touches open internet
  - *May be first step into a target network*
  - *May be dual homed or NAT'ed/PAT'ed*

- **Internal Device**
  - Regardless of IP address, these are hosts that are internal to the network

## TYPES OF SHELLS

### Unix/Linux Shells
- Bourne Again Shell (bash)
- Bourne Shell (sh)
- Korn Shell (ksh)
- C Shell (csh)

### Windows Shells
- cmd.exe
- COMMAND.COM
- Windows PowerShell
- Recovery Console

## SSH - BASIC SYNTAX

### Bare Bones SSH Command
```bash
ssh -p 2022 root@10.20.30.40
```

**SSH's Home** - Where this ssh instance will be executed
1. Calls ssh command binary to execute on the current host

**Present Connection** - Where we are pointing our connection attempt right now
1. **Username** - What user do you intend to authenticate as when you land on target? Here, that's `root`
2. **IP** - Where is our connection attempt going to? In this example, we are sending our connection to `10.20.30.40`
3. **Port** - The specific port listening for an ssh connection. Here, ssh is listening on port `2022`

> **NOTE:** THIS IS LOUD! WE WILL USE MASTER SOCKET TUNNELING/MULTIPLEXING

## SSH - BASIC MULTIPLEXED SYNTAX

### Basic Multiplexed SSH Command
```bash
ssh -M -S /tmp/T1 -p 2022 root@10.20.30.40
```

**Here** - The host where this ssh instance will be executed
1. Calls ssh command binary to execute on the current host
2. **Multiplex Information** - `-M` makes a new socket and `-S` saves the socket information for future use

**Present Connection** - Where we are pointing our connection attempt right now
1. **Username** - What user do you intend to authenticate as when you land on target? Here, that's `root`
2. **IP** - Where is our connection attempt going to? In this example, we are sending our connection to `10.20.30.40`
3. **Port** - The specific port listening for an ssh connection. Here, ssh is listening on port `2022`

## SSH TUNNEL SYNTAX

Every ssh tunnel line has **5 parts**, which always come in the same order:
```
-L 127.0.0.1:2222:192.168.0.2:2202
```

1. **The "direction" or "listening" end of the tunnel** - `-L` or `-R`, indicating whether the packet initiating the connection will be received on your (L)ocal host or the (R)emote target you are connecting to, followed by...

2. **The IP of the listening host** - The very first host to receive the connection request packet, which controls where traffic will "enter" the ssh tunnel (LOCAL IP), followed by...

3. **The open listening port on the listening host** - Where you expect a connection. This can usually be any number you like so long as that port is not already bound by another process. However, some devices may have restrictions on available ports (LOCAL PORT), followed by...

4. **The receiving IP** - The IP of the remote host you want the connection packet to reach once it exits its ssh tunnel. This is usually, but not always, the target you are attempting to log into. Note this is not the IP of any target currently involved in your ssh connection. This is where you want to connect to next (REMOTE IP), followed by...

5. **The receiving port** - The receiving port is not created in your ssh connection, and the receiving IP needs to already be listening there via some other process or service (REMOTE PORT)

### Basic SSH Command with -L Tunnel
```bash
ssh -S /tmp/T1 dummy -O forward -L 127.0.0.1:2222:192.168.0.2:2202
```

**SSH's Home** - Where this ssh instance will be executed
1. Calls ssh command binary to execute on the current host
2. **Multiplex Information** - Define the connection information from our `-S` saved socket

**Present Connection** - Where we are pointing our connection attempt right now
1. **Connection Information** - Because we are using the existing session context stored in `/tmp/T1` we don't need to restate that information here. However, ssh requires we put SOMETHING here, so we'll put `dummy` so if something goes wrong, it's unable to actually connect to anything

**Next Connection** - Where am I going from here after I'm done on this target?
1. **Options** - What options do we want to modify about our existing ssh session. In this case, we want to add forwarding
2. **Tunnel Syntax** - My tunnel information to connect me to the next target. Includes direction (`-L`), tunnel entrance IP (`127.0.0.1`), tunnel entrance port (`2222`), next hop IP (`192.168.0.2`), and next hop port (`22`)

## BASIC -R SYNTAX

The remote tunnel pieces are just the same. Like the `-L` tunnel, the listening tunnel entrance comes first, and the host that will likely actually process the connection request comes last.
```
-R 192.168.0.4:12345:127.0.0.1:5555
```

1. This tunnel opens remotely, so we put the remote information first...

2. **The IP and port of our remote target** serving as the entrance to our tunnel. This is where the beacon is currently sending its connection packets to. We need to configure our remote tunnel to catch it. This tunnel will open a listener on the target you are currently connecting to, the one indicated in your `-S /tmp/(socket)` line

3. **The receiving IP and port** for the host that will actually process this connection request. This is typically, but does not have to be, your local host. You will need to set up a listener on your local host, typically netcat, to receive and process this connection request

> **Note 1:** With both the `-L` and `-R`, the tunnel entrance socket always comes first
> 
> **Note 2:** With both the `-L` and `-R`, you typically have no control over the remote host information, but can select whatever port you choose for the local side of your tunnel

### SSH Command with -R Tunnel
```bash
ssh -S /tmp/T4 -p 4444 student@127.0.0.1 -O forward -R 192.168.0.4:12345:127.0.0.1:5555
```

**SSH's Home** - Where this ssh instance will be executed
1. Calls ssh command binary to execute on the current host
2. **Multiplex Information** - `-S` accesses the stored socket when we connected to T4

**Present Connection** - Where we are pointing our connection attempt right now
1. **Port** - The specific port listening for an ssh connection
2. **Username** - What user do you intend to authenticate as when you land on target?
3. **IP** - Where are we sending our connection request to right now?

**Future Connection** - Where are we going from here?
1. **Session Options** - Adding forwarding to the session
2. **Tunnel syntax** - My tunnel information to connect me to the next target. Includes direction, tunnel entrance IP, tunnel entrance port, next hop IP, and next hop port. The default IP for a `-R` tunnel's entrance is `0.0.0.0` or all interfaces on that target
