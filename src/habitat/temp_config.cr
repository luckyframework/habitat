class Habitat
  module TempConfig
    # Temporarily changes the configuration
    #
    # This method will change the configuration to the passed in value for the
    # duration of the block. When the block is finished running, Habitat will
    # then reset to the value before the block
    #
    # ```
    # MyServer.configure do |settings|
    #   settings.port = 80
    # end
    #
    # MyServer.settings.port # 80
    #
    # MyServer.temp_config(port: 3000) do
    #   MyServer.settings.port # 3000
    # end
    #
    # MyServer.settings.port # 80
    # ```
    #
    # This can be very helpful when writing specs and you need to temporarily
    # change a value
    macro temp_config(**settings_with_values)
      {% for setting_name, setting_value in settings_with_values %}
        original_{{ setting_name }} = {{ @type.name }}.settings.{{setting_name}}
        {{ @type.name }}.settings.{{ setting_name }} = {{ setting_value }}
      {% end %}

      {{ yield }}

      {% for setting_name, _unused in settings_with_values %}
        {{ @type.name }}.settings.{{ setting_name }} = original_{{ setting_name }}
      {% end %}
    end
  end
end
