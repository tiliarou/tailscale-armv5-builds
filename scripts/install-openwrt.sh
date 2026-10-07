#!/bin/sh
# Installe / met à jour les binaires Tailscale armv5 sur un routeur OpenWrt
# (kirkwood : Linksys EA4500 v1, EA3500, etc.).
#
# Prérequis :
#   - paquets OpenWrt \`tailscale\` et \`tailscaled\` installés (scripts d'init)
#   - wget, sha256sum (busybox)
#
# Usage : sh install-openwrt.sh [version]   (ex. sh install-openwrt.sh v1.102.2)

set -e

REPO="tiliarou/tailscale-armv5-builds"
TMP="/tmp/ts-armv5"
STAMP=$(date +%Y%m%d-%H%M%S)

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

if [ -n "$1" ]; then
  BASE="https://github.com/$REPO/releases/download/$1"
else
  BASE="https://github.com/$REPO/releases/latest/download"
fi

echo "Téléchargement depuis : $BASE"
rm -rf "$TMP"; mkdir -p "$TMP"
cd "$TMP"

for f in tailscale tailscaled SHA256SUMS; do
  echo "  -> $f"
  wget -q --show-progress -O "$f" "$BASE/$f" || { echo "ERREUR : téléchargement de $f"; exit 1; }
done

echo "Vérification des sommes de contrôle..."
sha256sum -c SHA256SUMS || { echo "ERREUR : checksum invalide, abandon."; exit 1; }
chmod +x tailscale tailscaled

echo "Sauvegarde des binaires actuels (.bak.$STAMP)..."
cp "$TSD_BIN" "$TSD_BIN.bak.$STAMP"
cp "$TS_BIN" "$TS_BIN.bak.$STAMP"

echo "Installation..."
mv tailscaled "$TSD_BIN"
mv tailscale "$TS_BIN"

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
