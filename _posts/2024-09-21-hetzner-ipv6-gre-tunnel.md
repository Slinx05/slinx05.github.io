---
title:  Hetzner Network IPv6 [GRE Tunnel]
date: 2024-09-21 12:00:00 +0200
categories: [🔥OPNsense, 🛜IPv6]
tags: [Hetzner, Ubuntu, GRE, Tunnel]
description: Im Hetzner Netzwerk für Cloud Server wird nur IPv4 Kommunikation unterstützt, keine IPv6 Kommunikation. Damit meine Server trotzdem via IPv6 erreichbar sind, nutze ich als Workaround einen GRE Tunnel.
---

Im [Hetzner Netzwerk][1] für Cloud Server wird nur IPv4 Kommunikation unterstützt, __keine__ IPv6 Kommunikation (Stand: September 2024).

Meine Cloud Server sind mit dem Hetzner Netzwerk an einer [OPNsense][4] verbunden.  
Damit meine Server trotzdem via IPv6 erreichbar sind, nutze ich als Workaround einen [GRE Tunnel][2].

OPNsense Version: `24.7.4_1`  
Ubuntu Version:   `24.04.1`

Übersicht der Config-Schritte:

1. WAN IPv6 Adresse prüfen
2. GRE Interface `gre0` erstellen
3. GRE Interface `gre0` zuweisen & aktivieren
4. Firewall Gruppe `DMZv6Pub` erstellen / Member hinzufügen
5. Firewall Regeln für `DMZv4Pirv`, `DMZv6Pub` erstellen
6. GRE Tunnel am Server konfigurieren

## OPNsense

### WAN Interface

Menü: __[Interfaces / WAN]__

Hetzner vergibt pro Server 1 Subnet (/64 IPv6 Prefix).  
Deshalb vergibt man dem WAN Interface eine /128 Maske und kann die gleiche IP Range auf anderen Interfaces nutzen.
Somit kann man Public IPv6 Adressen aus der gleichen Range auch "hinter" dem WAN Interface nutzen z.B. für die Server.

```notice
WAN:
IPv6 Address    = 2a01::1/128
Enable          = true
```

### GRE Interface erstellen

Menü: __[Interfaces / Other Types / GRE]__

Das Interface welches mit dem Hetzner Netzwerk verbunden ist, habe ich `DMZv4Priv` benannt.  
Das Interface `DMZv4Priv` nutze ich für den GRE Tunnel, dort werden die Pakete gesendet/empfangen.

```notice
gre0:
Local Address           = DMZv4Priv (10.80.0.3)
Remote Adress           = 10.80.0.4 (Tunnel Endpoint Server A)
Tunnel local address    = 2a01::2
Tunnel remote address   = 2a01::3
Tunnel netmask / prefix = 127
```

### GRE Interface zuweisen

Menü: __[Interfaces / Assignments]__

Das Interface `gre0` zuweisen und aktivieren.

### Firewall Gruppe erstellen

Menü: __[Firewall / Groups]__

In der Gruppe `DMZv6Pub` werden später die Firewall Regeln erstellt.
Sollten zukünftig weitere GRE Tunnel hinzugefügt werden, muss kein neues Regelwerk geschrieben werden.
Das neue GRE Interface wird zur Gruppe hinzugefügt und somit wird auch das vorhandene Regelwerk angewandt.

```notice
Name                    = DMZv6Pub
Members                 = gre0
```

### Firewall Regelwerk

Menü: __[Firewall / Rules]__

`DMZv4Priv`:  
Über dieses Regelwerk wird gesteuert, welche IPv4 Kommunikation von deinen Servern aus erlaubt ist.

```notice
Allow IPv4 GRE Any -> DMZv4Priv Address | Description: GRE Tunnel Allowed
```

`DMZv6Pub`:  
Über dieses Regelwerk wird gesteuert, welche IPv6 Kommunikation von deinen Servern aus erlaubt ist.

```notice
Allow IPv6 IPV6-ICMP Any -> Any | Description: Ping Allowed
```

## Server

### Netplan Config

[Netplan][3] ist ein Renderer zur Abstraktion der Netzwerkkonfiguration.

`netplan generate` - Erstellt die Backend-Config anhand deiner YAML-Config  
`netplan try -timeout 30` - Aktiviert die Config und macht einen Rollback, falls keine Bestätigung erfolgt  
`etc/netplan/90-tunnels.yaml` - Die YAML-Config Datei

```yaml
# Uncomment and configure to activate GRE Tunnel to opnsense hetzner
network:
  version: 2
  tunnels:
    tun0:
      mode: gre
      # https://baturin.org/tools/encapcalc/
      mtu: "1426" # = 1450 (Hetzner Network) - 20 (IPv4 Header) - 4 (GRE Header)
      optional: true
      remote: 10.80.0.3
      local: 10.80.0.4
      addresses:
        - "2a01::3/127"
      routes:
        - to: default
          via: "2a01::2"
```

Nach dem die Config aktiviert wurde, kann das Interface überprüft werden:

```bash
user@server:~$ ip address show dev tun0

tun0@NONE: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1426 qdisc noqueue state UNKNOWN group default qlen 1000
    link/gre 10.80.0.4 peer 10.80.0.3
    inet6 2a01::3/127 scope global
       valid_lft forever preferred_lft forever
```

### Funktionstest

Der Server kann nun via IPv6 kommunizieren.

```bash
user@server:~$ ping -6 google.com
PING google.com (2a00:1450:4001:82a::200e) 56 data bytes
64 bytes from fra24s07-in-x0e.1e100.net (2a00:1450:4001:82a::200e): icmp_seq=1 ttl=56 time=4.16 ms
64 bytes from fra24s07-in-x0e.1e100.net (2a00:1450:4001:82a::200e): icmp_seq=2 ttl=56 time=4.31 ms
64 bytes from fra24s07-in-x0e.1e100.net (2a00:1450:4001:82a::200e): icmp_seq=3 ttl=56 time=4.26 ms
64 bytes from fra24s07-in-x0e.1e100.net (2a00:1450:4001:82a::200e): icmp_seq=4 ttl=56 time=4.39 ms
^C
--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 4.162/4.279/4.387/0.081 ms
```

## Zusammenfassung

Solltest du weitere Server deployen musst du nur die Config-Schritte: __2,3,4,6__ durchführen.

Es gibt noch die Möglichkeit VXLAN zu nutzen, jedoch war mir der Config-Overhead zu hoch. Da im Hetzner Netzwerk kein Multicast unterstützt wird, muss für jeden Server ein VXLAN angelegt werden und dann auf eine Bridge gelegt werden.

Für mich hat sich der GRE Tunnel Workaround als "einfachste" IPv6 Lösung herausgestellt.

[1]: https://community.hetzner.com/tutorials/hcloud-networks-basic "Hetzner Cloud: Networks"
[2]: https://www.cloudflare.com/de-de/learning/network-layer/what-is-gre-tunneling/ "What is GRE tunneling"
[3]: https://netplan.readthedocs.io/en/stable/ "Netplan Documentation"
[4]: https://docs.opnsense.org/manual/other-interfaces.html#gre "OPNsense Documentation"
