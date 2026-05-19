ARG SDK_VERSION=1.0.1
ARG REGISTRY=ghcr.io/jacobbeningo

FROM ${REGISTRY}/zephyr-sdk:${SDK_VERSION}

# MANIFEST_FILE selects which module set to pull (maps to base/manifests/<file>)
ARG MANIFEST_FILE=nxp-v4.4.0.yml
# Set to "1" to run a west build smoke test against hello_world/qemu_x86 at image build time
ARG RUN_SMOKE_TEST=0

ENV ZEPHYR_BASE=/workdir/zephyr

# Copy the chosen manifest and init the workspace from it.
# west init -l sets the workspace root to the parent of the manifest dir (/workdir),
# so all projects (zephyr, hal_nxp, etc.) clone directly under /workdir.
COPY --chown=zephyr:zephyr manifests/${MANIFEST_FILE} /workdir/beg-manifest/west.yml

RUN west init -l /workdir/beg-manifest \
    && west update \
    && west zephyr-export

# Run as root: install Python deps system-wide (accessible to all users including root),
# register git safe.directory for zephyr-owned repos, copy cmake packages, and install Renode.
USER root
RUN pip3 install --no-cache-dir --break-system-packages \
        -r /workdir/zephyr/scripts/requirements.txt \
    && git config --system --add safe.directory /workdir/zephyr \
    && git config --system --add safe.directory /workdir \
    && cp -r /home/zephyr/.cmake /root/.cmake

# ---- Renode ----
# Headless ARM simulator. The portable-dotnet bundle is self-contained (~300 MB).
# Used by the `renode` docker-compose service in project-template/.
ARG RENODE_VERSION=1.16.1
RUN wget -q "https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode-${RENODE_VERSION}.linux-portable-dotnet.tar.gz" \
    && mkdir -p /opt/renode \
    && tar xf "renode-${RENODE_VERSION}.linux-portable-dotnet.tar.gz" -C /opt/renode --strip-components=1 \
    && rm "renode-${RENODE_VERSION}.linux-portable-dotnet.tar.gz" \
    && ln -s /opt/renode/renode /usr/local/bin/renode

USER zephyr

RUN if [ "${RUN_SMOKE_TEST}" = "1" ]; then \
        west build \
            -b qemu_x86 \
            /workdir/zephyr/samples/hello_world \
            -p always \
        && rm -rf /workdir/build; \
    fi

WORKDIR /workdir/app
CMD ["/bin/bash"]
