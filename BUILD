#!/bin/bash

# To checkout a fresh copy:
#   git clone git.tractionsys.com:/usr/local/git/ClearLake.git

# Fedora
if [ -e /usr/bin/yum ] ; then
    sudo yum -y install make gcc-objc libpng-devel libjpeg-devel libtiff-devel \
	mysql-devel pcre-devel gmp-devel freetds-devel libffi-devel
fi

# Ubuntu
if [ -e /usr/bin/apt-get ] ; then
    sudo apt-get install make gobjc libpng12-dev libjpeg-dev libtiff4-dev \
	libmysqlclient15-dev libgmp3-dev libpcre3-dev freetds-dev libssl-dev libffi-dev
fi

INCDIR=~/Unix/${OSTYPE}/include
if [ ! -e ${INCDIR} ] ; then
    mkdir -p ${INCDIR}
fi

CLDIR=`pwd`
CL=`basename ${CLDIR}`
if [ ! -e ${INCDIR}/${CL} ] ; then
    pushd ${INCDIR}
    ln -s ${CLDIR}
    popd
fi

PICDIR=`dirname ${CL}`/piclib
PIC=`basename ${PICDIR}`
if [ ! -e ${INCDIR}/${PIC} ] ; then
    pushd ${INCDIR}
    ln -s ${PICDIR}
    popd
fi

pushd ../piclib
if make lib${PIC}.a ; then
    mkdir -p ~/Unix/${OSTYPE}/lib
    if [ ! -e ~/Unix/${OSTYPE}/lib/lib${PIC}.a ] ; then
	ln -s `pwd`/lib${PIC}.a ~/Unix/${OSTYPE}/lib
    fi
    popd
    if make lib${CL}.a ; then
	if [ ! -e ~/Unix/${OSTYPE}/lib/lib${CL}.a ] ; then
	    ln -s `pwd`/lib${CL}.a ~/Unix/${OSTYPE}/lib
	fi
    fi
fi
