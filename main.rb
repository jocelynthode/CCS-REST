# Ruby dependencies
require 'sinatra'
require 'json'
require 'net/http'
if development?
  require 'sinatra/reloader'
  require 'pry'
end

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
  if response.body.empty?
    body ({ errors: [{ message: 'Ooops, this route does not seem exist' }] }.to_json)
  end
end

error do
  errormsg = 'Sorry there was a nasty error - ' + env['sinatra.error'].message
  body ({ errors: [{ message: errormsg }] }.to_json)
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
  url = TRANSPORT_EP + '/locations?' + uri_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  body result.to_json
end

get '/connections' do
  uri_param = URI.encode_www_form(params)
  url = TRANSPORT_EP + '/connections?' + uri_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  body result.to_json
end

get '/stationboard' do
  uri_param = URI.encode_www_form(params)
  url = TRANSPORT_EP + '/stationboard?' + uri_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  body result.to_json
end

get '/weather' do
  if params['q'] && (params['lon'] || params['lat'])
    return [400, { errors: [{ message: 'Cannot use both q and lat/lon parameters at the same time' }] }.to_json]
  end
  uri_param = URI.encode_www_form(params)
  url = WEATHER_EP + "/weather?APPID=#{WEATHER_APPID}&" + uri_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)

  if result['cod'].to_i == 200
    body result.to_json
  else
    return [result['cod'].to_i, { errors: [{ message: result['message'] }] }.to_json]
  end
end

get '/stations' do
  ip = params['ip'] || '130.125.1.11'
  url = IP_EP + '/' + ip
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)

  form_param = {}
  form_param[:station] = result['city']
  form_param['transportations[]'] = %w(ice_tgv_rj ec_ic ir re_d)
  form_param = URI.encode_www_form(form_param)

  url = TRANSPORT_EP + '/stationboard?' + form_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  result['stationboard'] = result['stationboard'][0..4]
  body result.to_json
end

get '/weathers' do
  ip = params['ip'] || '130.125.1.11'
  url = IP_EP + '/' + ip
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)

  form_param = {}
  form_param[:station] = result['city']
  form_param['transportations[]'] = %w(ice_tgv_rj ec_ic ir re_d)
  form_param = URI.encode_www_form(form_param)

  url = TRANSPORT_EP + '/stationboard?' + form_param
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  result = JSON.parse(response.body)
  result['stationboard'] = result['stationboard'][0..4]
  url = WEATHER_EP + "/weather?APPID=#{WEATHER_APPID}&q="
  tmp_result = []

  result['stationboard'].each { |destination|
    uri = URI(url + URI.encode(destination['to']))
    response = Net::HTTP.get_response(uri)
    tmp_result << { destination: destination['to'], weather: JSON.parse(response.body) }
  }

  if params['sort'].nil? || params['sort'] == 'temp'
    tmp_result.sort! { |x, y| y[:weather]['main']['temp'] <=> x[:weather]['main']['temp'] }
  elsif params['sort'] == 'humidity'
    tmp_result.sort! { |x, y| y[:weather]['main']['humidity'] <=> x[:weather]['main']['humidity'] }
  elsif params['sort'] == 'pressure'
    tmp_result.sort! { |x, y| y[:weather]['main']['pressure'] <=> x[:weather]['main']['pressure'] }
  elsif params['sort'] == 'cloud'
    tmp_result.sort! { |x, y| y[:weather]['clouds']['all'] <=> x[:weather]['clouds']['all'] }
  elsif params['sort'] == 'wind'
    tmp_result.sort! { |x, y| y[:weather]['wind']['speed'] <=> x[:weather]['wind']['speed'] }
  end
  body tmp_result.to_json
end

get '/future_weathers' do
  body ({ errors: [{ message: 'not yet implemented' }] }.to_json)
end
