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
	--disable-glusterfs \
	--disable-linux-user \
	--disable-bsd-user \
	--disable-guest-agent \
	--static

RUN make
RUN make DESTDIR=/tarball install

FROM busybox
COPY --from=qemu_builder /tarball /