#! /bin/sh
# ########################################
# 
# impro-backup by fmh 2013
#
# ########################################
# Versions
# 0.1 first version
# 0.2 include and encryption
# 0.3 better variables handling
version="0.3"

# ########################################
# Change path to config
. ../scripts-config/backup.cfg

# ########################################
# nothing to do for you any more
# ########################################
datum=$(date +%y%m%d-%H%M)
# Backupdir mit Datum anreichern
bdir=$BACKUPDIR
log=$LOGDIR"/backup_"$datum".log"

#cd $backupdir
mkdir -p $bdir
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

echo $(date +"%y-%m-%d %H:%M") " Backup von /etc/apache2/* " 
echo $(date +"%y-%m-%d %H:%M") " Backup von /etc/apache2/* " >> $log
zip -grv $bdir/backup_$datum.zip /etc/apache2/* >> $log 

echo $(date +"%y-%m-%d %H:%M") " Backup von /var/www/* "
echo $(date +"%y-%m-%d %H:%M") " Backup von /var/www/* " >> $log
zip -grv $bdir/backup_$datum.zip /var/www/* >> $log

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

