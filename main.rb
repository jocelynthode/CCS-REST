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

def get_response(api_url, path, params)
  uri_params = URI.encode_www_form(params)
  url = api_url + path + uri_params
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

def get_ip(ip)
  ip = '130.125.1.11' if ip.nil?
  get_response(IP_EP, '/', [ip])
end

def get_and_trim_stations(city)
  form_param = {}
  form_param[:station] = city
  form_param['transportations[]'] = %w(ice_tgv_rj ec_ic ir re_d)
  get_response(TRANSPORT_EP, '/stationboard?', form_param)

  result = get_response(TRANSPORT_EP, '/stationboard?', form_param)
  result['stationboard'] = result['stationboard'][0..4]
  result
end

def parse_params(params)
  params.each { |k, v| params[k] = v.strip.split(/[\s,]+/) if k.end_with? '[]' }
end

# start coding below
get '/ip' do
  body get_ip(params['ip']).to_json
end

get '/locations' do
  parse_params(params)

  result = get_response(TRANSPORT_EP, '/locations?', params)
  body result.to_json
end

get '/connections' do
  parse_params(params)

  result = get_response(TRANSPORT_EP, '/connections?', params)
  body result.to_json
end

get '/stationboard' do
  parse_params(params)

  result = get_response(TRANSPORT_EP, '/stationboard?', params)
  body result.to_json
end

get '/weather' do
  if params['q'] && (params['lon'] || params['lat'])
    return [400, { errors: [{ message: 'Cannot use both q and lat/lon parameters at the same time' }] }.to_json]
  end
  result = get_response(WEATHER_EP, "/weather?APPID=#{WEATHER_APPID}&", params)

  if result['cod'].to_i == 200
    body result.to_json
  else
    return [result['cod'].to_i, { errors: [{ message: result['message'] }] }.to_json]
  end
end

get '/stations' do
  result = get_ip(params['ip'])
  result = get_and_trim_stations(result['city'])
  body result.to_json
end

get '/weathers' do
  result = get_ip(params['ip'])

  result = get_and_trim_stations(result['city'])
  url = WEATHER_EP + "/weather?APPID=#{WEATHER_APPID}&q="
  tmp_result = []
  # TODO: 404 when no station board ?

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
  result = get_ip(params['ip'])

  result = get_and_trim_stations(result['city'])
  url = WEATHER_EP + "/forecast?APPID=#{WEATHER_APPID}&q="
  tmp_result = []
  # TODO: 404 when no station board ?

  # TODO: check nb_days
  nb_days = params['nb_days'].to_i
  today = Time.now.to_date
  result['stationboard'].each { |destination|
    uri = URI(url + URI.encode(destination['to']))
    response = Net::HTTP.get_response(uri)
    data = JSON.parse(response.body)
    weather = data['list'].find do |forecast|
      dt = Time.at(forecast['dt'])
      dt.utc.hour == 12 && (dt.to_date - today) == nb_days
    end
    data.merge!(weather).delete('list')
    tmp_result << { destination: destination['to'], weather: data }
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
