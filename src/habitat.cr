require "./habitat/*"

class Habitat
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

        def self.{{ decl.var }}=(value : {{ decl.type }})
          @@{{ decl.var }} = value
        end

        def self.{{ decl.var }}
          @@{{ decl.var }}.not_nil!
        end
      end
    end
  end
end
