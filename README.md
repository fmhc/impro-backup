impro-backup - backup script

copyright 2013 by Finn Malte Hinrichsen, fmh@fmhc.de

Alle Reche vorbehalten bis ich mich fuer eine OpenSource-Lizenz entschieden habe.

Was macht impro-Backup?
==
- Sichert Verzeichnisse rekursiv
	- /var/www (Webserverdateien)
	- /etc/apache2 (Webserverkonfiguration)
- Macht einen mysqldump einer/aller MySQL-Datenbank(en)
- packt alles in ein gzip-Archiv
- verschlüsselt das Archiv mit einem vorher angegebenen Key

Installation

(unter Ubuntu, andere Systeme aehnlich)
Falls git noch nicht installiert ist:
 apt-get install git -y

Anschliessend das Repository lokal klonen
 git clone https://github.com/fmhc/impro-backup.git

Datei backup.cfg.example nach backup.cfg kopieren und Inhalte anpassen:
 # mySQL-Settings
 $MYSQLUSER="root"
 $MYSQLPASS="password"
 $MYSQLDB="database"
 # Backup Directory without / @end
 $BACKUPDIR="/home/user" 
 # Log Dir without / @end
 $LOGDIR="/var/log"
 # Verschluesselung
 $KEYFILE="/home/user/keyfile.key"

Datei backup.key.example nach backup.key kopieren und Passwort rein schreiben.

In der Datei backup.sh muss evtl. noch der Pfad zur Konfigurationsdatei angepasst werden.

