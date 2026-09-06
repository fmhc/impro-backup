#!/usr/bin/env bash
# impro-backup 2.0 Installer — idempotent, überschreibt keine vorhandene Konfiguration.
# Ausführen als root im geklonten Repo:  sudo ./install.sh
set -Eeuo pipefail
umask 022

[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen (sudo ./install.sh)" >&2; exit 1; }
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF=/etc/impro-backup
BIN=/usr/local/bin/impro-backup

# 1. Abhängigkeiten
need=()
command -v restic >/dev/null || need+=(restic)
command -v curl   >/dev/null || need+=(curl)
if ((${#need[@]})); then
  if command -v apt-get >/dev/null; then
    echo "Installiere: ${need[*]}"
    apt-get update -qq && apt-get install -y -qq "${need[@]}"
  else
    echo "Bitte manuell installieren: ${need[*]} (https://restic.net)" >&2; exit 1
  fi
fi

# 2. Konfigverzeichnis (nur anlegen, nie überschreiben)
install -d -m 700 "$CONF"
for f in env my.cnf paths.txt; do
  if [[ ! -e "$CONF/$f" ]]; then
    install -m 600 "$SRC/etc/$f.example" "$CONF/$f"
    echo "angelegt: $CONF/$f  (bitte anpassen)"
  fi
done
[[ -e "$CONF/excludes.txt" ]] || install -m 600 "$SRC/etc/excludes.txt.example" "$CONF/excludes.txt"
if [[ ! -e "$CONF/restic.pw" ]]; then
  (umask 077; head -c 32 /dev/urandom | base64 > "$CONF/restic.pw")
  echo "Repo-Passwort erzeugt: $CONF/restic.pw  -> JETZT an einem zweiten Ort sichern, ohne Passwort ist das Backup wertlos."
fi
install -d -m 700 /var/cache/impro-backup

# 3. Skript + systemd
install -m 755 "$SRC/impro-backup" "$BIN"
install -m 644 "$SRC/systemd/impro-backup@.service" /etc/systemd/system/
install -m 644 "$SRC/systemd/impro-backup@run.timer"   /etc/systemd/system/
install -m 644 "$SRC/systemd/impro-backup@check.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now impro-backup@run.timer impro-backup@check.timer >/dev/null
echo "Timer aktiv:"
systemctl list-timers 'impro-backup@*' --no-pager | sed 's/^/  /'

cat <<EOF

Nächste Schritte:
  1. $CONF/env      RESTIC_REPOSITORY setzen (sftp:user@host:/pfad | s3:... | rclone:...), Backend-Creds, NTFY_URL
  2. $CONF/my.cnf   MySQL-Zugang eintragen (oder Datei löschen, wenn keine DB / DB_DUMP_CMD in env)
  3. $CONF/paths.txt  Verzeichnisse prüfen
  4. impro-backup init      # Repo anlegen
  5. impro-backup run       # erstes Backup, dann:  impro-backup list
  6. impro-backup restore   # einmal wirklich testen, nach /var/tmp/impro-restore
EOF
