RSpec.describe GitService::GcGuard do
  def gc_disabled?
    previous = GC.disable
    GC.enable unless previous
    previous
  end

  around do |example|
    GC.enable
    example.run
  ensure
    GC.enable
  end

  it "disables GC inside the block and re-enables it afterward" do
    expect(gc_disabled?).to be false

    described_class.without_gc { expect(gc_disabled?).to be true }

    expect(gc_disabled?).to be false
  end

  it "returns the value of the block" do
    expect(described_class.without_gc { 42 }).to eq(42)
  end

  it "re-enables GC when the block raises" do
    expect { described_class.without_gc { raise "boom" } }.to raise_error("boom")

    expect(gc_disabled?).to be false
  end

  it "leaves GC disabled if it was already disabled by the caller" do
    GC.disable

    described_class.without_gc { expect(gc_disabled?).to be true }

    expect(gc_disabled?).to be true
  end

  it "keeps GC disabled until the outermost guard exits" do
    described_class.without_gc do
      described_class.without_gc { expect(gc_disabled?).to be true }
      expect(gc_disabled?).to be true
    end

    expect(gc_disabled?).to be false
  end

  it "keeps GC disabled while another thread's guard is still active" do
    entered  = Queue.new
    release  = Queue.new
    thread = Thread.new do
      described_class.without_gc do
        entered << true
        release.pop
      end
    end
    entered.pop

    described_class.without_gc { expect(gc_disabled?).to be true }
    expect(gc_disabled?).to be true # the other thread's guard is still active

    release << true
    thread.join
    expect(gc_disabled?).to be false
  end
end
