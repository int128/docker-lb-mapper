#!/bin/bash
nginx_map=/containers/nginx.map

function event_loop () {
  while read line; do
    local event="$(echo $line | sed -e 's/^.* \(\w*\)$/\1/g')"
    case "$event" in
      start | destroy)
        echo "$(date): $event"
        provision_nginx;;
    esac
  done
}

function provision_nginx () {
  docker ps -q | xargs docker inspect -f '{{.Name}} {{.NetworkSettings.IPAddress}};' | tee "$nginx_map"
  docker ps -q | xargs docker inspect -f '{{if eq .Path "nginx"}}{{.ID}}{{end}}' | xargs docker kill -s HUP 2> /dev/null
}

docker --version || exit 1
provision_nginx
docker events "$@" | event_loop
