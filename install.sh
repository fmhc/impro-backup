#!/usr/bin/env bash
# impro-backup 2.0 Installer — idempotent: Erstinstallation legt Konfiguration an,
# jeder weitere Lauf aktualisiert nur Skript und systemd-Units.
# Ausführen als root im geklonten Repo:  sudo ./install.sh
set -Eeuo pipefail
umask 022

[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen (sudo ./install.sh)" >&2; exit 1; }
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF=/etc/impro-backup
BIN=/usr/local/bin/impro-backup
first_install=0
[[ -d "$CONF" ]] || first_install=1

# 1. Abhängigkeiten – jeder Schritt einzeln geprüft, am Ende Verifikation
need=()
for tool in restic curl flock; do command -v "$tool" >/dev/null || need+=("$tool"); done
if ((${#need[@]})); then
  pkgs=("${need[@]/flock/util-linux}")
  command -v apt-get >/dev/null || { echo "Bitte manuell installieren: ${need[*]} (https://restic.net)" >&2; exit 1; }
  echo "Installiere: ${pkgs[*]}"
  apt-get update -qq
  apt-get install -y -qq "${pkgs[@]}"
fi
for tool in restic curl flock; do
  command -v "$tool" >/dev/null || { echo "$tool fehlt nach Installation, breche ab" >&2; exit 1; }
done
echo "restic: $(restic version)"

# 2. Konfigverzeichnis – nur bei Erstinstallation befüllen, nie überschreiben
install -d -m 700 "$CONF"
if ((first_install)); then
  for f in env my.cnf paths.txt excludes.txt; do
    install -m 600 "$SRC/etc/$f.example" "$CONF/$f"
    echo "angelegt: $CONF/$f  (bitte anpassen)"
  done
  (umask 077; head -c 32 /dev/urandom | base64 > "$CONF/restic.pw")
  echo "Repo-Passwort erzeugt: $CONF/restic.pw  -> JETZT an einem zweiten Ort sichern, ohne Passwort ist das Backup wertlos."
else
  echo "Konfiguration in $CONF bleibt unverändert (Update-Lauf)."
fi
install -d -m 700 /var/cache/impro-backup

# 3. Skript + systemd-Units (Timer werden erst von `impro-backup init` aktiviert)
install -m 755 "$SRC/impro-backup" "$BIN"
install -m 644 "$SRC/systemd/impro-backup@.service"   /etc/systemd/system/
install -m 644 "$SRC/systemd/impro-backup@run.timer"   /etc/systemd/system/
install -m 644 "$SRC/systemd/impro-backup@check.timer" /etc/systemd/system/
systemctl daemon-reload
echo "installiert: $BIN + systemd-Units"

if ((first_install)); then
  cat <<EOF

Nächste Schritte:
  1. $CONF/env        RESTIC_REPOSITORY setzen (sftp:user@host:/pfad | s3:... | rclone:...), Backend-Creds, NTFY_URL
  2. $CONF/my.cnf     MySQL-Zugang eintragen. Keine MySQL? Datei löschen oder DB_DUMP_CMD in env setzen.
  3. $CONF/paths.txt  Verzeichnisse prüfen (alle müssen existieren)
  4. impro-backup init      # Repo anlegen + Timer aktivieren
  5. impro-backup run       # erstes Backup, dann:  impro-backup list
  6. impro-backup restore   # einmal wirklich testen
EOF
else
  systemctl list-timers 'impro-backup@*' --no-pager 2>/dev/null | sed 's/^/  /' || true
fi
