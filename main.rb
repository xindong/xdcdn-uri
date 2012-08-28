require 'rubygems'
require 'sinatra'
require 'pp'
$: << File.expand_path(File.dirname(__FILE__))

APP_ROOT = File.dirname(__FILE__)

set :port, 3003
set :public, APP_ROOT + '/public'

