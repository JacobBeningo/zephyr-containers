# Course Integration Guide: Zephyr Containers

## Overview

This document describes how the BEG Zephyr container images fit into the BEG Academy course sequence and provides guidance for updating Lab 9 and the overarching development process narrative.

---

## Pedagogical Sequence

The course introduces Zephyr tooling in a deliberate order:

1. **Early labs** — Students install the Zephyr SDK and west natively on their machine. They learn the T3 west topology, run `west init`, `west update`, and `west build` manually. They understand what a west workspace is, what modules are, and how the build system works from first principles.

2. **Lab 9 (containers)** — Students are introduced to Docker containers as a way to freeze and distribute that same environment consistently across machines and CI pipelines. Because they already understand what's inside the container, it's not a black box — it's a pre-initialized west workspace with the SDK baked in.

This sequence is intentional. Students who understand the native workflow first can reason about what the container replaced and why. Students introduced to the container first have no mental model of what's inside it.

---

## What the Container Is (and Isn't)

**What it is:**
- A pre-initialized west workspace (`west init` + `west update` already run at image build time)
- The Zephyr SDK and ARM toolchain pre-installed
- A frozen, reproducible snapshot of Zephyr + modules at a specific version
- A consistent build environment that works identically on any machine and in CI

**What it isn't:**
- A replacement for understanding west and the Zephyr build process
- A magic black box — it's the same environment students set up manually in earlier labs
- Required for every build — native builds still work alongside it

---

## The Two Copies Question

When students add the container to their existing T3 project they will have:

- A local west workspace at `~/zephyrproject/` (from earlier labs)
- Zephyr baked into the container at `/workdir/zephyr`

This is expected and not a problem. The two copies serve different purposes:

| | Local west workspace | Container |
|---|---|---|
| **Used for** | Native builds, west commands, learning | CI/CD, team consistency, reproducible builds |
| **Managed by** | Student's `west update` | Image maintainer (BEG) |
| **Source of truth** | Project's `west.yml` manifest | Image tag (e.g. `v4.4.0`) |

The key rule: **don't mix them for the same build**. The cmake cache bakes in absolute paths. A build done natively uses host paths; a build done via container uses `/workdir` paths. Switching between them on the same `build/` directory will break the cache. Use separate build directories or always clean when switching.

---

## The Role of the West Manifest in a Container Project

Students coming from T3 already have a `west.yml` in their project. When they add the container, this manifest doesn't become obsolete — it serves three purposes:

1. **Documentation of intent** — The project explicitly declares which Zephyr version and modules it depends on, independent of what's in any container image.

2. **An escape hatch** — Any developer can reproduce the environment without Docker by running `west init -l . && west update`. The project is not locked to the container.

3. **A migration path** — If a team outgrows the baked-in container approach and wants to switch to a mounted workspace (thin toolchain container + host west workspace), the manifest is already there driving that workflow.

The container and the west manifest are complementary, not competing. The container handles "same compiler, same SDK, same tools." The manifest handles "same Zephyr version, same modules." Together they give the most robust professional setup.

---

## Lab 9 Suggested Flow

### Goal
Students add container-based building and CI/CD to their existing T3 Zephyr project.

### Prerequisites
Students have completed earlier labs and have:
- A working native T3 Zephyr project with `west.yml`
- Experience running `west build`, `west flash`, and `west debug` natively
- Docker Desktop installed

### Steps

**Step 1 — Pull the base image**
```bash
docker pull ghcr.io/jacobbeningo/zephyr-base:v4.4.0
```

Explain: this image contains the same Zephyr workspace they set up manually in earlier labs, frozen at v4.4.0.

**Step 2 — Add container build support**

Copy `build.sh`, `docker-compose.yml` from the `project-template/` in the `zephyr-containers` repo into their project root.

Explain: `build.sh` is a thin wrapper that mounts their source into the container and runs `west build`. Build output lands in `./build/` on the host — same as a native build.

```bash
./build.sh frdm_mcxn947/mcxn947/cpu0
```

Point out: no `west init`, no `west update`, no pip install. The container handles all of that.

**Step 3 — Compare native vs container build output**

Have students run both:
```bash
# Native
west build -b frdm_mcxn947/mcxn947/cpu0

# Container (from a clean build dir)
./build.sh frdm_mcxn947/mcxn947/cpu0 clean
```

The output binaries should be identical. The difference is where the build runs.

**Step 4 — Add VS Code integration**

Copy `.vscode/launch.json`, `.vscode/tasks.json`, `.vscode/settings.json` from the project template. Walk through the `sourceFileMap` in `launch.json` — this is what allows VS Code to map container paths (`/workdir/app/src/main.c`) back to host paths for debugging.

Press F5. Demonstrate that debugging works identically to the native workflow.

**Step 5 — Add CI/CD**

Add `.github/workflows/build.yml` using the complete workflow from the README. Walk through:
- Why `--user root` is needed
- Why `working-directory: /workdir` is needed
- What `$GITHUB_WORKSPACE` is and why it differs from `/workdir`
- How the build matrix runs the same workflow for multiple boards
- How Twister runs tests on `native_sim`

Push to GitHub and show the green pipeline.

---

## Addressing the T3 + Container Question

Students who have internalized T3 may ask: *"If I have a container with Zephyr baked in, why do I still need a `west.yml` in my project?"*

The answer:

> The container guarantees a consistent toolchain and build environment — that's its job. Your `west.yml` guarantees reproducible dependency management at the project level — that's its job. You need both. The container answers "what tools do I build with?" Your manifest answers "what version of Zephyr and which modules does this project depend on?" A professional project documents both, independently.

Follow up: if they ever need to build without Docker (new machine, CI provider without Docker support, customer environment), the manifest is what allows them to reconstruct the workspace from scratch. The container is convenient but not a hard dependency.

---

## Long-Term Evolution (Beyond Lab 9)

Once students are comfortable with both T3 and containers, introduce the advanced pattern:

**Thin container + mounted workspace**

Instead of a 10 GB baked-in image, use a lightweight toolchain-only container (the `zephyr-sdk:1.0.1` image, ~3 GB) and mount the host west workspace:

```bash
docker run --rm \
  -v ~/zephyrproject:/workdir \
  -v $(pwd):/workdir/app \
  ghcr.io/jacobbeningo/zephyr-sdk:1.0.1 \
  west build -b frdm_mcxn947/mcxn947/cpu0 /workdir/app
```

This is the pattern used by mature professional projects and the Zephyr community's official CI images. The west manifest drives the workspace; the container provides only the toolchain. It requires more setup but gives full control over every dependency.

The baked-in image is the right starting point. The thin + mounted pattern is where a professional team eventually lands.
