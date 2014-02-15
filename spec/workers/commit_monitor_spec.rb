require 'spec_helper'

describe CommitMonitor do
  context "#compare_commits_list (private)" do
    let(:left)  { ["b35cfe137e193239d887a87182af971c6d1c7f07", "71eddc02941a4a8e08985202f49f8c88251b1bc1", "67b120c9ebf4467819fbfd329e06ad288621c53c"] }
    let(:right) { ["467ece9fe399a8e77ce6287a851acc62b6f9b5f6", "2bff87929646d40aca36649fc640310162b774f0", "e04b64754a32a6bedffc56d92e4a9f85b052296f"] }

    it "with matching lists" do
      expect(described_class.new.send(:compare_commits_list, left, left)).to eq(
        {:same => left, :left_only => [], :right_only => []}
      )
    end

    it "with non-matching lists" do
      expect(described_class.new.send(:compare_commits_list, left, right)).to eq(
        {:same => [], :left_only => left, :right_only => right}
      )
    end

    it "with partial matching lists" do
      l = left.dup << right[0]
      r = left.dup << right[1]

      expect(described_class.new.send(:compare_commits_list, l, r)).to eq(
        {:same => left, :left_only => [right[0]], :right_only => [right[1]]}
      )
    end

    it "with partial matching lists and left list longer" do
      l = left.dup << right[0]
      r = left.dup

      expect(described_class.new.send(:compare_commits_list, l, r)).to eq(
        {:same => left, :left_only => [right[0]], :right_only => []}
      )
    end

    it "with partial matching lists and right list longer" do
      l = left.dup
      r = left.dup << right[0]

      expect(described_class.new.send(:compare_commits_list, l, r)).to eq(
        {:same => left, :left_only => [], :right_only => [right[0]]}
      )
    end

    it "with empty lists" do
      expect(described_class.new.send(:compare_commits_list, [], [])).to eq(
        {:same => [], :left_only => [], :right_only => []}
      )
    end

    it "with empty left list" do
      expect(described_class.new.send(:compare_commits_list, [], right)).to eq(
        {:same => [], :left_only => [], :right_only => right}
      )
    end

    it "with empty right list" do
      expect(described_class.new.send(:compare_commits_list, left, [])).to eq(
        {:same => [], :left_only => left, :right_only => []}
      )
    end
  end
end
