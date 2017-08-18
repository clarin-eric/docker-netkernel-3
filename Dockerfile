FROM ubuntu:16.04

# app workdir
RUN mkdir -p /app && \
    mkdir -p /app/lib && \
    mkdir -p /app/bin
ENV PATH "/app/bin:$PATH"
WORKDIR /app

# base
RUN apt-get -y update && \
    apt-get -y clean && \
    apt-get -y install wget subversion supervisor xmlstarlet

# dev
RUN apt-get -y install less libxml2-utils vim

# locale
ENV TZ 'Europe/Amsterdam'
RUN echo $TZ > /etc/timezone && \
    apt-get update && apt-get install -y tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

RUN apt-get update && apt-get install -y locales && \
	sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG "en_US.UTF-8"
ENV LANGUAGE "en_US.UTF-8"
ENV LC_ALL "en_US.UTF-8"

# JDK8
RUN apt-get -y install software-properties-common python-software-properties && \
    add-apt-repository ppa:webupd8team/java && \
    apt-get update && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    apt-get -y install oracle-java8-installer
ENV JAVA_HOME "/usr/lib/jvm/java-8-oracle"

# NK3
RUN mkdir -p /app/nk && \
    cd /app/nk && \
    wget -O 1060-NetKernel-SE-DK-3.3.1.tgz "http://ftp.heanet.ie/mirrors/download.1060.org/dist/1060-NetKernel-SE-DK/1060-NetKernel-SE-DK-3.3.1.tgz" && \
    tar xvfz "1060-NetKernel-SE-DK-3.3.1.tgz" &&\
    rm 1060-NetKernel-SE-DK-3.3.1.tgz &&\
    mv 1060-NetKernel-SE-DK3.3.1 1060-NetKernel-SE-DK-3.3.1 &&\
    cd 1060-NetKernel-SE-DK-3.3.1 &&\
    ./complete-tarball-install.sh

ADD supervisord-nk.conf /etc/supervisor/conf.d/

EXPOSE 1060
EXPOSE 8080

# - patch kernel
RUN mkdir -p /tmp &&\
    cd /tmp &&\
    svn co https://svn.clarin.eu/cats/patches/NetKernel/trunk/src patches

RUN cd /app/nk/1060-NetKernel-SE-DK-3.3.1/lib &&\
    mkdir 1060netkernel-2.8.5 &&\
    cd 1060netkernel-2.8.5 &&\
    jar xf ../1060netkernel-2.8.5.jar &&\
    mv ../1060netkernel-2.8.5.jar ../1060netkernel-2.8.5.jar.ORG &&\
    cd /tmp/patches/kernel &&\
    javac \
        -cp /app/nk/1060-NetKernel-SE-DK-3.3.1/lib/1060netkernel-2.8.5 \
        -endorseddirs /app/nk/1060-NetKernel-SE-DK-3.3.1/lib/endorsed \
        -extdirs /app/nk/1060-NetKernel-SE-DK-3.3.1/lib/ext \
        -d /app/nk/1060-NetKernel-SE-DK-3.3.1/lib/1060netkernel-2.8.5 \
        com/ten60/netkernel/util/DynamicURLClassLoader.java \
        com/ten60/netkernel/module/ModuleClassLoader.java &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/lib/1060netkernel-2.8.5 &&\
    jar cf ../1060netkernel-2.8.5.jar *

# - fetch updates
RUN cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ &&\
    wget http://ftp.heanet.ie/mirrors/download.1060.org/module/ext-xquery/ext-xquery-2.4.4.jar &&\
    wget http://ftp.heanet.ie/mirrors/download.1060.org/module/http-client/http-client-1.2.4.jar &&\
    wget http://ftp.heanet.ie/mirrors/download.1060.org/module/tpt-http/tpt-http-2.2.4.jar &&\
    sed -i 's|ext-xquery-2.4.3.jar|ext-xquery-2.4.4.jar|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
    sed -i 's|ext-http-client-1.2.1.jar|http-client-1.2.4.jar|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
    sed -i 's|tpt-http-2.2.2.jar|tpt-http-2.2.4.jar|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml 

# - patch modules
RUN apt-get -y install ant &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ &&\
    cp /tmp/patches/modules/build.xml .

RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-sys-1.2.10 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-sys-1.2.10 &&\
    jar xf ../ext-sys-1.2.10.jar &&\
    cp -r /tmp/patches/modules/ext-sys-1.2.10/* . &&\
    cd .. &&\
    ant -Dmod=ext-sys-1.2.10

RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xml-core-1.5.2 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xml-core-1.5.2 &&\
    jar xf ../ext-xml-core-1.5.2.jar &&\
    cp -r /tmp/patches/modules/ext-xml-core-1.5.2/* . &&\
    cd .. &&\
    ant -Dmod=ext-xml-core-1.5.2 &&\
    cd ../etc &&\
    svn co https://svn.clarin.eu/cats/patches/NetKernel/trunk/dist/etc/catalog catalog

RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xml-ura-1.3.4 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xml-ura-1.3.4 &&\
    jar xf ../ext-xml-ura-1.3.4.jar &&\
    cp -r /tmp/patches/modules/ext-xml-ura-1.3.4/* . &&\
    cd .. &&\
    ant -Dmod=ext-xml-ura-1.3.4

RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/mod-developer-1.1.1 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/mod-developer-1.1.1 &&\
    jar xf ../mod-developer-1.1.1.jar &&\
    cp -r /tmp/patches/modules/mod-developer-1.1.1/* . &&\
    xmlstarlet ed -d '//import[uri="urn:isocat:control:session"]' module.xml > module.xml.NEW  &&\
    mv module.xml module.xml.BAK &&\
    mv module.xml.NEW module.xml &&\
    cd .. &&\
    ant -Dmod=mod-developer-1.1.1

RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/mod-smtp-1.1.2 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/mod-smtp-1.1.2 &&\
    jar xf ../mod-smtp-1.1.2.jar &&\
    cp -r /tmp/patches/modules/mod-smtp-1.1.2/* . &&\
    cd .. &&\
    ant -Dmod=mod-smtp-1.1.2

#    cp ext-xquery-2.4.3.jar ext-xquery-2.4.4.jar &&\
#    rm ext-xquery-2.4.4.jar.ORG &&\
#    sed -i 's|ext-xquery-2.4.3.jar|ext-xquery-2.4.4.jar|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
RUN mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xquery-2.4.4 &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/ext-xquery-2.4.4 &&\
    jar xf ../ext-xquery-2.4.4.jar &&\
    cp -r /tmp/patches/modules/ext-xquery-2.4.4/* . &&\
    cd .. &&\
    ant -Dmod=ext-xquery-2.4.4 &&\
    mv ext-xquery-2.4.3.jar ext-xquery-2.4.3.jar.BAK

# - add 3rd party modules
RUN cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules &&\
    svn co https://svn.clarin.eu/cats/patches/NetKernel/trunk/contrib &&\
    sed -i 's|</modules>|<module>modules/contrib/mod-e4x-1.0.0.jar</module></modules>|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
    sed -i 's|</modules>|<module>modules/contrib/db-metadata.jar</module></modules>|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
    sed -i 's|</modules>|<module>modules/contrib/mod-stink-0.1.0.jar</module></modules>|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml &&\
    sed -i 's|</modules>|<module>modules/contrib/test-stink-0.1.0.jar</module></modules>|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml

# - add mod-SLOOT
RUN cd /tmp &&\
    wget https://raw.githubusercontent.com/jcgregorio/mimeparse/master/mimeparse.js &&\
    mkdir -p /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/own &&\
    cd /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/own &&\
    svn co https://svn.clarin.eu/cats/shared/mod-SLOOT/trunk mod-SLOOT &&\
    cd mod-SLOOT &&\
    echo '<project name="local-props" basedir="."><property name="nk" location="/app/nk/1060-NetKernel-SE-DK-3.3.1/"/><property name="mimeparse" location="/tmp"/></project>' > local-props.xml &&\
    ant &&\
    sed -i 's|</modules>|<module>modules/own/mod-SLOOT</module></modules>|g' /app/nk/1060-NetKernel-SE-DK-3.3.1/etc/deployedModules.xml

# cleanup
RUN rm /app/nk/1060-NetKernel-SE-DK-3.3.1/modules/*.OLD &&\
    rm -rf /var/lib/apt/lists/* &&\
    rm -rf /tmp/*

# run
ADD start.sh /start.sh
RUN	chmod u+x /start.sh
ENTRYPOINT /start.sh