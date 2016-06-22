# encoding: utf-8
require "uri"
require "typhoeus"

class ::Typhoeus::Response
  alias :status :code

  def uri
    URI.parse(options[:effective_url])
  end

end

class ::Typhoeus::Request

  def uri
    URI.parse(url)
  end

  def verb
    options[:method].to_s.upcase
  end
  alias :http_method :verb
  alias :request_method :verb

end

module Npolar::Api::Client

  # Ruby client for https://api.npolar.no, based on Typhoeus and libcurl
  # https://github.com/typhoeus/typhoeus
  class JsonApiClient

    VERSION = "0.10.pre"

    class << self
      attr_accessor :key
    end
    attr_accessor :uri, :model, :parsed, :log, :authorization, :concurrency, :slice, :param, :options
    attr_reader :responses, :response, :options

    extend ::Forwardable
    def_delegators :uri, :scheme, :host, :port, :path

    BASE = "https://api.npolar.no"

    HEADER = { "User-Agent" => Npolar::Api::Client::USER_AGENT,
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Accept-Charset" => "UTF-8",
        "Accept-Encoding" => "gzip,deflate",
        "Connection" => "keep-alive"
    }
    # Typhoeus options => RENAME
    OPTIONS = { :headers => HEADER,
      :timeout => nil, # 600 seconds or nil for never
      :forbid_reuse => true
    }

    # New client
    # @param [String | URI] base Base URI for all requests
    # @param [Hash] options (for Typhoeus)
    def initialize(base=BASE, options=OPTIONS)
      # Prepend https://api.npolar.no if base is relative (like /service)
      if base =~ /^\//
        path = base
        base = BASE+path
      end
      @base = base
      unless base.is_a? URI
        @uri = URI.parse(base)
      end
      @options = options
      init
    end

    def init
      @model = Hashie::Mash.new
      @log = ENV["NPOLAR_ENV"] == "test" ? ::Logger.new("/dev/null") : ::Logger.new(STDERR)
      @concurrency = 5
      @slice = 1000
      @param={}
    end

    # All documents
    def all(path="_all")
      if not param.key "fields"
        self.param = param||{}.merge ({fields: "*"})
      end

      mash = get_body(path, param)
      mash
    end
    alias :feed :all

    # Base URI (without trailing slash)
    def base
      unless @base.nil?
        @base.gsub(/\/$/, "")
      end
    end

    # DELETE
    #
    def delete(path=nil)
      if param.key? "ids"
        delete_ids(uri, param["ids"])
      else
        execute(
          request(path, :delete, nil, param, header)
        )
      end
    end

    def delete_ids(endpoint, ids)
      delete_uris(self.class.uris_from_ids(endpoint, ids))
    end

    def delete_uris(uris)
      @responses=[]
      multi_request("DELETE", uris, nil, param, header).run
      responses
    end

    # Request header Hash
    def header
      options[:headers]
    end
    alias :headers :header

    def header=(header)
      if header.is_a? Array
        options[:headers]=header
      else
        options[:headers].merge! header
      end

    end
    alias :headers= :header=

    def http_method
      @method
    end
    alias :verb :http_method

    # Validation errors
    # @return [Array]
    def errors(document_or_id)
      @errors ||= model.merge(document_or_id).errors
    end

    # deprecated
    def get_body(uri, param={})
      @param = param
      response = get(uri)
      unless (200..299).include? response.code
        raise "Could not GET #{uri} status: #{response.code}"
      end

      begin
        body = JSON.parse(response.body)
        if body.is_a? Hash

          if model? and not body.key? "feed"
            body = model.class.new(body)
          else
            body = Hashie::Mash.new(body)
          end
        elsif body.is_a? Array
          body.map! {|hash|Hashie::Mash.new(hash)}
        end

      rescue
        body = response.body
      end

      body

      #if response.headers["Content-Type"] =~ /application\/json/
      #  #if model?
      #  JSON.parse(body)
      #  #
      #  #model
      #else
      #  body
      #end

    end

    # GET
    def get(path=nil)
      if param.key? "ids"
        get_ids(uri, param["ids"])
      else
        request = request(path, :get, nil, param, header)

        request.on_success do |response|
          if response.headers["Content-Type"] =~ /application\/json/

            @parsed = JSON.parse(response.body)

            if model?
              begin
                # hmm => will loose model!
                @modelwas = model
                @model = model.class.new(parsed)
                @mash = model
              rescue
                @model = @modelwas
                # Parsing only for JSON objects
              end
            end
          end
        end

      execute(request)
      end
    end

    def get_ids(endpoint, ids)
      get_uris(self.class.uris_from_ids(endpoint, ids))
    end

    def get_uris(uris)
      @responses=[]
      multi_request("GET", uris).run
      responses
      ## set on success =>
      #json = responses.select {|r| r.success? and r.headers["Content-Type"] =~ /application\/(\w+[+])?json/ }
      #if json.size == responses.size
      #  responses.map {|r| r.body }
      #else
      #  raise "Failed "
      #end
    end
    alias :multi_get :get_uris

    # HEAD
    def head(path=nil)
      execute(request(path, :head, nil, param, header))
    end

    # All ids
    def ids
      get_body("_ids").ids
    end

    # All invalid documents
    def invalid
      valid(false)
    end

    # Model?
    def model?
      not @model.nil?
    end

    # POST
    # @param [Array, Hash, String] body
    def post(body, path=nil)
      if header["Content-Type"] =~ /application\/(\w+[+])?json/
         chunk_save(path, "POST", body, param, header)
      else
        execute(
          request(path, :post, body, param, header)
        )
      end
    end

    # PUT
    def put(body, path=nil)
      execute(
        request(path, :put, body, param, header)
      )
    end

    def status
      response.code
    end

    def uris
      ids.map {|id| base+"/"+id }
    end

    # All valid documents
    def valid(condition=true)
      all.select {|d| condition == valid?(d) }.map {|d| model.class.new(d)}
    end

    # Valid?
    def valid?(document_or_id)
      # FIXME Hashie::Mash will always respond to #valid?
      if not model? or not model.respond_to?(:valid?)
        return true
      end

      validator = model.class.new(document_or_id)

      # Return true if validator is a Hash with errors key !
      # FIXME Hashie::Mash will always respond to #valid?
      if validator.key? :valid? or validator.key? :errors
        return true
      end

      valid = validator.valid?

      if validator.errors.nil?
        return true
      end

      @errors = validator.errors # store to avoid revalidating
      valid = case valid
        when true, nil
          true
        when false
          false
      end
      valid
    end

    def username
      # export NPOLAR_HTTP_USERNAME=http_username
      @username ||= ENV["NPOLAR_API_USERNAME"]
    end

    def username=(username)
      @username=username
    end

    def password
      # export NPOLAR_HTTP_PASSWORD=http_password
      @password ||= ENV["NPOLAR_API_PASSWORD"]
    end

    def password=(password)
      @password=password
    end

    def execute(request=nil)
      log.debug log_message(request)
      @response = request.run
    end

    # @return []
    def request(path=nil, method=:get, body=nil, params={}, headers={})

      if path =~ /^http(s)?[:]\/\//
        # Absolute URI
        uri = path

      elsif path.nil?
        # Use base URI if path is nil
        uri = base

      elsif path =~ /^\/\w+/
        # Support /relative URIs by prepending base
        uri = base+path

      elsif path =~ /^\w+/ and base =~ /^http(s)?[:]\/\//
        uri = base+"/"+path
      else
        # Invalid URI
        raise ArgumentError, "Path is invalid: #{path}"
      end

      unless uri.is_a? URI
        uri = URI.parse(uri)
      end

      @uri = uri
      @param = param
      @header = headers
      method = method.downcase.to_sym

      context = { method: method,
        body: body,
        params: params,
        headers: headers,
        accept_encoding: "gzip"
      }
      if true == authorization or [:delete, :post, :put].include? method
        context[:userpwd] = "#{username}:#{password}"
      end

      request = Typhoeus::Request.new(uri.to_s, context)

      request.on_complete do |response|
        on_complete.call(response)
      end

      request.on_failure do |response|
        on_failure.call(response)
      end

      request.on_success do |response|
        on_success.call(response)
      end

      @request = request

      request

    end

    def on_failure
      @on_failure ||= lambda {|response|
        if response.code == 0
          # No response, something's wrong.
          log.error "#{request.verb} #{request.uri.path} failed with message: #{response.return_message}"
        elsif response.timed_out?
          log.error "#{request.verb} #{request.uri.path} timed out in #{response.total_time} seconds"
        else
          log.error log_message(response)
        end
      }
    end

    def on_complete
      @on_complete ||= lambda {|response|} #noop
    end

    def on_success
      @on_success ||= lambda {|response|
        log.info log_message(response)
      }
    end

    #def on_complete=(on_complete_lambda)
    #  if @on_complete.nil?
    #    @on_complete = []
    #  end
    #  @on_complete << on_complete_lambda
    #end

    protected

    # @return [Array] ids
    def self.fetch_ids(uri)
      client = self.new(uri)
      client.model = nil

      response = client.get
      #if 200 == response.code
      #
      #end

      idlist = JSON.parse(response.body)

      if idlist.key? "feed" and idlist["feed"].key? "entries"

        ids = idlist["feed"]["entries"].map {|d|
          d["id"]
        }.flatten

      elsif idlist.key? "ids"

        ids = idlist["ids"]

      else
        raise "Cannot fetch ids"
      end
    end

    # @return [Array] URIs
    def self.uris_from_ids(base, ids)

      unless ids.is_a? Array
        if ids =~ /^http(s)?[:]\/\//
          ids = fetch_ids(ids)
        else
          raise "Can only fetch ids via HTTP"
        end
      end

      unless base.is_a? URI
        base = URI.parse(base)
      end

      ids.map {|id|
        puts id
        path = "#{base.path}/#{id}"
        uri = base.dup
        uri.path = path
        uri
      }

    end

    def hydra
      @hydra ||= Typhoeus::Hydra.new(max_concurrency: concurrency)
    end

    # Prepare and queue a multi request
    #
    # @return [#run]
    def multi_request(method, paths, body=nil, param=nil, header=nil)
      @multi = true

      # Response storage, if not already set
      if @responses.nil?
        @responses = []
      end

      # Handle one or many paths
      if paths.is_a? String or paths.is_a? URI
        paths = [paths]
      end

      # Handle (URI) objects
      paths = paths.map {|p| p.to_s }

      log.debug "Queueing multi-#{method} requests, concurrency: #{concurrency}, path(s): #{ paths.size == 1 ? paths[0]: paths.size }"

      paths.each do | path |

        multi_request = request(path, method.downcase.to_sym, body, param, header)
        multi_request.on_complete do | response |
          log.debug "Multi-#{method} [#{paths.size}]: "+log_message(response)
          @responses << response
        end
        hydra.queue(multi_request)
      end
      hydra
    end
    alias :queue :multi_request

    # Slice Array of documents into chunks of #slice size and queue up for POST or PUT
    # @return [Array] responses
    def chunk_save(path=nil, method="POST", docs, param, header)
      @multi = true

      if path.nil?
        path = uri
      end

      unless docs.is_a? Array
        docs = JSON.parse(docs)
      end


      if docs.is_a? Hash
        docs = [docs]
      end

      if slice < docs.size
        log.debug "Slicing #{docs.size} documents into #{slice} chunks"
      end

      docs.each_slice(slice) do | chunk |
        queue(method, path, chunk.to_json, param, header)
      end
      hydra.run

      # @todo => on complete
      successes = @responses.select {|r| (200..299).include? r.code }
      if successes.size > 0

        if docs.size < slice
          log.info "Saved #{docs.size} document(s) using #{@responses.size} #{method} request(s). Concurrency: #{concurrency}"
        else
          log.info "Saved #{docs.size} documents, sliced into chunks of #{slice} using #{@responses.size} #{method} requests.  Concurrency: #{concurrency}"
        end
      end

      failures = @responses.reject {|r| (200..299).include? r.code }
      if failures.size > 0
        log.debug "#chunk_save error in #{failures.size}/#{responses.size} requests"
      end

      @responses
    end


    def log_message(r)
      if r.is_a? Typhoeus::Request
        request = r
        "#{request.http_method} #{scheme}://#{host}:#{port}#{path} [#{self.class.name}] #{param} #{header}"
      else
        response = r

        "#{response.code} #{response.request.http_method} #{response.request.url} [#{self.class.name}] #{response.total_time} #{response.body.bytesize} #{response.body[0..1024]}"
      end
    end

  end

end
