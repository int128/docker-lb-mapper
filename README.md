nginx-container-mapper
======================

Dynamic proxy with Docker and nginx.


What is this
------------

A shell-script which provisions `/container/nginx.map` on Docker events such as start or stop.

For example, if following containers are running,

* CONTAINER IP = 172.17.0.1, CONTAINER NAME = www.example.com
* CONTAINER IP = 172.17.0.2, CONTAINER NAME = member.example.com

`/container/nginx.map` will be provisioned as follows:

```conf
/www.example.com 172.17.0.1;
/member.example.com 172.17.0.2;
```

Also a HUP signal will be sent to the nginx container to reload gracefully.


Prepare
-------

Add following to your nginx configuration.

```conf
http {
  map /$host $container_ip {
    include /containers/nginx.map;
  }

  server {
    listen              80;
    server_name         *.example.com;
    location / {
      proxy_pass http://$container_ip:8080;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
    if ($container_ip = "") {
      return 444;
    }
  }
}
```


Run
---

```sh
docker run -d -v /var/run/docker.sock:/var/run/docker.sock --name nginx-container-mapper int128/nginx-container-mapper
docker logs nginx-container-mapper
```

Your nginx container should mount `/containers` directory. 
Run with `--volumes-from` as follows.

```sh
docker run -d --volumes-from nginx-container-mapper your/nginx
```

