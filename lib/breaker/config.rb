module Breaker
  class Config
    attr_accessor :error_threshold_percentage,
                  :execution_timeout_in_milliseconds,
                  :minimum_sample_size,
                  :rolling_statistical_windown_in_milliseconds,
                  :sleep_windown_in_milliseconds

    DEFAULT_OPTIONS = {
      :error_threshold_percentage => 0.5,
      :execution_timeout_in_milliseconds => 60_000,
      :minimum_sample_size => 5,
      :rolling_statistical_windown_in_milliseconds => 10_000,
      :sleep_windown_in_milliseconds => 5_000,
    }

    def initialize(options = {})
      config_options = DEFAULT_OPTIONS.merge(options)
      assign_config_options(config_options)
    end

  private

    def assign_config_options(options)
      options.each do |attribute, value|
        __send__("#{attribute}=", value)
      end
    end
  end
end
