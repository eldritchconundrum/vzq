def java_startup
  puts "RUBY_PLATFORM != java, shouldn't you be running jruby?" unless RUBY_PLATFORM.match(/java/) #"emacs coloration fail
  require 'java'
  gp = lambda { |s| java.lang.System.getProperty(s) }
  lwjgl_version = gp.call('java.library.path').match(/lwjgl-[^\/]+/).to_s
  puts 'use the run script (it sets java.library.path for you)' if lwjgl_version. == ''
  puts 'using java vm %s %s and %s' % [gp.call('java.vm.vendor'), gp.call('java.vm.version'), lwjgl_version]
  jars = "lib/%s/**/*.jar" % lwjgl_version
  puts 'loading jars: %s' % jars if $VERBOSE
  Dir[jars].each { |jar| puts jar if $VERBOSE; require jar }
end

java_startup
GL11 = org.lwjgl.opengl.GL11 unless defined?(GL11)

puts 'bootstraping runtime environment'

$mtimes = {}
def try_to_reload_code
  (Dir['*.rb'] - ['main.rb']).sort_by { rand(3) - 1 }.each { |filename|
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

# func for live runtime alteration
$exec_once_hash = {}
def exec_once(unique) # ignore exec_once that already are in the code at startup
  $exec_once_hash[unique] = nil
end

# 'require', you say? real men use:
(Dir['*.rb'] - ['main.rb']).each { |filename| load(filename) }

def exec_once(unique)
  if !$exec_once_hash.has_key?(unique)
    $exec_once_hash[unique] = nil
    yield
  end
end

# commands for interpreter
def init
  $engine ||= GameEngine.new
end
def play
  init
  $engine.play(MenuScreen.new($engine))
end
def stop
  $engine.destroy
  $engine = nil
end

if !defined?($engine)
  case $0
  when 'main.rb' then play
  when /irb/
    puts "Welcome to the closure science enrichment interpreter. Type 'play' to play, 'quit' to quit, 'cake' to get a cake. "
    def cake; raise 'lie'; end
    $cube = '[ <3 ]'
  end
end
