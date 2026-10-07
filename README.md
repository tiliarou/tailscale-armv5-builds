# Tailscale armv5 builds

Builds automatiques de **Tailscale** pour **ARMv5 soft-float** (`GOARM=5`, `GOARCH=arm`, `CGO_ENABLED=0`), pour les routeurs anciens à base de Marvell Kirkwood (Feroceon 88FR131) — typiquement **Linksys EA4500 v1 / EA3500 sous OpenWrt** — dont l'architecture `armv5tejl` n'est pas couverte par les binaires statiques officiels de Tailscale (compilés pour ARMv7).

## Pourquoi ce dépôt

- Le dépôt OpenWrt fournit un paquet `tailscale` natif pour kirkwood, mais les versions y arrivent avec retard (branche stable).
- Les binaires statiques amont (pkgs.tailscale.com) ne supportent pas l'ARMv5.
- Ce dépôt compile les **sources officielles, non modifiées**, à chaque version stable amont, sur GitHub Actions — chaîne de build auditable de bout en bout : le workflow ne fait que `git checkout` du tag Tailscale + `go build`.

## Contenu des releases

- `tailscale` + `tailscaled` — binaires complets (toutes fonctionnalités)
- `tailscaled-tiny` — binaire combiné (démon + CLI) aux fonctionnalités minimales, pour l'espace disque réduit. Invoqué sous le nom `tailscale` (symlink), il agit comme le CLI.
- `SHA256SUMS` — sommes de contrôle

Chaque release correspond au tag amont Tailscale (ex. `v1.104.1`).

## Quelle variante ?

| | Complets | Tiny |
|---|---|---|
| Taille sur disque | ~46 Mo (2 binaires) | ~1 binaire, bien plus léger |
| Fonctionnalités | toutes | client pur : **pas d'annonce de routes (subnet router), pas d'exit node**, pas de SSH, pas de capture/debug |
| Recommandé pour | routeur qui annonce des sous-réseaux | nœud client simple (EA4500)

## Installation sur OpenWrt (EA4500 v1)

Prérequis : le paquet du dépôt OpenWrt doit être installé, pour ses scripts d'init et sa config UCI :

```sh
apk update && apk add tailscale tailscaled luci-app-tailscale-community
```

Puis (tiny par défaut) :

```sh
wget -O /tmp/install-armv5.sh https://raw.githubusercontent.com/tiliarou/tailscale-armv5-builds/main/scripts/install-openwrt.sh
sh /tmp/install-armv5.sh        # variante tiny
sh /tmp/install-armv5.sh full   # binaires complets
```

## Avertissements

- **Cohabitation avec apk** : remplacer les binaires du paquet apk n'est pas suivi par le gestionnaire de paquets. Un `apk upgrade` du paquet `tailscale`/`tailscaled` écrasera ces binaires par la version du dépôt OpenWrt — relancez simplement le script d'installation ensuite. Les mises à jour de ce dépôt ne modifient ni la config UCI (`/etc/config/tailscale`), ni l'état (`/etc/tailscale`).
- **RAM** : `tailscaled` est un binaire Go — prévoir 40-70 Mo de RAM résidente. Sur un EA4500 (128 Mo), c'est le facteur limitant, pas le disque.
- **TUN** : le module noyau doit être disponible (`kmod-tun` est installé en dépendance du paquet).

## Fonctionnement du workflow

`.github/workflows/build.yml` :

1. Détermine la dernière version stable de Tailscale (ou celle passée en paramètre via `workflow_dispatch`).
2. Compile depuis le tag amont avec `GOARM=5` (soft-float) : binaires complets + variante tiny (tags calculés par `cmd/featuretags --min --add=cli,osrouter,natraversal`, le mode minimal officiel de Tailscale).
3. **Vérifie l'ABI** : le build échoue si un binaire est hard-float (incompatible ARMv5).
4. Publie une release GitHub taguée comme la version Tailscale, avec checksums.

Le build tourne chaque lundi à 04:00 UTC, à chaque push sur `main`, et manuellement (avec version au choix).

## Licence

Tailscale est sous licence BSD-3-Clause. Ce dépôt ne contient que de l'automatisation de build ; les binaires produits sont des compilations non modifiées des sources [tailscale/tailscale](https://github.com/tailscale/tailscale).
