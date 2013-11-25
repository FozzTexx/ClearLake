#!/bin/sh

# Fedora
if [ -e /usr/bin/yum ] ; then
    if [ `arch` = x86_64 ] ; then
	sudo yum -y install make gcc-objc libpng-devel.i686 libjpeg-turbo-devel.i686 \
	    libtiff-devel.i686 mysql-devel.i686 pcre-devel.i686 gmp-devel.i686 \
	    freetds-devel.i686 glibc-devel.i686
    else
	sudo yum -y install make gcc-objc libpng-devel libjpeg-devel libtiff-devel \
	    mysql-devel pcre-devel gmp-devel freetds-devel
    fi
fi

# Ubuntu
if [ -e /usr/bin/apt-get ] ; then
    sudo apt-get install make gobjc-4.6-multilib libpng12-dev libjpeg-dev libtiff4-dev \
	libmysqlclient15-dev libgmp3-dev libpcre3-dev freetds-dev libssl-dev lib32gmp-dev
fi

make
