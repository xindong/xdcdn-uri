set :stage, :vng_www
server '172.16.5.5', user: 'www' , port: 22, roles: %w{nodes_www}
server '172.16.5.6', user: 'www' , port: 22, roles: %w{nodes_www}
server '172.16.5.7', user: 'www' , port: 22, roles: %w{nodes_www}