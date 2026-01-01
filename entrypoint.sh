#!/bin/sh
set -eu

EP_CONF_DIR=/run/nomad-entrypoint-conf.d

build_configs () {
	cat > "${EP_CONF_DIR}/disable-updates.hcl" <<-EOF
		disable_update_check = true
	EOF

	cat > "${EP_CONF_DIR}/enable-podman-plugin.hcl" <<-EOF
		plugin "nomad-driver-podman" {}
	EOF

	if [ -n "${BIND_PORTS-}" ]; then
			cat > "${EP_CONF_DIR}/ports.hcl" <<-EOF
				ports {
				  ${BIND_PORTS}
				}
			EOF
	fi

	if [ -n "${ADVERTISE_ADDR-}" ]; then
			cat > "${EP_CONF_DIR}/advertise-addr.hcl" <<-EOF
				advertise {
				  http = "${ADVERTISE_ADDR}"
				  rpc = "${ADVERTISE_ADDR}"
				  serf = "${ADVERTISE_ADDR}"
				}
			EOF
	fi

	if [ -n "${DRIVER_ALLOWLIST-}" ]; then
			cat > "${EP_CONF_DIR}/driver-allow.hcl" <<-EOF
				client {
				  options {
				    "driver.allowlist" = "${DRIVER_ALLOWLIST}"
				  }
				}
			EOF
	fi

	if [ -n "${NOMAD_SERVERS-}" ]; then
			cat > "${EP_CONF_DIR}/servers.hcl" <<-EOF
				client {
				  servers = [$(
						echo "${NOMAD_SERVERS}" \
						| tr , ' ' \
						| xargs printf '"%s",' \
						| sed 's/,$//'
					)]
				}
			EOF
	fi
}

cmd=${1-}
[ $# -gt 0 ] && shift

if [ "${cmd}" = "agent" ]; then
	mkdir -p ${EP_CONF_DIR}
	build_configs

	is_server=
	for n; do
		[ "$n" = '-server' ] || continue
		is_server=1
		break
	done

	alloc_arg=
	[ ! $is_server ] && alloc_arg=${ALLOC_DIR?'ALLOC_DIR must be set!'}

	set -- \
		-config ${EP_CONF_DIR} \
		-config /config \
		-data-dir /data \
		${alloc_arg:+'-alloc-dir' "${alloc_arg}"} \
		-plugin-dir /plugins \
		"$@"
fi

exec nomad ${cmd:+"${cmd}"} "$@"
