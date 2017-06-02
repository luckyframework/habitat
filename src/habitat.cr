require "./habitat/*"

class Habitat
  REQUIRED_SETTINGS = [] of String

  macro finished
    def self.missing_settings?
      {% for setting in REQUIRED_SETTINGS %}
        return true if {{ setting.id }}.nil?
      {% end %}
      false
    end
  end

  macro create
    include Habitat::SettingHelpers

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

  module SettingHelpers
    macro setting(decl)
      class Settings
        @@{{ decl.var }} : {{decl.type}} | Nil {% if decl.value %} = {{ decl.value }}{% end %}
        {% Habitat::REQUIRED_SETTINGS << "#{@type}.settings.#{decl.var}?" %}

        def self.{{ decl.var }}=(value : {{ decl.type }})
          @@{{ decl.var }} = value
        end

        def self.{{ decl.var }}
          @@{{ decl.var }}.not_nil!
        end

        def self.{{ decl.var }}?
          @@{{ decl.var }}
        end
      end
    end
  end
end
