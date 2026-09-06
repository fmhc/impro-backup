# impro-backup

Ein Backup-Skript für kleine Webserver: Datenbank-Dump plus Verzeichnisse, verschlüsselt, dedupliziert, versioniert, mit Retention, Integritätsprüfung und Benachrichtigung. Ein Bash-Wrapper um [restic](https://restic.net), rund 250 Zeilen, keine weiteren Abhängigkeiten.

```
impro-backup run              Backup (DB + Dateien) + Retention
impro-backup check            Repo-Integrität prüfen (liest Stichprobe der Daten)
impro-backup list             Snapshots dieses Hosts anzeigen
impro-backup restore [SNAP] [ZIEL]   letzten vollständigen Lauf (Dateien + DB) oder Snapshot SNAP holen
impro-backup init             Repo anlegen, Timer aktivieren (einmalig)
impro-backup restic ARGS...   beliebiger restic-Befehl mit der impro-Konfiguration
```

## Installation

```bash
git clone https://github.com/fmhc/impro-backup.git
cd impro-backup
sudo ./install.sh
```

Der Installer holt restic, curl und flock per apt (falls nötig), legt bei der **Erstinstallation** `/etc/impro-backup/` mit Beispiel-Konfiguration und einem erzeugten Repo-Passwort an und installiert Skript und systemd-Units. Jeder weitere Lauf aktualisiert nur Skript und Units und lässt die Konfiguration unangetastet, auch bewusst gelöschte Dateien wie `my.cnf`.

Danach:

1. `/etc/impro-backup/env` — `RESTIC_REPOSITORY` setzen (SFTP, S3, rclone oder lokaler Pfad), ggf. Backend-Zugangsdaten und `NTFY_URL`.
2. `/etc/impro-backup/my.cnf` — MySQL-Zugang für `mysqldump`. Keine MySQL? Datei löschen, oder `DB_DUMP_CMD` in `env` setzen (z. B. `pg_dumpall -U postgres` oder `docker exec db pg_dumpall -U postgres`).
3. `/etc/impro-backup/paths.txt` — zu sichernde Verzeichnisse, eines pro Zeile. Alle müssen existieren, sonst bricht der Lauf ab.
4. `/etc/impro-backup/restic.pw` — **an einem zweiten Ort sichern.** Ohne dieses Passwort ist das Backup wertlos.
5. `impro-backup init` legt das Repo an und aktiviert die Timer: täglich 03:15 `run`, sonntags 05:00 `check`.
6. `impro-backup run`, dann `impro-backup list`.
7. `impro-backup restore` einmal wirklich durchspielen und den SQL-Dump in eine Test-Datenbank einspielen. Ein Backup, das nie zurückgespielt wurde, ist eine Vermutung.

## Wie es arbeitet

- **Der Datenbank-Dump berührt nie die Platte.** `mysqldump | restic backup --stdin` streamt direkt ins verschlüsselte Repo.
- **Ein Lauf ist erst gültig, wenn beide Teile durch sind.** DB-Dump und Dateien tragen dasselbe Lauf-Tag (`run-JJJJMMTT-HHMMSS`). Bricht ein Teil ab, werden die Snapshots dieses Laufs verworfen. `restore` holt deshalb immer ein zusammengehöriges Paar und mischt nie Generationen.
- **Keine Passwörter in Prozesslisten.** MySQL liest `my.cnf` über `--defaults-extra-file`, restic sein Passwort aus `RESTIC_PASSWORD_FILE`, curl den ntfy-Token über eine Config auf stdin. Konfigdateien müssen dem ausführenden User gehören, reguläre Dateien sein und nur für den Owner lesbar; das Konfigverzeichnis darf für Gruppe und Andere nicht schreibbar sein. Sonst bricht das Skript ab.
- **Verschlüsselt und integritätsgeschützt** durch restic (AES-256, Poly1305-AES), dedupliziert und komprimiert. Transport ist SFTP, S3, B2 oder alles, was rclone kann. FTP gibt es nicht mehr.
- **Retention** nach jedem vollständigen Lauf: 7 tägliche, 4 wöchentliche, 6 monatliche Snapshots (über `KEEP_*` änderbar), nur für Snapshots dieses Hosts mit dem Tag `impro`. Andere Snapshots im selben Repo bleiben unberührt.
- **Fehler machen Lärm.** Jeder Abbruch, egal ob durch Fehler, fehlende Konfiguration, Signal oder systemd-Timeout, löst eine ntfy-Nachricht mit Priorität *high* aus; jeder erfolgreiche Lauf eine mit *low*. Bleibt die OK-Meldung aus, stimmt etwas nicht. Was das Skript nicht sehen kann: einen toten Host oder deaktivierten Timer. Dafür braucht es außen einen Dead-Man-Switch, der das Alter der letzten OK-Meldung überwacht.
- **Unvollständige Datei-Backups** (restic Exit 3, z. B. nicht lesbare Datei) behalten ihren Snapshot, bekommen aber das Tag `files-partial`, der Lauf endet mit Exit 3 und einer Warnung. `restore latest` übergeht solche Läufe, die Retention zählt sie nicht als Wiederherstellungspunkt und räumt sie nach 14 Tagen weg (`KEEP_PARTIAL`).
- **Ein Lauf zur Zeit.** `run`, `check` und `restore` teilen sich ein Lock; ein zweiter Aufruf wartet bis zu einer Stunde.
- **systemd statt Cron.** `Persistent=true` holt verpasste Läufe nach, `RandomizedDelaySec` verteilt Last, `IOSchedulingClass=idle` hält den Server bedienbar. Logs: `journalctl -u 'impro-backup@*'`.

## Restore

```bash
impro-backup list                                  # Snapshots ansehen
impro-backup restore                               # letzter vollständiger Lauf nach /var/tmp/impro-restore-<zeit>
impro-backup restore latest /root/restore-test     # dito in ein eigenes, noch nicht existierendes Ziel
impro-backup restore 490f30b8 /root/restore-test   # ein bestimmter Snapshot
impro-backup restic dump latest db-all.sql --host web01 --tag impro,db | mysql   # DB-Dump direkt einspielen
impro-backup restic ls latest --tag impro,files    # Inhalt eines Snapshots listen
```

Das Ziel wird neu und nur für root lesbar angelegt; ein vorhandenes Verzeichnis wird abgelehnt. Verzeichnisse landen unter ihrem Originalpfad unterhalb des Ziels (`ZIEL/var/www/...`), der Datenbank-Dump direkt als `ZIEL/db-all.sql`.

**Restore auf einem Ersatzserver:** Snapshots sind an den Hostnamen gebunden. Auf einer neuen Maschine `IMPRO_HOST=<alter-hostname>` in `env` setzen, dann findet `restore` die Sicherungen des alten Servers und `run` führt die Serie fort.

## Was das Backup nicht leistet

- **Anwendungskonsistenz zwischen DB und Dateien.** Der Dump läuft vor dem Datei-Backup; was die Anwendung dazwischen ändert, passt nicht zusammen. `--single-transaction` schützt InnoDB, nicht MyISAM. Wer das braucht, pausiert Schreibzugriffe oder sichert einen Dateisystem-Snapshot.
- **Schutz vor einem kompromittierten root.** Der Server hat Löschrechte im Repo (`prune`). Eine zweite Kopie mit Append-only-Zugang (z. B. `rest-server --append-only` oder S3 Object Lock) ist die Antwort darauf.
- **Ein Restore-Test.** `check` liest 5 % der Daten und findet Bitrot, aber keinen kaputten SQL-Dump. Einmal im Quartal wirklich zurückspielen.

## Konfiguration im Überblick

| Datei | Zweck |
|---|---|
| `env` | `RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`, optional `NTFY_URL`/`NTFY_TOKEN`, `KEEP_DAILY/WEEKLY/MONTHLY`, `CHECK_SUBSET`, `DB_DUMP_CMD`/`DB_DUMP_NAME`, `IMPRO_HOST`, `LOCK_WAIT`, Backend-Credentials |
| `my.cnf` | `[client]`-Block mit `user`/`password` für mysqldump |
| `paths.txt` | Pfade, `#` für Kommentare, alle müssen existieren |
| `excludes.txt` | restic-Exclude-Muster (optional) |
| `restic.pw` | Repo-Passwort, vom Installer erzeugt |

Alle Werte aus `env` landen in der Umgebung von restic, curl und dem Dump-Kommando. Für Tests oder Mehrfach-Installationen lässt sich das Konfigverzeichnis mit `IMPRO_CONFIG_DIR=/pfad impro-backup run` umbiegen.

## Hinweis zur Version 0.4 (2013)

Die alte Version (Tag [`v0.4-legacy`](https://github.com/fmhc/impro-backup/tree/v0.4-legacy)) hatte in `backup.sh` Zeile 64 einen Umleitungsfehler: `mysqldump | gzip > dump.sql.gz >> $log`. Bash lässt die letzte Umleitung gewinnen, der Dump landete deshalb gzip-komprimiert und **unverschlüsselt in `/var/log/backup_*.log`**, während die `.sql.gz` im verschlüsselten Archiv leer blieb. Wer das Skript jemals eingesetzt hat, sollte diese Log-Dateien löschen und prüfen, ob es überhaupt je ein brauchbares Datenbank-Backup gab. Dazu kamen Passwörter in der Prozessliste, Klartext-FTP und ccrypt ohne Integritätsschutz. Nichts davon ist in Version 2 noch vorhanden.

## Lizenz

MIT. Copyright (c) 2013–2026 Finn Malte Hinrichsen.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
