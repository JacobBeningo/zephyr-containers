ARG SDK_VERSION=1.0.1

FROM ubuntu:24.04

ARG SDK_VERSION
ARG TARGETARCH
# Space-separated list of additional toolchains to install, e.g. "riscv64-zephyr-elf xtensa-espressif_esp32_zephyr-elf"
ARG EXTRA_TOOLCHAINS=""
# SHA-256 checksums for the SDK tarballs.
# Find them at: https://github.com/zephyrproject-rtos/sdk-ng/releases/tag/v${SDK_VERSION}
# If left empty, verification is skipped (not recommended for production builds).
ARG SDK_SHA256_AMD64=""
ARG SDK_SHA256_ARM64=""

ENV DEBIAN_FRONTEND=noninteractive
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        ninja-build \
        device-tree-compiler \
        git \
        python3 \
        python3-pip \
        python3-venv \
        ccache \
        dfu-util \
        file \
        libmagic1 \
        wget \
        xz-utils \
        openocd \
        sudo \
        ca-certificates \
        gcc \
        g++ \
        make \
    && rm -rf /var/lib/apt/lists/*

# Map Docker TARGETARCH to Zephyr SDK arch naming, download and install SDK
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ZEPHYR_ARCH="x86_64";  EXPECTED_SHA="${SDK_SHA256_AMD64}" ;; \
        arm64) ZEPHYR_ARCH="aarch64"; EXPECTED_SHA="${SDK_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VERSION}/zephyr-sdk-${SDK_VERSION}_linux-${ZEPHYR_ARCH}_minimal.tar.xz"; \
    wget -q "${SDK_URL}" -O /tmp/zephyr-sdk.tar.xz; \
    if [ -n "${EXPECTED_SHA}" ]; then \
        echo "${EXPECTED_SHA}  /tmp/zephyr-sdk.tar.xz" | sha256sum -c -; \
    else \
        echo "WARNING: SDK_SHA256 not set for ${TARGETARCH} — skipping checksum verification"; \
    fi; \
    tar -xf /tmp/zephyr-sdk.tar.xz -C /opt; \
    mv /opt/zephyr-sdk-${SDK_VERSION} ${ZEPHYR_SDK_INSTALL_DIR}; \
    rm /tmp/zephyr-sdk.tar.xz

# Install ARM toolchain (covers STM32, nRF, RP2040/2350, most Cortex-M)
# Then install any requested extra toolchains
RUN ${ZEPHYR_SDK_INSTALL_DIR}/setup.sh -t arm-zephyr-eabi -h -c; \
    for tc in ${EXTRA_TOOLCHAINS}; do \
        ${ZEPHYR_SDK_INSTALL_DIR}/setup.sh -t "${tc}"; \
    done

RUN pip3 install --no-cache-dir --break-system-packages \
        west==1.3.0 \
        pyelftools==0.31 \
        pyyaml==6.0.2 \
        cryptography==43.0.3 \
        intelhex==2.3.0 \
        click==8.1.7

RUN if id ubuntu &>/dev/null 2>&1; then userdel -r ubuntu; fi \
    && useradd -m -u 1000 -s /bin/bash zephyr \
    && echo "zephyr ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/zephyr \
    && chmod 0440 /etc/sudoers.d/zephyr \
    && mkdir -p /workdir \
    && chown zephyr:zephyr /workdir

USER zephyr
WORKDIR /workdir
CMD ["/bin/bash"]
