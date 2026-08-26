# Raspberry PiでThreadMapperプローブを組み立てる

何もない机から、アプリにThreadの実測データが出るまでを順を追って。

一晩を見ておいてください。その大半はダウンロード待ちと、20分ほどのビルド1回です。

---

## 買う前に読んでください

この作業が割に合うかどうかは、2つの点で決まります。判断の基準になるのは、*ご自身の*環境です。どちらも、部品が届くまでは見落としがちです。

### 1. Raspberry Pi単体ではThreadを扱えません

Raspberry Piには802.15.4の無線が載っていません。Wi-FiとBluetoothは別の無線であり、Threadを話せません。**USBドングルが必要**で、しかもそこにはRCPファームウェアが要ります——市販のドングルが最初から積んでいるものではありません。

### 2. 本当に難しいのは、*ご自身の*Threadネットワークへの参加です

自分で新しいネットワークを作ったボーダールーターは、自分自身しか見えないまま置かれているだけになります。実際のデバイスは、HomePodやApple TV、Nestハブが作ったネットワークの側にいます。それを観測するには、プローブが**そのネットワークに参加**しなければなりません——つまり、その認証情報（Active Operational Dataset）を手に入れる必要があります。

| ご自身の環境 | プローブは実際のネットワークに参加できるか |
|---|---|
| **Home Assistant**を使っている | **はい。**HAのiOSコンパニオンアプリがAppleのThread認証情報を取り出せます——*設定 → デバイスとサービス → Thread → 設定 → Home Assistantに認証情報を送信*——そこからデータセットをプローブに渡せます。 |
| すでに**OTBR**を運用している（HAのアドオンなど） | **はい。**そこからデータセットを直接読み出してください。 |
| **AppleまたはGoogleのボーダールーターだけ**で、Home Assistantなし | **今のところ無理です。**AppleのThread認証情報を書き出す、ユーザー向けの手段がありません。プローブ側で、*新しい*ネットワークを作り、アクセサリをいくつかコミッショニングしてアプリが一通り動くところまでは確かめられますが、既存のメッシュは見えません。 |

3行目は本物の壁で、このプロジェクトが外側から壊せるものではありません。公式な道はAppleの`com.apple.developer.thread-network-credentials`エンタイトルメントで、ThreadMapperは申請済みですが、まだ持っていません。これが通れば、アプリが認証情報を直接プローブに渡せるようになり、この節はまるごと不要になります。

**3行目に当てはまり、既存のAppleメッシュを監視したいだけなら、そのエンタイトルメントが下りるまでここで止めておくことを検討してください。**

---

## 買い物リスト

| 品目 | 備考 |
|---|---|
| Raspberry Pi 4または5 | RAMは2 GBで十分です。Pi Zero 2 Wでも動きますが、手順4のビルドがはるかに長くかかります。 |
| microSDカード、16 GB以上 | 素性の確かなものなら何でも。 |
| USB-C電源アダプタ | 純正品を。Threadドングルは電圧の落ち込みに敏感です。 |
| **802.15.4ドングル1本** | どれか1つを選んでください——下記参照。 |

**ドングルの選択肢**、どちらでも構いません。

- **Nordic nRF52840ドングル**（約10ドル）——最も安く、ファームウェアはソースからビルドするのでダウンロードを探し回る必要がありません。
- **SkyConnect / Sonoff ZBDongle-E**（約25ドル）——Silicon Labs製。Home Assistant用にすでに持っているなら、それを使ってください。書き込みは1行のツールで済みます。

---

## 手順1 — ドングルにRCPファームウェアを書き込む

これはPiに触れる**前に**、お手元のMacまたはPCで行ってください。インストーラーがあえて自動化していない唯一の手順です。間違ったイメージを書き込むとドングルは文鎮になりますし、ベンダー純正のツールなら確実にやってくれるからです。

RCP（「Radio Co-Processor」）ファームウェアは、ドングルを`otbr-agent`が制御する単純な無線機に変えます。Zigbee用として出荷されたドングルは別のファームウェアを積んでおり、書き換えるまでは動きません。

### Silicon Labs（SkyConnect、Sonoff ZBDongle-E）

```bash
pipx install universal-silabs-flasher     # or: pip install universal-silabs-flasher
universal-silabs-flasher --device /dev/tty.usbserial-XXXX probe
universal-silabs-flasher --device /dev/tty.usbserial-XXXX flash --firmware <ot-rcp-firmware.gbl>
```

`ot-rcp`の`.gbl`は、Home Assistantのsilabsファームウェアのリリースから入手してください——OTBRアドオンが使っているのと同じイメージです。ファイルはお使いのドングルの型番に正確に合わせてください。SkyConnectとZBDongle-Eは**互換ではありません**。

### Nordic nRF52840

OpenThreadのNordic向け移植版からファームウェアをビルドし、USB DFUで書き込みます。

```bash
git clone --recurse-submodules https://github.com/openthread/ot-nrf528xx.git
cd ot-nrf528xx && ./script/bootstrap && ./script/build nrf52840 USB_trans
# → build/bin/ot-rcp  (convert to .hex/.zip per the repo's README, then:)
nrfutil dfu usb-serial -pkg ot-rcp.zip -p /dev/tty.usbmodemXXXX
```

パッケージング手順の現行版は、そのリポジトリのREADMEに従ってください——ときどき変わるので、ここに写したものより、そちらを読んだほうが確実です。

**うまくいったかの確認：**あとでドングルをPiに挿すと、`install.sh`が`Found <family> radio at /dev/serial/by-id/...`と表示します。何も見つからなければ、ファームウェアが入っていません。

---

## 手順2 — Raspberry Pi OSを書き込む

1. **Raspberry Pi Imager**をインストールします。
2. **Raspberry Pi OS Lite（64-bit）**を選びます。Liteです——デスクトップは要りません。
3. *書き込む前に*、**歯車 / Edit Settings**ボタンを押して、次を設定します：
   - ホスト名：`threadmapper-probe`
   - **SSHを有効化**。パスワードまたは鍵で。
   - ユーザー名とパスワード
   - Ethernetを使わないなら、Wi-Fiの認証情報
4. カードに書き込み、Piに挿し、ドングルを取り付けて電源を入れます。

ここではEthernetのほうがWi-Fiより信頼できますし、ボーダールーターは安定した上流回線の恩恵を受けます。使えるなら使ってください。

---

## 手順3 — ログインする

```bash
ssh <your-username>@threadmapper-probe.local
```

ホスト名が解決できないときは、ルーターのクライアント一覧でPiのIPアドレスを調べ、代わりに`ssh <user>@<ip>`としてください。

先へ進む前に、ドングルが見えていることを確認します。

```bash
ls -l /dev/serial/by-id/
```

お使いのドングル名を含むエントリが1つ見えるはずです。**ここが空なら、そこで止めてください**——この先は動きません。挿し直し、別のUSBポートを試し、手順1を見直してください。

---

## 手順4 — プローブをインストールする

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tintronix-lab/ThreadMapper.git
sudo ./ThreadMapper/tools/pi-image/install.sh
```

ドングルを検出し、`otbr-agent`とプローブエージェントをインストールして、どちらもsystemdサービスとして有効化します。

**Pi 4では20分ほどかかります**が、その大半は`otbr-agent`のコンパイルです。固まっているわけではありません。終わるとプローブのアドレスを表示します。

検出に失敗しても、デバイスのパスが分かっているなら、次のようにします。

```bash
sudo ./ThreadMapper/tools/pi-image/install.sh --radio-url spinel+hdlc+uart:///dev/ttyACM0
```

再実行しても安全です——冪等ですし、あとでエージェントを更新するときもこの方法を使います。

---

## 手順5 — Threadネットワークに参加する

「買う前に読んでください」で自分に当てはまった行を選んでください。

### 経路A — 既存のネットワークに参加する（本当にやりたいのはこちら）

すでに認証情報を持っているものから、Active Operational Datasetを16進文字列として取得します。

既存のOTBR（Home Assistantのアドオンを含む）から取る場合は、次のようにします。

```bash
curl -s http://<existing-otbr>:8081/node/dataset/active \
     -H 'Accept: text/plain'
```

長い16進文字列が1つ返ってきます。Pi側では、次のようにします。

```bash
sudo ot-ctl dataset set active <that-long-hex-string>
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
```

30秒ほど待ってから、次を実行します。

```bash
sudo ot-ctl state
```

`child`または`router`と出れば、参加できています。ここで`leader`と出たら、自分で別のネットワークを作ってしまったということで、この経路で望む結果ではありません。

### 経路B — 新しいネットワークを作る（テスト用、または認証情報が手に入らない場合）

```bash
sudo ot-ctl dataset init new
sudo ot-ctl dataset commit active
sudo ot-ctl ifconfig up
sudo ot-ctl thread start
sudo ot-ctl state          # expect: leader
```

これで、ノードが1つだけの空のネットワークができました。何か意味のあるものを見るには、アクセサリをこちらにコミッショニングする必要があります——つまり、先にAppleのネットワークから外すということです。**普段頼りにしているデバイスでこれをやってはいけません。**

あとで他のものをこのネットワークに参加させたいなら、データセットを表示しておきます。

```bash
sudo ot-ctl dataset active -x
```

---

## 手順6 — アプリから参照させる

```bash
curl http://localhost:8099/health
```

`"otCtlReachable": true`と`role`が返るはずです。そのうえで、同じネットワークにつないだiPhoneから、**ThreadMapper → 設定 → ThreadMapperプローブ**で次を指定します。

```
http://threadmapper-probe.local:8099
```

iOSで`.local`が解決できない場合は、代わりにPiのIPアドレスを使ってください。**接続テスト**をタップします——問題があるときは、赤い×を出すだけでなく、何が失敗したのかを名指しします。

---

## 手順7 — 何が見えるようになったか

- **ダッシュボード → ⋯ → Threadネットワーク**——ノードごとの実測RSSI、リンク品質、そしてパスコストと次のホップを含むルーティングテーブル。ノードは名前ではなくThreadアドレスで並びます。後述の「まだ動かないこと」を参照してください。
- **メッシュ → ツール → チャンネルスキャナ**——ここに**実測**バッジが付きます。棒の高さは全16チャンネルの本当のノイズフロアで、推奨チャンネルはWi-Fiの重なり表から推測したものではなく、実際に観測して最も静かだったチャンネルです。

まず見るべきはチャンネルスキャナです。これまでアプリが見せられたものと、いま見せられるものとの違いが、いちばんはっきり出ます。

---

## トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| `install.sh`が「No 802.15.4 dongle detected」と表示する | ドングルが挿さっていないか、手順1が効いていません。`ls /dev/serial/by-id/`を確認してください。 |
| 接続テスト：*「隣にあるボーダールーターに届きません」* | エージェントは動いていますが、`otbr-agent`が動いていません。`sudo systemctl status otbr-agent`、続いて`journalctl -u otbr-agent -n 50`。たいていは無線URLの誤りか、ドングルの電源が落ちたかです。 |
| 接続テスト：*「ThreadMapperプローブエージェントではありません」* | そのポートで別の何かが応答しています。エージェントは8099で、8081はボーダールーター自身のREST APIです。 |
| 接続テスト：*「そのアドレスに到達できませんでした」* | IPが違うか、iPhoneが別のサブネットかゲストVLANにいます。 |
| `ot-ctl state`が`detached`と表示する | 認証情報はありますが、ネットワークを見つけられません。データセットが違うか、他のどのノードの電波も届かない場所にあります。 |
| `ot-ctl state`が`disabled`と表示する | `ifconfig up` / `thread start`が実行されていないか、無線が起動しませんでした。 |
| Threadネットワーク画面にピアが1つも出ない | プローブが自分だけのネットワークにいます。参加させるつもりだったのに`leader`になっていないか確認してください。 |
| すべて動いていたのに、再起動後に動かなくなる | `systemctl is-enabled otbr-agent threadmapper-probe`——どちらも`enabled`と出るはずです。 |

両方のサービスのログをまとめて見るには、次を実行します。

```bash
journalctl -u threadmapper-probe -u otbr-agent -f
```

---

## まだ動かないこと

**ノードには名前が付きません。**Threadはノードを拡張アドレスで識別し、HomeKitはアクセサリを不透明な識別子で識別します。その2つを結び付けるものがありません。そのため見えるのは、「キッチンのランプ」ではなく、名前のないノードからなる本物の、正しいトポロジーです。

解決策は作ってあるものの、仕上がっていません。エージェントの`/traffic`エンドポイントはノードごとの通信状況を返すので、HomeKit経由でデバイスを操作し、どのノードが反応するかを見れば、両者を結び付けられます。その作り込みには、本物のメッシュ上に本物のアクセサリが必要です——まさに、これが動きだせば手に入るものです。`WORKPLAN.md`では**H1**として管理しています。

**メッシュタブは今も推論のままです。**そのグラフはHomeKitのアクセサリから組み立てているため、上記が解決するまではプローブのデータを使えません。実測を見せているのは、Threadネットワーク画面とチャンネルスキャナです。

---

## ここに間違いがあったら

このガイドは、実機で最初から最後まで通して試したものではありません——プロジェクトの誰も、まだPiもドングルも持っていないのです。プロビジョニングスクリプトはDebian Bookworm arm64に対してテストしてあり、エージェントの各エンドポイントもシミュレートした無線上で動く本物の`otbr-agent`に対してテストしてありますが、上記の物理的な手順は、実際にやってみた結果ではなくベンダーのドキュメントをもとに書いています。

手順に誤りがあれば、それはこのファイルで直す価値のあるものです。
