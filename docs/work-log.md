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

> [!note]
> `bitbake`を動かすためにいくつかの依存関係の解決が必要
> - archlinux
>   ```
>   $ paru -S rpcsvc-proto chrpath cpio diffstat inetutils
>   ```

いくつかバグがあったので、パッチを当てるlayerを`build/conf/bblayer.conf`に追加する。
```
$ cd sources
$ bitbake-layers add-layer meta-build
```

## build

> [!caution]
> kirkstoneと同様に最新のgccだとbuildに失敗する
> - 対策
>   - symbolic linkの張替え
>       ```
>       $ cp /sbin/gcc /sbin/gcc-14
>       $ sudo ln -s $(which gcc-11) /sbin/gcc
>       ```  
>   - build設定の方を変える
>       以前調べてたときに、`build`ディレクトリ下にbuild時の`PATH`を設定しているファイルがある。
>       これが`/bin`を直接指定しているため、userの`PATH`を参照しない。
>       そのため、ここを変更すれば良さそう。(どこに書いてたか忘れちゃった...)
>       - `/home/kanta/sc/kria-yocto/build/tmp/hosttools`
>           ここに、`/sbin/<hoge>`へのシンボリックリンクが貼られている。
>           `source setupsdk`のタイミングで生成される。
>           ビルド毎に生成しているわけではなさそうなので、シンボリックリンクを張り替えてもいけるのでは...?

> [!note]
> pythonのモジュールが必要なものがある。
> 以前yoctoを使っていたときに入れたものもあるので、完全ではないが、今回出てきたpackageを列挙しておく。

> [!caution]
> python 3.13以降では削除されている`pipes`を要求しているので、何かしら対策が必要
> - 対策
>   - gccと同様にsymbolic linkの張替えで対策
>       ```
>       $ sudo ln -s $(which python3.12) /sbin/python3
>       ```

```
$ MACHINE=k26-smk-kv-sdt bitbake kria-image-full-cmdline
```

### bug fix

#### `qemu-xilinx-native` recipe

`struct sched_attr`の二重定義エラーが発生する

> [!note]
> おそらく、linuxのバージョンが新しすぎるのが問題 (?)
> ```
> $ uname -r
> 6.13.2-arch1-1
> ```

> [!note]
> - https://sourceware.org/pipermail/libc-alpha/2023-October/151885.html

```
$ bitbake-layers show-recipes
...
qemu-xilinx-native:
  meta-xilinx-core     8.1.0+git
...
```

> [!note]
> 何故か `devtool modify qemu-xilinx-native` に失敗する...
> ```
> ERROR: ExecutionError('git tag -f devtool-base', 1, '', "error: cannot run nvim: No such file or directory\nerror: unable to start editor 'nvim'\nPlease supply the message using either -m or -F option.\n")
> ```

直接パッチを生成して、layerに加える方法を取る。
パッチ作成は、前回のbuild時に `tmp/work/x86_64-linux/qemu-xilinx-native/8.1.0+git/git` にfetchされているので、この中で行った。
> [!note]
> ```
> $ nvim linux-user/syscall.c
> # staged
> $ git diff --staged > 0001-sched-attr-fix.patch
> ```
```
$ cd sources
$ bitbake-layers create-layer meta-build
$ bitbake-layers add-layer meta-build
```
- `bitbake-layers create-layer <meta-layer>`: `<meta-layer>`を作成する
- `bitbake-layers add-layer <meta-layer>`: `<meta-layer>`を`build/conf/bblayers.conf`に加える
```
$ cd meta-build
$ rm -rf README COPYING.MIT recipes-example
$ mkdir -p recipes-devtools/qemu/files
$ nvim recipes-devtools/qemu/qemu-xilinx-system-native_%.bbappend
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://0001-sched-attr-fix.patch"

$ cat recipes-devtools/qemu/files/0001-sched-attr-fix.patch
diff --git a/linux-user/syscall.c b/linux-user/syscall.c
index ca90186405..c0c430810b 100644
--- a/linux-user/syscall.c
+++ b/linux-user/syscall.c
@@ -360,6 +360,7 @@ _syscall3(int, sys_sched_getaffinity, pid_t, pid, unsigned int, len,
 _syscall3(int, sys_sched_setaffinity, pid_t, pid, unsigned int, len,
           unsigned long *, user_mask_ptr);
 /* sched_attr is not defined in glibc */
+#ifndef _LINUX_SCHED_TYPES_H
 struct sched_attr {
     uint32_t size;
     uint32_t sched_policy;
@@ -372,6 +373,7 @@ struct sched_attr {
     uint32_t sched_util_min;
     uint32_t sched_util_max;
 };
+#endif /* _LINUX_SCHED_TYPES_H */
 #define __NR_sys_sched_getattr __NR_sched_getattr
 _syscall4(int, sys_sched_getattr, pid_t, pid, struct sched_attr *, attr,
           unsigned int, size, unsigned int, flags);

$ cat conf/layer.conf
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "${LAYERDIR}/recipes-devtools/qemu/qemu-xilinx-native_%.bbappend"

BBFILE_COLLECTIONS += "build"
BBFILE_PATTERN_build = "^${LAYERDIR}/"
BBFILE_PRIORITY_build = "6"

LAYERDEPENDS_meta-build = "core"
LAYERSERIES_COMPAT_meta-build = "scarthgap"
```

#### wip: `python3-lxml` recipe

> [!caution]
> 環境依存のバグ
> - 手元のマシン
>   ```
>   Could not find function xmlCheckVersion in library libxml2. Is libxml2 installed?
>   ```
> - 別のマシン
>   ビルド通る

#### `ninja` recipe

> [!caution]
> python3.13だと削除された`pipes`パッケージを利用している。
> python3.12にダウングレードして対策していたが、python3.12のライブラリ側がクロスコンパイルに対応していないためエラー...
> python3.13でも動くようにパッチを当てる方針に転換

- make patch
```
$ cd build/tmp/work/x86_64-linux/ninja-native/1.11.1/git
$ nvim configure.py
$ git diff --staged > 0001-duplicated-pipes-package.patch
```

- apply patch recipe
```
$ mkdir -p meta-build/recipes-devtools/ninja/files
$ cat meta-build/recipes-devtools/ninja/ninja_%.bbappend
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://0001-deplicated-pipes-package.patch"

$ cat meta-build/recipes-devtools/ninja/files/0001-duplicated-pipes-package.patch
Upstream-Status: Pending

diff --git a/configure.py b/configure.py
index 43904349..c80a43b6 100755
--- a/configure.py
+++ b/configure.py
@@ -23,7 +23,7 @@ from __future__ import print_function
 
 from optparse import OptionParser
 import os
-import pipes
+import shlex
 import string
 import subprocess
 import sys
@@ -264,7 +264,7 @@ n.variable('configure_args', ' '.join(configure_args))
 env_keys = set(['CXX', 'AR', 'CFLAGS', 'CXXFLAGS', 'LDFLAGS'])
 configure_env = dict((k, os.environ[k]) for k in os.environ if k in env_keys)
 if configure_env:
-    config_str = ' '.join([k + '=' + pipes.quote(configure_env[k])
+    config_str = ' '.join([k + '=' + shlex.quote(configure_env[k])
                            for k in configure_env])
     n.variable('configure_env', config_str + '$ ')
 n.newline()
```

> [!note]
> `do_patch`で怒られる可能性があるので、パッチファイルの先頭に`Upstream-Status`を追加しておく
> - `Accepted`: すでに upstream に取り込まれた変更
> - `Pending`: upstream に提案されているが、まだ取り込まれていない変更
> - `Denied`: upstream に拒否されたが、Yocto で必要
> - `Backport`: upstream の新しいバージョンから取り込んだもの
> - `Inappropriate <hoge>`: upstream に適用するのが適切でない Yocto 独自の変更

#### wip: pseudo error

```
ERROR: Task (/home/kanta/workspace/sc/kria-yocto/sources/poky/meta/recipes-kernel/linux-libc-headers/linux-libc-headers_6.6.bb:do_package) failed with exit code '134' 
Pseudo log:
path mismatch [2 links]: ino 4042882 db '/home/kanta/workspace/sc/kria-yocto/build/tmp/work/cortexa72-cortexa53-xilinx-linux/linux-libc-headers/6.6/packages-split/linux-libc-headers-lic/usr/share/licenses/linux-libc-headers/generic_GPL-2.0-only' req '/home/kanta/workspace/sc/kria-yocto/build/tmp/work/cortexa72-cortexa53-xilinx-linux/linux-libc-headers/6.6/sstate-build-package/package/usr/share/licenses/linux-libc-headers/generic_GPL-2.0-only'.
Setup complete, sending SIGUSR1 to pid 2292870.
```

このようなエラーがいくつかのレシピで発生する。

`PSEUDO_IGNORE_PATHS`に追加しまくれば、なんとかなる気がするが、根本的な解決じゃない + パッチを当てるレシピが膨大になりそうなので一旦調査。

- [Pseudo Abort](https://wiki.yoctoproject.org/wiki/Pseudo_Abort)

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

### limit parallel threads

- `local.conf`
```
BB_NUMBER_THREADS = '16'
PARALLEL_MAKE = '-j 16'
```

- `BB_NUMBER_THREADS`: レシピの並列数
- `PARALLEL_MAKE`: ビルド時の並列数

- [Yocto ビルド並列数の調整方法](https://qiita.com/byuu/items/95086d07e317dfe64ee2)

## run QEMU

```
$ MACHINE=k26-smk-kv-sdt runqemu nographic slirp
```

## references
- [Yocto Kria Support](https://xilinx.github.io/kria-apps-docs/yocto/build/html/docs/yocto_kria_support.html)
- [yocto-manifests](https://github.com/Xilinx/yocto-manifests)
- [git-repo](https://gerrit.googlesource.com/git-repo)
