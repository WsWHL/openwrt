define Device/beeconmini_seed-ac1
  DEVICE_VENDOR := BeeconMini
  DEVICE_MODEL := SEED AC1
  DEVICE_DTS := mt7981b-beeconmini-seed-ac1
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := -wpad-basic-mbedtls kmod-i2c-gpio kmod-sfp kmod-usb3 kmod-fs-f2fs mkf2fs
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += beeconmini_seed-ac1