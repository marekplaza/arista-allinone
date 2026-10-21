# check=skip=SecretsUsedInArgOrEnv
# arista-allinone: containerlab + Arista AVD (pyavd + arista.avd + full Ansible) + ANTA
# Multi-arch: linux/amd64 and linux/arm64 (Apple Silicon).
FROM python:3.12-slim-bookworm

ARG DEBIAN_FRONTEND=noninteractive
# Empty = latest at build time. Example: --build-arg AVD_VERSION=5.7.0
ARG CLAB_VERSION=""
ARG AVD_VERSION=""
ARG ANTA_VERSION=""
ARG REF_REPO=https://github.com/marekplaza/cvaas_avd_L2LS.git

LABEL org.opencontainers.image.title="arista-allinone" \
      org.opencontainers.image.description="containerlab, Arista AVD, ANTA, cEOS downloader" \
      org.opencontainers.image.source="https://github.com/marekplaza/arista-allinone"

# --- system tools + Docker CLI (drives the host Docker daemon through the mounted socket)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git make sudo jq less vim-tiny nano tree xz-utils \
        openssh-client sshpass iproute2 iputils-ping dnsutils bash-completion \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- containerlab
RUN bash -c "$(curl -sL https://get.containerlab.dev)" -- ${CLAB_VERSION:+-v $CLAB_VERSION} \
    && rm -rf /var/lib/apt/lists/* \
    && containerlab version

# --- Python: pyavd (with ansible-core), full Ansible community package, ANTA, helpers
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        "pyavd[ansible]${AVD_VERSION:+==$AVD_VERSION}" \
        "anta[cli]${ANTA_VERSION:+==$ANTA_VERSION}" \
        ansible eos-downloader ansible-lint yamllint netaddr jmespath paramiko

# --- Ansible collections: arista.avd at exactly the pyavd version + Arista/network ecosystem
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections
RUN AVD_VER=$(pip show pyavd | awk '/^Version:/{print $2}') \
    && ansible-galaxy collection install -p ${ANSIBLE_COLLECTIONS_PATH} \
         "arista.avd:==${AVD_VER}" arista.eos arista.cvp \
         ansible.netcommon ansible.utils community.general \
    && req=${ANSIBLE_COLLECTIONS_PATH}/ansible_collections/arista/avd/requirements.txt \
    && if [ -f "$req" ]; then pip install --no-cache-dir -r "$req"; fi \
    && ansible-galaxy collection list -p ${ANSIBLE_COLLECTIONS_PATH} 2>/dev/null | grep -E "^(arista|ansible|community)\."

# --- reference lab (cvaas_avd_L2LS), allinone Makefile and get_ceos.sh
RUN git clone --depth 1 ${REF_REPO} /opt/cvaas_avd_L2LS && rm -rf /opt/cvaas_avd_L2LS/.git
COPY lab/Makefile /opt/allinone/Makefile
COPY get_ceos.sh /opt/allinone/get_ceos.sh
COPY lab/bashrc /etc/profile.d/allinone.sh
RUN chmod +x /opt/allinone/get_ceos.sh \
    && ln -s /opt/allinone/get_ceos.sh /usr/local/bin/get_ceos \
    && containerlab completion bash > /etc/bash_completion.d/containerlab \
    && echo '. /etc/profile.d/allinone.sh' >> /root/.bashrc

ENV ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_PYTHON_INTERPRETER=/usr/local/bin/python3
WORKDIR /work
CMD ["bash"]
