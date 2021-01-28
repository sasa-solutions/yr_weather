# yr_weather

This gem converts yr.no forecasts into application friendly structures. It summarises and aggregates the data to make it easy to deliver weather forecasts, for any place on earth, using the awesome yr.no forecasts.

Specifically, the Gem repackages yr's data to make it easy to:
1. Present it
2. Draw graphs
3. Make decisions 
4. Script forecasts into databases or other systems

The Gem deals with caching (either using the file system, or in Redis), and constructs the API request to YR in a manner that complies with their [requirements](https://developer.yr.no/doc/locationforecast/HowTO/).

Takes the heavy lifting out of creating a forecast like this:

![alt text](https://raw.githubusercontent.com/sasa-solutions/yr_weather/main/example.png)

Code is below.

## Terms of Service
YR are pretty permissive. There is a request for attribution, and a twenty requests per second rate limit. Before you get to far, please review [this](https://developer.yr.no/doc/TermsOfService/).

## Installation
Either add it to your Gemfile:
`gem 'yr_weather'`

And then `bundle install`.

Or: `bundle install yr_weather`

## Configuration
While YR don't require any registration or API keys, they do as that you provide a site name and email address. Specifically:
> the name of your website and some contact info (e.g. a GitHub URL, a non-personal email address, a working website or a mobile app store appname)

To this end, the gem will require at least an `@` symbol in the site name.

`/config/initializers/weather.rb`
```
YrWeather.config do |c|
  c.sitename   = '<the_name_of_your_website>;<an_email_address>'
  c.utc_offset = '+02:00'
  c.redis      = Redis.new(:host => 'localhost', :port => 6379)
end
```
`utc_offset` is optional, and is used to calculate the day start time.

If `redis` is configured, it will be used to cache the forecasts. If it is `nil` or omitted, the gem will cache data in the file system.
## Usage
```
parser = YrWeather.new(latitude: -33.953109, longitude: 18.480635)
pp parser.metadata
pp parser.current
pp parser.next_12_hours
pp parser.daily
pp parser.six_hourly
pp parser.three_days
pp parser.week
pp parser.arrays
```

Method|Description
--|--|
`metadata`|Returns a hash describing the forecast. It includes units, expiry times, and geographic detail.
`current`|Current meteorological conditions: temperature, wind speed, etc.
`next_12_hours`|Conditions over the next twelve hours.
`daily`|For the next week, per day, minima and maxima, maximum windspeeds, rainfall, etc.
`six_hourly`|Six hourly forecast detail.
`three_days`|Maximum and minimum temperature over the next three days, maximum windspeed, as well as cumulative forecast precipitation for those three days.
`week`|Maximum and minimum temperature over the next week, maximum windspeed, as well as cumulative forecast precipitation for the week.
`arrays`|A hash of six, equally sized, arrays: `at`, `temperature`, `wind_speed`, `wind_speed_knots`, `precipitation`, and `hours`. Use this data for graphing.
## Returned Values
You will generally get back hashes, with some or all of the following:
Parameter|Description
--|--|
`temperature_maximum`|Maximum temperature
`temperature_minimum`|Minimum temperature
`wind_speed_max`|Wind speed (meters per second)
`wind_speed_max_knots`|Wind speed (knots)
`wind_description`|A Beaufort scale descriptor: _Breezy_ or _hurricane force_. Human friendly.
`wind_direction`|`N`, `S`, `SE` etc. Will be the predominant wind direction for the period.
`precipitation`|How much it's going to rain in that period.
`from`, `to`, `at`|The range or time that this forecast, or forecast period, relates to.
`symbol_code`|Maps to an [icon](https://api.met.no/weatherapi/weathericon/2.0/documentation).

## Icons
YR provide a set of icons [here](https://api.met.no/weatherapi/weathericon/2.0/documentation).
## Caching
YR only run their model periodically. As such, there's no point in beating up their API's endlessly. The gem will cache results based on the "expires" guidance provided by their API servers.

The gem will either need to be able to write to Redis, or to the Linux temporary directory (internally, we call `Dir.tmpdir`).

## Dependencies
Requires a reasonably recent version of ruby. There are no other dependencies.
## Sample Code
To render the forecast as illustrated above:
```
<%
  @weather = YrWeather.new(latitude: @latitude, longitude: @longitude)
  current  = @weather.current
%>

  <div class="d-flex mb-4 ml-1">
    
    <div class="card h-120 mr-4">
      <div class="card-body">
        <h4 class="card-title">Current Conditions</h5>
        <div class="d-flex">
          <div><img src="/img/weather_icons/<%=current[:symbol_code]%>.svg" width="128" height="128" /></div>
          <div class="h2">
            <%=current[:air_temperature].round%><small class="text-muted">&deg;C</small><br/>
            <small class="text-muted"><%=current[:wind_direction]%></small> <%=current[:wind_speed].round%> <small class="text-muted">ms<sup>-1</sup> (<%=current[:wind_description]%>)</small><br/>
            <%=current[:precipitation_amount]%> <small class="text-muted">mm rain</small><br/>
          </div>
        </div>
      </div>
    </div>
    
    <div class="card h-120 mr-4">
      <div class="card-body">
        <h4 class="card-title">Three Day View</h5>
        <div class="d-flex">
          <div class="h2">
            High: <%=@weather.three_days[:temperature_maximum].round%><small class="text-muted">&deg;C</small><br/>
            Low: <%=@weather.three_days[:temperature_minimum].round%><small class="text-muted">&deg;C</small><br/>
            Max: <%=@weather.three_days[:wind_speed_max].round%> <small class="text-muted">ms<sup>-1</sup> mostly <%=@weather.three_days[:wind_direction]%></small><br/>
            Cumm: <%=@weather.three_days[:precipitation].round%> <small class="text-muted">mm rain</small><br/>
          </div>
        </div>
      </div>
    </div>
    
    <div class="card h-120">
      <div class="card-body">
        <h4 class="card-title">Week View</h5>
        <div class="d-flex">
          <div class="h2">
            High: <%=@weather.week[:temperature_maximum].round%><small class="text-muted">&deg;C</small><br/>
            Low: <%=@weather.week[:temperature_minimum].round%><small class="text-muted">&deg;C</small><br/>
            Max: <%=@weather.week[:wind_speed_max].round%> <small class="text-muted">ms<sup>-1</sup> mostly <%=@weather.week[:wind_direction]%></small><br/>
            Cumm: <%=@weather.week[:precipitation].round%> <small class="text-muted">mm rain</small><br/>
          </div>
        </div>
      </div>
    </div>

  </div>

  <div class="d-flex flex-wrap" >
    <% @weather.six_hourly.each do |forecast| %>
      <div class="mb-2 mr-2" style="width: 220px;">
        <div class="card h-100">
          <div class="card-body">
            <h5 class="card-title"><span data-format="ddd, HH:mm" class="time"><%=forecast[:from]%></span> to <span data-format="HH:mm" class="time"><%=forecast[:to]%></span></h5>
            <div class="d-flex">
              <div class="mr-2"><img src="/img/weather_icons/<%=forecast[:symbol_code]%>.svg" width="64" height="64" /></div>
              <p class="card-text">
                Max: <%=forecast[:temperature_maximum].round%><small class="text-muted">&deg;C</small><br/>
                <small class="text-muted"><%=forecast[:wind_direction]%></small> <%=forecast[:wind_speed_max]%> <small class="text-muted">ms<sup>-1</sup></small><br/>
                <%=forecast[:precipitation]%> <small class="text-muted">mm rain</small><br/>
              </p>
            </div>
          </div>
        </div>
      </div>
    <% end %>
  </div>
```
This code has dependencies on Bootstrap, as well as some JavaScript magic we use for formatting dates and times. But, hopefully you get a sense of what's involved in using the gem.

## Contributing
Please do! There's plenty that can be improved here!