#!/bin/sh
# unroad installer: the ur binary, the roadmap web app and the ur-* skills.
#
#   curl -fsSL https://github.com/mikegorelikoff/unroad/releases/latest/download/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --agent all --version v0.1.0
#   ./install.sh --from-source          # from a checkout: builds with cargo and npm
#
# Options:
#   --version <tag>     release to install (default: latest)          env UR_VERSION
#   --bin <dir>         where to put ur (default: ~/.local/bin)       env UR_INSTALL_DIR
#   --agent <name>      claude, codex or all (default: detected)
#   --target <dir>      install the skills into this folder instead
#   --no-web            skip the web app
#   --no-skills         skip the skills
#   --from-source       build from this checkout instead of downloading
#   --uninstall         remove ur, the web app and the skills (keeps your progress)
#   --purge             with --uninstall: also delete ~/.unroad (your progress)
#   --print-target      print the detected platform and exit
#
# Private or internal repositories: the installer uses `gh` when it is logged in,
# or GITHUB_TOKEN / GH_TOKEN, to download release assets. Every archive is checked
# against the release's SHA256SUMS before anything is installed. No root needed.
set -eu

REPO="${UR_REPO:-mikegorelikoff/unroad}"
BASE="${UR_BASE_URL:-https://github.com/$REPO/releases}"
VERSION="${UR_VERSION:-latest}"
DEST="${UR_INSTALL_DIR:-${HOME:-.}/.local/bin}"
UNROAD_HOME="${UNROAD_HOME:-${HOME:-.}/.unroad}"
AGENT=""
TARGET_DIR=""
WITH_WEB=1
WITH_SKILLS=1
FROM_SOURCE=0
UNINSTALL=0
PURGE=0

# ---------------------------------------------------------------- output

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_SIG=$(printf '\033[38;5;208m'); C_OK=$(printf '\033[32m'); C_ERR=$(printf '\033[31m')
  C_WARN=$(printf '\033[33m'); C_DIM=$(printf '\033[2m'); C_B=$(printf '\033[1m'); C_0=$(printf '\033[0m')
  TTY=1
else
  C_SIG=""; C_OK=""; C_ERR=""; C_WARN=""; C_DIM=""; C_B=""; C_0=""; TTY=0
fi

say() { printf '%s\n' "$*" >&2; }
row() { printf '  %s %s%-10s%s %s\n' "$1" "$C_DIM" "$2" "$C_0" "$3" >&2; }
info() { row "${C_DIM}›${C_0}" "$1" "$2"; }
ok() { [ "$TTY" = 1 ] && printf '\r\033[2K' >&2; row "${C_OK}✓${C_0}" "$1" "$2"; }
warn() { [ "$TTY" = 1 ] && printf '\r\033[2K' >&2; row "${C_WARN}!${C_0}" "$1" "$2"; }
busy() { if [ "$TTY" = 1 ]; then printf '  %s○%s %s%-10s%s %s' "$C_DIM" "$C_0" "$C_DIM" "$1" "$C_0" "$2" >&2; fi; }
die() { [ "$TTY" = 1 ] && printf '\r\033[2K' >&2; row "${C_ERR}✗${C_0}" "error" "$*"; say ""; exit 1; }
header() {
  say ""
  say "  ${C_SIG}${C_B}unroad${C_0} ${C_DIM}installer${C_0}"
  say "  ${C_DIM}skills that teach you to build with AI agents${C_0}"
  say ""
}

# ---------------------------------------------------------------- arguments

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?--version needs a tag}"; shift 2 ;;
    --bin) DEST="${2:?--bin needs a folder}"; shift 2 ;;
    --agent) AGENT="${2:?--agent needs claude, codex or all}"; shift 2 ;;
    --target) TARGET_DIR="${2:?--target needs a folder}"; shift 2 ;;
    --no-web) WITH_WEB=0; shift ;;
    --no-skills) WITH_SKILLS=0; shift ;;
    --from-source) FROM_SOURCE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --purge) PURGE=1; shift ;;
    --print-target) PRINT_TARGET=1; shift ;;
    -h | --help) sed -n '2,24p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option '$1' (see --help)" ;;
  esac
done

detect_target() {
  os=$(uname -s); arch=$(uname -m)
  case "$arch" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *) die "unsupported CPU '$arch' (supported: x86_64, aarch64)" ;;
  esac
  case "$os" in
    Linux) echo "$arch-unknown-linux-musl" ;;
    Darwin) echo "$arch-apple-darwin" ;;
    MINGW* | MSYS* | CYGWIN*) die "on Windows run in PowerShell: irm https://github.com/$REPO/releases/latest/download/install.ps1 | iex" ;;
    *) die "unsupported system '$os' (supported: macOS, Linux, Windows)" ;;
  esac
}

if [ "${PRINT_TARGET:-0}" = 1 ]; then detect_target; exit 0; fi

skill_dirs() {
  if [ -n "$TARGET_DIR" ]; then echo "$TARGET_DIR"; return; fi
  case "$AGENT" in
    claude) echo "$HOME/.claude/skills" ;;
    codex) echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    all) echo "$HOME/.claude/skills"; echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    "")
      found=0
      if [ -d "$HOME/.claude" ]; then echo "$HOME/.claude/skills"; found=1; fi
      if [ -d "${CODEX_HOME:-$HOME/.codex}" ]; then echo "${CODEX_HOME:-$HOME/.codex}/skills"; found=1; fi
      [ "$found" = 1 ] || echo "$HOME/.claude/skills" ;;
    *) die "--agent must be claude, codex or all" ;;
  esac
}

short() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

# ---------------------------------------------------------------- uninstall

if [ "$UNINSTALL" = 1 ]; then
  header
  if [ -x "$DEST/ur" ]; then
    for d in $(skill_dirs); do
      if "$DEST/ur" uninstall --target "$d" >/dev/null 2>&1; then ok "skills" "removed from $(short "$d")"
      else warn "skills" "nothing to remove in $(short "$d")"; fi
    done
    "$DEST/ur" gui --stop >/dev/null 2>&1 || true
    rm -f "$DEST/ur"; ok "ur" "removed $(short "$DEST/ur")"
  else
    warn "ur" "not found in $(short "$DEST")"
  fi
  rm -rf "$UNROAD_HOME/web"; ok "web" "removed"
  if [ "$PURGE" = 1 ]; then rm -rf "$UNROAD_HOME"; ok "progress" "deleted $(short "$UNROAD_HOME")"
  else info "progress" "kept in $(short "$UNROAD_HOME") (add --purge to delete it)"; fi
  say ""; exit 0
fi

# ---------------------------------------------------------------- download helpers

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
USE_GH=0
if [ -n "${UR_BASE_URL:-}" ]; then
  TOKEN=""          # a custom mirror: plain downloads only
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH=1
fi

http_get() { # url, output file, [accept header]
  if command -v curl >/dev/null 2>&1; then
    if [ -n "$TOKEN" ] && [ -n "${3:-}" ]; then
      curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: $3" "$1" -o "$2"
    elif [ -n "$TOKEN" ]; then
      curl -fsSL -H "Authorization: Bearer $TOKEN" "$1" -o "$2"
    else
      curl -fsSL "$1" -o "$2"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -n "$TOKEN" ]; then wget -q --header="Authorization: Bearer $TOKEN" ${3:+--header="Accept: $3"} "$1" -O "$2"
    else wget -q "$1" -O "$2"; fi
  else
    die "need curl or wget"
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
  else die "need sha256sum, shasum or openssl to verify downloads"; fi
}

RELEASE_JSON=""
resolve_tag() {
  if [ "$USE_GH" = 1 ]; then
    if [ "$VERSION" = latest ]; then TAG=$(gh release view -R "$REPO" --json tagName -q .tagName 2>/dev/null) || die "no release found in $REPO"
    else TAG="$VERSION"; fi
  elif [ -n "$TOKEN" ]; then
    RELEASE_JSON="$TMP/release.json"
    if [ "$VERSION" = latest ]; then api="https://api.github.com/repos/$REPO/releases/latest"
    else api="https://api.github.com/repos/$REPO/releases/tags/$VERSION"; fi
    http_get "$api" "$RELEASE_JSON" "application/vnd.github+json" || die "cannot read $api (check GITHUB_TOKEN)"
    TAG=$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$RELEASE_JSON" | head -n 1)
  else
    TAG="$VERSION"
  fi
}

fetch_asset() { # name, output file
  if [ "$USE_GH" = 1 ]; then
    gh release download "$TAG" -R "$REPO" -p "$1" -O "$2" --clobber >/dev/null 2>&1
  elif [ -n "$TOKEN" ]; then
    url=$(awk -v want="$1" '
      /"url": *"https:\/\/api.github.com\/repos\/.*\/releases\/assets\// { gsub(/.*"url": *"|".*/, ""); u=$0 }
      /"name": *"/ { n=$0; gsub(/.*"name": *"|".*/, "", n); if (u != "" && n == want) { print u; exit } }' "$RELEASE_JSON")
    [ -n "$url" ] || return 1
    http_get "$url" "$2" "application/octet-stream"
  elif [ "$TAG" = latest ]; then
    http_get "$BASE/latest/download/$1" "$2"
  else
    http_get "$BASE/download/$TAG/$1" "$2"
  fi
}

verify() { # file, name
  want=$(grep " $2\$" "$TMP/SHA256SUMS" | awk '{print $1}' | head -n 1)
  [ -n "$want" ] || die "$2 is not listed in SHA256SUMS"
  got=$(sha256_of "$1")
  [ "$got" = "$want" ] || die "checksum mismatch for $2 (expected $want, got $got); nothing was installed"
}

# ---------------------------------------------------------------- install

header
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$DEST" "$UNROAD_HOME"
rm -f "$DEST/ur.new"

if [ "$FROM_SOURCE" = 1 ]; then
  SRC=$(cd "$(dirname "$0")" && pwd)
  [ -f "$SRC/Cargo.toml" ] || die "--from-source must run from an unroad checkout (no Cargo.toml in $SRC)"
  command -v cargo >/dev/null 2>&1 || die "cargo not found; install Rust from https://rustup.rs"
  info "source" "$(short "$SRC")"
  busy "build" "cargo build --release"
  (cd "$SRC" && cargo build --release -p unroad-cli >"$TMP/cargo.log" 2>&1) || { tail -20 "$TMP/cargo.log" >&2; die "cargo build failed"; }
  ok "build" "target/release/ur"
  mkdir -p "$TMP/stage" && cp "$SRC/target/release/ur" "$TMP/stage/ur"
  if [ "$WITH_WEB" = 1 ]; then
    if command -v npm >/dev/null 2>&1; then
      busy "web" "npm ci && next build"
      (cd "$SRC/runtime/web" && { [ -d node_modules ] || npm ci --no-audit --no-fund; } && NEXT_TELEMETRY_DISABLED=1 npm run build) >"$TMP/web.log" 2>&1 \
        || { tail -20 "$TMP/web.log" >&2; die "web build failed"; }
      sh "$SRC/scripts/package-web.sh" "$SRC/runtime/web" "$TMP/web" >/dev/null 2>&1 || die "web packaging failed"
      ok "web" "built"
    else
      warn "web" "npm not found; skipped (install Node.js 20+ and rerun)"
      WITH_WEB=0
    fi
  fi
else
  target=$(detect_target)
  resolve_tag
  info "platform" "$target"
  via="public download"; [ -n "$TOKEN" ] && via="GitHub token"; [ "$USE_GH" = 1 ] && via="gh"
  info "release" "$TAG ${C_DIM}via $via${C_0}"
  busy "checksums" "SHA256SUMS"
  fetch_asset SHA256SUMS "$TMP/SHA256SUMS" || die "cannot download SHA256SUMS for $TAG (is the repository private? log in with gh or set GITHUB_TOKEN)"
  ok "checksums" "SHA256SUMS"
  file=$(awk '{print $2}' "$TMP/SHA256SUMS" | grep -- "-$target\.tar\.gz\$" | head -n 1)
  [ -n "$file" ] || die "no build for $target in $TAG"
  busy "ur" "downloading $file"
  fetch_asset "$file" "$TMP/$file" || die "cannot download $file"
  verify "$TMP/$file" "$file"
  tar -xzf "$TMP/$file" -C "$TMP"
  [ -f "$TMP/${file%.tar.gz}/ur" ] || die "$file does not contain ur"
  mkdir -p "$TMP/stage" && cp "$TMP/${file%.tar.gz}/ur" "$TMP/stage/ur"
  if [ "$WITH_WEB" = 1 ]; then
    web=$(awk '{print $2}' "$TMP/SHA256SUMS" | grep -- '^unroad-web-.*\.tar\.gz$' | head -n 1)
    if [ -n "$web" ]; then
      busy "web" "downloading $web"
      fetch_asset "$web" "$TMP/$web" || die "cannot download $web"
      verify "$TMP/$web" "$web"
      mkdir -p "$TMP/web" && tar -xzf "$TMP/$web" -C "$TMP/web"
    else
      warn "web" "this release has no web bundle"; WITH_WEB=0
    fi
  fi
fi

# Everything is downloaded and verified; only now touch the system.
cp "$TMP/stage/ur" "$DEST/ur.new"
chmod 755 "$DEST/ur.new"
mv "$DEST/ur.new" "$DEST/ur"
ok "ur" "$("$DEST/ur" --version 2>/dev/null || echo ur) → $(short "$DEST/ur")"

if [ "$WITH_WEB" = 1 ]; then
  rm -rf "$UNROAD_HOME/web.old"; [ -d "$UNROAD_HOME/web" ] && mv "$UNROAD_HOME/web" "$UNROAD_HOME/web.old"
  inner="$TMP/web"; [ -d "$TMP/web/unroad-web" ] && inner="$TMP/web/unroad-web"
  mv "$inner" "$UNROAD_HOME/web" && rm -rf "$UNROAD_HOME/web.old"
  ok "web" "→ $(short "$UNROAD_HOME/web")"
fi

if [ "$WITH_SKILLS" = 1 ]; then
  for d in $(skill_dirs); do
    out=$("$DEST/ur" install --target "$d" 2>&1) || die "ur install --target $d failed: $out"
    n=$(printf '%s\n' "$out" | grep -oE 'ur-[a-z]+' | sort -u | wc -l | tr -d ' ')
    ok "skills" "${n:-6} skills → $(short "$d")"
  done
fi

if command -v node >/dev/null 2>&1; then
  major=$(node --version 2>/dev/null | sed 's/^v//; s/\..*//')
  if [ "${major:-0}" -ge 20 ] 2>/dev/null; then ok "node" "$(node --version) for the web app"
  else warn "node" "$(node --version) is old; the web app needs Node.js 20+"; fi
else
  warn "node" "not found; the web app needs Node.js 20+ (https://nodejs.org)"
fi

say ""
case ":${PATH:-}:" in
  *":$DEST:"*) ;;
  *)
    pdir="$DEST"; case "$DEST" in "$HOME"/*) pdir="\$HOME${DEST#"$HOME"}" ;; esac
    say "  ${C_WARN}!${C_0} $(short "$DEST") is not on your PATH. Add it:"
    case "${SHELL:-}" in
      */fish) say "    ${C_DIM}fish_add_path $pdir${C_0}" ;;
      */zsh) say "    ${C_DIM}echo 'export PATH=\"$pdir:\$PATH\"' >> \$HOME/.zshrc${C_0}" ;;
      */bash) say "    ${C_DIM}echo 'export PATH=\"$pdir:\$PATH\"' >> \$HOME/.bashrc${C_0}" ;;
      *) say "    ${C_DIM}echo 'export PATH=\"$pdir:\$PATH\"' >> \$HOME/.profile${C_0}" ;;
    esac
    say "" ;;
esac
say "  ${C_B}Next${C_0}"
say "    ${C_SIG}/ur-start${C_0}       ${C_DIM}in your agent: set up your goal, level and lab repository${C_0}"
say "    ${C_SIG}ur gui${C_0}          ${C_DIM}open the roadmap in your browser${C_0}"
say "    ${C_SIG}ur${C_0}              ${C_DIM}where you are and what to do next${C_0}"
say ""
