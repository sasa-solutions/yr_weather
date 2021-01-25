
# yr_parser

## TL;DR
This gem yr.no forecasts into daily and hourly forecasts, and as well as into summaries that are simpler to understand, and easy to script into databases and other systems.

yr.no forecasts include point-in-time forecasts (for, for example, temperature), and forecasts that relate to a time range (for, for example, precipitation).

## Installation
Either add it to your Gemfile:
`gem 'yr_parser'`

Or,
`bundle install yr_parser`

## Usage
```
irb(main):001:0> require 'yr_parser'
=> true
irb(main):002:0> YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)[:today]
=> {:precipitation=>0.0, :min_temperature=>19.3, :max_temperature=>25.5, :max_wind_speed=>6.7, :wind_direction=>"S"}

```
### What is returned?
The script returns A JSON structure as follows:
Node|Description|Type
-|-|-
`today`|Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`|Object
`three_days`|Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`|Object
`week`|Value only nodes: `precipitation`, `min_temperature`, `max_temperature`, `max_wind_speed`|Object
`hourly`|Object with five nodes: `from_time`, `temperatures`, `wind_speed`, `wind_direction`, `precipitation`. These nodes contain equally sized arrays which list times, temperatures etc that match the hour starting at the corresponding `from_time` entry.|Object
`daily`|Object with five nodes: `from_time`, `temperatures`, `wind_speed`, `wind_direction`, `precipitation`. These nodes contain equally sized arrays which list times, temperatures etc that match the hour starting at the corresponding `from_time` entry.|Object

A detailed exploration and unit definitions can be found in "Detailed Outputs" below. Or install and play with the gem - its probably more intuitive than wading through this document!

### Parameters
Parameter|Detail|Required?|Type|Default
---|---|--|--|--|--
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

I built a script that provides the necessary guidance to my irrigation system. And then, subsequently, migrated the script to this gem. The README in that  repo details my analysis and exploration.