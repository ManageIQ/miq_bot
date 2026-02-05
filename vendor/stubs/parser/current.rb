# frozen_string_literal: true

# Injects a "stub" 'parser/current' file (that should be appended to the Ruby
# $LOADPATH), which avoids the annoying loading the original, which includes
# the unskippable warnings like this:
#
#     warning: parser/current is loading parser/ruby27, which recognizes
#     warning: 2.7.2-compliant syntax, but you are running 2.7.1.
#     warning: please see https://github.com/whitequark/parser#compatibility-with-ruby-mri.
#
# in STDERR, which are flagged by the bot as errors (when they aren't useful to
# the end user).
#
# This stub will just define the `Parser::CurrentRuby` constant manually using
# the conventions of the `parser` gem.
#

require "parser/ruby#{RbConfig::CONFIG["MAJOR"]}#{RbConfig::CONFIG["MINOR"]}"

module Parser
  CurrentRuby = const_get("Ruby#{RbConfig::CONFIG["MAJOR"]}#{RbConfig::CONFIG["MINOR"]}")
end
