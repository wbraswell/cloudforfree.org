FROM myshinytemplate:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apache2-dev libapache2-mod-perl2-dev expect-dev expect libapreq2-3

WORKDIR /tmp
RUN git clone https://github.com/wbraswell/apache2-filemanager.git apache2-filemanager \
	&& cd apache2-filemanager \
	&& perl Makefile.PL \
	&& make \ 
	&& make install

RUN useradd -ms /bin/bash cff

RUN mkdir -p /home/cff/public_html
WORKDIR /home/cff/public_html

RUN git clone https://github.com/rmzg/cloudforfree.org.git \
	&& cd cloudforfree.org \
	&& perl Makefile.PL \
	&& cpanm -v --notest --installdeps .


WORKDIR /home/cff/public_html/cloudforfree.org
COPY ./shinycms.conf .
COPY ./init.sh .

ENTRYPOINT ["init.sh"]
