require "optparse"  

# @todo Dir[glob] support
#Dir[glob].select {|f|
# f is json?
#}.map {|filename|
#}
# #{CMD} -XPUT -iv -XPUT /endpoint/id -d@-

module Npolar::Api::Client
  
  class NpolarApiCommand

    # Delegate HTTP methods to Npolar::ApiClient::JsonApiClient
    extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html      
    def_delegators :client, :delete, :get, :head, :patch, :post, :put
  
    CMD = "npolar-api"

    PARAM = { method: "GET",
      headers: false,
      header: [],
      level: Logger::WARN,
      join: false,
      uri: JsonApiClient::BASE }

    attr_accessor :param, :log, :uri, :host, :data, :client
  
    def initialize(argv=ARGV, param = PARAM)
      @param = param

      option_parser = OptionParser.new(argv) do |opts|
      
      opts.version = Npolar::Api::Client::VERSION
      
      opts.banner = "#{CMD} [options] [#{PARAM[:uri]}]/endpoint

#{CMD} /schema
#{CMD} -XPOST /endpoint --data=/file.json
#{CMD} -XPOST /endpoint --data='{\"title\":\"Title\"}'
#{CMD} -XPUT --headers http://admin:password@localhost:5984/testdb
#{CMD} -XPUT -iv -XPUT /endpoint/id -d@/path/to/id
cat id-1.json | #{CMD} -XPUT -iv -XPUT /endpoint/id-1 -d@-
#{CMD} -XDELETE /endpoint/id-1

#{CMD} is built on top of Typhoeus/libcurl.
For more information and source: https://github.com/npolar/npolar-api-ruby-client

Options:\n"

        opts.on("--auth", "Force authorization") do |auth|
          @param[:auth] = true
        end
  
        opts.on("--data", "-d=data", "Data (request body) for POST and PUT") do |data|
          if /^([@])?-$/ =~ data
            data = ARGF.read
          else
            if /^[@]/ =~ data
              data = data.gsub(/^[@]/, "")
            end
            if File.exists? data
              data = File.read data
            end
          end
          @data = data
          # Change default method to POST on --data
          if param[:method] == "GET"
            param[:method]="POST"
          end
        end

        opts.on("--debug", "Debug (alias for --level=debug") do
          @param[:level] = Logger::DEBUG
        end

        opts.on("--level", "-l=level", "Log level") do |level|
          @param[:level] = self.class.level(level)
        end

        opts.on("--method", "-X=method", "HTTP method, GET is default") do |method|
          param[:method] = method
        end

        opts.on("--header", "-H=header", "Add HTTP request header") do |header|
          param[:header] << header
        end

        opts.on("--ids=ids", "URI that returns identifiers") do |ids|
          @param[:ids] = ids
        end

        opts.on("--join", "Use --join with --ids to join documents into a JSON array") do |join|
          @param[:join] = true
        end

        opts.on("--concurrency", "-c=number", "Concurrency (max)") do |c|
          param[:concurrency] = c
        end

        opts.on("--slice", "-s=number", "Slice size on POST ") do |slice|
          param[:slice] = slice
        end

        opts.on("--headers", "-i", "Show HTTP response headers") do
          param[:headers] = true
        end

        opts.on("--verbose", "-v", "Verbose") do
          Typhoeus::Config.verbose = true
        end

      end
      
      option_parser.parse!

      # URI is first argument
      @uri = ARGV[0]
      if uri.nil?
        puts option_parser.help
        exit(1)
      end
      
      @log = Logger.new(STDERR)
      @log.level = param[:level]
    end

    # Show response headers?
    def headers?
      param[:headers]
    end

    # Request header Hash
    # Merges default client headers with command line headers (-H or --header) 
    def header
      header = client.header
      param[:header].each do |h|
        k, v = h.split(": ")
        header[k] = v
      end
      header
    end

    # Request path (nil because base URI is already set)
    # @return nil
    def path
      nil
    end
    
    def param=(param)
      @param=param
    end

    # Request parameters (usually nil)
    def parameters
      parameters = {}
      if param.key? :ids
        parameters = parameters.merge({"ids" => param[:ids]})
      end
      parameters
    end

    # Execute npolar-api command
    # @return [nil]
    def run

      @client = JsonApiClient.new(uri)
      @client.log = log
      @client.header = header
      @client.param = parameters
      if param[:concurrency]
       @client.concurrency = param[:concurrency].to_i
      end

      if param[:slice]
       @client.slice = param[:slice].to_i
      end

      if uri =~ /\w+[:]\w+[@]/
        username, password = URI.parse(uri).userinfo.split(":")
        @client.username = username
        @client.password = password
      end
      
      if param[:auth]
        # Force authorization
        @client.authorization = true
      end

      method = param[:method].upcase

      response = nil

      case method
        when "DELETE"
          response = delete
        when "GET"
          response = get
        when "HEAD"
          response = head
        when "PATCH"
          response = patch
        when "POST"
          if data.is_a? Dir
            raise "Not implemented"
          else
            response = post(data)
          end
          
          
          
        when "PUT"
          response = put(data)
        else
          raise ArgumentError, "Unsupported HTTP method: #{param[:method]}"
      end

      #Loop dirs?
      if not response.nil? and (response.respond_to? :body or response.is_a? Array)
        if response.is_a? Array
          responses = response
        else
          responses = [response]
        end

        i = 0
        responses.each do | response |
          i += 1
          log.debug "#{method} #{response.uri.path} [#{i}] Total time: #{response.total_time}"+
            " DNS time: #{response.namelookup_time}"+
            " Connect time: #{response.connect_time}"+
            " Pre-transer time: #{response.pretransfer_time}"
            
          if "HEAD" == method or headers?
            puts response.response_headers
          end
          unless param[:join]
            puts response.body
          end
        end
        
        statuses = responses.map {|r| r.code }.uniq
        status = statuses.map {|code| { code => responses.select {|r| code == r.code }.size } }.to_json.gsub(/["{}\[\]]/, "")
        real_responses_size = responses.select {|r| r.code >= 100 }.size

        log.info "Status(es): #{status}, request(s): #{responses.size}, response(s): #{real_responses_size}"

      else
        raise "Invalid response: #{response}"
      end
      
      if param[:join]
        joined = responses.map {|r|
          JSON.parse(r.body)
        }
        puts joined.to_json
      end

    end

    def action
      param[:action]
    end

    def self.run(argv=ARGV)
      begin
        cmd = new(argv)
        cmd.run
        exit(0)
      rescue => e
        puts e
        puts e.backtrace.join("\n")
        exit(1)
      end
    end
    
    protected
    
    def self.level(level_string, fallback=Logger::INFO)
      
      case level_string
        when /debug|0/i
          Logger::DEBUG
        when /info|1/i
          Logger::INFO
        when /warn|2/i
          Logger::WARN
        when /error|3/i
          Logger::ERROR
        when /fatal|4/i
          Logger::FATAL
        else
          fallback  
      end
    end
    
  end
end
