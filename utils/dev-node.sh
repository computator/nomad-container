#!/bin/sh

is_root=$([ $(id -u) -eq 0 ] && echo 1)

export ALLOC_DIR
: ${ALLOC_DIR:="$(mktemp -d -p "$PWD" nomad_allocs.XXXXX)"}
[ $is_root ] \
	&& : ${PODMAN_SOCKET:="/run/podman/podman.sock"} \
	|| : ${PODMAN_SOCKET:="${XDG_RUNTIME_DIR}/podman/podman.sock"}

# Notes:
# - ALLOC_DIR must match inside and outside so podman can find mounts
# - SYS_ADMIN capability is for alloc mounting

extra_args=
if [ $is_root ]; then
	# disable labels so nomad can access podman socket
	extra_args="${extra_args} --security-opt label=disable"
	# allow access to cgroups so the agent can start
	extra_args="${extra_args} --cgroupns=host"
	extra_args="${extra_args} --security-opt unmask=/sys/fs/cgroup"
fi

exec podman run \
	--rm \
	-it \
	-p 127.0.0.1:4646:4646 \
	-v "${PODMAN_SOCKET}":/run/podman/podman.sock \
	-v "${ALLOC_DIR}:${ALLOC_DIR}:z,rshared" \
	-e ALLOC_DIR \
	--cap-add=SYS_ADMIN \
	${extra_args} \
	"${IMAGE:-"ghcr.io/computator/nomad"}" \
	agent -dev
