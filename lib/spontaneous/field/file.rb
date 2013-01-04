# encoding: UTF-8

require 'tempfile'

module Spontaneous::Field
  class File < Base
    has_editor

    def outputs
      [:html, :filesize, :filename]
    end

    def preprocess(image_path)
      filename = mimetype = nil
      case image_path
      when Hash
        mimetype = image_path[:type]
        filename = image_path[:filename]
        image_path = image_path[:tempfile].path
      when ::String
        filename = ::File.basename(image_path)
      end
      return image_path unless ::File.exist?(image_path)

      media_file = Spontaneous::Media::File.new(owner, filename, mimetype)
      media_file.copy(image_path)
      set_unprocessed_value(filename)
      media_file
    end

    def generate_filesize(input)
      if input.respond_to?(:filesize)
        input.filesize
      else
        if ::File.exist?(input)
          ::File.size(input)
        else
          0
        end
      end
    end

    def generate_filename(input)
      if input.respond_to?(:filename)
        input.filename
      else
        ::File.basename(input.to_s)
      end
    end

    def generate_html(input)
      return input if input.is_a?(::String)
      input.url
    end

    def export(user = nil)
      super(user).merge({
        :processed_value => processed_values
      })
    end

    def path
      value(:html)
    end

    self.register
  end
end
