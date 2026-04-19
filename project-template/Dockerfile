ARG ZEPHYR_VERSION=v4.4.0
ARG REGISTRY=ghcr.io/jacobbeningo

FROM ${REGISTRY}/zephyr-base:${ZEPHYR_VERSION}

# Copy application source into the image (used for CI; for local dev, bind-mount instead)
COPY --chown=zephyr:zephyr app/ /workdir/app/

WORKDIR /workdir/app
CMD ["/bin/bash"]
