require "#{File.expand_path(File.dirname(__FILE__))}/../system_command.rb"
include Homebrew

module HomebrewEnvExtension
  # -w: keep signal to noise high
  SAFE_CFLAGS_FLAGS = "-w -pipe"

  def setup_build_environment
    # Clear CDPATH to avoid make issues that depend on changing directories
    delete('CDPATH')
    delete('CPPFLAGS')
    delete('LDFLAGS')

    self['MAKEFLAGS']="-j#{Hardware.processor_count}"

    unless HOMEBREW_PREFIX.to_s == '/usr/local'
      # /usr/local is already an -isystem and -L directory so we skip it
      self['CPPFLAGS'] = "-isystem #{HOMEBREW_PREFIX}/include"
      self['LDFLAGS'] = "-L#{HOMEBREW_PREFIX}/lib"
      # CMake ignores the variables above
      self['CMAKE_PREFIX_PATH'] = "#{HOMEBREW_PREFIX}"
    end

    if SystemCommand.platform == :linux || SystemCommand.platform == :freebsd
      self['CC'] = '/usr/bin/cc'
      self['CXX'] = '/usr/bin/c++'
      cflags = ['-O3']
    else
      if MACOS_VERSION >= 10.6 and (self['HOMEBREW_USE_LLVM'] or ARGV.include? '--use-llvm')
        xcode_path = `/usr/bin/xcode-select -print-path`.chomp
        xcode_path = "/Developer" if xcode_path.to_s.empty?
        self['CC'] = "#{xcode_path}/usr/bin/llvm-gcc"
        self['CXX'] = "#{xcode_path}/usr/bin/llvm-g++"
        cflags = ['-O4'] # link time optimisation baby!
      else
        # If these aren't set, many formulae fail to build
        self['CC'] = '/usr/bin/cc'
        self['CXX'] = '/usr/bin/c++'
        cflags = ['-O3']
      end
    end

    # In rare cases this may break your builds, as the tool for some reason wants
    # to use a specific linker. However doing this in general causes formula to
    # build more successfully because we are changing CC and many build systems
    # don't react properly to that.
    self['LD'] = self['CC']

    # optimise all the way to eleven, references:
    # http://en.gentoo-wiki.com/wiki/Safe_Cflags/Intel
    # http://forums.mozillazine.org/viewtopic.php?f=12&t=577299
    # http://gcc.gnu.org/onlinedocs/gcc-4.2.1/gcc/i386-and-x86_002d64-Options.html
    # we don't set, eg. -msse3 because the march flag does that for us
    #   http://gcc.gnu.org/onlinedocs/gcc-4.3.3/gcc/i386-and-x86_002d64-Options.html
    if SystemCommand.platform == :mac
      if MACOS_VERSION >= 10.6
        case Hardware.intel_family
        when :nehalem, :penryn, :core2
          # the 64 bit compiler adds -mfpmath=sse for us
          cflags << "-march=core2"
        when :core
          cflags<<"-march=prescott"<<"-mfpmath=sse"
        end
        # gcc doesn't auto add msse4 or above (based on march flag) yet
        case Hardware.intel_family
        when :nehalem
          cflags << "-msse4" # means msse4.2 and msse4.1
        when :penryn
          cflags << "-msse4.1"
        end
      else
        # gcc 4.0 didn't support msse4
        case Hardware.intel_family
        when :nehalem, :penryn, :core2
          cflags<<"-march=nocona"
        when :core
          cflags<<"-march=prescott"
        end
        cflags<<"-mfpmath=sse"
      end
    else
      cflags<<"-mfpmath=sse"
    end

    self['CFLAGS'] = self['CXXFLAGS'] = "#{cflags*' '} #{SAFE_CFLAGS_FLAGS}"
  end

  def deparallelize
    remove 'MAKEFLAGS', /-j\d+/
  end
  alias_method :j1, :deparallelize

  # recommended by Apple, but, eg. wget won't compile with this flag, so…
  def fast
    remove_from_cflags(/-O./)
    append_to_cflags '-fast'
  end
  def O4
    # LLVM link-time optimization
    remove_from_cflags(/-O./)
    append_to_cflags '-O4'
  end
  def O3
    # Sometimes O4 just takes fucking forever
    remove_from_cflags(/-O./)
    append_to_cflags '-O3'
  end
  def O2
    # Sometimes O3 doesn't work or produces bad binaries
    remove_from_cflags(/-O./)
    append_to_cflags '-O2'
  end
  def Os
    # Sometimes you just want a small one
    remove_from_cflags(/-O./)
    append_to_cflags '-Os'
  end

  def gcc_4_0_1
    self['CC'] = self['LD'] = '/usr/bin/gcc-4.0'
    self['CXX'] = '/usr/bin/g++-4.0'
    self.O3
    remove_from_cflags '-march=core2'
    remove_from_cflags %r{-msse4(\.\d)?}
  end
  alias_method :gcc_4_0, :gcc_4_0_1

  def gcc_4_2
    # Sometimes you want to downgrade from LLVM to GCC 4.2
    self['CC']="/usr/bin/gcc-4.2"
    self['CXX']="/usr/bin/g++-4.2"
    self['LD']=self['CC']
    self.O3
  end

  def llvm
    xcode_path = `/usr/bin/xcode-select -print-path`.chomp
    xcode_path = "/Developer" if xcode_path.to_s.empty?
    self['CC'] = "#{xcode_path}/usr/bin/llvm-gcc"
    self['CXX'] = "#{xcode_path}/usr/bin/llvm-g++"
    self['LD'] = self['CC']
    self.O4
  end

  def osx_10_4
    self['MACOSX_DEPLOYMENT_TARGET']="10.4"
    remove_from_cflags(/ ?-mmacosx-version-min=10\.\d/)
    append_to_cflags('-mmacosx-version-min=10.4')
  end
  def osx_10_5
    self['MACOSX_DEPLOYMENT_TARGET']="10.5"
    remove_from_cflags(/ ?-mmacosx-version-min=10\.\d/)
    append_to_cflags('-mmacosx-version-min=10.5')
  end

  def minimal_optimization
    self['CFLAGS'] = self['CXXFLAGS'] = "-Os #{SAFE_CFLAGS_FLAGS}"
  end
  def no_optimization
    self['CFLAGS'] = self['CXXFLAGS'] = SAFE_CFLAGS_FLAGS
  end

  def libxml2
    append_to_cflags ' -I/usr/include/libxml2'
  end

  def x11
    opoo "You do not have X11 installed, this formula may not build." if not x11_installed?

    # There are some config scripts (e.g. freetype) here that should go in the path
    prepend 'PATH', '/usr/X11/bin', ':'
    # CPPFLAGS are the C-PreProcessor flags, *not* C++!
    append 'CPPFLAGS', '-I/usr/X11R6/include'
    append 'LDFLAGS', '-L/usr/X11R6/lib'
    # CMake ignores the variables above
    append 'CMAKE_PREFIX_PATH', '/usr/X11R6', ':'
  end
  alias_method :libpng, :x11

  # we've seen some packages fail to build when warnings are disabled!
  def enable_warnings
    remove_from_cflags '-w'
  end

  # Snow Leopard defines an NCURSES value the opposite of most distros
  # See: http://bugs.python.org/issue6848
  def ncurses_define
    append 'CPPFLAGS', "-DNCURSES_OPAQUE=0"
  end

  # Shortcuts for reading common flags
  def cc;      self['CC'] or "gcc";  end
  def cxx;     self['CXX'] or "g++"; end
  def cflags;  self['CFLAGS'];       end
  def cppflags;self['CPPLAGS'];      end
  def ldflags; self['LDFLAGS'];      end

  def m64
    append_to_cflags '-m64'
    append 'LDFLAGS', '-arch x86_64'
  end
  def m32
    append_to_cflags '-m32'
    append 'LDFLAGS', '-arch i386'
  end

  # i386 and x86_64 only, no PPC
  def universal_binary
    if SystemCommand.platform == :mac
      append_to_cflags '-arch i386 -arch x86_64'
      self.O3 if self['CFLAGS'].include? '-O4' # O4 seems to cause the build to fail
      append 'LDFLAGS', '-arch i386 -arch x86_64'

      # Can't mix "-march" for a 32-bit CPU  with "-arch x86_64"
      remove_from_cflags(/-march=\S*/) if Hardware.is_32_bit?
    end
  end

  def prepend key, value, separator = ' '
    # Value should be a string, but if it is a pathname then coerce it.
    value = value.to_s
    unless self[key].to_s.empty?
      self[key] = value + separator + self[key]
    else
      self[key] = value
    end
  end

  def append key, value, separator = ' '
    # Value should be a string, but if it is a pathname then coerce it.
    value = value.to_s
    unless self[key].to_s.empty?
      self[key] = self[key] + separator + value
    else
      self[key] = value
    end
  end

  def append_to_cflags f
    append 'CFLAGS', f
    append 'CXXFLAGS', f
  end
  def remove key, value
    return if self[key].nil?
    self[key] = self[key].sub value, '' # can't use sub! on ENV
    self[key] = nil if self[key].empty? # keep things clean
  end
  def remove_from_cflags f
    remove 'CFLAGS', f
    remove 'CXXFLAGS', f
  end
end
