# frozen_string_literal: true

module Eliza
  # The one MEMORY rule, e.g. (MEMORY MY (0 YOUR 0 = LETS DISCUSS FURTHER
  # WHY YOUR 3) ...). When its keyword tops the keystack a memory is formed
  # using the rule selected by the SLIP HASH of the last word of the input
  # [the MAD-SLIP source; the paper says "selected at random", page 41 (f)].
  class MemoryRule
    def initialize(keyword, transformations)
      @keyword = keyword
      @transformations = transformations
      @memories = []
    end

    def self.parse(expression)
      keyword = expression[1]
      transformations = expression.drop(2).map do |list|
        separator = list.index("=")
        Transformation.new(
          Transformation.decomposition_pattern(list[0...separator]),
          [[:text, Transformation.text_parts(list[separator + 1..])]]
        )
      end
      new(keyword, transformations)
    end

    def create(keyword, words, tags)
      return unless keyword == @keyword

      transformation = @transformations[Eliza.slip_hash(Eliza.last_chunk_as_bcd(words.last), 2)]
      constituents = Eliza.match(tags, transformation.decomposition, words)
      return unless constituents

      @memories.push(Eliza.reassemble(transformation.reassemblies[0][1], constituents).join(" "))
    end

    def memory?
      !@memories.empty?
    end

    def recall
      @memories.shift
    end
  end
end
