FROM myshinytemplate:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apache2-dev libapache2-mod-perl2-dev expect-dev expect libapreq2-3

WORKDIR /tmp
RUN git clone https://github.com/wbraswell/apache2-filemanager.git apache2-filemanager \
	&& cd apache2-filemanager \
	&& perl Makefile.PL \
	&& make \ 
	&& make install

RUN PERL_USE_UNSAFE_INC=1 cpanm -v -n Plack::Middleware::DoormanAuth0
# Update the version of DoormanAuth from 0.01 to 0.10. Why? ShinyCMS depends on 0.10...
RUN perl -pi -e's/VERSION   = "0.01";/VERSION   = "0.10";/' $(perl -MPlack::Middleware::DoormanAuth0 -le'print $INC{"Plack/Middleware/DoormanAuth0.pm"}')


RUN useradd -ms /bin/bash cff

RUN mkdir -p /home/cff/public_html
WORKDIR /home/cff/public_html

RUN git clone https://github.com/wbraswell/cloudforfree.org.git \
	&& cd cloudforfree.org \
	&& perl Makefile.PL \
	&& cpanm -v --notest --installdeps .


WORKDIR /home/cff/public_html/cloudforfree.org
COPY ./shinycms.conf .
COPY ./init.sh .

ENTRYPOINT ["init.sh"]
