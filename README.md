npolar-api-client-ruby
======================
UNSTABLE Ruby client for https://api.npolar.no, based on [Typhoeus](https://github.com/typhoeus/typhoeus)

## Features

* Handles POST of large JSON Arrays
* Parallel requests
* Mimicks well-known curl commands
* Automatic authentication on write operations
* Automatic Content-Type, Accept, and other headers

## npolar-api (command-line tool)
```
npolar-api [options] [https://api.npolar.no]/endpoint

npolar-api /schema
npolar-api -XPOST /endpoint --data=/file.json
npolar-api -XPOST /endpoint --data='{"title":"Title"}'
npolar-api -XPUT  --headers http://admin:password@localhost:5984/testdb
npolar-api -XPUT --headers http://admin:password@localhost:5984/testdb/test1
npolar-api -XDELETE /endpoint/id

npolar-api is built on top of Typhoeus/libcurl.
For more information and source: https://github.com/npolar/npolar-api-ruby-client

Options:
        --auth                       Force authorization
    -d, --data=data                  Data (request body) for POST and PUT
        --debug                      Debug (alias for --level=debug
    -l, --level=level                Log level
    -X, --method=method              HTTP method, GET is default
    -H, --header=header              Add HTTP request header
        --ids=ids                    URI that returns identifiers
        --join                       Use --join with --ids to join documents into a JSON array
    -c, --concurrency=number         Concurrency (max)
    -s, --slice=number               Slice size on POST 
    -i, --headers                    Show HTTP response headers
    -v, --verbose                    Verbose

```

## Install

gem install # not-yet-released

Gemfile:
gem "npolar-api-client-ruby"


## Authentication

Set the following environmental variables for automatic authentication
```
NPOLAR_API_USERNAME=username
NPOLAR_API_PASSWORD=********
```
