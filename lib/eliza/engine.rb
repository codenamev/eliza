# frozen_string_literal: true

module Eliza
  # The core ELIZA algorithm [1966 CACM paper, pages 37-42].
  class Engine
    def initialize(script)
      @script = script
      @limit = 1 # "a certain counting mechanism" -- cycles 1..4 per response
    end

    def greeting
      @script.greeting
    end

    def response(input)
      words = Eliza.split_user_input(input)
      @limit = @limit % 4 + 1

      keystack = scan(words)

      # No keywords: recall a memory, but only when LIMIT is 4 [page 41 (f)]
      if keystack.empty? && @limit == 4 && @script.memory_rule&.memory?
        return @script.memory_rule.recall
      end

      transform(keystack, words) || none_response(words)
    end

    private

    # Scan for keywords, building the keystack and applying word
    # substitutions in place [page 39 (a), (d)]. Only the first clause
    # containing a keyword is kept [page 37 (c)].
    def scan(words)
      keystack = []
      top_rank = 0
      index = 0
      while index < words.size
        word = words[index]
        if DELIMITERS.include?(word)
          if keystack.empty?
            words.shift(index + 1) # no keyword yet: discard through delimiter
            index = 0
          else
            words.pop(words.size - index) # keyword found: discard the rest
            break
          end
          next
        end
        if (rule = @script.rules[word])
          if rule.transformation?
            if rule.precedence > top_rank
              keystack.unshift(word)
              top_rank = rule.precedence
            else
              keystack.push(word)
            end
          end
          words[index] = rule.substitution if rule.substitution
        end
        index += 1
      end
      keystack
    end

    # Apply the transformation for the top keyword [page 39 (d)].
    # Returns the reply, or nil when the NONE rule should speak instead.
    def transform(keystack, words)
      while (keyword = keystack.shift)
        rule = @script.rules[keyword]
        return NOMATCH_MESSAGES[@limit - 1] unless rule # broken reference

        @script.memory_rule&.create(keyword, words, @script.tags)

        action, target = rule.apply(words, @script.tags)
        case action
        when :complete
          return words.join(" ")
        when :inapplicable # no decomposition matched: script error
          return NOMATCH_MESSAGES[@limit - 1]
        when :link
          keystack.unshift(target)
        when :newkey
          next # try the next keyword in the keystack
        end
      end
      nil # no keywords, or NEWKEY exhausted the keystack
    end

    # "the special reserved keyword NONE" never fails to reply [page 41 (d)]
    def none_response(words)
      @script.none_rule.apply(words, @script.tags)
      words.join(" ")
    end
  end
end
