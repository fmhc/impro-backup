# impro-backup

Ein Backup-Skript für kleine Webserver: Datenbank-Dump plus Verzeichnisse, verschlüsselt, dedupliziert, versioniert, mit Retention, Integritätsprüfung und Benachrichtigung. Ein Bash-Wrapper um [restic](https://restic.net), rund 190 Zeilen, keine weiteren Abhängigkeiten.

```
impro-backup run              Backup (DB + Dateien) + Retention
impro-backup check            Repo-Integrität prüfen (liest Stichprobe der Daten)
impro-backup list             Snapshots anzeigen
impro-backup restore [SNAP] [ZIEL]   Snapshot (Default: latest) nach ZIEL (Default: /var/tmp/impro-restore)
impro-backup init             Repo anlegen (einmalig)
impro-backup restic ARGS...   beliebiger restic-Befehl mit der impro-Konfiguration
```

## Installation

```bash
git clone https://github.com/fmhc/impro-backup.git
cd impro-backup
sudo ./install.sh
```

Der Installer holt restic und curl per apt (falls nötig), legt `/etc/impro-backup/` mit Beispiel-Konfiguration an, erzeugt ein Repo-Passwort, installiert das Skript nach `/usr/local/bin` und aktiviert zwei systemd-Timer: täglich 03:15 `run`, sonntags 05:00 `check`. Vorhandene Konfiguration wird nie überschrieben, `install.sh` kann zum Aktualisieren beliebig oft laufen.

Danach:

1. `/etc/impro-backup/env` — `RESTIC_REPOSITORY` setzen (SFTP, S3, rclone oder lokaler Pfad), ggf. Backend-Zugangsdaten und `NTFY_URL`.
2. `/etc/impro-backup/my.cnf` — MySQL-Zugang für `mysqldump`. Keine MySQL? Datei löschen, oder `DB_DUMP_CMD` in `env` setzen (z. B. `pg_dumpall -U postgres` oder `docker exec db pg_dumpall -U postgres`).
3. `/etc/impro-backup/paths.txt` — zu sichernde Verzeichnisse, eines pro Zeile.
4. `/etc/impro-backup/restic.pw` — **an einem zweiten Ort sichern.** Ohne dieses Passwort ist das Backup wertlos.
5. `impro-backup init`, dann `impro-backup run`, dann `impro-backup list`.
6. `impro-backup restore` einmal wirklich durchspielen. Ein Backup, das nie zurückgespielt wurde, ist eine Vermutung.

## Wie es arbeitet

- **Der Datenbank-Dump berührt nie die Platte.** `mysqldump | restic backup --stdin` streamt direkt ins verschlüsselte Repo.
- **Keine Passwörter in Prozesslisten.** MySQL liest `my.cnf` über `--defaults-extra-file`, restic sein Passwort aus `RESTIC_PASSWORD_FILE`. Alle Konfigdateien müssen Mode 600 haben, sonst bricht das Skript ab.
- **Verschlüsselt und integritätsgeschützt** durch restic (AES-256, Poly1305-AES), dedupliziert und komprimiert. Transport ist SFTP, S3, B2 oder alles, was rclone kann. FTP gibt es nicht mehr.
- **Retention** nach jedem Lauf: 7 tägliche, 4 wöchentliche, 6 monatliche Snapshots (über `KEEP_*` in `env` änderbar), danach `prune`.
- **Fehler machen Lärm.** `set -Eeuo pipefail`, jeder fehlgeschlagene Schritt löst eine ntfy-Nachricht mit Priorität *high* aus, jeder erfolgreiche Lauf eine mit *low*. Bleibt die OK-Meldung aus, stimmt etwas nicht.
- **Unvollständige Datei-Backups** (restic Exit 3, z. B. nicht lesbare Datei) laufen weiter, melden aber eine Warnung.
- **systemd statt Cron.** `Persistent=true` holt verpasste Läufe nach, `RandomizedDelaySec` verteilt Last, `IOSchedulingClass=idle` hält den Server bedienbar. Logs: `journalctl -u 'impro-backup@*'`.

## Restore

```bash
impro-backup list                                  # Snapshots ansehen
impro-backup restore                               # neuester Datei-Snapshot + neuester DB-Dump nach /var/tmp/impro-restore
impro-backup restore 490f30b8 /root/restore-test   # bestimmter Snapshot in ein anderes Ziel
impro-backup restic dump latest db-all.sql --tag db | mysql   # DB-Dump direkt einspielen
impro-backup restic ls latest --tag files          # Inhalt eines Snapshots listen
```

Verzeichnisse landen unter ihrem Originalpfad unterhalb des Ziels (`ZIEL/var/www/...`), der Datenbank-Dump direkt als `ZIEL/db-all.sql`.

## Konfiguration im Überblick

| Datei | Zweck |
|---|---|
| `env` | `RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`, optional `NTFY_URL`/`NTFY_TOKEN`, `KEEP_DAILY/WEEKLY/MONTHLY`, `CHECK_SUBSET`, `DB_DUMP_CMD`/`DB_DUMP_NAME`, Backend-Credentials |
| `my.cnf` | `[client]`-Block mit `user`/`password` für mysqldump |
| `paths.txt` | Pfade, `#` für Kommentare |
| `excludes.txt` | restic-Exclude-Muster (optional) |
| `restic.pw` | Repo-Passwort, vom Installer erzeugt |

Für Tests oder Mehrfach-Installationen lässt sich das Konfigverzeichnis mit `IMPRO_CONFIG_DIR=/pfad impro-backup run` umbiegen.

## Hinweis zur Version 0.4 (2013)

Die alte Version (Tag [`v0.4-legacy`](https://github.com/fmhc/impro-backup/tree/v0.4-legacy)) hatte in `backup.sh` Zeile 64 einen Umleitungsfehler: `mysqldump | gzip > dump.sql.gz >> $log`. Bash lässt die letzte Umleitung gewinnen, der Dump landete deshalb gzip-komprimiert und **unverschlüsselt in `/var/log/backup_*.log`**, während die `.sql.gz` im verschlüsselten Archiv leer blieb. Wer das Skript jemals eingesetzt hat, sollte diese Log-Dateien löschen und prüfen, ob es überhaupt je ein brauchbares Datenbank-Backup gab. Dazu kamen Passwörter in der Prozessliste, Klartext-FTP und ccrypt ohne Integritätsschutz. Nichts davon ist in Version 2 noch vorhanden.

## Lizenz

MIT. Copyright (c) 2013–2026 Finn Malte Hinrichsen.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
