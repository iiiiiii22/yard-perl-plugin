module YARD
  module Parser
    module Perl

      class Line
        attr_reader :file, :text, :line

        def initialize(file, text, line)
          @file = file
          @text = text
          @line = line
        end

        def ==(other)
          self.class == other.class &&
          @file == other.file &&
          @text == other.text &&
          @line == other.line
        end

        def show
          "\t#{@text}: #{@text.split[0]}"
        end
      end

      class Comment < Line
        def read
          @text.gsub(/^\s*#[ \t]?/, '')
        end
      end

      class Package < Line
        attr_accessor :comments

        def initialize(*args)
          super *args
          @comments = ''
        end

        def comments_range
          (@line - @comments.split.length)...@line
        end

        def namespace
          @text[/package (.*)::.*;/, 1]
        end

        def classname
          @text[/package .*::(.*);/, 1]
        end
      end

      class Sub < Line
        attr_accessor :comments
        attr_accessor :visibility

        def initialize(*args)
          super *args
          @comments = ''
        end

        def visibility
          @visibility ||= name.start_with?('_') ? :protected : :public
        end

        def comments_range
          (@line - @comments.split.length)...@line
        end

        def name
          @text[/sub ([\w_]+)/, 1]
        end
      end

      class << self
        def parse(content, file='(string)')
          line = 0
          @stack = content.lines.collect do |src|
            case src
            when /^\s*use namespace::clean;/
              :private
            when /^\s*#/
              Comment.new(file, src, line += 1)
            when /^\s*package/
              Package.new(file, src, line += 1)
            when /^\s*sub/
              Sub.new(file, src, line += 1)
            else
              Line.new(file, src, line += 1)
            end
          end

          reduce_stack

          self
        end

        def enumerator
          @stack
        end

        private

        def prepare_method(element)
          if @method
            @method = false if element.text =~ /^#{@method}\}\s*$/
          else
            @method = $1 || '' unless element.text =~ /^(\s*)sub.*\}\s*$/
          end
        end

        def reduce_stack
          @method = false

          @stack = @stack.reduce([]) do |stack, element|
            if stack.empty?
              prepare_method(element) if element.is_a? Sub
            elsif @method
              prepare_method(element)
              stack.last.text << element.text
              next stack
            else
              last = stack.last

              case element
              when :private
                stack.select { |e| e.is_a? Sub }.each { |e| e.visibility = :private }
              when Package
                element.comments = last.read if last.is_a? Comment
              when Sub
                element.comments = last.read if last.is_a? Comment
                prepare_method(element)
              when Comment
                if last.is_a? Comment
                  last.text << element.text
                else
                  stack << element
                end
                next stack
              end
            end

            stack << element
          end

          warn 'Whoops! Misparsed something...' if @method
        end
      end
    end
  end
end