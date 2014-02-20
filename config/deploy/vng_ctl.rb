set :stage, :vng_ctl
#role :nodes_ctl, %w{ root@172.16.5.5 root@172.16.5.6 root@172.16.5.7 }
#role :nodes_www, %w{  www@172.16.5.5  www@172.16.5.6  www@172.16.5.7 }
server '172.16.5.5', user: 'root', port: 22, roles: %w{nodes_ctl}
server '172.16.5.6', user: 'root', port: 22, roles: %w{nodes_ctl}
server '172.16.5.7', user: 'root', port: 22, roles: %w{nodes_ctl}
