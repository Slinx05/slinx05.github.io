---
title:  "Proxmox VMs isolieren"
date: 2024-10-03 17:34:00 +0200
categories: [Proxmox, Network]
tags: [Proxmox, Network, Linux, Bridge]
description: |
  Mit der Hilfe von einer Linux Bridge Option können VMs voneinander isoliert werden.
image:
  path: /assets/img/header/security.webp
  lqip: data:image/webp;base64,UklGRvAAAABXRUJQVlA4IOQAAABwBQCdASoUABQAPpFAm0olo6IhqAgAsBIJQBYgIZjPBMxBYh8swGKYyI/ukmzchE2snYYAAP70n6llEsweXwUpK5eM8NesRxrQ8ZN3N0rDuxQGWn1xumV3g78H9VZPLshxMXdLoapakXCeHpPD2ieZyzECQcP3dba9PM5ciMht9Q+3EdtkS6+iFtc4BX4cs3xg/N1Gev4bJroqhV6C91nhNBKzGiQuJOEWtWjUPRb58/zxjf5ZLGL6Jy0t+H8lvGwErenRoqRj64YAh1ssqnPqs66wirdvUPbufwzMXMVyjo2WAAA=
---

## Einleitung

Auf meinem Proxmox Server gibt es mehrere VMs die ich in der __[Zone DMZ][4]__ habe.  
Für diese Zone habe ich auf dem Proxmox Host die Linux Bridge `vmbr4010`angelegt.  
Per Default kann jede VM in der dieser Bridge ohne Gateway miteinander kommunizieren.  
Um diese Kommunikation zu unterbinden gibt es die Linux Bridge Option `BR_ISOLATED`

Proxmox Version: `8.2.7`

## Überblick

![Overview of bridge isolation](/assets/img/bridge_isolation_overview.webp){: w="1000" }
_Erstellt von [B. Jesuiter©][1]_

## Bridge Interfaces

Zeigt alle Bridges und deren Interfaces an:

  ```bash
  brctl show
  ```
  {: .nolineno }

Hier meine Bridge `vmbr4010` mit den Interfaces von `tap111i0 = VM111` und `tap420i0 = VM420`, diese Interfaces sollen nicht miteinander kommunizieren dürfen:

  ```bash
  brctl show vmbr4010
  
  bridge name     bridge id               STP enabled     interfaces
  vmbr4010        8000.1c697a69f346       no              eno1.4010
                                                          fwpr401p0
                                                          tap111i0
                                                          tap420i0
  ```
  {: .nolineno }

## VM Interfaces isolieren

Zum unterbinden der Kommunikation muss die Option auf den VM Interfaces gesetzt werden:

  ```bash
  bridge link set dev tap111i0 isolated on
  bridge link set dev tap420i0 isolated on
  ```
  {: .nolineno }

Damit lässt sich prüfen ob die Option `isolated on` auf dem VM Interface aktiv ist:

  ```bash
  bridge -d link show | grep -A1 "tap420i0"
  1877: tap420i0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 master vmbr4010 state forwarding priority 32 cost 2
      hairpin off guard off root_block off fastleave off learning on flood on mcast_flood on bcast_flood on mcast_router 1 mcast_to_unicast off neigh_suppress off vlan_tunnel off isolated on locked off
  ```
  {: .nolineno }

## Funktionstest

Ping Test mit den VMs:

```bash
# isolated off
VM420:~$ ping VM111
PING VM111 (VM111) 56(84) bytes of data.
64 bytes from VM111: icmp_seq=1 ttl=64 time=0.492 ms
64 bytes from VM111: icmp_seq=2 ttl=64 time=0.457 ms
64 bytes from VM111: icmp_seq=3 ttl=64 time=0.305 ms

# isolated on
VM420:~$ ping VM111
PING VM111 (VM111) 56(84) bytes of data.
^C
--- VM111 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2087ms
```
{: .nolineno }

## Zusammenfassung

Die Option `BR_ISOLATED` eignet sich sehr gut um in einer [DMZ][4] die VMs auf dem gleichen Host zu isolieren, so dass diese nur noch mit dem Gateway kommunizieren können. Sollte eine VM kompromittiert werden, kann diese innerhalb der Bridge auf keine VM zugreifen.

> Die Option ist im Proxmox WebUI noch nicht verfügbar, es gibt aber bereits einen [Patch][1] der leider noch nicht gemerged wurde.
> 
> ![Patched Proxmox Web UI](/assets/img/bridge_isolation_proxmox_webui.webp){: w="400" }
> _Vorschau des WebUIs, erstellt von [B. Jesuiter©][1]_
{: .prompt-info }

Weitere nützliche Infos die ich zu diesem Thema gefunden habe:

- [Proxmox Forum][2]
- [Linux Kernel support for port isolation][3]

[1]: https://bugzilla.proxmox.com/show_bug.cgi?id=4300 "Isolated option for new VM/CT Interface when attaching to bridge."
[2]: https://forum.proxmox.com/threads/port-isolation-private-vlan.111767/ "Proxmox Forum: Port Isolation/ Private VLAN"
[3]: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=7d850abd5f4edb1b1ca4b4141a4453305736f564 "Linux kernel bridge: add support for port isolation"
[4]: https://de.wikipedia.org/wiki/Demilitarisierte_Zone_(Informatik) "Demilitarisierte Zone"