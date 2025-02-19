# Kria KV260 Development

## setup
> [!note]
> [git-repo](https://gerrit.googlesource.com/git-repo)をインストールしておく
> - archlinux
>   ```
>   $ paru -S repo-git
>   ```

Xilinxのyocto用セットアップ[manifest](https://github.com/Xilinx/yocto-manifests)を用いる
```
$ repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2024.2
$ repo sync
$ repo start rel-v2024.2 --all
$ ls
 setupsdk   sources/
$ ls sources
 manifest/             meta-jupyter/   meta-openamp/        meta-qt5/    meta-security/            meta-vitis/          meta-xilinx-tsn/
 meta-aws/             meta-kria/      meta-openembedded/   meta-rauc/   meta-system-controller/   meta-xilinx/         poky/
 meta-embedded-plus/   meta-mingw/     meta-petalinux/      meta-ros/    meta-virtualization/      meta-xilinx-tools/   yocto-scripts/
```
> [!note]
> branch `rel-v2024.2` を用いたが、[Yocto Kria Support](https://xilinx.github.io/kria-apps-docs/yocto/build/html/docs/yocto_kria_support.html#machine-configurations-for-kria)を参考に使用するデバイスによっては使えないこともあるので注意

`setupsdk`を読み込むことで、`bitbake`コマンドや`build`ディレクトリが生成される
```
$ source setupsdk
```

## build
> [!caution]
> kirkstoneと同様に最新のgccだとbuildに失敗する
> - 対策
>   - symbolic linkの張替え
>       ```
>       $ cp /sbin/gcc /sbin/gcc-14
>       $ sudo ln -s $(which gcc-11) gcc
>       ```  
>   - build設定の方を変える
>       以前調べてたときに、`build`ディレクトリ下にbuild時の`PATH`を設定しているファイルがある。
>       これが`/bin`を直接指定しているため、userの`PATH`を参照しない。
>       そのため、ここを変更すれば良さそう。(どこに書いてたか忘れちゃった...)

> [!note]
> pythonのモジュールが必要なものがある。
> 以前yoctoを使っていたときに入れたものもあるので、完全ではないが、今回出てきたpackageを列挙しておく。

> [!caution]
> python 3.13以降では削除されている`pipes`を要求しているので、何かしら対策が必要
```
$ MACHINE=k26-smk-kv-sdt bitbake kria-image-full-cmdline
```

### MACHINE and Recipe Name

[Yocto Kria Support](https://xilinx.github.io/kria-apps-docs/yocto/build/html/docs/yocto_kria_support.html#machine-configurations-for-kria)を参考に設定する。

今回は [KV260](https://www.amd.com/en/products/system-on-modules/kria/k26/kv260-vision-starter-kit.html) を使用するため、`MACHINE=k26-smk-kv-sdt`と`RECIPE=kria-image-full-cmdline`を使用した。

- memo
    - sdt = system device tree

### `kria-zynqmp-generic`

> [!caution]
> 未検証

KV260、KR260、KD240をすべてサポートするMACHINE設定で、ビルド手順に少し工夫が必要になる。

> [!note]
> System Device Treeを使用したい場合は、`k26-smk-sdt`とする
```
# build DTB for k26
$ MACHINE=k26-smk bitbake virtual/dtb
$ cp tmp/deploy/images/k26-smk/devicetree/SMK-*.dtb <dtb_path>

# build DTB for k24
$ MACHINE=k24-smk bitbake virtual/dtb
$ cp tmp/deploy/images/k24-smk/devicetree/SMK-*.dtb <dtb_path>

...
```

1. `local.conf`に`<dtb_path>`を追加
    ```
    PRECOMPILED_DTB_FILES_DIR = <dtb_path>
    ```

2. build WIC image
    ```
    $ MACHINE=kria-zynqmp-generic bitbake kria-image-full-cmdline
    ```

## run QEMU

```
$ MACHINE=k26-smk-kv-sdt runqemu nographic slirp
```

## references
- [Yocto Kria Support](https://xilinx.github.io/kria-apps-docs/yocto/build/html/docs/yocto_kria_support.html)
- [yocto-manifests](https://github.com/Xilinx/yocto-manifests)
- [git-repo](https://gerrit.googlesource.com/git-repo)
