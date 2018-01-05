require 'stringio'

class MessageCollector
  attr_accessor :max_size, :header, :continuation_header

  def initialize(max_size = nil, header = nil, continuation_header = nil)
    @max_size = max_size
    @header = header
    @continuation_header = continuation_header
    @lines = []
  end

  def write(line)
    if max_size && line.length >= max_size
      raise ArgumentError, "line length must be less than #{max_size}"
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
    max_size ? (@comment.length + line.length + 1 >= max_size) : false
  end
end
