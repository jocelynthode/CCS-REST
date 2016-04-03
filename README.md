# CCS-REST
Teaching project for purpose of practical works.

The aim here is to manipulate several REST APIs to feed an other one.

All the datas are formatted in JSON.

## Used APIs

- [IP-API.com](http://ip-api.com/) - Geolocation API

- [Transport Opendata CH](http://transport.opendata.ch/) - Swiss public transport API

- [OpenWeatherMap](http://openweathermap.org/)


## Some examples

- `GET /ip`

- `GET /ip?ip=178.209.53.76`

- `GET /stations`

- `GET /stations?ip=178.209.53.76`

- `GET /weathers`

- `GET /weathers?ip=178.209.53.76`

## Implementation
An implementation using this API is available at [WIS-Client](https://github.com/jocelynthode/WIS-Client/) as well a report detailing this implementation.
