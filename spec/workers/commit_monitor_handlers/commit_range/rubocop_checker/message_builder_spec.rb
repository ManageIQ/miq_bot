require 'spec_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker::MessageBuilder do
  let(:branch) do
    CommitMonitorBranch.new(
      :name         => "pr/123",
      :commit_uri   => "https://github.com/some_user/some_repo/commit/$commit",
      :last_commit  => "8942a195a0bfa69ceb82c020c60565408cb46d3e",
      :commits_list => ["1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6", "8942a195a0bfa69ceb82c020c60565408cb46d3e"]
    )
  end

  let(:rubocop_version) { "0.21.0" }
  let(:rubocop_check_directory) { example.description.gsub(" ", "_") }
  let(:rubocop_check_path) { File.join(File.dirname(__FILE__), "data", rubocop_check_directory) }
  let(:json_file) { File.join(rubocop_check_path, "results.json") }

  let(:rubocop_results) do
    # To regenerate the results.json files, just delete them
    File.write(json_file, `rubocop --format=json #{rubocop_check_path}`) unless File.exists?(json_file)
    JSON.parse(File.read(json_file))
  end

  context "#messages" do
    subject do
      described_class.new(rubocop_results, branch).messages
    end

    it "with results with offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  eq <<-EOMSG
Checked commits https://github.com/some_user/some_repo/commit/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6 .. https://github.com/some_user/some_repo/commit/8942a195a0bfa69ceb82c020c60565408cb46d3e with rubocop #{rubocop_version}
4 files checked, 4 offenses detected

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb**
- [ ] Style - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L3), Col 5 - [AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/Rubocop/Cop/Style/AlignHash) - Align the elements of a hash literal if they span more than one line.
- [ ] Style - [Line 4](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L4), Col 5 - [AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/Rubocop/Cop/Style/AlignHash) - Align the elements of a hash literal if they span more than one line.

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb**
- [ ] **Error** - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb#L3), Col 1 - Syntax - unexpected token kEND

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb**
- [ ] **Warn** - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb#L3), Col 5 - [UselessAssignment](http://rubydoc.info/gems/rubocop/#{rubocop_version}/Rubocop/Cop/Lint/UselessAssignment) - Useless assignment to variable - `unused_variable`.
      EOMSG
    end

    it "with results with no offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  start_with <<-EOMSG.chomp
Checked commits https://github.com/some_user/some_repo/commit/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6 .. https://github.com/some_user/some_repo/commit/8942a195a0bfa69ceb82c020c60565408cb46d3e with rubocop #{rubocop_version}
1 file checked, 0 offenses detected
Everything looks good.
      EOMSG
      expect(subject.first.split(" ").last).to match /:[\w\d\+]+:/ # Ends with an emoji ;)
    end

    it "with multiple messages" do
      expect(subject.length).to eq 2
      expect(subject.first).to  start_with <<-EOMSG.chomp
Checked commits https://github.com/some_user/some_repo/commit/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6 .. https://github.com/some_user/some_repo/commit/8942a195a0bfa69ceb82c020c60565408cb46d3e with rubocop 0.21.0
1 file checked, 194 offenses detected
      EOMSG
      expect(subject.last).to   start_with "**...continued**\n"
    end
  end
end
