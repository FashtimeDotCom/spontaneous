# encoding: UTF-8

require 'sinatra/base'

module Spontaneous
  module Rack
    module Front
      include Spontaneous::Rack::Middleware
      def self.front_app
        ::Rack::Builder.app do
          use Scope::Front
          use Reloader if Spontaneous.development?
          run Server.new
        end
      end

      def self.application
        app = ::Rack::Builder.new do
          use Spontaneous::Rack::Static, :root => Spontaneous.revision_dir / "public",
            :urls => %w[/],
            :try => ['.html', 'index.html', '/index.html']

          Spontaneous.instance.front_controllers.each do |namespace, controller_class|
            map namespace do
              run controller_class
            end
          end if Spontaneous.instance

          # Make all the files available under plugin_name/public/**
          # available under the URL /plugin_name/**
          # Only used in preview mode
          Spontaneous.instance.plugins.each do |plugin|
            map "/#{plugin.name}" do
              run ::Rack::File.new(plugin.paths.expanded(:public))
            end
          end if Spontaneous.instance

          map "/rev" do
            run Spontaneous::Rack::CacheableFile.new(Spontaneous.revision_dir / "rev")
          end

          map "/media" do
            run Spontaneous::Rack::CacheableFile.new(Spontaneous.media_dir)
          end

          map "/" do
            run Spontaneous::Rack::Front.front_app
          end
        end
      end

      class Server < Sinatra::Base
        include Spontaneous::Rack::Public

        def call!(env)
          @env = env
          @response = ::Sinatra::Response.new
          @request  = ::Sinatra::Request.new(env)
          @params   = indifferent_params(@request.params)

          render_path(@request.path_info)
        end
      end
    end
  end
end
