FROM node:14.13.1-alpine3.12
ENV VCPKG_FORCE_SYSTEM_BINARIES=1

# Install system dependencies and Skyrim data files
RUN apk add --no-cache \
  gcc \
  musl-dev \
  g++ \
  cmake \
  gdb \
  git \
  curl \
  unzip \
  tar \
  ninja \
  perl \
  make \
  zip \
  pkgconfig \
  linux-headers \
  libsasl

# !!!!!! TODO: ADD TO SKYMP DOCKERFILE
RUN apk add --no-cache \
  bash \
  clang \
  llvm \
  python2 \
  icu-dev \
  libffi \
  libc-dev

# Install vcpkg and ports
# (vcpkg/refs/heads/master contains vcpkg version)

#RUN ls /lib && false

COPY .git/modules/vcpkg/refs/heads/master \
  ./vcpkg.json \
  ./x64-linux-musl.cmake \
  ./
RUN git clone https://github.com/skyrim-multiplayer/vcpkg.git \ 
  && cd vcpkg \
  && git checkout $(cat master) \
  && chmod 777 ./bootstrap-vcpkg.sh \
  && ./bootstrap-vcpkg.sh -useSystemBinaries -disableMetrics \
  && mv ../x64-linux-musl.cmake ./triplets/x64-linux-musl.cmake

COPY ./overlay_ports ./overlay_ports

RUN vcpkg/vcpkg --feature-flags=binarycaching,manifests install --triplet x64-linux --overlay-ports=/overlay_ports
#  && rm -r vcpkg/buildtrees \
#  && rm -r vcpkg/packages \
#  && rm -r vcpkg/downloads