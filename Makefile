NELUA ?= nelua
ZIG ?= zig
ZIGFLAGS ?= -mcpu=x86_64
NELIBC ?= ../nelibc
NELIBC_LIB ?= $(NELIBC)/build/libnelibc-standalone-zig.a
OUT ?= build
PREFIX ?= /usr/local
NM ?= nm

NELIBC_STAMP = $(shell sha256sum $(NELIBC_LIB) 2>/dev/null | cut -c1-16)
CFLAGS := -DNELIBC_STANDALONE -nostdlib -static -no-pie -fno-pie \
	-fno-stack-protector -ffreestanding -fno-builtin -fno-sanitize=all \
	-Wl,-e,_start -Wl,--build-id=none -I$(NELIBC)/include \
	-DNEBUILD_NELIBC_STAMP=$(NELIBC_STAMP)
LDFLAGS := -Wl,--whole-archive $(NELIBC_LIB) -Wl,--no-whole-archive

.PHONY: all nebuild test install clean

all: nebuild

nebuild: $(OUT)/nebuild

$(OUT)/nebuild: src/nebuild.nelua src/nebuild/sys.nelua Makefile $(NELIBC_LIB) | $(OUT)
	$(NELUA) -r -L src --cc '$(ZIG) cc $(ZIGFLAGS)' --cflags='$(CFLAGS)' --ldflags='$(LDFLAGS)' -o $@ src/nebuild.nelua
	@undefined=$$($(NM) -u $@) && test -z "$$undefined" || { echo "undefined symbols:"; $(NM) -u $@; exit 1; }

$(OUT):
	mkdir -p $(OUT)

test: $(OUT)/nebuild
	python3 tests/nebuild.py $(abspath $(OUT)/nebuild)

install: $(OUT)/nebuild
	install -D -m 0755 $(OUT)/nebuild $(DESTDIR)$(PREFIX)/bin/nebuild

$(NELIBC_LIB):
	$(MAKE) -C $(NELIBC) lib-standalone-zig NELUA="$(NELUA)" ZIG="$(ZIG)"

clean:
	rm -rf $(OUT)
