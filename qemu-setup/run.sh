#!/bin/sh

vnic=braich0

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

exec qemu-system-aarch64 \
     -nographic \
     -machine virt-4.1 \
     -accel tcg,thread=multi \
     -m 6g \
     -smp cores=2 \
     -cpu cortex-a53 \
     -kernel inetboot.bin \
     -append "-D /virtio_mmio@a003c00" \
     -netdev vnic,ifname=braich0,id=net0 \
     -device virtio-net-device,netdev=net0,mac=${mac} \
     -device virtio-blk-device,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
