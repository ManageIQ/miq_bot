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

  # Read the values back through the public GET options. git_libgit2_opts is
  # variadic, so it must be declared with TYPE_VARIADIC; a fixed-arity
  # declaration silently drops the argument on some ABIs (e.g. arm64).
  def libgit2_get_int_opt(opt)
    require 'fiddle'
    git_libgit2_opts = Fiddle::Function.new(
      Fiddle::Handle::DEFAULT["git_libgit2_opts"],
      [Fiddle::TYPE_INT, Fiddle::TYPE_VARIADIC],
      Fiddle::TYPE_INT
    )
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT, Fiddle::RUBY_FREE)
    rc  = git_libgit2_opts.call(opt, Fiddle::TYPE_VOIDP, buf)
    raise "git_libgit2_opts(#{opt}) failed with #{rc}" unless rc.zero?

    buf[0, Fiddle::SIZEOF_INT].unpack1("i")
  end

  it "sets libgit2 server connect timeout to 5 minutes" do
    expect(libgit2_get_int_opt(libgit2_enum_value("GIT_OPT_GET_SERVER_CONNECT_TIMEOUT")))
      .to eq(5.minutes.in_milliseconds.to_i)
  end

  it "sets libgit2 server read/write timeout to 5 minutes" do
    expect(libgit2_get_int_opt(libgit2_enum_value("GIT_OPT_GET_SERVER_TIMEOUT")))
      .to eq(5.minutes.in_milliseconds.to_i)
  end
end
