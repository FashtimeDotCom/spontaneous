# encoding: UTF-8

module Spontaneous::Model::Core
  module InstanceCode
    extend Spontaneous::Concern

    # InstanceMethods

    def after_initialize
      super
      mixin_instance_code
    end

    def mixin_instance_code
      self.instance_eval(self.instance_code) unless self.instance_code.nil?
    end
  end
end
