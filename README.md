# nebuild

`nebuild` is an incremental build runner for dependency graphs described in a
`build.ne` manifest. It is written in Nelua. The default build links statically against
standalone Nelibc. The runner is useful for small native builds and for
bootstrapping systems that need to build themselves.

## Build

On Linux x86-64, install the Nelua compiler and Zig, then build the standalone
Nelibc archive. `NELIBC` defaults to a sibling `../nelibc` checkout.

```sh
make -C ../nelibc lib-standalone-zig
make
```

Set `NELIBC` when the checkout is elsewhere. `NELUA`, `ZIG`, `ZIGFLAGS`, and
`OUT` can also be overridden on the make command line. The executable is
`build/nebuild` by default. The link check fails if the result has undefined
symbols.

Run the regression suite and install the runner with:

```sh
make test
sudo make install
```

## Build against the host libc

On Linux AArch64 or x86-64, build with Nelua and the system C compiler. Run
the same regression suite with Python 3.

```sh
make hosted NELUA=/path/to/nelua CC=gcc
make test-hosted NELUA=/path/to/nelua CC=gcc
```

This profile produces `build/nebuild-hosted` and uses the platform's C
library for file metadata, process management, and directory locking.

## Build with necc

The standalone `necc` driver can also build nebuild through its public
full-frontend/native-backend path. This keeps module lookup rooted at this
repository's `src/` tree and does not change the default Nelua+Zig build:

```sh
make native NECC=/path/to/necc
make test-native NECC=/path/to/necc
```

`NECC` defaults to `necc` on `PATH`. Set `NECC_SYSROOT` when the compiler uses
a staged SDK. The native executable is `build/nebuild-native` by default.

`PREFIX` defaults to `/usr/local`. Packaging can use `DESTDIR`:

```sh
make install DESTDIR="$PWD/package-root" PREFIX=/usr
```

## Manifest format

Each build rule declares a file output and its file inputs. The following
indented line is the shell command that creates the output. Default targets
are selected with `default` lines.

```text
default bin/hello
build bin/hello src/hello.c include/message.h
	mkdir -p bin && cc -Iinclude -o bin/hello src/hello.c
```

Put a literal tab at the start of each recipe line. Manifest paths are
whitespace-separated and cannot contain spaces. Inputs must exist before
planning starts or be outputs of another rule. The runner checks dependency
cycles, duplicate outputs, and missing inputs before starting a recipe.

Run the default targets or name targets explicitly. `-j` enables parallel
recipes whose dependencies are ready.

```sh
nebuild build.ne
nebuild -j 4 build.ne bin/hello
```

The runner works in the current directory, locks that directory while it
runs, and records a completion file beside each output. It reruns an output
when its command, manifest rule, or declared input metadata changes, or when
the output or its completion record is missing. Add every file that affects a
command to its declared inputs. Generated inputs carry a build generation so
downstream outputs update even when a filesystem has coarse timestamps.

Recipes execute through `/bin/sh -c`. Each declared output must be a regular
file when its recipe succeeds. A failed command has its old completion record
removed, so a later invocation retries it.

## Source layout

`src/nebuild.nelua` contains the runner. `src/nebuild/sys.nelua` supplies
the Linux system-call declarations used by the runner. `tests/nebuild.py`
exercises dependency planning, incremental rebuilds, target selection,
parallel jobs, cache hits, build-directory locking, and failure recovery.
