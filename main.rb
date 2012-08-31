APP_ROOT = File.dirname(__FILE__)

$: << File.expand_path(APP_ROOT) + '/lib'

require 'rubygems'
require 'sinatra'
require 'pp'
require 'grit'
require 'xdcdn_uri'
require 'redis'
require 'radix62'
require 'zlib'
require 'yaml'

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

def pack_trees_hash(trees_hash)
    index = []
    trees_hash.each { |dir, tid|
        key = Digest::SHA1.hexdigest(dir)[0..10].to_i(16).encode62
        val = tid.to_i(16).encode62
        index << "#{key}:#{val}"
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

# 默认缓存1年
before do
  expires 31536000, :public, :must_revalidate
end

get '/ktk/index/:tag' do
    idx = {}
    tag = params[:tag]
    key = "V:XdcdnUri:KtkIdx:#{tag}"
    begin
        dat = $redis.get(key)
        if dat.nil?
            idx = settings.ktk.index(params[:tag])
            if idx.nil?
                status 404
                no_cache
                return
            end
            dat = pack_trees_hash(idx)
            $redis.set(key, dat)
            $redis.expire(key, 3600)
        end
        if params[:nozip].nil?
            body Zlib::Deflate.deflate(dat, 9)
        else
            body dat
        end
    rescue Grit::NoSuchPathError => e
        broken_with 'Git Error'
    rescue Redis::ConnectionError => e
        broken_with 'Redis Error'
    rescue => e
        broken_with e.message
    ensure
        return
    end
end

get '/ktk/tree/:tree/:file' do
    tree_id = params[:tree].decode62.to_s(16)
    blob = settings.ktk.file(tree_id, params[:file])
    content_type blob['mime_type']
    body blob['data']
end
