#!/bin/sh

# pfSense master builder script
# (C)2005 Scott Ullrich and the pfSense project
# All rights reserved.

#set -e -u

. ../freesbie/config.sh
. ../freesbie/.common.sh

# Define the Kernel file we're using
export KERNCONF=pfSense.6

PFSENSECVS=/home/pfsense/pfSense
UPDATES=/home/pfsense/updates

cd /home/pfsense
rm -rf $PFSENSECVS

cvs -d:ext:sullrich@216.135.66.16:/cvsroot co pfSense

mkdir -p $PFSENSECVS/libexec
cp /libexec/ld-elf.so.1 $PFSENSECVS/libexec/ld-elf.so.1
cp /lib/libedit* $PFSENSECVS/lib/
cp /bin/sh $PFSENSECVS/bin/
cp /lib/libncurses.so.5 $PFSENSECVS/lib/
cp /lib/libc* $PFSENSECVS/lib/
cp /bin/ln /bin/rm $PFSENSECVS/bin/
mkdir -p $LOCALDIR/var/run
echo "#!/bin/sh" > $PFSENSECVS/script
echo ln -s /cf/conf /conf >> $PFSENSECVS/script
echo ln -s /conf /cf/conf >> $PFSENSECVS/script
echo ln -s /var/etc/hosts /etc/hosts >> $PFSENSECVS/script
echo ln -s /lib/libm.so.3 /lib/libm.so.2 >> $PFSENSECVS/script
cat $PFSENSECVS/script
chmod a+x $PFSENSECVS/script
chroot $PFSENSECVS/ /bin/sh /script

echo Nuking CVS...
find $PFSENSECVS -type d -name CVS -exec rm -rf {}/* \;
find $PFSENSECVS -type d -name CVS -exec rm -rf {} \;
rm -rf $PFSENSECVS.tgz
cd $PFSENSECVS/ && tar czPf /home/pfsense/pfSense.tgz .

cd $LOCALDIR
./0.rmdir.sh
./1.mkdir.sh
#./2.buildworld.sh
./3.installworld.sh

# nuke some extra stuff
find /usr/local/livefs -name sysinstall -exec rm -rf {} \;

cd /home/pfsense/pfSense/ && tar czPf /tmp/pfSense.tgz .

# Uncomment for wrap builds.
cd /usr/local/livefs && tar xzpf /tmp/pfSense.tgz
rm /usr/local/livefs/etc/hosts

cd /home/pfsense/freesbie

./4.kernel.sh pfSense.6
#./4.kernel.sh pfSense_wrap.6

cp /sbin/brconfig /usr/local/livefs/sbin/
cp /usr/sbin/bsnmpd /usr/local/livefs/sbin/
chmod a+rx /usr/local/livefs/sbin/brconfig

./5.patchfiles.sh
./6.packages.sh
./7.customuser.sh
#./71.bsdinstaller.sh

# restore values if overwritten accidently.
. ../freesbie/config.sh
. ../freesbie/.common.sh

cp /sbin/pf* $FREESBIEBASEDIR/sbin
cp /sbin/pf* /home/pfsense/pfSense/sbin/
chmod a+rx $FREESBIEBASEDIR/sbin/pf*
cp $LOCALDIR/files/gettytab $FREESBIEBASEDIR/etc/
rm -rf $FREESBIEBASEDIR/dist/pfSense.tgz
cp /home/pfsense/pfSense.tgz $FREESBIEBASEDIR/dist/
cp /usr/lib/libstdc* $FREESBIEBASEDIR/usr/lib/

mkdir -p $FREESBIEBASEDIR/usr/local/share/dfuibe_installer
cp $LOCALDIR/files/sources.conf \
	$FREESBIEBASEDIR/usr/local/share/dfuibe_installer/sources.conf
rm -rf $FREESBIEBASEDIR/etc/shells
cp $LOCALDIR/files/shells $FREESBIEBASEDIR/etc/shells
echo exit > $FREESBIEBASEDIR/root/.xcustom.sh
touch $FREESBIEBASEDIR/root/.hushlogin
cp $FREESBIEBASEDIR/lib/libc.so.6 $FREESBIEBASEDIR/lib/libc.so.5
cp $FREESBIEBASEDIR/lib/libc.so.6 $FREESBIEBASEDIR/lib/libc.so.4

# bsnmpd related
mkdir -p /usr/local/livefs/usr/share/snmp/defs/
cp -R /usr/share/snmp/defs/ /usr/local/livefs/usr/share/snmp/defs/

version_kernel=`cat /home/pfsense/pfSense/etc/version_kernel`
version_base=`cat /home/pfsense/pfSense/etc/version_base`
version=`cat /home/pfsense/pfSense/etc/version`

# pf related binaries
cd /usr/src/sbin/pfctl && make && make install && cd /home/pfsense/freesbie
cd /usr/src/sbin/pflogd && make && make install && cd /home/pfsense/freesbie
cp /sbin/pfctl /usr/local/livefs/sbin/
cp /sbin/pflogd /usr/local/livefs/sbin/
cp /sbin/devd /usr/local/livefs/sbin/devd
chmod a+rx /usr/local/livefs/sbin/*

# Set buildtime
date > /usr/local/livefs/etc/version.buildtime

#./8.preparefs.sh
#./81.mkiso.sh

mkdir -p $UPDATES

