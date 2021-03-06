require "rubygems"
require "bundler/setup"

require "yajl/json_gem"
require "hashie"
require "typhoeus"

require "forwardable"
require "uri"

module Npolar
  module Api
    module Client

      VERSION = "0.3.5"

      USER_AGENT = "npolar-api-client-ruby-#{VERSION}/Typhoeus-#{Typhoeus::VERSION}/libcurl-#{`curl --version`.chomp.split(" ")[1]}"

    end
  end
end

require_relative "client/json_api_client"
