#!/bin/sh
#
#  build_nano_wrap.sh
#  Copyright (C) 2004-2009 Scott Ullrich
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#  
#  1. Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#  
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  
#  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
#  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
#  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
#
# Crank up error reporting, debugging.
#  set -e 
#  set -x

# If a full build has been performed we need to nuke
# /usr/obj.pfSense/ since embedded uses a different
# src.conf
if [ -f /usr/obj.pfSense/pfSense.$FREEBSD_VERSION.world.done ]; then
	echo -n "Removing /usr/obj* since full build performed prior..."
	rm -rf /usr/obj*
	echo "done."
fi

# Suck in local vars
. ./pfsense_local.sh

# Optional Per build config file.
# Specify a file with build parameters to override the default.
if [ "$1" != "" ]; then
	[ -r "$1" ] && . $1
fi

# Suck in script helper functions
. ./builder_common.sh

# This should be run first
launch

# Make sure source directories are present.
ensure_source_directories_present

# Ensure binaries are present that builder system requires
install_required_builder_system_ports

# Output build flags
print_flags

# Allow old CVS_CO_DIR to be deleted later
chflags -R noschg $CVS_CO_DIR

# Yep we are building nanobsd
export IS_NANO_BUILD=yes

# Do not compress this image which is used on the ISO
export NO_COMPRESSEDFS=yes

if [ ! -z "${CUSTOM_REMOVE_LIST:-}" ]; then
	echo ">>> Using ${CUSTOM_REMOVE_LIST:-} ..."
	export PRUNE_LIST="${CUSTOM_REMOVE_LIST:-}"
else
	echo ">>> Using ${BUILDER_SCRIPTS}/remove.list.iso.$FREEBSD_VERSION ..."
	export PRUNE_LIST="${BUILDER_SCRIPTS}/remove.list.iso.$FREEBSD_VERSION"
fi

# Use embedded src.conf
export SRC_CONF="${BUILDER_SCRIPTS}/conf/src/src.conf.embedded.$FREEBSD_VERSION"
export SRC_CONF_INSTALL="${BUILDER_SCRIPTS}/conf/src/src.conf.embedded.$FREEBSD_VERSION.install"

# nopacket is required for WRAP's
export NANO_BOOT0CFG="-o nopacket -s 1 -m 3"

# Clean up items that should be cleaned each run
freesbie_clean_each_run

# Checkout a fresh copy from pfsense cvs depot
update_cvs_depot

# Calculate versions
version_kernel=`cat $CVS_CO_DIR/etc/version_kernel`
version_base=`cat $CVS_CO_DIR/etc/version_base`
version=`cat $CVS_CO_DIR/etc/version`

# Build if needed and install world and kernel
echo ">>> Building world for Embedded... $FREEBSD_VERSION  $FREEBSD_BRANCH ..."
make_world

# Build kernels
echo ">>> Building kernel configs: $BUILD_KERNELS for FreeBSD: $FREEBSD_BRANCH ..."
build_all_kernels

# Add extra files such as buildtime of version, bsnmpd, etc.
echo ">>> Phase populate_extra..."
cust_populate_extra

# Add extra pfSense packages
install_custom_packages

# Overlay pfsense checkout on top of FreeSBIE image
# using the customroot plugin
echo ">>> Merging extra items..."
freesbie_make extra

# Overlay host binaries
cust_overlay_host_binaries

# Must be run after overlay_host_binaries and freesbie_make extra
cust_fixup_nanobsd

# Check for custom config.xml
cust_install_config_xml

echo -n ">>> Creating md5 summary of files present..."
rm -f $PFSENSEBASEDIR/etc/pfSense_md5.txt
echo "#!/bin/sh" > $PFSENSEBASEDIR/chroot.sh
echo "find / -type f | /usr/bin/xargs /sbin/md5 >> /etc/pfSense_md5.txt" >> $PFSENSEBASEDIR/chroot.sh
chmod a+rx $PFSENSEBASEDIR/chroot.sh
chroot $PFSENSEBASEDIR /chroot.sh 2>/dev/null
rm $PFSENSEBASEDIR/chroot.sh
echo "Done."

# Copy config.xml
copy_config_xml_from_conf_default

# Install custom pfSense-XML packages from a chroot
# and ensure php.ini is setup and ready to run.
# php.ini is auto generated on 2.0 from the list
# of php installed modules.
pfsense_install_custom_packages_exec

# Test PHP installation
test_php_install

# Invoke FreeSBIE2 toolchain
check_for_zero_size_files
freesbie_make clonefs

# Setup NanoBSD specific items
FlashDevice $FLASH_MODEL $FLASH_SIZE
setup_nanobsd_etc
setup_nanobsd

# Overlay any loader.conf customziations
install_extra_loader_conf_options

# Get rid of non-wanted files
prune_usr

# Create the NanoBSD disk image
create_nanobsd_diskimage

# Wrap up the show, Johnny
echo "Image completed."
echo "$MAKEOBJDIRPREFIX/"
ls -lah $MAKEOBJDIRPREFIX/nanobsd*

# E-Mail that we are done.
email_operation_completed

# Email that the operation has completed
email_operation_completed

# Run final finish routines
finish
