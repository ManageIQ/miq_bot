RSpec.describe Linter::Yaml do
  describe "#parse_output" do
    it "formats the output in the same form as rubocop" do
      output = <<-EOOUTPUT
config/settings.yml:8:5: [warning] wrong indentation: expected 2 but found 4 (indentation)
config/settings.yml:11:1: [error] duplication of key ":a" in mapping (key-duplicates)
EOOUTPUT

      actual = described_class.new(double("branch")).send(:parse_output, output)

      expected = {
        "files"   => [
          {
            "path"     => "config/settings.yml",
            "offenses" => a_collection_containing_exactly(
              {
                "severity" => "warning",
                "message"  => "wrong indentation: expected 2 but found 4",
                "cop_name" => "indentation",
                "location" => {
                  "line"   => 8,
                  "column" => 5
                }
              },
              {
                "severity" => "error",
                "message"  => "duplication of key \":a\" in mapping",
                "cop_name" => "key-duplicates",
                "location" => {
                  "line"   => 11,
                  "column" => 1
                }
              }
            )
          }
        ],
        "summary" => {
          "offense_count"        => 2,
          "target_file_count"    => 1,
          "inspected_file_count" => 1
        },
      }
      expect(actual).to include(expected)
    end
  end
end
