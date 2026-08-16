#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.0"
APPID="1091500"
BACKUP_ROOT="${BACKPUNK_BACKUP_ROOT:-$HOME/Backpunk2077_Backups}"

GAME="${BACKPUNK_GAME_DIR:-}"
PFX="${BACKPUNK_PREFIX_DIR:-}"
WINHOME=""
SAVES=""
SETTINGS=""
REDENGINE=""
STEAMAPPS=""
MANIFEST=""

ASSUME_YES=0
SKIP_PRE_RESTORE=0
INCLUDE_FULL_BIN=0
PROFILE="all"
BIN_MODE="safe"

ok(){ printf '✅ %s\n' "$*"; }
warn(){ printf '⚠️  %s\n' "$*"; }
die(){ printf '❌ %s\n' "$*" >&2; exit 1; }

usage() {
cat <<EOF
Backpunk-2077 v$VERSION

Usage:
  bash backpunk.sh
  bash backpunk.sh --scan
  bash backpunk.sh --backup [--include-full-bin]
  bash backpunk.sh --verify BACKUP
  bash backpunk.sh --restore BACKUP [--profile all|personal|mods] [--bin safe|full|skip]

Overrides:
  --game-dir PATH
  --prefix-dir PATH
  --backup-root PATH
  --skip-pre-restore
  --assume-yes
EOF
}

need_tools() {
  local c
  for c in cp mkdir mktemp mv find sort sha256sum du df awk sed grep readlink basename dirname pgrep; do
    command -v "$c" >/dev/null 2>&1 || die "Missing required command: $c"
  done
}

canon(){ readlink -f -- "$1" 2>/dev/null || printf '%s\n' "$1"; }

steam_roots() {
  local roots=(
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
    "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
  )
  local r
  if [[ -n "${BACKPUNK_STEAM_ROOTS:-}" ]]; then
    IFS=: read -r -a extra <<< "$BACKPUNK_STEAM_ROOTS"
    roots+=("${extra[@]}")
  fi
  for r in "${roots[@]}"; do [[ -d "$r/steamapps" ]] && canon "$r"; done | awk '!seen[$0]++'
}

libraries() {
  local root p
  while IFS= read -r root; do
    printf '%s\n' "$root"
    [[ -f "$root/steamapps/libraryfolders.vdf" ]] || continue
    awk -F'"' '/"path"/ {for(i=1;i<=NF;i++) if($i=="path"){print $(i+2);break}}' \
      "$root/steamapps/libraryfolders.vdf" | sed 's/\\\\/\\/g'
  done < <(steam_roots) | while IFS= read -r p; do
    [[ -d "$p/steamapps" ]] && canon "$p"
  done | awk '!seen[$0]++'
}

detect_game() {
  [[ -n "$GAME" ]] && { GAME="$(canon "$GAME")"; return; }

  local lib mf dir found=()
  while IFS= read -r lib; do
    mf="$lib/steamapps/appmanifest_${APPID}.acf"
    [[ -f "$mf" ]] || continue
    dir="$(awk -F'"' '/"installdir"/ {for(i=1;i<=NF;i++) if($i=="installdir"){print $(i+2);exit}}' "$mf")"
    [[ -n "$dir" ]] || dir="Cyberpunk 2077"
    [[ -d "$lib/steamapps/common/$dir" ]] && found+=("$lib/steamapps/common/$dir")
  done < <(libraries)

  (( ${#found[@]} )) || return 1
  if (( ${#found[@]} > 1 )); then
    echo "Multiple installations found:"
    local i
    for i in "${!found[@]}"; do printf '  %d) %s\n' "$((i+1))" "${found[$i]}"; done
    read -r -p "Choose: " i
    GAME="${found[$((i-1))]}"
  else
    GAME="${found[0]}"
  fi
  GAME="$(canon "$GAME")"
}

detect_prefix() {
  [[ -n "$PFX" ]] && { PFX="$(canon "$PFX")"; return; }

  if [[ "$(basename "$(dirname "$GAME")")" == common ]]; then
    STEAMAPPS="$(dirname "$(dirname "$GAME")")"
    MANIFEST="$STEAMAPPS/appmanifest_${APPID}.acf"
    [[ -d "$STEAMAPPS/compatdata/$APPID/pfx" ]] && PFX="$STEAMAPPS/compatdata/$APPID/pfx"
  fi

  if [[ -z "$PFX" ]]; then
    local lib p
    while IFS= read -r lib; do
      p="$lib/steamapps/compatdata/$APPID/pfx"
      [[ -d "$p" ]] && { PFX="$p"; break; }
    done < <(libraries)
  fi
  [[ -n "$PFX" ]] && PFX="$(canon "$PFX")"
}

detect_winhome() {
  [[ -d "$PFX/drive_c/users/steamuser" ]] && WINHOME="$PFX/drive_c/users/steamuser"
  if [[ -z "$WINHOME" && -d "$PFX/drive_c/users" ]]; then
    local d
    while IFS= read -r -d '' d; do
      case "$(basename "$d")" in Public|Default|"Default User"|"All Users") continue;; esac
      WINHOME="$d"; break
    done < <(find "$PFX/drive_c/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
  [[ -n "$WINHOME" ]] || return
  SAVES="$WINHOME/Saved Games/CD Projekt Red/Cyberpunk 2077"
  SETTINGS="$WINHOME/AppData/Local/CD Projekt Red/Cyberpunk 2077"
  REDENGINE="$WINHOME/AppData/Local/REDEngine"
}

resolve() {
  detect_game || die "Cyberpunk 2077 not found. Use --game-dir PATH."
  detect_prefix
  [[ -n "$PFX" ]] && detect_winhome || true
}

show_env() {
cat <<EOF

Detected environment
--------------------
Game:       ${GAME:-<not found>}
Proton pfx: ${PFX:-<not found>}
Windows:    ${WINHOME:-<not found>}
Saves:      ${SAVES:-<not found>}
Settings:   ${SETTINGS:-<not found>}
Backups:    $BACKUP_ROOT

EOF
}

running() { pgrep -fi 'Cyberpunk2077(\.exe)?' >/dev/null 2>&1; }

copy_snap() {
  local src="$1" dst="$2"
  [[ -e "$src" || -L "$src" ]] || return 1
  mkdir -p -- "$(dirname "$dst")"
  cp -aL -- "$src" "$dst"
}

build_map() {
  MAP=()
  [[ -n "$SAVES" ]] && MAP+=("$SAVES"$'\t'"personal/Saves/Cyberpunk 2077"$'\t'"personal"$'\t'"saves")
  [[ -n "$SETTINGS" ]] && MAP+=("$SETTINGS"$'\t'"personal/AppData/Local/CD Projekt Red/Cyberpunk 2077"$'\t'"personal"$'\t'"settings")
  [[ -n "$REDENGINE" ]] && MAP+=("$REDENGINE"$'\t'"personal/AppData/Local/REDEngine"$'\t'"personal"$'\t'"redengine")
  MAP+=(
    "$GAME/archive/pc/mod"$'\t'"game/archive/pc/mod"$'\t'"mods"$'\t'"archive"
    "$GAME/mods"$'\t'"game/mods"$'\t'"mods"$'\t'"redmod"
    "$GAME/red4ext"$'\t'"game/red4ext"$'\t'"mods"$'\t'"red4ext"
    "$GAME/r6/scripts"$'\t'"game/r6/scripts"$'\t'"mods"$'\t'"r6scripts"
    "$GAME/r6/tweaks"$'\t'"game/r6/tweaks"$'\t'"mods"$'\t'"r6tweaks"
    "$GAME/r6/config"$'\t'"game/r6/config"$'\t'"mods"$'\t'"r6config"
    "$GAME/r6/input"$'\t'"game/r6/input"$'\t'"mods"$'\t'"r6input"
    "$GAME/r6/inputs"$'\t'"game/r6/inputs"$'\t'"mods"$'\t'"r6inputs"
    "$GAME/engine/config/platform/pc"$'\t'"game/engine/config/platform/pc"$'\t'"mods"$'\t'"enginepc"
    "$GAME/engine/tools"$'\t'"game/engine/tools"$'\t'"mods"$'\t'"enginetools"
    "$GAME/V2077"$'\t'"game/V2077"$'\t'"mods"$'\t'"v2077"
    "$GAME/plugins"$'\t'"game/plugins"$'\t'"mods"$'\t'"plugins"
    "$GAME/bin/x64/plugins"$'\t'"game/bin/x64/plugins"$'\t'"mods"$'\t'"binplugins"
  )
  local f
  for f in d3d11.dll global.ini powrprof.dll winmm.dll version.dll; do
    MAP+=("$GAME/bin/x64/$f"$'\t'"game/bin/x64/$f"$'\t'"mods"$'\t'"binfile")
  done
  if (( INCLUDE_FULL_BIN )); then
    MAP+=("$GAME/bin/x64"$'\t'"advanced/full-bin-x64"$'\t'"advanced"$'\t'"fullbin")
  fi
}

write_meta() {
  local root="$1"
  cat > "$root/INFO.txt" <<EOF
Backpunk-2077 v$VERSION
Created: $(date)
Game: $GAME
Proton prefix: ${PFX:-unavailable}
Windows user dir: ${WINHOME:-unavailable}

Restore is additive: matching files may be overwritten; destination-only files are never deleted.
A successful SHA-256 check proves copy integrity, not mod compatibility with a newer game build.
EOF
  {
    printf '%s\t%s\t%s\n' 'backup_path' 'class' 'kind'
    printf '%s\t%s\t%s\n' 'personal/Saves/Cyberpunk 2077' 'personal' 'saves'
    printf '%s\t%s\t%s\n' 'personal/AppData/Local/CD Projekt Red/Cyberpunk 2077' 'personal' 'settings'
    printf '%s\t%s\t%s\n' 'personal/AppData/Local/REDEngine' 'personal' 'redengine'
    printf '%s\t%s\t%s\n' 'game/archive/pc/mod' 'mods' 'archive'
    printf '%s\t%s\t%s\n' 'game/mods' 'mods' 'redmod'
    printf '%s\t%s\t%s\n' 'game/red4ext' 'mods' 'red4ext'
    printf '%s\t%s\t%s\n' 'game/r6/scripts' 'mods' 'r6scripts'
    printf '%s\t%s\t%s\n' 'game/r6/tweaks' 'mods' 'r6tweaks'
    printf '%s\t%s\t%s\n' 'game/r6/config' 'mods' 'r6config'
    printf '%s\t%s\t%s\n' 'game/r6/input' 'mods' 'r6input'
    printf '%s\t%s\t%s\n' 'game/r6/inputs' 'mods' 'r6inputs'
    printf '%s\t%s\t%s\n' 'game/engine/config/platform/pc' 'mods' 'enginepc'
    printf '%s\t%s\t%s\n' 'game/engine/tools' 'mods' 'enginetools'
    printf '%s\t%s\t%s\n' 'game/V2077' 'mods' 'v2077'
    printf '%s\t%s\t%s\n' 'game/plugins' 'mods' 'plugins'
    printf '%s\t%s\t%s\n' 'game/bin/x64/plugins' 'mods' 'binplugins'
    printf '%s\t%s\t%s\n' 'game/bin/x64/d3d11.dll' 'mods' 'binfile'
    printf '%s\t%s\t%s\n' 'game/bin/x64/global.ini' 'mods' 'binfile'
    printf '%s\t%s\t%s\n' 'game/bin/x64/powrprof.dll' 'mods' 'binfile'
    printf '%s\t%s\t%s\n' 'game/bin/x64/winmm.dll' 'mods' 'binfile'
    printf '%s\t%s\t%s\n' 'game/bin/x64/version.dll' 'mods' 'binfile'
    printf '%s\t%s\t%s\n' 'advanced/full-bin-x64' 'advanced' 'fullbin'
  } > "$root/LAYOUT.tsv"
  [[ -f "$0" ]] && cp -a -- "$0" "$root/backpunk.sh"
  (cd "$root"; find . -type f ! -name SHA256SUMS.txt -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS.txt)
}

verify_backup() {
  local b="$1"
  [[ -f "$b/SHA256SUMS.txt" ]] || { warn "Missing SHA256SUMS.txt"; return 1; }
  (cd "$b" && sha256sum -c --quiet SHA256SUMS.txt) || return 1
  ok "Backup integrity verified."
}

make_backup() {
  local label="${1:-Backpunk2077}"
  resolve
  running && die "Cyberpunk appears to be running. Close it first."
  mkdir -p -- "$BACKUP_ROOT"
  build_map

  local stamp tmp final rec src rel class kind
  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  tmp="$(mktemp -d "$BACKUP_ROOT/.${label}_${stamp}.partial.XXXXXX")"
  final="$BACKUP_ROOT/${label}_${stamp}"

  echo "Creating snapshot..."
  for rec in "${MAP[@]}"; do
    IFS=$'\t' read -r src rel class kind <<< "$rec"
    if copy_snap "$src" "$tmp/$rel"; then ok "$rel"; else printf '⚪ %s (not present)\n' "$rel"; fi
  done

  write_meta "$tmp"
  verify_backup "$tmp" || die "Snapshot validation failed. Partial backup kept at: $tmp"
  mv -- "$tmp" "$final"
  ok "Backup completed: $final"
  LAST_BACKUP="$final"
}

dest_for() {
  case "$1" in
    saves) echo "$SAVES";;
    settings) echo "$SETTINGS";;
    redengine) echo "$REDENGINE";;
    archive) echo "$GAME/archive/pc/mod";;
    redmod) echo "$GAME/mods";;
    red4ext) echo "$GAME/red4ext";;
    r6scripts) echo "$GAME/r6/scripts";;
    r6tweaks) echo "$GAME/r6/tweaks";;
    r6config) echo "$GAME/r6/config";;
    r6input) echo "$GAME/r6/input";;
    r6inputs) echo "$GAME/r6/inputs";;
    enginepc) echo "$GAME/engine/config/platform/pc";;
    enginetools) echo "$GAME/engine/tools";;
    v2077) echo "$GAME/V2077";;
    plugins) echo "$GAME/plugins";;
    binplugins) echo "$GAME/bin/x64/plugins";;
    binfile) echo "$GAME/bin/x64";;
    fullbin) echo "$GAME/bin/x64";;
  esac
}

profile_ok() {
  case "$PROFILE:$1" in
    all:personal|all:mods|all:advanced|personal:personal|mods:mods|mods:advanced) return 0;;
    *) return 1;;
  esac
}

verify_tree() {
  local src="$1" dst="$2" f rel h1 h2 fail=0
  if [[ -f "$src" ]]; then
    [[ -f "$dst" ]] || return 1
    [[ "$(sha256sum "$src"|cut -d' ' -f1)" == "$(sha256sum "$dst"|cut -d' ' -f1)" ]]
    return
  fi
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    [[ -f "$dst/$rel" ]] || { fail=1; continue; }
    h1="$(sha256sum "$f"|cut -d' ' -f1)"
    h2="$(sha256sum "$dst/$rel"|cut -d' ' -f1)"
    [[ "$h1" == "$h2" ]] || fail=1
  done < <(find "$src" -type f -print0)
  (( fail == 0 ))
}

restore_one() {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || return
  if [[ -d "$src" ]]; then mkdir -p "$dst"; cp -a "$src"/. "$dst"/
  else mkdir -p "$(dirname "$dst")"; cp -a "$src" "$dst"; fi
  verify_tree "$src" "$dst" || die "Post-restore validation failed: $src"
}

restore_backup() {
  local b="$1"
  resolve
  [[ -d "$PFX" && -n "$WINHOME" ]] || die "Proton prefix not ready. Launch the game once first."
  running && die "Cyberpunk appears to be running. Close it first."
  verify_backup "$b" || die "Backup integrity failed."

  if (( ! ASSUME_YES )); then
    show_env
    read -r -p "Type RESTORE to continue: " x
    [[ "$x" == RESTORE ]] || return
  fi

  if (( ! SKIP_PRE_RESTORE )); then
    warn "Creating PRE_RESTORE safety snapshot..."
    local old="$INCLUDE_FULL_BIN"; INCLUDE_FULL_BIN=0
    make_backup PRE_RESTORE
    INCLUDE_FULL_BIN="$old"
  fi

  local rel class kind src dst
  while IFS=$'\t' read -r rel class kind; do
    [[ "$rel" == backup_path ]] && continue
    profile_ok "$class" || continue
    [[ "$kind" == fullbin && "$BIN_MODE" != full ]] && continue
    [[ ("$kind" == binplugins || "$kind" == binfile) && "$BIN_MODE" == skip ]] && continue
    [[ ("$kind" == binplugins || "$kind" == binfile) && "$BIN_MODE" == full && -e "$b/advanced/full-bin-x64" ]] && continue

    src="$b/$rel"; [[ -e "$src" ]] || continue
    dst="$(dest_for "$kind")"
    [[ "$kind" == binfile ]] && dst="$dst/$(basename "$src")"
    printf '📥 %s\n' "$rel"
    restore_one "$src" "$dst"
  done < "$b/LAYOUT.tsv"

  ok "Restore completed and validated."
}

choose_backup() {
  mapfile -t BKS < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*.partial.*' | sort -r)
  (( ${#BKS[@]} )) || return 1
  local i n
  for i in "${!BKS[@]}"; do printf '%d) %s\n' "$((i+1))" "$(basename "${BKS[$i]}")"; done
  read -r -p "Choose: " n
  SELECTED="${BKS[$((n-1))]}"
}

menu() {
  while true; do
    cat <<EOF

╭──────────────────────────────────────────────╮
│           BACKPUNK-2077 v$VERSION             │
╰──────────────────────────────────────────────╯
1) Backup + verify
2) Restore + validate
3) Verify an existing backup
4) Scan / show paths
0) Exit
EOF
    read -r -p "Choose: " x
    case "$x" in
      1) resolve; show_env; read -r -p "Include full bin/x64? [y/N]: " y; [[ "$y" =~ ^[Yy]$ ]] && INCLUDE_FULL_BIN=1; make_backup;;
      2) resolve; choose_backup || { warn "No backups found."; continue; }; restore_backup "$SELECTED";;
      3) choose_backup && verify_backup "$SELECTED";;
      4) resolve; show_env;;
      0) return;;
    esac
  done
}

MODE="menu"; TARGET=""
while (( $# )); do
  case "$1" in
    --scan) MODE="scan";;
    --backup) MODE="backup";;
    --verify) MODE="verify"; shift; TARGET="${1:-}";;
    --restore) MODE="restore"; shift; TARGET="${1:-}";;
    --game-dir) shift; GAME="${1:-}";;
    --prefix-dir) shift; PFX="${1:-}";;
    --backup-root) shift; BACKUP_ROOT="${1:-}";;
    --profile) shift; PROFILE="${1:-all}";;
    --bin) shift; BIN_MODE="${1:-safe}";;
    --include-full-bin) INCLUDE_FULL_BIN=1;;
    --skip-pre-restore) SKIP_PRE_RESTORE=1;;
    --assume-yes) ASSUME_YES=1;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
  shift
done

need_tools

case "$MODE" in
  menu) menu;;
  scan) resolve; show_env;;
  backup) make_backup;;
  verify) verify_backup "$TARGET";;
  restore) restore_backup "$TARGET";;
esac
