
#const_undef :LwjglKeyboardKey
#const_undef :LwjglKeyboardKeyBase
#const_undef :KeyTableSingleton
#const_undef :KeyTable

const_def :LwjglKeyboardKeyBase, ClassWithFields([:name, :value])
class LwjglKeyboardKey < LwjglKeyboardKeyBase
  def to_s
    "%s %s" % [value.to_s.ljust(10), name[4..-1]]
  end
end

class KeyTableSingleton
  const_def :Keyboard, org.lwjgl.input.Keyboard
  include Singleton
  def initialize
    list = Keyboard.constants.reject {|c| !c.to_s.match(/^KEY_/) }
    list = list.collect { |c| LwjglKeyboardKey.new(c, eval('Keyboard::' + c).to_i) }
    @h = list.to_hash(false) { |key| key.value }
  end
  def [](key_value)
    @h[key_value]
  end
  def to_showable_list
    @h.values.sort_by { |key| key.value }.collect { |x| x.to_s }
  end
end
const_def :KeyTable, KeyTableSingleton.instance

# TODO: la souris ! la souris !

# TODO: a keyboard mapping screen, and a module to include in screens to make them support user-defined bindings

class InputScreen < GameScreen
  def initialize
    super()
    @scroll_index = 0
    @listening = false
    @wheel = 0
    @buttons_down = nil
    @input = nil
  end
  def inactive_draw
    inactive_draw_lower_screen
    color = RGBA[64, 16, 0, 192]
    get_sprite(Filled.new(color)).with(:zoom => EngineConfig.ortho).draw

    # key table
    table = KeyTable.to_showable_list + ['-' * 42]
    index = @scroll_index % table.size
    list = (table + table)[index...index+table.size]
    write_list(list, lambda { |i| Point2D.new(10, 0 + i * 10) }, 10)

    write("press space to enter listen mode", Point2D.new(180, 50))
    write("Listening...", Point2D.new(180, 100)) if @listening
    unless @input.nil?
      key = KeyTable[@input[2]]
      key = "none :-(" if key.value == 0
      input_desc = "%s%s%s" % [@input[0] ? 'ctrl + ' : '', @input[1] ? 'shift + ' : '', key]
      write(input_desc, Point2D.new(180, 150))
    end
    write("Mouse: wheel=%s, %s buttons (%s)" %
          [Mouse.has_wheel, Mouse.button_count,
           (0...Mouse.button_count).map { |i| Mouse.get_button_name(i) }.join(', ')
          ], Point2D.new(180, 300))
    write("wheel=%s (%s)" % [@wheel, @wheel / 120], Point2D.new(180, 350)) unless @wheel == 0
    write("buttons down=%s" % [@buttons_down * ', '], Point2D.new(180, 400)) unless @buttons_down.nil?
    clipboard = org.lwjgl.Sys.get_clipboard
    write("clipboard content: %s" % clipboard, Point2D.new(180, 450)) unless clipboard.nil?
  end
  def process_input
    result = super
    wheel = Mouse.getDWheel
    if @listening && wheel != 0
      @wheel = wheel
      @listening = false
    end
    buttons_down = (0...Mouse.button_count).map { |i| Mouse.is_button_down(i) }
    if @listening && buttons_down.any?
      @buttons_down = buttons_down
      @listening = false
    end
    return result
  end
  def process_key(ctrl, shift, key)
    if @listening
      @input = [ctrl, shift, key]
      @listening = false
    else
      case key
      when Keyboard::KEY_SPACE then @listening = true; @input = nil; @wheel = 0; @buttons_down = nil
      when Keyboard::KEY_DOWN then @scroll_index += 5
      when Keyboard::KEY_UP then @scroll_index -= 5
      when Keyboard::KEY_NEXT then @scroll_index += 20
      when Keyboard::KEY_PRIOR then @scroll_index -= 20
      else super
      end
    end
  end
end

TitleGameScreens[InputScreen] = "input test screen"
