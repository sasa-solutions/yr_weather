
# yr_parser

## TL;DR
This gem yr.no forecasts into daily and hourly forecasts, and as well as into summaries that are simpler to understand, and easy to script into databases and other systems.

yr.no forecasts include point-in-time forecasts (for, for example, temperature), and forecasts that relate to a time range (for, for example, precipitation).

## Installation
Either add it to your Gemfile:
`gem 'yr_parser'` and then `bundle install`.

Or,
`bundle install yr_parser`

## Usage
```
irb(main):001:0> require 'yr_parser'
=> true
irb(main):002:0> YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:today]
=> {:precipitation=>0.0, :min_temperature=>19.3, :max_temperature=>25.5, :max_wind_speed=>6.7, :wind_direction=>"S"}
```
You can also ask it for `tomorrow`: `YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:tomorrow]`

And, you can ask it about the weather over the coming three days (or week): 
```
YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:three_days]
=> {:precipitation=>0.2, :min_temperature=>17.6, :max_temperature=>25.5, :max_wind_speed=>9.2}
```
This tells us that the maximum temperature over the next three days will be `25.5`, the maximum wind speed will be 9.2m/s, and we should expect 0.2mm of rain at some point.
## Caching
YR only run their model periodically. As such, there's no point in beating up their API's endlessly. In our environments, we cache the result and use the cached forecast until YR are scheduled to update it. The metadata returned by yr_parser helps with that:
```
YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:metadata][:seconds_to_cache]
=> 17234
```
Other metadata includes when this forecast was downloaded and generated:
```
YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:metadata]
=> {:requested_at=>2021-01-25 14:52:57 +0000, :next_run_at=>2021-01-25 19:23:55 UTC, :model_generated_at=>2021-01-25 13:18:53 UTC, :seconds_to_cache=>17156}
```
Within our code, requests are managed as follows:
```
      forecast = $redis.get(redis_key)
      if forecast.nil?
        forecast = YrParser.get(latitude: @latitude, longitude: @longitude)
        $redis.set(redis_key, forecast, ex: forecast[:metadata][:seconds_to_cache])
      end
      forecast
```

## Detailed Parameters
The script returns A JSON structure as follows:
Node|Description|Type
-|-|-
`today`|Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`,`wind_direction`|Object
`tomorrow`|Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`,`wind_direction`|Object
`three_days`|Summary data detailing weather over the next three days. Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`|Object
`week`|Summary data detailing weather over the next seven days. Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`|Object
`hourly`|Object with five nodes: `from_time`, `temperatures`, `wind_speed`, `wind_direction`, `precipitation`. These nodes contain equally sized arrays which list times, temperatures etc that match the hour starting at the corresponding `from_time` entry.|Object
`daily`|Object with five nodes: `from_time`, `temperatures`, `wind_speed`, `wind_direction`, `precipitation`. These nodes contain equally sized arrays which list times, temperatures etc that match the day starting at the corresponding `from_time` value.|Object

A detailed exploration and unit definitions can be found in "Detailed Outputs" below. Or install and play with the gem - its probably more intuitive than wading through this document!

### Parameters
Parameter|Detail|Required?|Type|Default
---|---|--|--|--
latitude|Latitude|Required|Float|
longitude|Longitude|Required|Float|
msl|Altitude|Optional|Integer|0
utc_offset|Timezone offset. For example: +2:00. It is *vital* that this offset includes a colon, as illustrated.|Optional|String|Defaults to local system.

Latitude, longitude and MSL are passed transparently through to YR. MSL *mean sea level* (I think), seems optional on YR's side.

## Dependencies
Requires a reasonably recent version of ruby. There are no other dependencies.

## Context
Even before Cape Town's water crisis, I got grumpy when my irrigation system watered the garden when it was raining. Or going to rain. Or watered the lawn when the wind was blowing. This lead to me building an Arduino-based, network driven switch system (the code is [here](https://github.com/renenw/harduino/blob/master/switch/switch.ino)). 

Making sure that the irrigation doesn't turn on today when its going to bucket tomorrow, obviously, requires a weather forecast. And by far the most accurate forecast for my hood is the forecast provided by the Norwegian weather service.

However, their API isn't the simplest to understand. And I missed their documentation - if it exists.

I built a script that provides the necessary guidance to my irrigation system. And then, subsequently, migrated the script to this gem. The README in [here](https://github.com/renenw/yr_parser) details my analysis and exploration.