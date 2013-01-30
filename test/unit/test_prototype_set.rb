# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)


class PrototypeSetTest < MiniTest::Spec
  class Super < Struct.new(:prototypes); end
  context "Prototype Sets" do
    setup do
      @one = "One"
      @two = "Two"
      @three = "Three"
      @one.stubs(:schema_id).returns("one_id")
      @two.stubs(:schema_id).returns("two_id")
      @three.stubs(:schema_id).returns("three_id")
      @set = Spontaneous::Collections::PrototypeSet.new
      @set['one'] = @one
      @set[:two] = @two
      @set[:three] = @three
    end

    should "return correct value for empty? test" do
      @set.empty?.should be_false
      Spontaneous::Collections::PrototypeSet.new.empty?.should be_true
    end

    should "return the last value" do
      @set.last.should == "Three"
    end

    should "enable hash-like access by name" do
      @set[:three].should == "Three"
      @set['three'].should == "Three"
    end

    should "know the number of entries" do
      @set.length.should == 3
      @set.count.should == 3
    end

    should "enable array-like access by index" do
      @set[2].should == "Three"
    end

    should "have a list of names" do
      @set.keys.should == [:one, :two, :three]
      @set.names.should == [:one, :two, :three]
      @set.order.should == [:one, :two, :three]
    end

    should "have a list of values" do
      @set.values.should == ['One', 'Two', 'Three']
    end

    should "test for keys" do
      @set.key?(:one).should be_true
      @set.key?(:two).should be_true
    end

    should "enable access by schema id" do
      @set.sid("two_id").should == @two
    end

    should "have externally settable ordering" do
      @set.order = [:three, :two]
      @set.order.should == [:three, :two, :one]
      @set.map { |val| val }.should == ['Three', 'Two', 'One']
    end

    should "allow multiple setting of the order" do
      @set.order = [:three, :two]
      @set.order.should == [:three, :two, :one]
      @set.order = [:one, :three]
      @set.order.should == [:one, :three, :two]
    end

    should "have a hash-like map function" do
      @set.map { |val| val }.should == ["One", "Two", "Three"]
    end

    should "have a hash-like each function" do
      keys = []
      @set.each { |val| keys << val }
      keys.should == ["One", "Two", "Three"]
    end

    should "allow access to values as method calls" do
      @set.one.should == "One"
      @set.three.should == "Three"
      lambda { @set.nine }.must_raise(NoMethodError)
    end

    context "with superset" do
      setup do
        @superset = @set.dup
        # give the superset a custom order to make sure it propagates to the child set
        @superset.order = [:three, :one, :two]
        @super = Super.new
        @super.prototypes = @superset
        @set = Spontaneous::Collections::PrototypeSet.new(@super, :prototypes)
        @four = "Four"
        @five = "Five"
        @four.stubs(:schema_id).returns("four_id")
        @five.stubs(:schema_id).returns("five_id")
        @set[:four] = @four
        @set[:five] = @five
      end

      teardown do
      end

      should "inherit values from a super-set" do
        @set[:one].should == "One"
        @set[:five].should == "Five"
      end

      should "test for keys" do
        @set.key?(:one).should be_true
        @set.key?(:five).should be_true
      end

      should "test for local keys only" do
        @set.key?(:one, false).should be_false
        @set.key?(:five, false).should be_true
      end

      should "enable array-like access by index" do
        @set[3].should == "Four"
        @set[0].should == "Three"
      end

      should "have a list of names" do
        @set.names.should == [:three, :one, :two, :four, :five]
        @set.keys.should == [:three, :one, :two, :four, :five]
      end

      should "enable access by schema id" do
        @set.sid("two_id").should == @two
        @set.sid("four_id").should == @four
      end

      should "have externally settable ordering" do
        @set.order = [:five, :three, :two]
        @set.order.should == [:five, :three, :two, :one, :four]
        @set.map { |val| val }.should == ['Five', 'Three', 'Two', 'One', 'Four']
        @set.values.should == ['Five', 'Three', 'Two', 'One', 'Four']
      end

      should "have a hash-like map function" do
        @set.map { |val| val }.should == ["Three", "One", "Two", "Four", "Five"]
      end

      should "have a hash-like each function" do
        keys = []
        @set.each { |val| keys << val }
        keys.should == ["Three", "One", "Two", "Four", "Five"]
      end

      should "ignore a nil superobject" do
        set = Spontaneous::Collections::PrototypeSet.new(nil, :prototypes)
        set[:four] = @four
        set[:five] = @five
        set[:four].should == @four
        set[:two].should be_nil
        set.order.should == [:four, :five]
      end

      should "have a list of values" do
        @set.values.should == ['Three', 'One', 'Two', 'Four', 'Five']
      end

      should "allow access to values as method calls" do
        @set.two.should == "Two"
        @set.five.should == "Five"
      end

      should "intelligently deal with sub-sets over-writing values" do
        order = @set.order
        @set.first.should == "Three"
        @set[:three] = "One Hundred"
        @set[:three].should == "One Hundred"
        @set.first.should == "One Hundred"
        @set.order.should == order
      end

      should "return the last value" do
        @set.last.should == "Five"
      end

      should "know the number of entries" do
        @set.length.should == 5
        @set.count.should == 5
      end

      should "return the first item in the local set" do
        @set.local_first.should == "Four"
      end

      should "traverse the object list until it finds a local_first" do
        a = Super.new
        a.prototypes = @set
        set1 = Spontaneous::Collections::PrototypeSet.new(a, :prototypes)
        b = Super.new
        b.prototypes = set1
        set2 = Spontaneous::Collections::PrototypeSet.new(b, :prototypes)
        set1.local_first.should == "Four"
        set2.local_first.should == "Four"
      end

      should "return nil for local first if empty" do
        a = Super.new
        a.prototypes = Spontaneous::Collections::PrototypeSet.new(nil, :prototypes)
        set1 = Spontaneous::Collections::PrototypeSet.new(a, :prototypes)
        set1.local_first.should be_nil
      end

      should "correctly search the hierarchy" do
        one = "One"
        one.stubs(:default?).returns(false)
        two = "Two"
        two.stubs(:default?).returns(true)
        three = "Three"
        three.stubs(:default?).returns(false)
        four = "Four"
        four.stubs(:default?).returns(false)
        five = "Five"
        five.stubs(:default?).returns(false)
        six = "Six"
        six.stubs(:default?).returns(true)
        a = Super.new
        a.prototypes = Spontaneous::Collections::PrototypeSet.new(nil, :prototypes)
        a.prototypes[:one] = one
        a.prototypes[:two] = two
        b = Super.new
        b.prototypes = Spontaneous::Collections::PrototypeSet.new(a, :prototypes)
        a.prototypes[:three] = three
        a.prototypes[:four] = four
        c = Super.new
        c.prototypes = Spontaneous::Collections::PrototypeSet.new(b, :prototypes)

        test = proc { |value|
          value.default?
        }

        c.prototypes.hierarchy_detect(&test).should == "Two"

        c.prototypes[:five] = five
        c.prototypes[:six] = six

        c.prototypes.hierarchy_detect(&test).should == "Six"
      end
    end
  end
end

