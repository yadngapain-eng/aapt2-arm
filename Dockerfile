FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y -qq \
    openjdk-17-jdk git curl unzip zip wget python3 python3-pip \
    bison flex gperf build-essential zlib1g-dev gcc-multilib \
    g++-multilib libc6-dev-i386 x11proto-core-dev libx11-dev \
    lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc fontconfig \
    cmake ninja-build pkg-config libssl-dev cpio rsync bc

WORKDIR /work
COPY build-aapt2.sh /work/
RUN chmod +x /work/build-aapt2.sh

CMD ["/work/build-aapt2.sh"]
