set :stage, :pd_ctl
server '116.182.64.232', user: 'root', port: 22281, roles: %w{nodes_clt}
server '116.182.64.232', user: 'root', port: 22291, roles: %w{nodes_clt}
server '116.182.64.232', user: 'root', port: 22301, roles: %w{nodes_clt}
server '223.202.26.147', user: 'root', port: 22   , roles: %w{nodes_clt}
server '223.202.26.148', user: 'root', port: 22   , roles: %w{nodes_clt}
server '223.202.26.149', user: 'root', port: 22   , roles: %w{nodes_clt}
server '60.251.11.28'  , user: 'root', port: 22   , roles: %w{nodes_clt}
server '60.251.11.29'  , user: 'root', port: 22   , roles: %w{nodes_clt}
server '162.243.140.6' , user: 'root', port: 22   , roles: %w{nodes_ctt}

