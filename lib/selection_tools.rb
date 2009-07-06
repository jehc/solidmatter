#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 7-7-09.
#  Copyright (c) 2009. All rights reserved.

require 'tools.rb'


class SelectionTool < Tool
  def initialize text
    super text
    @selection = nil
    @callback = Proc.new if block_given?
    @glview.rebuild_selection_pass_colors selection_modes
  end
  
  def selection_modes
    raise "Must be overridden"
  end
  
  def exit
    super
    @callback.call @selection if @callback
  end
end


class PartSelectionTool < SelectionTool
  def initialize
    super( GetText._("Drag a part to move it around, right click for options:") )
  end
  
  def selection_modes
    [:instances]
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    if @current_comp
      if $manager.key_pressed? :Shift
        $manager.selection.add @current_comp
      else
        $manager.select @current_comp
      end
    else
      $manager.selection.deselect_all
    end
    $manager.op_view.select @current_comp
  end
  
  def double_click( x,y )
    super
    real_sel = $manager.selection.first
    if real_sel
      $manager.change_working_level real_sel 
    else
      $manager.working_level_up
    end
  end
  
  def mouse_move( x,y )
    super
    @current_comp = $manager.top_ancestor @glview.select(x,y)
    @glview.redraw
  end
  
  def press_right( x,y, time )
    super
    click_left( x,y )
    sel = $manager.selection.first
    menu = sel ? ComponentMenu.new( sel, :glview) : BackgroundMenu.new
    menu.popup(nil, nil, 3,  time)
  end
  
  def draw
    super
    GL.Color4f( 0.9, 0.2, 0, 0.5 )
    GL.Disable(GL::POLYGON_OFFSET_FILL)
    #@current_part.solid.faces.each{|f| f.draw } if @current_part
    if @current_comp
      parts = (@current_comp.class == Assembly) ? @current_comp.contained_parts : [@current_comp]
      for list in parts.map{|p| p.displaylist }
        GL.CallList list
      end
    end
    GL.Enable(GL::POLYGON_OFFSET_FILL)
  end
end


class OperatorSelectionTool < SelectionTool
  def initialize
    super( GetText._("Select a feature from your model, right click for options:") )
    @draw_faces = []
    #part = $manager.work_component
    #@op_displaylists = {}
    #part.operators.map do |op| 
    #  faces = part.solid.faces.select{|f| f.created_by_op == op }
    #  list = @glview.add_displaylist
    #  GL.NewList( list, GL::COMPILE)
    #    faces.each{|f| f.draw }
    #  GL.EndList
    #  @op_displaylists[op] = list
    #end
  end
  
  def selection_modes
    [:faces, :dimensions]
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    if (dim = @glview.select(x,y)).is_a? Dimension
      FloatingEntry.new( x,y, dim.value ) do |value| 
        dim.value = value
        $manager.work_component.build @op
        @glview.redraw
      end
    else
      mouse_move( x,y )
      @dims.each{|d| d.visible = false } if @dims
      if @current_face
        @op = @current_face.created_by_op
        sk = @op.settings[:sketch]
        @dims = (@op.dimensions + (sk ? sk.dimensions : [])).flatten
        @dims.each{|d| d.visible = true }
      end
    end
    @glview.redraw
  end
  
  def double_click( x,y )
    super
    mouse_move( x,y )
    if @current_face
    #if @current_op
      op = @current_face.created_by_op
      $manager.exit_current_mode
      $manager.operator_mode op
      #$manager.operator_mode @current_op
    else
      $manager.working_level_up
    end
  end
  
  def mouse_move( x,y )
    super
    sel = @glview.select(x,y)
    raise "Wörkking plane" if sel.is_a? WorkingPlane
    @current_face = nil
    @current_face = sel if sel.is_a? Face and $manager.work_component.operators.include? sel.created_by_op
    @draw_faces = @current_face ? @current_face.solid.faces.select{|f| f.created_by_op == @current_face.created_by_op } : []
    #face = @glview.select(x,y, :select_faces)
    #@current_op = (face and @op_displaylists[face.created_by_op]) ? face.created_by_op : nil
    @glview.redraw
  end
  
  def click_right( x,y, time )
    super
    mouse_move( x,y )
    if @current_face
      OperatorMenu.new( @current_face.created_by_op).popup(nil, nil, 3,  time)
    else
      BackgroundMenu.new.popup(nil, nil, 3,  time)
    end
  end
  
  def draw
    super
    GL.Color4f( 0.9, 0.2, 0.0, 0.5 )
    GL.Disable(GL::POLYGON_OFFSET_FILL)
    @draw_faces.each{|f| f.draw }
    #GL.CallList @op_displaylists[@current_op] if @current_op
    GL.Enable(GL::POLYGON_OFFSET_FILL)
  end
  
  def exit
    super
    #@op_displaylists.values.each{|l| @glview.delete_displaylist l }
    @dims.each{|d| d.visible = false } if @dims
  end
end


Region = Struct.new(:chain, :poly, :face)
class RegionSelectionTool < SelectionTool
  attr_accessor :selection
  def initialize
    super( GetText._("Pick a closed region from a sketch:") )
    @selection = []
    # create a list of regions that can be picked
    @op_sketch = $manager.work_operator.settings[:sketch]
    @all_sketches = ($manager.work_component.unused_sketches + [@op_sketch]).compact
    @regions = @all_sketches.inject([]) do |regions, sketch|
      regions + sketch.all_chains.reverse.map do |chain|
        poly = Polygon.from_chain chain #.map{|seg| seg.tesselate }.flatten
        face = PlanarFace.new
        face.plane = sketch.plane.plane
        sketch.plane.build_displaylists
        face.segments = chain.map{|seg| seg.tesselate }.flatten.map{|seg| Line.new(Tool.sketch2world(seg.pos1, sketch.plane.plane), Tool.sketch2world(seg.pos2, sketch.plane.plane), sketch)  }
        Region.new(chain, poly, face)
      end
    end
    @regions.compact!
    $manager.on_key_released(:Shift) do
      if @selection.empty?
        true
      else
        $manager.cancel_current_tool 
        false
      end
    end
    @op_sketch.visible = true if @op_sketch
    @glview.redraw
  end
  
  def selection_modes
    [:planes]
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    if @current_region
      if $manager.key_pressed? :Shift
        if @selection.include? @current_region.chain
          @selection.delete @current_region.chain
        else
          @selection.push @current_region.chain
        end
      else
        @selection = [@current_region.chain]
        $manager.cancel_current_tool
      end
    end
  end

  def mouse_move( x,y )
    super
    for sketch in @all_sketches
      sketch.plane.visible = true
      sel = @glview.select(x,y, [:planes])
      sketch.plane.visible = false
      if sel and pos = pos_of( x,y, sel )
        @current_region = @regions.select{|r| r.face.plane == sel.plane and r.poly.contains? Point.new( pos.x, pos.z ) }.first
        @glview.redraw
        break if @current_region
      end
    end
    @glview.window.cursor = @current_region ? Gdk::Cursor.new(Gdk::Cursor::HAND2) : nil
  end
  
  def draw
    super
    GL.Disable(GL::POLYGON_OFFSET_FILL)
    if @current_region
      GL.Color4f( 0.9, 0.2, 0, 0.5 )
      @current_region.face.draw
    end
    unless @selection.empty?
      GL.Color4f( 0.2, 0.5, 0.8, 0.5 )
      regions = @regions.select{|r| @selection.include? r.chain }
      regions.each{|r| r.face.draw }
    end
    GL.Enable(GL::POLYGON_OFFSET_FILL)
  end
  
  def pos_of( x,y, plane )
    planestate = plane.visible
    plane.visible = true
    pos = @glview.screen2world( x,y )
    pos = Tool.world2sketch( pos, plane.plane ) if pos
    plane.visible = planestate
    return pos
  end
  
  def exit
  # @all_sketches.each { |s| s.plane.visible = false }
    @op_sketch.visible = false if @op_sketch
    super
  end
end


class PlaneSelectionTool < SelectionTool
  def initialize
    super( GetText._("Select a single plane:") )
    $manager.work_component.working_planes.each{|plane| plane.visible = true }
  end
  
  def selection_modes
    [:faces, :planes]
  end
  
  def click_left( x,y )
    super
    sel = @glview.select(x,y, [:faces, :planes])
    if sel
      @selection = sel.plane
      $manager.cancel_current_tool
    end
  end
  
  def exit
    $manager.work_component.working_planes.each{|plane| plane.visible = false }
    super
  end
end


class FaceSelectionTool < SelectionTool
  def initialize
    super GetText._("Select solid faces or surfaces:")
  end
  
  def selection_modes
    [:faces]
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    if @current_face
      @selection = @current_face
      $manager.cancel_current_tool
    end
  end
  
  def mouse_move( x,y )
    super
    @current_face = @glview.select(x,y, [:faces])
    raise "Wörkking plane" if @current_face.is_a? WorkingPlane
    @current_face = nil unless $manager.work_component.solid.faces.include? @current_face
    @glview.redraw
  end
  
  def draw
    super
    GL.Color4f( 0.9, 0.2, 0.0, 0.5 )
    GL.Disable(GL::POLYGON_OFFSET_FILL)
    @current_face.draw if @current_face
    GL.Enable(GL::POLYGON_OFFSET_FILL)
  end
end


class EdgeSelectionTool < SelectionTool
  def initialize
    super GetText._("Select edges:")
    @no_depth = true
  end
  
  def selection_modes
    $manager.work_operator.is_a?(RevolveOperator) ? [:segments] : [:edges]
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    if @current_edge
      @selection = @current_edge
      $manager.cancel_current_tool
    end
  end
  
  def mouse_move( x,y )
    super
    @current_edge = @glview.select( x,y, selection_modes )
    @glview.redraw
  end
  
  def draw
    super
    GL.Color4f( 0.9, 0.2, 0.0, 0.5 )
    @current_edge.draw if @current_edge
  end
  
  def resume
    super
  end
end


class TweakTool < SelectionTool
    def initialize
    super GetText._("Select solid faces and drag the arrow to change your objects shape:")
  end
  
  def selection_modes
    [:faces, :handles]
  end
  
  def click_left( x,y )
    super
    if @current_face
      points = @selection.segments.map{|s| s.snap_points }.flatten
      center = points.inject{|sum, p| sum + p } / points.size
      $manager.glview.handles.delete @handle
      @handle = ArrowHandle.new( center, dir )
      $manager.glview.handles.push @handle
    end
  end
  
  def press_left
    super
    mouse_move( x,y )
    if @current_handle
    
    end
  end
  
  def drag_left( x,y )
    
  end
  
  def release_left
    
  end
  
  def mouse_move( x,y )
    super
    @current_face = @glview.select(x,y, [:faces])
    @current_face = nil unless $manager.work_component.solid.faces.include? @current_face
    @current_handle = @glview.select(x,y, [:handles])
    @glview.redraw
  end
  
  def draw
    super
    GL.Color4f( 0.9, 0.2, 0.0, 0.5 )
    GL.Disable(GL::POLYGON_OFFSET_FILL)
    @current_face.draw if @current_face
    GL.Enable(GL::POLYGON_OFFSET_FILL)
  end
  
  def exit
    $manager.glview.handles.delete @handle
    super
  end
end




