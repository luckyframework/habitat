require "./habitat/*"

class Habitat
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
                (setting[:decl].type.is_a?(Union) && !setting[:decl].type.types.any? { |t| t.is_a?(ProcNotation) ? false : t.names.includes?(Nil.id) }) %}
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

  # Extend an existing Habitat config with additional
  # settings. Can be used if a shard sets a config, and
  # and you need additional properties to extend the shard.
  #
  # ```
  # class IoT
  #   Habitat.create do
  #     setting name : String
  #   end
  # end
  #
  # class IoT
  #   Habitat.extend do
  #     setting uuid : UUID
  #   end
  # end
  #
  # IoT.configure do |settings|
  #   settings.name = "plug"
  #   settings.uuid = UUID.random
  # end
  # ```
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
        {% if decl.type.is_a?(Union) && decl.type.types.any? { |t| t.is_a?(ProcNotation) ? false : t.names.includes?(Nil.id) } %}
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
end
