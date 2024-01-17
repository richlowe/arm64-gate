#!/bin/sh

QEMU_SCRIPT_MACHINE="virt,gic-version=3" \
  exec "${SHELL}" "${PWD}/run.sh"
