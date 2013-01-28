# encoding: UTF-8

require 'sass'

module Spontaneous::Output::Helpers
  module StylesheetHelper
    extend self

    def stylesheets(*args)
      stylesheets = args.flatten
      options = stylesheets.extract_options!
      compress_stylesheets = (live? or (publishing? and options[:force_compression]))

      return compressed_stylesheets(stylesheets) if compress_stylesheets

      stylesheets.map do |stylesheet|
        stylesheet_tag(stylesheet)
      end.join("\n")
    end

    alias_method :stylesheet, :stylesheets

    def stylesheet_tag(href)
      href = "#{href}.css" unless href =~ /\.css$/o
      %(<link rel="stylesheet" href="#{href}" />)
    end

    def compressed_stylesheets(stylesheets)
      file_paths = stylesheets.map { |style| [style, S::Output::Assets.find_file("#{style}.scss", "#{style}.css")] }
      invalid, file_paths = file_paths.partition { |url, path| path.nil? }
      roots = Spontaneous.instance.paths.expanded(:public)

      tags = []
      css = file_paths.map { |url, path|
        case path
        when /\.scss$/o
          load_paths = roots + [File.dirname(path), File.dirname(path) / "sass"]
          ::Sass::Engine.for_file(path, {
            :load_paths => load_paths,
            :cache => false,
            :style => :compressed
          }).render
        else
          File.read(path)
        end
      }.join
      compressed, hash = compress_css_string(css)
      output_path = Spontaneous::Output::Assets.path_for(revision, "#{hash}.css")
      FileUtils.mkdir_p(File.dirname(output_path))
      File.open(output_path, "w") { |file| file.write(compressed) }
      tags = [stylesheet_tag(Spontaneous::Output::Assets.url(hash))]
      tags.join("\n")
    end

    def compress_css_string(css_string)
      Spontaneous::Output::Assets::Compression.compress_css_string(css_string)
    end

    Spontaneous::Output::Helpers.register_helper(self, :html)
  end
end
