# Cloud Computing: Mini-project 1
This implementation was made by Simon BRULHART and Jocelyn THODE.

The project is composed of:
* CCS-REST
    * Repository: https://github.com/jocelynthode/CCS-REST
    * Public endpoint: https://brulhart-thode-sass-app.herokuapp.com
* WIS-Client
    * Repository: https://github.com/jocelynthode/WIS-Client
    * Public endpoint: http://clusterinfo.unineuchatel.ch:10104/

## 1 Development Environment
We decided to use our own environment instead of the provided VM, since we already had Rubymine installed. We used RVM to use Ruby 2.2.4. To debug the code we used pry-byebug which is a really helpful debugger.

The presentation server sets the REST endpoint to http://localhost:4000 when running in the development environment.

## 2 Implementing your own calls
Below we explain the purpose of the different routes and in some cases a particularity of our code. As we had to repeat a lot of code each we wanted to make a request, we created the following method:
```ruby
def get_response(api_url, path, params)
  uri_params = URI.encode_www_form(params)
  url = api_url + path + uri_params
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  response_body = JSON.parse(response.body)

  [response.code.to_i, response_body]
end
```
which makes a standard JSON API call.

### 2.1 /ip
This route returns the location of the provided IP address. If no address is supplied, we use `130.125.1.11`. As we needed to retrieve the IP address for many other routes in this project we decided to encapsulate this functionality in a function called `get_ip` which takes an ip as argument.

### 2.2 /locations
This route returns the closest station to the supplied query or x and y coordinates. On the presentation layer, a **+** button lets the user add additional `transportations[]` parameters if needed. This button is available for every parameters that can be specified multiple time.

### 2.3 /connections
This route returns the next connections from a location to another. The `from` and `to` fields are required.

### 2.4 /stationboard
This route returns the next connections leaving from a location. Only the `station` field is required.

### 2.5 /weather
This route returns the current weather of a location. You can either use the name of the city or its coordinates. If both are set, this leads to an error.

### 2.6 /stations
This route is the first one to mash up different services. Here we ask for an IP address and we return the next five train connections leaving from the closest station to this IP address.

We used our `get_ip` function to retrieve the location easily and we also created a function `get_and_trim_stations` as we also need to get the first five train connections /weathers. `get_and_trim_stations` creates a request and sets `transportations[]` to
```ruby
form_param['transportations[]'] = %w(ice_tgv_rj ec_ic ir re_d)
```
which states we are only interested in the trains. After that when we get the response we slice the array of connections to only include the first five using `[0..4]`.

### 2.7 /weathers
This route returns a JSON array containing hashes of the form:
```javascript
{
  "destination": <destination>,
  "weather": {
    ...
  }
}
```
The destinations are found using the provided IP address to find the next 5 departures from the train station using the earlier defined function `get_and_trim_stations`. We then get the five destinations from the result and do a request for each one of them to find the weather for each of them.

You can sort by either temperature, humidity, pressure,
cloud or wind, always in decreasing order. We decided to implement a new helper to provide this functionality in WIS-Client. This helper allows creating an HTML `select` element.

In CCS-Rest we check if this parameter is set and if it is we sort it using `sort` with a block. For example to sort by decreasing temperature:
```ruby
results.sort_by! { |x| x[:weather]['main']['temp'] }
results.reverse!
```
All of this is done in a function called `sort_weathers!`

### 2.8 /future_weathers
This route works similarily to `/weathers` except it returns the weathers in `nb_days` instead of the current weathers.
The remote API returns forecasts with a granularity of 3 hours, but we chose to always pick the forecast for 12:00 (12 PM). We thought this behavior to be more user-friendly, since we are more often insterested in the weather for the day than for the night, even if it is 21:00 when looking at the weather.

When counting the days, we start from the current time in the server's timezone, assuming that the user is in the same timezone as the server. This is meant to avoid issues, e.g. the user asks for the weather in 2 days, but instead get the weather in 1 day because the user thinks in 01:00 UTC+2 and the server in 23:00 UTC.
A better solution would be for the REST API to always work in UTC, and the presentation layer to calculate `nb_days` using the timezone of the browser. Another approach would be for the API to accept an ISO date string instead of a number of days.

We pick the forecast for 12:00 **UTC** because it is simple and close enough to 12:00 in our timezone.

## 3 Error Management
### 3.1 Error Format
We followed the same format for any error returned to the client. The HTTP status code has to semantically reflect the error. The response body follows this somewhat conventional format:
```javascript
{
  "errors": [
    {"message": "Some error message"},
    {"message": "Another error message"}
  ]
}
```
This allows us to display errors in a particular manner in the presentation client.
![Error on presentation layer](https://github.com/jocelynthode/CCS-REST/raw/master/report/error_sc.png)
### 3.2 Error Handling
In order to make errors easier to raise, we made a small variadic function `halt_errors` that output the errors in the right format and aborts the request.
This allows us to handle many errors without polluting the code too much.
```ruby
halt_errors 400, 'station is required' if params['station'].nil?
```

If an error occurs in our code and we don't catch it explicitly, a default error handler output a generic error message. In a development environment, the message of the actual encountered error is also shown.
The whole stack trace is dumped in the logs, both in development and production.

For simplicity, we chose to handle some errors directly in our helper functions `get_ip` and `get_and_trim_stations`. This could become a limitation if later we wanted to handle those errors differently in each route. However we thought that the relative simplicity was worth the risk since this project isn't meant to grow.

### 3.3 Issues Encountered
A `not_found` handler was set in case no route matches a client GET request. However, this handler was also triggered when we were returning a 404 error in another route, overriding our response body with the default one.

To mitigate this issue, we now set the `@http_error_caught` instance variable to `true` in `halt_errors`, before outputting any error. This allows the `not_found` handler to check if it should override the response body or not.
