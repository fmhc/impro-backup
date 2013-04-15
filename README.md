impro-backup - backup script
==

License
==
copyright (c) 2013 by Finn Malte Hinrichsen, fmh@fmhc.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE


Was macht impro-Backup?
==

- Sichert Verzeichnisse rekursiv
	- /var/www (Webserverdateien)
	- /etc/apache2 (Webserverkonfiguration)
- Macht einen mysqldump einer/aller MySQL-Datenbank(en)
- packt alles in ein gzip-Archiv
- verschlÃ¼sselt das Archiv mit einem vorher angegebenen Key

Installation
==

(unter Ubuntu, andere Systeme aehnlich)
Falls git noch nicht installiert ist:
 apt-get install git -y
 
ncftp wird benötigt
 apt-get install ncftp

Anschliessend das Repository lokal klonen
 git clone https://github.com/fmhc/impro-backup.git

Datei backup.key.example nach backup.key kopieren und Passwort rein schreiben.

In der Datei backup.sh muss noch der Pfad zur Konfigurationsdatei angepasst werden.

