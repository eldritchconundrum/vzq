def java_startup
  puts "RUBY_PLATFORM != java, shouldn't you be running jruby?" unless RUBY_PLATFORM.match(/java/) #"emacs coloration fail
  require 'java'
  prop = Hash.new { |h, k| h[k] = java.lang.System.getProperty(k) }
  lwjgl_version = prop['java.library.path'].match(/lwjgl-[^\/]+/).to_s
  puts 'No LWJGL: use the run script (it sets java.library.path for you)', '-' * 80 if lwjgl_version == ''
  puts 'using java vm %s %s and %s' % [prop['java.vm.vendor'], prop['java.vm.version'], lwjgl_version]
  jars = "lib/%s/**/*.jar" % lwjgl_version
  puts 'loading jars: %s' % jars if $VERBOSE
  Dir[jars].each { |jar| puts jar if $VERBOSE; require jar }
end

java_startup
GL11 = org.lwjgl.opengl.GL11 unless defined?(GL11)

puts 'bootstraping runtime environment'

$mtimes = {}
def try_to_reload_code
  (Dir['*.rb'] - [__FILE__]).shuffle.each { |filename| # shuffle to ensure that the load order is not important
    begin
      mtime = File.mtime(filename)
      next if $mtimes[filename] == mtime
      $mtimes[filename] = mtime
      load(filename)
    rescue Exception => e
      puts '====== while reloading code:', $!
    end
  }
end

# func for live runtime alteration from code editor
$exec_once_hash ||= {}
def exec_once(unique) # ignore exec_once blocks that already are in the code at startup
  $exec_once_hash[unique] = nil
end

# 'require', you say? real men use:
(Dir['*.rb'] - [__FILE__]).each { |filename| load(filename) }

def exec_once(unique)
  if !$exec_once_hash.has_key?(unique)
    $exec_once_hash[unique] = nil
    yield
  end
end

# commands for interpreter
def play
  $engine ||= GameEngine.new
  $engine.games << StartupScreen.new
  $engine.mainloop
end
def stop
  $engine.destroy
  $engine = nil
end

#if !defined?($engine)
  case $0
  when __FILE__ then play
  when /irb/
  end
#end
