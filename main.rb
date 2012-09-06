APP_ROOT = File.dirname(__FILE__)

$: << File.expand_path(APP_ROOT) + '/lib'

require 'rubygems'
require 'sinatra'
require 'chandy'
require 'redis'
require 'zlib'
require 'yaml'

# =========================== configurations =========================

set :bind, '0.0.0.0'
set :port, 3013
set :public_folder, APP_ROOT + '/public'
set :static_cache_control, [:public, :max_age => 3600]
enable :threaded, :protection

configure :production do
    $config = YAML::load_file("#{APP_ROOT}/config/production.yml")
end
configure :development do
    $config = YAML::load_file("#{APP_ROOT}/config/development.yml")
    enable :reload_templates
end
configure do
    $redis = Redis.new(
        :host => $config['redis']['host'],
        :port => $config['redis']['port']
    )
    $redis.select($config['redis']['base'])
    $uri = $config['repos'].merge($config['repos']) { |k, v| Chandy::Repo.new(v['git']) }
end

# =========================== functions ==============================

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
    return data.sort.join("\n")
end

def no_cache
    cache_control :private, :max_age => 0
end

def deflate_body(data)
    if env['HTTP_ACCEPT_ENCODING'].nil? or data.size < 10000
        body data
    elsif env['HTTP_ACCEPT_ENCODING'].split(",").include? 'deflate'
        logger.info "EEE"
        gzipped = Zlib::Deflate.deflate(data, 9)
        if gzipped.size < data.size * 0.8
            headers \
                'Vary' => 'Accept-Encoding',
                'Content-Encoding' => 'gzip'
            body gzipped
            logger.info gzipped.size
        end
    end
    body data
end

# =========================== hooks =================================

error 404 do
    no_cache
    content_type 'text/plain; charset=utf-8'
    body "404
    file not found
    -- XINDONG CDN\n"
end

error 500 do
    no_cache
    content_type 'text/plain; charset=utf-8'
    body "500
    internal server error
    please try later
    -- XINDONG CDN\n"
end

error Chandy::NotFound do 404 end
error do
    headers 'X-DCDN-URI-Exception' => msg
    logger.error msg
    500
end

before do
    @repo = request.path_info.split('/')[1]
    404 if $uri[@repo].nil?
    # 默认缓存1年
    expires 31536000, :public, :must_revalidate
end

after do
    body '' if body.nil?
end

# ============================ actions ==============================

get '/:repo/index/:tag' do
    unpack = params[:unpack] ? true : false
    begin
        tag = params[:tag]
        key = "V:Chandy:IDX:#{@repo}:#{tag}"
        dat = nil
        dat = $redis.get(key) unless unpack
        if dat.nil?
            idx = $uri[@repo].index(params[:tag])
            dat = pack_path_hash(idx, unpack)
            unless unpack
                $redis.set(key, dat)
                $redis.expire(key, 3600)
            end
        end
        content_type 'text/plain; charset=utf-8'
        expires 3600, :public, :must_revalidate
        deflate_body dat
    rescue Redis::CannotConnectError => e
        500
    rescue Chandy::NotFound => e
        404
    rescue => e
        raise e.message
    end
end

get '/:repo/indexall/:tag' do
    unpack = params[:unpack] ? true : false
    begin
        tag = params[:tag]
        key = "V:Chandy:IDXAll:#{@repo}:#{tag}"
        dat = nil
        dat = $redis.get(key) unless unpack
        if dat.nil?
            idx = $uri[@repo].all_blobs(params[:tag])
            dat = pack_path_hash(idx, unpack)
            unless unpack
                $redis.set(key, dat)
                $redis.expire(key, 3600)
            end
        end
        content_type 'text/plain; charset=utf-8'
        deflate_body dat
    rescue Redis::CannotConnectError => e
        500
    rescue Chandy::NotFound => e
        404
    rescue => e
        raise e.message
    end
end

get '/:repo/tree/:tree/:file' do
    blob = $uri[@repo].file(params[:tree], params[:file])
    content_type blob['mime_type']
    deflate_body blob['data']
end
