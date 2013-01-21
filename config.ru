require 'rubygems'
require 'bundler'
Bundler.require

$:.push File.expand_path("../lib", __FILE__)
require 'uecmos.rb'


run Sinatra::Application