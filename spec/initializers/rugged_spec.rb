require 'spec_helper'

RSpec.describe "config/initializers/rugged" do
  # Parse the bundled libgit2 header to resolve enum values at test time,
  # so that if the enum ordering changes between libgit2 versions the spec
  # fails loudly rather than silently calling the wrong git_libgit2_opts option.
  def libgit2_enum_value(name)
    header = Gem::Specification.find_by_name("rugged")
                               .gem_dir
                               .then { |d| File.join(d, "vendor/libgit2/include/git2/common.h") }
    entries = File.read(header)
                  .scan(/^\s*(GIT_OPT_\w+)/)
                  .flatten
    index = entries.index(name)
    raise "#{name} not found in #{header}" if index.nil?

    index
  end

  it "uses the correct enum value for GIT_OPT_SET_SERVER_CONNECT_TIMEOUT" do
    expect(libgit2_enum_value("GIT_OPT_SET_SERVER_CONNECT_TIMEOUT")).to eq(39)
  end

  it "uses the correct enum value for GIT_OPT_SET_SERVER_TIMEOUT" do
    expect(libgit2_enum_value("GIT_OPT_SET_SERVER_TIMEOUT")).to eq(41)
  end

  # GIT_OPT_SET_SERVER_CONNECT_TIMEOUT and GIT_OPT_SET_SERVER_TIMEOUT write to
  # these two exported globals in libgit2's socket stream. Read them back
  # directly via dlsym rather than calling git_libgit2_opts as a variadic GET,
  # which crashes on arm64 due to Fiddle's variadic ABI limitations.
  def libgit2_stream_global(name)
    require 'fiddle'
    sym = Fiddle::Handle::DEFAULT[name]
    Fiddle::Pointer.new(sym)[0, Fiddle::SIZEOF_INT].unpack1("i")
  rescue Fiddle::DLError
    skip "#{name} is not exported by the bundled libgit2 (internal symbol)"
  end

  it "sets libgit2 server connect timeout to 5 minutes" do
    expect(libgit2_stream_global("git_socket_stream__connect_timeout"))
      .to eq(5.minutes.in_milliseconds.to_i)
  end

  it "sets libgit2 server read/write timeout to 5 minutes" do
    expect(libgit2_stream_global("git_socket_stream__timeout"))
      .to eq(5.minutes.in_milliseconds.to_i)
  end
end
