describe CodeAnalysisMixin do
  let(:test_class) do
    Class.new do
      include CodeAnalysisMixin
      attr_reader :branch
    end
  end
  subject { test_class.new }

  describe "#merged_linter_results" do
    it "should always return a hash with a 'files' and 'summary' key, even with no cops running" do
      allow(subject).to receive(:pronto_result).and_return([])
      expect(subject.merged_linter_results).to eq("files" => [], "summary" => {"offense_count" => 0, "target_file_count" => 0})
    end
  end

  describe "#run_all_linters" do
    let(:item_rubocop) { double("RuCo object", :runner => item_runner_ruco, :path => "RuCo filepath.rb", :level => "RuCo warning-text", :msg => item_msg, :line => item_line) }
    let(:item_haml)    { double("haml object", :runner => item_runner_haml, :path => "haml filepath.rb", :level => "haml warning-text", :msg => item_msg, :line => item_line) }
    let(:item_yaml)    { double("yaml object", :runner => item_runner_yaml, :path => "yaml filepath.rb", :level => "yaml warning-text", :msg => item_msg, :line => item_line) }

    let(:item_runner_ruco)  { double("runner object", :name => "Pronto::Rubocop") }
    let(:item_runner_haml)  { double("runner object", :name => "Pronto::Haml") }
    let(:item_runner_yaml)  { double("runner object", :name => "Pronto::Yaml") }

    let(:item_msg)  { double("msg object", :msg => "message-text", :line => item_line) }
    let(:item_line) { double("line object", :position => 1) }

    before do
      allow(subject).to receive(:pronto_result).and_return(input)
    end

    context "input is array of pronto messages" do
      let(:input) { [item_rubocop, item_haml, item_yaml] }

      it "returns a hash created from an array of \'Pronto::Message\'s" do
        expect(subject.run_all_linters).to eq(
          [
            {
              "files"    =>
                            [
                              {
                                "path"     => item_rubocop.path,
                                "offenses" =>
                                              [
                                                {
                                                  "severity"  => item_rubocop.level,
                                                  "message"   => item_rubocop.msg,
                                                  "cop_name"  => item_rubocop.runner,
                                                  "corrected" => false,
                                                  "line"      => item_msg.line.position
                                                },
                                              ]
                              }
                            ],
              "summary"  =>
                            {
                              "offense_count"     => input.group_by(&:runner).values[0].count,
                              "target_file_count" => input.group_by(&:runner).values[0].group_by(&:path).count
                            }
            },
            {
              "files"   =>
                           [
                             {
                               "path"     => item_haml.path,
                               "offenses" =>
                                             [
                                               {
                                                 "severity"  => item_haml.level,
                                                 "message"   => item_haml.msg,
                                                 "cop_name"  => item_haml.runner,
                                                 "corrected" => false,
                                                 "line"      => item_msg.line.position
                                               },
                                             ]
                             }
                           ],
              "summary" =>
                           {
                             "offense_count"     => input.group_by(&:runner).values[1].count,
                             "target_file_count" => input.group_by(&:runner).values[1].group_by(&:path).count
                           }
            },
            {
              "files"   =>
                           [
                             {
                               "path"     => item_yaml.path,
                               "offenses" =>
                                             [
                                               {
                                                 "severity"  => item_yaml.level,
                                                 "message"   => item_yaml.msg,
                                                 "cop_name"  => item_yaml.runner,
                                                 "corrected" => false,
                                                 "line"      => item_msg.line.position
                                               },
                                             ]
                             }
                           ],
              "summary" =>
                           {
                             "offense_count"     => input.group_by(&:runner).values[2].count,
                             "target_file_count" => input.group_by(&:runner).values[2].group_by(&:path).count
                           }
            }
          ]
        ) # expect END
      end
    end
  end
end
