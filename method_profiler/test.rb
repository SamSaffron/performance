require_relative './method_profiler'
require 'net/http'
require 'openssl'

MethodProfiler.patch(Net::HTTP, [
  :request
], :net, no_recurse: true)


MethodProfiler.start

def raw_json_request
  arguments ||= {}

  # Support paths that begin with slashes
  uri = URI.parse("https://meta.discourse.org/")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 15

  if uri.scheme == "https"
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  end

  headers = {}

  request = yield(uri.request_uri, headers)
  response = http.request(request)

  code = response.code.to_i

  case code
  when 401
    raise Blizzard::TokenError.new(response.body)
  when 500..599
    raise Blizzard::ServiceError.new(response.body)
  end
  response.body
end

raw_json_request do |query_url, headers|
  Net::HTTP::Get.new(query_url, headers)
end

p MethodProfiler.stop


