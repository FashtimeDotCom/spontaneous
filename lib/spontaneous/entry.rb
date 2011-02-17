# encoding: UTF-8


module Spontaneous
  class Entry < ProxyObject
    extend Plugins
    plugin Plugins::Render

    def self.find_target(container, id)
      if container
        container._pieces.find { |f| f.id == id }
      else
        Content[id]
      end


      ## the following results in infinite loops in some circumstances
      # if container.page
      #   container.page.content.find { |f| f.id == id }
      # else
      #   Content[id]
      # end
    end

    def self.page(container, page, entry_style, box = nil)
      create(PageEntry, container, page, entry_style, box)
    end

    def self.piece(container, piece, entry_style, box = nil)
      create(Entry, container, piece, entry_style, box)
    end


    def self.create(entry_class, container, content, entry_style, box = nil)
      content.save if content.new?
      entry = entry_class.new(container, content.id, entry_style ? entry_style.name : nil, box ? box.box_id : nil)
      entry.target = content
      entry
    end

    attr_accessor :piece_store
    attr_reader :box_id

    def initialize(container, target_id, style_name, box_id = nil)
      @container = container
      @target_id = target_id
      @entry_style_name = style_name.to_sym if style_name
      @box_id = box_id.to_sym if box_id
    end

    def box
      container.boxes.named(@box_id)
    end

    def each
      pieces.each { |c| yield(c) } if block_given?
    end

    def destroy(remove_container_entry=true, _container=nil)
      target.destroy(remove_container_entry, self.container)
    end

    attr_reader :container, :target_id

    def target
      @target ||= load_target
    end

    def label
      @label ||= read_label
    end

    def read_label
      l = target.label
      return nil if l.nil? or l.empty?
      target.label.to_sym
    end

    def pieces
      target.pieces
    end

    def first
      pieces.first
    end

    def first?
      container.pieces.first == self
    end

    def last
      pieces.last
    end

    def last?
      container.pieces.last == self
    end

    def set_position(new_position)
      if box
        box.set_position(self, new_position)
      else
        container.pieces.set_position(self, new_position)
      end
    end

    def position
      container.pieces.index(self)
    end

    def style
      if @entry_style_name
        target.styles[@entry_style_name]
      else
        target.style
      end
    end

    def template(format=:html)
      style.template(format)
    end

    def style=(style)
      style = target.styles[style] unless style.is_a?(Style)
      @entry_style_name = style.name
      target[:style_id] = style.name
      # because it's not obvious that a change to an entry
      # will affect the fields of the target piece
      # make sure that the target is saved using an instance hook
      @container.after_save_hook do
        target.save
      end
      @container.entry_modified!(self)
    end

    def style_name
      @entry_style_name
    end

    def load_target
      # Content[target_id].tap do |t|
      proxy_class.find_target(@container, @target_id).tap do |t|
        t.entry = self
      end
    end

    def target=(target)
      @target = target
    end

    def method_missing(method, *args)
      if block_given?
        self.target.__send__(method, *args, &Proc.new)
      else
        self.target.__send__(method, *args)
      end
    end

    def serialize
      {
        :type => self.proxy_class.name.demodulize,
        :id => target.id,
        :style => @entry_style_name,
        # TODO: remove reference to slot
        :slot => target.slot_id,
        :box_id => @box_id
      }
    end

    def inspect
      "#<#{self.proxy_class.name.demodulize}:#{self.object_id.to_s(16)} content=#{target} entry_style=\"#{@entry_style_name}\" label=\"#{label}\" box_id=\"#{@box_id}\">"
    end

    def to_hash
      target.to_hash.merge(styles_to_hash)
    end

    def styles_to_hash
      {
        :style => @entry_style_name.to_s,
        :styles => container.available_styles(target).map { |s| s.name.to_s },
      }
    end

    # oops, optimisation. sorry
    Content.instance_methods.sort.each do |method|
      unless method_defined?(method)
        define_method(method) { |*args, &block| target.__send__(method, *args, &block) }
      end
    end
  end
end
