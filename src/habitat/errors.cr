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
end
