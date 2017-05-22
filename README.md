# habitat
Easily configure settings for Crystal projects

_No code yet. This is here to give me an idea of what I want the library to do._

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
```
