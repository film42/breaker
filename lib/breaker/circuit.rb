require "concurrent"

module Breaker
  class Circuit
    attr_reader :sampler, :state, :error_threshold_percentage

    REGISTRY = {}

    def self.register(name, options = {})
      REGISTRY[name.dup] = new(options)
    end

    def self.get_or_register(name, options = {})
      REGISTRY[name] || register(name, options)
    end

    def initialize(options)
      @error_threshold_percentage = options.fetch(:error_threshold_percentage, ::Breaker.config.error_threshold_percentage)
      @sampler = ::Breaker::Sampler::SlidingWindowSampler.new
      @state = :closed
    end

    def execute(options = {}, &block)
      update_state
      current_state = state
      return false if current_state == :open

      timeout_in_ms = options.fetch(:execution_timeout_in_milliseconds, ::Breaker.config.execution_timeout_in_milliseconds)
      timeout = timeout_in_ms / 1000.0
      execute_block(timeout, &block)
    ensure
      update_state
    end

  private

    class Result < ::Struct.new(:value, :error, :failed?); end

    def execute_block(timeout, &block)
      # HACK: This is a little heavy, but at least it's isolated for
      # future improvement ;).
      thread_pool = ::Concurrent::FixedThreadPool.new(1)
      future = ::Concurrent::Future.new(:executor => thread_pool, &block)
      future.execute

      value = nil
      if future.wait_or_cancel(timeout)
        # Only attempt a value call if we completed the execution.
        value = future.value unless future.rejected?
      end

      thread_pool.shutdown
      thread_pool.kill

      has_failed = future.completed?
      if has_failed
        sampler.increment_failure
      else
        sampler.increment_success
      end

      Result.new(value, future.reason, has_failed)
    end

    def next_circuit_timeout
      ::Time.now + (::Breaker.config.sleep_windown_in_milliseconds / 1000.0)
    end

    ##
    # State list:
    # - :closed
    # - :open
    # - :half_open
    #
    def update_state
      case state
      when :closed
        # Change state to open if we're over the max error rate.
        if sampler.percent_error > error_threshold_percentage
          @state = :open
          @circuit_timeout = next_circuit_timeout
        end

      when :open
        if ::Time.now > @circuit_timeout
          @state = :half_open
          @circuit_timeout = nil
          sampler.reset
        end

      when :half_open
        if sampler.data_point_count == 0
          # Do nothing, we haven't attempted an execution yet
        elsif sampler.totals[:failures] > 0
          # If we detect any failures after the last execution, we go
          # back to an open state.
          @state = :open
          @circuit_timeout = next_circuit_timeout
        else
          # We must have made a successful request. We can transition
          # back into a closed state.
          @state = :closed
        end

      end
    end

    ################
  end
end
