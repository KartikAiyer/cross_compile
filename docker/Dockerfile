FROM repo.k2labs.org/ubuntu:21.10

RUN echo 'Starting Galileo Build Environment...'

# Install necessary ubuntu packages
RUN apt-get update --fix-missing && DEBIAN_FRONTEND=noninteractive apt-get install -y \
   build-essential \
   bash-completion \
   ssh \
   gawk \
   device-tree-compiler \
   dos2unix \
   git-review \
   sudo \
   curl \
   libssl-dev \
   libncurses-dev \
   cpio \
   unzip \
   rsync \
   csh \
   tcsh \
   lsof \
   gnupg \
   git \
   autoconf \
   tree \
   vim \
   wget \
   bc \
   time \
   software-properties-common

RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null

RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN apt update

RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.4/cmake-3.22.4.tar.gz && \
    tar -xzf cmake-3.22.4.tar.gz && \
    cd cmake-3.22.4 &&\
    ./bootstrap && make -j$(nproc) && sudo make install

RUN apt update && apt install -y \
    openssl \
    pkgconf \
    libssl-dev \
    libengine-pkcs11-openssl \
    opensc-pkcs11

RUN apt update && apt install -y python3 python3-pip
RUN apt update && apt install -y \
   libgflags-dev \
   libgoogle-glog-dev \
   libhdf5-serial-dev \
   libprotobuf-dev \
   libprotoc-dev \
   protobuf-compiler \
   graphviz \
   libsnappy-dev \
   sed \
   bison \
   texinfo \
   pigz

RUN apt update && apt install -y ccache

ENV PATH=${PATH}:${HOME}/.local/bin
ENV MOUNT_PATH=/home/kartik/project

ARG UNAME=kartik
ARG UID=501
ARG GID=20

RUN groupadd --gid $GID $UNAME || true
RUN useradd -m -u $UID -g $GID -s /bin/sh $UNAME

RUN echo 'kartik    ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER $UNAME

RUN sudo pip install conan
WORKDIR /home/kartik/project

ADD --chown=kartik:staff entrypoint.sh /usr/bin/entrypoint.sh
RUN echo "set -o vi" >> $HOME/.bashrc
ENTRYPOINT [ "entrypoint.sh" ]
