require "./habitat/*"

class Habitat
  class MissingSettingError < Exception
    def initialize(type, setting_name)
      super <<-ERROR
      The '#{setting_name}' setting for #{type} was nil, but the setting is required.

      Try this...

        #{type}.configure do
          settings.#{setting_name} = "some_value"
        end

      ERROR
    end
  end

  TYPES_WITH_HABITAT = [] of Nil

  macro track(type)
    {% TYPES_WITH_HABITAT << type %}
  end

  macro finished
    def self.raise_if_missing_settings!
      {% for type in TYPES_WITH_HABITAT %}
        {% for decl in type.constant(:HABITAT_SETTINGS) %}
          {% if !decl.type.is_a?(Union) ||
                  (decl.type.is_a?(Union) && !decl.type.types.map(&.id).includes?(Nil.id)) %}
            if {{ type }}.settings.{{ decl.var }}?.nil?
              raise MissingSettingError.new {{ type }}, setting_name: {{ decl.var.stringify }}
            end
          {% end %}
        {% end %}
      {% end %}
    end
  end

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
  # `create` adds class and instance `settings` methods to the embedding
  # class/module, which we'll use to set and get the values of our settings.
  #
  # ```
  # MyServer.settings.port = 80
  # MyServer.settings.port # 80
  # ```
  #
  # The settings assigned to a class will be inherited by its instances, but
  # can be overwritten with the `settings` setters.
  #
  # ```
  # server = MyServer.new
  # server.settings.port # 80
  # server.settings.port = 3000
  # server.settings.port # 3000
  # ```
  #
  # The settings assigned to a parent class will be inherited by its children
  # classes and can be overwritten with the `settings` setters.
  #
  # ```
  # class CustomServer < MyServer; end
  #
  # CustomServer.settings.port # 80
  # CustomServer.settings.port = 3000
  # CustomServer.settings.port # 3000
  # ```
  #
  # Assigning a value to a setting of incompatible type will result in an error
  # at compile time.
  #
  # ```
  # MyServer.settings.port = "80" # Compile-time error! An Int32 was expected
  # ```
  #
  # `create` also adds a `.configure` class method that takes a block where we
  # can use the `settings` setters.
  #
  # ```
  # MyServer.configure do
  #   settings.port = 80
  # end
  # ```
  macro create
    Habitat.track(\{{ @type }})

    include Habitat::TempConfig
    include Habitat::SettingsHelpers

    HABITAT_SETTINGS = [] of Crystal::Macros::TypeDeclaration

    def self.configure
      with self yield
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

  module SettingsHelpers
    macro setting(decl)
      {% HABITAT_SETTINGS << decl %}
    end

    macro inherit_habitat_settings_from_superclass
      {% if @type.superclass && @type.superclass.constant(:HABITAT_SETTINGS) %}
        {% for decl in @type.superclass.constant(:HABITAT_SETTINGS) %}
          {% HABITAT_SETTINGS << decl %}
        {% end %}
      {% end %}
    end
  end

  macro create_settings_methods(type_with_habitat)
    {% type_with_habitat = type_with_habitat.resolve %}

    class Settings
      {% if type_with_habitat.superclass && type_with_habitat.superclass.constant(:HABITAT_SETTINGS) %}
        {% for decl in type_with_habitat.superclass.constant(:HABITAT_SETTINGS) %}
          def self.{{ decl.var }}
            ::{{ type_with_habitat.superclass }}::Settings.{{ decl.var }}
          end
        {% end %}
      {% end %}

      {% for decl in type_with_habitat.constant(:HABITAT_SETTINGS) %}
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
