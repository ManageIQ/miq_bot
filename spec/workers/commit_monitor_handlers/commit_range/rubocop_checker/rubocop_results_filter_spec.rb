require 'spec_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker::RubocopResultsFilter do
  describe "#filtered" do
    subject { described_class.new(rubocop_results, @diff_details) }

    it "with lines not in the diff" do
      @diff_details = {
        rubocop_check_path_file("example.rb").to_s => [4]
      }

      filtered = subject.filtered

      expect(filtered["files"].length).to eq(1)
      expect(filtered["files"][0]["offenses"].length).to eq(1)
      expect(filtered["files"][0]["offenses"][0]["location"]["line"]).to eq(4)

      expect(filtered["summary"]["offense_count"]).to eq(1)
    end
  end
end
