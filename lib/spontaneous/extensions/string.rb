# encoding: UTF-8


module Spontaneous
  module Extensions
    module String
      def /(path)
        File.join(self, path.to_s)
      end

      def or(alternative)
        return alternative if empty?
        self
      end

      alias_method :'|', :or

      def value(format = :html)
        self
      end

      HTML_ESCAPE_TABLE = {
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        "'" => '&#039;',
      }

      def escape_html
        self.gsub(%r{[#{HTML_ESCAPE_TABLE.keys.join}]}) { |s| HTML_ESCAPE_TABLE[s] }
      end

      JS_ESCAPE_MAP = {
        '\\' => '\\\\',
        '</' => '<\/',
        "\r\n" => '\n',
        "\n" => '\n',
        "\r" => '\n',
        '"' => '\\"',
        "'" => "\\'"
      } unless defined?(JS_ESCAPE_MAP)

      def escape_js
        self.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }
      end

      # Makes it easier to pass either a field or a String around
      # in templates
      def to_html
        self
      end
    end
  end
end


class String
  include Spontaneous::Extensions::String
end
