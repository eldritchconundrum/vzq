# -*- coding: iso-8859-1 -*-
class FileBrowser < GameScreen
  def initialize(path = JRuby.runtime.current_directory)
    super()
    @path = path
    @index = 0
  end

# à voir : le path '.' de VZQ change suivant la frame

  def cached_dir_content
    @dir_content_cache ||= AsyncCache.new { |key|
      Dir.new(key).to_a
    }
    @dir_content_cache.get(@path)
  end

  def inactive_draw
    write(@path, Point2D.new(20, 5))
    h = 30
    i = 0
    cached_dir_content.each { |filename|
      write(filename, Point2D.new(50, h))
      write("->", Point2D.new(0, h)) if i == @index
      h += 15
      i += 1
    }
  end

  def process_input
    result = super
    wheel = Mouse.getDWheel
    if wheel != 0
      puts "wheel=%s" % wheel
      @index += wheel < 0 ? -wheel / 120 : -wheel / 120
      @index %= cached_dir_content.size
    end
    return result
  end

  def exec_current_item
    filename = cached_dir_content[@index]
    puts "  exec #{filename}"
    full_path = @path + '/' + filename
    if File.directory?(full_path)
      @path = File.expand_path(full_path)
    else
      case full_path
      when /.sh$/ then exec_cmd("/bin/sh #{full_path}")
      when /.txt$/i then exec_cmd("notepad #{full_path}")
      when /.rb$/ #then load full_path#exec_cmd("/usr/bin/ruby #{full_path}")
      else puts "unknown extension. ignoring"
      end
    end
  end
  def exec_cmd(cmd)
    puts("exec: \n" + cmd)
    system "#{cmd} > stdout.tmp 2> stderr.tmp"
  end

  def process_key(ctrl, shift, key)
    case key
    when Keyboard::KEY_F5 then @dir_content_cache = nil
    when Keyboard::KEY_L then @dir_content_cache = nil if ctrl
    when Keyboard::KEY_RETURN, Keyboard::KEY_NUMPADENTER
      exec_current_item
    else super(ctrl, shift, key)
    end
  end
end

TitleGameScreens[FileBrowser] = "file browser"
