# Ruby dependencies
require 'ipaddr'
require 'json'
require 'net/http'
require 'sinatra'
if development?
  require 'sinatra/reloader'
  require 'pry'
end

# sinatra configuration
set :show_exceptions, false # Never show exceptions

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
  unless @http_error_caught
    halt_errors 404, 'Ooops, this route does not seem exist'
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
def halt_errors(code, *errors)
  content = {
    errors: errors.map do |msg| { message: msg } end
  }
  @http_error_caught = true
  halt code, content.to_json
end

# Generic function to request a function from an API
def get_response(api_url, path, params)
  uri_params = URI.encode_www_form(params)
  url = api_url + path + uri_params
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  response_body = JSON.parse(response.body)

  [response.code.to_i, response_body]
end

# Retrieves IP while checking for possible errors
def get_ip(ip)
  ip = '130.125.1.11' if ip.nil?
  # Validate IP address by trying to build an IPAddr object
  begin
    IPAddr.new(ip)
  rescue IPAddr::InvalidAddressError
    halt_errors 400, 'Invalid IP address'
  end

  code, data = get_response(IP_EP, '/', [ip])
  # The remote API doesn't use HTTP error code semantically
  if code != 200
    halt_errors 500, 'An unknown problem occurred when trying to locate this IP Address'
  elsif data['status'] != 'success'
    halt_errors 400, "Couldn't infer location from IP Address: " + data['message']
  else
    data
  end
end

# Get next 5 destinations from a city
def get_and_trim_stations(city)
  form_param = {}
  form_param[:station] = city
  form_param['transportations[]'] = %w(ice_tgv_rj ec_ic ir re_d) # Only trains
  code, data = get_response(TRANSPORT_EP, '/stationboard?', form_param)
  if code != 200
    halt_errors code, data['errors'].map { |err| err['message'] }
  elsif data['stationboard'].empty?
    halt_errors 404, %[Cannot find any train connections leaving from "#{city}"]
  end
  data['stationboard'] = data['stationboard'][0..4]
  data
end

# Update params that are arrays so that they can be encoded using URI.encode_www_forms
def update_params(params)
  params.map { |k, v|
    if v.is_a?(Array)
      [k + '[]', v[0].strip.split(/[\s,]+/)]
    else
      [k, v]
    end
  }.to_h
end

# Sort the result using a criterion in descending order
def sort_weathers!(results, sort_by = 'temp')
  case sort_by
  when 'temp'
    results.sort_by! { |x| x[:weather]['main']['temp'] }
  when 'humidity'
    results.sort_by! { |x| x[:weather]['main']['humidity'] }
  when 'pressure'
    results.sort_by! { |x| x[:weather]['main']['pressure'] }
  when 'cloud'
    results.sort_by! { |x| x[:weather]['clouds']['all'] }
  when 'wind'
    results.sort_by! { |x| x[:weather]['wind']['speed'] }
  else
    return false
  end
  results.reverse!
  true
end

get '/ip' do
  body get_ip(params['ip']).to_json
end

get '/locations' do
  if params['query'] && (params['x'] || params['y'])
    halt_errors 400, 'Cannot use both query and x/y parameters at the same time'
  elsif params['query'].nil? && params['x'].nil? && params['y'].nil?
    halt_errors 400, 'Either query or x/y are required'
  elsif params['query'].nil? && (params['x'].nil? || params['y'].nil?)
    halt_errors 400, 'You have to set both x and y'
  elsif params['transportations'] && (params['x'].nil? || params['y'].nil?)
    halt_errors 400, 'You need to use x and y to use transportations[]'
  end

  _code, result = get_response(TRANSPORT_EP, '/locations?', update_params(params))
  # TODO: handle code != 200, is http code semantic ?
  body result.to_json
end

get '/connections' do
  if params['from'].nil? || params['to'].nil?
    halt_errors 400, 'from and to are both required'
  end

  _code, result = get_response(TRANSPORT_EP, '/connections?', update_params(params))
  # TODO: handle code != 200, is http code semantic ?
  body result.to_json
end

get '/stationboard' do
  halt_errors 400, 'station is required' if params['station'].nil?

  _code, result = get_response(TRANSPORT_EP, '/stationboard?', update_params(params))
  # TODO: check if status: 200 but station: false (for example with wrong transpotation but no station given)
  body result.to_json
end

get '/weather' do
  if params['q'].nil? && (params['lon'].nil? || params['lat'].nil?)
    halt_errors 400, 'Either q or lat and long have to be set'
  elsif params['q'] && (params['lon'] || params['lat'])
    halt_errors 400, 'Cannot use both q and lat/lon parameters at the same time'
  end
  _code, result = get_response(WEATHER_EP, "/weather?APPID=#{WEATHER_APPID}&", params)

  # OpenWeather api returns the code in the JSON, therefore we check it here
  if result['cod'].to_i == 200
    body result.to_json
  else
    halt_errors result['cod'].to_i, result['message']
  end
end

get '/stations' do
  result = get_ip(params['ip'])
  result = get_and_trim_stations(result['city'])
  # TODO: check response code ?
  body result.to_json
end

get '/weathers' do
  location = get_ip(params['ip'])
  connections = get_and_trim_stations(location['city'])

  # retrieve the weather for each destination
  weathers = connections['stationboard'].map do |connection|
    code, data = get_response(WEATHER_EP, '/weather?', APPID: WEATHER_APPID, q: connection['to'])
    # TODO: check error code ?
    { destination: connection['to'], weather: data }
  end

  if sort_weathers! weathers, params['sort']
    body weathers.to_json
  else
    halt_errors 400, 'Given sort criterion doesn\'t exist'
  end
end

get '/future_weathers' do
  # Check if nb_days is between 1 and 5
  nb_days = params['nb_days'].to_i
  halt_errors 400, 'nb_days must be a number between 1 and 5' unless (1..5).cover? nb_days

  location = get_ip(params['ip'])
  connections = get_and_trim_stations(location['city'])

  today = Time.now.to_date
  # Retrieve the forecasts for each destination
  weathers = connections['stationboard'].map do |connection|
    code, data = get_response(WEATHER_EP, '/forecast?', APPID: WEATHER_APPID, q: connection['to'])
    # TODO: check error code ?
    # Get the forecast for 12:00 UTC in nb_days
    # Note: We count the days using localtime
    weather = data['list'].find do |forecast|
      dt = Time.at(forecast['dt'])
      dt.utc.hour == 12 && (dt.to_date - today) == nb_days
    end
    data.merge!(weather).delete('list')
    { destination: connection['to'], weather: data }
  end

  if sort_weathers! weathers, params['sort']
    body weathers.to_json
  else
    halt_errors 400, 'Given sort criterion doesn\'t exist'
  end
end
