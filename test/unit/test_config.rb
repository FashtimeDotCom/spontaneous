# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)

class ConfigTest < MiniTest::Spec
  include CustomMatchers
  def setup
    @site = setup_site
  end

  def teardown
    teardown_site
  end

  context "Config" do
    setup do
      @config_dir = File.expand_path("../../fixtures/config/config", __FILE__)

      class ::TopLevel
        def self.parameter=(something)
          @parameter = something
        end

        def self.parameter
          @parameter
        end
      end
    end

    teardown do
      Object.send(:remove_const, :TopLevel) rescue nil
    end

    context "Config" do
      setup do
        @config = Spontaneous::Config.new(:development)
        @config.load(@config_dir)
      end
      should "load the first time its accessed" do
        @config.over_ridden.should == :development_value
      end
    end

    context "containing blocks" do
      setup do
        @settings = {}
        @config = Spontaneous::Config::Loader.new(@settings)
      end
      should "add a hash to the settings under the defined key" do
        @config.storage :key1 do |config|
          config[:a] = "a"
          config[:b] = "b"
        end
        @config.storage :key2 do |config|
          config[:c] = "c"
          config[:d] = "d"
        end
        @config.storage :key1 do |config|
          config[:e] = "e"
        end
        @config.settings[:storage].should == {
          :key1 => { :a => "a", :b => "b", :e => "e" },
          :key2 => { :c => "c", :d => "d" }
        }
      end
    end
    context "Independent configuration loading" do
      setup do
        # defined?(Spontaneous).should be_nil
        # Object.send(:remove_const, :Spontaneous) rescue nil
        # defined?(Spontaneous).should be_nil
        # require @lib_dir + '/spontaneous/config.rb'
        # Config.environment = :development
        @config = Spontaneous::Config.new(:development)
        @config.load(@config_dir)
      end

      teardown do
      end

      should "be run from application dir" do
        File.exist?('config').should be_true
      end

      should "read from the global environment file" do
        @config.some_configuration.should == [:some, :values]
      end

      should "initialise in development mode" do
        @config.environment.should == :development
      end

      # should "allow setting of environment" do
      #   Config.environment.should == :development
      #   Config.environment = :production
      #   Config.environment.should == :production
      # end

      should "overwrite values depending on environment" do
        @config.over_ridden.should == :development_value
        config = Spontaneous::Config.new(:production)
        config.load(@config_dir)
        config.over_ridden.should == :production_value
        config = Spontaneous::Config.new(:staging)
        config.load(@config_dir)
        config.over_ridden.should == :environment_value
      end

      should "allow setting of env values" do
        @config.something_else.should be_nil
        @config[:something_else] = "loud"
        @config.something_else.should == "loud"
      end

      should "allow setting of env values through method calls" do
        @config.something_else2.should be_nil
        @config.something_else2 = "loud"
        @config.something_else2.should == "loud"
      end

      should "dynamically switch values according to the configured env" do
        @config.over_ridden.should == :development_value
        config = Spontaneous::Config.new(:production)
        config.load(@config_dir)
        config.over_ridden.should == :production_value
        config = Spontaneous::Config.new(:staging)
        config.load(@config_dir)
        config.over_ridden.should == :environment_value
      end

      should "allow local over-riding of settings" do
        @config.wobbling.should be_nil
        @config.wobbling = "badly"
        @config.wobbling.should == "badly"
      end

      should "fallback to defaults" do
        @config.new_setting.should be_nil
        @config.defaults[:new_setting] = "new setting"
        @config.new_setting.should == "new setting"
      end

      should "accept blocks/procs/lambdas as values" do
        fish = "flying"
        @config.useful_feature = Proc.new { fish }
        @config.useful_feature.should == "flying"
        @config.defaults[:new_dynamic_setting] = Proc.new { fish }
        @config.new_dynamic_setting.should == "flying"
      end

      should "allow calling of global methods" do
        TopLevel.parameter.should == :dev
      end

      teardown do
      end

      context "Spontaneous :back" do
        setup do
          @config = Spontaneous::Config.new(:development, :back)
          @config.load(@config_dir)
        end
        should "read the correct configuration values" do
          @config.port.should == 9001
        end
      end
      context "Spontaneous :front" do
        setup do
          @config = Spontaneous::Config.new(:development, :front)
          @config.load(@config_dir)
        end
        should "read the correct configuration values" do
          @config.port.should == 9002
        end
      end
    end
  end
end
