#--
#
# Chingu -- OpenGL accelerated 2D game framework for Ruby
# Copyright (C) 2009 ippa / ippa@rubylicio.us
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#++

module Chingu
  module GameStates
  
    #
    # Premade game state for chingu - simple level editing.
    # Start editing in a gamestate with:
    #   push_game_state(Chingu::GameStates::Edit)
    #
    # requires the global $window set to the instance of Gosu::Window (automaticly handled if you use Chingu::Window)
    #
    # Edit will only edit game objects created with the editor itself or that's been loaded with load_game_objects.
    # This makes mixing of loaded game objects and code create game objects possible, in the game, and in the editor.
    #
    # Various shortcuts are available in the editor
    #
    # 1-5: create object 1..5 shown in toolbar
    # DEL: delete selected objects
    # CTRL+A: select all objects (not code-created ones though)
    # S: Save
    # E: Save and Quit
    # Right Mouse Button Click: Copy object that was clicked on for fast duplication
    # Arrows: Scroll within a viewport
    # Page up/down: Modify the zorder of selected game objects
    #
    class Edit < Chingu::GameState
      attr_accessor :grid, :debug, :file, :hud_color
      attr_reader :classes, :exclude
      
      def initialize(options = {})
        super
        @grid = options[:grid] || [8,8]
        @classes = Array(options[:classes]) || game_object_classes
        @except = options[:except] || []
        @classes -= Array(@except)
        
        @debug = options[:debug]
        @zorder = 10000
        
        @hud_color = Gosu::Color.new(180,70,70,70)
        @selected_game_object = nil        
        self.input =  { 
          :left_mouse_button => :left_mouse_button, 
          :released_left_mouse_button => :released_left_mouse_button,
          :right_mouse_button => :right_mouse_button,
          :released_right_mouse_button => :released_right_mouse_button, 
                        
          :delete => :destroy_selected_game_objects,
          :backspace => :reset_selected_game_objects,
                        
          :holding_numpad_8 => :scale_up,
          :holding_numpad_4 => :tilt_left,
          :holding_numpad_5 => :scale_down,
          :holding_numpad_6 => :tilt_right,
          :tab => :save_and_quit,
                     
          :s => :try_save,
          :a => :try_select_all,
    
          :esc => :save_and_quit,
          :q => :quit,
          
          :holding_up_arrow => :scroll_up,
          :holding_down_arrow => :scroll_down,
          :holding_left_arrow => :scroll_left,
          :holding_right_arrow => :scroll_right,
                        
          :page_up => :inc_zorder,
          :page_down => :dec_zorder,
          :plus => :scale_up,
          :minus => :scale_down,
          :mouse_wheel_up => :scale_up,
          :mouse_wheel_down => :scale_down,
                        
          :"1" => :create_object_1,
          :"2" => :create_object_2,
          :"3" => :create_object_3,
          :"4" => :create_object_4,
          :"5" => :create_object_5,
        }
        
        x = 20
        y = 60
        @classes.each do |klass|
          puts "Creating a #{klass}"  if @debug
          
          # We initialize x,y,zorder,rotation_center after creation
          # so they're not overwritten by the class initialize/setup or simular
          game_object = klass.create
          game_object.x = x
          game_object.y = y
          game_object.zorder = @zorder
          game_object.options[:toolbar] = true
          
          # Scale down big objects, don't scale objects under [32, 32]
          if game_object.image
            game_object.factor_x = 32.0 / game_object.image.width   if game_object.image.width > 32
            game_object.factor_y = 32.0 / game_object.image.height  if game_object.image.height > 3
          end          
          x += 40
        end
      end
      
      #
      # SETUP
      #
      def setup
        @scroll_border_thickness = 50
        @file = options[:file] || previous_game_state.filename + ".yml"
        @title = Text.create("File: #{@file}", :x => 5, :y => 2, :factor => 1, :size => 16, :zorder => @zorder)
        @title.text += " - Grid: #{@grid}" if @grid
        @text = Text.create("", :x => 200, :y => 20, :factor => 1, :size => 16, :zorder => @zorder)
        @status_text = Text.create("-", :x => 5, :y => 20, :factor => 1, :size => 16, :zorder => @zorder)
      end
                  
      #
      # UPDATE
      #
      def update
        # Sync all changes to previous game states game objects list
        # This is needed since we don't call update on it.
        previous_game_state.game_objects.sync
        
        super
        
        #
        # We got a selected game object
        #
        if s = @selected_game_object
          @text.text = "#{s.class.to_s} @ #{s.x.to_i} / #{s.y.to_i}"
          @text.text += " [S: #{sprintf("%.2f", s.factor_x)}/#{sprintf("%.2f", s.factor_y)} A: #{s.angle.to_i} Z: #{s.zorder}]"
        end
        
        #
        # We got a selected game object and the left mouse button is held down
        #
        if @left_mouse_button && @selected_game_object
          selected_game_objects.each do |selected_game_object|            
            selected_game_object.x = self.mouse_x + selected_game_object.options[:mouse_x_offset]
            selected_game_object.y = self.mouse_y + selected_game_object.options[:mouse_y_offset]
            selected_game_object.x -= selected_game_object.x % @grid[0]
            selected_game_object.y -= selected_game_object.y % @grid[1]
          end
          
          # TODO: better cleaner sollution
          if @selected_game_object.respond_to?(:bounding_box)
            @selected_game_object.bounding_box.x = @selected_game_object.x
            @selected_game_object.bounding_box.y = @selected_game_object.y
          end
        elsif @left_mouse_button
          if defined?(self.previous_game_state.viewport)
            self.previous_game_state.viewport.x = @left_mouse_click_at[0] - $window.mouse_x
            self.previous_game_state.viewport.y = @left_mouse_click_at[1] - $window.mouse_y
          end
        end
        
        if inside_window?($window.mouse_x, $window.mouse_y)
          scroll_right  if $window.mouse_x > $window.width - @scroll_border_thickness
          scroll_left   if $window.mouse_x < @scroll_border_thickness
          scroll_up     if $window.mouse_y < @scroll_border_thickness
          scroll_down   if $window.mouse_y > $window.height - @scroll_border_thickness
        end
        
        @status_text.text = "#{self.mouse_x} / #{self.mouse_y}"
      end
      
      #
      # DRAW
      #
      def draw
        # Draw prev game state onto screen (the level we're editing)
        previous_game_state.draw
        
        super
        
        #
        # Draw an edit HUD
        #
        $window.draw_quad(  0,0,@hud_color,
                            $window.width,0,@hud_color,
                            $window.width,100,@hud_color,
                            0,100,@hud_color, @zorder-1)
        
        #
        # Draw red rectangles/circles around all selected game objects
        #
        selected_game_objects.each { |game_object| game_object.draw_debug }
        
        if @cursor_game_object
          @cursor_game_object.draw_at($window.mouse_x, $window.mouse_y)
        else
          draw_cursor_at($window.mouse_x, $window.mouse_y)
        end
      end
      
      #
      # CLICKED LEFT MOUSE BUTTON
      #
      def left_mouse_button
        @left_mouse_button  = true
        
        if defined?(self.previous_game_state.viewport)
          @left_mouse_click_at = [self.previous_game_state.viewport.x + $window.mouse_x, self.previous_game_state.viewport.y + $window.mouse_y]
        else
          @left_mouse_click_at = [$window.mouse_x, $window.mouse_y]
        end
        
        if @cursor_game_object && empty_area_at_cursor
          game_object = @cursor_game_object.class.create(:parent => previous_game_state)
          game_object.update
          game_object.options[:selected] = true
          game_object.options[:created_with_editor] = true
          game_object.x = self.mouse_x
          game_object.y = self.mouse_y
          
          unless @cursor_game_object.options[:toolbar]
            game_object.angle = @cursor_game_object.angle
            game_object.factor_x = @cursor_game_object.factor_x
            game_object.factor_y = @cursor_game_object.factor_y
            game_object.color = @cursor_game_object.color
            game_object.zorder = @cursor_game_object.zorder
            @cursor_game_object.update
          end
        end

        # Check if user clicked on anything in the icon-toolbar of available game objects
        @cursor_game_object = game_object_icon_at($window.mouse_x, $window.mouse_y)

        # Get editable game object that was clicked at (if any)
        @selected_game_object = game_object_at(self.mouse_x, self.mouse_y)
        
        if @selected_game_object && defined?(self.previous_game_state.viewport)
          self.previous_game_state.viewport.center_around(@selected_game_object)  if @left_double_click
        end
                      
        if @selected_game_object
          #
          # If clicking on a new object that's wasn't previosly selected
          #  --> deselect all objects unless holding left_ctrl
          #
          if @selected_game_object.options[:selected] == nil
            selected_game_objects.each { |object| object.options[:selected] = nil } unless holding?(:left_ctrl)
          end
          
          if holding?(:left_ctrl)
            # Toggle selection
            @selected_game_object.options[:selected] =  !@selected_game_object.options[:selected]
          else
            @selected_game_object.options[:selected] = true
          end
          
          #
          # Re-align all objects x/y offset in relevance to the cursor
          #
          selected_game_objects.each do |selected_game_object|
            selected_game_object.options[:mouse_x_offset] = selected_game_object.x - self.mouse_x
            selected_game_object.options[:mouse_y_offset] = selected_game_object.y - self.mouse_y
          end
        else
          deselect_selected_game_objects unless holding?(:left_ctrl)
        end
      end
      
      def right_mouse_button
        @cursor_game_object = game_object_at(self.mouse_x, self.mouse_y)
        
      end
      def released_right_mouse_button
      end
            
      #
      # RELASED LEFT MOUSE BUTTON
      #
      def released_left_mouse_button
        @left_mouse_button = false
      end

      #
      # Returns a list of game objects the editor can create. 2 types of object gets this flag:
      # - An object loaded with load_game_objects
      # - An object created from within the editor
      #
      # This helps us mix code-created with editor-created objects inside the editor and not muck around with
      # the code-created ones.
      #
      def editable_game_objects
        previous_game_state.game_objects.select { |o| o.options[:created_with_editor] }
      end
      
      #
      # Returns a list of selected game objects
      #
      def selected_game_objects
        editable_game_objects.select { |o| o.options[:selected] }
      end
      
      #
      # Call destroy on all selected game objects
      #
      def destroy_selected_game_objects
        selected_game_objects.each(&:destroy)
      end

      def deselect_selected_game_objects
        selected_game_objects.each { |object| object.options[:selected] = nil }
      end
      
      def empty_area_at_cursor
        game_object_at(self.mouse_x, self.mouse_y)==nil && 
        game_object_icon_at($window.mouse_x, $window.mouse_y) == nil
      end

      #
      # Get all classes based on GameObject except Chingus internal classes.
      #
      def game_object_classes
        ObjectSpace.enum_for(:each_object, class << GameObject; self; end).to_a.select do |game_class|
          game_class.instance_methods && !game_class.to_s.include?("Chingu::")
        end
      end      
      
      def create_object_nr(number)
        c = @classes[number].create(:x => self.mouse_x, :y => self.mouse_y, :parent => previous_game_state)  if @classes[number]
        c.options[:created_with_editor] = true
        c.update
        #@text.text = "Created a #{c.class} @ #{c.x} / #{c.y}"
      end
      
      def create_object_1; create_object_nr(0); end
      def create_object_2; create_object_nr(1); end
      def create_object_3; create_object_nr(2); end
      def create_object_4; create_object_nr(3); end
      def create_object_5; create_object_nr(4); end

      #
      # Resets selected game objects defaults, angle=0, scale=1.
      #
      def reset_selected_game_objects
        selected_game_objects.each do |game_object|
          game_object.angle = 0
          game_object.scale = 1
        end
      end

      def game_object_icon_at(x, y)
        game_objects.select do |game_object| 
          game_object.respond_to?(:collision_at?) && game_object.collision_at?(x,y)
        end.first
      end

      def game_object_at(x, y)
        editable_game_objects.select do |game_object| 
          game_object.respond_to?(:collision_at?) && game_object.collision_at?(x,y)
        end.first
      end

      #
      # draw a simple triangle-shaped cursor
      #
      def draw_cursor_at(x, y, c = Color::WHITE)
        $window.draw_triangle(x, y, c, x, y+10, c, x+10, y+10, c, @zorder + 10)
      end

      def try_select_all
        editable_game_objects.each { |x| x.options[:selected] = true }  if holding?(:left_ctrl)
      end
      def try_save
        save if holding?(:left_ctrl)
      end
      
      def quit
        pop_game_state(:setup => false)
      end
      def save 
        save_game_objects(:game_objects => editable_game_objects, :file => @file, :classes => @classes)
      end
      def save_and_quit
        save unless holding?(:left_ctrl)
        quit
      end

      def tilt_left
        selected_game_objects.each { |game_object| game_object.angle -= 1 }
      end
      def tilt_right
        selected_game_objects.each { |game_object| game_object.angle += 1 }        
      end
      def scale_up
        selected_game_objects.each { |game_object| game_object.factor_x += 0.01 }
        selected_game_objects.each { |game_object| game_object.factor_y += 0.01 }
      end
      def scale_down
        selected_game_objects.each { |game_object| game_object.factor_x -= 0.01 }
        selected_game_objects.each { |game_object| game_object.factor_y -= 0.01 }
      end
      def inc_zorder
        selected_game_objects.each { |game_object| game_object.zorder += 1 }
      end
      def dec_zorder
        selected_game_objects.each { |game_object| game_object.zorder -= 1 }
      end
      def page_up
        self.previous_game_state.viewport.y -= $window.height if defined?(self.previous_game_state.viewport)
      end
      def page_down
        self.previous_game_state.viewport.y += $window.height if defined?(self.previous_game_state.viewport)
      end
      def scroll_up
        self.previous_game_state.viewport.y -= 10 if defined?(self.previous_game_state.viewport)
      end
      def scroll_down
        self.previous_game_state.viewport.y += 10 if defined?(self.previous_game_state.viewport)
      end
      def scroll_left
        self.previous_game_state.viewport.x -= 10 if defined?(self.previous_game_state.viewport)
      end
      def scroll_right
        self.previous_game_state.viewport.x += 10 if defined?(self.previous_game_state.viewport)
      end
      def mouse_x
        x = $window.mouse_x
        x += self.previous_game_state.viewport.x if defined?(self.previous_game_state.viewport)
      end
      def mouse_y
        y = $window.mouse_y
        y += self.previous_game_state.viewport.y if defined?(self.previous_game_state.viewport)
      end

      def inside_window?(x = $window.mouse_x, y = $window.mouse_y)
        x >= 0 && x <= $window.width && y >= 0 && y <= $window.height
      end

      #
      # If we're editing a game state with automaticly called special methods, 
      # the following takes care of those.
      #
      def method_missing(symbol, *args)
        if symbol != :button_down || symbol != :button_up
          previous_game_state.__send__(symbol, *args)
        end
      end
      
    end
  end
end
