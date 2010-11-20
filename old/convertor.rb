require 'syntax/convertors/abstract'

module Syntax
  module Convertors
    class Meta < Abstract
      def type= new_type
        @tokenizer.type = new_type
      end
      def type
        @tokenizer.type
      end
      def virtual_root= new_value
        @tokenizer.virtual_root = new_value
      end
      def virtual_root; @tokenizer.virtual_root; end
      def follow_includes= new_value
        @tokenizer.follow_includes = new_value
      end
      def swallow= new_value
        @tokenizer.swallow = new_value
      end
      attr_accessor :start_group
      def convert text, filename
        @tokenizer.filename = filename
        @tokenizer.start( text ) do |token|
          start_group.call token.group, token
        end
        @tokenizer.step until @tokenizer.eos?
        @tokenizer.finish
      end
    end
    class CodeTree < Abstract
      def type= new_type
        @tokenizer.type = new_type
      end
      def type
        @tokenizer.type
      end
      def virtual_root; @tokenizer.virtual_root; end
      def virtual_root= new_value
        @tokenizer.virtual_root = new_value
      end
      def follow_includes= new_value
        @tokenizer.follow_includes = new_value
      end
      def swallow= new_value
        @tokenizer.swallow = new_value
      end
      def convert text, filename
        @text = text
        @filename = filename
        VbScriptRaccParser.new.run_parse self, :go
      end
      def go
        @tokenizer.filename = @filename
        @tokenizer.start( @text ) do |token|
          if $DEBUG
            if token.group.is_a? Symbol then
              puts "Yielding :#{token.group} for '#{token}'"
            else
              puts "Yielding characters for '#{token}'"
            end
          end
          yield [token.group, token] unless token.group == :token_sep
        end
        @tokenizer.step until @tokenizer.eos?
        @tokenizer.finish
        puts "Yielding final :fake_newline" if $DEBUG
        yield [:fake_newline, nil]
        puts "Yielding EOF" if $DEBUG
        yield [false, false]
      end
    end
  end
end
