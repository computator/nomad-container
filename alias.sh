# example alias to run the cli more easily
alias nomad='podman run --rm -i --net=host --env "NOMAD_*" -v .:/workdir -w /workdir ghcr.io/computator/nomad'
