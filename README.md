# BEG Zephyr Container Images

Reproducible Zephyr RTOS build environments delivered as Docker images. Students and engineers get a working build environment with a single `docker pull` — no SDK installation, no toolchain setup, no west workspace configuration.

## What's Inside

Three-tier image hierarchy:

```
ghcr.io/jacobbeningo/zephyr-sdk:1.0.1
    └── ghcr.io/jacobbeningo/zephyr-base:nxp-v4.4.0
            └── your-project (optional CI image)
```

| Image | What it contains | Size |
|---|---|---|
| `zephyr-sdk:1.0.1` | Ubuntu 24.04, Zephyr SDK 1.0.1, ARM toolchain | ~3.1 GB |
| `zephyr-base:nxp-v4.4.0` | SDK image + Zephyr 4.4.0 + NXP modules (see below) | ~10 GB |

### Modules included in `zephyr-base:nxp-v4.4.0`

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

## Quick Start

### Prerequisites (host machine)

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Windows) or Docker Engine (Linux)
- [VS Code](https://code.visualstudio.com/) with the [Cortex Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug) extension
- [LinkServer](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/linkserver-for-microcontrollers:LINKSERVER) (for flashing and debugging NXP boards)

No west, no Zephyr SDK, no toolchain needed on the host.

### 1. Pull the image

```bash
docker pull ghcr.io/jacobbeningo/zephyr-base:nxp-v4.4.0
```

### 2. Set up your project

Copy the `project-template/` directory from this repo as a starting point, or add the following files to an existing Zephyr app:

```
your-app/
├── build.sh                  # container build wrapper
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
./build.sh frdm_mcxn947/mcxn947/cpu0
```

Build output (including `zephyr.elf` and `compile_commands.json`) lands in `./build/` on the host.

### 4. Debug in VS Code

Press **F5** and select a debug configuration. Cortex Debug will:
1. Run the build task (rebuilds if source changed)
2. Launch LinkServer and flash the ELF to the board
3. Stop at `main` — step through code normally

---

## Daily Workflow

### Building

```bash
# Incremental build
./build.sh frdm_mcxn947/mcxn947/cpu0

# Clean build (removes build/ before building)
./build.sh frdm_mcxn947/mcxn947/cpu0 clean
```

The script auto-detects stale cmake caches (e.g. from a prior host-native build) and cleans automatically. You only need `clean` when switching boards or explicitly forcing a full rebuild.

### Interactive shell

For running west commands directly:

```bash
# Using docker compose (from project directory)
docker compose run --rm zephyr

# Or directly
docker run -it --rm \
  -v $(pwd):/workdir/app \
  ghcr.io/jacobbeningo/zephyr-base:nxp-v4.4.0
```

Inside the container you have full west access:

```bash
west build -b frdm_mcxn947/mcxn947/cpu0 /workdir/app -d /workdir/app/build
west boards | grep frdm
west list
west config --list
```

> **Note:** `west flash` and `west debug` require USB access to the debug probe. These do not work from inside a container on macOS or Windows. Use VS Code + Cortex Debug for flashing and debugging instead.

### Debugging

Debugging uses the host-native LinkServer — no west required:

| Task | How |
|---|---|
| Flash + debug | F5 in VS Code (runs build task first) |
| Step through app source | Works — paths are remapped via `sourceFileMap` |
| Step into Zephyr kernel | Shows disassembly (Zephyr source not on host) |
| Peripheral register view | Add SVD file path to `launch.json` |

Source files are remapped automatically: the ELF contains container paths (`/workdir/app/src/main.c`) and VS Code translates them to your local workspace.

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
├── .github/
│   └── workflows/
│       ├── build-sdk.yml
│       ├── build-base.yml
│       └── build-project-template.yml
└── docs/
    ├── student-quickstart.md
    ├── instructor-guide.md
    └── ci-integration.md
```

---

## Adding a Vendor Variant

To add support for a different vendor (e.g. STM32), create a new manifest file:

```bash
cp base/manifests/nxp-v4.4.0.yml base/manifests/stm32-v4.4.0.yml
```

Edit the `name-allowlist` to include the vendor's HAL:

```yaml
name-allowlist:
  - cmsis
  - cmsis_6
  - hal_stm32      # replace hal_nxp with your vendor
  - picolibc
  - mbedtls
  - segger
```

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
| `nxp-v4.4.0` | 4.4.0 | 1.0.1 | 24.04 |

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
