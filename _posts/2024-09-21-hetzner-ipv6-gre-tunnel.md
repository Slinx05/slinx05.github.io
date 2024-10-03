---
title:  "Hetzner Cloud Networks IPv6"
date: 2024-09-21 12:00:00 +0200
categories: [Hetzner Cloud]
tags: [Hetzner, Ubuntu, GRE, Tunnel, IPv6, OPNsense]
description: |
  Mit diesem Workaround sind meine Server im Hetzer Cloud Netzwerk an einer OPNsense auch per IPv6 erreichbar.
image:
  path: /assets/img/header/ipv6.webp
  lqip: data:image/webp;base64,UklGRv4AAABXRUJQVlA4IPIAAABQBQCdASoUABQAPpFCm0olo6IhqAgAsBIJYwC7AYw6aPF1tAK1Z1Ua46B0DhSiDk/63gAA/u+h6lKHdxXJoKk5UGL7969a9BdkftO7rmx7A1LkjiIQw/lBTckTHWxVGoer+d6dVRJbIarW92s+hgzrTxdbx4hfodo+ju86yRHdFCH9q5rPA6e6vgAa5k2IMAuVencqAM0+Iz2gt/R+Qke7cUUlYepJ/69J982niKuKxgYcO5v3NlRMFFv2Lbi6Do9+TWHPS4RKYcT/EhZ8ko03XRvIHGEkoYLubBq0FbLNFopigUS3rcvuov8fsnIE/z8AAA==
  alt: ChatGTPs Vorstellung von einer Firewall und einem Server mit IPv6.
---

## Einleitung

Im Hetzner Netzwerk für Cloud Server wird __nur IPv4__ unterstützt und __kein IPv6__ (Stand: September 2024).

Meine Cloud Server sind nicht direkt mit dem öffentlichen Netzwerk verbunden, sondern über das Hetzner Netzwerk mit einer [OPNsense][4]. Damit meine Server hinter der OPNsense trotzdem via IPv6 erreichbar sind, nutze ich als Workaround einen [GRE Tunnel][2].

OPNsense Version: `24.7.4_1`  
Ubuntu Version:   `24.04.1`

Übersicht der Config-Schritte:

- Hetzner Netzwerk erstellen
- OPNsense `WAN` & `Hetzner (LAN)` Interface prüfen
- OPNsense GRE Interface `gre0` erstellen, zuweisen & aktivieren
- OPNsense Firewall Gruppe `DMZv6Pub` erstellen 
- OPNsense Interface `gre0` zur Gruppe `DMZv6Pub` hinzufügen
- OPNsense Firewall Regeln für `DMZv4Pirv`, `DMZv6Pub` erstellen
- Server GRE Tunnel `tun0` konfigurieren

## Voraussetzung

Mein Workaround setzt voraus, dass die OPNsense bereits betriebsbereit und via IPv4 erreichbar ist.  

## Topologie

![Topologie](/assets/img/Hetzner-GRE-IPv6-Topologie.svg){: w="1000" }
_Vereinfachte Darstellung des Aufbaus_

## Hetzner

Die Einrichtung des Hetzner Netzwerks ist in diesem [Tutorial][1] beschrieben.

  > Achte darauf, dass im Hetzner Netzwerk eine Default Route zur OPNsense eingerichtet ist.  
  > Ziel: `0.0.0.0/0`, Gateway: `10.80.0.3`
  {: .prompt-warning }

## OPNsense

### WAN Interface prüfen

Hetzner vergibt pro Cloud Server 1 kostenloses IPv6 Prefix mit einer `/64` Maske.  
Um diesen Prefix auch auf Servern hinter der OPNsense nutzen zu können, vergibt man dem OPNsense WAN Interface eine `::1/128` Adresse.

Menü: __[Interfaces / WAN]__

- Stelle sicher, dass dein WAN Interface die korrekte Adresse & Maske eingestellt hat:

  ```note
  WAN:
  Enable                  = true
  IPv6 Configuration Type = Static IPv6
  IPv6 Address            = 2a01::1/128
  ```

  > Ersetze den Prefix `2a01::` mit dem dir von Hetzner zugeteilten Prefix!
  {: .prompt-warning }

### Hetzner Interface prüfen

Das Interface welches mit dem Hetzner Netzwerk verbunden ist, habe ich `DMZv4Priv` benannt.  

Menü: __[Interfaces / DMZv4Priv]__

- Stelle sicher, dass dein Hetzner Interface eine Adresse via DHCP bezieht:

  ```note
  DMZv4Priv:
  Enable                  = true
  IPv4 Configuration Type = DHCP
  ```

### GRE Interface erstellen

Das Interface `DMZv4Priv` nutze ich für den GRE Tunnel, dort werden die Pakete gesendet/empfangen.

Menü: __[Interfaces / Other Types / GRE]__

- Erstelle das GRE Interface:

  ```note
  gre0:
  Local Address         = DMZv4Priv (10.80.0.3)
  Remote Adress         = 10.80.0.4 (Server IP / Tunnel Endpoint)
  Tunnel local address  = 2a01::3
  Tunnel remote address = 2a01::4
  Tunnel netmask/prefix = 127
  ```

### GRE Interface zuweisen

Damit das `gre0` Interface genutzt werden kann, muss dieses zugewiesen und aktiviert werden.

Menü: __[Interfaces / Assignments]__

- Ordne das Interface zu:

  ```note
  Device      = gre0
  Description = Tun0
  ```

Menü: __[Interfaces / Tun0]__

- Aktiviere das Interface:

  ```note
  Enable:  [x] Enable Interface
  ```

### Firewall Gruppe erstellen

Menü: __[Firewall / Groups]__

In der Gruppe `DMZv6Pub` werden später die Firewall Regeln erstellt.
Sollten zukünftig weitere GRE Tunnel hinzugefügt werden, muss kein neues Regelwerk geschrieben werden.
Das neue GRE Interface wird zur Gruppe hinzugefügt und somit wird auch das vorhandene Regelwerk angewandt.

- Erstelle die Gruppe und füge das Interface hinzu:

  ```note
  Name    = DMZv6Pub
  Members = Tun0
  ```

### Firewall Regelwerk

Menü: __[Firewall / Rules / DMZv4Priv]__

Dieses Regelwerk steuert die IPv4 Kommunikation deiner Server.

-  Erstelle die Regel, damit der GRE Tunnel erlaubt ist:

| Action | Protocol | Source | Port | Destination       | Port | Gateway | Description        |
| ------ | -------- | ------ | ---- | ----------------- | ---- | ------- | ------------------ |
| Allow  | IPv4 GRE | *      | *    | DMZv4Priv address | *    | *       | GRE Tunnel Allowed |

Menü: __[Firewall / Rules / DMZv6Pub]__

Dieses Regelwerk steuert die IPv6 Kommunikation deiner Server.

- Erstelle die Regel, damit ein Ping in Richtung Internet erlaubt ist:

| Action | Protocol       | Source | Port | Destination | Port | Gateway | Description  |
| ------ | -------------- | ------ | ---- | ----------- | ---- | ------- | ------------ |
| Allow  | IPv6 IPV6-ICMP | *      | *    | *           | *    | *       | Ping Allowed |

## Server

### Interface Config

Zur Konfiguration des Server Interfaces nutze ich [Netplan][3].  
Das Tool ist ein Renderer zur Abstraktion der Netzwerkkonfiguration.

- Erstelle die beiden Netplan Konfigurationsdateien und passe diese auf deine Parameter an:

  ```yaml
  network:
    version: 2
    ethernets:
      ens10:                # <- dein Interface Name angeben
        dhcp4: true
        nameservers:
          addresses:
            - 1.1.1.1       # <- DNS IP
        routes:
          - to: default
            via: 10.80.0.1  # <- IP des Hetzner "Switches"
  ```
  {: file='/etc/netplan/00-default-interface.yaml'}

  > Nutze den [MTU Calculator][5] um für deine Umgebung die korrekte MTU zu ermitteln.  
  {: .prompt-tip }

  ```yaml
  network:
    version: 2
    tunnels:
      tun0:
        mode: gre
        mtu: "1426"         # <- 1450 (Hetzner Network) - 20 (IPv4 Header) - 4 (GRE Header)
        optional: true      # <- damit der Server beim booten nicht auf dieses Interface wartet
        remote: 10.80.0.3   # <- OPNsense IPv4 Adresse (DMZv4Priv Interface)
        local: 10.80.0.4    # <- Server IPv4 Adresse (wird per DHCP von Hetzner vergeben)
        addresses:
          - "2a01::4/127"   # <- dein öffentlicher IPv6 Prefix bzw. die IPv6 die dein Server bekommen soll
        routes:
          - to: default
            via: "2a01::3"  # <- OPNsense IPv6 Adresse (DMZv6Pub Interface)
  ```
  {: file='/etc/netplan/01-tunnels.yaml'}

- Führe den Befehl aus, um die Netzwerk Config erstellen zu lassen:

  ```bash
  netplan generate
  ```
  {: .nolineno }

- Führe den Befehl aus, um die Netzwerk Config zu übernehmen:

  ```bash
  netplan try -timeout 30
  ```
  {: .nolineno }

  > Ohne anschließende Bestätigung des Befehls, wird die Netzwerk Config zurück gerollt.  
  > Sehr hilfreich, falls die Netzwerkverbindung durch einen Konfigurationsfehler unterbrochen wird.
  {: .prompt-info }

- Nach dem die Konfiguration übernommen wurde, prüfe ob die Adressen auf dem Interface `tun0` korrekt sind:

  ```bash
  user@server:~$ ip address show dev tun0
  
  tun0@NONE: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1426 qdisc noqueue state UNKNOWN group default qlen 1000
      link/gre 10.80.0.4 peer 10.80.0.3
      inet6 2a01::4/127 scope global
         valid_lft forever preferred_lft forever
  ```
  {: .nolineno }

### Funktionstest

Ein erster Test mit `ping` zeigt, der Server kann nun via IPv6 kommunizieren.

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
{: .nolineno }

## Zusammenfassung

Solltest du weitere Server in der Hetzner Cloud bereitstellen, musst du für jeden Server einen neuen GRE Tunnel konfigurieren.

Es gibt noch die Möglichkeit VXLAN zu nutzen, jedoch war mir der Config-Overhead zu hoch. Da im Hetzner Netzwerk kein Multicast unterstützt wird, muss für jeden Server ein VXLAN angelegt werden und dann auf eine Bridge gelegt werden.

Für mich hat sich der GRE Tunnel Workaround als "einfachste" IPv6 Lösung herausgestellt.

[1]: https://community.hetzner.com/tutorials/hcloud-networks-basic "Hetzner Cloud: Networks"
[2]: https://www.cloudflare.com/de-de/learning/network-layer/what-is-gre-tunneling/ "What is GRE tunneling"
[3]: https://netplan.readthedocs.io/en/stable/ "Netplan Documentation"
[4]: https://docs.opnsense.org/manual/other-interfaces.html#gre "OPNsense Documentation"
[5]: https://baturin.org/tools/encapcalc/ "Visual packet size calculator"
