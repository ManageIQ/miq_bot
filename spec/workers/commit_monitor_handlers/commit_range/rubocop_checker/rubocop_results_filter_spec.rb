require 'spec_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker::RubocopResultsFilter do
  describe "#filtered" do
    subject { described_class.new(rubocop_results, @diff_details) }

    before { |example| @example = example }

    it "with lines not in the diff" do
      @diff_details = {
        rubocop_check_path_file("example.rb").to_s => [4]
      }

      filtered = subject.filtered

      expect(filtered["files"].length).to eq(1)
      expect(filtered["files"][0]["offenses"].length).to eq(1)
      expect(filtered["files"][0]["offenses"][0]["line"]).to eq(4)

      expect(filtered["summary"]["offense_count"]).to eq(1)
    end

    it "with void warnings in spec files" do
      @diff_details = {
        rubocop_check_path_file("non_spec_file_with_void_warning.rb").to_s                  => [2],
        rubocop_check_path_file("spec/non_spec_file_in_spec_dir_with_void_warning.rb").to_s => [2],
        rubocop_check_path_file("spec/spec_file_with_void_warning_spec.rb").to_s            => [3]
      }

      filtered = subject.filtered

      expect(filtered["files"].length).to eq(3)
      expect(filtered["summary"]["offense_count"]).to eq(2)

      spec_file = filtered["files"].detect do |f|
        f["path"].include?("spec_file_with_void_warning_spec.rb")
      end
      expect(spec_file["offenses"]).to be_empty
    end

    it "with haml file using haml-lint" do
      @diff_details = {
        rubocop_check_path_file("example.haml").to_s => [4]
      }

      filtered = subject.filtered

      expect(filtered["files"].length).to eq(1)
      expect(filtered["files"][0]["offenses"].length).to eq(1)
      expect(filtered["files"][0]["offenses"][0]["line"]).to eq(3)

      expect(filtered["summary"]["offense_count"]).to eq(1)
    end
  end
end
