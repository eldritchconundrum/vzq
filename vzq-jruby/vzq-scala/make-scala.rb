#!/usr/bin/env jruby

Dir.chdir(File.dirname(__FILE__))

$vzq_engine_jar = '../lib/vzq-engine.jar'
$scala_src = 'src/*.scala'
$java_src = 'src/*.java'
$all_src = 'src/*.{scala,java}'

out_mtime = File.mtime($vzq_engine_jar) rescue nil
puts Dir[$all_src].find_all { |f| out_mtime.nil? || File.mtime(f) > out_mtime }
if Dir[$all_src].any? { |f| out_mtime.nil? || File.mtime(f) > out_mtime }
  require 'rbconfig'
  require 'fileutils'
  include FileUtils

  case Config::CONFIG["host_os"]
  when /(msdos|mswin|djgpp|mingw)/i then $classpath_sep, $os_dir, $run = ';', 'windows', 'run.bat'
  when /mac/i                       then $classpath_sep, $os_dir, $run = ':', 'macosx', 'sh run.sh' # untested
  when /solaris/i                   then $classpath_sep, $os_dir, $run = ':', 'solaris', 'sh run.sh' # untested
  when /linux/i                     then $classpath_sep, $os_dir, $run = ':', 'linux', 'sh run.sh'
  end

  class Array
    def to_shell_file_list
      if $classpath_sep == ';'
        join(' ')
      else
        collect { |f| "'#{f}'" }.join(' ') # TODO: fully correct shell quoting support, not just single quotes
      end
    end
  end
  def print_and_exec(*args)
    if $classpath_sep == ';'
      args[0].sub!(/^scalac/, "C:\\Progra~1\\Scala-2.9.1\\bin\\scalac.bat")
      args[0].sub!(/^javac/, "c:\\Program Files\\Java\\jdk1.6.0\\bin\\javac.exe")
      args[0].sub!(/^jar/, "c:\\Program Files\\Java\\jdk1.6.0\\bin\\jar.exe")
    end

    puts '=== print_and_exec', *args
    fail 'system' unless system *args
  end

  $lwjgl_dir = Dir['../lib/lwjgl-*'].sort.last
  $lwjgl_jars = Dir[$lwjgl_dir + '/jar/*.jar']
  $scala_jars = Dir['../lib/scala-*.jar']
  $native_arg = "-Djava.library.path=#{$lwjgl_dir}/native/#{$os_dir}"

  def classpath_arg(files)
    '-classpath %s' % files.join($classpath_sep)
  end
  def compile(compiler, files, classpath)
    return if files.empty?
    print_and_exec "#{compiler} -d out #{classpath_arg(classpath)} #{files.to_shell_file_list}"
  end
  def scalac(*args); compile('scalac -g:vars -deprecation -unchecked', *args); end # or fsc
  def javac(*args); compile('javac -g', *args); end

  rm_rf 'out/'
  mkdir_p 'out'
  jars = $lwjgl_jars + $scala_jars
  # 1) scalac need to see java sources to compile succesfully java uses from scala
  # 2) javac then finds scala's .classes and does not complain about scala uses from java
  scalac Dir[$all_src], jars
  javac Dir[$java_src], (jars + ['out/'])
  Dir.chdir('out') do
    print_and_exec "jar cf ../#{$vzq_engine_jar} #{Dir['**/*.class'].to_shell_file_list}"
  end
  rm_rf 'out/'
end
