describe TravisBranchMonitor do
  include IncludedReposConfigMethods

  describe ".included_and_excluded_repos (private)" do
    it "builds the list from a hash of only keys" do
      stub_settings included_repos_keys_only
      expected = %w[ManageIQ/manageiq ManageIQ/miq_bot]

      expect(described_class.send(:included_and_excluded_repos)).to eq([expected, nil])
    end

    it "builds the list from a hash of keys with values" do
      stub_settings included_repos_keys_and_values
      expected = %w[ManageIQ/manageiq-ui-classic ManageIQ/manageiq-gems-pending]

      expect(described_class.send(:included_and_excluded_repos)).to eq([expected, nil])
    end

    it "builds the list from a mixed hash with keys and some values" do
      stub_settings included_repos_mixed_keys_with_some_values
      expected = %w[
        ManageIQ/manageiq-ui-classic
        ManageIQ/manageiq-gems-pending
        ManageIQ/manageiq
        ManageIQ/miq_bot
      ]

      expect(described_class.send(:included_and_excluded_repos)).to eq([expected, nil])
    end
  end

  describe "#find_first_recent_failure (private)" do
    def passed(build_id)
      build = Travis::Client::Build.new(nil, build_id)
      allow(build).to receive(:inspect_info).and_return("Foo/foo##{build_id}")
      build.tap { |b| b.update_attributes(:state => "passed") }
    end

    def failed(build_id)
      build = Travis::Client::Build.new(nil, build_id)
      allow(build).to receive(:inspect_info).and_return("Foo/foo##{build_id}")
      build.tap { |b| b.update_attributes(:state => "failed") }
    end

    it "returns earliest failure" do
      earliest_failure = failed(2)
      builds = [
        failed(4),
        failed(3),
        earliest_failure,
        passed(1)
      ]

      expect(subject.send(:find_first_recent_failure, builds)).to eq(earliest_failure)
    end

    it "returns nil if the first build has passed" do
      builds = [
        passed(5),
        failed(4),
        failed(3),
        failed(2),
        passed(1)
      ]

      expect(subject.send(:find_first_recent_failure, builds)).to eq(nil)
    end
  end
end
