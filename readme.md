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

> [!note]
> `build/conf/local.conf`に次の内容を追記すればbuildディレクトリを削除してもキャッシュが残り、ビルドが高速になる。
> ```
> DL_DIR ?= "/opt/yocto/downloads"
> SSTATE_DIR ?= "/opt/yocto/sstate-cache"
> ```

## build for KV260 (System-Device-Tree)

```
$ docker compose build
$ docker compose run --rm build-kria
```

## run QEMU 

```
$ MACHINE=k26-smk-kv-sdt runqemu nographic slirp
```
