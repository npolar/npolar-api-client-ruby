# encoding: utf-8
# https://github.com/radar/guides/blob/master/gem-development.md
# require File.expand_path(File.dirname(__FILE__)+"/lib/npolar/api/client")

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'npolar/api/client'

Gem::Specification.new do |s|
  s.name        = "npolar-api-client-ruby"
  s.version     = Npolar::Api::Client::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Conrad Helgeland"]
  s.email       = ["data*npolar.no"]
  s.homepage    = "http://github.com/npolar/npolar-api-client-ruby"
  s.summary     = "Ruby client library and command line tools for https://api.npolar.no"
  s.description = "Official Ruby client for the Norwegian Polar Institute's API."

  #s.add_development_dependency "rspec", "~> 2.0"
  #s.add_development_dependency "bundler", "~> 2.0"

  s.add_runtime_dependency "hashie"    , "~> 3.4"
  s.add_runtime_dependency "typhoeus"  , "~> 0.7"
  s.add_runtime_dependency "yajl-ruby" , "~> 0.0"
  s.add_runtime_dependency "uuidtools" , "~> 2.1"

  s.files         = Dir.glob("{lib}/**/*") + %w(README.md)
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  git_files       = `git ls-files`.split("\n") rescue ''
  s.files         = git_files # + whatever_else
  s.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  s.require_paths = ["lib"]
  s.license       = 'GPL-3.0'
end
