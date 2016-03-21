require "spec_helper"

describe ::Breaker::Sampler::SlidingWindowSampler do

  def increment_time(seconds = 0)
    # HACK: Get the time to be the same down to the millisecond level.
    allow(::Time).to receive(:now).and_return(::Time.now + seconds)
  end

  subject { described_class.new(:window_size_in_milliseconds => window_size_in_milliseconds) }

  let(:window_size_in_milliseconds) { 1_000 }

  describe ".new" do
    it "sets the window size in ms" do
      expect(subject.window_size_in_milliseconds).to eq(window_size_in_milliseconds)
    end

    it "sets the current frame" do
      expect(subject.current_frame).to_not be_nil
    end

    it "creates a frames array" do
      expect(subject.frames).to eq([subject.current_frame])
    end

    it "calculates the next frame time" do
      increment_time
      expect(subject.next_frame_at).to eq(::Time.now + 0.1)
    end
  end

  describe "#data_point_count" do
    it "counts the total points" do
      subject.increment_success
      subject.increment(:failure)
      expect(subject.data_point_count).to eq(2)
    end
  end

  describe "#increment_failure" do
    it "calls increment with :failure" do
      expect(subject).to receive(:increment).with(:failure)
      subject.increment_failure
    end
  end

  describe "#increment_success" do
    it "calls increment with :success" do
      expect(subject).to receive(:increment).with(:success)
      subject.increment_success
    end
  end

  describe "#increment" do
    it "updates the totals" do
      subject.increment_success
      subject.increment_failure

      expect(subject.current_frame[:successes]).to eq(1)
      expect(subject.totals).to eq({ :successes => 1, :failures => 1 })
    end

    context "when frames are pruned" do
      before do
        # Add three frames.
        increment_time
        subject.increment_success
        expect(subject.current_frame[:successes]).to eq(1)
        increment_time(0.1)
        subject.increment_success
        expect(subject.current_frame[:successes]).to eq(1)
        increment_time(0.1)
        subject.increment_success
        expect(subject.current_frame[:successes]).to eq(1)
        expect(subject.totals[:successes]).to eq(3)
      end

      it "subtracts the success/ failures from the totals" do
        expect(subject.totals[:successes]).to eq(3)
        increment_time(0.9)
        subject.increment_success
        expect(subject.totals[:successes]).to eq(2)
      end

      it "deletes all frames older than the threshold" do
        increment_time(0.9)
        subject.increment_success
        expect(subject.totals[:successes]).to eq(2)
        expect(subject.frames.size).to eq(2)
      end

      it "can look really far into the future quickly" do
        increment_time(10_000)
        subject.increment_success
        expect(subject.totals[:successes]).to eq(1)
        expect(subject.frames.size).to eq(1)
      end
    end
  end


  describe "#percent_error" do
    it "returns 0% when there are no data points" do
      expect(subject.percent_error).to eq(0)
    end

    it "correctly calculates the error rate" do
      subject.increment_success
      subject.increment_success
      subject.increment_success
      subject.increment(:failure)
      expect(subject.percent_error).to eq(0.25)
    end
  end

  describe "#percent_success" do
    it "returns 100% when there are no data points" do
      expect(subject.percent_success).to eq(1)
    end

    it "correctly calculates the error rate" do
      subject.increment_success
      subject.increment_success
      subject.increment_success
      subject.increment_failure
      expect(subject.percent_success).to eq(0.75)
    end
  end
end
