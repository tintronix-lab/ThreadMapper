# Como montar uma sonda do ThreadMapper em um Raspberry Pi

Passo a passo, da mesa vazia até dados Thread medidos no app.

Reserve uma noite. A maior parte é esperar downloads e uma compilação de uns 20 minutos.

---

## Leia isto antes de comprar qualquer coisa

Duas coisas decidem se isso vale a pena para a *sua* instalação. As duas são fáceis de deixar passar até as peças chegarem.

### 1. Um Raspberry Pi não faz Thread sozinho

Não existe rádio 802.15.4 dentro de um Raspberry Pi. Wi-Fi e Bluetooth são rádios diferentes e não sabem falar Thread. **Você precisa de um dongle USB**, e ele precisa ter firmware RCP — que não é o que esses dongles trazem de fábrica.

### 2. Entrar na *sua* rede Thread é a parte difícil

Um roteador de borda que forma uma rede nova só vai ficar ali enxergando a si mesmo. Seus dispositivos de verdade estão na rede que o seu HomePod, a sua Apple TV ou o seu hub Nest criou, e para observá-los a sonda precisa **entrar nessa rede** — o que significa obter as credenciais dela (o Active Operational Dataset).

| A sua instalação | A sonda consegue entrar na sua rede real? |
|---|---|
| Você usa o **Home Assistant** | **Sim.** O app Companion do HA para iOS consegue extrair as credenciais Thread da Apple — *Configurações → Dispositivos e serviços → Thread → Configurar → Enviar credenciais para o Home Assistant* — e dali você entrega o dataset para a sonda. |
| Você já roda um **OTBR** (o complemento do HA, por exemplo) | **Sim.** Leia o dataset direto dele. |
| **Só roteadores de borda da Apple ou do Google**, sem Home Assistant | **Hoje não.** Não existe nenhum caminho acessível ao usuário para exportar as credenciais Thread da Apple. Você ainda pode formar uma rede *nova* na sonda e comissionar alguns acessórios nela para ver o app funcionando de ponta a ponta, mas ela não vai mostrar a sua malha atual. |

Essa terceira linha é uma parede de verdade, e não é uma que este projeto consiga derrubar de fora: o caminho autorizado é o entitlement `com.apple.developer.thread-network-credentials` da Apple, que o ThreadMapper solicitou mas não tem. Se ele sair, o app poderá entregar as suas credenciais direto para a sonda e esta seção inteira desaparece.

**Se você está na terceira linha e só quer monitorar a sua malha Apple atual, considere parar por aqui até esse entitlement chegar.**

---

## Lista de compras

| Item | Observações |
|---|---|
| Raspberry Pi 4 ou 5 | 2 GB de RAM é de sobra. Um Pi Zero 2 W funciona, mas a compilação do passo 4 demora muito mais. |
| Cartão microSD, 16 GB ou mais | Qualquer um de marca confiável. |
| Fonte USB-C | A oficial; dongles Thread são sensíveis a quedas de tensão. |
| **Um dongle 802.15.4** | Escolha um — veja abaixo. |

**Opções de dongle**, qualquer uma das duas serve:

- **Dongle Nordic nRF52840** (cerca de US$ 10) — o mais barato, e o firmware é compilado a partir do código-fonte, então não há download nenhum para caçar.
- **SkyConnect / Sonoff ZBDongle-E** (cerca de US$ 25) — da Silicon Labs. Se você já tem um para o Home Assistant, use-o. A gravação é feita por uma ferramenta de uma linha só.

---

## Passo 1 — Grave o firmware RCP no dongle

Faça isso **antes** de encostar no Pi, no seu Mac ou PC. É o único passo que o instalador deliberadamente não automatiza: gravar a imagem errada inutiliza o dongle, e as ferramentas do fabricante fazem isso direito.

O firmware RCP (“Radio Co-Processor”) transforma o dongle em um rádio burro que o `otbr-agent` comanda. Um dongle vendido para Zigbee tem outro firmware e não vai funcionar até ser regravado.

### Silicon Labs (SkyConnect, Sonoff ZBDongle-E)

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

Pegue o `.gbl` do `ot-rcp` nas publicações de firmware silabs do Home Assistant — as mesmas imagens que o complemento OTBR usa. Combine o arquivo com o modelo exato do seu dongle; SkyConnect e ZBDongle-E **não** são intercambiáveis.

### Nordic nRF52840

Compile o firmware a partir do port do OpenThread para a Nordic e grave por USB DFU:

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

Siga o README daquele repositório para o passo de empacotamento atual — ele muda de vez em quando e é melhor lido lá do que copiado aqui.

**Confira se deu certo:** conecte o dongle no Pi mais tarde e o `install.sh` vai informar `Found <family> radio at /dev/serial/by-id/...`. Se ele não encontrar nada, o firmware não pegou.

---

## Passo 2 — Grave o Raspberry Pi OS

1. Instale o **Raspberry Pi Imager**.
2. Escolha **Raspberry Pi OS Lite (64-bit)**. Lite mesmo — não há necessidade de desktop.
3. Clique no botão de **engrenagem / Editar configurações** *antes* de gravar e defina:
   - nome do host: `threadmapper-probe`
   - **Ative o SSH**, com senha ou com chave
   - nome de usuário e senha
   - credenciais do Wi-Fi, se você não for usar Ethernet
4. Grave o cartão, coloque-o no Pi, conecte o dongle e ligue.

Aqui o Ethernet é mais confiável que o Wi-Fi, e um roteador de borda se beneficia de um uplink estável. Use-o se puder.

---

## Passo 3 — Faça login

```bash
ssh <your-username>@threadmapper-probe.local
```

Se o nome do host não resolver, ache o IP do Pi na lista de clientes do seu roteador e use `ssh <user>@<ip>`.

Confirme que o dongle está visível antes de seguir:

```bash
ls -l /dev/serial/by-id/
```

Você deve ver uma entrada com o nome do seu dongle. **Se isso estiver vazio, pare** — o resto não vai funcionar. Reencaixe o dongle, tente outra porta USB e revise o passo 1.

---

## Passo 4 — Instale a sonda

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

Ele detecta o dongle, instala o `otbr-agent` e o agente da sonda, e ativa os dois como serviços do systemd.

**Isso leva uns 20 minutos em um Pi 4**, quase tudo compilando o `otbr-agent`. Não travou. Ao terminar, ele imprime o endereço da sonda.

Se a detecção falhar mas você souber o caminho do dispositivo:

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

Rodar de novo é seguro — é idempotente, e é assim que você atualiza o agente mais tarde.

---

## Passo 5 — Entre em uma rede Thread

Escolha a linha que combinou com você em “Leia isto antes de comprar qualquer coisa”.

### Caminho A — Entrar na sua rede atual (o que você realmente quer)

Obtenha o Active Operational Dataset como string hexadecimal de onde quer que as suas credenciais já estejam.

De um OTBR existente (incluindo o complemento do Home Assistant):

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

Isso devolve uma única string hexadecimal longa. No Pi:

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

Espere uns 30 segundos e então:

```bash
sudo ot-ctl state
```

O esperado é `child` ou `router` — ela entrou. Um `leader` aqui significaria que ela formou a própria rede, que não é o que você quer neste caminho.

### Caminho B — Formar uma rede nova (para testar, ou sem jeito de obter credenciais)

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

Agora você tem uma rede vazia com um nó só. Para ver algo interessante, você precisa comissionar acessórios nela — o que significa tirá-los da sua rede Apple primeiro. **Não faça isso com dispositivos dos quais você depende.**

Imprima o dataset se quiser juntar outras coisas a ela mais tarde:

```bash
sudo ot-ctl dataset active -x
```

---

## Passo 6 — Aponte o app para ela

```bash
curl http://localhost:8099/health
```

O esperado é `"otCtlReachable": true` e um `role`. Depois, do seu celular na mesma rede, em **ThreadMapper → Ajustes → Sonda do ThreadMapper**:

```
http://threadmapper-probe.local:8099
```

Use o endereço IP do Pi se o `.local` não resolver no iOS. Toque em **Testar conexão** — ele nomeia a falha quando algo está errado, em vez de só mostrar um X vermelho.

---

## Passo 7 — Veja o que você conseguiu

- **Painel → ⋯ → Rede Thread** — RSSI medido por nó, qualidade da conexão e a tabela de roteamento com custo do caminho e próximo salto. Os nós aparecem pelo endereço Thread, não pelo nome; veja “O que ainda não funciona” abaixo.
- **Malha → ferramentas → Scanner de canais** — agora com o selo **Medido**. A altura das barras é o nível de ruído real dos 16 canais, e os canais recomendados são os mais silenciosos de fato observados, não um palpite tirado de uma tabela de sobreposição com o Wi-Fi.

O Scanner de canais é o primeiro a olhar. É a diferença mais clara entre o que o app conseguia mostrar antes e o que ele consegue mostrar agora.

---

## Solução de problemas

| Sintoma | Causa e solução |
|---|---|
| O `install.sh` diz “No 802.15.4 dongle detected” | O dongle não está presente, ou o passo 1 não pegou. Confira `ls /dev/serial/by-id/`. |
| Testar conexão: *“não alcança o roteador de borda ao lado”* | O agente está no ar, mas o `otbr-agent` não. `sudo systemctl status otbr-agent` e depois `journalctl -u otbr-agent -n 50`. Normalmente é uma URL de rádio errada ou um dongle que perdeu energia. |
| Testar conexão: *“não é um agente de sonda do ThreadMapper”* | Outra coisa está respondendo naquela porta. O agente é o 8099; o 8081 é a API REST do próprio roteador de borda. |
| Testar conexão: *“Não foi possível acessar esse endereço”* | IP errado, ou o celular está em outra sub-rede ou em uma VLAN de convidados. |
| O `ot-ctl state` diz `detached` | Ela tem credenciais mas não acha a rede. Dataset errado, ou fora do alcance de rádio de qualquer outro nó. |
| O `ot-ctl state` diz `disabled` | O `ifconfig up` / `thread start` não rodou, ou o rádio não subiu. |
| A tela Rede Thread está sem nenhum par | A sonda está na própria rede — confira se você não está como `leader` quando queria entrar em uma. |
| Tudo funciona e depois morre após um reinício | `systemctl is-enabled otbr-agent threadmapper-probe` — os dois devem dizer `enabled`. |

Os registros dos dois serviços juntos:

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## O que ainda não funciona

**Os nós aparecem sem nome.** O Thread identifica um nó pelo endereço estendido dele; o HomeKit identifica um acessório por um identificador opaco, e nada liga os dois. Então você vai ver uma topologia real e correta de nós anônimos, em vez de “a lâmpada da cozinha”.

A correção está construída mas não terminada: o endpoint `/traffic` do agente informa a atividade por nó, então acionar um dispositivo pelo HomeKit e observar qual nó responde amarraria os dois. Essa interação precisa de acessórios reais em uma malha real para ser desenvolvida, que é exatamente o que você vai ter assim que isto estiver rodando. Acompanhado como **H1** no `WORKPLAN.md`.

**A aba Malha ainda é deduzida.** O gráfico dela é montado a partir dos acessórios do HomeKit, então ela não consegue usar os dados da sonda enquanto o problema acima não for resolvido. A tela Rede Thread e o Scanner de canais são as que mostram medições.

---

## Se alguma coisa aqui estiver errada

Este guia não foi percorrido de ponta a ponta em hardware real — ninguém no projeto tem um Pi ou um dongle ainda. O script de provisionamento é testado no Debian Bookworm arm64, e todos os endpoints do agente são testados contra um `otbr-agent` real em um rádio simulado, mas os passos físicos acima foram escritos a partir da documentação do fabricante, não de tê-los feito.

Se um passo estiver errado, vale a pena corrigir neste arquivo.
