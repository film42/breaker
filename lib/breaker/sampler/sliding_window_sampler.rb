require "time"

module Breaker
  module Sampler
    class SlidingWindowSampler
      attr_reader :window_size_in_milliseconds, :current_frame, :frames, :next_frame_at, :totals

      MINIMUM_FRAME_SIZE_IN_MILLISECONDS = 100
      MINIMUM_FRAME_SIZE_IN_SECONDS = (MINIMUM_FRAME_SIZE_IN_MILLISECONDS / 1000.0)

      def initialize(options = {})
        @window_size_in_milliseconds = options.fetch(:window_size_in_milliseconds)

        reset
      end

      def data_point_count
        totals[:failures] + totals[:successes]
      end

      ##
      # Types: :success, :failure
      #
      def increment(type)
        prune_frames

        case type
        when :success
          current_frame[:successes] += 1
          totals[:successes] += 1
        when :failure
          current_frame[:failures] += 1
          totals[:failures] += 1
        end
      end

      def increment_success
        increment(:success)
      end

      def increment_failure
        increment(:failure)
      end

      def percent_error
        failures = totals[:failures]
        total = data_point_count.to_f

        return 0.0 if total == 0

        failures / total
      end

      def percent_success
        1.0 - percent_error
      end

      def reset
        @next_frame_at = ::Time.now + MINIMUM_FRAME_SIZE_IN_SECONDS
        @current_frame = new_frame
        @frames = [current_frame]
        @totals = { :successes => 0, :failures => 0 }
      end

    private

      def new_frame
        {
          :started_at => ::Time.now,
          :successes => 0,
          :failures => 0
        }
      end

      def prune_frames
        current_time = ::Time.now
        return unless next_frame_at <= current_time

        # Advance the next frame create time into the future
        seconds_to_advance = (current_time - next_frame_at).to_i
        @next_frame_at += seconds_to_advance

        # Ensure that we look into the future if we're exactly on a
        # time boundary.
        if next_frame_at <= current_time
          @next_frame_at += seconds_to_advance * MINIMUM_FRAME_SIZE_IN_SECONDS
        end

        # Drop old frames
        maximum_age = ::Time.now - window_size_in_seconds
        while !frames.empty? && frames.first[:started_at] < maximum_age
          frame = frames.shift

          # Remove the frame quantity from the totals.
          totals[:failures] -= frame[:failures]
          totals[:successes] -= frame[:successes]
        end

        # Create a new frame because we've past the last point
        @current_frame = new_frame
        frames << current_frame
      end

      def window_size_in_seconds
        window_size_in_milliseconds / 1000.0
      end
    end
  end
end
