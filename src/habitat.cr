require "./habitat/*"

class Habitat
  # :nodoc:
  class MissingSettingError < Exception
    def initialize(type, setting_name, example)
      example ||= "some_value"
      super <<-ERROR
      The '#{setting_name}' setting for #{type} was nil, but the setting is required.

      Try this...

        #{type}.configure do |settings|
          settings.#{setting_name} = #{example}
        end

      ERROR
    end
  end

  TYPES_WITH_HABITAT = [] of Nil

  # :nodoc:
  macro track(type)
    {% TYPES_WITH_HABITAT << type %}
  end

  # :nodoc:
  macro finished
    # Raises an error when a required setting is missing.
    #
    # Raises a `Habitat::MissingSettingError` if a required setting hasn't been
    # set. We recommend that you call it at the very end of your program.
    #
    # ```
    # class YourClass
    #   Habitat.create do
    #     # ...
    #   end
    # end
    #
    # YourClass.configure do |settings|
    #   # ...
    # end
    #
    # # ...your main program ends here.
    #
    # Habitat.raise_if_missing_settings!
    # ```
    def self.raise_if_missing_settings!
      {% for type in TYPES_WITH_HABITAT %}
        {% for setting in type.constant(:HABITAT_SETTINGS) %}
          {% if !setting[:decl].type.is_a?(Union) ||
                  (setting[:decl].type.is_a?(Union) && !setting[:decl].type.types.map(&.id).includes?(Nil.id)) %}
            if {{ type }}.settings.{{ setting[:decl].var }}?.nil?
              raise MissingSettingError.new {{ type }}, setting_name: {{ setting[:decl].var.stringify }}, example: {{ setting[:example] }}
            end
          {% end %}
        {% end %}
      {% end %}
    end
  end

  # Embed settings in a Class or Module.
  #
  # A class or module can call `Habitat.create` with a block of `setting` calls
  # that will declare the types (and optionally default values) of our settings.
  #
  # ```
  # class MyServer
  #   Habitat.create do
  #     setting port : Int32
  #     setting debug_errors : Bool = true
  #   end
  # end
  # ```
  #
  # `create` adds a `.configure` class method that takes a block where we
  # can use the `settings` setters.
  #
  # ```
  # MyServer.configure do
  #   settings.port = 80
  #   settings.debug_errors = false
  # end
  # ```
  #
  # `create` also adds class and instance `settings` methods to the embedding
  # class/module, which we'll use to get the values of our settings.
  #
  # ```
  # MyServer.configure do |settings|
  #   settings.port = 80
  # end
  #
  # MyServer.settings.port # 80
  #
  # # In an instance method
  # class MyServer
  #   def what_is_the_port
  #     settings.port # 80
  #   end
  # end
  # ```
  #
  # The settings assigned to a parent class will be inherited by its children
  # classes.
  #
  # ```
  # class CustomServer < MyServer; end
  #
  # MyServer.configure do |settings|
  #   settings.port = 3000
  # end
  #
  # CustomServer.settings.port # 3000
  # ```
  #
  # Assigning a value to a setting of incompatible type will result in an error
  # at compile time.
  #
  # ```
  # MyServer.configure do |settings|
  #   settings.port = "80" # Compile-time error! An Int32 was expected
  # end
  # ```
  macro create
    Habitat.track(\{{ @type }})

    include Habitat::TempConfig
    include Habitat::SettingsHelpers

    HABITAT_SETTINGS = [] of Nil

    def self.configure
      yield settings
    end

    class Settings
    end

    def self.settings
      Settings
    end

    def settings
      Settings
    end

    {{ yield }}

    # inherit_habitat_settings_from_superclass

    macro finished
      Habitat.create_settings_methods(\{{ @type }})
    end
  end

  # :nodoc:
  module SettingsHelpers
    macro setting(decl, example = nil)
      {% HABITAT_SETTINGS << {decl: decl, example: example} %}
    end

    macro inherit_habitat_settings_from_superclass
      {% if @type.superclass && @type.superclass.type_vars.size == 0 && @type.superclass.constant(:HABITAT_SETTINGS) %}
        {% for decl in @type.superclass.constant(:HABITAT_SETTINGS) %}
          {% HABITAT_SETTINGS << decl %}
        {% end %}
      {% end %}
    end
  end

  # :nodoc:
  macro create_settings_methods(type_with_habitat)
    {% type_with_habitat = type_with_habitat.resolve %}

    class Settings
      {% if type_with_habitat.superclass && type_with_habitat.superclass.type_vars.size == 0 && type_with_habitat.superclass.constant(:HABITAT_SETTINGS) %}
        {% for decl in type_with_habitat.superclass.constant(:HABITAT_SETTINGS).map { |setting| setting[:decl] } %}
          def self.{{ decl.var }}
            ::{{ type_with_habitat.superclass }}::Settings.{{ decl.var }}
          end
        {% end %}
      {% end %}

      {% for decl in type_with_habitat.constant(:HABITAT_SETTINGS).map(&.[:decl]) %}
        {% if decl.type.is_a?(Union) && decl.type.types.map(&.id).includes?(Nil.id) %}
          {% nilable = true %}
        {% else %}
          {% nilable = false %}
        {% end %}

        {% has_default = decl.value || decl.value == false %}
        @@{{ decl.var }} : {{decl.type}} | Nil {% if has_default %} = {{ decl.value }}{% end %}

        def self.{{ decl.var }}=(value : {{ decl.type }})
          @@{{ decl.var }} = value
        end

        def self.{{ decl.var }}
          @@{{ decl.var }}{% if !nilable %}.not_nil!{% end %}
        end

        def self.{{ decl.var }}?
          @@{{ decl.var }}
        end
      {% end %}
    end
  end

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
