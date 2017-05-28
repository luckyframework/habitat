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
    macro setting(type_declaration)
      class Settings
        # TODO: Allow nil and check types at the end
        @@port = 8080808
        class_property {{ type_declaration }}
      end
    end
  end
end
