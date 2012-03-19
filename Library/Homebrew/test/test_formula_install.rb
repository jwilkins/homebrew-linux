require 'testing_env'

require 'extend/ARGV' # needs to be after test/unit to avoid conflict with OptionsParser
ARGV.extend(HomebrewArgvExtension)

require 'formula'
require 'test/testball'
require 'keg'
require 'utils'


class TestScriptFileFormula <ScriptFileFormula
  url "file:///#{Pathname.new(ABS__FILE__).realpath}"
  version "1"
  
  def initialize
    @name='test-script-formula'
    @homepage = 'http://example.com/'
    super
  end
end


class ConfigureTests < Test::Unit::TestCase
  def test_detect_failed_configure
    f=ConfigureFails.new
    begin
      f.brew { f.install }
    rescue ExecutionError => e
      assert e.was_running_configure?
    end
  end
end


class InstallTests < Test::Unit::TestCase
  def temporary_install f
    # Brew and install the given formula
    nostdout do
      f.brew { f.install }
    end

    # Allow the test to do some processing
    yield
    
    # Remove the brewed formula and double check
    # that it did get removed. This lets multiple
    # tests use the same formula name without
    # stepping on each other.
    keg=Keg.new f.prefix
    keg.uninstall
    assert !keg.exist?
    assert !f.installed?
  end

  def test_a_basic_install
    f=TestBall.new
    
    assert_equal Formula.path(f.name), f.path
    assert !f.installed?
    
    temporary_install f do
      assert_match Regexp.new("^#{HOMEBREW_CELLAR}/"), f.prefix.to_s
    
      # Test that things made it into the Keg
      assert f.bin.directory?
      assert_equal 3, f.bin.children.length
      libexec=f.prefix+'libexec'
      assert libexec.directory?
      assert_equal 1, libexec.children.length
      assert !(f.prefix+'main.c').exist?
      assert f.installed?
    
      # Test that things make it into the Cellar
      keg=Keg.new f.prefix
      keg.link
      assert_equal 2, HOMEBREW_PREFIX.children.length
      assert (HOMEBREW_PREFIX+'bin').directory?
      assert_equal 3, (HOMEBREW_PREFIX+'bin').children.length
    end
  end
  
  def test_script_install
    f=TestScriptFileFormula.new
    
    temporary_install f do
      nostdout do
        f.brew { f.install }
      end
    
      assert_equal 1, f.bin.children.length
    end
  end

end
