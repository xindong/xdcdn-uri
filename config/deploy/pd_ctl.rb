set :stage, :pd_ctl
server '116.182.64.232', user: 'root', port: 22281, roles: %w{nodes_ctl}
server '116.182.64.232', user: 'root', port: 22291, roles: %w{nodes_ctl}
server '116.182.64.232', user: 'root', port: 22301, roles: %w{nodes_ctl}
server '223.202.26.147', user: 'root', port: 22   , roles: %w{nodes_ctl}
server '223.202.26.148', user: 'root', port: 22   , roles: %w{nodes_ctl}
server '223.202.26.149', user: 'root', port: 22   , roles: %w{nodes_ctl}
server '60.251.11.28'  , user: 'root', port: 22   , roles: %w{nodes_ctl}
server '60.251.11.29'  , user: 'root', port: 22   , roles: %w{nodes_ctl}
server '106.186.22.159', user: 'root', port: 22   , roles: %w{nodes_ctl}
server '23.239.25.98'  , user: 'root', port: 22   , roles: %w{nodes_ctl}

