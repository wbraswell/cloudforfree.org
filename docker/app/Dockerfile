FROM wbraswell/rperl_cpan:latest

USER root:root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apache2-dev \
        libapache2-mod-perl2-dev \
        expect-dev \
        expect \
        libapreq2-3 \
        screen \
        software-properties-common \
        certbot \
        python-certbot-apache \
        default-mysql-client \
        default-libmysqlclient-dev \
        expat \
        libexpat1-dev \
        libxml2-dev \
        zlib1g-dev \
        unzip

# NEED UPDATE, CORRELATION #cff05: replace GitHub code w/ Apache2::FileManager v0.3 from CPAN, as soon as it has been created
WORKDIR /tmp
RUN git clone https://github.com/wbraswell/apache2-filemanager.git apache2-filemanager \
    && cd apache2-filemanager \
    && perl Makefile.PL \
    && make \
    && make install

RUN useradd -ms /bin/bash cff

RUN mkdir -p /home/cff/public_html
WORKDIR /home/cff/public_html

#RUN git clone https://github.com/rmzg/cloudforfree.org.git \
  #&& cd cloudforfree.org \
  #&& perl Makefile.PL \
  #&& cpanm -v --notest --installdeps .


#WORKDIR /home/cff/public_html/cloudforfree.org
#COPY ./shinycms.conf .

COPY ./init.sh /

ENTRYPOINT ["/init.sh"]
