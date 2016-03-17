# Ruby dependencies
require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
require 'net/http'

# sinatra configuration
set :show_exceptions, :after_handler

before do
  # allow CORS
  content_type :json
  status 200
  headers \
    'Allow'                         => 'OPTIONS, GET',
    'Access-Control-Allow-Origin'   => '*',
    'Access-Control-Allow-Methods'  => %w('OPTIONS', 'GET')
end

not_found do
  body ({ error: 'Ooops, this route does not seem exist' }.to_json)
end

error do
  body ({ error: 'Sorry there was a nasty error - ' + env['sinatra.error'].message }.to_json)
end

# API endpoints
IP_EP = 'http://ip-api.com/json'.freeze
TRANSPORT_EP = 'http://transport.opendata.ch/v1'.freeze
WEATHER_EP = 'http://api.openweathermap.org/data/2.5'.freeze

WEATHER_APPID = '78d387756f815cffc23dc7de1ed27497'.freeze

# start coding below
get '/ip' do
  ip = params['ip'] || '130.125.1.11'
  url = IP_EP + '/' + ip
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  body result.to_json
end

get '/locations' do
  uri_param = URI.encode_www_form(params)
  uri = URI.join(TRANSPORT_EP, 'locations?' + uri_param)

  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  body result.to_json
end

get '/connections' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end

get '/stationboard' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end

get '/weather' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end

get '/stations' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end

get '/weathers' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end

get '/future_weathers' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end
