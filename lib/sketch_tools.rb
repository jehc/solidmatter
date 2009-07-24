#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 7-7-09.
#  Copyright (c) 2009. All rights reserved.

require 'tools.rb'


class SketchTool < Tool
  attr_accessor :create_reference_geometry
  def initialize( text, sketch )
    super text
    @sketch = sketch    
    @last_reference_points = []
    @create_reference_geometry = false
    @does_snap = true
    @temp_segments = []
  end
  
  def resume
    super
    @glview.rebuild_selection_pass_colors [:segments, :dimensions]
  end
  
  # snap points to guides, then to other points, then to grid
  def snapped( x,y, excluded=[] )
    guide = [@x_guide,@z_guide].compact.first
    point = if guide and $manager.use_sketch_guides
              guide.last
            else
              point = @glview.screen2world( x, y ) 
              point ? world2sketch(point) : nil
            end
    if point
      was_point_snapped = false
      point, was_point_snapped = point_snapped( point, excluded ) if $manager.point_snap
      point = grid_snapped point unless was_point_snapped or guide or not $manager.grid_snap
      return point, was_point_snapped
    else
      return nil
    end
  end
  
  # snap to surrounding points
  def point_snapped( point, excluded=[] )
    closest = nil
    unless @sketch.segments.empty?
      closest_dist = 999999
      @sketch.segments.each do |seg|
        seg.snap_points.each do |pos|
          unless excluded.include? pos
            dist = @glview.world2screen(sketch2world(point)).distance_to @glview.world2screen(sketch2world(pos))
            if dist < $preferences[:snap_dist]
              if dist < closest_dist
                closest = pos
                closest_dist = dist
              end
            end
          end
        end
      end
    end
    if closest
      return closest, true
    else
      return point, false
    end
  end
  
  def grid_snapped p
    if $manager.grid_snap
      spacing = @sketch.plane.spacing
      div, mod = p.x.divmod spacing
      new_x = div * spacing
      new_x += spacing if mod > spacing / 2
      div, mod = p.y.divmod spacing
      new_y = div * spacing
      new_y += spacing if mod > spacing / 2
      div, mod = p.z.divmod spacing
      new_z = div * spacing
      new_z += spacing if mod > spacing / 2
      new_point = Vector[new_x, new_y, new_z]
      return new_point
    else
      return p
    end
  end
    
  def mouse_move( x,y, excluded=[] )
    super( x,y )
    if @does_snap
      point = @glview.screen2world( x, y )
      if point and $manager.use_sketch_guides
        point = world2sketch point
        # determine point(s) to draw guide through
        x_candidate = nil
        z_candidate = nil
        (@last_reference_points - excluded).each do |p|
          # construct a point with our height, but exactly above or below reference point (z axis)
          snap_point = Vector[p.x, point.y, point.z]
          # measure out distance to that in screen coords
          screen_dist = @glview.world2screen(sketch2world(snap_point)).distance_to @glview.world2screen(sketch2world(point))
          if screen_dist < $preferences[:snap_dist]
            x_candidate ||= [p, screen_dist]
            x_candidate = [p, screen_dist] if screen_dist < x_candidate.last
          end
          # now for y direction (x axis)
          snap_point = Vector[point.x, point.y, p.z]
          screen_dist = @glview.world2screen(sketch2world(snap_point)).distance_to @glview.world2screen(sketch2world(point))
          if screen_dist < 6
            z_candidate ||= [p, screen_dist]
            z_candidate = [p, screen_dist] if screen_dist < z_candidate.last
          end
        end
        # snap cursor point to guide(s)
        # point on axis schould be calculated from workplane instead of world coordinates
        cursor_point = if x_candidate and z_candidate
                         Vector[x_candidate.first.x, point.y, z_candidate.first.z]
                       elsif x_candidate
                         Vector[x_candidate.first.x, point.y, point.z] 
                       elsif z_candidate
                         Vector[point.x, point.y, z_candidate.first.z]
                       else
                         point
                       end
        @x_guide = z_candidate ? [z_candidate.first, cursor_point] : nil 
        @z_guide = x_candidate ? [x_candidate.first, cursor_point] : nil
        # if we are near a snap point, use it as reference in the next run
        point, was_snapped = point_snapped( point, excluded )
        @last_reference_points.push point if was_snapped
        @last_reference_points.uniq!
        @last_reference_points.shift if @last_reference_points.size > $preferences[:max_reference_points]
      end
    end
  end
  
  def click_left( x,y )
    super
    @sketch.plane.resize2fit @sketch.segments.map{|s| s.snap_points }.flatten
  end
  
  def click_right( x,y, time )
    super
    menu = SketchToolMenu.new self
    menu.popup(nil, nil, 3,  time)
  end
  
  def draw
    super
    GL.Disable(GL::DEPTH_TEST)
    # draw guides as stippeled lines
    if $manager.use_sketch_guides
      [@x_guide, @z_guide].compact.each do |guide|
        first = sketch2part(guide.first)
        last = sketch2part( guide.last )
        GL.Enable GL::LINE_STIPPLE
        GL.LineWidth(2)
        GL.Enable GL::LINE_STIPPLE
        GL.LineStipple(5, 0x1C47)
        GL.Color3f(0.5,0.5,1)
        GL.Begin( GL::LINES )
          GL.Vertex( first.x, first.y, first.z )
          GL.Vertex( last.x, last.y, last.z )
        GL.End
        GL.Disable GL::LINE_STIPPLE
      end
    end
    # draw dot at snap location
    if $manager.point_snap and @draw_dot
      dot = sketch2part @draw_dot
      GL.Color3f(1,0.3,0.1)
      GL.PointSize(8.0)
      GL.Begin( GL::POINTS )
        GL.Vertex( dot.x, dot.y, dot.z )
      GL.End
    end
    # draw additional temporary geometry
    for seg in @temp_segments
      GL.LineWidth(2)
      GL.Color3f(1,1,1)
      for v in seg.dynamic_points
        v.take_coords_from sketch2part( v )
      end
      seg.draw
      for v in seg.dynamic_points
        v.take_coords_from part2sketch( v )
      end
    end
    GL.Enable(GL::DEPTH_TEST)
  end
  
  def part2sketch v
    @sketch.plane.plane.part2plane v
  end
  
  def sketch2part v
    @sketch.plane.plane.plane2part v
  end
  
  def sketch2world v
    $manager.work_component.part2world sketch2part v
  end
  
  def world2sketch v
    part2sketch $manager.work_component.world2part v
  end
  
  def exit
    super
    @sketch.build_displaylist
  end
end


class LineTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to create a point, middle click to move points:"), sketch )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
    @first_line = true
  end
  
  # add temporary line to sketch and add a new one
  def click_left( x,y )
    super
    if @temp_line
      unless @temp_line.pos1 == @temp_line.pos2
        snap_p, snapped = point_snapped( world2sketch( @glview.screen2world(x,y)))
        @sketch.constraints << CoincidentConstraint.new( @sketch, @temp_line.pos2, snap_p ) if snapped
        @sketch.constraints << CoincidentConstraint.new( @sketch, @temp_line.pos1, @sketch.segments.last.pos2 ) unless @first_line
        @sketch.constraints << CoincidentConstraint.new( @sketch, @temp_line.pos1, @last_point ) if @last_point_was_snapped and @first_line
        @sketch.segments << @temp_line
        if $manager.use_auto_constrain
          if @temp_line.pos1.x == @temp_line.pos2.x
            @sketch.constraints << VerticalConstraint.new( @sketch, @temp_line )
            puts "vertical"
          elsif @temp_line.pos1.z == @temp_line.pos2.z
            puts "horizontal"
            @sketch.constraints << HorizontalConstraint.new( @sketch, @temp_line )
          end
        end
        @first_line = false
        @sketch.constraints.each{|c| c.visible = true }
        @sketch.build_displaylist
      end
    end
    @last_point, @last_point_was_snapped = snapped( x,y )
    @last_reference_points.push @last_point
    $manager.cancel_current_tool if @last_point == @first_point
    @first_point ||= @last_point
  end
  
  # update temp line
  def mouse_move( x,y )
    super
    new_point, was_snapped = snapped( x,y )
    @draw_dot = was_snapped ? new_point : nil
    if new_point and @last_point
      @temp_line = Line.new( @last_point, new_point, @sketch)
      @temp_segments = [@temp_line]
    end
    @glview.redraw
  end
  
  def pause
    super
    @glview.window.cursor = nil
  end
  
  def resume
    super
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
  end
end


class ArcTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to select center:"), sketch )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
    @step = 1
    @uses_toolbar = true
  end

  def click_left( x,y )
    point, was_snapped = snapped( x,y )
    if point
      case @step
      when 1
        @center = point
        $manager.set_status_text GetText._("Click left to select first point on arc:")
      when 2
        @radius = @center.distance_to point
        @start_angle = 360 - (@sketch.plane.plane.u_vec.angle @center.vector_to point)
        @start_point = point
        $manager.set_status_text GetText._("Click left to select second point on arc:")
      when 3
        #end_angle = 360 - @sketch.plane.plane.u_vec.angle( @center.vector_to( point ) )
        end_angle = @sketch.plane.plane.u_vec.angle @center.vector_to point
        end_angle = 360 - end_angle 
        end_angle = 360 - end_angle if point.z > @center.z
        @sketch.segments.push Arc2D.new( @center, @radius, @start_angle, end_angle, @sketch )
        @sketch.build_displaylist
        $manager.cancel_current_tool
      end
      @step += 1
    end
    super
  end

  def mouse_move( x,y )
    super
    point, was_snapped = snapped( x,y )
    @draw_dot = was_snapped ? point : nil
    if point
      case @step
      when 2
        @temp_segments = [ Line.new( @center, point, @sketch ) ]
      when 3
        end_angle =@sketch.plane.plane.u_vec.angle @center.vector_to point
        end_angle = 360 - end_angle 
        end_angle = 360 - end_angle if point.z > @center.z
        arc = Arc2D.new( @center, @radius, @start_angle, end_angle )
        @temp_segments = [ Line.new( @center, arc.pos1 ), arc, Line.new( @center, arc.pos2 ) ]
      end
    end
    @glview.redraw
  end
end


class CircleTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to select center:"), sketch )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
    @step = 1
  end
  
  def click_left( x,y )
    point, was_snapped = snapped( x,y )
    if point
      case @step
      when 1
        @center = point
        $manager.set_status_text GetText._("Click left to select a point on the circle:")
      when 2
        radius = @center.distance_to point
        @sketch.segments.push Circle2D.new( @center, radius, @sketch )
        @sketch.build_displaylist
        $manager.cancel_current_tool
      end
      @step += 1
    end
    super
  end

  def mouse_move( x,y )
    super
    point, was_snapped = snapped( x,y )
    @draw_dot = was_snapped ? point : nil
    if point
      if @step == 2
        radius = @center.distance_to point
        circle = Circle2D.new( @center, radius )
        @temp_segments = [ Line.new(@center, point), circle ]
      end
    end
    @glview.redraw
  end
end


class TwoPointCircleTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to select first point on circle:"), sketch )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
    @step = 1
  end
  
  def click_left( x,y )
    point, was_snapped = snapped( x,y )
    if point
      case @step
      when 1
        @p1 = point
        $manager.set_status_text GetText._("Click left to select second point on circle:")
      when 2
        @sketch.segments.push Circle2D::from_opposite_points( @p1, point, @sketch )
        @sketch.build_displaylist
        $manager.cancel_current_tool
      end
      @step += 1
    end
    super
  end

  def mouse_move( x,y )
    super
    point, was_snapped = snapped( x,y )
    @draw_dot = was_snapped ? point : nil
    if point and @step == 2
      @temp_segments = [ Circle2D::from_opposite_points( @p1, point, @sketch.plane.plane.dup ) ]
    end
    @glview.redraw
  end
end


class DimensionTool < SketchTool
  def initialize sketch
    super( GetText._("Choose a segment or two points to add a dimension:"), sketch )
    @points = []
    @selected_segments = []
    @does_snap = false
  end
  
  def click_left( x,y )
    if dim = dimension_for( @selected_segments, x,y )
      dim.visible = true
      @sketch.constraints << dim
      $manager.cancel_current_tool
      @glview.redraw
      FloatingEntry.new( x,y, dim.value ) do |value, code| 
        dim.value = value
        @sketch.build_displaylist
        @glview.redraw
      end
    else
      # use point instead of segment if we find one near
      p, was_snapped = point_snapped( world2sketch(@glview.screen2world(x,y)) )
      #if not points.empty?
      if was_snapped
        #p = points.first
        @selected_segments << p
        $manager.set_status_text( GetText._("Choose a point to position your dimension:") ) if @selected_segments.size == 2
      else
        # don't use segment if we have one point already
        unless @selected_segments.is_a? Array and @selected_segments.size == 1
          if seg = @glview.select(x,y)
            @selected_segments = seg
            $manager.set_status_text( GetText._("Choose a point to position your dimension:") )
          end
        end
      end
    end
    super
  end
  
  def dimension_for( seg_or_points, x,y, temp=false )
    if pos = @glview.screen2world( x,y )
      pos = world2sketch pos
      if seg_or_points.is_a? Arc2D
        RadialDimension.new( seg_or_points, pos, @sketch, temp )
      elsif seg_or_points.is_a? Line
        width  = (seg_or_points.pos1.x - seg_or_points.pos2.x).abs
        height = (seg_or_points.pos1.z - seg_or_points.pos2.z).abs
        midp = seg_or_points.midpoint
        x_dist = (pos.x - midp.x).abs
        z_dist = (pos.z - midp.z).abs
        if (x_dist - z_dist).abs / (x_dist + z_dist) < 0.35
          LengthDimension.new( seg_or_points.pos1, seg_or_points.pos2, pos, @sketch, temp )
        else
          if z_dist > x_dist
            HorizontalDimension.new( seg_or_points, pos, @sketch, temp )
          else
            VerticalDimension.new( seg_or_points, pos, @sketch, temp )
          end
        end
      elsif seg_or_points.is_a? Array and seg_or_points.size == 2
        #XXX create linear dimension
      end
    else
      nil
    end
  end
  
  def mouse_move( x,y )
    super
    p = @glview.screen2world(x,y)
    p, snapped = point_snapped( world2sketch(p) ) if p
    @draw_dot = snapped ? p : nil
    @temp_dim = dimension_for( @selected_segments, x,y, true )
    @glview.redraw
  end
  
  def draw
    super
    @temp_dim.draw if @temp_dim
  end
end


class ConstrainTool < SketchTool
  def initialize sketch
    super( GetText._("Choose one or more segments to constrain:"), sketch )
    @selected_segments = []
    @does_snap = true
    @no_depth = true
  end
  
  def click_left( x,y )
    @chooser.destroy if @chooser and not @chooser.destroyed?
    # use point instead of segment if we find one near
    p, was_snapped = point_snapped( world2sketch(@glview.screen2world(x,y)) )
    hit_something = false
    if was_snapped
      @selected_segments << p
      hit_something = true
    else
      seg = @glview.select(x,y)
      if seg
        @selected_segments << seg
        hit_something = true
      end
    end
    @selected_segments = [] unless hit_something
    @selected_segments.shift if @selected_segments.size == 3
    unless @selected_segments.empty?
      @chooser = SketchConstraintChooser.new( x,y, @selected_segments ) do |type| 
        c = case type
        when :horizontal
          HorizontalConstraint.new( @sketch, *@selected_segments )
        when :vertical
          VerticalConstraint.new( @sketch, *@selected_segments )
        when :equal
          EqualLengthConstraint.new( @sketch, *@selected_segments )
        end
        c.visible = true
        @sketch.constraints << c
        @sketch.update_constraints [@selected_segments.first.is_a?(Vector) ? 
                                    @selected_segments.first : @selected_segments.first.pos1]
        @sketch.build_displaylist
        @selected_segments = []
        @chooser.destroy
        @glview.redraw
      end
    end 
    super
  end
  
  def mouse_move( x,y )
    p = @glview.screen2world( x,y )
    p, snapped = point_snapped(world2sketch p) if p
    if snapped
      @draw_dot = p
      @temp_segments = @selected_segments
    else
      @draw_dot = nil
      @temp_segments = [@glview.select(x,y)].compact + @selected_segments
    end
    @glview.redraw
  end
  
  def exit
    super
    @chooser.destroy if @chooser and not @chooser.destroyed?
  end
end


class SplineTool < SketchTool
  def initialize sketch
    super( GetText._("Spline   L: add point   M: move points"), sketch )
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
    @points = []
  end
  
  def click_left( x,y )
    super
    snap_p, snapped = point_snapped( world2sketch( @glview.screen2world(x,y) ) )
    @points << snap_p
    @last_reference_points.push snap_p
  end
  
  def mouse_move( x,y )
    super
    new_point, was_snapped = snapped( x,y )
    @draw_dot = was_snapped ? new_point : nil
    @temp_segments = [Spline.new( @points + [new_point], 3, @sketch )] if new_point
    @glview.redraw
  end
  
  def pause
    super
    @glview.window.cursor = nil
  end
  
  def resume
    super
    @glview.window.cursor = Gdk::Cursor.new Gdk::Cursor::PENCIL if @glview.window
  end
  
  def exit
    @sketch.segments << Spline.new( @points, 3, @sketch ) unless @points.size < 2
    @sketch.build_displaylist
    super
  end
end
  

class EditSketchTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to select points, drag to move points, right click for options:"), sketch )
    @does_snap = false
    @points_to_drag = []
    @no_depth = true
  end
  
  def click_left( x,y )
    unless @draw_dot
      sel = @glview.select( x,y )
      case sel
      when Segment
        if $manager.key_pressed? :Shift
          $manager.selection.switch sel
          @selection = $manager.selection.all
        else
          $manager.selection.select sel
          @selection = [sel]
        end
      when Dimension
        FloatingEntry.new( x,y, sel.value ) do |value, code| 
          sel.value = value
          @sketch.build_displaylist
          @glview.redraw
        end
      else
        $manager.selection.deselect_all unless $manager.key_pressed? :Shift
        @selection = nil
      end
      @sketch.build_displaylist
      @glview.redraw
    end
    super
  end
  
  def press_left( x,y )
    super
    @does_snap = true
    pos = @glview.screen2world( x,y )
    new_selection = @glview.select( x,y )
    if pos and not new_selection.is_a? Dimension
      pos = world2sketch(pos)
      @drag_start = @draw_dot ? @draw_dot.dup : pos
      @old_draw_dot = Marshal.load(Marshal.dump(@draw_dot))
      # if drag starts on an already selected segment
      if @selection and @selection.include? new_selection    
        @points_to_drag = @selection.map{|e| e.dynamic_points }.flatten.uniq
        @old_points = Marshal.load(Marshal.dump( @points_to_drag ))
      elsif not $manager.key_pressed? :Shift
        if new_selection and not @draw_dot
          click_left( x,y )
          press_left( x,y )
        else
          click_left( x,y )
        end
      end
    end
  end
  
  def drag_left( x,y )
    super
    mouse_move( x,y, true, [@draw_dot] )
    pos, dummy = snapped( x,y, [@draw_dot] )
    if pos and @drag_start
      move = @drag_start.vector_to pos
      if @draw_dot
        @draw_dot.x = @old_draw_dot.x + move.x
        @draw_dot.y = @old_draw_dot.y + move.y
        @draw_dot.z = @old_draw_dot.z + move.z
        3.times{ @sketch.update_constraints [@draw_dot] }
      elsif @selection
        @points_to_drag.zip( @old_points ).each do |neu, original|
          neu.x = original.x + move.x
          neu.y = original.y + move.y
          neu.z = original.z + move.z
        end
        3.times{ @sketch.update_constraints @points_to_drag } #XXX once should be enough
        #@points_to_drag.each{|p| @sketch.update_constraints [p] }
      end
      @sketch.build_displaylist
      @glview.redraw
    end
  end
  
  def release_left
    super
    @does_snap = false
    @sketch.build_displaylist
    @glview.redraw
  end
  
  def mouse_move( x,y, only_super=false, excluded=[] )
    super( x,y, excluded )
    unless only_super
      #points = @sketch.segments.map{|s| [s.pos1, s.pos2] }.flatten
      points = @sketch.segments.map{|s| s.dynamic_points }.flatten
      @draw_dot = points.select{|point|
        dist = Point.new(x, @glview.allocation.height - y).distance_to @glview.world2screen(sketch2world(point))
        dist < $preferences[:snap_dist]
      }.first #XXX use point_snapped instead
      @glview.redraw
    end
  end
  
  def click_middle( x,y )
    super
    sel = @glview.select( x,y )
    if sel
      @selection = sel.sketch.chain( sel )
      if @selection
        $manager.selection.select *@selection
        sel.sketch.build_displaylist
        @glview.redraw
      end
    else
      $manager.selection.deselect_all
    end
  end
  
  def click_right( x,y, time )
    new_selection = @glview.select( x,y )
    click_left( x,y ) unless @selection and @selection.include? new_selection
    @glview.redraw
    menu = SketchSelectionToolMenu.new
    menu.popup(nil, nil, 3,  time)
  end
  
  def double_click( x,y )
    $manager.working_level_up if $manager.selection.empty?
  end
end


class TrimTool < SketchTool
  def initialize sketch
    super( GetText._("Click left to delete subsegments of your sketch:"), sketch )
    @does_snap = false
    @no_depth = true
  end
  
  def mouse_move( x,y )
    super
    if sel = @glview.select( x,y )
      # generate intersection points with all other segs in the sketch
      @intersections = []
      for s in @sketch.segments - [sel]
        @intersections += sel.intersections_with(s)
      end
      unless @intersections.empty?
        cut_segments = sel.cut_at @intersections
        # check which sub-segment to cut away
        click_point = world2sketch( @glview.screen2world(x,y) )
        @cut_seg = cut_segments.min_by{|s| s.midpoint.distance_to click_point }
        # create the remaining parts of the segment
        remains = sel.cut_at [@cut_seg.pos1, @cut_seg.pos2]
        remains.reject!{|s| s.midpoint == @cut_seg.midpoint }
        @replacement = [sel, remains]
        @temp_segments = [@cut_seg, @intersections].flatten
        @glview.redraw
        return
      end
    end
    @cut_seg, @replacement = nil, nil
    @temp_segments = []
    @glview.redraw
  end
  
  def click_left( x,y )
    super
    mouse_move( x,y )
    return unless @replacement
    @sketch.segments.delete @replacement.first
    @sketch.segments += @replacement.last
    #XXX correct constraints
    @glview.rebuild_selection_pass_colors [:segments]
    @sketch.build_displaylist
    @cut_seg, @replacement = nil, nil
    @glview.redraw
  end
end





