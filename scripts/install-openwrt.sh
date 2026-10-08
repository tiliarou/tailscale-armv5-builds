#!/bin/sh
# Installe / met à jour les binaires Tailscale armv5 sur un routeur OpenWrt
# (kirkwood : Linksys EA4500 v1, EA3500, etc.).
#
# Par défaut : variante combinée (un seul binaire = démon + CLI, avec
# exit node et subnet router). Passez `full` en argument pour les
# binaires complets (toutes fonctionnalités, SSH inclus).
#
# Optimisé RAM : /tmp est en tmpfs sur OpenWrt — on ne télécharge que la
# variante choisie et on installe chaque binaire dès sa vérification.
#
# Prérequis :
#   - paquets OpenWrt `tailscale` et `tailscaled` installés (scripts d'init)
#   - wget, sha256sum (busybox)
#
# Usage :
#   sh install-openwrt.sh              # dernière release, variante combinée
#   sh install-openwrt.sh full         # dernière release, binaires complets
#   sh install-openwrt.sh v1.104.1     # version précise
#   sh install-openwrt.sh v1.104.1 full

set -e

REPO="tiliarou/tailscale-armv5-builds"
TMP="/tmp/ts-armv5"
STAMP=$(date +%Y%m%d-%H%M%S)
MODE="tiny"

for a in "$@"; do
  case "$a" in
    full|FULL) MODE="full" ;;
  esac
done

VERSION=""
for a in "$@"; do
  case "$a" in
    full|FULL) ;;
    *) VERSION="$a" ;;
  esac
done

command -v wget >/dev/null 2>&1 || { echo "ERREUR : wget manquant"; exit 1; }

TS_BIN=$(command -v tailscale || true)
TSD_BIN=$(command -v tailscaled || true)
[ -z "$TS_BIN" ] && [ -z "$TSD_BIN" ] && {
  echo "ERREUR : tailscale/tailscaled introuvables."
  echo "Installez d'abord le paquet OpenWrt : apk update && apk add tailscale tailscaled"
  exit 1
}
[ -z "$TS_BIN" ] && TS_BIN="/usr/bin/tailscale"
[ -z "$TSD_BIN" ] && TSD_BIN="/usr/sbin/tailscaled"
echo "Binaires existants : tailscale=$TS_BIN tailscaled=$TSD_BIN"
echo "Mode : $MODE"

if [ -n "$VERSION" ]; then
  BASE="https://github.com/$REPO/releases/download/$VERSION"
else
  BASE="https://github.com/$REPO/releases/latest/download"
fi

rm -rf "$TMP"; mkdir -p "$TMP"
cd "$TMP"

echo "Téléchargement des sommes de contrôle..."
wget -q -O SHA256SUMS "$BASE/SHA256SUMS" || { echo "ERREUR : téléchargement de SHA256SUMS"; exit 1; }

install_one() {
  # $1 = fichier de la release, $2 = destination finale
  f="$1"; dest="$2"
  echo "  -> $f"
  wget -q -O "$f" "$BASE/$f" || { echo "ERREUR : téléchargement de $f"; exit 1; }
  grep " $f\$" SHA256SUMS > "$f.sum" || { echo "ERREUR : checksum manquant pour $f"; exit 1; }
  sha256sum -c "$f.sum" >/dev/null || { echo "ERREUR : checksum invalide pour $f, abandon."; exit 1; }
  echo "     checksum OK, installation..."
  chmod +x "$f"
  mv "$f" "$dest"   # libère la RAM de /tmp immédiatement
}

echo "Sauvegarde des binaires actuels (.bak.$STAMP)..."
cp "$TSD_BIN" "$TSD_BIN.bak.$STAMP"
cp "$TS_BIN" "$TS_BIN.bak.$STAMP"

echo "Installation (mode $MODE)..."
if [ "$MODE" = "full" ]; then
  install_one tailscaled "$TSD_BIN"
  install_one tailscale "$TS_BIN"
else
  # Binaire combiné : invoqué sous le nom "tailscale" il agit comme le CLI.
  install_one tailscaled-tiny "$TSD_BIN"
  ln -sf "$TSD_BIN" "$TS_BIN"
fi

rm -rf "$TMP"

if [ -x /etc/init.d/tailscale ]; then
  echo "Redémarrage du service..."
  /etc/init.d/tailscale restart
elif [ -x /etc/init.d/tailscaled ]; then
  /etc/init.d/tailscaled restart
fi

echo
echo "Installé :"
tailscale version
echo
echo "Retour arrière si besoin :"
echo "  mv $TSD_BIN.bak.$STAMP $TSD_BIN && mv $TS_BIN.bak.$STAMP $TS_BIN"
