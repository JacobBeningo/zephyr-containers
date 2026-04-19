# Zephyr Container Images: Implementation Plan

## Purpose

Build a set of Docker images that provide a reproducible Zephyr RTOS build environment for:

1. Students in BEG academy courses (zero-setup onboarding)
2. BEG consulting projects (long-term reproducibility)
3. CI/CD pipelines (fast, deterministic builds)

The strategy is to **bake the Zephyr SDK, Zephyr source, and all west-managed modules into the image at build time**. The west workspace is frozen at a known state inside the image. At runtime, only the application source directory is mounted from the host.

This gives bit-identical builds across time, eliminates network dependencies during builds, and makes onboarding a single `docker pull` away.

## Architecture

Three-tier image hierarchy:

```
beg/zephyr-sdk:<sdk-version>
    └── beg/zephyr-base:<zephyr-version>
            └── beg/zephyr-<project>:<tag>   (optional, per-project)
```

### Tier 1: SDK Image (`beg/zephyr-sdk`)

- Base OS: Ubuntu 22.04 LTS
- Zephyr SDK installed at `/opt/zephyr-sdk`
- System dependencies: cmake, ninja, device-tree-compiler, git, python3, python3-pip, python3-venv, ccache, dfu-util, file, libmagic1, wget, xz-utils
- Python packages: west, pyelftools, pyyaml, cryptography, intelhex, click
- Environment: `ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk`, `ZEPHYR_TOOLCHAIN_VARIANT=zephyr`
- Non-root user `zephyr` with UID 1000 and sudo rights (so bind-mounted project dirs from host don't have permission issues on Linux)
- Rebuilt rarely (only on SDK version bumps)

Tag scheme: `beg/zephyr-sdk:0.17.0` (matches SDK version)

### Tier 2: Base Image (`beg/zephyr-base`)

- `FROM beg/zephyr-sdk:<version>`
- Runs `west init` against a manifest that pins to a specific Zephyr release
- Runs `west update` to fetch all modules at their pinned SHAs
- Runs `west zephyr-export` and `pip install -r zephyr/scripts/requirements.txt`
- Workspace frozen at `/workdir/zephyrproject`
- Rebuilt when moving to new Zephyr version

Tag scheme: `beg/zephyr-base:v4.0.0` (matches Zephyr version)

Build at least two variants initially:
- `beg/zephyr-base:v3.7-lts` (current LTS)
- `beg/zephyr-base:v4.0.0` (or whatever the current stable release is at build time)

### Tier 3: Project Images (`beg/zephyr-<project>`) - optional

- `FROM beg/zephyr-base:<zephyr-version>`
- Adds project-specific west manifest overrides, private modules, or app source
- Used for CI and for shipping a fully self-contained build artifact to clients
- Built per-project, tagged per-release

Not every use case needs tier 3. For student work and general development, tier 2 is sufficient because the student's app is bind-mounted at runtime.

## Deliverables for Claude Code

Create a repository with the following structure:

```
beg-zephyr-containers/
├── README.md
├── .github/
│   └── workflows/
│       ├── build-sdk.yml
│       ├── build-base.yml
│       └── build-project-template.yml
├── sdk/
│   ├── Dockerfile
│   └── build.sh
├── base/
│   ├── Dockerfile
│   ├── manifests/
│   │   ├── zephyr-v3.7-lts.yml
│   │   └── zephyr-v4.0.yml
│   └── build.sh
├── project-template/
│   ├── Dockerfile
│   ├── .devcontainer/
│   │   └── devcontainer.json
│   ├── docker-compose.yml
│   ├── west.yml
│   └── app/
│       └── (sample blinky app)
└── docs/
    ├── student-quickstart.md
    ├── instructor-guide.md
    └── ci-integration.md
```

## Implementation Requirements

### SDK Image Dockerfile

1. Start from `ubuntu:22.04`
2. Install system packages in a single layer, clean apt cache at end
3. Download Zephyr SDK from the official GitHub release URL, verify with SHA-256, extract to `/opt/zephyr-sdk`
4. Make the SDK version a `ARG` so the Dockerfile can build different SDK versions
5. Install minimal toolchain set by default: ARM (covers STM32, nRF, RP2040/2350, most ARM Cortex-M). Make additional toolchains (RISC-V, Xtensa) optional via build args
6. Run `setup.sh -t <toolchain> -h -c` during SDK install
7. Create `zephyr` user, UID 1000, with passwordless sudo
8. Set `WORKDIR /workdir`, `USER zephyr`
9. Default CMD to bash

### Base Image Dockerfile

1. `FROM beg/zephyr-sdk:${SDK_VERSION}`
2. Accept `ZEPHYR_VERSION` and `MANIFEST_FILE` as build args
3. Copy the chosen manifest file into the image
4. As the `zephyr` user:
   - `west init -l <manifest-dir>` or `west init --mr <version> /workdir/zephyrproject`
   - `west update`
   - `west zephyr-export`
   - `pip install --user -r /workdir/zephyrproject/zephyr/scripts/requirements.txt`
5. Set `ZEPHYR_BASE=/workdir/zephyrproject/zephyr` as an ENV var
6. Verify the build by running `west build -b qemu_x86 zephyr/samples/hello_world -p always` as a smoke test in a separate RUN layer (optional, gated behind a build arg)

### Project Template

1. Minimal `Dockerfile` showing `FROM beg/zephyr-base:v4.0.0` with a placeholder for app copy
2. `docker-compose.yml` for local dev that bind-mounts the host project directory to `/workdir/app`
3. `.devcontainer/devcontainer.json` for VS Code that references the base image
4. Sample `west.yml` showing T3 manifest pattern (app as manifest repo)
5. A working blinky sample that builds for `qemu_cortex_m3` so students can verify without hardware

### Build Scripts

Each tier gets a `build.sh` that:

1. Accepts version args
2. Builds with appropriate tags (both version-specific and `latest` where appropriate)
3. Supports `--push` to push to registry
4. Supports `--platform linux/amd64,linux/arm64` for multi-arch builds (important - many students and engineers are on Apple Silicon now)

### GitHub Actions Workflows

1. `build-sdk.yml`: Manual trigger, builds SDK image and pushes to GitHub Container Registry (ghcr.io/jacobbeningo/...)
2. `build-base.yml`: Manual trigger + scheduled monthly, builds base images for each supported Zephyr version
3. `build-project-template.yml`: Example workflow that students can copy into their own projects

Use `docker/setup-buildx-action` and `docker/build-push-action`. Enable layer caching via GitHub Actions cache.

### Registry

Target `ghcr.io/jacobbeningo` as the registry namespace. Images should be public so students can pull without authentication. CI for private client projects can use the same base image from ghcr and layer private content into a private registry of the client's choosing.

## Hardware Flashing (document, do not automate)

Include a section in `docs/student-quickstart.md` covering USB passthrough for hardware flashing:

- **Linux host:** `--device=/dev/bus/usb` or specific `/dev/ttyACM*` nodes in docker-compose
- **macOS host:** Containers can't access USB directly. Recommend flashing from the host using `west flash --runner` approaches or using the image for build-only and flashing with a host-native tool
- **Windows host:** WSL2 + `usbipd-win` works. Document the exact commands

Flashing tools to include in SDK image: `openocd`, `dfu-util`, `pyocd` (via pip), `nrfjprog` is optional and requires Nordic license acceptance so leave it out of the public image

## Documentation Requirements

### `README.md` (repo root)

- What these images are and why they exist
- Quick start (one-liner to pull and run)
- Version matrix (which SDK versions pair with which Zephyr versions)
- Link to sub-docs

### `docs/student-quickstart.md`

- Install Docker Desktop (or Docker Engine on Linux)
- Pull the image: `docker pull ghcr.io/jacobbeningo/zephyr-base:v4.0.0`
- Clone the course project template
- `docker compose up -d` or open in VS Code with Dev Containers extension
- Build the sample: `west build -b qemu_cortex_m3 samples/blinky -p always`
- Run it: `west build -t run`
- Flash to hardware: per-platform instructions

### `docs/instructor-guide.md`

- How to rebuild images when Zephyr releases a new version
- How to add a new MCU family to the student curriculum
- How to produce a course-specific image variant (e.g., pre-loaded with lab exercises)

### `docs/ci-integration.md`

- Example GitHub Actions workflow for a student or consulting project
- Example GitLab CI config
- How to cache builds across CI runs (ccache volume)

## Sequencing

Build in this order:

1. SDK image (tier 1) - get this working and pushed to ghcr
2. Base image for current Zephyr stable (tier 2) - verify `west build` works inside the container against a sample
3. Project template with docker-compose and devcontainer - verify the bind-mount flow works end-to-end on Linux and macOS
4. Base image for LTS (v3.7) - second variant to confirm the build script handles multiple versions
5. GitHub Actions workflows - automate the rebuilds
6. Documentation - student-facing first, then instructor, then CI
7. Multi-arch support (arm64) - add after the amd64 path is proven

## Acceptance Criteria

The work is done when:

1. A student on macOS, Windows (via WSL2), or Linux can run a single `docker compose up` command and have a working Zephyr build environment
2. `west build -b qemu_cortex_m3 samples/blinky` completes successfully inside the container from a fresh pull, with zero network activity during the build itself (proving the workspace is truly frozen)
3. The same image used locally produces a byte-identical hex file when run in GitHub Actions CI
4. Rebuilding the base image six months from now with the same manifest produces the same Zephyr tree (modulo any force-pushes upstream, which the frozen image protects against once built)
5. Image sizes are documented and reasonable (expect SDK image around 2-3 GB, base image around 4-5 GB - this is fine given the use case)
6. At least one smoke test runs as part of the image build that exercises `west build` against a real sample

## Notes for Claude Code

- Use `docker buildx` for all builds to get layer caching and multi-arch support
- Pin all apt packages and pip packages to specific versions in the SDK image for reproducibility
- Use SHA-256 verification on any downloaded artifacts (SDK tarball especially)
- Do not run `west update` at container runtime - it must happen at image build time only
- The `zephyr` user must own `/workdir` and all nested directories; bind-mounted host volumes may need matching UID on Linux
- Test the full flow on at least amd64 before starting arm64 work
- Commit the Dockerfiles, manifests, and scripts to the repo; do not commit built images

## Out of Scope (for this iteration)

- Custom toolchains outside the Zephyr SDK (e.g., IAR, Keil, vendor-specific)
- Windows containers (Linux containers on Windows via WSL2 is fine)
- Kubernetes manifests for running this at scale in a classroom - if demand emerges, handle in a follow-up
- Pre-loading the image with vendor IDEs (MCUXpresso, nRF Connect) - those stay host-native
