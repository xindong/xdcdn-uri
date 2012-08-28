$: << File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'rubygems'
require 'sinatra'
require 'pp'
require 'xdcdn_uri'
require 'radix62'
require 'zlib'

APP_ROOT = File.dirname(__FILE__)

set :port, 3003
set :public_folder, APP_ROOT + '/public'

def xdcdn(dir)
    XdcdnUri.new(dir)
end

configure :production do
    set :ktk, xdcdn("/home/www/sites/ktk.xdcdn.net")
end

configure :development do
    set :ktk, xdcdn("/Users/xdanger/Sites/xdcdn.net/ktk.xdcdn.net")
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

get '/ktk/index/:tag' do
    begin
        idx = settings.ktk.index(params[:tag])
        response['Cache-Control'] = 'max-age=31536000'
        data = pack_trees_hash(idx)
        Zlib::Deflate.deflate(data, 9)
    rescue
        response['Cache-Control'] = 'max-age=0'
        "Error"
    end
end

get '/ktk/tree/:tree/:file' do
    tree_id = params[:tree].decode62.to_s(16)
    blob = settings.ktk.file(tree_id, params[:file])
    response['Content-Length'] = blob['bytes'].to_s
    response['Cache-Control'] = 'max-age=31536000'
    response['Content-Type'] = blob['mime_type']
    blob['data']
end
