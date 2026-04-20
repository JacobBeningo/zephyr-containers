# BEG Zephyr Container Images

Reproducible Zephyr RTOS build environments delivered as Docker images. Students and engineers get a working build environment with a single `docker pull` — no SDK installation, no toolchain setup, no west workspace configuration.

## Two Ways to Use These Images

**Option 1 — Pull the pre-built image (recommended)**
Use the images published to ghcr.io. No build step required. Right for students, engineers, and CI pipelines targeting NXP targets with Zephyr 4.4.0.

```bash
docker pull ghcr.io/jacobbeningo/zephyr-base:v4.4.0
```

**Option 2 — Build from scratch**
Clone this repo and build your own image. Right for adding a different vendor (STM32, Nordic, etc.), targeting a different Zephyr version, or customizing the image.

```bash
git clone https://github.com/JacobBeningo/zephyr-containers
MANIFEST_FILE=nxp-v4.4.0.yml bash base/build.sh
```

See [Building the Images](#building-the-images) and [Adding a Vendor Variant](#adding-a-vendor-variant) for details.

---

## What's Inside

Three-tier image hierarchy:

```
ghcr.io/jacobbeningo/zephyr-sdk:1.0.1
    └── ghcr.io/jacobbeningo/zephyr-base:v4.4.0
            └── your-project (optional CI image)
```

| Image | What it contains | Size |
|---|---|---|
| `zephyr-sdk:1.0.1` | Ubuntu 24.04, Zephyr SDK 1.0.1, ARM toolchain | ~3.1 GB |
| `zephyr-base:v4.4.0` | SDK image + Zephyr 4.4.0 + NXP modules (see below) | ~10 GB |

### Modules included in `zephyr-base:v4.4.0`

| Module | Purpose |
|---|---|
| `zephyr` | Zephyr RTOS kernel (v4.4.0) |
| `hal_nxp` | NXP HAL — i.MX RT, LPC, Kinetis, S32K, MCX |
| `cmsis` | ARM CMSIS 5.x (Cortex-A/R support) |
| `cmsis_6` | ARM CMSIS 6.x (Cortex-M support — required for all NXP MCX/i.MX RT targets) |
| `picolibc` | C standard library (Zephyr default) |
| `mbedtls` | Crypto / TLS |
| `segger` | SEGGER RTT and SystemView |
| `fatfs` | FAT filesystem |
| `lvgl` | GUI framework |
| `open-amp` | Multicore messaging (i.MX RT1170/1160) |
| `libmetal` | Hardware abstraction for open-amp |

Need a different vendor? Add a new manifest under `base/manifests/` and rebuild — see [Adding a vendor variant](#adding-a-vendor-variant).

---

## Local Development Workflow

### Prerequisites (host machine)

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Windows) or Docker Engine (Linux)
- [VS Code](https://code.visualstudio.com/) with the [Cortex Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug) extension
- [LinkServer](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/linkserver-for-microcontrollers:LINKSERVER) (for flashing and debugging NXP boards)

No west, no Zephyr SDK, no toolchain needed on the host.

### 1. Pull the image

```bash
docker pull ghcr.io/jacobbeningo/zephyr-base:v4.4.0
```

### 2. Set up your project

Copy the `project-template/` directory from this repo as a starting point, or add the following files to an existing Zephyr app:

```
your-app/
├── build.sh                  # container build wrapper
├── docker-compose.yml        # interactive shell
├── .vscode/
│   ├── launch.json           # debug configurations
│   ├── tasks.json            # build tasks
│   └── settings.json         # IntelliSense + LinkServer path
├── CMakeLists.txt
├── prj.conf
└── src/
    └── main.c
```

### 3. Build

```bash
# Incremental build
./build.sh frdm_mcxn947/mcxn947/cpu0

# Clean build (removes build/ before building)
./build.sh frdm_mcxn947/mcxn947/cpu0 clean
```

Build output (including `zephyr.elf` and `compile_commands.json`) lands in `./build/` on the host.

The script auto-detects stale cmake caches (e.g. from a prior host-native build) and cleans automatically. You only need `clean` when switching boards or explicitly forcing a full rebuild.

### 4. Debug in VS Code

Press **F5** and select a debug configuration. Cortex Debug will:
1. Run the build task (rebuilds if source changed)
2. Launch LinkServer and flash the ELF to the board
3. Stop at `main` — step through code normally

Debugging uses the host-native LinkServer — no west required:

| Task | How |
|---|---|
| Flash + debug | F5 in VS Code (runs build task first) |
| Step through app source | Works — paths are remapped via `sourceFileMap` |
| Step into Zephyr kernel | Shows disassembly (Zephyr source not on host) |
| Peripheral register view | Add SVD file path to `launch.json` |

Source files are remapped automatically: the ELF contains container paths (`/workdir/app/src/main.c`) and VS Code translates them to your local workspace.

### 5. Interactive shell (optional)

For running west commands directly — listing boards, inspecting configuration, running Twister locally:

```bash
# Using docker compose (recommended, from project directory)
docker compose run --rm zephyr

# Or directly
docker run -it --rm \
  -v $(pwd):/workdir/app \
  ghcr.io/jacobbeningo/zephyr-base:v4.4.0
```

Inside the container you have full west access:

```bash
west build -b frdm_mcxn947/mcxn947/cpu0 /workdir/app -d /workdir/app/build
west twister -T /workdir/app/tests -p native_sim/native/64
west boards | grep frdm
west list
west config --list
```

> **Note:** `west flash` and `west debug` require USB access to the debug probe. These do not work from inside a container on macOS or Windows. Use VS Code + Cortex Debug for flashing and debugging instead.

---

## CI/CD Workflow (GitHub Actions)

The base image is public on ghcr.io — no credentials required to pull it.

### Complete workflow example

```yaml
name: Firmware CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/jacobbeningo/zephyr-base:v4.4.0
      options: --user root
    defaults:
      run:
        working-directory: /workdir
    strategy:
      fail-fast: false
      matrix:
        board:
          - frdm_mcxn947/mcxn947/cpu0
          - native_sim/native/64

    steps:
      - name: Checkout firmware
        uses: actions/checkout@v4

      # No west init, west update, or pip install needed —
      # Zephyr 4.4.0 and all NXP modules are baked into the image.
      - name: Build firmware
        run: |
          west build -b ${{ matrix.board }} \
            $GITHUB_WORKSPACE \
            -d /workdir/build/${{ matrix.board }}

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        if: matrix.board == 'frdm_mcxn947/mcxn947/cpu0'
        with:
          name: firmware-frdm_mcxn947
          path: |
            /workdir/build/${{ matrix.board }}/zephyr/zephyr.bin
            /workdir/build/${{ matrix.board }}/zephyr/zephyr.elf
          retention-days: 30

  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/jacobbeningo/zephyr-base:v4.4.0
      options: --user root
    defaults:
      run:
        working-directory: /workdir

    steps:
      - name: Checkout firmware
        uses: actions/checkout@v4

      - name: Run Twister tests
        run: |
          west twister \
            -T $GITHUB_WORKSPACE/tests/ \
            -p native_sim/native/64 \
            --inline-logs \
            --report-dir /workdir/twister-out

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: /workdir/twister-out/
          retention-days: 30

  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: sudo apt-get update && sudo apt-get install -y cppcheck clang-format

      - name: Run cppcheck
        run: |
          cppcheck --enable=warning,style,performance \
            --error-exitcode=1 \
            --suppress=missingIncludeSystem \
            -I src/ src/

      - name: Check formatting
        run: find src/ -name "*.c" -o -name "*.h" | xargs clang-format --dry-run --Werror
```

### Key requirements for container jobs

**`options: --user root`**
GitHub Actions mounts its temp directory (`/__w/_temp/`) with permissions that only allow the runner's user (root) to write. Without this, `actions/checkout` fails with a permission error. The image's git config and Python packages are set up to work correctly as root.

**`defaults: run: working-directory: /workdir`**
west discovers extension commands (`west build`, `west twister`, `west flash`) by traversing up from the current directory looking for the workspace root (`.west/config`). The workspace lives at `/workdir` inside the image. GitHub Actions defaults to running steps in `/__w/<repo>/<repo>` — outside the workspace — so west can't find its commands without this setting.

**`$GITHUB_WORKSPACE`**
This is the path where `actions/checkout` places your firmware source code inside the runner (e.g. `/__w/my-repo/my-repo`). Pass it to `west build` as the application source directory. It is separate from `/workdir` where the Zephyr workspace lives.

---

## Project Structure

```
beg-zephyr-containers/
├── README.md
├── sdk/
│   ├── Dockerfile            # Tier 1: Ubuntu 24.04 + Zephyr SDK + ARM toolchain
│   └── build.sh
├── base/
│   ├── Dockerfile            # Tier 2: SDK image + frozen west workspace
│   ├── manifests/
│   │   └── nxp-v4.4.0.yml   # West manifest (NXP modules only)
│   └── build.sh
├── project-template/
│   ├── Dockerfile            # Tier 3 starting point (optional, for CI)
│   ├── build.sh              # Container build wrapper for local dev
│   ├── docker-compose.yml    # Interactive shell with volume mounts
│   ├── .vscode/
│   │   ├── launch.json       # Cortex Debug configurations
│   │   ├── tasks.json        # Build tasks
│   │   └── settings.json     # IntelliSense + LinkServer path
│   └── app/
│       ├── CMakeLists.txt
│       ├── prj.conf
│       └── src/main.c
└── .github/
    └── workflows/
        ├── build-sdk.yml
        ├── build-base.yml
        └── build-project-template.yml
```

---

## Adding a Vendor Variant

To add support for a different vendor (e.g. STM32), create a new manifest file:

```bash
cp base/manifests/nxp-v4.4.0.yml base/manifests/stm32-v4.4.0.yml
```

Edit the `name-allowlist` to include the vendor's HAL:

```yaml
projects:
  - name: zephyr
    remote: zephyrproject-rtos
    revision: v4.4.0
    west-commands: scripts/west-commands.yml
    import:
      name-allowlist:
        - cmsis
        - cmsis_6
        - hal_stm32      # replace hal_nxp with your vendor
        - picolibc
        - mbedtls
        - segger
```

> **Important:** Keep `west-commands: scripts/west-commands.yml` in the zephyr project entry. This registers `west build`, `west twister`, `west flash`, and other extension commands. Omitting it causes all extension commands to silently disappear.

Build the new variant:

```bash
MANIFEST_FILE=stm32-v4.4.0.yml bash base/build.sh
```

This produces `ghcr.io/jacobbeningo/zephyr-base:stm32-v4.4.0`.

---

## Building the Images

Images are built manually or via GitHub Actions. For local builds:

```bash
# Build SDK image (do this once per SDK version bump)
bash sdk/build.sh

# Build base image
bash base/build.sh

# Push to ghcr.io (requires docker login ghcr.io first)
PUSH=1 bash sdk/build.sh
PUSH=1 bash base/build.sh
```

For multi-arch builds (amd64 + arm64):

```bash
PUSH=1 PLATFORMS=linux/amd64,linux/arm64 bash sdk/build.sh
```

Multi-arch requires `--push` — it cannot be loaded locally.

### GitHub Actions

| Workflow | Trigger | What it builds |
|---|---|---|
| `build-sdk.yml` | Manual | SDK image → ghcr.io |
| `build-base.yml` | Manual + monthly | Base image(s) → ghcr.io |
| `build-project-template.yml` | Push / PR | Example project CI build |

---

## Version Matrix

| `zephyr-base` tag | Zephyr version | SDK version | Ubuntu |
|---|---|---|---|
| `v4.4.0` | 4.4.0 | 1.0.1 | 24.04 |

---

## Flashing on macOS

Containers cannot access USB on macOS, so flashing is always done from the host:

- **VS Code F5** — flash + debug via Cortex Debug + LinkServer (recommended)
- **LinkServer CLI** — `LinkServer flash MCXN947:FRDM-MCXN947 load build/zephyr/zephyr.elf`

For Linux hosts, USB passthrough is possible with `--device=/dev/bus/usb` in the docker run command, which would allow `west flash` from the container.

---

## Troubleshooting

**`cmake/pristine.cmake` error on build**
You have a stale build directory from a host-native build. Run:
```bash
rm -rf build/
./build.sh <board>
```
Or use `./build.sh <board> clean` — the script detects and handles this automatically.

**`west flash` / `west debug` not working**
Expected on macOS/Windows — USB passthrough is not supported. Use VS Code + Cortex Debug instead.

**IntelliSense not resolving Zephyr headers**
Zephyr headers live at `/workdir/zephyr/...` inside the container and don't exist on the host. Your app source (`src/`) will resolve correctly. Zephyr headers will show as unresolved but builds are unaffected.

**LinkServer not found**
Update `cortex-debug.linkserverPath` in `.vscode/settings.json` to match your installed version:
```bash
ls /Applications/LinkServer_*/
```

**Out of disk space during image build**
The base image requires ~15 GB of free space in Docker Desktop's virtual disk. Increase it under Docker Desktop → Settings → Resources → Virtual Disk Limit, or remove unused images with `docker image prune -a`.

**`west build` / `west twister` not found in CI**
Ensure your workflow sets `defaults: run: working-directory: /workdir` for container jobs. west discovers extension commands by traversing up from the current directory to find the workspace root. GitHub Actions defaults to running steps in `/__w/...` which is outside the `/workdir` workspace.

**`actions/checkout` fails with permission denied in CI**
Add `options: --user root` to your container spec. GitHub Actions needs root to write to its temp directory inside the container.
