require 'spec_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker::RubocopResultsFilter do
  describe "#filtered" do
    let(:rubocop_check_directory) { example.description.gsub(" ", "_") }
    let(:rubocop_check_path) { File.join(File.dirname(__FILE__), "data", rubocop_check_directory) }
    let(:json_file) { File.join(rubocop_check_path, "results.json") }

    let(:rubocop_results) do
      # To regenerate the results.json files, just delete them
      File.write(json_file, `rubocop --format=json #{rubocop_check_path}`) unless File.exist?(json_file)
      JSON.parse(File.read(json_file))
    end

    subject { described_class.new(rubocop_results, @diff_details) }

    it "with lines not in the diff" do
      @diff_details = {
        Pathname.new(rubocop_check_path).join("example.rb").relative_path_from(Rails.root).to_s => [4]
      }

      filtered = subject.filtered

      expect(filtered["files"].length).to eq(1)
      expect(filtered["files"][0]["offenses"].length).to eq(1)
      expect(filtered["files"][0]["offenses"][0]["location"]["line"]).to eq(4)

      expect(filtered["summary"]["offense_count"]).to eq(1)
    end
  end
end
