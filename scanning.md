Types of Scans
- ping
- traceroute
- nmap
- nc
- wget / curl
- snmp-check
- rpcinfo

MAKE SURE YOUR SCANS ARE QUIET!!!!

Ping:
Ping can tell us what the OS could potentially be.
TTL Values:
	- 64: Unix
	- 128: Windows
	- 255: Networking Devices/Solaris Systems

Nmap:
 nmap {scan type} {options} {target speficiation}
nmap -sS 10.50.23.0-254 -p 22
nmap 10.50.23.0/24 -p U:53,111,T:21-25
Common Options:
	-p (port range): Scan specific ports
	-sS : SYN Stealth Scan : Sends SYN packet to each port and waits for a response. Relatively quiet.
	-sT : TCP Connect Scan : More aggressive. Establishes full TCP connection to each port.
	-sU : UDP Scan : 
Research relevant NSE Scripts

Netcat:
nc is another simple program, used for legitimate and illegitimate purposes. It can be used to
scan ports, transfer files, or create a simplistic backdoor.

Banner Grab Syntax: nc {options} {hostname/IP-goes-here} {port-range-here}
-z : Port scanning mode i.e. zero I/O mode.
-v : Be verbose [use twice -vv to be more verbose].
-n : Use numeric-only IP addresses i.e. do not use DNS to resolve ip addresses.
-w 1 : Set time out value to 1.

Examples:
nc -z -v secretserver.military.krasnovia 1-1023
nc -zvn 192.168.0.29 22

Proxychains Scanning:
#Scan 192.168.0.1/24 network for ssh
//SET UP TUNNEL
ssh -S /tmp/T1(whatever tgt scanning from) dummy -O forward -D 9050

//PORT SCAN FOR SSH
proxychains -q nmap -n -Pn -sT -T3 -p 22 192.168.0.10,23,27
(-iL to reference target file instead of IP)
//BANNER GRAB
proxychains nmap -sV -n -Pn -v -sT -T3 -p ##,## <ip.addr>
