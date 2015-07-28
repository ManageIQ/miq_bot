require 'rails_helper'

describe CommitMonitorHandlers::CommitRange::RubocopChecker::MessageBuilder do
  let(:branch) do
    Branch.new(
      :name         => "pr/123",
      :commit_uri   => "https://github.com/some_user/some_repo/commit/$commit",
      :last_commit  => "8942a195a0bfa69ceb82c020c60565408cb46d3e",
      :commits_list => ["1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6", "8942a195a0bfa69ceb82c020c60565408cb46d3e"]
    )
  end

  context "#comments" do
    subject do
      described_class.new(rubocop_results, branch).comments
    end

    before { |example| @example = example }

    it "with results with offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  eq <<-EOMSG
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, and haml-lint #{hamllint_version}
4 files checked, 4 offenses detected

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb**
- [ ] :large_orange_diamond: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L3), Col 5 - [Style/AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Style/AlignHash) - Align the elements of a hash literal if they span more than one line.
- [ ] :large_orange_diamond: - [Line 4](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L4), Col 5 - [Style/AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Style/AlignHash) - Align the elements of a hash literal if they span more than one line.

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb**
- [ ] :red_circle: **Error** - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb#L3), Col 1 - Syntax - unexpected token kEND

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb**
- [ ] :red_circle: **Warn** - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb#L3), Col 5 - [Lint/UselessAssignment](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Lint/UselessAssignment) - Useless assignment to variable - `unused_variable`.
      EOMSG
    end

    it "with results with no offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  start_with <<-EOMSG.chomp
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, and haml-lint #{hamllint_version}
1 file checked, 0 offenses detected
Everything looks good.
      EOMSG
      expect(subject.first.split(" ").last).to match /:[\w\d\+]+:/ # Ends with an emoji ;)
    end

    it "with results generating multiple comments" do
      expect(subject.length).to eq 2
      expect(subject.first).to  start_with <<-EOMSG.chomp
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, and haml-lint #{hamllint_version}
1 file checked, 194 offenses detected
      EOMSG
      expect(subject.last).to   start_with "<rubocop />**...continued**\n"
    end
  end
end
