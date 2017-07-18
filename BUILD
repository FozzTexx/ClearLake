#!/bin/bash

# Fedora
if [ -e /usr/bin/yum ] ; then
    sudo yum -y install make gcc-objc libpng-devel libjpeg-devel libtiff-devel \
	mysql-devel pcre-devel gmp-devel freetds-devel libffi-devel
    if [ $? != 0 ] ; then
	echo Package install failed
	exit 1
    fi
fi

# Debian/Ubuntu
if [ -e /usr/bin/apt-get ] ; then
    sudo apt-get install make gobjc libpng-dev libjpeg-dev libtiff5-dev \
	 libmysqlclient-dev libgmp3-dev libpcre3-dev freetds-dev libssl-dev libffi-dev
    if [ $? != 0 ] ; then
	echo Package install failed
	exit 1
    fi
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
    LIBPICLIB=${OSTYPE}-${ARCH}_bin/libpiclib.a
    if [ ! -e ${LIBPICLIB} ] ; then
	echo piclib build failed
	exit 1
    fi
    mkdir -p ~/Unix/${OSTYPE}/lib
    if [ ! -e ~/Unix/${OSTYPE}/lib/libpiclib.a ] ; then
	ln -s `pwd`/${LIBPICLIB} ~/Unix/${OSTYPE}/lib
    fi
    popd
    if make libClearLake.a ; then
	LIBCLEARLAKE=${OSTYPE}-${ARCH}_bin/libClearLake.a
	if [ ! -e ${LIBCLEARLAKE} ] ; then
	    echo ClearLake build failed
	    exit 1
	fi
	if [ ! -e ~/Unix/${OSTYPE}/lib/libClearLake.a ] ; then
	    ln -s `pwd`/${LIBCLEARLAKE} ~/Unix/${OSTYPE}/lib
	fi
    fi
fi
