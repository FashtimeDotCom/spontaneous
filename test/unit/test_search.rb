# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)

describe "Search" do

  # search should be defined by DSL
  # DSL should
  # - Allow naming of index
  # - Allow restricting of the content by hierarchy
  #   - (Including/Excluding) Page & children (>=)
  #   - (Including/Excluding) Children of page (>)
  # - Allow restricting of indexed content by type
  #   - (Including/Excluding) Specific Page types
  #   - (Including/Excluding) Page types & subclasses (>=)
  #   - (Including/Excluding) Subclasses of type (>)
  #
  # Fields should be included in indexes
  # - Default is to add field to all indexes
  # - Should be able to include on a per index basis
  # - Should be able to set the weight factor globally & per-index
  # - Should be able to partition fields into groups so that in search query you can specify that query is in particular group of fields
  #
  # - Indexing is done by page

  before do
    @site = setup_site
    Content.delete


    # class ::Piece < S::Piece; end
    # class ::Page < S::Page; end
    b = ::Page.box :pages
    # instantiate box instance class to it gets added to schema
    ::Page.boxes.pages.instance_class.schema_id

    class ::PageClass1 < ::Page; end
    class ::PageClass2 < ::Page; end
    class ::PageClass3 < ::PageClass1; end
    class ::PageClass4 < ::PageClass2; end
    class ::PageClass5 < ::PageClass3; end
    class ::PageClass6 < ::PageClass5; end

    class ::PieceClass1 < ::Piece; end
    class ::PieceClass2 < ::Piece; end
    class ::PieceClass3 < ::Piece; end

    @all_page_classes = [::Page, ::PageClass1, ::PageClass2, ::PageClass3, ::PageClass4, ::PageClass5, ::PageClass6]
    @all_piece_classes = [::Piece, ::PieceClass1, ::PieceClass2, ::PieceClass3]
    @all_box_classes = [ ::Box, ::Page::PagesBox ]
    @all_classes = @all_page_classes + @all_piece_classes + @all_box_classes

    @root0 = ::Page.create(:uid => "root")
    @page1 = ::PageClass1.create(:slug => "page1", :uid => "page1")
    @root0.pages << @page1
    @page2 = ::PageClass2.create(:slug => "page2", :uid => "page2")
    @root0.pages << @page2
    @page3 = ::PageClass3.create(:slug => "page3", :uid => "page3")
    @root0.pages << @page3
    @page4 = ::PageClass4.create(:slug => "page4", :uid => "page4")
    @root0.pages << @page4
    @page5 = ::PageClass5.create(:slug => "page5", :uid => "page5")
    @root0.pages << @page5
    @page6 = ::PageClass6.create(:slug => "page6", :uid => "page6")
    @root0.pages << @page6

    @page7 = ::PageClass1.create(:slug => "page7", :uid => "page7")
    @page1.pages << @page7
    @page8 = ::PageClass6.create(:slug => "page8", :uid => "page8")
    @page1.pages << @page8

    @page9 = ::PageClass1.create(:slug => "page9", :uid => "page9")
    @page8.pages << @page9
    @page10 = ::PageClass2.create(:slug => "page10", :uid => "page10")
    @page8.pages << @page10
    @page11 = ::PageClass3.create(:slug => "page11", :uid => "page11")
    @page8.pages << @page11
    @page12 = ::PageClass4.create(:slug => "page12", :uid => "page12")
    @page8.pages << @page12

    @all_pages = [@root0, @page1, @page2, @page3, @page4, @page5, @page6, @page7, @page8, @page9, @page10, @page11, @page12]
    @all_pages.each { |page| page.save; page.reload }
  end

  after do
    (@all_classes.map { |k| k.name.to_sym }).each { |klass|
      Object.send(:remove_const, klass) rescue nil
    } rescue nil
    Content.delete
    teardown_site
  end

  describe "indexes" do
    it "be retrievable by name" do
      index = S::Site.index :arthur
      S::Site.indexes[:arthur].must_be_instance_of Spontaneous::Search::Index
      S::Site.indexes[:arthur].name.must_equal :arthur
      S::Site.indexes[:arthur].must_equal index
    end

    it "default to indexing all content classes" do
      index = S::Site.index :all
      assert_has_elements (@all_classes), index.search_types
    end

    it "allow restriction to particular classes" do
      index = S::Site.index :all do
        include_types ::PageClass1, "PageClass2", :PageClass3
      end
      assert_has_elements [::PageClass1, ::PageClass2, ::PageClass3], index.search_types
    end

    it "allow restriction to a class & its subclasses" do
      index = S::Site.index :all do
        include_types ">= PageClass1"
      end
      assert_has_elements [::PageClass1, ::PageClass3, ::PageClass5, ::PageClass6], index.search_types
    end

    it "allow restriction to a class's subclasses" do
      index = S::Site.index :all do
        include_types "> PageClass1"
      end
      assert_has_elements [::PageClass3, ::PageClass5, ::PageClass6], index.search_types
    end

    it "allow removal of particular classes" do
      index = S::Site.index :all do
        exclude_types ::PageClass1, "PageClass2"
      end
      assert_has_elements (@all_classes - [PageClass1, PageClass2]), index.search_types
    end

    it "allow removal of a class and its subclasses" do
      index = S::Site.index :all do
        exclude_types ">= PageClass1", PieceClass1
      end
      assert_has_elements (@all_classes - [::PageClass1, ::PageClass3, ::PageClass5, ::PageClass6, PieceClass1]), index.search_types
    end

    it "allow removal of a class's subclasses" do
      index = S::Site.index :all do
        exclude_types "> PageClass1"
      end
      assert_has_elements (@all_classes - [::PageClass3, ::PageClass5, ::PageClass6]), index.search_types
    end

    it "default to including all content" do
      index = S::Site.index :all
      @all_pages.each do |page|
        assert index.include?(page)
      end
    end

    it "allow restriction to a set of specific pages" do
      id = @root0.id
      path = @page8.path
      index = S::Site.index :all do
        include_pages id, "$page11", path
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [true,false,false,false,false,false,false,false,true,false,false,true,false]
    end

    it "allow restriction to a page and its children" do
      index = S::Site.index :all do
        include_pages ">= $page8"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [false,false,false,false,false,false,false,false,true,true,true,true,true]
    end

    it "allow restriction to a page's children" do
      index = S::Site.index :all do
        include_pages "> $page8"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [false,false,false,false,false,false,false,false,false,true,true,true,true]
    end

    it "allow removal of specific pages" do
      index = S::Site.index :all do
        exclude_pages "$page8", "/page1"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [true,false,true,true,true,true,true,true,false,true,true,true,true]
    end

    it "allow removal of a page and its children" do
      index = S::Site.index :all do
        exclude_pages "/page1", ">= $page8"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [true,false,true,true,true,true,true,true,false,false,false,false,false]
    end

    it "allow removal of a page's children" do
      index = S::Site.index :all do
        exclude_pages "/page1", "> $page8"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [true,false,true,true,true,true,true,true,true,false,false,false,false]
    end

    it "allow multiple, mixed, page restrictions" do
      index = S::Site.index :all do
        include_pages "$page1", "> $page8"
      end

      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [false,true,false,false,false,false,false,false,false,true,true,true,true]
    end

    it "allow combining of class and page restrictions" do
      index = S::Site.index :all do
        exclude_types PageClass3, PageClass4
        include_pages "$page1", "> $page8"
        exclude_pages "$page10"
      end
      included = @all_pages.map{ |page| index.include?(page) }
      included.must_equal [false,true,false,false,false,false,false,false,false,true,false,false,false]
    end
  end

  describe "Fields definitions" do
    # Inclusion of field in indexes.
    # Default is not to include field
    # By adding the following clause:
    #
    #   field :title, :index => true
    #
    # you include the :title field in all indexes with a search weight of 1. this is equivalent to the following:
    #
    #   field :title, :index => { :name => :*, :weight => 1, :group => nil }
    #
    # If you only want to include this field in a specific index, then you do the following:
    #
    #   field :title, :index => :tags
    #
    # this is equivalent to
    #
    #   field :title, :index => { :name => :tags, :weight => 1, :group => nil }
    #
    # or if you want to include it into more than one index:
    #
    #   field :title, :index => [:tags, :content]
    #
    # this is equivalent to
    #
    #   field :title, :index => [
    #     { :name => :tags, :weight => 1, :group => nil },
    #     { :name => :content, :weight => 1, :group => nil }]
    #
    # Groups:
    #
    # Normally field values are grouped by content types. Indexes are generated from a page by iterating through
    # all it's pieces and creating a single aggregate value for each field of each type found
    #
    # Groups are a way of joining disparate fields from different types into a single, addressable/searchable
    # index
    #
    # weight:
    #
    # weight defines how much priority is given to a field. I.e. if your search term occurs in a field
    # with a high weight value then it will apear higher in the results list than in a page where the
    # term appears in a lower weight field
    #
    # :store   = 0 : store but don't index (makes value available to results lister without loading page from db)
    # :normal  = 1 : default weight
    # :high    = 2 : high weight
    # :higher  = 4 : higher weight
    # :highest = 8 : higest
    #
    # actual weight are powers of 10: 10, 100, 10000, 100000000 (unless this is different from Ferret)
    #
    #
    before do
      @index1 = S::Site.index(:one)
      @index2 = S::Site.index(:two)
      @index3 = S::Site.index(:three) do
        include_types PageClass1
      end
    end

    after do
    end

    it "be included in all indexes if :index is set to true" do
      prototype_a = PageClass1.field :a, :index => true
      assert prototype_a.in_index?(@index1)
      assert prototype_a.in_index?(@index2)
      assert prototype_a.in_index?(@index3)
    end

    it "must be included in all indexes with if passed a hash with no name key" do
      prototype_a = PageClass1.field :a, :index => {weight: 16}
      assert prototype_a.in_index?(@index1)
      assert prototype_a.in_index?(@index2)
      assert prototype_a.in_index?(@index3)
      [:one, :two, :three].each do |name|
        index = S::Site.indexes[name]
        index.fields[PageClass1.fields[:a].schema_id.to_s][:weight].must_equal 16
      end
    end

    it "be included in indexes referenced by name" do
      prototype_a = PageClass1.field :a, :index => [:one, :two]
      assert prototype_a.in_index?(@index1)
      assert prototype_a.in_index?(@index2)
      refute prototype_a.in_index?(@index3)
    end

    it "be included in indexes referenced as hash" do
      prototype_a = PageClass1.field :a, :index => {:name => :two}
      refute prototype_a.in_index?(@index1)
      assert prototype_a.in_index?(@index2)
      refute prototype_a.in_index?(@index3)
    end

    it "be included in indexes listed in hash" do
      prototype_a = PageClass1.field :a, :index => [{:name => :one}, {:name => :two}]
      assert prototype_a.in_index?(@index1)
      assert prototype_a.in_index?(@index2)
      refute prototype_a.in_index?(@index3)
    end

    it "return the field's schema id as its index name by default" do
      prototype_a = PageClass1.field :a, :index => [{:name => :one}, {:name => :two, :group => :a}]
      prototype_a.index_id(@index1).must_equal prototype_a.schema_id.to_s
      prototype_a.index_id(@index2).must_equal :a
    end

    it "produce a field list in a xapian-fu compatible format" do
      a = PageClass1.field :a, :index => [{:name => :one, :weight => :store},
                                          {:name => :two, :group => :a, :weight => 2}]
      b = PageClass2.field :b, :index => :one
      c = ::Piece.field :c, :index => [{:name => :one, :weight => 4}, {:name => :two, :group => :a}]
      d = ::Piece.field :d, :index => :three
      e = ::PageClass1.field :e, :index => :three
      f = ::PageClass2.field :f, :index => :three
      g = ::Piece.field :g, :index => {:weight => :highest}

      h = ::PageClass1.boxes.pages.instance_class.field :h, :index => :two

      S::Site.indexes[:one].fields.must_equal({
        a.schema_id.to_s => { :type => String, :store => true, :index => false},
        b.schema_id.to_s => { :type => String, :store => true, :weight => 1, :index => true},
        c.schema_id.to_s => { :type => String, :store => true, :weight => 4, :index => true},
        g.schema_id.to_s => { :type => String, :store => true, :weight => 16, :index => true}
      })

      S::Site.indexes[:two].fields.must_equal({
        :a => { :type => String, :store => true, :weight => 2, :index => true},
        g.schema_id.to_s => { :type => String, :store => true, :weight => 16, :index => true},
        h.schema_id.to_s => { :type => String, :store => true, :weight => 1, :index => true}
      })

      S::Site.indexes[:three].fields.must_equal({
        e.schema_id.to_s => { :type => String, :store => true, :weight => 1, :index => true}
      })
    end
  end

  describe "indexing" do
    before do
      @revision = 99

      @index1 = S::Site.index :one do
        exclude_types PageClass3
      end
      @index2 = S::Site.index :two

      @a = PageClass1.field  :a, :index => true
      @b = PageClass2.field  :b, :index => true
      @c = PageClass3.field  :c, :index => true
      @d = PageClass4.field  :d, :index => true
      @e = PageClass5.field  :e, :index => true
      @f = PageClass6.field  :f, :index => true
      @g = PieceClass1.field :g, :index => true
      @h = PieceClass2.field :h, :index => true
      @i = PieceClass3.field :i, :index => {:group => :i}
      @j = PieceClass3.field :j, :index => {:group => :i}
      @k = PieceClass3.field :k

      @l = ::PageClass1.boxes.pages.instance_class.field :l, :index => true

      @page1.a = "a value 1"
      @page1.pages.first.a =  "a value 2"
      @page1.pages.l =  "l value 1"

      @piece1 = PieceClass1.new(:g => "g value 1")
      @page1.pages << @piece1
      @piece2 = PieceClass1.new(:g => "g value 2")
      @page1.pages << @piece2
      @piece3 = PieceClass1.new(:g => "g value 3")
      @page1.pages << @piece3
      @piece4 = PieceClass2.new(:h => "h value 1")
      @page1.pages << @piece4
      @piece5 = PieceClass2.new(:h => "h value 2")
      @page1.pages << @piece5
      @piece6 = PieceClass3.new(:i => "i value 1", :j => "j value 1", :k => "k value 1")
      @page1.pages << @piece6
      @piece7 = PieceClass3.new(:i => "i value 2", :j => "j value 2", :k => "k value 2")
      @page1.pages << @piece7

      @page2.b = "b value 1"
      @page3.c = "c value 1"
      @page1.save
    end

    after do
    end

    it "correctly extract content from pages" do
      @page1.a.expects(:indexable_value).returns("(a value 1)")
      @index1.indexable_content(@page1).must_equal({
        :id => @page1.id,
        @a.schema_id.to_s => "(a value 1)",
        @g.schema_id.to_s => "g value 1\ng value 2\ng value 3",
        @h.schema_id.to_s => "h value 1\nh value 2",
        :i                => "i value 1\nj value 1\ni value 2\nj value 2",
        @l.schema_id.to_s => "l value 1",
      })
    end

    it "only include specified pieces" do
      index = S::Site.index :four do
        include_types PageClass1, PieceClass1
      end

      index.indexable_content(@page1).must_equal({
        :id => @page1.id,
        @a.schema_id.to_s => "a value 1",
        @g.schema_id.to_s => "g value 1\ng value 2\ng value 3",
      })
    end

    it "allow for page types to append their own custom indexable values" do
      index = S::Site.index :four do
        include_types PageClass1, PieceClass1
      end
      class ::PageClass1
        def additional_search_values
          { "search_key1" => "value 1",
            "search_key2" => "value 2" }
        end
      end
      index.indexable_content(@page1).must_equal({
        :id => @page1.id,
        @a.schema_id.to_s => "a value 1",
        @g.schema_id.to_s => "g value 1\ng value 2\ng value 3",
        "search_key1" => "value 1",
        "search_key2" => "value 2"
      })
    end

    it "deal with arrays of additional search index values" do
      index = S::Site.index :four do
        include_types PageClass1, PieceClass1
      end
      class ::PageClass1
        def additional_search_values
          [ { "search_key1" => "value 1",
              "search_key2" => "value 2" },
              { "search_key1" => "value 3",
                "search_key2" => "value 4" } ]
        end
      end
      index.indexable_content(@page1).must_equal({
        :id => @page1.id,
        @a.schema_id.to_s => "a value 1",
        @g.schema_id.to_s => "g value 1\ng value 2\ng value 3",
        "search_key1" => "value 1\nvalue 3",
        "search_key2" => "value 2\nvalue 4"
      })
    end

    it "allow for pieces to append their own custom indexable values" do
      index = S::Site.index :four do
        include_types PageClass1, PieceClass1
      end
      class ::PieceClass1
        def additional_search_values
          { "search_key3" => "value 3",
            "search_key4" => "value 4" }
        end
      end
      index.indexable_content(@page1).must_equal({
        :id => @page1.id,
        @a.schema_id.to_s => "a value 1",
        @g.schema_id.to_s => "g value 1\ng value 2\ng value 3",
        "search_key3" => "value 3\nvalue 3\nvalue 3",
        "search_key4" => "value 4\nvalue 4\nvalue 4"
      })
    end

    it "create database in the right directory" do
      db_path = @site.revision_dir(@revision) / 'indexes' / 'one'
      Site.stubs(:published_revision).returns(@revision)
      mset = mock()
      mset.stubs(:matches).returns([])
      xapian = mock()
      xapian.expects(:<<).with(@index1.indexable_content(@page1))
      xapian.expects(:search).with('"value 2"', {}).returns(XapianFu::ResultSet.new(:mset => mset))
      xapian.expects(:flush)

      XapianFu::XapianDb.expects(:new).with(has_entries({
        :dir => db_path,
        :create => true,
        :overwrite => true,
        :language => :english,
        :fields => @index1.fields,
        :spelling => true
      })).returns(xapian)

      db = @index1.create_db(@revision)
      assert File.directory?(db_path)
      db << @page1
      db << @page3
      db.close
      db.search('"value 2"')
      FileUtils.rm_r(db_path)
    end

    it "pass on index configuration to the xapian db" do
      db_path = @site.revision_dir(@revision) / 'indexes' / 'name'

      index = Site.index :name do
        language :italian
      end

      XapianFu::XapianDb.expects(:new).with(has_entries({
        :dir => db_path,
        :create => true,
        :overwrite => true,
        :language => :italian,
        :fields => index.fields,
        :spelling => true
      }))

      db = index.create_db(@revision)

      index = Site.index :name do
        language :french
        stopper  false
        stemmer  false
      end

      XapianFu::XapianDb.expects(:new).with(has_entries({
        :dir => db_path,
        :create => true,
        :overwrite => true,
        :language => :french,
        :stemmer => false,
        :stopper => false,
        :fields => index.fields,
        :spelling => true
      }))

      db = index.create_db(@revision)

      FileUtils.rm_r(db_path)
    end

    it "return (reasonable) results to searches" do
      db_path = @site.revision_dir(@revision) / 'indexes' / 'one'
      S::Site.stubs(:published_revision).returns(@revision)
      db = @index1.create_db(@revision)
      db << @page1
      db << @page2
      db << @page3
      db.close

      results = @index1.search('+valeu', :limit => 1, :autocorrect => true)
      results.must_be_instance_of S::Search::Results
      results.each do |result|
        result.class.must_be :<, Content::Page
      end

      results.corrected_query.must_equal '+value'
      results.current_page.must_equal 1
      results.per_page.must_equal 1
      results.total_pages.must_equal 2
      results.next_page.must_equal 2
      results.offset.must_equal 0
      results.previous_page.must_equal nil
      results.total_entries.must_equal 2

      results = @index1.search('valeu', :limit => 1, :autocorrect => false)
      results.corrected_query.must_equal 'value'
      results.total_entries.must_equal 0

      results = @index1.search('value', :limit => 1)
      results.corrected_query.must_equal ''
      results.total_entries.must_equal 2

      FileUtils.rm_r(db_path)
    end

    it "respect weighting factors given to fields" do
      db_path = @site.revision_dir(@revision) / 'indexes' / 'one'
      S::Site.stubs(:published_revision).returns(@revision)
      db = @index1.create_db(@revision)
      @w = PieceClass1.field :w, :index => { :weight => 100 }
      @page1.pages << PieceClass1.new(:w => "findme")
      @page2.pages << PieceClass2.new(:h => "findme findme")
      @page2.pages << PieceClass2.new(:h => "findme findme")
      @page5.pages << PieceClass2.new(:h => "findme")
      @page5.pages << PieceClass2.new(:h => "findme")

      @page1.save
      @page2.save
      @page5.save
      db << @page1
      db << @page2
      db << @page5
      db.close
      results = @index1.search('findme', :limit => 5)
      results.map(&:id).must_equal [@page1.id, @page2.id, @page5.id]
    end

    it "use the weighting specific to a subclass" do
      db_path = @site.revision_dir(@revision) / 'indexes' / 'one'
      S::Site.stubs(:published_revision).returns(@revision)
      @w = PieceClass1.field :w, :index => { :weight => 100 }
      WeightedPiece = Class.new(PieceClass1)
      WeightedPiece.field :w, :index => { :weight => 1}
      index = Site.index :weighted do
      end
      @page1.pages << WeightedPiece.new(:w => "findme")
      @page2.pages << PieceClass2.new(:h => "findme findme")
      @page2.pages << PieceClass2.new(:h => "findme findme")
      @page5.pages << PieceClass2.new(:h => "findme")
      @page5.pages << PieceClass2.new(:h => "findme")

      @page1.save
      @page2.save
      @page5.save
      db = index.create_db(@revision)
      db << @page1
      db << @page2
      db << @page5
      db.close
      results = index.search('findme', :limit => 5)
      results.map(&:id).must_equal [@page2.id, @page5.id, @page1.id]
    end

    it "provide a convenient way to add documents to multiple indexes" do
      db1 = mock()
      db2 = mock()
      @index1.expects(:create_db).with(@revision).returns(db1)
      @index2.expects(:create_db).with(@revision).returns(db2)
      db1.expects(:<<).with(@page1)
      db2.expects(:<<).with(@page1)
      db1.expects(:close)
      db2.expects(:close)
      S::Site.indexer(@revision) do |indexer|
        indexer.length.must_equal 2
        indexer << @page1
      end
    end
  end

  describe "initialization" do
    before do
      FileUtils.cp_r(File.expand_path("../../fixtures/search/config", __FILE__), @site.root)
    end

    it "load the config/indexes.rb file" do
      @site.expects(:connect_to_database!)
      @site.initialize!
      index = @site.indexes[:fast]
      index.must_be_instance_of S::Search::Index
      index.name.must_equal :fast
      index.search_types.must_equal [PageClass1, PageClass2, PageClass3]
    end
  end
end
