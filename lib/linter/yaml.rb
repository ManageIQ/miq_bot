module Linter
  class Yaml < Base
    private

    REGEX = /(?<filename>.*):(?<line>\d+):(?<column>\d+): \[(?<severity>.*)\] (?<message>.*) \((?<cop_name>.*)\)/

    def parse_output(output)
      lines = output.chomp.split("\n")
      parsed = lines.collect { |line| line_to_hash(line) }
      grouped = parsed.group_by { |hash| hash["filename"] }
      file_count = parsed.collect { |hash| hash["filename"] }.uniq.count
      {
        "files"   => grouped.collect do |filename, offenses|
          {
            "path"     => filename.sub(%r{\A\./}, ""),
            "offenses" => offenses.collect { |offense_hash| offense_hash.except("filename") }
          }
        end,
        "summary" => {
          "offense_count"        => lines.size,
          "target_file_count"    => file_count,
          "inspected_file_count" => file_count
        }
      }
    end

    def linter_executable
      "yamllint"
    end

    def config_files
      [".yamllint"]
    end

    def options
      {:f => "parsable", nil => ["."]}
    end

    def filtered_files(files)
      files.select { |f| f.end_with?(".yml", ".yaml") }
    end

    def line_to_hash(line)
      match = REGEX.match(line)
      {
        "filename" => match[:filename],
        "severity" => match[:severity],
        "message"  => match[:message],
        "cop_name" => match[:cop_name],
        "location" => {
          "line"   => match[:line].to_i,
          "column" => match[:column].to_i
        }
      }
    end
  end
end
