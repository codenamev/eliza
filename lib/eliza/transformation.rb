# frozen_string_literal: true

module Eliza
  # One decomposition pattern with its reassembly rules. Reassembly rules
  # are cycled through in order, one per use, "so that a repertoire of 4
  # such rules is exhausted before any repetition occurs" [page 41].
  class Transformation
    attr_reader :decomposition, :reassemblies

    def initialize(decomposition, reassemblies)
      @decomposition = decomposition
      @reassemblies = reassemblies
      @next_reassembly = 0
    end

    def next_reassembly
      rule = @reassemblies[@next_reassembly]
      @next_reassembly = (@next_reassembly + 1) % @reassemblies.size
      rule
    end

    def self.decomposition_pattern(list)
      list.map do |element|
        if element.is_a?(Array)
          first = element[0].to_s
          rest = element.drop(1)
          names = ([first[1..]] + rest).reject { |w| w.nil? || w.empty? }
          first.start_with?("*") ? [:any, names] : [:tag, names]
        elsif element.match?(/\A\d+\z/)
          element.to_i
        else
          element
        end
      end
    end

    def self.text_parts(list)
      list.map { |part| part.match?(/\A\d+\z/) ? part.to_i : part }
    end

    def self.parse(list)
      decomposition = decomposition_pattern(list[0])
      reassemblies = list.drop(1).map do |rule|
        if rule == ["NEWKEY"]
          [:newkey]
        elsif (target = KeywordRule.reference_target(rule))
          [:link, target]
        elsif rule[0] == "PRE"
          [:pre, text_parts(rule[1]), KeywordRule.reference_target(rule[2])]
        else
          [:text, text_parts(rule)]
        end
      end
      new(decomposition, reassemblies)
    end
  end
end
