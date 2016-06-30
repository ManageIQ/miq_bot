describe OffenseMessage::Entry do
  context "#to_s" do
    it "basic entry" do
      entry = described_class.new(:high, "Message")
      expect(entry.to_s).to eq("- [ ] :exclamation: - Message")
    end

    it "basic entry with locator" do
      entry = described_class.new(:high, "Message", nil, "Locator")
      expect(entry.to_s).to eq("- [ ] :exclamation: - Locator - Message")
    end
  end

  context "#<=>" do
    shared_examples_for "sortable" do
      it "should be sortable" do
        expect(entry1 <=> entry2).to eq(-1)
        expect(entry1 <=> entry1).to eq(0)
        expect(entry2 <=> entry1).to eq(1)
      end
    end

    context "by group" do
      context "with groups" do
        let(:entry1) { described_class.new(:high, "Message", "Group A") }
        let(:entry2) { described_class.new(:high, "Message", "Group B") }
        include_examples "sortable"
      end

      context "with and without group" do
        let(:entry1) { described_class.new(:high, "Message") }
        let(:entry2) { described_class.new(:high, "Message", "Group B") }
        include_examples "sortable"
      end
    end

    context "by severity" do
      let(:entry1) { described_class.new(:high, "Message") }
      let(:entry2) { described_class.new(:low, "Message") }
      include_examples "sortable"
    end

    context "by locator" do
      context "with locators" do
        let(:entry1) { described_class.new(:high, "Message", "Group A", "Locator A") }
        let(:entry2) { described_class.new(:high, "Message", "Group A", "Locator B") }
        include_examples "sortable"
      end

      context "with and without locator" do
        let(:entry1) { described_class.new(:high, "Message", "Group A") }
        let(:entry2) { described_class.new(:high, "Message", "Group A", "Locator B") }
        include_examples "sortable"
      end
    end

    context "by message" do
      let(:entry1) { described_class.new(:high, "Message A") }
      let(:entry2) { described_class.new(:high, "Message B") }
      include_examples "sortable"
    end

    it "as part of an Array" do
      entry1 = described_class.new(:low, "Message")
      entry2 = described_class.new(:high, "Message")
      expect([entry1, entry2].sort).to eq([entry2, entry1])
    end
  end
end
