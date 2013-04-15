#!/bin/bash
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
echo " Cloudheizung Easy Backup Script "
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

