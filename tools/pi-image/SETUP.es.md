# Cómo montar una sonda de ThreadMapper en una Raspberry Pi

Paso a paso, desde una mesa vacía hasta datos Thread medidos en la app.

Reserva una tarde. La mayor parte es esperar descargas y una compilación de unos 20 minutos.

---

## Lee esto antes de comprar nada

Hay dos cosas que deciden si esto merece la pena para *tu* instalación. Las dos son fáciles de pasar por alto hasta que llegan las piezas.

### 1. Una Raspberry Pi no puede hacer Thread por sí sola

Una Raspberry Pi no lleva radio 802.15.4. El Wi-Fi y el Bluetooth son radios distintas y no saben hablar Thread. **Necesitas un adaptador USB**, y tiene que llevar firmware RCP, que no es el que traen de fábrica estos adaptadores.

### 2. Unirse a *tu* red Thread es la parte difícil

Un router de borde que forma su propia red nueva se quedará ahí sin ver nada más que a sí mismo. Tus dispositivos reales están en la red que creó tu HomePod, tu Apple TV o tu hub Nest, y para observarlos la sonda tiene que **unirse a esa red**, lo que significa conseguir sus credenciales (el Active Operational Dataset).

| Tu instalación | ¿Puede la sonda unirse a tu red real? |
|---|---|
| Usas **Home Assistant** | **Sí.** La app Companion de HA para iOS puede extraer las credenciales Thread de Apple —*Ajustes → Dispositivos y servicios → Thread → Configurar → Enviar credenciales a Home Assistant*— y desde ahí puedes pasarle el dataset a la sonda. |
| Ya tienes un **OTBR** en marcha (p. ej. el complemento de HA) | **Sí.** Lee el dataset directamente de él. |
| **Solo routers de borde de Apple o Google**, sin Home Assistant | **Hoy no.** No hay ninguna vía accesible al usuario para exportar las credenciales Thread de Apple. Aún puedes formar una red *nueva* en la sonda y añadirle algunos accesorios para ver la app funcionando de principio a fin, pero no te mostrará tu malla actual. |

Esa tercera fila es un muro de verdad, y no es uno que este proyecto pueda derribar desde fuera: la vía autorizada es el entitlement `com.apple.developer.thread-network-credentials` de Apple, que ThreadMapper ha solicitado pero no tiene. Si llega a concederse, la app podrá pasarle tus credenciales a la sonda directamente y toda esta sección desaparece.

**Si estás en la tercera fila y solo quieres vigilar tu malla de Apple actual, plantéate parar aquí hasta que ese entitlement llegue.**

---

## Lista de la compra

| Artículo | Notas |
|---|---|
| Raspberry Pi 4 o 5 | Con 2 GB de RAM sobra. Una Pi Zero 2 W funciona, pero la compilación del paso 4 tarda muchísimo más. |
| Tarjeta microSD, 16 GB o más | Cualquiera de una marca fiable. |
| Fuente de alimentación USB-C | La oficial; los adaptadores Thread son quisquillosos con las caídas de tensión. |
| **Un adaptador 802.15.4** | Elige uno; mira abajo. |

**Opciones de adaptador**, cualquiera de las dos vale:

- **Adaptador Nordic nRF52840** (unos 10 $) — el más barato, y el firmware se compila desde el código fuente, así que no hay que buscar ninguna descarga.
- **SkyConnect / Sonoff ZBDongle-E** (unos 25 $) — de Silicon Labs. Si ya tienes uno para Home Assistant, úsalo. Para grabarlo basta una herramienta de una sola orden.

---

## Paso 1 — Instala el firmware RCP en el adaptador

Haz esto **antes** de tocar la Pi, en tu Mac o PC. Es el único paso que el instalador deliberadamente no automatiza: grabar la imagen equivocada inutiliza el adaptador, y las herramientas del fabricante lo hacen bien.

El firmware RCP («Radio Co-Processor») convierte el adaptador en una radio tonta controlada por `otbr-agent`. Un adaptador vendido para Zigbee lleva otro firmware y no funcionará hasta que lo regrabes.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Consigue el `.gbl` de `ot-rcp` en las publicaciones de firmware de silabs de Home Assistant: las mismas imágenes que usa el complemento OTBR. Haz que el archivo coincida con el modelo exacto de tu adaptador; SkyConnect y ZBDongle-E **no** son intercambiables.

### Nordic nRF52840

Compila el firmware desde el port para Nordic de OpenThread y grábalo por USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Sigue el README de ese repositorio para el paso de empaquetado actual: cambia de vez en cuando y es mejor leerlo allí que copiarlo aquí.

**Comprueba que ha funcionado:** enchufa más tarde el adaptador a la Pi e `install.sh` informará de `Found <family> radio at /dev/serial/by-id/...`. Si no encuentra nada, el firmware no se ha grabado.

---

## Paso 2 — Graba Raspberry Pi OS

1. Instala **Raspberry Pi Imager**.
2. Elige **Raspberry Pi OS Lite (64-bit)**. Lite: no hace falta ningún escritorio.
3. Pulsa el botón del **engranaje / Editar ajustes** *antes* de escribir, y configura:
   - nombre de host: `threadmapper-probe`
   - **Activa SSH**, con contraseña o con clave
   - nombre de usuario y contraseña
   - credenciales del Wi-Fi, si no vas a usar Ethernet
4. Graba la tarjeta, ponla en la Pi, conecta el adaptador y enciéndela.

Aquí Ethernet es más fiable que el Wi-Fi, y a un router de borde le viene bien un enlace estable. Úsalo si puedes.

---

## Paso 3 — Inicia sesión

```bash
ssh <your-username>@threadmapper-probe.local
```

Si el nombre de host no se resuelve, busca la IP de la Pi en la lista de clientes de tu router y usa `ssh <user>@<ip>` en su lugar.

Confirma que el adaptador se ve antes de seguir:

```bash
ls -l /dev/serial/by-id/
```

Deberías ver una entrada con el nombre de tu adaptador. **Si esto está vacío, para** — el resto no va a funcionar. Vuelve a encajarlo, prueba otro puerto USB y revisa de nuevo el paso 1.

---

## Paso 4 — Instala la sonda

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Detecta el adaptador, instala `otbr-agent` y el agente de la sonda, y activa los dos como servicios de systemd.

**Esto tarda unos 20 minutos en una Pi 4**, casi todo compilando `otbr-agent`. No se ha colgado. Al terminar imprime la dirección de la sonda.

Si la detección falla pero conoces la ruta del dispositivo:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Volver a ejecutarlo es seguro: es idempotente, y es la forma de actualizar el agente más adelante.

---

## Paso 5 — Entra en una red Thread

Elige la fila que te correspondía en «Lee esto antes de comprar nada».

### Vía A — Únete a tu red actual (lo que de verdad quieres)

Consigue el Active Operational Dataset como cadena hexadecimal de aquello que ya tenga tus credenciales.

Desde un OTBR existente (incluido el complemento de Home Assistant):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Eso devuelve una sola cadena hexadecimal larga. En la Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Espera unos 30 segundos y después:

```bash
sudo ot-ctl state
```

Deberías ver `child` o `router`: se ha unido. Un `leader` aquí significaría que ha formado su propia red, que no es lo que quieres en esta vía.

### Vía B — Forma una red nueva (para probar, o si no hay forma de conseguir credenciales)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Ahora tienes una red vacía con un solo nodo. Para ver algo interesante tienes que añadirle accesorios, lo que implica quitarlos primero de tu red de Apple. **No hagas esto con dispositivos de los que dependas.**

Imprime el dataset si quieres unir otras cosas a ella más adelante:

```bash
sudo ot-ctl dataset active -x
```

---

## Paso 6 — Apunta la app hacia ella

```bash
curl http://localhost:8099/health
```

Deberías ver `"otCtlReachable": true` y un `role`. Después, desde tu teléfono en la misma red, en **ThreadMapper → Ajustes → Sonda de ThreadMapper**:

```
http://threadmapper-probe.local:8099
```

Usa la dirección IP de la Pi si `.local` no se resuelve en iOS. Toca **Probar conexión**: nombra el fallo si algo va mal, en vez de limitarse a mostrar una X roja.

---

## Paso 7 — Mira lo que has conseguido

- **Panel → ⋯ → Red Thread** — RSSI medido por nodo, calidad de enlace y la tabla de enrutamiento con el coste de ruta y el siguiente salto. Los nodos aparecen por dirección Thread, no por nombre; mira «Lo que todavía no funciona» más abajo.
- **Malla → herramientas → Escáner de canales** — ahora con el distintivo **Medido**. La altura de las barras es el nivel de ruido real de los 16 canales, y los canales recomendados son los más silenciosos observados de verdad, no una suposición sacada de una tabla de solapamiento con el Wi-Fi.

El Escáner de canales es lo primero que hay que mirar. Es la diferencia más clara entre lo que la app podía enseñar antes y lo que puede enseñar ahora.

---

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| `install.sh` dice «No 802.15.4 dongle detected» | El adaptador no está, o el paso 1 no cuajó. Comprueba `ls /dev/serial/by-id/`. |
| Probar conexión: *«no alcanza el router de borde contiguo»* | El agente está en marcha, pero `otbr-agent` no. `sudo systemctl status otbr-agent` y luego `journalctl -u otbr-agent -n 50`. Suele ser una URL de radio equivocada o un adaptador que se ha quedado sin corriente. |
| Probar conexión: *«no es un agente de sonda de ThreadMapper»* | Hay otra cosa respondiendo en ese puerto. El agente es el 8099; el 8081 es la propia API REST del router de borde. |
| Probar conexión: *«No se pudo contactar con esa dirección»* | IP equivocada, o el teléfono está en otra subred o en una VLAN de invitados. |
| `ot-ctl state` dice `detached` | Tiene credenciales pero no encuentra la red. Dataset equivocado, o fuera del alcance de radio de cualquier otro nodo. |
| `ot-ctl state` dice `disabled` | No se ejecutó `ifconfig up` / `thread start`, o la radio no llegó a arrancar. |
| La pantalla Red Thread no muestra ningún nodo par | La sonda está en su propia red: comprueba que no seas `leader` cuando lo que querías era unirte a una. |
| Todo funciona y deja de hacerlo tras reiniciar | `systemctl is-enabled otbr-agent threadmapper-probe` — los dos deberían decir `enabled`. |

Los registros de los dos servicios juntos:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Lo que todavía no funciona

**Los nodos aparecen sin nombre.** Thread identifica un nodo por su dirección extendida; HomeKit identifica un accesorio por un identificador opaco, y no hay nada que relacione los dos. Así que verás una topología real y correcta de nodos anónimos en lugar de «la lámpara de la cocina».

La solución está construida pero sin terminar: el endpoint `/traffic` del agente informa de la actividad por nodo, así que accionar un dispositivo a través de HomeKit y mirar qué nodo responde los emparejaría. Esa interacción necesita accesorios reales sobre una malla real contra los que desarrollarla, que es exactamente lo que tendrás en cuanto esto esté funcionando. Se sigue como **H1** en `WORKPLAN.md`.

**La pestaña Malla sigue siendo deducida.** Su gráfico se construye a partir de los accesorios de HomeKit, así que no puede usar los datos de la sonda hasta que se resuelva lo anterior. La pantalla Red Thread y el Escáner de canales son las que muestran mediciones.

---

## Si algo de aquí está mal

Esta guía no se ha recorrido de principio a fin con hardware real: nadie en el proyecto tiene todavía una Pi ni un adaptador. El script de aprovisionamiento está probado contra Debian Bookworm arm64, y todos los endpoints del agente están probados contra un `otbr-agent` real sobre una radio simulada, pero los pasos físicos de arriba están escritos a partir de la documentación del fabricante y no de haberlos hecho.

Si un paso está mal, merece la pena arreglarlo en este archivo.
