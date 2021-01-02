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

COPY ./cpanfile .
RUN cpanm --installdeps -n .

RUN useradd -ms /bin/bash cff

RUN mkdir -p /home/cff/public_html
WORKDIR /home/cff/public_html

# NEED UPDATE, CORRELATION #cff06: Git Clone vs Docker Volume Mount; disable Git in favor of direct Docker mount, for easy file editing outside Docker container
# This image does not contain the actual application
# code.  It expects to mount the actual CFF application code
# (/wbraswell/cloudforfree.org.git) from the local file system into the
# image at /home/cff/public_html/cloudforfree.org this allows us to edit
# the application code and perform live reloading without having to push
# to github and rebuild the image while developing.
# By default this is handled by the provided docker-compose.yaml file.

#RUN git clone https://github.com/wbraswell/cloudforfree.org.git \
  #&& cd cloudforfree.org \
  #&& perl Makefile.PL \
  #&& cpanm -v --notest --installdeps .
#WORKDIR /home/cff/public_html/cloudforfree.org
#COPY ./shinycms.conf .

COPY ./init.sh /

ENTRYPOINT ["/init.sh"]
