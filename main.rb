APP_ROOT = File.dirname(__FILE__)

$: << File.expand_path(APP_ROOT) + '/lib'

require 'rubygems'
require 'sinatra'
require 'grit'
require 'xdcdn_uri'
require 'redis'
require 'zlib'
require 'yaml'

# 404 handler
not_found do
    no_cache
    content_type 'text/plain; charset=utf-8'
    "404\nfile not found
    -- XINDONG CDN\n"
end

configure :production do
    set :config, Proc.new { YAML::load_file("#{APP_ROOT}/config/production.yml") }
end
configure :development do
    set :config, Proc.new { YAML::load_file("#{APP_ROOT}/config/development.yml") }
end

set :port, 3013
set :public_folder, APP_ROOT + '/public'
set :ktk, Proc.new { XdcdnUri.new(settings.config['ktk']['git']) }

configure do
    $redis = Redis.new(
        :host => settings.config['redis']['host'],
        :port => settings.config['redis']['port']
    )
    $redis.select(settings.config['redis']['base'])
end

def pack_trees_hash(trees_hash, unpack = false)
    index = []
    trees_hash.each { |dir, tid|
        if unpack
            key = Digest::SHA1.hexdigest(dir)[0,10]
            val = tid
        else
            key = Digest::SHA1.digest(dir)[0,5]
            val = [tid].pack('H*')
        end
        index << "#{key}#{val}"
    }
    return index.join("\n")
end

def no_cache
    cache_control :private, :max_age => 0
end

def broken_with(msg)
    status 500
    headers 'X-DCDN-URI-Exception' => msg
    $stderr.puts msg
    no_cache
end

def deflate_body(dat)
    if env['HTTP_ACCEPT_ENCODING'].nil? or dat.size < 10000
        body dat
    elsif env['HTTP_ACCEPT_ENCODING'].split(",").include? 'deflate'
        gzipped = Zlib::Deflate.deflate(dat, 9)
        if gzipped.size < dat.size * 0.8
            headers \
                'Vary' => 'Accept-Encoding',
                'Content-Encoding' => 'gzip'
            body gzipped
        end
    else
        body dat
    end
end

# 默认缓存1年
before do
  expires 31536000, :public, :must_revalidate
end

get '/ktk/index/:tag' do
    unpack = params[:unpack] ? true : false
    begin
        tag = params[:tag]
        key = "V:XdcdnUri:KtkIdx:#{tag}"
        dat = nil
        dat = $redis.get(key) unless unpack
        if dat.nil?
            idx = settings.ktk.index(params[:tag])
            if idx.nil?
                status 404
                no_cache
                return
            end
            dat = pack_trees_hash(idx, unpack)
            unless unpack
                $redis.set(key, dat)
                $redis.expire(key, 3600)
            end
        end
        content_type 'text/plain; charset=utf-8'
        deflate_body dat
    rescue Grit::NoSuchPathError => e
        broken_with 'Git Error'
    rescue Redis::ConnectionError => e
        broken_with 'Redis Error'
    rescue => e
        broken_with e.message
    end
end

get '/ktk/tree/:tree/:file' do
    blob = settings.ktk.file(params[:tree], params[:file])
    content_type blob['mime_type']
    deflate_body blob['data']
end
