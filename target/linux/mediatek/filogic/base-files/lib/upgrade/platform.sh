#!/bin/sh
#
# Copyright (C) 2021 OpenWrt.org
#

PLATFORM_PREPARE_UPGRADE=1

. /lib/upgrade/common.sh
. /lib/upgrade/nand.sh
. /lib/upgrade/emmc.sh
. /lib/upgrade/fit.sh

filogic_get_image_name() {
	local board=$1
	local dtver=0x0

	case "$board" in
	*)
		dtver=0x0
		;;
	esac

echo -n "$dtver"
}

filogic_v1_jffs2_config() {
	# config, invalidate the vendor jffs2 partition triggering recovery instead
	find "$1" -name "mtd*" -o -name "*.jffs2" 2>/dev/null | while read mtdname; do
		[ -f "$mtdname" ] && rm -f "$mtdname"
	done
}

filogic_is_mounted() {
	local target=$1
	mount | grep -q $target
}

filogic_sysupgrade_config() {
	local config_src=/tmp/sysupgrade.tgz

	if [ -f "$config_src" ]; then
		filogic_is_mounted /overlay || mount -o noatime /overlay
		tar xzf "$config_src" -C /overlay max-retries=3
		umount /overlay
	fi
}

filogic_do_upgrade() {
	local sysupgrade_pre_upgrade
	local sysupgrade_post_upgrade
	local sysupgrade_do_upgrade
	local sysupgrade_do_kernel_upgrade

	if [ "$UPGRADE_IMAGE_TYPE" = "kernelpkg" ]; then
		sysupgrade_do_kernel_upgrade
		filogic_sysupgrade_config
	elif [ "$UPGRADE_IMAGE_TYPE" = "rootfspkg" ]; then
		sysupgrade_do_upgrade
		filogic_sysupgrade_config
	else
		sysupgrade_do_upgrade
		filogic_sysupgrade_config
	fi
}

filogic_is_flash_recovery_supported() {
	local board=$1

	case "$board" in
	asus,pac3100|\
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		echo "0"
		;;
	*)
		echo "1"
		;;
	esac
}

filogic_get_root_fstype() {
	local board=$1

	case "$board" in
	*)
		echo "f2fs"
		;;
	esac
}

filogic_get_block_size() {
	local board=$1

	case "$board" in
	*)
		echo "0x800"
		;;
	esac
}

filogic_supports_ubifs() {
	local board=$1

	case "$board" in
	asus,pac3100|\
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		echo "1"
    ;;
	abt,asr3000|\
	acer,predator-w6x-ubootmod|\
	asus,zenwifi-bt8-ubootmod|\
	bananapi,bpi-r3|\
	bananapi,bpi-r3-mini|\
	bananapi,bpi-r4|\
	bananapi,bpi-r4-2g5|\
	bananapi,bpi-r4-poe|\
	bananapi,bpi-r4-lite|\
	bazis,ax3000wm|\
	cmcc,a10-ubootmod|\
	cmcc,rax3000m|\
	comfast,cf-wr632ax-ubootmod|\
	creatlentem,clt-r30b1-ubi|\
	cudy,m3000-v1-ubootmod|\
	cudy,m3000-v2-yt8821-ubootmod|\
	cudy,tr3000-v1-ubootmod|\
	cudy,wbr3000uax-v1-ubootmod|\
	cudy,wr3000e-v1-ubootmod|\
	cudy,wr3000s-v1-ubootmod|\
	cudy,wr3000h-v1-ubootmod|\
	cudy,wr3000p-v1-ubootmod|\
	gatonetworks,gdsp|\
	globitel,bt-r320|\
	h3c,magic-nx30-pro|\
	imou,hx21|\
	jcg,q30-pro|\
	jdcloud,re-cp-03|\
	konka,komi-a31|\
	mediatek,mt7981-rfb|\
	mediatek,mt7988a-rfb|\
	mercusys,mr90x-v1-ubi|\
	netis,eap930-v1|\
	netis,nx30v2|\
	netis,nx31|\
	netis,nx32u|\
	nokia,ea0326gmp|\
	openwrt,one|\
	netcore,n60|\
	netcore,n60-pro|\
	qihoo,360t7|\
	qihoo,360t7-ubi|\
	routerich,ax3000-ubootmod|\
	routerich,be7200|\
	snr,snr-cpe-ax2|\
	tplink,tl-xdr4288|\
	tplink,tl-xdr6086|\
	tplink,tl-xdr6088|\
	tplink,tl-xtr8488|\
	wavlink,wl-wnt100x3-ubootmod|\
	xiaomi,mi-router-ax3000t-ubootmod|\
	xiaomi,redmi-router-ax6000-ubootmod|\
	xiaomi,mi-router-wr30u-ubootmod|\
	zyxel,ex5601-t0-ubootmod|\
	zyxel,wx5600-t0-ubootmod)
		fit_do_upgrade "$1"
		;;
	acer,predator-w6|\
	acer,predator-w6d|\
	acer,vero-w6m|\
	airpi,ap3000m|\
	arcadyan,mozart|\
	glinet,gl-mt2500|\
	glinet,gl-mt2500-airoha|\
	glinet,gl-mt6000|\
	glinet,gl-x3000|\
	glinet,gl-xe3000|\
	huasifei,wh3000|\
	huasifei,wh3000-pro-emmc|\
	smartrg,sdg-8612|\
	smartrg,sdg-8614|\
	smartrg,sdg-8622|\
	smartrg,sdg-8632|\
	smartrg,sdg-8733|\
	smartrg,sdg-8733a|\
	smartrg,sdg-8734)
		CI_KERNPART="kernel"
		CI_ROOTPART="rootfs"
		emmc_do_upgrade "$1"
		;;
	*)
		echo "0"
		;;
	esac
}

filogic_get_supported_image_formats() {
	local board=$1

	case "$board" in
	asus,pac3100)
		echo "asus"
		;;
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		echo "asus"
		;;
	*)
		echo "fit"
		;;
	esac
}

fi_check_kernel_partition_dev_mtdname() {
	[ "$CI_KERNPART" ] && return

	for dev in /dev/mtd[0-9]*; do
		name=$(cat "$dev/name" 2>/dev/null)
		case "$name" in
		KERNEL*|kernel*|LINUX*|Kernel*)
			CI_KERNPART="$(echo "$dev" | sed 's|/dev/mtd||g')"
			return
			;;
		esac
	done
}

fi_check_kernel_partition_dev_mtdnr() {
	[ "$CI_KERNPART" ] && return

	for dev in /dev/mtd[0-9]*; do
		name=$(cat "$dev/name" 2>/dev/null)
		case "$name" in
		ubi0|rootfs)
			CI_KERNPART=$(($(echo "$dev" | sed 's|/dev/mtd||g') - 1))
			return
			;;
		esac
	done
}

filogic_find_kerneldev_by_name() {
	[ "$CI_KERNPART" ] && return

	for dev in /dev/mtd[0-9]*; do
		name=$(cat "$dev/name" 2>/dev/null)
		case "$name" in
		kernel|kernel_a|kernel_b|kernel_1|kernel_2|ap_firmware|os-image)
			CI_KERNPART="$(echo "$dev" | sed 's|/dev/mtd||g')"
			return
			;;
		esac
	done
}

filogic_get_mtd_from_name() {
	local mtdname=$1

	for dev in /dev/mtd[0-9]*; do
		name=$(cat "$dev/name" 2>/dev/null)
		[ "$name" = "$mtdname" ] && echo "$(echo "$dev" | sed 's|/dev/mtd||g')"
	done
}

filogic_is_mtd_recovery_supported() {
	local board=$1
	local ubi
	local parts="$(cat /proc/mtd | grep ubi | awk '{print $1}' | tr -d ':')"

	for part in $parts; do
		ubi="$(/sbin/ubiattach -m $(echo $part | sed 's|mtd||') 2>&1)"
		echo "$ubi" | grep -q "attached" && {
			ubidetach -m $(echo $part | sed 's|mtd||') > /dev/null 2>&1
			echo "1"
			return
		}
	done

	echo "0"
}

filogic_get_ubiinfo() {
	local index=$1
	local mtdname=$2
	local volumes="$(ubinfo -a 2>/dev/null | grep -E "$mtdname" -A 3 | grep Volume | awk '{print $2}')"

	echo "$volumes" | sed -n "${index}p"
}

filogic_jffs2_rootfs() {
	local board=$1

	case "$board" in
	asus,pac3100|\
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		filogic_v1_jffs2_config "$2"
		;;
	esac
}

filogic_do_upgrade() {
	local board=$1
	local cmd=$2
	local file=$3
	local upgrade_size=$4
	local upgrade_type=$5

	case "$upgrade_type" in
	nand)
		CI_KERNPART="kernel"
		nand_do_upgrade "$file"
		;;
	uartnand)
		if [ ! -f /sys/class/ubi/ubi0/subsystem/devices/ubi0 ]; then
			CI_KERNPART="kernel"
			nand_do_upgrade "$file"
		else
			echo "Device already has UBI, skip UART download"
		fi
		;;
	*)
		echo "Unknown upgrade type $upgrade_type"
		;;
	esac
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
	asus,pac3100)
		CI_KERNPART="kernel"
		nand_do_upgrade "$1"
		;;
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		CI_KERNPART="kernel"
		nand_do_upgrade "$1"
		;;
	bananapi,bpi-r4-lite|\
	bananapi,bpi-r3|\
	bananapi,bpi-r4)
		CI_KERNPART="linux"
		nand_do_upgrade "$1"
    ;;
	bazis,ax3000wm|\
	cmcc,a10-ubootmod|\
	cmcc,rax3000m|\
	comfast,cf-wr632ax-ubootmod|\
	creatlentem,clt-r30b1-ubi|\
	cudy,m3000-v1-ubootmod|\
	cudy,m3000-v2-yt8821-ubootmod|\
	cudy,tr3000-v1-ubootmod|\
	cudy,wbr3000uax-v1-ubootmod|\
	cudy,wr3000e-v1-ubootmod|\
	cudy,wr3000s-v1-ubootmod|\
	cudy,wr3000h-v1-ubootmod|\
	cudy,wr3000p-v1-ubootmod|\
	gatonetworks,gdsp|\
	globitel,bt-r320|\
	h3c,magic-nx30-pro|\
	jcg,q30-pro|\
	jdcloud,re-cp-03|\
	konka,komi-a31|\
	mediatek,mt7981-rfb|\
	mediatek,mt7988a-rfb|\
	mercusys,mr90x-v1-ubi|\
	nokia,ea0326gmp|\
	netis,eap930-v1|\
	netis,nx32u|\
	openwrt,one|\
	netcore,n60|\
	qihoo,360t7|\
	qihoo,360t7-ubi|\
	routerich,ax3000-ubootmod|\
	tplink,tl-xdr4288|\
	tplink,tl-xdr6086|\
	tplink,tl-xdr6088|\
	tplink,tl-xtr8488|\
	wavlink,wl-wnt100x3-ubootmod|\
	xiaomi,mi-router-ax3000t-ubootmod|\
	xiaomi,redmi-router-ax6000-ubootmod|\
	xiaomi,mi-router-wr30u-ubootmod|\
	zyxel,ex5601-t0-ubootmod)
		fit_check_image "$1"
		return $?
		;;
	beeconmini,seed-ac1)
		CI_KERNPART="kernel"
		CI_ROOTPART="rootfs"
		CI_DATAPART="rootfs_data"
		emmc_do_upgrade "$1"
		;;
	buffalo,wsr-3000ax4p|\
	xiaomi,mi-router-ax3000t|\
	xiaomi,mi-router-wr30u-stock|\
	xiaomi,mi-router-wr300-stock|\
	xiaomi,mi-router-wr32x-stock|\
	xiaomi,mi-router-wr32xs-stock|\
	xiaomi,mi-router-wr32xsc-stock)
		CI_KERNPART="linux"
		nand_do_upgrade "$1"
		;;
	*)
		echo "Unsupported platform $board"
		return 1
		;;
	esac
}

platform_copy_config() {
	local board=$(board_name)

	case "$board" in
	acer,vero-w6m|\
	airpi,ap3000m|\
	arcadyan,mozart|\
	beeconmini,seed-ac1|\
	glinet,gl-mt2500|\
	glinet,gl-mt2500-airoha|\
	glinet,gl-mt6000|\
	glinet,gl-mt6000a|\
	glinet,gl-mt6000w|\
	glinet,gl-xe3000|\
	glinet,gl-xfr610|\
	glinet,gl-xt6|\
	glinet,glx-tr7620|\
	glinet,glx-tr7621|\
	glinet,glx-tr7631|\
	glinet,glx-tr7632|\
	mtk,mt7981-rfb|\
	mtk,mt7986a-rfb|\
	mtk,mt7986b-rfb|\
	netgear,wax206|\
	netgear,wax220-2.5g|\
	openwrt,one|\
	openwrt,sax1200w2-onie|\
	openvox,ov-p2641|\
	openvox,ov-p2642|\
	openwrt,wpq-873-single-ap|\
	openwrt,wpq-873-uap-2x2|\
	openwrt,wpq-873-uap-dual|\
	openwrt,wpq-873ap-led|\
	openwrt,wpq-873eap-4k|\
	prologue,pl6600|\
	sierracom,mc7430-5g|\
	sierracom,mc7455-5g|\
	sophos,red-10-sfp|\
	sophos,red-15-sfp|\
	sophos,red-20-sfp|\
	sophos,red-30-sfp|\
	sophos,red-40-sfp|\
	telecominfraproject,tfiax540|\
	tenbay,txq-xe30)
		emmc_copy_config
		;;
	*)
		nand_copy_config
		;;
	esac
}

platform_pre_upgrade() {
	local board=$(board_name)

	case "$board" in
	asus,pac3100|\
	asus,zenwifi-ax6600|\
	asus,zenwifi-ax7800)
		filogic_jffs2_rootfs "$board" "$1"
		;;
	esac
}
