# Kria KV260 development with Yocto

## setup

- fetch layers
```
$ repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2024.2
$ repo sync
$ repo start rel-v2024.2 --all
```

- setup build environment
```
$ source setupsdk
```

## build for KV260 (System-Device-Tree)

```
$ MACHINE=k26-smk-kv-sdt bitbake kria-image-full-cmdline
```

## run QEMU 

```
$ MACHINE=k26-smk-kv-sdt runqemu nographic slirp
```
