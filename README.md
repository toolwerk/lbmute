# lbmute

[![macOS](https://img.shields.io/badge/macOS-Core%20Audio-000000?logo=apple&logoColor=white)](#voraussetzungen)
[![Swift](https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white)](Sources/lbmute.swift)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue)](LICENSE)

**Deutsch** · [English](README.en.md)

Ein winziges macOS-Kommandozeilenwerkzeug, das **den Eingang eines einzelnen Audiogeräts stumm- und wieder hörbar schaltet**, ohne das echte Mikrofon dahinter anzufassen.

```bash
lbmute ChatGPT-Mikro set 1   # dieses Gerät liefert jetzt Stille
lbmute ChatGPT-Mikro set 0   # wieder hörbar
```

Virtuelle Geräte, etwa aus [Loopback](https://rogueamoeba.com/loopback/) von Rogue Amoeba, stellen über Core Audio einen Stummschalter auf der Eingangsseite bereit. `lbmute` liest und setzt ihn. Loopback selbst hat keine Skript-Schnittstelle (kein AppleScript, kein URL-Schema, keine Kurzbefehle-Aktion); dieser Schalter ist der eine Ansatzpunkt, den man von außen bedienen kann.

## Wozu

Ein Mikrofon, zwei Abnehmer, und nur einer soll dich hören.

Typischer Fall: Du diktierst in ein Textfeld, während in einer anderen App ein Sprachchat läuft. Der Sprachchat soll das Diktat nicht mithören, das Diktierprogramm braucht aber weiter das Mikrofon. Schaltest du das echte Mikrofon stumm, hört keiner von beiden etwas. Schaltest du ein **virtuelles Gerät stumm, das nur der Sprachchat nutzt**, schweigt nur der Sprachchat.

```
echtes Mikrofon ──┬──────────────────────► Diktierprogramm (hört weiter zu)
                  └─► virtuelles Gerät ──► Sprachchat      (lbmute schaltet dieses stumm)
```

## Voraussetzungen

- macOS (Core Audio). Entwickelt unter macOS 26.
- Xcode-Kommandozeilenwerkzeuge (`swiftc`) zum Bauen.
- Ein Gerät mit Eingangs-Stummschaltung. Loopback-Geräte haben sie, viele echte Mikrofone nicht. `lbmute list` zeigt es.

## Bauen und installieren

```bash
git clone https://github.com/toolwerk/lbmute.git
cd lbmute
make install                         # baut und kopiert nach ~/bin/lbmute
make install PREFIX=/usr/local/bin   # oder an einen anderen Ort
```

Nur `make` baut `./lbmute` im Repository.

## Benutzung

```
lbmute list                  alle Audiogeräte mit ihrem Stumm-Zustand
lbmute <Gerät> get           Stumm-Zustand ausgeben
lbmute <Gerät> set 0|1       Stumm-Zustand setzen und ausgeben
lbmute <Gerät> toggle        Stumm-Zustand umkehren und ausgeben
```

`<Gerät>` ist der genaue Gerätename **oder** ein beliebiger Teil der Geräte-UID. `get`, `set` und `toggle` geben den Zustand danach aus: `1` ist stumm, `0` ist hörbar.

Die Ausgabe von `lbmute list` sieht so aus (Name, UID, Stumm-Zustand; `-` heißt: das Gerät hat keine Eingangs-Stummschaltung):

```
Elgato Wave:3 | AppleUSBAudioEngine:Elgato Systems:Elgato Wave:3:…:2,1 | inputMute:0
ChatGPT-Mikro | com.rogueamoeba.Loopback::DF6F7BF0-… | inputMute:0
Multiausgangsgerät | ~:AMS2_StackedOutput:0 | inputMute:-
```

Exit-Codes: `0` Erfolg, `1` Gerät nicht gefunden, keine Stummschaltung vorhanden oder Setzen fehlgeschlagen, `2` falsche Benutzung. Fehlermeldungen gehen nach stderr.

Ein UID-Teil hilft, wenn zwei Geräte denselben Namen haben:

```bash
lbmute DF6F7BF0 get
```

## Beispiel: Sprachchat stumm, solange du diktierst

### 1. Virtuelles Gerät in Loopback anlegen

1. In Loopback ein neues virtuelles Gerät anlegen, zum Beispiel `ChatGPT-Mikro`.
2. **Nur dein echtes Mikrofon** als Quelle hinzufügen.
3. In der Sprachchat-App `ChatGPT-Mikro` als Mikrofon wählen.
4. Das Diktierprogramm bleibt am **echten** Mikrofon.

Prüfen, ob `lbmute` das Gerät sieht:

```bash
lbmute list | grep ChatGPT-Mikro
# ChatGPT-Mikro | com.rogueamoeba.Loopback::… | inputMute:0
```

### 2. An das Diktierprogramm anbinden

Jedes Programm, das beim Start und beim Ende einer Aufnahme einen Befehl ausführen kann, taugt dafür. Mit [TorroWhisper](https://github.com/mahype/TorroWhisper) (Einstellungen → Aufnahme → Befehle, sobald dessen Aufnahme-Befehle veröffentlicht sind):

| Feld | Befehl |
| --- | --- |
| Bei Aufnahmebeginn ausführen | `~/bin/lbmute ChatGPT-Mikro set 1` |
| Bei Aufnahmeende ausführen | `~/bin/lbmute ChatGPT-Mikro set 0` |

Weil das Programm den echten Aufnahmezustand meldet, läuft das Wiederhörbarschalten auch bei Abbruch, Fehler und Beenden der App. Der Sprachchat bleibt also nie stumm hängen.

### 3. Oder von der Shell

```bash
lbmute ChatGPT-Mikro set 1
# … diktieren …
lbmute ChatGPT-Mikro set 0
```

In einem Skript den vorgefundenen Zustand wiederherstellen, statt pauschal `0` zu setzen:

```bash
vorher=$(lbmute ChatGPT-Mikro get)
lbmute ChatGPT-Mikro set 1
# … etwas tun …
lbmute ChatGPT-Mikro set "$vorher"
```

## Gemessen

Pegelmessung mit `ffmpeg` (`volumedetect`) am virtuellen Gerät, gleiche Spracheingabe:

| Zustand | Mittlerer Pegel |
| --- | --- |
| hörbar | etwa −31 dB |
| stumm | etwa −91 dB |

Das echte Mikrofon nahm dabei unverändert weiter auf.

## Hinweise und Grenzen

- Der Stummschalter gehört zum Gerät, nicht zu einem Prozess. Jede App, die dieses Gerät nutzt, ist gemeinsam stumm.
- Der Zustand wird nicht gespeichert: Nach einem Neustart von Loopback oder des Rechners sind die Geräte wieder hörbar.
- `lbmute` ändert nur das Stumm-Flag. Es legt keine Geräte an, ändert oder löscht keine.
- Keine Verbindung zu Rogue Amoeba. Loopback ist ein Produkt von Rogue Amoeba Software, LLC.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
