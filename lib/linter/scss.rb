module Linter
  class SCSS < Base
    private

    def config_files
      [".scss-lint.yml"]
    end

    def linter_executable
      'scss-lint'
    end

    def options
      {:format => 'JSON'}
    end

    def filtered_files(files)
      files.select { |file| file.end_with?(".scss") }
    end

    def convert_parsed(hash)
      files = hash.map { |path, offenses| convert_file(path, offenses) }

      {:files   => files,
       :summary => {:offense_count     => files.reduce(0) { |memo, f| memo + f.offenses.count },
                    :target_file_count => files.count}}
    end

    def convert_file(path, offenses)
      {:path     => path,
       :offenses => offenses.map { |o| convert_offense(o) }}
    end

    def convert_offense(offense)
      {:severity => offense[:severity],
       :message  => offense[:reason],
       :location => {:line   => offense[:line],
                     :column => offense[:column]},
       :cop_name => offense[:linter]}
    end
  end
  end
end
