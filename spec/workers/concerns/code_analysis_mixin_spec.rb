describe CodeAnalysisMixin do
  let(:example_rubocop_result) { {"metadata" => {"rubocop_version" => "0.47.1", "ruby_engine" => "ruby", "ruby_version" => "2.3.3", "ruby_patchlevel" => "222", "ruby_platform" => "x86_64-linux"}, "files" => [{"path" => "app/helpers/application_helper/button/mixins/discovery_mixin.rb", "offenses" => []}, {"path" => "app/helpers/application_helper/button/button_new_discover.rb", "offenses" => [{"severity" => "warning", "message" => "Method `ApplicationHelper::Button::ButtonNewDiscover#visible?` is defined at both /tmp/d20171201-9050-1m4n90/app/helpers/application_helper/button/button_new_discover.rb:5 and /tmp/d20171201-9050-1m4n90/app/helpers/application_helper/button/button_new_discover.rb:9.", "cop_name" => "Lint/DuplicateMethods", "corrected" => nil, "location" => {"line" => 9, "column" => 3, "length" => 3}}]}], "summary" => {"offense_count" => 1, "target_file_count" => 2, "inspected_file_count" => 2}} }
  let(:test_class) do
    Class.new do
      include CodeAnalysisMixin
      attr_reader :branch
    end
  end
  subject { test_class.new }

  context "#merged_linter_results" do
    it "should always return a hash with a 'files' and 'summary' key, even with no cops running" do
      expect(Linter::Rubocop).to receive(:new).and_return(double(:run => nil))
      expect(Linter::Haml).to receive(:new).and_return(double(:run => nil))
      expect(Linter::Yaml).to receive(:new).and_return(double(:run => nil))

      expect(subject.merged_linter_results).to eq("files" => [], "summary" => {"inspected_file_count" => 0, "offense_count" => 0, "target_file_count" => 0})
    end

    it "merges together with one result" do
      expect(Linter::Rubocop).to receive(:new).and_return(double(:run => example_rubocop_result))
      expect(Linter::Haml).to receive(:new).and_return(double(:run => nil))
      expect(Linter::Yaml).to receive(:new).and_return(double(:run => nil))

      expect(subject.merged_linter_results).to eq(
        "files"   => example_rubocop_result["files"],
        "summary" => {"inspected_file_count" => 2, "offense_count" => 1, "target_file_count" => 2}
      )
    end

    it "merges together with one result" do
      expect(Linter::Rubocop).to receive(:new).and_return(double(:run => example_rubocop_result))
      expect(Linter::Haml).to receive(:new).and_return(double(:run => example_rubocop_result))
      expect(Linter::Yaml).to receive(:new).and_return(double(:run => nil))

      results = subject.merged_linter_results
      expect(results["files"]).to include(*example_rubocop_result["files"])
      expect(results["summary"]).to eq("inspected_file_count" => 4, "offense_count" => 2, "target_file_count" => 4)
    end
  end
end
