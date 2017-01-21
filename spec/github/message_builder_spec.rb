require 'spec_helper'

describe MiqToolsServices::Github::MessageBuilder do
  let(:max) { described_class::COMMENT_BODY_MAX_SIZE }
  let(:header) { "header stuff\n\n" }
  let(:continuation_header) { "continued...\n\n" }
  subject { described_class.new(header, continuation_header) }

  describe "#write / #comments" do
    it "with simple line" do
      subject.write("a line")
      expect(subject.comments).to eq ["#{header}a line\n"]
    end

    it "with a line that's too long" do
      expect { subject.write("a" * max) }.to raise_error(ArgumentError)
    end

    it "with a line that will warp to a new comment" do
      line = "a" * (max - header.length)
      subject.write("a line")
      subject.write(line)
      expect(subject.comments).to eq [
        "#{header}a line\n",
        "#{continuation_header}#{line}\n"
      ]
    end
  end

  describe "#write_lines / #comments" do
    it "with simple lines" do
      subject.write_lines(["a line", "another line"])
      expect(subject.comments).to eq ["#{header}a line\nanother line\n"]
    end

    it "with a line that's too long" do
      expect { subject.write_lines(["a line", "a" * max]) }.to raise_error(ArgumentError)
    end

    it "with a line that will wrap to a new comment" do
      line = "a" * (max - header.length)
      subject.write_lines(["a line", line])
      expect(subject.comments).to eq [
        "#{header}a line\n",
        "#{continuation_header}#{line}\n"
      ]
    end
  end
end
