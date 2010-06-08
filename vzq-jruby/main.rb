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

require 'sysutils'
puts 'bootstraping runtime environment'

$mtimes = {}
def load_if_mtime_changed(filename)
  mtime = File.mtime(filename)
  if $mtimes[filename] != mtime
    $mtimes[filename] = mtime
    load(filename)
  end
end

def reload_code
  # shuffle to ensure that the load order is not important
  (Dir['*.rb'] - [__FILE__]).shuffle.each { |filename| load_if_mtime_changed(filename) }
end

# func for live runtime alteration from code editor
$exec_once_hash ||= {}
def exec_once(unique) # ignore exec_once blocks that already are in the code at startup
  $exec_once_hash[unique] = nil
end
reload_code
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

case $0
when __FILE__ then play
when /irb/ then puts 'type "play" to play'
end
