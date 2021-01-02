#!/bin/sh
DATE=`date +%Y%m%d`
USER=root
#PASS='REDACTED'
DB=cloudforfree_org
DIR=/home/wbraswell
FILE=wbraswell_$DATE-cloudforfree.org.sql
#rm $DIR/*.sql.gz
#mysqldump --user=$USER --password=$PASS $DB --lock-tables --ignore-table=$DB.user > $DIR/$FILE
mysqldump --user=$USER --password $DB --lock-tables > $DIR/$FILE
cd $DIR
du -hs $FILE
gzip $FILE
du -hs $FILE.gz
