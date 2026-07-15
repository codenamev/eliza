# frozen_string_literal: true

module Eliza
  # A parsed ELIZA script: greeting, keyword rules, the MEMORY rule, the
  # NONE rule and the DLIST tag map (e.g. "FAMILY" -> [MOTHER, FATHER, ...]).
  class Script
    attr_reader :greeting, :rules, :memory_rule, :none_rule, :tags

    def self.parse(text)
      new(text)
    end

    def initialize(text)
      @greeting = nil
      @rules = {}
      @memory_rule = nil
      @none_rule = nil
      Eliza.read_expressions(text).each { |expression| absorb(expression) }
      @greeting ||= "HELLO"
      @tags = collect_tags
    end

    private

    def absorb(expression)
      return unless expression.is_a?(Array) # skip bare atoms such as START
      return if expression.empty?           # () marks the end of the script

      if @greeting.nil? # the script begins with the greeting
        @greeting = expression.join(" ")
      elsif expression[0] == "MEMORY"
        @memory_rule = MemoryRule.parse(expression)
      else
        rule = KeywordRule.parse(expression)
        if rule.keyword == "NONE"
          # NONE is reserved: typing the word NONE must not trigger it
          @none_rule = rule
        else
          @rules[rule.keyword] = rule
        end
      end
    end

    # e.g. "FAMILY" -> ["MOTHER", "MOM", "DAD", "FATHER", ...]
    def collect_tags
      @rules.each_value.with_object({}) do |rule, tags|
        rule.dlist_tags.each { |tag| (tags[tag] ||= []).push(rule.keyword) }
      end
    end
  end
end
