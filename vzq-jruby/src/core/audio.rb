# -*- coding: iso-8859-1 -*-
require '../lib/javazoom/tritonus_share.jar'
require '../lib/javazoom/jl1.0.jar'
require '../lib/javazoom/mp3spi1.9.4.jar'

require '../lib/javazoom/jogg-0.0.7.jar'
require '../lib/javazoom/jorbis-0.0.15.jar'
require '../lib/javazoom/vorbisspi1.0.3.jar'

class SoundManagerSingleton
  include Singleton

  # list of the instances of SoundPlayer (to shut them up)
  def <<(sound_player)
    @@sound_players ||= []
    @@sound_players << sound_player
  end

  def stop_all
    @@sound_players ||= []
    for s in @@sound_players
      s.kill
    end
  end

  const_def :Snd, javax.sound.sampled

  # use JavaSound API to load the sound, and if necessary, javazoom's spi to decode mp3 and ogg
  def get_audio_input_stream(file) # works on filename, file, inputstream, or url
    file = java.io.File.new(file) if file.is_a?(String)
    #puts "  #{file}: audio file format:\t #{Snd.AudioSystem.getAudioFileFormat(file)}"
    stream = Snd.AudioSystem.getAudioInputStream(file)
    puts "  #{file}: format:\t #{stream.format}"
    if stream.format.encoding.to_s.match(/PCM/)
      return stream
    else
      target_format = Snd.AudioFormat.new(Snd.AudioFormat::Encoding::PCM_SIGNED,
                                          stream.format.sample_rate, 16,
                                          stream.format.channels, stream.format.channels * 2,
                                          stream.format.sample_rate, false)
      #puts "  conversion: target format:\t #{target_format}"
      decoded_stream = Snd.AudioSystem.getAudioInputStream(target_format, stream)
      fail "pas un PropertiesContainer javazoom" unless decoded_stream.is_a? Java.javazoom.spi.PropertiesContainer
      return decoded_stream
      # TODO: stream.close et decoded_stream.close
      # (mais ne pas fermer stream avant de lire decoded_stream sinon ogg marche plus)
    end
  end

end
const_def :SoundManager, SoundManagerSingleton.instance



require 'thread'
class SoundPlayer # plays a sound with JavaSound in a background thread
  const_def :Snd, javax.sound.sampled

  attr_reader :resource

  # TODO: a is_playing property

  # TODO: init avant play (évite les exceptions), mais threadsafe.

  def initialize(resource)
    SoundManager << self
    @resource = resource
    @thread = Thread.new { thread_play }
  end

  def play
    fail if @thread.nil?
    @thread_state = :play
  end

  def pause
    fail if @thread.nil?
    @thread_state = :paused
  end

  def reset
    fail if @thread.nil?
    @thread_state = :reset
  end

  def kill
    @thread_state = :die
    @thread = nil
  end

  private

  def reinit_audio_stream
    @audio_stream = SoundManager.get_audio_input_stream(@resource)
  end

  def thread_play
    reinit_audio_stream if @audio_stream.nil?

    data = ([0] * 4096).to_java(:byte)
    info = Snd.DataLine::Info.new(Snd.SourceDataLine.java_class, @audio_stream.format)
    line = Snd.AudioSystem.getLine(info)
    line.open(@audio_stream.format)
    line.start
    while true
      case @thread_state
      when :play
        r = @audio_stream.read(data, 0, data.length)
        if r != -1
          w = line.write(data, 0, r)
        else # reached end of stream
          @thread_state = :pause
        end
      when :pause
        sleep 0.03 # active loop is bad loop
      when :reset
        @audio_stream.close
        reinit_audio_stream
        @thread_state = :play
      when :die
        break
      end
    end
    line.drain
    line.stop
    line.close
    @audio_stream.close
    @audio_stream = nil
  rescue Exception => ex # don't ignore exceptions in other thread: enqueue it to be displayed at next frame
    Engine.enqueue_exception(ex)
  end

end

