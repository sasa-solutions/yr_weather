
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|

  spec.name          = "yr_parser"
  spec.version       = '0.1.0'
  spec.date          = '2021-01-25'
  spec.licenses      = ['MIT']

  spec.authors       = ["renen"]
  spec.email         = ["renen@121.co.za"]

  spec.summary       = 'This gem leverages yr.no to convert location data into hourly forecasts, and summaries that are simpler to understand, and easy to script into databases and systems.'
  spec.homepage      = 'https://github.com/sasa-solutions/yr_parser'

  spec.files = ['lib/yr_parser.rb']

end
