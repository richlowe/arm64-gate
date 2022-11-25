#!/bin/sh

exec sudo qemu-system-aarch64 \
     -nographic \
     -machine virt-4.1 \
     -m 2g \
     -smp 2 \
     -cpu cortex-a53 \
     -kernel inetboot.bin \
     -append "-D /virtio_mmio@a003c00" \
     -netdev bridge,id=net0,br=virbr0 \
     -device virtio-net-device,netdev=net0,mac=52:54:00:70:0a:e4 \
     -device virtio-blk-device,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
