# Habitat

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
  end

  # Access them like this
  def start
    start_server_on port: settings.port
  end
end

MyServer.configure do
  settings.port = 8080
end

# At the very end of your program use this
# It will raise if you forgot to set any settings
Habitat.raise_if_missing_settings!
```

## Contributing

1. Fork it ( https://github.com/luckyframework/habitat/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [paulcsmith](https://github.com/paulcsmith) Paul Smith - creator, maintainer
