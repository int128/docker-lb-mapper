docker-lb-mapper
================

A daemon for provisioning mapping of nginx and Docker containers.


Concept
-------

When an new Docker container is started, docker-lb-mapper does following:

1. Regenerates a mapping file.
  * the nginx container must have a volume for a mapping file, e.g. `/etc/nginx/containers` volume.
  * the docker-lb-mapper container mounts the volume from it.
2. Sends a signal (SIGHUP) to the nginx container.
  * docker-lb-mapper finds the nginx container which provides the volume.
  * docker-lb-mapper sends a signal via Docker API.

A mapping file consists of hostname, domainname and IP address of each container.

```conf
xxx.example.com 172.17.0.1;
yyy.example.com 172.17.0.2;
zzz.example.com 172.17.0.2;
```


How to use
----------

Try the demo now.
It requires Docker and [Fig](http://www.fig.sh).

```sh
git clone https://github.com/int128/docker-lb-mapper.git
cd docker-lb-mapper/demo/
fig up

# Access to helloworld container
curl helloworld.lvh.me

# Not exists
curl dummy.lvh.me
```

See [fig.yml](demo/fig.yml) and [nginx configuration](demo/sites-enabled/vhosts.conf) for details.

