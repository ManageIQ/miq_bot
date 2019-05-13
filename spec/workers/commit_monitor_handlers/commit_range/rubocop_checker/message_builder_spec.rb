require 'spec_helper'

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
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
4 files checked, 4 offenses detected

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb**
- [ ] :exclamation: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L3), Col 5 - [Layout/AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Layout/AlignHash) - Align the elements of a hash literal if they span more than one line.
- [ ] :exclamation: - [Line 4](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L4), Col 5 - [Layout/AlignHash](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Layout/AlignHash) - Align the elements of a hash literal if they span more than one line.

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb**
- [ ] :bomb: :boom: :fire: :fire_engine: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb#L3), Col 1 - [Lint/Syntax](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Lint/Syntax) - unexpected token kEND
(Using Ruby 2.3 parser; configure using `TargetRubyVersion` parameter, under `AllCops`)

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb**
- [ ] :warning: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb#L3), Col 5 - [Lint/UselessAssignment](http://rubydoc.info/gems/rubocop/#{rubocop_version}/RuboCop/Cop/Lint/UselessAssignment) - Useless assignment to variable - `unused_variable`.
      EOMSG
    end

    it "with results with no offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  start_with <<-EOMSG.chomp
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
1 file checked, 0 offenses detected
Everything looks fine.
      EOMSG
      expect(subject.first.split(" ").last).to match /:[\w\d\+]+:/ # Ends with an emoji ;)
    end

    it "with results generating multiple comments" do
      expect(subject.length).to eq 2
      expect(subject.first).to  start_with <<-EOMSG.chomp
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
1 file checked, 292 offenses detected
      EOMSG
      expect(subject.last).to   start_with "<rubocop />**...continued**\n"
    end

    it "with results without column numbers and cop names" do
      expect(subject.length).to eq 1
      expect(subject.first).to  eq <<-EOMSG
<rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
1 file checked, 1 offense detected

**spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/example.haml**
- [ ] :warning: - [Line 2](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/with_results_without_column_numbers_and_cop_names/example.haml#L2) - The - symbol should have one space separating it from code
      EOMSG
    end
  end
end
