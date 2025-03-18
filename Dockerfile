FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# install dependencies
RUN apt-get update
RUN apt-get install -y git tar python3 gcc make
RUN apt-get install -y build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd
RUN apt-get install -y libncurses5
RUN apt-get install -y repo

# generate en_US.UTF-8 locale
RUN locale-gen en_US.UTF-8

# create a user
# NOTE: yocto requires a non-root user
RUN useradd -m dev
USER dev
WORKDIR /home/dev

CMD ["/bin/bash"]
