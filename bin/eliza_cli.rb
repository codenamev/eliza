#!/usr/bin/env ruby
# frozen_string_literal: true
#
# eliza_cli - eliza command line interface
#
# usage: eliza_cli.rb [--input FILE] [--script FILE] [--test]
#
# Type *cacm at the prompt to replay the conversation from the 1966 CACM
# paper. End the session with Ctrl-D.

require "optparse"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "eliza"

options = {
  input: $stdin,
  script: File.expand_path("../lib/eliza/scripts/original-1966-cacm.txt", __dir__)
}

OptionParser.new do |parser|
  parser.banner = "usage: eliza_cli.rb [--input FILE] [--script FILE] [--test]"
  parser.on("-i", "--input FILE", "read patient input from FILE") { |f| options[:input] = File.open(f) }
  parser.on("-s", "--script FILE", "use the ELIZA script in FILE") { |f| options[:script] = f }
  parser.on("-t", "--test", "reproduce the 1966 CACM conversation and exit") { options[:test] = true }
end.parse!

script_text = File.read(options[:script])

if options[:test]
  engine = Eliza::Engine.new(Eliza::Script.parse(script_text))
  failures = 0
  Eliza::CACM_1966_CONVERSATION.each do |prompt, expected|
    actual = engine.response(prompt)
    status = actual == expected ? "ok  " : "FAIL"
    failures += 1 unless actual == expected
    puts "#{status} > #{prompt}"
    puts "#{status}   #{actual}"
    puts "     expected: #{expected}" unless actual == expected
  end
  puts failures.zero? ? "\nAll tests passed." : "\n#{failures} failure(s)."
  exit failures.zero? ? 0 : 1
end

$stdout.sync = true
engine = Eliza::Engine.new(Eliza::Script.parse(script_text))
puts engine.greeting
print "\n* "
options[:input].each_line do |line|
  input = line.strip
  puts input if options[:input].is_a?(File)
  if input == "*cacm"
    # replay the conversation from the 1966 CACM paper on a fresh engine
    cacm = Eliza::Engine.new(Eliza::Script.parse(script_text))
    Eliza::CACM_1966_CONVERSATION.each do |prompt, _|
      puts "* #{prompt}"
      puts cacm.response(prompt)
    end
  elsif !input.empty?
    puts engine.response(input)
  end
  print "\n* "
end
puts
