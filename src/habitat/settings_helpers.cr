class Habitat
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
end
