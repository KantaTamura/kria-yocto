# Supported Xilinx Boards

ビルド時に`MACHINE`に指定するコンフィグファイルは、次のリンクから見ることができる。

- [AMD Evaluation Boards XSCT BSP Machines files](https://github.com/Xilinx/meta-xilinx-tools/blob/rel-v2024.2/README.xsct.bsp.md)
- [AMD Adaptive SoC's Evaluation Boards SDT BSP Machines files](https://github.com/Xilinx/meta-amd-adaptive-socs/blob/rel-v2024.2/meta-amd-adaptive-socs-bsp/README.asoc.bsp.md)
- [AMD Kria SOM and Evaluation Starter kits BSP Machines files](https://github.com/Xilinx/meta-kria/blob/rel-v2024.2/README.kria.bsp.md)

## Use docker-compose build

Yoctoでサポートされていない環境(arch etc.)では、依存パッケージなどの関係でビルドがうまくいかない可能性が高い。
Ubuntu22.04でYoctoをビルドできるようにした環境をDockerfileで用意しているので、docker-compose.yamlのenvironmentで`MACHINE`を設定しておけば再現性のある環境でビルドできる。

> [!note]
> e.g. Kria KV260 Vision AI Starter Kit
> ```
> services:
>   build-kria:
>     build:
>       context: .
>       dockerfile: Dockerfile
>     container_name: xilinx-yocto
>     environment:
>       - MACHINE=k26-smk-kv-sdt
>     volumes:
>       - .:${PWD}
>       - /opt/yocto:/opt/yocto
>     working_dir: ${PWD}
>     command: /bin/bash -c "source ${PWD}/setupsdk > /dev/null && bitbake kria-image-full-cmdline"
>     tty: true
>     stdin_open: true
> ```
