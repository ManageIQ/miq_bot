module Linter
  class ESLint < Base
    private

    def config_files
      [".eslintrc.js", ".eslintrc.json"]
    end

    def linter_executable
      'eslint .'
    end

    def options
      {:format => 'json'}
    end

    def filtered_files(files)
      files.select do |file|
        file.end_with? '.js'
      end
    end

    def convert_parsed(array)
      files = array.map { |f| convert_file(f) }

      {:files   => files,
       :summary => {:offense_count     => files.reduce(0) { |memo, f| memo + f.offenses.count },
                    :target_file_count => files.count}}
    end

    def convert_file(file)
      {:path     => file[:filePath],
       :offenses => file[:messages].map { |m| convert_offense(m) }}
    end

    SEVERITY = ['off', 'warning', 'error']
    def convert_offense(offense)
      {:severity => SEVERITY[offense[:severity]],
       :message  => offense[:message],
       :location => {:line   => offense[:line],
                     :column => offense[:column]},
       :cop_name => offense[:ruleId]}
    end
  end
end
