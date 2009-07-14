#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 13-10-06.
#  Copyright (c) 2008. All rights reserved.

require 'pop_ups.rb'


class Tool
  attr_reader :toolbar, :uses_toolbar, :no_depth
  def initialize status_text
    @status_text = status_text
    @glview = $manager.glview
    create_toolbar
    @uses_toolbar = false
    resume
  end
public
  def self.part2sketch( v, plane )
    o = plane.origin
    v - o
  end
  
  def self.sketch2part( v, plane )
    o = plane.origin
    v + o
  end

  def click_left( x,y )
    $manager.has_been_changed = true
  end
  
  def double_click( x,y )
  end
  
  def click_middle( x,y )
  end
  
  def click_right( x,y, time )
  end
  
  def drag_left( x,y )
  end
  
  def drag_middle( x,y )
  end
  
  def drag_right( x,y )
  end
  
  def mouse_move( x,y )
  end
  
  def press_left( x,y )
  end
  
  def press_right( x,y, time )
  end
  
  def release_left
  end
  
  def release_right
  end
  
  def button_release
  end
  
  def pause
    @glview.immediate_draw_routines.pop
  end
  
  def resume
    @draw_routine = lambda{ @glview.object_space($manager.work_component){ draw } }
    @glview.immediate_draw_routines.push @draw_routine
    $manager.set_status_text @status_text
  end
  
  def exit
    @glview.immediate_draw_routines.delete @draw_routine
    @glview.window.cursor = nil
  end
  
  #--- UI ---#
  def create_toolbar
    @toolbar = Gtk::Toolbar.new
    @toolbar.toolbar_style = Gtk::Toolbar::BOTH
    @toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    fill_toolbar 
    @toolbar.append( Gtk::SeparatorToolItem.new){}
    @toolbar.append( Gtk::Stock::OK, GetText._("Finish using tool"),"Tool/Ok"){ $manager.cancel_current_tool }
  end
  
  def fill_toolbar
    # should be overridden by subclasses
  end
private
  def draw
  end
end
                                                             ###

class CameraTool < Tool
  def initialize
    super( GetText._("Drag left to pan, drag right to rotate the camera, middle drag for zoom:") )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
  end
  
  def click_left( x,y )
    # is already handled by GLView
  end
  
  def press_left( x,y )
    super
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
  end
  
  def click_middle( x,y )
    super
    @glview.window.cursor =Gdk::Cursor.new Gdk::Cursor::SB_V_DOUBLE_ARROW
  end
  
  def press_right( x,y, time )
    super
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::EXCHANGE
  end
  
  def button_release
    super
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::FLEUR
  end
  
  def draw
    # is already handled by GLView
  end
end


class MeasureDistanceTool < Tool
  def initialize
    super( GetText._("Pick a series of points to display the lenght of the path along them:") )
    @points = []
  end
  
  def click_left( x,y )
    super
    pick_point x, y
  end
  
private
  def pick_point( x, y )
    @points.push( @glview.screen2world( x, y ) )
    display_distance
  end
  
  def display_distance
    dist = 0
    previous = nil
    @points.each do |p|
      dist += p.distance_to previous if previous
      previous = p
    end
    # lenght should be displayed even when tool was paused
    @status_text = GetText._("Distance:") + " #{dist}"
    $manager.set_status_text @status_text
  end
  
  def draw
    glcontext = @glview.gl_context
    gldrawable =  @glview.gl_drawable
    if gldrawable.gl_begin( glcontext )
      GL.LineWidth(3)
      GL.Color3f(1,0,1)
      previous = nil
      @points.each do |p|
        if previous
          GL.Begin( GL::LINES )
            GL.Vertex( previous.x, previous.y, previous.z )
            GL.Vertex( p.x, p.y, p.z )
          GL.End
        end
        previous = p
      end
      @points.each do |p|
        GL.Begin( GL::POINTS ) #XXX must be drawn taller
          GL.Vertex( p.x, p.y, p.z )
        GL.End
      end
    gldrawable.gl_end
    end
  end
end


require 'selection_tools.rb'
require 'sketch_tools.rb'








