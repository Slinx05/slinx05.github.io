---
title: Deckenventilator mit Sonoff iFan03 Steuerung
date: 2020-02-05 16:00:00 +0200
categories: [Smart Home, Tasmota]
tags: [Smarthome, Tasmota, Sonoff]
description: |
  Anleitung zur Integration des Ventilators in Home Assistant.
image:
  path: /assets/img/header/smarthome_fan.webp
  lqip: data:image/webp;base64,UklGRtYAAABXRUJQVlA4IMoAAADQBACdASoUABQAPpE+mEmloyIhKAqosBIJZQDA3dwLe5OYBD9o/ks9EZeBUrDmqAD+6yW4amVy6OjoeFfUBBaDfTr1OqbrX3g4vgTUkw93tUP8tDu7j9L3V8aQB+19j46tncCgkllk4RlQWHtN607NsbxB2NBZd6pvvKBGMMG9o5kK+w5ZJlE5kAKUtU6RN4dsXS5I/cupK1RoLknTOikGvF33tIdB+4qBI2NsFSHDHhVca2GSBqhHG2QMs3flLnTboQB2ETBBAAAA
---

In Vorbereitung auf die heißen Sommertage habe ich den Deckenventilator - [Westinghouse Bendan](https://www.amazon.de/dp/B002Y15CWO/ref=cm_sw_em_r_mt_dp_U_syVoEbBV1H1S0) fürs Schlafzimmer gekauft. Zur Ansteuerung nutze ich das [Sonoff iFan03](https://www.amazon.de/dp/B07TRTG8PS/ref=cm_sw_r_tw_dp_U_x_7NVoEb0HC0AWJ) Module. Somit kann der Ventilator in Abhängigkeit von z.B. Temperatur, Luftfeuchtigkeit oder Zeit geschaltet werden.

## Tools

Editor: [Visual Studio Code](https://code.visualstudio.com/download) mit [PlatformIO IDE](https://marketplace.visualstudio.com/items?itemName=platformio.platformio-ide)  
Tasmota Version: [8.1.0.3](https://github.com/arendst/Tasmota/tree/master)  
Flashing Programm: [Tasmotizer](https://github.com/tasmota/tasmotizer)  
Flashing Tool: [USB zu TTL-Konverter-Modul](https://www.amazon.de/USB-TTL-Konverter-Modul-mit-eingebautem-CP2102/dp/B00AFRXKFU/ref=sr_1_3?__mk_de_DE=%C3%85M%C3%85%C5%BD%C3%95%C3%91&keywords=USB+zu+TTL-Konverter-Modul+mit+eingebautem+in+CP2102&qid=1578948764&s=computers&sr=1-3)  
Kleinkram: [Jumperkabel](https://www.amazon.de/Female-Female-Male-Female-Male-Male-Steckbrücken-Drahtbrücken-bunt/dp/B01EV70C78/ref=sr_1_3?__mk_de_DE=ÅMÅŽÕÑ&crid=3D9JJ4C2W5VM4&keywords=jumper+kabel&qid=1579031684&sprefix=jumper%2Caps%2C150&sr=8-3)

## Tasmota flashen

> **Achtung:** _Niemals die 230V Versorgung nutzen um den Shelly zu flashen! Immer die 3.3V USB-TTL Konverter Versorgung nutzen._
{: .prompt-warning }

### Pinout

Pinout der Plantine (Rückseite) für den Anschluss der seriellen Schnittstelle.

![sonoff-ifan03-pcb](/assets/img/sonoff-ifan03.webp){: w="600" }
[Quelle](https://templates.blakadder.com/sonoff_ifan03.html)

### Tasmotizer

* Port auswählen
* Select image:  *Release* `tasmota.bin`
* Enable: Backup original firmware
* Enable: Erase before flashing
* Send config - Module: Sonoff iFan03, WLAN/MQTT: deine Einstellungen hinterlegen

![Tasmotizer](/assets/img/tasmotizer-menu-screen.webp)

### Anlernen der Fernbedinung

1. Nach dem Flashen das Sonoff iFan03 Module wieder mit dem Gehäuse sicher verschließen.  
2. Nun einen Taster der Fernbedinung gedrückt halten, während das Module an 230V eingeschaltet wird. 
3. Anschließend ist die Fernbedinung verbunden und die Relais können damit geschaltet werden.

## Sonoff iFan03 an den Ventilator anschließen

Das Kabel welches am Klemmblock des Decken-Montagesockels angeschlossen ist, habe ich abgeklemmt und mit Wago Klemmen am Sonoff iFan03 verbunden. Somit kann der Sonoff iFan03 direkt per Steckverbindung mit dem Ventilatormotor verbunden werden und es müssen keine neuen Steckverbindungen verbaut werden.

![sonoff-ifan03-connection](/assets/img/sonoff-ifan03-connect.webp){: w="600" }

> **Achtung:** _Keine Gewähr auf die Anschlusstabelle. Anschluss nur durch eine qualifizierte Person durchführen lassen!_
{: .prompt-warning }

| Klemmblock         | Sonoff Input | Sonoff Output | Westinghouse Bendan |
| ------------------ | ------------ | ------------- | ------------------- |
| L (braun)          | L (schwarz)  | FAN (schwarz) | Stecker (braun)     |
| N (blau)           | N (weiß)     | COM (weiß)    | Stecker (blau)      |
| -                  | -            | LIGHT (blau)  | Stecker (rot)       |
| Erdung (grün/gelb) | -            | -             | Erdung (grün/gelb)  |

Achte darauf, alle Kabel ordentlich und platzsparend zu verbauen, denn die Abdeckung des Decken-Montagesockels hat nicht viel Platz.

## Home Assistant Config

Mein MQTT Topic: `ventilator_01` muss durch dein Topic ersetzt werden!

### Allgemein

```yaml
homeassistant:
  customize: !include_dir_merge_named customize/
fan: !include_dir_merge_list fan/
light: !include_dir_merge_list light/
```
{: file='configuration.yaml'}

### Ventilator

{% raw %}
```yaml
- platform: mqtt  
  name: ventilator_01
  command_topic: "cmnd/ventilator_01/FanSpeed"
  speed_command_topic: "cmnd/ventilator_01/FanSpeed"    
  state_topic: "stat/ventilator_01/RESULT"
  speed_state_topic: "stat/ventilator_01/RESULT"
  state_value_template: >
    {% if value_json.FanSpeed is defined %}
      {% if value_json.FanSpeed == 0 -%}0{%- elif value_json.FanSpeed > 0 -%}ON{%- endif %}
    {% else %}
      {% if states.fan.ventilator_01.state == 'off' -%}0{%- elif states.fan.ventilator_01.state == 'on' -%}ON{%- endif %}
    {% endif %}
  speed_value_template: "{{ value_json.FanSpeed }}"
  availability_topic: tele/ventilator_01/LWT
  payload_off: "0"
  payload_on: "ON"
  payload_low_speed: "1"
  payload_medium_speed: "2"
  payload_high_speed: "3"
  payload_available: Online
  payload_not_available: Offline
  qos: 1
  retain: false
  speeds:
    - off
    - low
    - medium
    - high
```
{: file='fan/ventilator01.yaml'}
{% endraw %}

### Lampe

```yaml
- platform: mqtt
  name: ventilator_01
  state_topic: "stat/ventilator_01/RESULT"
  value_template: "{{ value_json.POWER1 }}"
  command_topic: "cmnd/ventilator_01/POWER1"
  availability_topic: "tele/ventilator_01/LWT"
  payload_on: "ON"
  payload_off: "OFF"
  payload_available: "Online"
  payload_not_available: "Offline"
  retain: false
  qos: 1
```
{: file='light/ventilator01.yaml'}

### Customize

```yaml
fan.ventilator_01:
  friendly_name: Deckenventilator
light.ventilator_01:
  friendly_name: Schlafzimmerlampe
  icon: mdi:ceiling-light
```
{: file='customize/ventilator01.yaml'}
