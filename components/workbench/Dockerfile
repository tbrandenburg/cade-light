FROM node:24-bookworm-slim
# Maintained core toolchain; Node-RED 5 recommends Node.js 24.

# MAINTAINER-OWNED: how the workbench is built. User package additions live
# in config/requirements.txt and config/node-red/package.json instead.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git openssh-client ca-certificates python3 python3-venv bubblewrap socat ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/jupyter \
    && /opt/jupyter/bin/pip install --no-cache-dir jupyterlab==4.6.4
COPY config/requirements.txt /tmp/workbench-requirements.txt
RUN /opt/jupyter/bin/pip install --no-cache-dir -r /tmp/workbench-requirements.txt \
    && rm /tmp/workbench-requirements.txt
ENV PATH="/opt/jupyter/bin:${PATH}"

# Core CLIs are maintained here; user palette nodes are in config/node-red/.
RUN npm install -g --no-audit --no-fund \
      node-red@5.0.8 \
      opencode-ai@1.18.35 \
      @anthropic-ai/sandbox-runtime@0.0.79
COPY config/node-red/package.json /opt/node-red/package.json
RUN npm install --prefix /opt/node-red --omit=dev --no-audit --no-fund

RUN curl -fsSL https://code-server.dev/install.sh -o /tmp/install.sh \
    && sh /tmp/install.sh --method=standalone --prefix=/usr/local --version=4.141.0 \
    && rm /tmp/install.sh

# Git-tracked bundled flow source; external Git is fetched at runtime.
COPY flows/flows.json /opt/cade/bundled-flows/flows.json
COPY --chmod=755 components/workbench/prepare-node-red-flows.sh /usr/local/bin/prepare-node-red-flows
COPY components/workbench/node-red-settings.js /etc/node-red/settings.js
COPY --chmod=755 components/workbench/start.sh /usr/local/bin/start-workbench
COPY --chmod=755 components/workbench/security/verify-srt.sh /usr/local/bin/verify-srt
RUN mkdir -p /workspace /home/node/.node-red \
    && chown -R node:node /workspace /home/node

USER node
WORKDIR /workspace
CMD ["/usr/local/bin/start-workbench"]
