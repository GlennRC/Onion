# Git Binary for OnionOS (Miyoo Mini Flip)

The `git_sync_saves` feature requires a **statically compiled git binary** for ARM (armv7/armhf).

## How to obtain

### Option 1: Cross-compile with musl (recommended)
```bash
# Using Alpine Linux or musl cross-toolchain:
export CC=arm-linux-musleabihf-gcc
export CFLAGS="-static"
make -C git prefix=/usr \
    NO_OPENSSL=1 NO_CURL=1 NO_EXPAT=1 \
    NO_TCLTK=1 NO_GETTEXT=1 NO_PERL=1 NO_PYTHON=1 \
    INSTALL_SYMLINKS=1 \
    all
```

### Option 2: Extract from an Alpine ARM rootfs
```bash
docker run --rm --platform linux/arm/v7 alpine:latest \
    sh -c "apk add --no-cache git && cat /usr/bin/git" > git
```

### Option 3: Use the Miyoo Mini toolchain
Build inside the `aemiii91/miyoomini-toolchain` Docker container with static linking flags.

## Installation

1. Place the compiled `git` binary at:
   ```
   /mnt/SDCARD/.tmp_update/bin/git
   ```

2. Ensure it is executable:
   ```
   chmod +x /mnt/SDCARD/.tmp_update/bin/git
   ```

3. The binary must support at minimum: `init`, `add`, `commit`, `push`, `remote`, `branch`, `ls-remote`, `diff`

## Dependencies

- SSH client (`ssh`) must be available on the device (typically included in OnionOS via dropbear)
- WiFi must be configured on the device for push operations
