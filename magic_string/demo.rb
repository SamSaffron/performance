require "active_support"
require "active_support/core_ext/string/output_safety"
require "objspace"

def assert_same_object(x, y)
  raise unless x.object_id == y.object_id
end

def assert_not_same_object(x, y)
  raise unless x.object_id != y.object_id
end

# a lot of what is here depends on Ruby 2.5
raise unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.5.0")

vm_deduped1 = "vm_deduped".freeze
vm_deduped2 = "vm_deduped".freeze
assert_same_object(vm_deduped1, vm_deduped2)

# interpolated strings are not magic deduped if they include vars
assert_not_same_object(vm_deduped1, "#{vm_deduped1}".freeze)

# there is a rare case where they are
assert_same_object(vm_deduped1, "#{"vm_deduped"}".freeze)

# String @- can be used to dedupe strings
simple1 = "simple"
simple2 = "simple"
assert_same_object(-simple1, -simple2)

# duduping is a bit inconsistent at the moment
frozen_not_deduped1 = ("x" * 100).freeze
frozen_not_deduped2 = ("x" * 100).freeze

# dynamic strings are not vm deduped
assert_not_same_object(frozen_not_deduped1, frozen_not_deduped2)

# till https://bugs.ruby-lang.org/issues/14478 is fixed, this is sadly the case
assert_not_same_object(-frozen_not_deduped1, -frozen_not_deduped2)

# WARNING: frozen_string_litral: true creates frozen strings for interpolated strings
eval <<~RUBY
  # frozen_string_literal: true
  def bad_dedup(val)
    x = "\#{val}s"
    -x
  end

  def yucky_good_dedup(val)
    # did you know String + unfreezes a string?
    -+"\#{val}s"
  end
RUBY

# :( my bad dedup does not work, so hopefully a fix for 14478 is backported
assert_not_same_object(bad_dedup("bad"), bad_dedup("bad"))
assert_same_object(-yucky_good_dedup("good"), -yucky_good_dedup("good"))

# active support caveats
html_safe1 = "<html>#{"x"*100}<html>".html_safe
html_safe2 = "<html>#{"x"*100}<html>".html_safe

# an instance var was set on String, so we can not dedup
# if you want to dedup always do it prior to calling html_safe
assert_not_same_object(-html_safe1, -html_safe2)

# untrusted strings are not deduped
not_trusted1 = "i am not trusted"
not_trusted1.untrust

not_trusted2 = "i am not trusted"
not_trusted2.untrust

assert_not_same_object(-not_trusted1, -not_trusted2)

# tainted strings are not deduped
tainted1 = File.read(__FILE__)
tainted2 = File.read(__FILE__)

assert_not_same_object(-tainted1, -tainted2)

# if you want to dedup tainted strings you must create a copy
tainted_dedup1 = -tainted1.dup.untaint
tainted_dedup2 = -tainted2.dup.untaint

assert_same_object(tainted_dedup1, tainted_dedup2)

# calling uminus creates shared string as a side effect
str = "X" * 10000

raise unless ObjectSpace.memsize_of(str) == 10041

_ = -str

# -str triggered a side effect that ended up sharing the giant string
# with a hidden RVALUE in the fstring hash table
raise unless ObjectSpace.memsize_of(str) == 40

# with patched in ivar you also get partial dedupes
class String
  attr_accessor :monkey_patched
end

assert_same_object(-"#{"hello"}", -"hello")

patched1 = "p" * 1000
patched2 = "p" * 1000

raise unless ObjectSpace.memsize_of(patched1) == 1041

# the same object cause no ivar is set
assert_same_object(-patched1, -patched2)

patched1.monkey_patched = true
patched2.monkey_patched = true

partially_dedup1 = -patched1
partially_dedup2 = -patched2

# not the same cause we would lose the ivar if we returned fstring
assert_not_same_object(partially_dedup1, partially_dedup2)

unless ObjectSpace.memsize_of(patched1) == 64 &&
  ObjectSpace.memsize_of(patched2) == 64 &&
  ObjectSpace.memsize_of(partially_dedup1) == 64 &&
  ObjectSpace.memsize_of(partially_dedup2) == 64

  raise
end


