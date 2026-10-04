#!/usr/bin/with-contenv bashio

server_addr=$(bashio::config 'server_addr')
server_port=$(bashio::config 'server_port')
token=$(bashio::config 'token')
local_ip=$(bashio::config 'local_ip')
local_port=$(bashio::config 'local_port')
remote_port=$(bashio::config 'remote_port')

# Create FRP configuration file (TOML format, current frp syntax)
cat > /etc/frpc.toml <<EOF
serverAddr = "${server_addr}"
serverPort = ${server_port}

[auth]
method = "token"
token = "${token}"

[[proxies]]
name = "homeassistant"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
EOF

# Never log the config/token (upstream used to `cat` it to the log).
bashio::log.info "Connecting to ${server_addr}:${server_port}, forwarding ${local_ip}:${local_port} -> remote port ${remote_port}"

exec /usr/local/bin/frpc -c /etc/frpc.toml
