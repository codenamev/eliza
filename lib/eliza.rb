# frozen_string_literal: true
#
# ELIZA -- a faithful Ruby reconstruction of Joseph Weizenbaum's 1966
# ELIZA/DOCTOR program.
#
# The algorithm follows Weizenbaum's description in "ELIZA - A Computer
# Program For the Study of Natural Language Communication Between Man And
# Machine", Communications of the ACM, January 1966, including details
# recovered from the original MAD-SLIP source code found in the Weizenbaum
# archives at MIT (the keystack, the BUT delimiter, the LIMIT counter, the
# SLIP HASH memory selection and the built-in no-match messages), as
# documented by Anthony Hay's C++ reconstruction:
# https://github.com/anthay/ELIZA (CC0). See also https://elizagen.org.
#
# The browser build embeds a copy of this library in docs/index.html;
# regenerate it with: ruby bin/build_site.rb

module Eliza
  # "the procedure recognizes a comma or a period as a delimiter" [page 37].
  # The MAD-SLIP source shows the word BUT is also treated as a delimiter.
  DELIMITERS = [",", ".", "BUT"].freeze

  # Weizenbaum's built-in responses, used when a script problem prevents a
  # reply being generated. Selected by the LIMIT counter, which cycles 1..4.
  NOMATCH_MESSAGES = ["PLEASE CONTINUE", "HMMM", "GO ON , PLEASE", "I SEE"].freeze

  # IBM 7090/7094 six-bit BCD (Hollerith) character codes. ELIZA ran on a
  # 7094; the MEMORY mechanism hashes words in this encoding.
  HOLLERITH = {}.tap do |h|
    "0123456789".each_char.with_index { |c, i| h[c] = i }
    h["="] = 0o13
    h["'"] = 0o14
    h["+"] = 0o20
    ("A".."I").each_with_index { |c, i| h[c] = 0o21 + i }
    h["."] = 0o33
    h[")"] = 0o34
    h["-"] = 0o40
    ("J".."R").each_with_index { |c, i| h[c] = 0o41 + i }
    h["$"] = 0o53
    h["*"] = 0o54
    h[" "] = 0o60
    h["/"] = 0o61
    ("S".."Z").each_with_index { |c, i| h[c] = 0o62 + i }
    h[","] = 0o73
    h["("] = 0o74
  end.freeze

  module_function

  # Uppercase the text and reduce it to the BCD character set, mapping
  # punctuation ELIZA never saw (?, !, colons, dashes, fancy quotes) onto
  # the delimiters it did, as the keypunch operator effectively had to.
  def normalize(text)
    mapped = +""
    text.each_char do |ch|
      case ch
      when "’"                                    then mapped << "'"
      when "‘", "`", '"', "“", "”", "«", "»", "‹", "›", "‚", "‛", "„", "‟" then mapped << " "
      when "!", "?"                               then mapped << "."
      when ":", ";", "–", "—"                     then mapped << ","
      else mapped << ch
      end
    end
    mapped.upcase.gsub(%r{[^A-Z0-9='+.)($*/,\- ]}, " ")
  end

  # Split normalized text into words; commas and periods are words too.
  # e.g. "MEN ARE ALL ALIKE." -> ["MEN", "ARE", "ALL", "ALIKE", "."]
  def split_user_input(text)
    normalize(text).gsub(/([.,])/, ' \1 ').split
  end

  # The 36-bit BCD encoding of the last SLIP cell of a word: its last chunk
  # of up to six characters, space padded. e.g. "INVENTED" -> "ED    "
  def last_chunk_as_bcd(word)
    chunk = word.empty? ? "" : word[((word.length - 1) / 6) * 6..]
    chunk.ljust(6).each_char.reduce(0) { |acc, c| (acc << 6) | HOLLERITH.fetch(c, c.ord & 0x3F) }
  end

  # The SLIP HASH function: the middle n bits of the square of the least
  # significant 35 bits of d (von Neumann mid-square).
  def slip_hash(d, n)
    d &= 0x7FFFFFFFF
    ((d * d) >> (35 - n / 2)) & ((1 << n) - 1)
  end

  # Match words against a decomposition pattern [page 38 (a)].
  # Pattern elements: 0 (any number of words, leftmost-shortest), a positive
  # integer n (exactly n words), a literal word, [:any, words] for
  # (* WORD ...) groups, or [:tag, names] for (/TAG ...) groups.
  # Returns the matched constituents (one string per element) or nil.
  def match(tags, pattern, words)
    return words.empty? ? [] : nil if pattern.empty?

    element = pattern[0]
    rest = pattern[1..]
    case element
    when 0
      constituent = []
      remaining = words
      loop do
        tail = match(tags, rest, remaining)
        return [constituent.join(" ")] + tail if tail
        return nil if remaining.empty?

        constituent << remaining[0]
        remaining = remaining[1..]
      end
    when Integer
      return nil if words.size < element

      tail = match(tags, rest, words[element..])
      tail && [words[0, element].join(" ")] + tail
    else
      return nil if words.empty? || !first_word_fits?(element, words[0], tags)

      tail = match(tags, rest, words[1..])
      tail && [words[0]] + tail
    end
  end

  def first_word_fits?(element, word, tags)
    case element
    in [:any, group] then group.include?(word)
    in [:tag, names] then names.any? { |name| tags.fetch(name, []).include?(word) }
    else element == word
    end
  end

  # Assemble a reply from reassembly-rule parts: integers index the matched
  # constituents (1-based), everything else is literal text [page 38 (b)].
  def reassemble(parts, constituents)
    parts.flat_map do |part|
      if part.is_a?(Integer)
        part.between?(1, constituents.size) ? constituents[part - 1].split(" ") : ["HMMM"]
      else
        [part]
      end
    end
  end

  # -- script reading (the script is MAD-SLIP list structures) --------------

  # ';' starts a comment; '(' and ')' delimit lists; atoms are whitespace
  # delimited. Returns the top-level expressions as nested arrays of strings.
  def read_expressions(text)
    expressions = []
    stack = [expressions]
    text.each_line do |line|
      line.sub(/;.*/, "").scan(/[()]|[^\s()]+/) do |token|
        case token
        when "(" then stack.push(stack.last.push([]).last)
        when ")" then stack.pop
        else stack.last.push(token)
        end
      end
    end
    expressions
  end
end

require "eliza/transformation"
require "eliza/keyword_rule"
require "eliza/memory_rule"
require "eliza/script"
require "eliza/engine"
require "eliza/cacm_conversation"
