set :stage, :pd_www
#role :nodes_clt, %w{ root@116.182.64.232:22281 root@115.182.64.232:22291 root@115.182.64.232:22301 root@60.251.11.28 root@60.251.11.29 }
#role :nodes_www, %w{  www@115.182.64.232:22281  www@115.182.64.232:22291  www@115.182.64.232:22301  www@60.251.11.28  www@60.251.11.29 }
server '115.182.64.227', user: 'www' , port: 22281, roles: %w{nodes_www}
server '115.182.64.227', user: 'www' , port: 22291, roles: %w{nodes_www}
server '115.182.64.227', user: 'www' , port: 22301, roles: %w{nodes_www}
server '223.202.26.147', user: 'www' , port: 22   , roles: %w{nodes_www}
server '223.202.26.148', user: 'www' , port: 22   , roles: %w{nodes_www}
server '223.202.26.149', user: 'www' , port: 22   , roles: %w{nodes_www}
server '60.251.11.28'  , user: 'www' , port: 22   , roles: %w{nodes_www}
server '60.251.11.29'  , user: 'www' , port: 22   , roles: %w{nodes_www}
server '106.186.22.159', user: 'www' , port: 22   , roles: %w{nodes_www}
server '23.239.25.98'  , user: 'www' , port: 22   , roles: %w{nodes_www}
