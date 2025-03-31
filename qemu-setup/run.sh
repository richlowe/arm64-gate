#!/bin/sh

QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt}"
QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-6g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-2}"
QEMU_SCRIPT_CPU="${QEMU_SCRIPT_CPU:-cortex-a53}"
QEMU_SCRIPT_ACCEL="${QEMU_SCRIPT_ACCEL:-tcg,thread=multi}"

vnic=braich0

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

exec qemu-system-aarch64 \
     -nographic \
     -machine "${QEMU_SCRIPT_MACHINE}" \
     -accel "${QEMU_SCRIPT_ACCEL}" \
     -m ${QEMU_SCRIPT_MEMORY} \
     -smp cores="${QEMU_SCRIPT_NCPU}" \
     -cpu "${QEMU_SCRIPT_CPU}" \
     -bios u-boot.bin \
     -netdev vnic,ifname=braich0,id=net0 \
     -device virtio-net-device,netdev=net0,mac=${mac} \
     -device virtio-blk-device,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
