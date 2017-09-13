FROM debian:stretch-slim as busybox_builder

RUN apt-get update && apt-get install -y \
		bzip2 \
		curl \
		gcc \
		gnupg2 dirmngr \
		make \
		libncurses-dev \
		\
# buildroot
		bc \
		cpio \
		dpkg-dev \
		g++ \
		patch \
		perl \
		python \
		rsync \
		unzip \
		wget \
	&& rm -rf /var/lib/apt/lists/*

ENV BUILDROOT_VERSION 2017.02.5

RUN set -ex; \
	tarball="buildroot-${BUILDROOT_VERSION}.tar.bz2"; \
	curl -fL -o buildroot.tar.bz2 "https://buildroot.uclibc.org/downloads/$tarball"; \
	mkdir -p /usr/src/buildroot; \
	tar -xf buildroot.tar.bz2 -C /usr/src/buildroot --strip-components 1; \
	rm buildroot.tar.bz2*

WORKDIR /usr/src/buildroot

RUN make defconfig

RUN set -ex; \
	setConfs=' \
		BR2_x86_64=y \
		BR2_TOOLCHAIN_BUILDROOT_GLIBC=y \
		BR2_TOOLCHAIN_BUILDROOT_CXX=y \
		BR2_PACKAGE_LIBCAP_NG=y \
		BR2_PACKAGE_LIBFFI=y \
		BR2_PACKAGE_JPEG=y \
		BR2_PACKAGE_LIBJPEG=y \
		BR2_PACKAGE_ZLIB=y \
		BR2_PACKAGE_PIXMAN=y \
		BR2_PACKAGE_LIBGLIB2=y \
	'; \
	unsetConfs=' \
	'; \
	for conf in $unsetConfs; do \
		sed -i \
			-e "s!^$conf=.*\$!# $conf is not set!" \
			.config; \
	done; \
	for confV in $setConfs; do \
		conf="${confV%=*}"; \
		sed -i \
			-e "s!^$conf=.*\$!$confV!" \
			-e "s!^# $conf is not set\$!$confV!" \
			.config; \
		if ! grep -q "^$confV\$" .config; then \
			echo "$confV" >> .config; \
		fi; \
	done;

RUN	make oldconfig

RUN make -s

FROM debian:stretch-slim as qemu_builder

RUN apt-get update -q && apt-get install -q -y \
	git \
	build-essential flex bison \
	pkg-config \
	python \
	zlib1g-dev libpixman-1-dev libglib2.0-dev libfdt-dev

ENV QEMU_VERSION v2.10.0

RUN git clone git://git.qemu-project.org/qemu.git && \
	cd qemu && \
	git checkout tags/$QEMU_VERSION && \
	git submodule update --init dtc

WORKDIR /qemu
RUN ./configure --target-list=x86_64-softmmu \
	--disable-tpm \
	--disable-libiscsi \
	--disable-libnfs \
	--disable-fdt \
	--disable-glusterfs
RUN make
RUN make DESTDIR=/tarball install

FROM scratch
COPY --from=busybox_builder /usr/src/buildroot/output/target /
COPY --from=qemu_builder /tarball /
