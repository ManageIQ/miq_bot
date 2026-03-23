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
      expect(subject.first).to  eq <<~EOMSG
        <rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
        5 files checked, 5 offenses detected

        **spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb**
        - [ ] :exclamation: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L3), Col 5 - [Layout/HashAlignment](https://docs.rubocop.org/rubocop/latest/cops_layout.html#layouthashalignment) - Align the keys and values of a hash literal if they span more than one line.
        - [ ] :exclamation: - [Line 4](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/coding_convention.rb#L4), Col 5 - [Layout/HashAlignment](https://docs.rubocop.org/rubocop/latest/cops_layout.html#layouthashalignment) - Align the keys and values of a hash literal if they span more than one line.

        **spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/with_results_with_offenses/rails.rb**
        - [ ] :exclamation: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/with_results_with_offenses/rails.rb#L3), Col 5 - [Rails/DynamicFindBy](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html#railsdynamicfindby) - Use `find_by` instead of dynamic `find_by_name`.

        **spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb**
        - [ ] :bomb: :boom: :fire: :fire_engine: - [Line 6](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_syntax_error.rb#L6), Col 1 - [Lint/Syntax](https://docs.rubocop.org/rubocop/latest/cops_lint.html#lintsyntax) - unexpected token kEND
        (Using Ruby 2.6 parser; configure using `TargetRubyVersion` parameter, under `AllCops`)

        **spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb**
        - [ ] :warning: - [Line 3](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/ruby_warning.rb#L3), Col 5 - [Lint/UselessAssignment](https://docs.rubocop.org/rubocop/latest/cops_lint.html#lintuselessassignment) - Useless assignment to variable - `unused_variable`.
      EOMSG
    end

    it "with results with no offenses" do
      expect(subject.length).to eq 1
      expect(subject.first).to  start_with <<~EOMSG.chomp
        <rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
        1 file checked, 0 offenses detected
        Everything looks fine.
      EOMSG
      expect(subject.first.split(" ").last).to match /:[\w\d+]+:/ # Ends with an emoji ;)
    end

    it "with results generating multiple comments" do
      expect(subject.length).to eq 2
      expect(subject.first).to  start_with <<~EOMSG.chomp
        <rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
        1 file checked, 292 offenses detected
      EOMSG
      expect(subject.last).to   start_with "<rubocop />**...continued**\n"
    end

    it "with results without column numbers and cop names" do
      expect(subject.length).to eq 1
      expect(subject.first).to  eq <<~EOMSG
        <rubocop />Checked commits https://github.com/some_user/some_repo/compare/1ec36efd33279f79f8ddcf12984bb2aa48f3fbd6~...8942a195a0bfa69ceb82c020c60565408cb46d3e with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}
        1 file checked, 1 offense detected

        **spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/#{rubocop_check_directory}/example.haml**
        - [ ] :warning: - [Line 2](https://github.com/some_user/some_repo/blob/8942a195a0bfa69ceb82c020c60565408cb46d3e/spec/workers/commit_monitor_handlers/commit_range/rubocop_checker/data/with_results_without_column_numbers_and_cop_names/example.haml#L2) - The - symbol should have one space separating it from code
      EOMSG
    end
  end

  describe "::COP_URIS" do
    it "generates documentation URLs for builtin cops" do
      expect(described_class::COP_URIS['Style/StringLiterals']).to match(/\[Style\/StringLiterals\]\(https:\/\/docs\.rubocop\.org\/rubocop\/latest\/cops_style\.html#stylestringliterals\)/)
    end

    it "generates documentation URLs for Rails cops" do
      expect(described_class::COP_URIS['Rails/DynamicFindBy']).to match(/\[Rails\/DynamicFindBy\]\(https:\/\/docs\.rubocop\.org\/rubocop-rails\/latest\/cops_rails\.html#railsdynamicfindby\)/)
    end

    it "generates documentation URLs for Performance cops" do
      expect(described_class::COP_URIS['Performance/StringInclude']).to match(/\[Performance\/StringInclude\]\(https:\/\/docs\.rubocop\.org\/rubocop-performance\/latest\/cops_performance\.html#performancestringinclude\)/)
    end
  end

  context "with stubbed yamllint" do
    before do
      described_class.instance_variable_set(:@yamllint_version, nil) # Clear caching
      expect(described_class).to receive(:`).with("yamllint -v 2>&1").and_return("yamllint 1.35.1\n")
    end

    after do
      described_class.instance_variable_set(:@yamllint_version, nil) # Clear caching
    end

    it ".yamllint_version" do
      expect(described_class.yamllint_version).to eq("1.35.1")
    end

    it "#yamllint_version (private)" do
      subject = described_class.new(nil, nil)
      expect(subject.send(:yamllint_version)).to eq("1.35.1")
    end
  end
end
