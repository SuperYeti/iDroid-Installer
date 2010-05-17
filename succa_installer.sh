#!/bin/bash

V_IP="192.168.0.3"                #IPHONE IP
V_PASS="alpine"                   #IPHONE ROOT PASSWORD

#remove the line below
echo -e "\nOpen this file, change ip and root password, then remove this line ;) \n\n" ; exit

#
# DO NOT EDIT BELOW UNLESS YOU ARE KNOWING WHAT ARE YOU DOING
#
V_VERSION=2010051600
V_WIFI_DRIVER=8
V_DEVICE="iPhone"
V_DIR="./succa_installer_files"
V_LOGIN="root"                   
V_MNT=mnt/android
V_IDROID_ZIMAGE_URL="http://idroid.nickpack.com/kernel/zImage-3G/bluerise.8d956f1.nickpack.zip" #"http://noltari.googlecode.com/svn/trunk/idroid/zImage.zip"
V_IDROID_IMAGE_URL="http://dl.dropbox.com/u/1927334/idroid-0.1b_rooted_with_sd_emulation_and_dnsfix.zip"
V_MARVELL_DRIVER="http://extranet.marvell.com/drivers/files/SD-8686-LINUX26-SYSKT-9.70.3.p24-26409.P45-GPL.zip"

V_SD8686_V8="http://git.kernel.org/?p=linux/kernel/git/dwmw2/linux-firmware.git;a=blob_plain;f=libertas/sd8686_v8.bin;hb=HEAD"
V_SD8686_V8_HELPER="http://git.kernel.org/?p=linux/kernel/git/dwmw2/linux-firmware.git;a=blob_plain;f=libertas/sd8686_v8_helper.bin;hb=HEAD"
V_IDROID_CALLSUPPORT_SO="http://github.com/SuperYeti/iDroid-Installer/raw/master/compiled/libreference-ril.so"
V_ALSA_CONF="http://github.com/planetbeing/vendor_apple/raw/donut-iphone/3g-asound.conf"
V_ALSA_STATE="http://github.com/planetbeing/vendor_apple/raw/donut-iphone/3g-asound.state"
isDebian() {

  if [ -f "/etc/debian_version" ]
  then
        return 1
  else
  	return 0
  fi
}

init() {
	sudo echo 1 > /dev/null
	echo -e "\nSucca Installer version $V_VERSION\n"
}

err_check() {

	if [ $ERR -ne 0 ]; then
		echo "An error occured!"
		echo "Please launch again the script with 'sh -x succa_installer.sh' for having more info!"
		exit;
	fi
	echo "[ OK ]"
}

#
# IS THE DEVICE REACHABLE?
#
ssh_works() {

	echo -e "\nTesting if $V_DEVICE is reachable....\c "
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP ls 1> /dev/null 2>&1
	ERR=$?

	if [ $ERR -ne 0 ]; then
		if [ $ERR -eq 255 ]; then
			echo "ERROR: Host unreachable: is openssh installed on $V_DEVICE using Cydia?";
			exit;
		elif [ $ERR -eq 6 ]; then
			echo -e "\n*\n* Digit "yes" and then your iphone root password please!\n*"
			ssh -l$V_LOGIN $V_IP exit
#			exit;
		elif [ $ERR -eq 5 ]; then
			"ERROR: Incorret login/password"
			exit;
		else
			echo -e "ERROR: Some error occurred! ($ERR)."
			exit;
		fi
	else
		echo "[ OK ]"
	fi
}

#
# DIR
#
create_dir() {

	echo -e "\nTesting if $V_DIR exists...\c"
	if [ -d $V_DIR ]; then
		echo "[ OK ]"
	else
		mkdir $V_DIR
		ERR=$?
		err_check
	fi

	cd $V_DIR

	echo -e "\nTesting if $V_MNT exists...\c"
	if [ -d $V_MNT ]; then
		echo "[ OK ]"
	else
		mkdir -p $V_MNT
		ERR=$?
		err_check
	fi

}

#
# INSTALL MISSING PACKAGES
#

install_pkgs_local() {

	echo -e "\nVerifying packages to install locally...   \c"
	sudo apt-get install -y sshpass git-core libssl-dev libusb-1.0-0-dev libusb-dev libreadline-dev libpthread-stubs0-dev texinfo libpng12-dev 1> /dev/null 2>&1

	ERR=$?
	if [ $ERR -ne 0 ]; then
			echo "An error occured ($ERR)!"
			exit;
	fi
	echo "[ OK ]"
}

install_pkgs_remote() {

	PKG=""
	echo -e "\nVerifying packages to install remotely...   \c"

	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP which apt-get > /dev/null

	ERR=$?	
	if [ $ERR -ne 0 ]; then
		echo -e "ERR: Install 'apt 0.7 strict' on your $V_DEVICE using Cydia!"
		exit
	fi

	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP dpkg -l | grep "coreutils " | grep "^ii" > /dev/null
	ERR=$?
	
	if [ $ERR -ne 0 ]; then
		PKG="$PKG coreutils"
	fi

	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP dpkg -l | grep iokittools | grep "^ii" > /dev/null
	ERR=$?
	
	if [ $ERR -ne 0 ]; then
		PKG="$PKG iokittools"
	fi

	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP which vim  > /dev/null
	ERR=$?
	
	if [ $ERR -ne 0 ]; then
		PKG="$PKG vim"
	fi

	echo "[ OK ]"

	if [ ! -s $PKG  ]; then
		echo -e "\nWait while packages are being installed on $V_DEVICE:$PKG \c"
		sshpass -p $V_PASS ssh $V_LOGIN@$V_IP apt-get install -y $PKG > /dev/null
		ERR=$?
	
		if [ $ERR -ne 0 ]; then
			echo "An error occured!"
			exit;
		fi
		echo "[ OK ]"
	fi
	
}

#
# CREATE NEEDED FILES ON DEVICE AND TRANSFER ON PC
#

create_bin_files() {
	
	FILE="zephyr2_cal.bin"
	echo -e "\nCreating $FILE on $V_DEVICE...\c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "ioreg -l -w 0 | grep '\"Calibration Data\" =' | cut -d '<' -f2 | cut -d '>' -f1 | xxd -r -ps - $FILE"
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "An error occured!"
		exit;
	fi
	echo "[ OK ]"

	echo -e "\nTransfering $FILE from $V_DEVICE...\c"
	sshpass -p $V_PASS scp -C $V_LOGIN@$V_IP:$FILE .
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "Error transfering $FILE!"
		exit;
	fi
	echo "[ OK ]"

	if [ -z $FILE -o ! -e $FILE ]; then
		echo "$FILE is empty or not exits, check in $V_DIR!"
		exit;	
	fi

	FILE="zephyr2_proxcal.bin"
	echo -e "\nCreating $FILE on $V_DEVICE...\c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "ioreg -l -w 0 | grep '\"Prox Calibration Data\" =' | cut -d '<' -f2 | cut -d '>' -f1 | xxd -r -ps - $FILE"
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "An error occured!"
		exit;
	fi
	echo "[ OK ]"

	echo -e "\nTransfering $FILE from $V_DEVICE...\c"
	sshpass -p $V_PASS scp -C $V_LOGIN@$V_IP:$FILE .
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "Error transfering $FILE!"
		exit;
	fi
	echo "[ OK ]"

	if [ -z $FILE -o ! -e $FILE ]; then
		echo "$FILE is empty or not exits, check in $V_DIR!"
		exit;	
	fi

	#IPHONE_FW="/private/var/stash/share/firmware/multitouch/iPhone.mtprops"
	FILE="zephyr2.bin"
	
	#echo -e "\nSearching `basename $FILE`... \c"
	#sshpass -p $V_PASS ssh $V_LOGIN@$V_IP ls $IPHONE_FW > /dev/null
	#ERR=$?
	#if [ $ERR -ne 0 ]; then
	#	echo -e "ERR: Cannot find!\n\n*** Are you running 3.0 or lower? It is unsupported! ***\n"
	#	exit;
	#fi
	#echo "[ OK ]"

	echo -e "\nSearching iPhone.mtprops...\c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "find /private/var/ -name iPhone.mtprops | head -n1 > /tmp/dummy.txt"
	ERR=$?
	err_check

	echo -e "\nVerifying iPhone.mtprops...\c"
#	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP ls $IPHONE_FW > /dev/null
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP test -s /tmp/dummy.txt
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo -e "ERR: Cannot find!\n\n*** Are you running 3.0 or lower? It is unsupported! ***\n"
		exit;
	fi
	echo "[ OK ]"

	echo -e "\nGenerating $FILE from $V_DEVICE...\c"
#	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "cat $IPHONE_FW | grep -B2 0x0049 | grep data | sed 's/^\t\t<data>//' | sed 's/<\/data>$//' | base64 -d > $FILE"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "cat  \`cat /tmp/dummy.txt\` | grep -B2 0x0049 | grep data | sed 's/^\t\t<data>//' | sed 's/<\/data>$//' | base64 -d > $FILE"
	if [ $ERR -ne 0 ]; then
		echo "An error occured!"
		exit;
	fi
	echo "[ OK ]"

	echo -e "\nTransfering $FILE from $V_DEVICE...\c"
	sshpass -p $V_PASS scp -C $V_LOGIN@$V_IP:$FILE .
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "Error transfering $FILE!"
		exit;
	fi
	echo "[ OK ]"
}

#
# GET WIFI DRIVER
# 

get_wifi_drivers() {

mkdir wifi

if [ $V_WIFI_DRIVER -eq 9 ]; then
	echo -e "\nDownloading Wifi driver from Marvel site... \c"
	wget -q $V_MARVELL_DRIVER -O wifi.zip
	ERR=$?
	err_check

	echo -e "\nUnpacking Wifi driver... \c"
	unzip wifi.zip -d wifi_tmp > /dev/null
	ERR=$?
	err_check

	echo -e "\nUnpacking inner Wifi package.. \c"
	tar -xf wifi_tmp/SD-8686-FEDORA26FC6-SYSKT-GPL-9.70.3.p24-26409.P45.tar -C wifi
	ERR=$?
	err_check

	mv wifi/FwImage/helper_sd.bin sd8686_helper.bin
	mv wifi/FwImage/sd8686.bin .
else
	wget -q "$V_SD8686_V8" -O sd8686.bin
	ERR=$?
	err_check
	wget -q "$V_SD8686_V8_HELPER" -O sd8686_helper.bin
	ERR=$?
	err_check
fi;

}

#
# GET ANDROID IMAGE AND PATCH
#

get_android_image() {

	echo -e "\nGetting unofficial android image 0.1b (will take some time)... \c"
	wget -q $V_IDROID_IMAGE_URL -O idroid.zip
	ERR=$?
	err_check

	echo -e "\nGetting patched zImage... \c"
	#wget -q $V_IDROID_ZIMAGE_URL -O zImage.tar.gz
	wget -q $V_IDROID_ZIMAGE_URL -O zImage.zip
	ERR=$?
	err_check
	
	echo -e "\nUnpacking patched zImage... \c"
	unzip zImage.zip > /dev/null
	ERR=$?
	err_check

	
	echo -e "\nGetting patched libreference-ril.so... \c"
	wget -q $V_IDROID_CALLSUPPORT_SO -O libreference-ril.so
	ERR=$?
	err_check
	
	FILE="/var/root/Library/Lockdown/activation_records/wildcard_record.plist"
	echo -e "\nExtracting Activation Token from $V_DEVICE... \c"
	sshpass -p $V_PASS scp -C $V_LOGIN@$V_IP:$FILE .
	ERR=$?
	err_check

	echo -e "\nGetting asound.conf... \c"
	wget -q $V_ALSA_CONF -O asound.conf
	ERR=$?
	err_check
	
	echo -e "\nGetting asound.state... \c"
	wget -q $V_ALSA_STATE -O asound.state
	ERR=$?
	err_check

	echo -e "\nUnpacking unofficial android image 0.1b... \c"
	unzip idroid.zip -d idroid01b > /dev/null
	ERR=$?
	err_check

	echo -e "\nCopying zImage... \c"
	cp zImage idroid01b/idroid-0.1b_rooted_with_sd_emulation/var
	ERR=$?
	err_check

	mv idroid01b/idroid-0.1b_rooted_with_sd_emulation/var .
	mv idroid01b/idroid-0.1b_rooted_with_sd_emulation/sdcard/512mb/sdcard.img var
	
	echo -e "\nUnpacking android.img.gz... \c"
	gunzip var/android.img.gz
	ERR=$?
	err_check

	echo -e "\nMounting android image... \c"
	sudo mount -o loop var/android.img $V_MNT
	ERR=$?
	err_check
	
	echo -e "\nCopying drivers to the image... \c"
	sudo cp  *.bin $V_MNT/lib/firmware/
	ERR=$?
	err_check

	echo -e "\nUnounting android image... \c"
	sudo umount $V_MNT
	ERR=$?
	err_check

	echo -e "\nCompressing android.img.gz... \c"
	gzip var/android.img
	ERR=$?
	err_check

}

#
# PATCH SYSTEM.IMG
#

patch_system_image() {

	echo -e "\nMounting system image... \c"
	sudo mount -o loop var/system.img $V_MNT
	ERR=$?
	err_check
	
	echo -e "\nCopying drivers to the image... \c"
	sudo cp  *.bin $V_MNT/etc/firmware/
	ERR=$?
	err_check

	echo -e "\nInjecting call support to the image... \c"
	sudo cp libreference-ril.so $V_MNT/lib/
	ERR=$?
	err_check
	
	echo -e "\nInjecting Activation Token from device... \c"
	sudo cp wildcard_record.plist $V_MNT/lib/
	ERR=$?
	err_check
	
	echo -e "\nInjecting Audio Drivers... \c"
	sudo cp asound.conf $V_MNT/etc/
	ERR=$?
	err_check
	sudo cp asound.state $V_MNT/etc/
	ERR=$?
	err_check
	
	echo -e "\nUnounting system image... \c"
	sudo umount $V_MNT
	ERR=$?
	err_check

}


# PATCH RAMDISK.IMG
#

patch_ramdisk_image() {

	echo -e "\nMounting ramdisk image... \c"
	sudo mount -o loop var/ramdisk.img $V_MNT
	ERR=$?
	err_check
	
	echo -e "\nPatching init.rc... \c"
	perl -pi -e "s/-d \/dev\/ttyS1/-d \/dev\/ttyS4 -3/g" $V_MNT/init.rc
	ERR=$?
	err_check

	echo -e "\nUnounting system image... \c"
	sudo umount $V_MNT
	ERR=$?
	err_check

}

#
# TRANSFER FILES TO THE DEVICE
#

transfer_to_device() {

	echo -e "\nRemoving previously installed remote files... \c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP rm -f /private/var/ramdisk.img /private/var/system.img /private/var/userdata.img /private/var/cache.img /private/var/android.img.gz /private/var/zImage /private/var/sdcard.img
	ERR=$?
	err_check

	echo -e "\nTransfering files to $V_DEVICE... \c"
	sshpass -p $V_PASS scp -C var/* $V_LOGIN@$V_IP:/private/var
	ERR=$?
	err_check

	echo -e "\nChanging permissions on remote files... \c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP chmod 755 /private/var/ramdisk.img /private/var/system.img /private/var/userdata.img /private/var/cache.img /private/var/android.img.gz /private/var/zImage /private/var/sdcard.img
	ERR=$?
	err_check

}

get_git() {

	#echo -e "\nGetting latest commit of OpeniBoot... \c"	
	#git clone git://github.com/planetbeing/iphonelinux.git > /dev/null 2>&1
	#ERR=$?
	#err_check
	
	echo -e "\nCompiling toolchain (will take a while)... "	
	cd iphonelinux
	sudo toolchain/build-toolchain.sh make
	ERR=$?
	err_check
	
}

#
# REMOVE IPHONE GENERATED FILES
#

remove_files() {
	
	echo -e "\nCleaning temporary generated files on $V_DEVICE...\c"
	sshpass -p $V_PASS ssh $V_LOGIN@$V_IP "rm zephyr*bin"
	ERR=$?
	err_check
}

#
# MAIN
#

ERR=0
clear

init
install_pkgs_local
ssh_works
create_dir
install_pkgs_remote
create_bin_files
remove_files
get_wifi_drivers
get_android_image
patch_system_image
patch_ramdisk_image
transfer_to_device

#get_git

echo ":)"
