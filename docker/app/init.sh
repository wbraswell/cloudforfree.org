#!/bin/bash

BASEDIR=/home/cff/public_html/cloudforfree.org

cd $BASEDIR
perl Makefile.PL
cpanm -v --notest --installdeps .


PATH="$PATH:/home/rperluser/perl5/bin/" PERL5LIB=/home/rperluser/perl5/lib/perl5/  perl ./script/shinycms_server.pl
