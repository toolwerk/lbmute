# lbmute

[![macOS](https://img.shields.io/badge/macOS-Core%20Audio-000000?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white)](Sources/lbmute.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

[Deutsch](README.md) · **English**

A tiny macOS command-line tool that **mutes and unmutes the input of one audio device** — without touching the physical microphone behind it.

```bash
lbmute ChatGPT-Mikro set 1   # that device now delivers silence
lbmute ChatGPT-Mikro set 0   # audible again
```

Virtual devices, such as those created with [Loopback](https://rogueamoeba.com/loopback/) by Rogue Amoeba, expose a Core Audio mute control on their input side. `lbmute` reads and sets it. Loopback itself has no scripting interface (no AppleScript, no URL scheme, no Shortcuts action); this control is the one hook that can be driven from outside.

## Why

One microphone, two consumers, and only one of them should hear you.

Typical case: you dictate into a text field while a voice chat runs in another app. The voice chat must not hear the dictation, but the dictation tool still needs the microphone. Muting the real microphone silences both. Muting a **virtual device that only the voice chat uses** silences only the voice chat.

```
real microphone ──┬──────────────────────► dictation tool (keeps hearing you)
                  └─► virtual device ────► voice chat     (lbmute mutes this one)
```

## Requirements

- macOS (Core Audio). Developed on macOS 26.
- Xcode command line tools (`swiftc`) to build.
- A device that exposes an input mute control. Loopback virtual devices do; many physical microphones do not. `lbmute list` shows which.

## Build and install

```bash
git clone https://github.com/toolwerk/lbmute.git
cd lbmute
make install            # builds and copies to ~/bin/lbmute
make install PREFIX=/usr/local/bin   # or another location
```

`make` alone builds `./lbmute` in the repository.

## Usage

```
lbmute list                  list all audio devices with their input mute state
lbmute <device> get          print the mute state
lbmute <device> set 0|1      set the mute state and print it
lbmute <device> toggle       flip the mute state and print it
```

`<device>` is the exact device name **or** any part of the device UID. `get`, `set` and `toggle` print the resulting state: `1` is muted, `0` is audible.

`lbmute list` output looks like this (name, UID, mute state; `-` means the device has no input mute control):

```
Elgato Wave:3 | AppleUSBAudioEngine:Elgato Systems:Elgato Wave:3:…:2,1 | inputMute:0
ChatGPT-Mikro | com.rogueamoeba.Loopback::DF6F7BF0-… | inputMute:0
Multiausgangsgerät | ~:AMS2_StackedOutput:0 | inputMute:-
```

Exit codes: `0` success, `1` device not found / no mute control / could not set, `2` wrong usage. Errors go to stderr.

Use a UID part when two devices share a name, or when the name contains characters that are awkward to type:

```bash
lbmute DF6F7BF0 get
```

## Example: silence a voice chat while dictating

### 1. Create the virtual device in Loopback

1. In Loopback, add a new virtual device and name it, for example, `ChatGPT-Mikro`.
2. Add **only your real microphone** as its source.
3. In the voice-chat app, pick `ChatGPT-Mikro` as its microphone input.
4. Keep the dictation tool on the **real** microphone.

Check that `lbmute` sees it:

```bash
lbmute list | grep ChatGPT-Mikro
# ChatGPT-Mikro | com.rogueamoeba.Loopback::… | inputMute:0
```

### 2. Hook it to the dictation tool

Any tool that can run a command at the start and end of a recording works. With [TorroWhisper](https://github.com/mahype/TorroWhisper) (settings → *Aufnahme* / *Recording* → *Commands*, available once its recording hooks are released):

| Field | Command |
| --- | --- |
| Run when recording starts | `~/bin/lbmute ChatGPT-Mikro set 1` |
| Run when recording ends | `~/bin/lbmute ChatGPT-Mikro set 0` |

Because the tool reports the real recording state, the unmute also runs when a recording is cancelled, fails or the app quits, so the voice chat is never left muted.

### 3. Or from the shell

```bash
lbmute ChatGPT-Mikro set 1
# … dictate …
lbmute ChatGPT-Mikro set 0
```

In a script, restore the state you found instead of forcing `0`:

```bash
before=$(lbmute ChatGPT-Mikro get)
lbmute ChatGPT-Mikro set 1
# … do the thing …
lbmute ChatGPT-Mikro set "$before"
```

## Measured

A level measurement with `ffmpeg` (`volumedetect`) on the virtual device, same spoken input:

| State | Mean level |
| --- | --- |
| audible | about −31 dB |
| muted | about −91 dB |

while the real microphone kept recording unchanged.

## Notes and limits

- The mute is a property of the device, not of a process. Every app using that device is muted together.
- State is not persisted: after a restart of Loopback or a reboot, devices start audible again.
- `lbmute` only changes the mute flag. It does not create, change or remove devices.
- No relation to Rogue Amoeba. Loopback is a product of Rogue Amoeba Software, LLC.

## License

MIT, see [LICENSE](LICENSE).
