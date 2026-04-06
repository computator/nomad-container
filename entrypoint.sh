#!/bin/sh
set -eu

EP_CONF_DIR=/run/nomad-entrypoint-conf.d

build_configs () {
	local is_server=$1

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

	if [ -n "${BIND_ADDR-}" ]; then
			cat > "${EP_CONF_DIR}/bind-addr.hcl" <<-EOF
				bind_addr = "${BIND_ADDR}"
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

	if [ -z "${TLS_DISABLED:+1}" ]; then
			cat > "${EP_CONF_DIR}/tls.hcl" <<-EOF
				tls {
				  http = true
				  rpc = true
				  verify_https_client = ${TLS_HTTPS_VERIFY:-true}
				  verify_server_hostname = true
				  ca_file = "${TLS_CA_FILE:?'TLS_CA_FILE must be set!'}"
				  cert_file = "${TLS_CERT_FILE:?'TLS_CERT_FILE must be set!'}"
				  key_file = "${TLS_KEY_FILE:?'TLS_KEY_FILE must be set!'}"
				}
			EOF
	fi

	if [ $is_server ] && [ -z "${SERF_ENC_DISABLED:+1}" ]; then
			: "${SERF_ENC_KEY:?'SERF_ENC_KEY must be set!'}"
			# mktemp creates with mode 600
			f=$(mktemp -p "${EP_CONF_DIR}")
			cat > "$f" <<-EOF
				server {
				  encrypt = "${SERF_ENC_KEY}"
				}
			EOF
			mv "$f" "${EP_CONF_DIR}/serf-enc-key.hcl"
	fi

	if [ -n "${ACL_ENABLED:+1}" ]; then
			cat > "${EP_CONF_DIR}/acl-enable.hcl" <<-EOF
				acl {
				  enabled = true
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
	is_server=
	for n; do
		[ "$n" = '-server' ] || continue
		is_server=1
		break
	done

	mkdir -p ${EP_CONF_DIR}
	build_configs "${is_server}"

	alloc_arg=
	[ ! $is_server ] && alloc_arg=${ALLOC_DIR:?'ALLOC_DIR must be set!'}

	set -- \
		-config ${EP_CONF_DIR} \
		-config /config \
		-data-dir /data \
		${alloc_arg:+'-alloc-dir' "${alloc_arg}"} \
		-plugin-dir /plugins \
		"$@"
fi

exec nomad ${cmd:+"${cmd}"} "$@"
