module Linter
  class Yaml < Base
    private

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
      filename, line, column, severity_message_cop = line.split(":", 4)
      severity_message, cop = severity_message_cop.split(/ \((.*)\)\Z/)
      severity, message = severity_message.match(/\[(.*)\] (.*)/).captures

      {
        "filename" => filename,
        "severity" => severity,
        "message"  => message,
        "cop_name" => cop,
        "location" => {
          "line"   => line.to_i,
          "column" => column.to_i
        }
      }
    end
  end
end
