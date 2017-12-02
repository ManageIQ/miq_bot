RSpec.describe Linter::Yaml do
  describe "#parse_output" do
    it "formats the output in the same form as rubocop" do
      output = <<-EOOUTPUT
config/settings.yml:8:5: [warning] wrong indentation: expected 2 but found 4 (indentation)
config/settings.yml:11:1: [error] duplication of key ":a" in mapping (key-duplicates)
lib/generators/provider/templates/config/settings.yml:8:15: [error] syntax error: could not find expected ':'
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
          },
          {
            "path"     => "lib/generators/provider/templates/config/settings.yml",
            "offenses" => [
              {
                "severity" => "error",
                "message"  => "syntax error: could not find expected ':'",
                "cop_name" => nil,
                "location" => {
                  "line"   => 8,
                  "column" => 15
                }
              },
            ]
          }
        ],
        "summary" => {
          "offense_count"        => 3,
          "target_file_count"    => 2,
          "inspected_file_count" => 2
        },
      }
      expect(actual).to include(expected)
    end
  end

  describe "#line_to_hash" do
    it "with a syntax error" do
      line = "./lib/generators/provider/templates/config/settings.yml:8:15: [error] syntax error: could not find expected ':'"
      expect(described_class.new(double).send(:line_to_hash, line)).to eq(
        "cop_name" => nil,
        "filename" => "./lib/generators/provider/templates/config/settings.yml",
        "location" => {"line" => 8, "column" => 15},
        "message"  => "syntax error: could not find expected ':'",
        "severity" => "error"
      )
    end

    it "with an indentation warning" do
      line = "config/settings.yml:8:5: [warning] wrong indentation: expected 2 but found 4 (indentation)"
      expect(described_class.new(double).send(:line_to_hash, line)).to eq(
        "cop_name" => "indentation",
        "filename" => "config/settings.yml",
        "location" => {"line" => 8, "column" => 5},
        "message"  => "wrong indentation: expected 2 but found 4",
        "severity" => "warning"
      )
    end

    it "with a duplicate key error" do
      line = "config/settings.yml:11:1: [error] duplication of key \":a\" in mapping (key-duplicates)"
      expect(described_class.new(double).send(:line_to_hash, line)).to eq(
        "cop_name" => "key-duplicates",
        "filename" => "config/settings.yml",
        "location" => {"line" => 11, "column" => 1},
        "message"  => "duplication of key \":a\" in mapping",
        "severity" => "error"
      )
    end
  end
end
