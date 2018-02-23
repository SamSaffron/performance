$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'frozen'
require 'not_frozen'

# iseq = RubyVM::InstructionSequence.new <<-eoruby
# # frozen_string_literal: true
# x = -"foo"
# p x.object_id
# eoruby
#
# puts iseq.disasm

puts frozen.object_id
puts frozen.object_id
#
# puts not_frozen.object_id
# puts not_frozen.object_id
