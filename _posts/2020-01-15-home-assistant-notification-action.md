---
title:  Home Assistant - iOS Notification & Action Button
date: 2020-01-15 18:00:00 +0200
categories: [Smart Home, Homeassistant]
tags: [Smarthome, Homeassistant, iPhone, Notification]
description: |
  Anleitung zur Einrichtung von iOS Push Notification.
image:
  path: /assets/img/header/smarthome_phone.webp
  lqip: data:image/webp;base64,UklGRqgAAABXRUJQVlA4IJwAAACQBACdASoUABQAPpE6mUgloyKhKA1QsBIJZQDImYu4bvtSPuctp9KSb2RNgQAA/vYSqcN1z12g98YWB9u6Hi41852fEbgE+UFGlp4jsoPthxiiqmOI0OYNFezgldmMbRnAiuHJdt73hed2V4T2Gxq1QxUYzV0ieQYj/FNJvA199eb83Jby7Tru6cS/ju56z1KHgTmI+B5yY665gAA=
---

## Einleitung

Ich besitze seit kurzem einen 3D Drucker - [Artillery Genius](https://youtu.be/koZo6GaNFi0). Ein ordentlicher Druck dauert mehrere Stunden und ist oftmals erst mitten in der Nacht fertiggestellt. Deshalb habe ich eine Automation in Home Assistant erstellt, welche mir per iOS Push Notification mitteilt, dass mein Druck fertig ist und per Default den Drucker nach 5 Minuten ausschaltet. Innerhalb dieser 5 Minuten habe ich die Möglichkeit den Ausschaltvorgang abzubrechen um z.B. einen weiteren Druck zu starten.

>**Achtung:** _Die Aktion des iOS Button funktioniert im LAN ohne weitere Einstellungen. Willst du die Aktion per Internet ausführen, musst du sicherstellen, dass Home Assistant über das Internet erreichbar ist!_
{: .prompt-warning }

![iOS Notification](/assets/img/homeassistant-ios-notification.webp){: w="400" }
![iOS Notification Button](/assets/img/homeassistant-ios-notification-button.webp){: w="400" }

## Tools & Devices

Editor: [Visual Studio Code](https://code.visualstudio.com/download)  
Smart Plug: [Gosund WLAN Steckdose](https://www.amazon.de/Steckdose-Stromverbrauch-Funktion-Fernsteurung-Netzwerk/dp/B07B911Y6V/ref=sr_1_5?__mk_de_DE=ÅMÅŽÕÑ&crid=10MOVZFNOBKV7&keywords=gosund+wlan+steckdose&qid=1579114863&sprefix=gosund%2Cinstant-video%2C151&sr=8-5) + [ESPHome Firmware](https://esphome.io)  
Controller: [Raspberry Pi4](https://www.amazon.de/LABISTS-Ultimatives-Aus-Schaltnetzteil-Kühlkörper-HDMI-Kabel/dp/B07YYWZDX7/ref=sr_1_6?__mk_de_DE=ÅMÅŽÕÑ&crid=3NNARRA6HD8JO&keywords=raspberry+pi+4&qid=1579115215&smid=A31LN8HLP979CO&sprefix=raspberry+p%2Caps%2C157&sr=8-6) + [Hassio](https://www.home-assistant.io/hassio/installation/)  
App: [Home Assistant Companion](https://companion.home-assistant.io)

## Allgemeine Config

In der Datei `configuration.yaml` wird der Button welcher auf dem iPhone erscheint erstellt.  
> _Wichtig ist hierbei eindeutige "identifier" Bezeichnungen zu nutzen!_
{: .prompt-info }

```yaml
ios:
  push:
    categories:
      - name: '3dprinter'
        identifier: '3dprinter'
        actions:
          - identifier: 'CANCEL_01'
            title: 'Nicht ausschalten'
            destructive: 'true'
```

## Input Boolean

Ich nutze für die Automation einen Input Boolean um den Zustand des iOS Buttons temporär zu speichern.
Dieser wird dann in der Automation als Bedingung abgefragt.

```yaml
input_boolean:
  ios_button_3dprinter:
    name: Status iOS Button
    initial: off
    icon: mdi:cellphone
```

## Automation 01

Der Zustand ob der Druck abgeschlossen ist erfolgt über den [Octoprint](https://www.home-assistant.io/integrations/octoprint/) Status.
Anschließend wird die Benachrichtigung an mein iPhone gesendet. Nach 5 Minuten wird geprüft, ob der iOS Button gedrückt wurde (Automation 02), falls nicht wird der Drucker ausgeschaltet.

```yaml
- id: '1578249490920'
  alias: '3D Print finished'
  description: 'turn printer off after 5min'
  trigger:
    - entity_id: sensor.octoprint_current_state
      for: '00:00:05'
      from: 'Printing'
      platform: state
      to: 'Operational'
  condition: []
  action:
    - service: notify.mobile_app_bens_iphone
      data:
        title: "3D-Druck fertig"
        message: "Gerät wird in 5min ausgeschaltet"
        data:
          push:
          #Verweis zum iOS Butten in der configuration.yaml
            category: '3dprinter'
    - delay: '00:05:00'
    - condition: state
      entity_id: input_boolean.ios_button_3dprinter
      state: 'off'
    - entity_id: switch.3d_printer
      service: switch.turn_off
```

## Automation 02

Die zweite Automation wird ausgelöst, wenn der iOS Button gedrückt wurde und der Input Boolean vermerkt den Zustand.
Da die Automation 01 nach 5 Minuten beendet ist, wird der Input Boolean nach 05:10 Minuten zurückgesetzt

```yaml
- id: '1578249490921'
  alias: '3D Print Push Action'
  description: 'turn 3d print automation off'
  trigger:
    platform: event
    event_type: ios.notification_action_fired
    event_data:
      actionName: CANCEL_01
  condition: []
  action:
    - service: input_boolean.turn_on
      entity_id: input_boolean.ios_button_3dprinter
    - delay: 00:05:10
    - service: input_boolean.turn_off
      entity_id: input_boolean.ios_button_3dprinter
```
