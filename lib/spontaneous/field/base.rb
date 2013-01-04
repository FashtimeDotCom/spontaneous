module Spontaneous
  module Field
    class Base
      module ClassMethods
        def has_editor
          define_singleton_method(:editor_class) { ui_class }
        end

        def register(*labels)
          labels = self.labels if labels.empty?
          # logger.debug("Registering #{self} as #{labels.join(", ")}")
          Field.register(self, *labels)
          self
        end

        def labels
          [self.name.demodulize.gsub(/Field$/, '').underscore]
        end

        def inherited(subclass, real_caller = nil)
          if self.respond_to?(:editor_class)
            editor_class = self.editor_class
            subclass.singleton_class.send(:define_method, :editor_class) do
              editor_class
            end
          end
        end

        def prototype=(prototype)
          @prototype = prototype
        end

        def prototype
          @prototype
        end

        def accepts
          %w(text/.+)
        end

        def accepts?(mime_type)
          accepts.find do |pattern|
            Regexp.new(pattern).match(mime_type)
          end
        end

        # Provides the ability for specific field types to customize the schema values
        # they return to the UI
        def export(user)
          {}
        end
      end

      extend ClassMethods

      attr_accessor :owner, :name, :unprocessed_value, :template_params, :version
      attr_reader   :processed_values

      alias_method :values, :processed_values


      def initialize(params={}, from_db=false)
        @processed_values = {}
        load(params, from_db)
      end


      def outputs
        [:html, :plain]
      end

      def unprocessed_value=(v)
        set_unprocessed_value(v)
        unless @preprocessed
          @modified = (@initial_value != v)
          increment_version if @modified
          self.processed_values = generate_outputs(@unprocessed_value)
          owner.field_modified!(self) if owner
        end
      end

      def increment_version
        self.version += 1
      end

      def version
        @version ||= 0
      end

      # value used to show conflicts between the current value and the value they're attempting to enter
      def conflicted_value
        unprocessed_value
      end

      def generate_outputs(value)
        values = {}
        value = preprocess(value)
        outputs.each do |output|
          process_method = "generate_#{output}"
          values[output] = \
            if respond_to?(process_method)
              send(process_method, value)
            else
              generate(output, value)
            end
        end
        values
      end

      # should be overwritten in subclasses that actually do something
      # with the field value
      def preprocess(value)
        value
      end

      HTML_ESCAPE_TABLE = {
        '&' => '&amp;'
      }

      def escape_html(value)
        value.to_s.gsub(%r{[#{HTML_ESCAPE_TABLE.keys.join}]}) { |s| HTML_ESCAPE_TABLE[s] }
      end

      def generate(output, value)
        value
      end

      # attr_accessor :values

      # override this to return custom values derived from (un)processed_value
      # alias_method :value, :processed_value
      def value(format=:html)
        processed_values[format.to_sym] || unprocessed_value
      end
      alias_method :processed_value, :value

      def image?
        false
      end

      def indexable_value
        unprocessed_value
      end

      def to_s(format = :html)
        value(format).to_s
      end

      def render(format=:html, *args)
        value(format)
      end

      def to_html(*args)
        render(:html, *args)
      end

      def to_pdf(*args)
        render(:pdf, *args)
      end

      def value=(value)
        self.unprocessed_value = value
      end

      def mark_unmodified
        @modified = nil
      end

      def modified?
        @modified
      end

      attr_accessor :prototype
      # def prototype
      #   self.class.prototype
      # end

      def schema_id
        self.prototype.schema_id
      end


      def schema_name
        self.prototype.schema_name
      end

      def schema_owner
        self.prototype.owner
      end

      def owner_sid
        schema_owner.schema_id
      end

      def serialize_db
        S::Field.serialize_field(self)
      end

      def update(params={})
        params.each do |property, value|
          setter = "#{property}=".to_sym
          if respond_to?(setter)
            self.send(setter, value)
          end
        end
      end

      # def start_inline_edit_marker
      #   "spontaneous:previewedit:start:field id:#{owner.id} name:#{self.name}"
      # end
      # def end_inline_edit_marker
      #   "spontaneous:previewedit:end:field id:#{owner.id} name:#{self.name}"
      # end

      def export(user)
        {
        :name => name.to_s,
        :id => schema_id.to_s,
        :unprocessed_value => unprocessed_value,
        :processed_value => ui_preview_value,
        :version => version
        }
      end

      def ui_preview_value
        value(:html)
      end

      def inspect
        %(#<#{self.class.name}:#{self.object_id} #{self.serialize_db.inspect}>)
      end

      def blank?
        unprocessed_value.blank?
      end

      alias_method :empty?, :blank?


      def or(field)
        return field if self.blank?
        self
      end

      alias_method :'/', :or
      alias_method :'|', :or

      def versions
        owner.field_versions(self)
      end

      def previous_version
        versions.first
      end

      def create_version
        Spontaneous::Field::FieldVersion.create(
          :content_id => owner.id,
          :field_sid => self.schema_id.to_s,
          :version => version,
          :value => @initial_value,
          :user => owner.current_editor)
      end

      protected

      def load(params={}, from_db=false)
        with_preprocessed_values(from_db) do
          params.each do |property, value|
            setter = "#{property}=".to_sym
            if respond_to?(setter)
              self.send(setter, value)
            end
          end
        end
      end

      def processed_values=(values)
        @processed_values = values
      end

      def with_preprocessed_values(state=true)
        @preprocessed = state
        yield
      ensure
        @preprocessed = nil
      end

      def set_unprocessed_value(new_value)
        # initial_value should only be set once so that it can act as a test for field modification
        @initial_value ||= new_value
        @unprocessed_value = new_value
      end

      def method_missing(method, *args)
        if outputs.include?(method)
          value(method)
        else
          super
        end
      end
    end
  end
end
