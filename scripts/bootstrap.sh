#!/bin/sh
#
# $Id: bootstrap.sh 19 2005-02-20 20:55:03Z bwolf $
#
#  Copyright 2005 Marcus Geiger
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
set -e
umask 027

# -----------------------------------------------------------------------------
# NOTES:
#  1) download MoinMoin (as tar.gz) and place somewhere (see below)
#  2) download Twisted (as tar.bz2) and place somewhere (see belog)
#  3) download libarchive (as tar.gz) and place somewhere (see below)
#  3) edit the user configuration
#  4) run this script from the project base directory
#
# DOWNLOAD URLS
#  a) MoinMoin:   http://moinmoin.wikiwikiweb.de/
#  b) Twisted:    http://twistedmatrix.com/products/twisted
#  c) libarchive: http://people.freebsd.org/~kientzle/libarchive/
#
# TESTED PRODUCT VERSIONs
#   I) MoinMoin:   1.3.1, 1.3.3
#  II) Twisted:    1.3.0
# III) libarchive: 1.01.022, 1.02.002
#
#
# BEGIN USER CONFIGURATION
MOIN_TAR_GZ_DIST=~/Desktop/Heap/moin-1.3.3.tar.gz
MOIN_RELEASE=moin-1.3.3
TWISTED_TAR_BZ2_DIST=~/Desktop/Heap/Twisted_NoDocs-1.3.0.tar.bz2
TWISTED_RELEASE=Twisted-1.3.0
MOIN_LANGUAGES_TO_PURGE='ge he|ge nb|ge sr|ge zh_tw|ge nl|ge sv|ge fr|ge da|ge sv|ge es|ge zh|ge ru|ge it|ge nl|ge zh-tw|ge zh_tw|ge ru|ge es'
LIBARCHIVE_TAR_GZ_DIST=~/Desktop/Heap/libarchive-1.02.002.tar.gz
LIBARCHIVE_RELEASE=libarchive-1.02.002
# END USER CONFIGURATION ------------------------------------------------------




# -----------------------------------------------------------------------------
# BEGIN OF DO NOT EDIT SECTION
# -----------------------------------------------------------------------------

# Ensure the current Directory contains a subdirectory Named MoinX.xcode
# such that the script called from the project base directory.
if [ ! -d MoinX.xcode ]; then
    echo Script must be called from the project root directory
    exit 64
fi

# Debugging?
if [ "$1" = "-d" ]; then
    set -x
fi

base=`pwd`
generated=$base/generated
build_dir=$generated/build
src_dir=$build_dir/src
out_dir=$generated/WikiBootstrap
log_dir=$build_dir/log
instance_name=instance
instance_default="$out_dir/$instance_name"
instance_default_archive="$out_dir/$instance_name.tar.bz2"
bin_dir="$out_dir/bin"
python_lib_dir="$out_dir/pythonlib"
htdocs_dir="$out_dir" # source folder is a htdocs dir
python_run_dir="$out_dir/pyrun"
moin_source=$src_dir/$MOIN_RELEASE
moin_install_log=$log_dir/moin-install.log
moin_pages_dir=$build_dir/share/moin/underlay/pages
moin_license=$moin_source/COPYING
twisted_install_log=$log_dir/twisted-install.log
twisted_source=$src_dir/$TWISTED_RELEASE
twisted_packages_dir=$build_dir/lib/python2.3/site-packages/twisted
twisted_remove_dirs="conch enterprise flow im lore mail manhole names news test trial words xish protocols/gps protocols/jabber protocols/mice"
twisted_license=$twisted_source/LICENSE
python_version=`python -V 2>&1 | sed 's/Python[ ]*//'`
libarchive_source=$src_dir/$LIBARCHIVE_RELEASE
libarchive_configure_log=$log_dir/libarchive-configure.log
libarchive_make_log=$log_dir/libarchive-make.log
libarchive_make_install_log=$log_dir/libarchive-make-install.log

# -----------------------------------------------------------------------------
# check if required files exist
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

check_required_dep() {
    archive_name="$1"
    archive_path="$2"
    msg="Checking for $archive_name: "
    if [ ! -f "$archive_path" ]; then
        msg="$msg MISSING -> Can't locate $archive_path"
        echo $msg
        exit 1
    else
        msg="$msg Ok"
        echo $msg
    fi
}

check_required_dep $MOIN_RELEASE $MOIN_TAR_GZ_DIST
check_required_dep $TWISTED_RELEASE $TWISTED_TAR_BZ2_DIST
check_required_dep $LIBARCHIVE_RELEASE $LIBARCHIVE_TAR_GZ_DIST

# -----------------------------------------------------------------------------
# prepare
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

echo cleaning up generated in $generated
echo cleaning up build dir in $build_dir
echo cleaning up out dir in $out_dir
rm -rf $generated 
echo creating...
mkdir -p \
	"$generated" \
	"$build_dir" \
	"$src_dir" \
	"$out_dir" \
	"$log_dir"
echo creating dirs in $out_dir
mkdir -p \
	"$bin_dir" \
	"$python_lib_dir" \
	"$htdocs_dir" \
	"$python_run_dir" \
	"$instance_default"

# -----------------------------------------------------------------------------
# unpack
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

echo unpacking, this takes some time!
cd $src_dir
echo unpacking moin wiki in $src_dir
tar xfz $MOIN_TAR_GZ_DIST
echo unpacking twisted in $src_dir
tar xfj $TWISTED_TAR_BZ2_DIST
echo unpacking libarchive in $src_dir
tar xfz $LIBARCHIVE_TAR_GZ_DIST

# -----------------------------------------------------------------------------
# moin
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

echo building moin in $moin_source
cd $moin_source
echo ... installation logfile in $moin_install_log
echo ... install dir is in $build_dir
python setup.py --quiet install --prefix=$build_dir --record=$moin_install_log
ret=$?
if [ $ret -ne 0 ]; then
	echo failed to install moin in $build_dir
	exit $ret
fi

echo removing unwanted language pages from moin in $moin_pages_dir
echo ... deleting languages $MOIN_LANGUAGES_TO_PURGE
cd $moin_pages_dir
egrep '^#language' */*/* | egrep "$MOIN_LANGUAGES_TO_PURGE" > results
sed -e 's/\/.*// ; s/^/rm -rf "/ ; s/$/"/' results > removedirs.sh
sh ./removedirs.sh
rm -f results
rm -f removedirs.sh

# -----------------------------------------------------------------------------
# twisted
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

echo building twisted in $twisted_source
cd $twisted_source
echo ... installation logfile in $twisted_install_log
echo ... install dir is in $build_dir
python setup.py --quiet install --prefix=$build_dir --record=$twisted_install_log
ret=$?
if [ $ret -ne 0 ]; then
	echo failed to install twisted in $build_dir
	exit $ret
fi

echo removing unneeded packages from twisted in $twisted_packages_dir
echo ...deleting packages $twisted_remove_dirs
for x in $twisted_remove_dirs; do # no quotes!
	dir="$twisted_packages_dir/$x"
	if [ -d "$dir" ]; then
		echo "   removing $x"
		rm -rf "$dir"
	else
		echo "Directory $dir doesn't exist!"
		exit 2
	fi
done

# -----------------------------------------------------------------------------
# libarchive
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

echo building libarchive in $libarchive_source
cd $libarchive_source
echo ... configure logfile in $libarchive_configure_log
echo ... make logfile in $libarchive_make_log
echo ... installation dir is in $build_dir
./configure --prefix=$build_dir >"$libarchive_configure_log" 2>&1
ret=$?
if [ $ret -ne 0 ]; then
    echo configure script failed
    exit $ret
fi
make >"$libarchive_make_log" 2>&1
ret=$?
if [ $ret -ne 0 ]; then
    echo make failed
    exit $ret
fi
make install >"$libarchive_make_install_log" 2>&1
ret=$?
if [ $ret -ne 0 ]; then
    echo make failed
    exit $ret
fi

## -----------------------------------------------------------------------------
## copy to base and assemble directories
## -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""

cd $generated
# bin
S=$build_dir/bin/twistd
echo copying $S to "$bin_dir"
cp -p $S "$bin_dir"
# pythonlib
echo
S=$build_dir/lib/python$python_version/site-packages/* 
echo copying $S to "$python_lib_dir"
cp -Rp $S "$python_lib_dir"
# htdocs
echo
S=$build_dir/share/moin/htdocs 
echo copying $S to "$htdocs_dir"
cp -Rp $S "$htdocs_dir"
# moin start script and configuration
echo
cd $base
S=python/*.py
echo copying $S to "$python_run_dir"
cp -p $S "$python_run_dir"
# instance
echo
S=$build_dir/share/moin/data
echo copying $S to "$instance_default"
cp -Rp $S "$instance_default"
echo
S=$build_dir/share/moin/underlay
echo copying $S to "$instance_default"
cp -Rp $S "$instance_default"
# tar.bz2 instance
echo
cd "$out_dir"
echo creating $instance_default_archive
tar cfj `basename "$instance_default_archive"` `basename "$instance_name"`
echo
echo removing intermediate "$instance_name"
rm -rf "$instance_name"
# Licenses
echo
cd "$out_dir"
echo copying licenses of MoinMoin and Twisted
cp $moin_license LICENSE.MoinMoin
cp $twisted_license LICENSE.Twisted
# Status menu icon
echo
cd $base
echo building statusmenu icon
tiffutil -cat Icons/MoinX_16.tif -out $base/MoinX_statusmenuicon.tif

# -----------------------------------------------------------------------------
# notes
# -----------------------------------------------------------------------------
echo ""
echo "###############################################################"
echo ""
echo Now fire up XCode and build.
