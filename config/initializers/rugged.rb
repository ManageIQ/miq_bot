# libgit2 1.7+ supports server connect/read timeouts via git_libgit2_opts,
# but Rugged::Settings does not yet expose them. Call git_libgit2_opts
# directly via Fiddle until a Rugged PR lands to add "server_timeout" and
# "server_connect_timeout" to rugged_settings.c. Once that lands and rugged
# cuts a release, this can be replaced with:
#   Rugged::Settings["server_connect_timeout"] = timeout_ms
#   Rugged::Settings["server_timeout"]         = timeout_ms
# The enum values below are from libgit2/include/git2/common.h; verified
# against libgit2 1.9.6 (bundled in rugged 1.9.6). Other versions may have
# different orderings -- confirm against the bundled libgit2 version.
#   GIT_OPT_SET_SERVER_CONNECT_TIMEOUT = 39
#   GIT_OPT_SET_SERVER_TIMEOUT         = 41
require 'fiddle'
require 'rugged'

git_libgit2_opts = Fiddle::Function.new(
  Fiddle::Handle::DEFAULT["git_libgit2_opts"],
  [Fiddle::TYPE_INT, Fiddle::TYPE_INT],
  Fiddle::TYPE_INT
)

timeout_ms = 5.minutes.in_milliseconds.to_i
git_libgit2_opts.call(39, timeout_ms) # GIT_OPT_SET_SERVER_CONNECT_TIMEOUT
git_libgit2_opts.call(41, timeout_ms) # GIT_OPT_SET_SERVER_TIMEOUT
