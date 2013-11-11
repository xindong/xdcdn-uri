APP_ROOT = File.dirname(__FILE__)

$: << File.expand_path(APP_ROOT) + '/lib'

require 'rubygems'
require 'sinatra'
require 'chandy'
require 'redis'
require 'zlib'
require 'yaml'
require 'time'
require 'pp'
require 'newrelic_rpm'

# =========================== configurations =========================

set :bind, '0.0.0.0'
set :public_folder, APP_ROOT + '/public'
set :static_cache_control, [:public, { :max_age => 3600 }]

disable :protection
enable :threaded

configure :production do
    disable :show_exceptions
    set :log_file, "#{APP_ROOT}/log/production.log"
end

configure :development do
    enable :reload_templates
    set :log_file, "#{APP_ROOT}/log/development.log"
end

$config = YAML::load_file("#{APP_ROOT}/config/#{ENV['CONFIG_FILE']}.yml")

configure do
    $redis = Redis.new(
        :host => $config['redis']['host'],
        :port => $config['redis']['port']
    )
    $redis.select($config['redis']['base'])
    $uri = $config['repos'].merge($config['repos']) { |k, v| Chandy::Repo.new(v['git']) }

    set :content_type , 'application/octet-stream'
    mime_type :jpg    , 'image/jpeg'
    mime_type :jpeg   , 'image/jpeg'
    mime_type :png    , 'image/png'
    mime_type :swf    , 'application/x-shockwave-flash'
    mime_type :xml    , 'application/xml'
    mime_type :zip    , 'application/zip'
    mime_type :unity3d, 'application/vnd.unity'

    #orig_stdout = $stdout
    #$stdout = File.new('/dev/null', 'w')
    unity = MIME::Types['application/vnd.unity'].first.to_hash
    unity['Extensions'].push('unity3d')
    MIME::Types.add(MIME::Type.from_hash(unity))
    #$stdout = orig_stdout
end

# =========================== common functions ==============================

def log(msg)
    File.open(settings.log_file, 'a') do |f|
        f.write("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg.inspect}\n")
    end
end

def no_cache
    cache_control :private, :max_age => 0
    expires 0
end

def echo_mt(mt)
    begin
        content_type mt
    rescue RuntimeError
        content_type 'application/octet-stream'
    end
end

def deflate_body(data)
    body data and return
    if env['HTTP_ACCEPT_ENCODING'].nil? or data.size < 10000
        body data
    elsif env['HTTP_ACCEPT_ENCODING'].split(",").include? 'deflate'
        gzipped = Zlib::Deflate.deflate(data, 9)
        if gzipped.size < data.size * 0.8
            headers \
                'Vary' => 'Accept-Encoding',
                'Content-Encoding' => 'gzip'
            body gzipped
        end
    end
    body data
end

# =========================== hooks =================================

error 404 do
    key = "V:Chandy:NotFound:#{request.path_info}"
    do_redis { $redis.set(key, "1") }
    do_redis { $redis.expire(key, 60) }
    no_cache
    echo_mt 'text/plain; charset=utf-8'
    body "404
    file not found
    -- XINDONG CDN\n"
end

error 500 do
    no_cache
    echo_mt 'text/plain; charset=utf-8'
    body "500
    internal server error
    please try later
    -- XINDONG CDN\n"
end

error Chandy::NotFound do halt 404 end
error do halt 500 end

before do
    @repo = request.path_info.split('/')[1]
    halt 404 if $uri[@repo].nil?
    dat = nil
    key = "V:Chandy:NotFound:#{request.path_info}"
    do_redis { dat = $redis.get(key) }
    halt 404 unless dat.nil?
    # 默认缓存1年
    headers \
        'Date' => Time.now.rfc2822,
        'Last-Modified' => Time.now.rfc2822,
        'X-Response-On' => Time.now.to_s
    expires 31536000
end

after do
    if body.nil? or body.empty? do
        no_cache
        body ''
    end
end

# =========================== app functions ==============================

def pack_path_hash(hash, unpack = false)
    data = []
    hash.each { |pth, tid|
        if unpack
            key = Digest::SHA1.hexdigest(pth)[0,10]
            val = tid
        else
            key = Digest::SHA1.digest(pth)[0,5]
            val = [tid].pack('H*')
        end
        data << "#{key}#{val}"
    }
    if unpack
        return data.sort.join("\n")
    else
        return data.sort.join("")
    end
end

def do_redis
    begin
        yield
    rescue Redis::InheritedError => e
        $redis.client.reconnect
        yield
    end
end

def process_index(key, unpack = false)
    dat = nil
    unless unpack
        do_redis { dat = $redis.get(key) }
        return dat unless dat.nil? or dat.empty?
    end
    idx = yield
    dat = pack_path_hash(idx, unpack)
    unless unpack
        do_redis { $redis.set(key, dat) }
        do_redis { $redis.expire(key, 3600) }
    else
        # unpack 相当于一个清缓存的接口了
        do_redis { $redis.del(key) }
    end
    return dat
end

# ============================ actions ==============================

get '/:repo/index/:tag' do
    unpack = params[:unpack] ? true : false
    key = "V:Chandy:Index:#{@repo}:#{params[:tag]}"
    begin
        dat = process_index(key, unpack) do
            $uri[@repo].index(params[:tag])
        end
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    rescue => e
        log e.inspect
        halt 500
    end
    echo_mt 'text/plain; charset=utf-8'
    expires 3600, :public, :must_revalidate
    deflate_body dat
end

get '/:repo/diff/:tag1..:tag2' do
    unpack = params[:unpack] ? true : false
    key = "V:Chandy:Diff:#{@repo}:#{params[:tag1]}..#{params[:tag2]}"
    begin
        dat = process_index(key, unpack) do
            $uri[@repo].diff(params[:tag1], params[:tag2])
        end
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    rescue => e
        log e.inspect
        halt 500
    end
    echo_mt 'text/plain; charset=utf-8'
    expires 3600, :public, :must_revalidate
    deflate_body dat
end

get '/:repo/files/:tag' do
    unpack = params[:unpack] ? true : false
    key = "V:Chandy:Files:#{@repo}:#{params[:tag]}"
    begin
        dat = process_index(key, unpack) do
            $uri[@repo].all_blobs(params[:tag])
        end
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    rescue => e
        log e.inspect
        halt 500
    end
    echo_mt 'text/plain; charset=utf-8'
    expires 3600, :public, :must_revalidate
    deflate_body dat
end

get '/:repo/file/:blob_id.:ext' do
    begin
        blob = $uri[@repo].file(:blob_id => params[:blob_id])
        echo_mt params[:ext]
        deflate_body blob['data']
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    end
end

get '/:repo/file/:blob_id/:file' do
    begin
        blob = $uri[@repo].file(:blob_id => params[:blob_id])
        log("/#{params[:repo]}/file/#{params[:blob_id]}/#{params[:file]} : #{blob['bytes']}")
        echo_mt File.extname(params[:file])
        deflate_body blob['data']
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    end
end

get '/:repo/tree/:tree/:file' do
    begin
        blob = $uri[@repo].file(:tree_id => params[:tree], :filename => params[:file])
        echo_mt File.extname(params[:file])
        deflate_body blob['data']
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    end
end

get %r{^/([a-z]+)/load/([a-zA-Z0-9_\-\.]+)/([\w/\.]+)} do
    begin
        blob = $uri[@repo].file(:tag => params[:captures][1], :path => params[:captures][2])
        echo_mt File.extname(params[:captures][2])
        deflate_body blob['data']
    rescue Chandy::NotFound => e
        log e.reason
        halt 404
    end
end

get '/:repo/preload/:tag1..:tag2' do
    data = []
    $uri[@repo].diff(params[:tag1], params[:tag2]).each { |path, blob|
        data << "http://#{request.host}/#{params[:repo]}/file/#{blob}/#{File.basename(path)}"
    }
    echo_mt "text/plain; charset=utf-8"
    data.join("\n")
end

get '/:repo/preload/:tag' do
    data = []
    $uri[@repo].index(params[:tag]).each { |dir, tid|
        $uri[@repo].grit.tree(tid).blobs.each { |b|
            data << "http://#{request.host}/#{params[:repo]}/tree/#{tid}/#{b.basename}"
            #data << "http://#{request.host}/#{params[:repo]}/file/#{b.id}/#{b.basename}"
        }
    }
    echo_mt "text/plain; charset=utf-8"
    data.join("\n")
end

get '/:repo/status' do
    no_cache
    echo_mt 'text/plain; charset=utf-8'
    file = "#{APP_ROOT}/log/uri_#{params[:repo]}.txt"
    halt 404 unless File.exists?(file)
    text = `tail -n 200 #{file}`
    deflate_body text
end

get '/:repo/404' do
    no_cache
    echo_mt 'text/plain; charset=utf-8'
    klist = nil
    urls = []
    do_redis { klist = $redis.keys("V:Chandy:NotFound:/#{params[:repo]}/*") }
    klist.each { |key| urls << key.gsub(/^V:Chandy:NotFound:/, '') }
    deflate_body urls.join("\n")
end

