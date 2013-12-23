set :stage, :a2_www
#role :nodes_clt, %w{ root@a11.xd.cn }
#role :nodes_www, %w{  www@a11.xd.cn }
server 'a11.xd.cn', user: 'www' , roles: %w{nodes_www}
