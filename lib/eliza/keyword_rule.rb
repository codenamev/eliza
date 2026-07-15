# frozen_string_literal: true

module Eliza
  # A keyword and its transformation rules, e.g.
  #   (MY = YOUR 2
  #       ((0 YOUR 0 (/FAMILY) 0)
  #           (TELL ME MORE ABOUT YOUR FAMILY) ...) ...)
  class KeywordRule
    attr_reader :keyword, :substitution, :precedence, :dlist_tags, :link

    def initialize(keyword, substitution: nil, precedence: 0, dlist_tags: [],
                   link: nil, transformations: [])
      @keyword = keyword
      @substitution = substitution
      @precedence = precedence
      @dlist_tags = dlist_tags
      @link = link
      @transformations = transformations
    end

    # (=KEY) and (= KEY) both reference the rule for KEY
    def self.reference_target(list)
      return nil unless list.is_a?(Array) && list[0].is_a?(String)
      return list[1] if list[0] == "=" && list.size == 2
      return list[0][1..] if list.size == 1 && list[0].start_with?("=")

      nil
    end

    def self.parse(expression)
      items = expression.dup
      keyword = items.shift
      options = { transformations: [] }
      until items.empty?
        item = items.shift
        if item == "="
          options[:substitution] = items.shift
        elsif item == "DLIST"
          options[:dlist_tags] = items.shift.flat_map { |t| t == "/" ? [] : [t.delete_prefix("/")] }
        elsif item.is_a?(String) && item.match?(/\A\d+\z/)
          options[:precedence] = item.to_i
        elsif (target = reference_target(item))
          options[:link] = target
        else
          options[:transformations].push(Transformation.parse(item))
        end
      end
      new(keyword, **options)
    end

    # only keywords with transformations (or a reference) join the keystack
    def transformation?
      !@transformations.empty? || !@link.nil?
    end

    # Apply this rule to words (in place for :complete and :pre).
    # Returns [:complete], [:link, keyword], [:newkey] or [:inapplicable].
    def apply(words, tags)
      transformation, constituents = decompose(words, tags)
      unless transformation
        return @link ? [:link, @link] : [:inapplicable]
      end

      kind, *payload = transformation.next_reassembly
      case kind
      when :newkey
        [:newkey]
      when :link
        [:link, payload[0]]
      when :pre # (PRE (reassembly) (=KEY)): transform, then go to KEY
        words.replace(Eliza.reassemble(payload[0], constituents))
        [:link, payload[1]]
      else # :text
        words.replace(Eliza.reassemble(payload[0], constituents))
        [:complete]
      end
    end

    private

    # first decomposition rule matching words, with its matched constituents
    def decompose(words, tags)
      @transformations.each do |transformation|
        constituents = Eliza.match(tags, transformation.decomposition, words)
        return [transformation, constituents] if constituents
      end
      [nil, nil]
    end
  end
end
