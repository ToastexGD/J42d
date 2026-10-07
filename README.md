# J42d
Linux bring-up for the Apple TV HD (A8 / t7000) via checkm8.
- Multi-year boxtop hacklot project, likely never to be solved lmao

Sits on top of [Hoolock Linux](https://github.com/HoolockLinux) (kernel, m1n1, initramfs, remote_boot).

## Status

| | |
|---|---|
| m1n1 + Linux boot, HDMI framebuffer, USB-C gadget shell | Hoolock |
| PMU GPIO | here, untested |
| Ethernet (LAN9730 over HSIC) | here, untested |
| Bluetooth (BCM4350 on uart1) | here, untested |
| Wi-Fi, IR remote, audio, storage, GPU | no |

## Layout

- `linux/patches` on top of HoolockLinux/linux `hoolock` @ 6831bc70
- `linux/j42d_defconfig`
- `scripts` host setup, kernel build, debug tools, boot payload, boot
- `initramfs` files layered on top of HoolockRD (`j42d-diag` dumps GPIO, PMGR, HSIC/EHCI and USB state)
- `tools/adt.py` Apple device tree dumper, `tools/fetch-fw.sh` pulls the DeviceTree and kernelcache out of the signed IPSW
- `hw/j42d.md` hardware notes

## Build and boot

Debian/Ubuntu host.

```
scripts/setup-host.sh
scripts/build-kernel.sh
scripts/build-tools.sh
scripts/mkpayload.sh
scripts/boot.sh
```

Or skip building and take the CI output: `gh run download -R ToastexGD/J42d -n j42d -D build`, then `scripts/boot.sh`.

DFU: USB-C to the PC, plug in power, hold Menu + Play/Pause until the light blinks fast. `lsusb` shows `05ac:1227`.

After boot the Apple TV shows up as a USB network + serial device. Shell on `/dev/ttyACM0` or `telnet 172.16.42.1`.
With Ethernet plugged in, `udhcpc -i eth0` gets it on the LAN.
