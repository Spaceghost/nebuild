NELUA ?= nelua
ZIG ?= zig
ZIGFLAGS ?= -mcpu=x86_64
NELIBC ?= ../nelibc
NELIBC_LIB ?= $(NELIBC)/build/libnelibc-standalone-zig.a
OUT ?= build
PREFIX ?= /usr/local
NM ?= nm
NECC ?= necc

NELIBC_STAMP = $(shell sha256sum $(NELIBC_LIB) 2>/dev/null | cut -c1-16)
CFLAGS := -DNELIBC_STANDALONE -nostdlib -static -no-pie -fno-pie \
	-fno-stack-protector -ffreestanding -fno-builtin -fno-sanitize=all \
	-Wl,-e,_start -Wl,--build-id=none -I$(NELIBC)/include \
	-DNEBUILD_NELIBC_STAMP=$(NELIBC_STAMP)
LDFLAGS := -Wl,--whole-archive $(NELIBC_LIB) -Wl,--no-whole-archive

.PHONY: all nebuild native test test-native hosted test-hosted install clean

all: nebuild

nebuild: $(OUT)/nebuild

# Build through the public necc driver while keeping the normal Nelua+Zig
# target as the default `make` behavior.
native: $(OUT)/nebuild-native

$(OUT)/nebuild-native: src/nebuild.nelua src/nebuild/sys.nelua Makefile | $(OUT)
	$(NECC) --native --release -L src src/nebuild.nelua -o $@

$(OUT)/nebuild: src/nebuild.nelua src/nebuild/sys.nelua Makefile $(NELIBC_LIB) | $(OUT)
	$(NELUA) -r -L src --cc '$(ZIG) cc $(ZIGFLAGS)' --cflags='$(CFLAGS)' --ldflags='$(LDFLAGS)' -o $@ src/nebuild.nelua
	@undefined=$$($(NM) -u $@) && test -z "$$undefined" || { echo "undefined symbols:"; $(NM) -u $@; exit 1; }

hosted: $(OUT)/nebuild-hosted

$(OUT)/nebuild-hosted: src/nebuild.nelua src/nebuild/sys.nelua Makefile | $(OUT)
	$(NELUA) -r -D nebuild_hosted=true -L src --cc '$(CC)' -o $@ src/nebuild.nelua

test-hosted: $(OUT)/nebuild-hosted
	python3 tests/nebuild.py $(abspath $(OUT)/nebuild-hosted)

$(OUT):
	mkdir -p $(OUT)

test: $(OUT)/nebuild
	python3 tests/nebuild.py $(abspath $(OUT)/nebuild)

test-native: $(OUT)/nebuild-native
	python3 tests/nebuild.py $(abspath $(OUT)/nebuild-native)

install: $(OUT)/nebuild
	install -D -m 0755 $(OUT)/nebuild $(DESTDIR)$(PREFIX)/bin/nebuild

$(NELIBC_LIB):
	$(MAKE) -C $(NELIBC) lib-standalone-zig NELUA="$(NELUA)" ZIG="$(ZIG)"

clean:
	rm -rf $(OUT)
