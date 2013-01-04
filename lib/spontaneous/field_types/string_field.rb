# encoding: UTF-8

module Spontaneous
  module FieldTypes
    class StringField < Field
      has_editor

      def preprocess(value)
        Spontaneous::Utils::SmartQuotes.smarten(value.to_s)
      end

      def generate_html(value)
        escape_html(value)
      end
    end

    StringField.register :string, :title
  end
end
