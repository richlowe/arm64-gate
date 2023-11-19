# illumos for AArch64 bootstrap

This tree is the bootstrap for illumos on AArch64.  It contains sufficient
pieces, and build materials, to build a bootable disk that can be used for
development of the AArch64 port.

## Dependencies

- An illumos system
- A compilation environment, headers, compiler, etc.
  (You will need both GCC 7, GCC 10, and their dependencies and build
  dependencies to include at least GMP, MPC, and MPFR):
  ```sh
  # Run this in OmniOS:
  sudo pkg install \
	pkg:/developer/gcc7 \
	pkg:/developer/gcc10 \
	pkg:/developer/pkg-config \
	pkg:/ooce/library/gnutls \
	pkg:/ooce/text/texinfo

  # Run this in OpenIndiana:
  sudo pkg install \
	pkg:/developer/gcc-7 \
	pkg:/developer/gcc-10 \
	pkg:/developer/build/pkg-config \
	pkg:/library/gnutls-3 \
  pkg:/network/rsync \
	pkg:/text/texinfo

  # For OpenIndiana, this may be necessary before installing OpenSSL:
  sudo pkg set-mediator -V 1.1 openssl

  # Run this in OmniOS or OpenIndiana:
  sudo pkg install \
	pkg:/developer/astdev \
	pkg:/developer/illumos-closed \
	pkg:/developer/swig \
	pkg:/developer/build/gnu-make \
	pkg:/developer/build/onbld \
	pkg:/developer/java/openjdk8 \
	pkg:/developer/parser/bison \
	pkg:/file/gnu-coreutils \
	pkg:/library/perl-5/xml-parser \
	pkg:/library/security/openssl-11 \
	pkg:/media/cdrtools \
	pkg:/security/sudo \
	pkg:/shell/pipe-viewer \
	pkg:/system/zones/internal
  ```

## Building

To build there are three-ish steps

1. `make download` -- Fetch all the other sources we need at their correct
   versions.  (By default this takes shallow-ish clones of big trees, feel
   free to replace them with full clones).
1. `make setup` -- Build all the prerequisites to building illumos
1. `make illumos` -- Build illumos
   The environment file is in `env/aarch64` in this directory, and is what gets
   used for bootstrapping.
1. `make disk` -- Build the disk image which you can give to `qemu(1)`
	This will also ask for your password, so if you just run `make disk` and let
    dependencies take over, that won't go great.

Note that `make sysroot` and `make download-omnios` may be run multiple times
as you work to keep those pieces up-to-date, the latter is especially useful
as that goes into the disk image we create.

## Booting

Take the `illumos-disk.img` you have built, and the `inetboot.bin` for your
platform (likely qemu) out of the proto area, and supply them to `qemu`

I use something like this:

```
sudo qemu-system-aarch64 -nographic -machine virt-4.1 -m 2g -smp 2 -cpu cortex-a53 -kernel inetboot.bin -append "-D /virtio_mmio@a003c00" -netdev vnic,ifname=braich0,id=net0 -device virtio-net-device,netdev=net0,mac=52:54:00:70:0a:e4 -device virtio-blk-device,drive=hd0 -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none
```

- `-nographic` -- serial console on stdout
- `-machine virt-4.1` -- the current target qemu machine
- `-m 2g` -- 2G of memory, more can never hurt
- `-smp 2` -- 2 CPUs, again, more shouldn't hurt
- `-cpu cortex-a53` -- an appropriate CPU for the port
- `-kernel inetboot.bin` -- the inetboot.bin for qemu taken from the illumos
  build
- `-append "-D /virtio_mmio@a003c00"` -- tell inetboot where to boot from
- `-netdev vnic,ifname=braich0,id=net0` -- vnic networking
- `-device virtio-net-device,netdev=net0,mac=52:54:00:70:0a:e4` -- virtual
  NIC, `vioif0` in the system. The MAC must match your vnic.
- `-device virtio-blk-device,drive=hd0` -- our disk
- `-drive file=illumos-disk.img,format=raw,id=hd0,if=none` -- the illumos disk
  image you want to boot.

A convenient way to do this is just to take the entire `qemu-setup/`
directory.  Note that the default configuration we use is trying to strike a
balance between running on smaller systems and booting in an even vaguely
tolerable amount of time.  It is a balance we have not yet reached.

> **Note:** the networking configuration here is important, you need to have
> _a_ networking device for the device tree to be what we expect right now.
> The configuration above and in `run.sh` is for qemu on illumos using vnic
> networking, using a vnic `braich0`.  If this is inappropriate for you, you
> need to provide _an_ alternative, in the worst case user networking `-netdev
> user,id=net0`.

You will see messages from the temporary booter that seem worrying, about
missing boot_archives and `vdev_probe`, these are, weirdly, specific to the
currently weird booting method.

Once you have booted you will see copious boot messages both to aid debugging
and because the emulation is slow and it helps to keep track that something is
still happening, these are hardwired in the source at present, absent a real
booter.

There are also lingering bugs around SMF that may or may not fail during boot.
The two most notable are that, after messages indicating your CPU(s) are
online, things will pause without output while `svvcfg apply` happens.  The
other is that `svc:/system/rbac`, `svc:/network/inetd-upgrade`, and
`svc:/system/update-man-index` almost always time out, and often take a long
time to do so, be patient.  The first of these has dependencies, and so stall
a lot of our boot process.

## After you boot

`root` has no password (at all, rather than an empty password).

Find something to fix! Lots of things are missing are broken!  Many of them important!

The most notable things for fixing stuff are that we have at present no mdb(1)
or kmdb(1) or dtrace(8), which is unfortunate.

We build a cross gdb(1) to tide us over, which can be used to analyze core
dumps from the virtual machine (you can just mount your pool back onto a
development machine, etc), or to analyze the running kernel code directly
(connect to the gdb server).

`(gdb) target remote tcp::1234`

There is a `.gdbinit` in this directory which does useful things like load the
`inetboot` and `unix` for qemu and provide a `load-kernel-modules` command to
load the other modules currently present in the running kernel.  It is not
great, but it is _something_.

## See Also

* [IPD 24 Support for 64-bit ARM (AArch64)](https://github.com/illumos/ipd/blob/master/ipd/0024/README.md)
