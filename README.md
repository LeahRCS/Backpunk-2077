<div align="center">

# 🩺 Backpunk-2077

### *Backup, migrate and restore your modded Cyberpunk 2077 setup without performing open-heart surgery on Night City.*

[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?style=for-the-badge&logo=linux&logoColor=black)](#-requirements)
[![Steam](https://img.shields.io/badge/Steam-Proton-1B2838?style=for-the-badge&logo=steam&logoColor=white)](#-automatic-detection)
[![Bash](https://img.shields.io/badge/Bash-4%2B-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

[![Smoke Test](https://github.com/LeahRCS/Backpunk-2077/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/LeahRCS/Backpunk-2077/actions/workflows/smoke-test.yml)

**One Bash script for backups, migrations, restores and SHA-256 integrity checks — designed around heavily modded Cyberpunk 2077 installations on Linux/Proton.**

[✨ Features](#-what-it-does) · [📦 What gets backed up](#-what-gets-backed-up) · [🚀 Quick start](#-quick-start) · [🛡️ Safety model](#️-safety-model) · [🤝 Contributing](#-contributing)

</div>

---

## 📖 Why this exists

A vanilla Cyberpunk 2077 reinstall is easy.

A modded one with **Archive mods, RED4ext, redscript, TweakXL, ArchiveXL, Cyber Engine Tweaks, REDmods, custom inputs, keybinds and a Proton prefix full of saves/settings** is... considerably less cute.

**Backpunk-2077** creates a portable snapshot of the important parts, verifies it with SHA-256, and can later put those files back in the correct places.

The goal is not to be only clever. The goal is to be **precise, explicit, maybe a little paranoid and definitely difficult to misuse**.

> **The ideal backup tool is the one you only remember exists after your SSD dies.**

---

## ✨ What it does

| Feature | What happens in practice |
| --- | --- |
| 🔎 **Steam discovery** | Finds native Steam and Flatpak Steam installations |
| 💽 **Multiple libraries** | Reads `libraryfolders.vdf`, including secondary SSDs/libraries |
| 🍷 **Proton awareness** | Locates Cyberpunk's AppID `1091500` prefix |
| 💾 **Personal data** | Saves, `UserSettings.json`, local settings and keybind-related data |
| 🧩 **Mod ecosystem** | Archives, REDmods, RED4ext, redscript, tweaks, CET, inputs and more |
| 🔗 **Portable symlinks** | Dereferences deployed symlinks into real files inside the snapshot |
| 🔐 **SHA-256** | Backup is hashed and verified before it gets its final name |
| 🛟 **PRE_RESTORE** | Makes a safety snapshot before restoration by default |
| 📥 **Additive restore** | Overwrites matching files, but never deletes destination-only files |
| 🧪 **Post-restore validation** | Re-hashes restored files and compares them to the backup |
| 🧯 **Conservative `bin/x64`** | Full `bin/x64` restore is optional instead of being the default sledgehammer |

---

## 📦 What gets backed up

### 👤 Saves, settings and binds

Inside the Proton prefix:

```text
Saved Games/CD Projekt Red/Cyberpunk 2077
AppData/Local/CD Projekt Red/Cyberpunk 2077
AppData/Local/REDEngine
```

That includes the game's `UserSettings.json`, where Cyberpunk stores important user settings and keybind-related preferences.

Valve documents Proton's per-game Wine prefixes under:

```text
steamapps/compatdata/<appid>/pfx
```

Backpunk-2077 uses Cyberpunk 2077's Steam AppID:

```text
1091500
```

### 🧩 Mods and frameworks

From the Cyberpunk 2077 game directory:

```text
archive/pc/mod
mods
red4ext
r6/scripts
r6/tweaks
r6/config
r6/input
r6/inputs
engine/config/platform/pc
engine/tools
V2077
plugins
bin/x64/plugins
```

Known loader/proxy files are also included when present:

```text
bin/x64/d3d11.dll
bin/x64/global.ini
bin/x64/powrprof.dll
bin/x64/winmm.dll
bin/x64/version.dll
```

### Why both `r6/input` **and** `r6/inputs`?

Because Cyberpunk modding has successfully found a way to make one letter matter.

- **Input Loader** explicitly consumes custom XMLs from `r6/input/*.xml`.
- CDPR's modding troubleshooting documentation also treats `r6/inputs` as a potentially modified directory.

So the script preserves both when they exist.

### Intentionally not treated as essential

```text
r6/cache/modded
```

Generated caches should be rebuilt, not treated as precious family heirlooms.

The Steam `appmanifest_1091500.acf` is included **for reference only** and is never automatically restored.

---

## 🔎 Automatic detection

The script checks common Linux Steam roots, including:

```text
~/.local/share/Steam
~/.steam/steam
~/.var/app/com.valvesoftware.Steam/.local/share/Steam
~/.var/app/com.valvesoftware.Steam/.steam/steam
```

It then reads:

```text
steamapps/libraryfolders.vdf
```

and searches the discovered libraries for:

```text
steamapps/appmanifest_1091500.acf
```

This means an installation such as:

```text
/mnt/Games/SteamLibrary/steamapps/common/Cyberpunk 2077
```

can be found without assuming that the game lives in your home directory.

If detection fails, paths can be supplied manually.

---

## 🚀 Quick start

Clone:

```bash
git clone https://github.com/LeahRCS/Backpunk-2077.git
cd Backpunk-2077
```

Run:

```bash
chmod +x backpunk.sh
bash backpunk.sh
```

> Using Fish or Zsh as your interactive shell is completely fine.  
> The script itself is Bash, so run it with `bash backpunk.sh`.

### Menu

```text
1) Backup + integrity verification
2) Restore + post-copy validation
3) Verify an existing backup
4) Re-scan / show detected environment
0) Exit
```

Default backup directory:

```text
~/Backpunk2077_Backups
```

---

## 🗂️ Backup layout

Every completed snapshot is self-describing:

```text
Backpunk2077_YYYY-MM-DD_HH-MM-SS/
├── personal/
│   ├── Saves/
│   └── AppData/
├── game/
│   ├── archive/
│   ├── bin/
│   ├── engine/
│   ├── mods/
│   ├── r6/
│   ├── red4ext/
│   └── ...
├── advanced/                 # only if requested
├── reference/
├── INFO.txt
├── LAYOUT.tsv
├── SHA256SUMS.txt
└── backpunk.sh
```

The utility copies **itself** into the snapshot before hashing it.

So Future You can find an old backup, enter its directory, and still have the tool that knows how to verify/restore it.

A little gift from Past You, who for once planned ahead.

---

## 🛡️ Safety model

This project is intentionally paranoid.

### Backup

```text
Detect paths
    ↓
Check game is closed
    ↓
Estimate required disk space
    ↓
Create temporary snapshot
    ↓
Copy files
    ↓
Generate SHA256SUMS.txt
    ↓
Verify every hash
    ↓
Only then give the backup its final name
```

### Restore

```text
Select backup
    ↓
Verify SHA-256 BEFORE touching the game
    ↓
Show detected destination paths
    ↓
Require confirmation
    ↓
Create PRE_RESTORE safety backup
    ↓
Restore additively
    ↓
Hash destination files again
    ↓
Report success only if validation passes
```

### Things the script deliberately does **not** do

- no `rm`;
- no `rm -rf`;
- no mirroring/deleting files that exist only in the destination;
- no blind appmanifest replacement;
- no automatic full `bin/x64` overwrite;
- no claim that "hash matched" means "this 2024 mod definitely works on the current game build".

**Integrity and compatibility are different problems.**

---

## 🧠 About `bin/x64`

This directory deserves special treatment because it can contain both game files and framework/loader files.

The normal backup captures:

```text
bin/x64/plugins
```

plus known proxy/loader files when present.

A **complete `bin/x64` snapshot** is available as an advanced opt-in:

```bash
bash backpunk.sh --backup --include-full-bin
```

After a major Cyberpunk update, restoring an old full `bin/x64` can be a fantastic way to convert a working game into a very expensive desktop shortcut.

Use the safe mode unless you know why you need the full one.

---

## ⌨️ CLI / advanced usage

### Scan only

```bash
bash backpunk.sh --scan
```

### Backup

```bash
bash backpunk.sh --backup
```

### Backup + complete `bin/x64`

```bash
bash backpunk.sh --backup --include-full-bin
```

### Verify an existing snapshot

```bash
bash backpunk.sh --verify "$HOME/Backpunk2077_Backups/Backpunk2077_YYYY-MM-DD_HH-MM-SS"
```

### Restore

```bash
bash backpunk.sh --restore "/path/to/backup"
```

### Manual path overrides

```bash
bash backpunk.sh \
  --game-dir "/mnt/Games/SteamLibrary/steamapps/common/Cyberpunk 2077" \
  --prefix-dir "/mnt/Games/SteamLibrary/steamapps/compatdata/1091500/pfx"
```

Environment variables are also supported:

```text
BACKPUNK_GAME_DIR
BACKPUNK_PREFIX_DIR
BACKPUNK_BACKUP_ROOT
BACKPUNK_STEAM_ROOTS
```

`BACKPUNK_STEAM_ROOTS` accepts a colon-separated list of additional Steam roots.

---

## 🔗 Mod managers and symlinks

Backpunk-2077 snapshots the **deployed game state**.

If a deployed mod is a symlink to some Vortex/MO2 staging directory, the script dereferences that link and stores the actual contents in the backup.

That makes the snapshot more portable.

However, it does **not** attempt to back up every mod manager's:

- download cache;
- profile database;
- staging metadata;
- load-order UI state;
- application configuration outside the game directory.

If reproducing the mod manager itself matters to you, back up its own profile/data separately.

---

## 🧪 Tests

Run the local smoke test:

```bash
bash tests/smoke-test.sh
```

It builds a fake Steam/Cyberpunk/Proton tree under `/tmp` and checks:

1. Steam library discovery;
2. backup creation;
3. SHA-256 verification;
4. restore + post-copy validation;
5. intentional corruption detection.

It does **not** touch your real Cyberpunk installation.

GitHub Actions runs the same smoke test on every push and pull request.

---

## 📚 Path references

The path choices are based on upstream/project documentation rather than vibes:

- [ValveSoftware/Proton — Proton FAQ](https://github.com/ValveSoftware/Proton/wiki/Proton-FAQ)
- [CDPR Modding Documentation — troubleshooting/reset paths](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs)
- [CDPR Modding Documentation — REDmod usage](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Modding-Docs)
- [RED4ext — installation / plugins / proxy DLLs](https://docs.red4ext.com/)
- [Cyber Engine Tweaks](https://github.com/maximegmd/CyberEngineTweaks)
- [Cyberpunk 2077 Input Loader](https://github.com/jackhumbert/cyberpunk2077-input-loader)
- [redscript](https://github.com/jac3km4/redscript)

---

## 🤝 Contributing

Found a weird Steam library layout? A framework started using a new persistent directory? Flatpak decided to become even more creative?

Issues and pull requests are welcome.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a patch.

Especially useful contributions:

- Steam Deck / Flatpak edge cases;
- unusual secondary-library layouts;
- new **well-established** mod/framework paths;
- regression tests;
- safe support for other launchers in the future.

For new backup locations, please provide an upstream/framework/CDPR source whenever possible.

---

## ⚠️ Scope

Currently targeted:

- Linux;
- Steam;
- Proton;
- native Steam and Flatpak Steam.

Not automatically supported yet:

- GOG via Wine;
- Heroic;
- Lutris;
- Epic;
- native macOS;
- Windows.

Manual path overrides may make some unusual layouts usable, but **Steam/Proton is the supported discovery model for now**.

---

## 📜 License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

Built with an unreasonable amount of caution by **[Leah R.C.S.](https://github.com/LeahRCS)**.

<sub>Because reinstalling 150 mods manually is character building, but nobody asked for that character arc.</sub>

</div>
