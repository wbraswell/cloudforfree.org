#!/bin/sh
DATE=`date +%Y%m%d`
DIR=/home/wbraswell/public_html/cloudforfree.org-latest

/home/wbraswell/bin/mysqldump__cloudforfree.org__no_user.sh

cd $DIR
rm shinycms.conf.redacted
cp shinycms.conf shinycms.conf.redacted
echo
echo
echo "DELETE PASSWORD(S) FROM CONF FILE!!!"
echo "DELETE PASSWORD(S) FROM CONF FILE!!!"
echo "DELETE PASSWORD(S) FROM CONF FILE!!!"
sleep 2
vi shinycms.conf.redacted

cd $DIR
git add -A
git commit -a
git push origin master
