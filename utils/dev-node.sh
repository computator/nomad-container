#!/bin/sh

export ALLOC_DIR
: ${ALLOC_DIR:="$(mktemp -d -p "$PWD" nomad_allocs.XXXXX)"}
: ${PODMAN_SOCKET:="${XDG_RUNTIME_DIR}/podman/podman.sock"}

# Notes:
# - ALLOC_DIR must match inside and outside so podman can find mounts
# - SYS_ADMIN capability is for alloc mounting
# - disabling labels is so nomad can access podman socket
exec podman run \
	--rm \
	-it \
	-p 127.0.0.1:4646:4646 \
	-v "${PODMAN_SOCKET}":/run/podman/podman.sock \
	-v "${ALLOC_DIR}:${ALLOC_DIR}:rshared" \
	-e ALLOC_DIR \
	--cap-add=SYS_ADMIN \
	--security-opt label=disable \
	"${IMAGE:-"ghcr.io/computator/nomad"}" \
	agent -dev
