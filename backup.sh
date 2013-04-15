#!/bin/bash
#Copyright (c) 2013 Finn Malte Hinrichsen
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
# ########################################
# 
# impro-backup by fmh 2013
#
# ########################################
# Versions
# 0.1 first version
# 0.2 include and encryption
# 0.3 better variables handling
# 0.4 bugfixes, FTP Upload
version="0.4"

# ########################################
# (!) Change path to config
source /home/fmh/scripts-config/backup-config.sh
# TODO: check einbauen ob alle benoetigten variablen geladen sind


# ########################################
# nothing to do for you any more
# ########################################
datum=$(date +%y%m%d-%H%M)
# Backupdir mit Datum anreichern
bdir=$BACKUP_TO
log=$LOG_TO"/backup_"$datum".log"

#cd $backupdir
# TODO: if not exist Backupdir abfragen
#mkdir -p $bdir
line="-------------------------------------------------------------------------"

echo $line
echo " impro-backup - easy backup script "
echo " Copyright 2013 Finn Malte Hinrichsen "
echo " Version "$version
echo $line
echo "" 
echo " Logs werden in der Datei "
echo "  "$log
echo " festgehalten"
echo ""
echo $line
echo $(date +"%y-%m-%d %H:%M") " Backup gestartet in Verzeichnis: "$bdir 
echo $(date +"%y-%m-%d %H:%M") " Backup gestartet in Verzeichnis: "$bdir >> $log


echo $BACKUP_DIR
filecontent=$(<$BACKUP_DIR)

for t in "${filecontent[@]}"
do
echo $(date +"%y-%m-%d %H:%M") " Backup von "$t"/* /n" 
echo $(date +"%y-%m-%d %H:%M") " Backup von "$t"/* " >> $log
zip -grv $bdir/backup_$datum.zip $t/* >> $log 
done

echo $(date +"%y-%m-%d %H:%M") " mysql-dump "
echo $(date +"%y-%m-%d %H:%M") " mysql-dump " >> $log
mysqldump -u $MYSQLUSER -p$MYSQLPASS $MYSQLDB | gzip > $bdir/backup_sql_$datum.sql.gz >> $log
zip -gv $bdir/backup_$datum.zip $bdir/backup_sql_$datum.sql.gz >> $log
rm  $bdir/backup_sql_$datum.sql.gz
echo $(date +"%y-%m-%d %H:%M")  $bdir/backup_sql_$datum.sql.gz" deleted"

# Verschluesselung
echo $(date +"%y-%m-%d %H:%M") " verschluesseln... "
echo $(date +"%y-%m-%d %H:%M") " verschluesseln " >> $log
ccencrypt $bdir/backup_$datum.zip -k $KEYFILE
echo $(date +"%y-%m-%d %H:%M") " Backup beendet "
echo $line
echo $(date +"%y-%m-%d %H:%M") " Backup beendet " >> $log

ncftpput -m -u $FTPU -p $FTPP $FTPS  $FTPF $bdir/backup_$datum.zip.cpt
echo $(date +"%y-%m-%d %H:%M") " Backup hochgeladen "
echo $line
echo $(date +"%y-%m-%d %H:%M") " Backup hochgeladen " >> $log

