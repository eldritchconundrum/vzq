# -*- coding: iso-8859-1 -*-
module ShootEmUpGame # en fait c'est pas spécifique au shmup...
  module View
    module Sprites # sprite building from resources
      include Drawers

#TODO: dériver de genre ConfBase2 ?

      #TODO: rename "make_" as "new_" or something
      def make_explosion_sprite
        # in the file name are the parameters to "phaedy explosion generator"
        get_animation_from_tileset('explosion_32_51_1_1_95_98_4_8.png', 7, 7, 32, 32).with(:z_order => 3) # on top
      end

      def make_basic_enemy_sprite
        drawer = FileDrawer.new('sprites/PsychoFox-SMS-Hippopotamus.png')
        drawer.mirror_left_right = true if rand < 0.5
        return file_sprite(drawer).with(:zoom => 1) #TODO: animate
      end

      def make_enemy2_enemy_sprite
        file_sprite(FileDrawer.new('sprites/PhantasyStar-SMS-DarkForce.png')).with(:zoom => 1)
      end

      def make_flying_honda
        file_sprite(FileDrawer.new('sprites/flyinghonda.png')).with(:zoom => 2)
      end

      def make_mario_kart_fish
        get_animation_from_tileset('sprites/mario-kart-fish_tileset.png', 2, 1, 95, 95).with(:zoom => 1)
      end

      def make_ship_sprite
        file_sprite(FileDrawer.new('sprites/SpyVsSpy-SMS-Heckel.png'))
      end

      def make_guile_sprite
        file_sprite(FileDrawer.new('sprites/StreetFighterII-SMS-Guile-FlashKick.png')).with(:zoom => 2)
      end

      def make_zelda_faery_tileset
        get_animation_from_tileset('sprites/zelda-faery_tileset.png', 2, 1, 16, 16).with(:zoom => 2)
      end

      def make_nyancat_sprite
        get_animation_from_tileset('sprites/nyancat_tileset.png', 12, 1, 53, 21).with(:zoom => 1)
      end

      def make_3_headed_monkey_sprite
        get_animation_from_tileset('sprites/3-headed-monkey_tileset.png', 15, 1, 50, 50).with(:zoom => 2)
      end

      def make_background_sprite
        #get_sprite(WrapperDrawer.new(FastDrawer.new('mandel')))
        #get_sprite(WrapperDrawer.new(FastDrawer.new('perlin'))).with(:zoom => 5)
        file_sprite(FileDrawer.new('bg_moon.png'))
      end
#puts '--------- TODO perlin debug:', Java.vzq.engine.PerlinNoise.noise(4.5, 5.5)

      def make_bonus1_sprite
        #get_sprite(TextDrawer.new('$', 24, RGBA[255, 128, 255]))
        #file_sprite(FileDrawer.new('sprites/MortalKombat-SMS-LiuKang-FlyingKick.png'))
        make_nyancat_sprite
      end

      def make_bonus2_sprite
        #get_sprite(TextDrawer.new('Â£', 24, RGBA[255, 255, 128]))
        #file_sprite(FileDrawer.new('sprites/CaliforniaGames-SMS-Surfboarder.png'))
        make_zelda_faery_tileset
      end

      def make_shoot1_sprite
        file_sprite(FileDrawer.new('sprites/fireball.png'))
      end

      def make_shoot2_sprite
        file_sprite(FileDrawer.new('sprites/fireball.png'))
      end

      def make_arrobase_sprite(multiplier)
        get_sprite(TextDrawer.new('@', 32 * (1 + Math.log(multiplier)), RGBA[255, 255, 0]))
      end

      def make_enemy_fire_sprite(char)
        get_sprite(TextDrawer.new(char, 32, RGBA[255, 128, 0]))
      end

      def preload_images
        FileDrawer.new('explosion_32_51_1_1_95_98_4_8.png').background_preload
      end

      private
      def file_sprite(*drawers)
        #drawers = filenames.collect { |f| f.respond_to?(:draw) ? f : FileDrawer.new(f) }
        NormalSprite.new { drawers.collect{ |d| Engine.texture_cache.get(d) } }
      end

      def get_animation_from_tileset(filename, xcount, ycount, xsize, ysize) # left to right then top to bottom
        drawers = []
        for y in (0..ycount-1)
          for x in (0..xcount-1)
            drawers << FileDrawer.new(filename, Point2D.new(x * xsize, y * ysize), Point2D.new(xsize, ysize))
          end
        end
        sprite = nil
        t = Utils.time {
          sprite = file_sprite(*drawers)
        }
        puts "creating animation from tileset '%s' took %s ms total" % [filename, t] if t > 40
        sprite
      end
    end
  end
end
