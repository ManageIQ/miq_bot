require 'stringio'

module MiqToolsServices
  class Github
    class MessageBuilder
      attr_accessor :header, :continuation_header

      GITHUB_COMMENT_BODY_MAX_SIZE = 65_535

      def initialize(header = nil, continuation_header = nil)
        @header = header
        @continuation_header = continuation_header
        @lines = []
      end

      def write(line)
        if line.length >= GITHUB_COMMENT_BODY_MAX_SIZE
          raise ArgumentError, "line length must be less than #{GITHUB_COMMENT_BODY_MAX_SIZE}"
        end
        @lines << line
      end

      def write_lines(lines)
        lines.each { |l| write(l) }
      end

      def messages
        build_messages
        @messages.collect(&:string)
      end

      private

      def build_messages
        @messages = []
        start_new_message(header)
        @lines.each { |line| add_to_message(line) }
      end

      def start_new_message(message_header)
        @message = StringIO.new
        @messages << @message
        add_to_message(message_header) if message_header
      end

      def add_to_message(line)
        start_new_message(continuation_header) if will_exceed_message_max_size?(line)
        @message.puts(line)
      end

      def will_exceed_message_max_size?(line)
        @message.length + line.length + 1 >= GITHUB_COMMENT_BODY_MAX_SIZE
      end
    end
  end
end
