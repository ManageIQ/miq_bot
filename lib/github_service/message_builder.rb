require 'stringio'

module MiqToolsServices
  class Github
    class MessageBuilder
      attr_accessor :header, :continuation_header

      COMMENT_BODY_MAX_SIZE = 65_535

      def initialize(header = nil, continuation_header = nil)
        @header = header
        @continuation_header = continuation_header
        @lines = []
      end

      def write(line)
        if line.length >= COMMENT_BODY_MAX_SIZE
          raise ArgumentError, "line length must be less than #{COMMENT_BODY_MAX_SIZE}"
        end
        @lines << line
      end

      def write_lines(lines)
        lines.each { |l| write(l) }
      end

      def comments
        build_comments
        @comments.collect(&:string)
      end

      private

      def build_comments
        @comments = []
        start_new_comment(header)
        @lines.each { |line| add_to_comment(line) }
      end

      def start_new_comment(comment_header)
        @comment = StringIO.new
        @comments << @comment
        add_to_comment(comment_header) if comment_header
      end

      def add_to_comment(line)
        start_new_comment(continuation_header) if will_exceed_comment_max_size?(line)
        @comment.puts(line)
      end

      def will_exceed_comment_max_size?(line)
        @comment.length + line.length + 1 >= COMMENT_BODY_MAX_SIZE
      end
    end
  end
end
