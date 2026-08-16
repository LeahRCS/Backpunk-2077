#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(mktemp -d /tmp/backpunk-2077-test.XXXXXX)"
HOME_FAKE="$ROOT/home/tester"
STEAM="$HOME_FAKE/.local/share/Steam"
LIB="$ROOT/Games/SteamLibrary"
GAME="$LIB/steamapps/common/Cyberpunk 2077"
PFX="$LIB/steamapps/compatdata/1091500/pfx"
WIN="$PFX/drive_c/users/steamuser"
BACKUPS="$ROOT/backups"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/backpunk.sh"

mkdir -p "$STEAM/steamapps" "$LIB/steamapps" "$GAME" "$WIN"

cat > "$STEAM/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
    "0"
    {
        "path" "$STEAM"
    }
    "1"
    {
        "path" "$LIB"
    }
}
EOF

cat > "$LIB/steamapps/appmanifest_1091500.acf" <<'EOF'
"AppState"
{
    "appid" "1091500"
    "name" "Cyberpunk 2077"
    "installdir" "Cyberpunk 2077"
}
EOF

mkdir -p \
  "$WIN/Saved Games/CD Projekt Red/Cyberpunk 2077/ManualSave-0" \
  "$WIN/AppData/Local/CD Projekt Red/Cyberpunk 2077" \
  "$GAME/archive/pc/mod" \
  "$GAME/r6/scripts" \
  "$GAME/r6/tweaks" \
  "$GAME/r6/input" \
  "$GAME/r6/inputs" \
  "$GAME/red4ext/plugins/TestPlugin" \
  "$GAME/bin/x64/plugins/cyber_engine_tweaks"

printf 'save-data\n' > "$WIN/Saved Games/CD Projekt Red/Cyberpunk 2077/ManualSave-0/sav.dat"
printf '{"settings":true}\n' > "$WIN/AppData/Local/CD Projekt Red/Cyberpunk 2077/UserSettings.json"
printf 'archive\n' > "$GAME/archive/pc/mod/example.archive"
printf 'script\n' > "$GAME/r6/scripts/example.reds"
printf 'tweak\n' > "$GAME/r6/tweaks/example.yaml"
printf 'input-loader\n' > "$GAME/r6/input/example.xml"
printf 'inputs-data\n' > "$GAME/r6/inputs/example.xml"
printf 'plugin\n' > "$GAME/red4ext/plugins/TestPlugin/TestPlugin.dll"
printf '{"bind":"F1"}\n' > "$GAME/bin/x64/plugins/cyber_engine_tweaks/bindings.json"

echo "[1/5] scan"
HOME="$HOME_FAKE" BACKPUNK_BACKUP_ROOT="$BACKUPS" \
  bash "$SCRIPT" --scan | grep -F "$GAME" >/dev/null

echo "[2/5] backup"
HOME="$HOME_FAKE" BACKPUNK_BACKUP_ROOT="$BACKUPS" \
  bash "$SCRIPT" --backup >/dev/null

BACKUP="$(find "$BACKUPS" -mindepth 1 -maxdepth 1 -type d -name 'Backpunk2077_*' | head -n1)"
[[ -n "$BACKUP" ]]

echo "[3/5] verify"
HOME="$HOME_FAKE" bash "$SCRIPT" --verify "$BACKUP" >/dev/null

echo "[4/5] restore + post-copy validation"
printf 'BROKEN-SAVE\n' > "$WIN/Saved Games/CD Projekt Red/Cyberpunk 2077/ManualSave-0/sav.dat"
printf 'BROKEN-ARCHIVE\n' > "$GAME/archive/pc/mod/example.archive"

HOME="$HOME_FAKE" BACKPUNK_BACKUP_ROOT="$BACKUPS" \
  bash "$SCRIPT" \
    --restore "$BACKUP" \
    --profile all \
    --bin safe \
    --assume-yes \
    --skip-pre-restore >/dev/null

grep -Fx 'save-data' "$WIN/Saved Games/CD Projekt Red/Cyberpunk 2077/ManualSave-0/sav.dat" >/dev/null
grep -Fx 'archive' "$GAME/archive/pc/mod/example.archive" >/dev/null

echo "[5/5] corruption detection"
printf 'CORRUPTED\n' >> "$BACKUP/game/archive/pc/mod/example.archive"
if HOME="$HOME_FAKE" bash "$SCRIPT" --verify "$BACKUP" >/dev/null 2>&1; then
    echo "ERROR: corruption was not detected"
    exit 1
fi

echo "PASS: discovery, backup, verification, restore validation, and corruption detection"
echo "Temporary test tree: $ROOT"
