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

  # :nodoc:
  class InvalidSettingFormatError < Exception
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

  # Raise the `message` passed in.
  def self.raise_validation_error(message : String)
    raise InvalidSettingFormatError.new(message)
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
  #
  # Each setting can take an optional `validation` argument to ensure the setting
  # value matches a specific format.
  #
  # ```
  # class MyMachine
  #   Habitat.create do
  #     setting pin : String, validation: :pin_format
  #   end
  #
  #   def self.pin_format(value : String)
  #     value.match(/^\d{4}/) || Habitat.raise_validation_error("Your PIN must be exactly 4 digits")
  #   end
  # end
  # ```
  #
  # Even though the type is correct, this will now raise an error because the format doesn't match
  # ```
  # MyMachine.configure do |settings|
  #   settings.pin = "abcd"
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

    class HabitatSettings
    end

    def self.settings
      HabitatSettings
    end

    def settings
      HabitatSettings
    end

    {{ yield }}

    # inherit_habitat_settings_from_superclass

    macro finished
      Habitat.create_settings_methods(\{{ @type }})
    end
  end

  macro extend
    macro validate_create_setup_first(type)
      \{% if !type.has_constant? "HABITAT_SETTINGS" %}
        \{% raise <<-ERROR
          No create block was specified for #{type}.
          Habitat must be created before you can extend it.

          Example:
            Habitat.create do
              setting id : Int64
              ...
            end
          ERROR
        %}
      \{% end %}
    end

    validate_create_setup_first(\{{ @type }})

    include Habitat::TempConfig
    include Habitat::SettingsHelpers

    {{ yield }}
  end

  # :nodoc:
  module SettingsHelpers
    macro setting(decl, example = nil, validation = nil)
      {% if decl.var.stringify.ends_with?('?') %}
        {% decl.raise <<-ERROR
        You cannot define a setting ending with '?'. Found #{decl.var} defined in #{@type}.

        Habitat already has a predicate method #{decl.var} used when checking for missing settings.
        ERROR
        %}
      {% end %}
      {% HABITAT_SETTINGS << {decl: decl, example: example, validation: validation} %}
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

    class HabitatSettings
      {% if type_with_habitat.superclass && type_with_habitat.superclass.type_vars.size == 0 && type_with_habitat.superclass.constant(:HABITAT_SETTINGS) %}
        {% for decl in type_with_habitat.superclass.constant(:HABITAT_SETTINGS).map { |setting| setting[:decl] } %}
          def self.{{ decl.var }}
            ::{{ type_with_habitat.superclass }}::HabitatSettings.{{ decl.var }}
          end
        {% end %}
      {% end %}

      {% for opt in type_with_habitat.constant(:HABITAT_SETTINGS) %}
        {% decl = opt[:decl] %}
        # NOTE: We can't use the macro level `type.resolve.nilable?` here because
        # there's a few declaration types that don't respond to it which would make the logic
        # more complex. Metaclass, and Proc types are the main, but there may be more.
        {% if decl.type.is_a?(Union) && decl.type.types.map(&.id).includes?(Nil.id) %}
          {% nilable = true %}
        {% else %}
          {% nilable = false %}
        {% end %}


        {% has_default = decl.value || decl.value == false %}

        # Use `begin` to catch if the default value raises an exception,
        # then raise a MissingSettingError
        @@{{ decl.var }} : {{decl.type}} | Nil {% if has_default %} = begin
          {{ decl.value }}
        rescue
          # This will cause a MissingSettingError to be raised
          nil
        end
        {% end %}


        def self.{{ decl.var }}=(value : {{ decl.type }})
          {% if opt[:validation] %}
          {{ type_with_habitat }}.{{ opt[:validation].id }}(value)
          {% end %}
          @@{{ decl.var }} = value
        end

        def self.{{ decl.var }} : {{ decl.type }}
          @@{{ decl.var }}{% if !nilable %}.not_nil!{% end %}
        end

        # Used for checking missing settings on non-nilable types
        # It's advised to use {{ decl.var }} in your apps to ensure
        # the propper type is checked.
        def self.{{ decl.var }}?
          @@{{ decl.var }}
        end
      {% end %}

      # Generates a hash using the provided values
      def self.to_h
        {
          {% for decl in type_with_habitat.constant(:HABITAT_SETTINGS).map(&.[:decl]) %}
            {{ decl.var.stringify }} => {{ decl.var }},
          {% end %}
        }
      end
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
