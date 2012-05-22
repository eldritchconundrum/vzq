#!/usr/bin/env jruby
# -*- coding: iso-8859-1 -*-

class ExternalEnvironmentSetup
  def initialize(except_gl = false)
    puts '* Checking external environment...'
    Dir.chdir(File.dirname(__FILE__)) # vzq root
    $LOAD_PATH << 'lib'
    jruby_setup
    lwjgl_setup unless except_gl # unit tests
    scala_setup
    vzq_setup
    puts '* External environment is ready.', '-' * 78
  end

private
  def exec_jruby_with_java_library_path # never returns
    require 'rbconfig'
    case Config::CONFIG["host_os"]
    when /(msdos|mswin|djgpp|mingw)/i then os_dir = 'windows'
    when /mac/i                       then os_dir = 'macosx'
    when /solaris/i                   then os_dir = 'solaris'
    when /linux/i                     then os_dir = 'linux'
    end
    lwjgl_path = Dir["lib/lwjgl-*"].sort.last
    args = ["-X-O", "--fast", #"-J-Dorg.lwjgl.util.Debug=true",
            "-J-Djava.library.path=#{lwjgl_path}/native/#{os_dir}", "#{File.basename($0)}"] + $*
    args.unshift '-w' if $VERBOSE # such interpreter options are lost unless explicitly preserved
    args_string = args.map { |s| s.inspect }.join(' ')

    if os_dir == 'windows'
      cmd = "jruby.bat " + args_string
      puts 'exec %s' % cmd, '-' * 78
    else
      if false
        cmd = "jruby 2>&1 " + args_string
        puts 'exec %s' % cmd, '-' * 78
        # 2>&1 is a workaround to a jruby wontfix bug.
        # It forces bypassing of in-process launching, which is needed to change -J args.
        # see http://jira.codehaus.org/browse/JRUBY-4302
        # unfortunately... the workaround does not work under jruby1.2, so use sh instead
      else
        cmd = "jruby " + args_string
        puts 'exec %s' % cmd, '-' * 78
        cmd = "sh -c %s" % [cmd.inspect]
      end
    end
    sleep 0.3
    exec cmd
  end

  def jruby_setup
    # older than jruby 1.2 was not tested with VZQ. (and will not be supported)
    puts "* running jruby version: #{JRUBY_VERSION}, $$ = #{$$}"
    require 'java'
    puts "* jruby -v: #{%x{jruby -v} rescue 'error'}"
  rescue Exception
    puts $!
    puts "RUBY_PLATFORM != java" unless RUBY_PLATFORM.match(/java/)
    puts '  -> launching jruby'
    exec_jruby_with_java_library_path
  end

  def lwjgl_setup
    lwjgl_version = java.lang.System.getProperty('java.library.path').match(/lwjgl-[^\/]+/).to_s
    puts '* lwjgl version: %s' % [lwjgl_version == '' ? 'error' : lwjgl_version]
    if lwjgl_version == ''
      # ^$ù*"$%µ JVM can't change java.library.path at runtime!
      puts '  -> setting lwjgl in java.library.path (in a new JVM process)...'
      exec_jruby_with_java_library_path
    end
    jars = "lib/%s/**/*.jar" % lwjgl_version
    Dir[jars].each { |jar| require jar }
    Java.org.lwjgl.opengl.GL11 rescue puts 'cannot access to lwjgl classes', $!
    Java.org.lwjgl.Sys rescue puts 'cannot access to lwjgl classes', $! # this check gets the noexec error sooner
  end

  def scala_setup
    puts '* loading scala jars'
    require 'scala-library.jar'
    #require 'scala-compiler.jar'
    Java.scala.collection.immutable.HashMap rescue puts 'cannot access to scala classes', $!
  end

  def vzq_setup
    puts '* loading VZQ jar'
    require 'vzq-engine.jar'
    Java.vzq.engine.PlaceHolder rescue puts 'cannot access to scala VZQ classes', $!
    # BUG !!! jruby cannot load anything under a package or subpackage that has any uppercase letter !!!
    # TODO: report the bug with a simple test case
  end
end

class SourceCodeReloader
  require 'singleton'
  include Singleton

  def load_if_mtime_changed(filename)
    mtime = File.mtime(filename)
    @mtimes ||= {}
    if @mtimes[filename] != mtime
      @mtimes[filename] = mtime
      puts "loading source '%s'" % filename
      d = Java.java.lang.System.currentTimeMillis
      load(filename)
      puts "%s ms" % [Java.java.lang.System.currentTimeMillis - d] if $VERBOSE
    end
  end

  def reload_code
    Dir.chdir('src') {
      # shuffle to ensure that the load order is not important
      load_dir = lambda { |path|
        for filename in (Dir[path] - [__FILE__]).shuffle
          load_if_mtime_changed(filename)
        end
      }
      load_dir.call('core/*.rb')
      load_dir.call('*.rb')
      load_dir.call('*/*.rb')
    }
  end

end

def load_vzq_sources
  puts 'Loading...'
  $LOAD_PATH << 'src'
  require 'src/core/ext_sysutils' # for 'shuffle'

  # func for live runtime alteration from code editor
  def exec_once(unique)
    $exec_once_hash ||= {}
    unless $first_run.nil?
      $exec_once_hash[unique] = nil # ignore exec_once blocks that already are in the code at startup
    else
      if !$exec_once_hash.has_key?(unique)
        $exec_once_hash[unique] = nil
        yield
      end
    end
  end
  begin
    $first_run = true
    SourceCodeReloader.instance.reload_code
  ensure
    $first_run = nil
  end
end

def start_vzq
  const_def :Engine, EngineSingleton.instance
  $engine = Engine
  Engine.mainloop
end

case $0
when __FILE__
  ExternalEnvironmentSetup.new
  load_vzq_sources
  start_vzq
end
