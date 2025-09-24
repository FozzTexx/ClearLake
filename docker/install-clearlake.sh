#!/bin/sh

set -e

SCRIPTPATH=$(realpath "$0")
SCRIPTDIR=$(dirname "${SCRIPTPATH}")

BASE=$(basename $0)
TMP=/tmp/${BASE}.$$
if [ -z "$1" ] ; then
    mkdir ${TMP}
    cd ${TMP}
else
    cd "$1"
fi

export OSTYPE=${OSTYPE-`/bin/bash -c 'echo $OSTYPE'`}
ARCH=$(arch)

cd /usr/local
git clone ${SCRIPTDIR}/fzlocal.bundle
FZDIR=/usr/local/fzlocal
ln -s ${FZDIR}/Makefiles/$OSTYPE /usr/local/Makefiles
mkdir -p ~/Developer/${OSTYPE}
ln -s /usr/local/Makefiles ~/Developer/${OSTYPE}/Makefiles

mkdir -p ~/Unix/${OSTYPE}/include
mkdir -p ~/Unix/${OSTYPE}/lib/${ARCH}

cd ${TMP}
git clone ${SCRIPTDIR}/hoedown.bundle
cd hoedown
make
make install
cd ${TMP}

install_lib()
{
    RESTORE=${PWD}
    LIB=$1
    INCLUDE_DIR=/usr/local/include/${LIB}
    LIB_DIR=/usr/local/lib
    if [ -e ${SCRIPTDIR}/${LIB}.tar ] ; then
	tar -xf ${SCRIPTDIR}/${LIB}.tar
    else
	git clone ${SCRIPTDIR}/${LIB}.bundle
    fi
    cd ${LIB}
    mkdir -p ${INCLUDE_DIR}
    cp *.h ${INCLUDE_DIR}
    make
    mkdir -p ${LIB_DIR}
    for EXT in "so" "a" ; do
	LIB_FILE=${OSTYPE}-${ARCH}_bin/lib${LIB}.${EXT}
	if [ -e ${LIB_FILE} ] ; then
	    break
	fi
    done
    cp ${LIB_FILE} ${LIB_DIR}
    cd ${RESTORE}
}

for EXT in .bundle .tar ; do
    if [ -e ${SCRIPTDIR}/ClearLake-${CL_VERS_MAJOR}${EXT} ] ; then
	ln -s ${SCRIPTDIR}/ClearLake-${CL_VERS_MAJOR}${EXT} ${SCRIPTDIR}/ClearLake${EXT}
    fi
done

install_lib fozzlib
install_lib piclib
install_lib ClearLake

if [ -e ${SCRIPTDIR}/OnionPatch.bundle ] ; then
    install_lib OnionPatch
fi

ldconfig

# CL_PYTHON=ClearLake/python
# if [ -d ${CL_PYTHON} ] ; then
#     make -C ${CL_PYTHON} INSTALL_PREFIX=--prefix=/usr
# fi

# cd
# rm -rf ${TMP}
