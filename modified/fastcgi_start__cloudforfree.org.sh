#!/bin/bash


# NEED FIX: remove or formalize temp code
source /home/wbraswell/.bashrc;
export PATH=/home/wbraswell/github_repos/rperl-latest/script/:$PATH;
export PERL5LIB=/home/wbraswell/github_repos/apache2filemanager-latest/lib/:/home/wbraswell/github_repos/rperl-latest/lib/:/home/wbraswell/perl5:/home/wbraswell/perl5/lib/perl5:$PERL5LIB;


USERNAME=`whoami`
export HOME=/home/$USERNAME
SITE=$HOME/public_html/cloudforfree.org-latest
cd $SITE
eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
$SITE/bin/external-fastcgi-server
