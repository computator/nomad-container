ARG NOMAD_VERSION=1.11
FROM docker.io/hashicorp/nomad:${NOMAD_VERSION}

LABEL org.opencontainers.image.source=https://github.com/computator/nomad-container

ARG TARGETOS
ARG TARGETARCH
RUN set -eux; \
	mkdir /config /plugins; \
	rel_base=https://releases.hashicorp.com ; \
	rel_url=$( \
		wget -qO - "${rel_base}$( \
				wget -qO - "${rel_base}/nomad-driver-podman/" \
				| grep -Eom 1 '/nomad-driver-podman/[0-9.]+/' \
			)" \
			| awk '/data-os="'"${TARGETOS}"'"/ && /data-arch="'"${TARGETARCH}"'"/ { print substr($0, match($0, /https?:[^"]*/), RLENGTH) }' \
	) ; \
	wget -O plugin.zip "${rel_url}"; \
	unzip plugin.zip nomad-driver-podman; \
	install nomad-driver-podman /plugins/nomad-driver-podman; \
	rm -f nomad-driver-podman plugin.zip

COPY entrypoint.sh /

VOLUME /data
VOLUME /alloc
EXPOSE 4646 4647 4648/tcp 4648/udp
ENTRYPOINT ["/entrypoint.sh"]
