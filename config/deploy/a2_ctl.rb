set :stage, :a2_ctl
#role :nodes_ctl, %w{ root@a11.xd.cn }
#role :nodes_www, %w{  www@a11.xd.cn }
server 'a11.xd.cn', user: 'root' , roles: %w{nodes_ctl}
