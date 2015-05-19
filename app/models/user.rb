class User < ActiveRecord::Base
  serialize :preferences

  before_save do
    preferences.each do |key, value|
      case key
      when Preference::BOOLEAN_FIELD_REGEXP
        if !value.is_a?(TrueClass) && !value.is_a?(FalseClass)
          if %w(true 1).include?(value)
            preferences[key] = true
          else
            preferences[key] = false
          end
        end
      end
    end
  end
end
