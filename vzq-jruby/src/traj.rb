# -*- coding: iso-8859-1 -*-

require 'collision_detection'

# TODO : see wavefunc class from song.ho vbo tuto

class Trajectory # abstract
  def initialize(time_origin, pos = nil)
    @time_origin = if time_origin.respond_to?(:time) then time_origin.time else time_origin.to_i end
    @pos_origin = pos
  end
  attr_accessor :pos_origin
  attr_reader :time_origin
  def elapsed_ms(time)
    time - @time_origin
  end
  def position(time) # takes a cached game time, returns a Point2D
    fail 'abstract'
  end
end

# TODO: find a way to combine easily trajectory calculators
# or just provide helper funcs and stop using them and use a different lambda formula every time

class LinearTraj < Trajectory
  def initialize(time_origin, pos, movement_vector)
    super(time_origin, pos)
    @movement_vector = movement_vector
  end
  def position(time)
    @pos_origin + @movement_vector * (elapsed_ms(time).to_f / 100)
  end
end

class SinusoidalTraj < Trajectory
  # amplitude is a factor of the given movement vector, 1 means a 45° maximum angle    #TODO: no it doesn't, yet.
  # freq is in Hz
  # phase: between 0 and 1
  def initialize(time_origin, pos, movement_vector, amplitude = 1, frequency = 1, phase = 0)
    super(time_origin, pos)
    @movement_vector, @amplitude, @frequency, @phase = movement_vector, amplitude, frequency, phase
    update_orthog_vect
    @movement_vector = V2I.new(@movement_vector.x, @movement_vector.y)
  end
  def update_orthog_vect
    @orthog_vect = V2I.new(-@movement_vector.y, @movement_vector.x)
  end
  def position(time) # time-critical. scala? TODO: tester. mais Point2D ? scala en batch aussi ?
    elapsed = elapsed_ms(time).to_f / 100.0
    k = Math.sin(Math::Tau * (@phase + @frequency * elapsed / 10)) * @amplitude
#    return @pos_origin + (@movement_vector * elapsed) + (@orthog_vect * k)
    return Point2D.new(@pos_origin.x + (@movement_vector.x * elapsed) + (@orthog_vect.x * k),
                       @pos_origin.y + (@movement_vector.y * elapsed) + (@orthog_vect.y * k))
  end
end

class CrossFadeTrajectoryComposition < Trajectory
  def initialize(time_origin, traj1, traj2, time_fade_start, time_fade_end) # ms
    super(time_origin, nil)
    @traj1, @traj2, @time_fade_start, @time_fade_end = traj1, traj2, time_fade_start, time_fade_end
  end
  def position(time)
    ms = elapsed_ms(time).to_f
    if ms < @time_fade_start then @traj1.position(time)
    elsif ms >= @time_fade_end then @traj2.position(time)
    else
      c = (ms - @time_fade_start) / (@time_fade_end - @time_fade_start)
      p1, p2 = @traj1.position(time), @traj2.position(time)
      p1 * (1 - c) + p2 * c
    end
  end
end
