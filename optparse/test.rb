require_relative '../rerunner/rerunner.rb'

require 'optparse'


class OptionParser::OptionMap
  def complete(key, icase = false, pat = nil)
    # disable completions
    nil
  end
end

args = ["-h", "world"]

OptionParser.new do |opts|
  opts.on("-h", "--hello=NAME", "say hello") do |v|
    puts "got hello"
    puts v
  end
end.parse!(args)

