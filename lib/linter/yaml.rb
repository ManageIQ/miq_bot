module Linter
  class Yaml < Base
    private

    REGEX = /(?<filename>.*):(?<line>\d+):(?<column>\d+): \[(?<severity>.*)\] (?<message>.*) \((?<cop_name>.*)\)/

    def parse_output(output)
      lines = output.chomp.split("\n")
      parsed = lines.collect { |line| REGEX.match(line) }
      grouped = parsed.group_by { |match| match[:filename] }
      file_count = parsed.collect { |match| match[:filename] }.uniq.count
      {
        "files"   => grouped.collect do |filename, offenses|
          {
            "path"     => filename.sub(%r{\A\./}, ""),
            "offenses" => offenses.collect do |match|
              {
                "severity" => match[:severity],
                "message"  => match[:message],
                "cop_name" => match[:cop_name],
                "location" => {
                  "line"   => match[:line].to_i,
                  "column" => match[:column].to_i
                }
              }
            end
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
  end
end
