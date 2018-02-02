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
        {% for type_declaration in type.constant(:REQUIRED_SETTINGS) %}
          if {{ type }}.settings.{{ type_declaration.var }}?.nil?
            raise MissingSettingError.new {{ type }}, setting_name: {{ type_declaration.var.stringify }}
          end
        {% end %}
      {% end %}
    end
  end

  macro create
    include Habitat::SettingHelpers
    include Habitat::TempConfig
    Habitat.track(\{{ @type }})

    REQUIRED_SETTINGS = [] of TypeDeclaration

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

  module SettingHelpers
    macro setting(decl)
      {% if decl.type.is_a?(Union) && decl.type.types.map(&.id).includes?(Nil.id) %}
        {% nilable = true %}
      {% else %}
        {% nilable = false %}
        {% REQUIRED_SETTINGS << decl %}
      {% end %}

      class Settings
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
      end
    end
  end
end
