describe BuildFailureNotifier do
  include IncludedReposConfigMethods

  describe "#repo_room_map (private)" do
    it "builds a map from a hash of only keys" do
      stub_settings included_repos_keys_only
      expected_map = {
        "ManageIQ/manageiq" => "ManageIQ/manageiq",
        "ManageIQ/miq_bot"  => "ManageIQ/miq_bot"
      }

      expect(described_class.repo_room_map).to eq(expected_map)
    end

    it "builds a map from a hash of keys with values" do
      stub_settings included_repos_keys_and_values
      expected_map = {
        "ManageIQ/manageiq-ui-classic"   => "ManageIQ/ui",
        "ManageIQ/manageiq-gems-pending" => "ManageIQ/core"
      }

      expect(described_class.repo_room_map).to eq(expected_map)
    end

    it "builds a map from a mixed hash with keys and some values" do
      stub_settings included_repos_mixed_keys_with_some_values
      expected_map = {
        "ManageIQ/manageiq-ui-classic"   => "ManageIQ/ui",
        "ManageIQ/manageiq-gems-pending" => "ManageIQ/core",
        "ManageIQ/manageiq"              => "ManageIQ/manageiq",
        "ManageIQ/miq_bot"               => "ManageIQ/miq_bot"
      }

      expect(described_class.repo_room_map).to eq(expected_map)
    end
  end
end
