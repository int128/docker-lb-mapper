Settings =
  mapfile: process.env.mapfile || 'containers'
  allowPorts: process.env.allowPorts?.split(',') || [80, 8080]

require 'array.prototype.find'
require 'string.prototype.endswith'

Docker      = require 'dockerode'
JSONStream  = require 'JSONStream'
Q           = require 'q'
fs          = require 'fs'
os          = require 'os'

docker      = new Docker socketPath: '/var/run/docker.sock'

console.info Settings

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
    fqdn = "#{inspect.Config.Hostname}#{inspect.Config.Domainname && '.' || ''}#{inspect.Config.Domainname}"
    if port = findDestinationPort inspect
      "#{fqdn} #{inspect.NetworkSettings.IPAddress}:#{port};"
    else
      "# #{fqdn} #{inspect.NetworkSettings.IPAddress};"
  .join '\n'

findDestinationPort = (inspect) ->
  exposedPorts = Object.keys inspect.Config.ExposedPorts ? {}
    .filter (port) -> port.endsWith '/tcp'
    .map    (port) -> parseInt(port)
  Settings.allowPorts
    .find   (port) -> port in exposedPorts

