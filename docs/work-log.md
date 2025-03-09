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

#### `python3-lxml` recipe

> [!caution]
> 環境依存のバグ
> - 手元のマシン
>   ```
>   Could not find function xmlCheckVersion in library libxml2. Is libxml2 installed?
>   ```
> - 別のマシン
>   ビルド通る -> re-buildで通らない

[lxml](https://github.com/lxml/lxml)をgithubから落としてきて、手元でビルドしてみる
→ 手元の環境ではなく、yocto側が用意している環境依存であることを特定

```
$ gh repo clone lxml/lxml
$ cd lxml

$ python3 setup.py bdist_wheel --verbose --dist-dir dist
# ok
```

> [!note]
> `<workspace>/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/temp/run.do_compile`を参考にビルド方法を指定

手元の環境ならうまく行くので、`do_compile`と同様の方法でビルド
```
$ NO_FETCH_BUILD=1 \
    STAGING_INCDIR=/home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/include \
    STAGING_LIBDIR=/home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/lib \
    /home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/bin/python3-native/python3 setup.py \
    bdist_wheel --verbose --dist-dir /home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/dist
# error
```
何らかの手段で、コードを自動生成している？
-> その部分がうまく生成できていない。

- 原因
    - host build
        ```
        $ python3 setup.py bdist_wheel --verbose --dist-dir dist
        ...
        building 'lxml.etree' extension
        creating build/temp.linux-x86_64-cpython-313/src/lxml
        ...
        ```
    - yocto build
        ```
        $ NO_FETCH_BUILD=1 \
        STAGING_INCDIR=/home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/include \
        STAGING_LIBDIR=/home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/lib \
        /home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/recipe-sysroot-native/usr/bin/python3-native/python3 setup.py \
        bdist_wheel --verbose --dist-dir /home/kanta/workspace/sc/kria-yocto/build/tmp/work/x86_64-linux/python3-lxml-native/5.0.0/dist
        ...
        building 'lxml.etree' extension
        creating build/temp.linux-x86_64-cpython-312
        creating build/temp.linux-x86_64-cpython-312/src
        creating build/temp.linux-x86_64-cpython-312/src/lxml
        ...
        ```
    これもpython3.12起因のバグな気がする...
    自動生成するCPythonがv3.12、ホストの環境はより新しいgccを使っているので、構造体の構成が異なり、エラーが発生している
    -> lxml内部でCPythonを使ってる？
    ```
    $ ls build/
     lib.linux-x86_64-cpython-312/   lib.linux-x86_64-cpython-313/   temp.linux-x86_64-cpython-312/   temp.linux-x86_64-cpython-313/
    ```
    -> v3.13用のlibが生成されてるけど使われてない...??
    -> もしかしたら、手動で`python3 setup.py bdist_wheel`したときに生成されたかも。
    -> `log.do_compile`には乗っていないため。
    何を見てv3.12を使っているのか?

- 原因2
    gcc14だと、python3.12のcythonが生成したコードをコンパイルできないのが原因。
    パッチを当てれば対策できそうだが、一旦gcc-13以下にすることで回避。

    - [gevent-24.2.1: Fails to build with GCC 14 due to -Wincompatible-pointer-types](https://github.com/gevent/gevent/issues/2049)
    - [gevent fails to build with Cython 3.0.10](https://github.com/gevent/gevent/issues/2031)
    - [Fix bad self casts when calling methods of final types](https://github.com/cython/cython/pull/6085)


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

- よく出るエラー
```
  /home/kanta/workspace/sc/kria-yocto/sources/poky/meta/recipes-core/base-files/base-files_3.0.14.bb:do_package
  /home/kanta/workspace/sc/kria-yocto/sources/poky/meta/recipes-support/ca-certificates/ca-certificates_20211016.bb:do_package
  /home/kanta/workspace/sc/kria-yocto/sources/poky/meta/recipes-extended/timezone/tzdata.bb:do_package
  /home/kanta/workspace/sc/kria-yocto/sources/poky/meta/recipes-kernel/linux-libc-headers/linux-libc-headers_6.6.bb:do_package
```

このようなエラーがいくつかのレシピで発生する。

`PSEUDO_IGNORE_PATHS`に追加しまくれば、なんとかなる気がするが、根本的な解決じゃない + パッチを当てるレシピが膨大になりそうなので一旦調査。
-> `PSEUDO_IGNORE_PATHS`に追加すると、ビルドに失敗する

- 推測・対処法
    1. buildディレクトリを削除する
        `do_clean`や`do_cleanall`でも同様のエラーがでる。
    2. (wip) DBは `build/tmp/` 下に生成されているが、ずっとメモリ上にある説？
        `source setupsdk`したshellを閉じるとうまく行くかも

- [Pseudo Abort](https://wiki.yoctoproject.org/wiki/Pseudo_Abort)

#### xilinx recipes fetch error

つぎのようなフェッチエラーがたまに発生する
- リポジトリ側が原因な気がする...

成功するまでビルドすればok

```
WARNING: mc:k26-smk-kv-sdt-cortexa53-fsbl:xilstandalone-2024.2+git-r0 do_fetch: Failed to fetch URL git://github.com/Xilinx/embeddedsw.git;protocol=https;branch=xlnx_rel_v2024.2, attempting MIRRORS if available
ERROR: mc:k26-smk-kv-sdt-cortexa53-fsbl:xilstandalone-2024.2+git-r0 do_fetch: Fetcher failure: Fetch command export PSEUDO_DISABLED=1; export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"; export PATH="/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/sysroots-uninative/x86_64-linux/usr/bin:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/usr/bin/python3-native:/home/kanta/workspace/sc/nix-kria/sources/poky/scripts:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/usr/bin/aarch64-xilinx-elf:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot/usr/bin/crossscripts:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/usr/sbin:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/usr/bin:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/sbin:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/recipe-sysroot-native/bin:/home/kanta/workspace/sc/nix-kria/sources/poky/bitbake/bin:/home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/hosttools"; export HOME="/home/kanta"; LANG=C git -c gc.autoDetach=false -c core.pager=cat -c safe.bareRepository=all clone --bare --mirror https://github.com/Xilinx/embeddedsw.git /home/kanta/workspace/sc/nix-kria/build/downloads/git2/github.com.Xilinx.embeddedsw.git --progress failed with exit code 128, see logfile for output
ERROR: mc:k26-smk-kv-sdt-cortexa53-fsbl:xilstandalone-2024.2+git-r0 do_fetch: Bitbake Fetcher Error: FetchError('Unable to fetch URL from any source.', 'git://github.com/Xilinx/embeddedsw.git;protocol=https;branch=xlnx_rel_v2024.2')
ERROR: Logfile of failure stored in: /home/kanta/workspace/sc/nix-kria/build/tmp-k26-smk-kv-sdt-cortexa53-fsbl/work/cortexa53-xilinx-elf/xilstandalone/2024.2+git/temp/log.do_fetch.2126488
ERROR: Task (mc:k26-smk-kv-sdt-cortexa53-fsbl:/home/kanta/workspace/sc/nix-kria/sources/poky/../meta-xilinx/meta-xilinx-standalone-sdt/recipes-libraries/xilstandalone_2024.2.bb:do_fetch) failed with exit code '1'
```

### build environment

archの環境依存の部分がでかすぎるので、nixで隠蔽したい。

```
$ nix develop --no-write-lock-file github:KantaTamura/nix-environments#yocto
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
