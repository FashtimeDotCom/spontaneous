# encoding: UTF-8


module Spontaneous::Render
  module Context

    attr_reader :format, :target

    def initialize(target, format, params={})
      @target, @format, @params = target, format, params
      _update(params) if params.is_a?(Hash)
    end

    def page
      target.page
    end

    def template
      target.template(format)
    end

    def each
      content.each { |c| yield(c) } if block_given?
    end

    def each_with_index
      content.each_with_index { |c, i| yield(c, i) } if block_given?
    end

    def map
      content.map { |c| yield(c) } if block_given?
    end

    def content
      target.iterable
    end

    def pieces
      content
    end

    def first
      content.first
    end

    def last
      content.last
    end

    def first?
      target.container.pieces.first == self
    end

    def last?
      target.container.pieces.last == self
    end

    # def position
    #   target.container.visible_pieces.index(self) if target.container
    # end

    # TODO: replace the use of _content with a iterator by using #each & Enumerable
    def render_content
      target.map do |c|
        c.render(format)
      end.join("\n")
    end

    def render(format, *args)
      target.render(format, *args)
    end

    def respond_to?(method)
      super || target.respond_to?(method)
    end

    protected

    def method_missing(method, *args)
      key = method.to_sym
      # if target.respond_to?(method)
      #   if block_given?
      #     target.__send__(method, *args, &Proc.new)
      #   else
      #     target.__send__(method, *args)
      #   end

      if target.field?(key)
        target.send(key, *args)
      elsif target.box?(key)
        # WHY do I have to wrap boxes in a context? Is there anyway of removing this
        # need for a context wrapper from everything? Is it just there to pass along the current
        # format??
        self.class.new(target.boxes[key], format, @params)
      else
        if block_given?
          target.__send__(method, *args, &Proc.new)
        else
          target.__send__(method, *args)
        end
      end
    rescue => e
      # TODO: sensible, configurable fallback for when template calls non-existant method
      # - logging.warn when happens
      # - an inline comment when in dev mode?
      # - some placeholder text, perhaps the name of the missing method and line no.
      nil
    end

    # make each key of the params hash into a method call for speed
    def _update(params)
      params.each do |key, val|
        meta.__send__(:define_method, key) { val }
      end
    end
  end
end

