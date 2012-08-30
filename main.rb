$: << File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'rubygems'
require 'sinatra'
require 'pp'
require 'xdcdn_uri'
require 'radix62'
require 'zlib'
require 'yaml'

APP_ROOT = File.dirname(__FILE__)

set :port, 3003
set :public_folder, APP_ROOT + '/public'

configure :production do
    set :config, Proc.new { YAML::load_file(File.dirname(__FILE__) + '/config/production.yml') }
end

configure :development do
    set :config, Proc.new { YAML::load_file(File.dirname(__FILE__) + '/config/development.yml') }
end

set :ktk, Proc.new { XdcdnUri.new(settings.config['ktk']['git']) }

def pack_trees_hash(trees_hash)
    index = []
    trees_hash.each { |dir, tid|
        key = Digest::SHA1.hexdigest(dir)[0..10].to_i(16).encode62
        val = tid.to_i(16).encode62
        index << "#{key}:#{val}"
    }
    return index.join("\n")
end

get '/ktk/index/:tag' do
    begin
        idx = settings.ktk.index(params[:tag])
        if idx.nil?
            status 404
            return
        end
        response['Cache-Control'] = 'max-age=31536000'
        data = pack_trees_hash(idx)
        Zlib::Deflate.deflate(data, 9)
    rescue => e
        response['Cache-Control'] = 'max-age=0'
        $stderr.puts e.backtrace
    end
end

get '/ktk/tree/:tree/:file' do
    tree_id = params[:tree].decode62.to_s(16)
    blob = settings.ktk.file(tree_id, params[:file])
    headers \
        'Content-Length' => blob['bytes'].to_s,
        'Cache-Control' => 'max-age=31536000',
        'Content-Type' => blob['mime_type']
    body blob['data']
end
