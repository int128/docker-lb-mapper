Settings =
  mapfile: process.env.mapfile || 'containers'

Docker      = require 'dockerode'
JSONStream  = require 'JSONStream'
Q           = require 'q'
fs          = require 'fs'
os          = require 'os'

docker      = new Docker socketPath: '/var/run/docker.sock'

Q.ninvoke docker, 'ping'
  .then ->
    provision()
  .then ->
    Q.ninvoke docker, 'getEvents', {}
  .then (stream) ->
    stream.pipe JSONStream.parse().on 'root', (event) ->
      console.info "Received event #{event.status} #{event.id} #{event.from}"
      if event.status == 'start'
        provision()
  .fail (error) ->
    console.error error

provision = ->
  Q.ninvoke docker, 'listContainers'
    .then (containers) ->
      containers.map (container) ->
        Q.ninvoke docker.getContainer(container.Id), 'inspect'
    .all()
    .then (inspects) ->
      mapcontent = formatter inspects
      Q.denodeify(fs.writeFile)(Settings.mapfile, mapcontent)
        .then ->
          console.info "Updated #{Settings.mapfile} as"
          console.info mapcontent
        .then ->
          Q.delay 100
        .then ->
          findLoadBalancers inspects
            .map (lb) ->
              console.info "Sending singal to reload #{lb.Name} #{lb.Id}"
              Q.ninvoke docker.getContainer(lb.Id), 'kill', signal: 'SIGHUP'
    .all()
    .then ->
      console.info 'Provisioning done'

findLoadBalancers = (inspects) ->
  volumesFroms =
    Array.prototype.concat.apply [],
      inspects.filter (inspect) -> inspect.Config.Hostname == os.hostname()
        .map (inspect) -> inspect.HostConfig.VolumesFrom
  inspects.filter (inspect) -> inspect.Id in volumesFroms

formatter = (inspects) ->
  inspects.map (inspect) ->
    if inspect.Config.Domainname
      "#{inspect.Config.Hostname}.#{inspect.Config.Domainname} #{inspect.NetworkSettings.IPAddress};"
    else
      "#{inspect.Config.Hostname} #{inspect.NetworkSettings.IPAddress};"
  .join '\n'

