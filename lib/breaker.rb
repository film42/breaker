require "breaker/version"

require "breaker/config"
require "breaker/circuit"
require "breaker/sampler/sliding_window_sampler"

module Breaker
  CONFIG_MUTEX = ::Mutex.new

  def self.config(&block)
    CONFIG_MUTEX.synchronize do
      @config = ::Breaker::Config.new(&block)
    end
  end

  config
end
