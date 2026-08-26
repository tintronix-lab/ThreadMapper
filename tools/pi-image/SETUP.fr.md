# Installer une sonde ThreadMapper sur un Raspberry Pi

Pas à pas, du bureau vide aux données Thread mesurées dans l’app.

Prévoyez une soirée. L’essentiel du temps se passe à attendre des téléchargements et une compilation d’environ 20 minutes.

---

## À lire avant d’acheter quoi que ce soit

Deux points décident si l’opération en vaut la peine pour *votre* installation. Tous deux sont faciles à manquer tant que les pièces ne sont pas arrivées.

### 1. Un Raspberry Pi ne sait pas faire du Thread tout seul

Il n’y a aucune radio 802.15.4 dans un Raspberry Pi. Le Wi-Fi et le Bluetooth sont des radios différentes et ne savent pas parler Thread. **Il vous faut un dongle USB**, et il lui faut un micrologiciel RCP — ce n’est pas celui avec lequel ces dongles sont livrés.

### 2. Rejoindre *votre* réseau Thread est le plus difficile

Un routeur de bordure qui forme son propre réseau restera là à ne voir que lui-même. Vos vrais appareils, eux, sont sur le réseau créé par votre HomePod, votre Apple TV ou votre hub Nest, et pour les observer la sonde doit **rejoindre ce réseau** — ce qui suppose d’en obtenir les identifiants (le jeu de données opérationnel actif).

| Votre installation | La sonde peut-elle rejoindre votre vrai réseau ? |
|---|---|
| Vous utilisez **Home Assistant** | **Oui.** L’app Companion iOS de HA sait récupérer les identifiants Thread d’Apple — *Paramètres → Appareils et services → Thread → Configurer → Envoyer les identifiants à Home Assistant* — et vous pouvez ensuite transmettre le jeu de données à la sonde. |
| Vous utilisez déjà un **OTBR** (par exemple le module complémentaire de HA) | **Oui.** Lisez-y le jeu de données directement. |
| **Uniquement des routeurs de bordure Apple ou Google**, sans Home Assistant | **Pas aujourd’hui.** Il n’existe aucun moyen offert à l’utilisateur d’exporter les identifiants Thread d’Apple. Vous pouvez tout de même former un *nouveau* réseau sur la sonde et y appairer quelques accessoires pour voir l’app fonctionner de bout en bout, mais elle ne vous montrera pas votre maillage existant. |

Cette troisième ligne est un vrai mur, et ce n’est pas un mur que ce projet peut abattre de l’extérieur : la voie officielle est le droit d’accès `com.apple.developer.thread-network-credentials` d’Apple, que ThreadMapper a demandé mais n’a pas obtenu. S’il est accordé, l’app pourra transmettre vos identifiants directement à la sonde et toute cette section disparaîtra.

**Si vous êtes dans la troisième ligne et que vous voulez seulement surveiller votre maillage Apple existant, envisagez de vous arrêter ici jusqu’à l’obtention de ce droit d’accès.**

---

## Liste de courses

| Élément | Remarques |
|---|---|
| Raspberry Pi 4 ou 5 | 2 Go de RAM suffisent largement. Un Pi Zero 2 W fonctionne, mais la compilation de l’étape 4 y est bien plus longue. |
| Carte microSD, 16 Go ou plus | N’importe quelle marque sérieuse. |
| Alimentation USB-C | L’officielle ; les dongles Thread supportent mal les baisses de tension. |
| **Un dongle 802.15.4** | Choisissez-en un — voir ci-dessous. |

**Options de dongle**, les deux conviennent :

- **Dongle Nordic nRF52840** (environ 10 $) — le moins cher, et le micrologiciel se compile depuis les sources, donc pas de téléchargement à chercher.
- **SkyConnect / Sonoff ZBDongle-E** (environ 25 $) — Silicon Labs. Si vous en possédez déjà un pour Home Assistant, utilisez-le. Le flashage tient en une ligne de commande.

---

## Étape 1 — Installer le micrologiciel RCP sur le dongle

Faites-le **avant** de toucher au Pi, depuis votre Mac ou votre PC. C’est la seule étape que le script d’installation n’automatise délibérément pas : flasher la mauvaise image rend le dongle inutilisable, et les outils du fabricant font le travail correctement.

Le micrologiciel RCP (« Radio Co-Processor ») fait du dongle une simple radio pilotée par `otbr-agent`. Un dongle livré pour Zigbee a un micrologiciel différent et ne fonctionnera pas tant qu’il n’est pas reflashé.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Récupérez le `.gbl` `ot-rcp` dans les versions publiées du micrologiciel silabs de Home Assistant — les mêmes images que celles employées par le module complémentaire OTBR. Faites correspondre le fichier au modèle exact de votre dongle ; le SkyConnect et le ZBDongle-E ne sont **pas** interchangeables.

### Nordic nRF52840

Compilez le micrologiciel depuis le portage Nordic d’OpenThread, puis flashez-le par USB DFU :

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Suivez le README de ce dépôt pour l’étape d’empaquetage actuelle — elle change de temps en temps et il vaut mieux la lire là-bas que la recopier ici.

**Vérifiez que ça a marché :** branchez plus tard le dongle sur le Pi et `install.sh` signalera `Found <family> radio at /dev/serial/by-id/...`. S’il ne trouve rien, le micrologiciel n’est pas passé.

---

## Étape 2 — Flasher Raspberry Pi OS

1. Installez **Raspberry Pi Imager**.
2. Choisissez **Raspberry Pi OS Lite (64-bit)**. Lite — un bureau n’a aucune utilité ici.
3. Cliquez sur le bouton **engrenage / Edit Settings** *avant* d’écrire la carte, et renseignez :
   - nom d’hôte : `threadmapper-probe`
   - **Activez SSH**, par mot de passe ou par clé
   - nom d’utilisateur et mot de passe
   - identifiants Wi-Fi, si vous n’utilisez pas l’Ethernet
4. Écrivez la carte, insérez-la dans le Pi, branchez le dongle, mettez sous tension.

L’Ethernet est plus fiable que le Wi-Fi ici, et un routeur de bordure gagne à disposer d’un lien montant stable. Utilisez-le si vous le pouvez.

---

## Étape 3 — Se connecter

```bash
ssh <your-username>@threadmapper-probe.local
```

Si le nom d’hôte ne se résout pas, trouvez l’IP du Pi dans la liste des clients de votre routeur et faites plutôt `ssh <user>@<ip>`.

Vérifiez que le dongle est visible avant d’aller plus loin :

```bash
ls -l /dev/serial/by-id/
```

Vous devriez voir une entrée portant le nom de votre dongle. **Si c’est vide, arrêtez-vous** — la suite ne fonctionnera pas. Rebranchez-le, essayez un autre port USB et reprenez l’étape 1.

---

## Étape 4 — Installer la sonde

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Il détecte le dongle, installe `otbr-agent` et l’agent de la sonde, puis active les deux comme services systemd.

**Comptez environ 20 minutes sur un Pi 4**, presque entièrement consacrées à la compilation d’`otbr-agent`. Il n’est pas bloqué. À la fin, il affiche l’adresse de la sonde.

Si la détection échoue mais que vous connaissez le chemin du périphérique :

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Le relancer est sans risque — le script est idempotent, et c’est ainsi que vous mettrez l’agent à jour par la suite.

---

## Étape 5 — Mettre la sonde sur un réseau Thread

Choisissez la ligne qui vous correspondait dans « À lire avant d’acheter ».

### Voie A — Rejoindre votre réseau existant (ce que vous voulez vraiment)

Récupérez le jeu de données opérationnel actif sous forme de chaîne hexadécimale depuis ce qui détient déjà vos identifiants.

Depuis un OTBR existant (y compris le module complémentaire de Home Assistant) :

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Cela renvoie une longue chaîne hexadécimale. Sur le Pi :

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Attendez environ 30 secondes, puis :

```bash
sudo ot-ctl state
```

Attendez-vous à `child` ou `router` — elle a rejoint le réseau. `leader` signifierait ici qu’elle a formé son propre réseau, ce qui n’est pas le but sur cette voie.

### Voie B — Former un nouveau réseau (test, ou aucun moyen d’obtenir les identifiants)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Vous avez maintenant un réseau vide avec un seul nœud. Pour y voir quoi que ce soit d’intéressant, vous devez y appairer des accessoires — ce qui suppose de les retirer d’abord de votre réseau Apple. **Ne faites pas cela avec des appareils dont vous dépendez.**

Affichez le jeu de données si vous voulez y raccorder d’autres appareils plus tard :

```bash
sudo ot-ctl dataset active -x
```

---

## Étape 6 — Diriger l’app vers la sonde

```bash
curl http://localhost:8099/health
```

Attendez-vous à `"otCtlReachable": true` et à un `role`. Ensuite, depuis votre téléphone connecté au même réseau, dans **ThreadMapper → Réglages → Sonde ThreadMapper** :

```
http://threadmapper-probe.local:8099
```

Utilisez plutôt l’adresse IP du Pi si `.local` ne se résout pas sur iOS. Touchez **Tester la connexion** — en cas de problème, l’app nomme l’échec au lieu d’afficher seulement une croix rouge.

---

## Étape 7 — Voir ce que vous avez obtenu

- **Tableau de bord → ⋯ → Réseau Thread** — le RSSI mesuré par nœud, la qualité de liaison et la table de routage avec coût du chemin et saut suivant. Les nœuds apparaissent par adresse Thread, pas par nom ; voir « Ce qui ne fonctionne pas encore » plus bas.
- **Réseau → outils → Scanner de canaux** — désormais marqué du badge **Mesuré**. La hauteur des barres correspond au plancher de bruit réel sur les 16 canaux, et les canaux recommandés sont les plus calmes réellement observés plutôt qu’une supposition tirée d’un tableau de chevauchement Wi-Fi.

Le scanner de canaux est le premier à regarder. C’est la différence la plus nette entre ce que l’app pouvait montrer avant et ce qu’elle peut montrer maintenant.

---

## Dépannage

| Symptôme | Cause et correctif |
|---|---|
| `install.sh` affiche « No 802.15.4 dongle detected » | Le dongle est absent, ou l’étape 1 n’a pas pris. Vérifiez avec `ls /dev/serial/by-id/`. |
| Tester la connexion : *« il ne joint pas le routeur de bordure voisin »* | L’agent tourne, mais pas `otbr-agent`. Faites `sudo systemctl status otbr-agent`, puis `journalctl -u otbr-agent -n 50`. En général une mauvaise URL de radio ou un dongle qui a perdu son alimentation. |
| Tester la connexion : *« ce n’est pas un agent de sonde ThreadMapper »* | Autre chose répond sur ce port. L’agent est sur le 8099 ; le 8081 est l’API REST du routeur de bordure lui-même. |
| Tester la connexion : *« adresse injoignable »* | Mauvaise IP, ou le téléphone est sur un autre sous-réseau ou un VLAN invité. |
| `ot-ctl state` affiche `detached` | Elle a des identifiants mais ne trouve pas le réseau. Mauvais jeu de données, ou hors de portée radio de tout autre nœud. |
| `ot-ctl state` affiche `disabled` | `ifconfig up` / `thread start` n’ont pas été exécutés, ou la radio n’a pas démarré. |
| L’écran Réseau Thread ne montre aucun pair | La sonde est sur son propre réseau — vérifiez que vous n’êtes pas `leader` alors que vous vouliez en rejoindre un. |
| Tout fonctionne, puis meurt après un redémarrage | `systemctl is-enabled otbr-agent threadmapper-probe` — les deux doivent répondre `enabled`. |

Les journaux des deux services ensemble :

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## Ce qui ne fonctionne pas encore

**Les nœuds apparaissent sans nom.** Thread identifie un nœud par son adresse étendue ; HomeKit identifie un accessoire par un identifiant opaque, et rien ne relie les deux. Vous verrez donc une topologie réelle et exacte de nœuds anonymes plutôt que « la lampe de la cuisine ».

Le correctif est écrit mais pas terminé : le point de terminaison `/traffic` de l’agent rapporte l’activité par nœud, donc actionner un appareil via HomeKit en observant quel nœud répond permettrait de les associer. Développer cette interaction demande de vrais accessoires sur un vrai maillage, ce que vous aurez précisément une fois tout ceci en marche. Suivi sous **H1** dans `WORKPLAN.md`.

**L’onglet Réseau reste déduit.** Son graphe est construit à partir des accessoires HomeKit, il ne peut donc pas exploiter les données de la sonde tant que le point ci-dessus n’est pas résolu. Ce sont l’écran Réseau Thread et le scanner de canaux qui affichent des mesures.

---

## Si quelque chose ici est faux

Ce guide n’a pas été parcouru de bout en bout sur du matériel réel — personne sur le projet ne possède encore de Pi ni de dongle. Le script de provisionnement est testé sur Debian Bookworm arm64, et chaque point de terminaison de l’agent est testé face à un vrai `otbr-agent` sur une radio simulée, mais les étapes physiques ci-dessus sont écrites d’après la documentation des fabricants plutôt que par expérience.

Si une étape est fausse, cela vaut la peine d’être corrigé dans ce fichier.
