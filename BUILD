#!/bin/bash

# Fedora
if [ -e /usr/bin/yum ] ; then
    sudo yum -y install make gcc-objc libpng-devel libjpeg-devel libtiff-devel \
	mysql-devel pcre-devel gmp-devel freetds-devel libffi-devel
fi

# Debian/Ubuntu
if [ -e /usr/bin/apt-get ] ; then
    sudo apt-get install make gobjc libpng12-dev libjpeg-dev libtiff5-dev \
	libmysqlclient15-dev libgmp3-dev libpcre3-dev freetds-dev libssl-dev libffi-dev
fi

CL=`pwd`
CLBASE=`basename ${CL}`
if [ ! -e ~/Unix/${OSTYPE}/include/${CLBASE} ] ; then
    mkdir -p ~/Unix/${OSTYPE}/include
    pushd ~/Unix/${OSTYPE}/include
    ln -s ${CL}
    ln -s `dirname ${CL}`/piclib
    popd
fi

pushd ../piclib
if make libpiclib.a ; then
    mkdir -p ~/Unix/${OSTYPE}/lib
    if [ ! -e ~/Unix/${OSTYPE}/lib/libpiclib.a ] ; then
	ln -s `pwd`/libpiclib.a ~/Unix/${OSTYPE}/lib
    fi
    popd
    if make libClearLake.a ; then
	if [ ! -e ~/Unix/${OSTYPE}/lib/libClearLake.a ] ; then
	    ln -s `pwd`/libClearLake.a ~/Unix/${OSTYPE}/lib
	fi
    fi
fi
