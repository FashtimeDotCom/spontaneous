require 'foreman/engine/cli'
require 'thor'



require File.expand_path('../../test_helper', __FILE__)


describe "CLI" do
  let(:cli) { Spontaneous::Cli }
  let(:root) { cli::Root }

  def run_command(cmd)
    quietly do
      root.start(cmd)
    end
  end

  def set_expectation(method, _cmd = cmd)
    quietly do
      _cmd.any_instance.expects(method)
    end
  end

  describe "Init" do
    let(:cmd) { cli::Init }
    it "maps 'spot init' to Init#init" do
      set_expectation(:initialize_size)
      run_command(["init"])
    end
  end

  describe "Console" do
    let(:cmd) { cli::Console }
    it "maps 'spot console' to Console#open" do
      set_expectation(:open_console)
      run_command(["console"])
    end
    it "maps 'spot c' to Console#open" do
      set_expectation(:open_console)
      run_command(["c"])
    end
  end

  describe "Server" do
    let(:cmd) { cli::Server }

    def expect_subcommand_launch
      foreman = mock()
      foreman.expects(:register).with("front", regexp_matches(/spot server front/))
      foreman.expects(:register).with("back", regexp_matches(/spot server back/))
      foreman.expects(:register).with("tasks", regexp_matches(/spot server tasks/))
      foreman.expects(:start)
      ::Foreman::Engine::CLI.expects(:new).returns(foreman)
    end

    it "maps 'spot server' to Server#start" do
      set_expectation(:start)
      run_command(["server"])
    end

    it "'spot server' launches front & back" do
      expect_subcommand_launch
      run_command(["server"])
    end

    it "'spot s' launches front & back" do
      expect_subcommand_launch
      run_command(["s"])
    end

    it "maps 'spot server back' to Server#back" do
      silence_logger do
        set_expectation(:start_server).with(:back)
        run_command(["server", "back"])
      end
    end

    it "maps 'spot s back' to Server#back" do
      silence_logger do
        set_expectation(:start_server).with(:back)
        run_command(["s", "back"])
      end
    end

    it "maps 'spot server front' to Server#front" do
      silence_logger do
        set_expectation(:start_server).with(:front)
        run_command(["server", "front"])
      end
    end

    it "maps 'spot s front' to Server#front" do
      silence_logger do
        set_expectation(:start_server).with(:front)
        run_command(["s", "front"])
      end
    end

    it "maps 'spot server tasks' to Server#tasks" do
      silence_logger do
        set_expectation(:start_simultaneous)
        run_command(["server", "tasks"])
      end
    end

    it "maps 'spot s tasks' to Server#tasks" do
      silence_logger do
        set_expectation(:start_simultaneous)
        run_command(["s", "tasks"])
      end
    end
  end

  describe "User" do
    let(:cmd) { cli::User }
    it "maps 'spot user' to User#add" do
      set_expectation(:add_user)
      run_command(["user"])
    end

    it "maps 'spot user add' to User#add" do
      set_expectation(:add_user)
      run_command(["user", "add"])
    end

    it "maps 'spot user list' to User#list" do
      set_expectation(:list_users)
      run_command(["user", "list"])
    end

    it "maps 'spot user authenticate' to User#authenticate" do
      set_expectation(:authenticate_user).with("garry", "fishingrod")
      run_command(["user", "authenticate", "garry", "fishingrod"])
    end
  end

  describe "Generate" do
    let(:cmd) { cli::Generate }
    let(:generator) { ::Spontaneous::Generators::Site }
    it "maps 'generate site' to Generate#site" do
      generator.expects(:start).with([])
      run_command(["generate", "site"])
    end

    it "maps 'generate example.com' to Generate#site" do
      generator.expects(:start).with(['example.com'])
      run_command(["generate", "example.com"])
    end

  end

  describe "Assets" do
    let(:cmd) { cli::Assets }
    it "maps 'spot assets compile' to Assets#compile" do
      set_expectation(:compile_assets)
      run_command(["assets", "compile", "--destination=/tmp/destination"])
    end
  end

  describe "Content" do
    let(:cmd) { cli::Content }
    it "maps 'spot content clean' to Content#clean" do
      set_expectation(:clean_content)
      run_command(["content", "clean"])
    end
  end

  describe "Fields" do
    let(:cmd) { cli::Fields }
    it "maps 'spot fields update' to Fields#update" do
      set_expectation(:update_fields)
      run_command(["fields", "update"])
    end
  end

  describe "Site" do
    let(:cmd) { cli::Site }
    it "maps 'spot site dump' to Site#dump" do
      set_expectation(:dump_site_data)
      run_command(["site", "dump"])
    end

    it "maps 'spot site load' to Site#load" do
      set_expectation(:load_site_data)
      run_command(["site", "load"])
    end

    it "maps 'spot site publish' to Site#publish" do
      set_expectation(:publish_site)
      run_command(["site", "publish"])
    end

    it "maps 'spot site render' to Site#render" do
      set_expectation(:render_site)
      run_command(["site", "render"])
    end

    it "maps 'spot site revision' to Site#revision" do
      set_expectation(:show_site_revision)
      run_command(["site", "revision"])
    end

    it "maps 'spot site browse' to Site#browse" do
      set_expectation(:browse_site)
      run_command(["site", "browse"])
    end
  end

end