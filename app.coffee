Settings =
  mapfile: process.env.mapfile || 'containers'
  prefix:  process.env.prefix  || ''
  postfix: process.env.postfix || ''

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
              Q.ninvoke workaroundKill(docker.getContainer(lb.Id)), 'kill', signal: 'SIGHUP'
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
    "#{Settings.prefix}#{inspect.Name.slice 1}#{Settings.postfix} #{inspect.NetworkSettings.IPAddress};"
  .join '\n'

# Workaround for dockerode kill API
# TODO: remove if updated to v2.0.4 or later
workaroundKill = (container) ->
  container.kill = (opts, callback) ->
    if !callback && typeof(opts) == 'function'
      callback = opts
      opts = null
    optsf =
      path: '/containers/' + @id + '/kill?'
      method: 'POST'
      statusCodes:
        204: true
        404: "no such container"
        500: "server error"
      options: opts
    @modem.dial optsf, (err, data) -> callback(err, data)
  container

