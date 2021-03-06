# Habitat

[![API Documentation Website](https://img.shields.io/website?down_color=red&down_message=Offline&label=API%20Documentation&up_message=Online&url=https%3A%2F%2Fluckyframework.github.io%2Fhabitat%2F)](https://luckyframework.github.io/habitat)

Easily configure settings for Crystal projects

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  habitat:
    github: luckyframework/habitat
```

## Usage

```crystal
require "habitat"
```

```crystal
class MyServer
  Habitat.create do
    setting port : Int32
    setting debug_errors : Bool = true

    # Optionally add examples to settings that appear in error messages
    # when the value is not set.
    #
    # Use `String#dump` when you want the example to be wrapped in quotes
    setting host : String, example: "127.0.0.1".dump
    setting logger : Logger, example: "Logger.new(STDOUT)"

    # If you need the value to match a specific format, you can create
    # your own validation.
    setting protocol : String, validation: :validate_protocol
  end

  # Read more on validations below
  def self.validate_protocol(value : String)
    value.match(/^http(?:s)*:$/) || Habitat.raise_validation_error("The protocol must be `http:` or `https:`.")
  end

  # Access them with the `settings` method like this.
  def start
    start_server_on port: settings.port
  end
end

# Configure your settings
MyServer.configure do |settings|
  settings.port = 8080
end

# At the very end of your program use this
# It will raise if you forgot to set any settings
Habitat.raise_if_missing_settings!
```

Settings can also be accessed from outside the class:

```crystal
port = MyServer.settings.port
puts "The server is starting on port #{port}"
```

### Setting validations

The `validation` option takes a Symbol which matches a class method
that will run your custom validation. This can be useful if your
setting needs to be in a specific format like maybe a 4 digit code
that can start with a 0.

```crystal
class Secret
  Habitat.create do
    setting code : String, validation: :validate_code
  end

  # The validation method will take an argument of the same type.
  # If your setting is `Int32`, then this argument will also be `Int32`.
  #
  # Use any method of validation you'd like here. (i.e. regex, other custom methods, etc...)
  # If your validation fails, you can call `Habitat.raise_validation_error` with your custom error
  # message
  def self.validate_code(value : String)
    value.match(/^\d{4}$/) || Habitat.raise_validation_error("Be sure the code is only 4 digits")
  end
end

Secret.configure do |settings|

  # Even though the code is the correct type, this will still
  # raise an error for us.
  settings.code = "ABCD"

  # This value will pass our validation
  settings.code = "0123"
end
```

### Temp Config

There are some cases in which you may want to temporarily change a setting value. (i.e. specs, one off jobs, etc...)

Habitat comes with a built-in method `temp_config` that allows you to do this:

```crystal
class Server
  Habitat.create do
    setting hostname : String
  end
end

Server.configure do |settings|
  settings.hostname = "localhost"
end

Server.settings.hostname #=> "localhost"

Server.temp_config(hostname: "fancyhost.com") do
  # This seting affects the value globally while inside this block
  Server.settings.hostname #=> "fancyhost.com"
end

# Once the block exits, the original value is returned
Server.settings.hostname #=> "localhost"
```

## Contributing

1. Fork it ( https://github.com/luckyframework/habitat/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [paulcsmith](https://github.com/paulcsmith) Paul Smith - creator, maintainer
