role :nodes_clt, "root@20v001.xd.cn", "root@kti.xd.com:22281", "root@kti.xd.com:22291", "root@kti.xd.com:22301", :type => 'production'
role :nodes_www, "www@20v001.xd.cn", "www@kti.xd.com:22281", "www@kti.xd.com:22291", "www@kti.xd.com:22301", :type => 'production'
role :nodes_clt, "root@a11.xd.cn", :type => 'testing'
role :nodes_www, "www@a11.xd.cn" , :type => 'testing'

namespace :a2 do 

    task :deploy, :roles => :nodes_clt, :except => { :type => 'production' } do
        run "ln -sf /home/www/sites/uri.xdcdn.net/config/ssh-keys/config /home/www/.ssh/config && \
             ln -sf /home/www/sites/uri.xdcdn.net/config/supervisord.conf /etc/"
    end

    task :update, :roles => :nodes_clt, :except => { :type => 'production' } do
        run "supervisorctl update"
    end

    desc "在 uri.xindong.com 上释出新版本"
    task :release, :roles => :nodes_www, :except => { :type => 'production' } do
        run "cd /home/www/sites/uri.xdcdn.net \
             && git pull \
             && chmod 0600 config/ssh-keys/*"
        update
        run "touch /home/www/sites/uri.xdcdn.net/tmp/restart.txt"
    end

    task :status, :roles => :nodes_clt, :except => { :type => 'production' } do
        run "tail -n 10 /home/www/sites/uri.xdcdn.net/log/*.txt"
    end
    
end

namespace :pd do 

    task :deploy, :roles => :nodes_clt, :except => { :type => 'testing' } do
        run "ln -sf /home/www/sites/uri.xdcdn.net/config/ssh-keys/config /home/www/.ssh/config && \
             ln -sf /home/www/sites/uri.xdcdn.net/config/supervisord.conf /etc/"
    end

    task :update, :roles => :nodes_clt, :except => { :type => 'testing' } do
        run "supervisorctl update"
    end

    desc "在 uri.xdcdn.net 上释出新版本"
    task :release, :roles => :nodes_www, :except => { :type => 'testing' } do
        run "cd /home/www/sites/uri.xdcdn.net \
             && git pull \
             && chmod 0600 config/ssh-keys/*"
        update
        run "touch /home/www/sites/uri.xdcdn.net/tmp/restart.txt"
    end

    task :status, :roles => :nodes_clt, :except => { :type => 'testing' } do
        run "tail -n 10  /home/www/sites/uri.xdcdn.net/log/*.txt"
    end
    
end
