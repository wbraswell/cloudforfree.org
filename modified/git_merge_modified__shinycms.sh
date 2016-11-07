#!/bin/sh
PARENT_DIR=$1
MY_REPO_NAME=$2
MY_DIR_SUFFIX=$3
MY_DIR=$PARENT_DIR/$MY_REPO_NAME$MY_DIR_SUFFIX
DATE=`date +%Y%m%d`
BACKUP_DIR=$PARENT_DIR/$MY_REPO_NAME-backup_$DATE
GIT_BACKUP_COMMAND=/home/NEED_USERNAME/bin/git_backup__$MY_REPO_NAME.sh
SHINY_DIR=/home/NEED_USERNAME/public_html/ShinyCMS-latest

# GIT BACKUP, LOCAL BACKUP, GIT PULL, COPY

$GIT_BACKUP_COMMAND

echo
echo
echo "ABOUT TO MERGE FILES, DID BACKUP SUCCEED???"
echo "ABOUT TO MERGE FILES, DID BACKUP SUCCEED???"
echo "ABOUT TO MERGE FILES, DID BACKUP SUCCEED???"
sleep 3

rm -Rf $BACKUP_DIR
mv $MY_DIR $BACKUP_DIR

cd $SHINY_DIR
git pull origin master

cp -a $SHINY_DIR $MY_DIR
cd $MY_DIR
rm -Rf .git
cp -a $BACKUP_DIR/.git ./
cp -a $BACKUP_DIR/modified ./
cp -a $BACKUP_DIR/backup ./

# MERGE MODIFIED FILES

cd $MY_DIR
rm .gitignore
ln -s ./modified/.gitignore ./.gitignore

cd $MY_DIR
rm README
rm README.md
# HARD LINK so README contents show up in GitHub online
ln ./modified/README.md ./README.md  

cd $MY_DIR
rm shinycms.conf
ln -s ./modified/shinycms.conf ./shinycms.conf

cd $MY_DIR
cd root/static/ckeditor/
rm config.js
ln -s ../../../modified/config.js ./config.js

cd $MY_DIR
cd root/pages/cms-templates/
rm homepage.tt
ln -s ../../../modified/homepage.tt ./homepage.tt

cd $MY_DIR
cd root/static/css/
rm main.css
ln -s ../../../modified/main.css ./main.css

cd $MY_DIR
cd root/
rm site-footer.tt
ln -s ../modified/site-footer.tt ./site-footer.tt

cd $MY_DIR
cd root/
rm site-wrapper.tt
ln -s ../modified/site-wrapper.tt ./site-wrapper.tt

cd $MY_DIR
cd root/static/
rm -Rf cms-uploads
ln -s ../../modified/cms-uploads ./cms-uploads

cd $MY_DIR
cd root/
rm site-menu.tt
ln -s ../modified/site-menu.tt ./site-menu.tt

cd $MY_DIR
cd root/
rm offline.html
ln -s ../modified/offline.html ./offline.html

cd $MY_DIR
cd bin/
rm external-fastcgi-server
ln -s ../modified/external-fastcgi-server ./external-fastcgi-server

cd $MY_DIR
cd root/pages/cms-templates
ln -s ../../../modified/html_only.tt ./html_only.tt

cd $MY_DIR
cd root/static/images
ln -s ../../../modified/w3c-valid-html5.png ./w3c-valid-html5.png

cd $MY_DIR
cd root/events
rm view_events.tt
ln -s ../../modified/view_events.tt ./view_events.tt

cd $MY_DIR
cd root/events
rm view_event.tt
ln -s ../../modified/view_event.tt ./view_event.tt

cd $MY_DIR
cd root/user
rm view_user.tt
ln -s ../../modified/view_user.tt ./view_user.tt

cd $MY_DIR
cd root/shop
rm wrapper.tt
ln -s ../../modified/wrapper.tt ./wrapper.tt

cd $MY_DIR
cd root/
rm robots.txt
ln -s ../modified/robots.txt ./robots.txt

cd $MY_DIR
cd root/
rm google*.html
ln -s ../modified/google*.html ./

