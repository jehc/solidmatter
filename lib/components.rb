#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'quaternion.rb'
require 'sketch.rb'
require 'units.rb'
require 'ui/material_editor.rb'
require 'ui/part_dialog.rb'
require 'ui/assembly_dialog.rb'
require 'ui/progress_dialog.rb'


class Array
  def each_combination
    size.times do |i|
      size.times do |j|
        yield self[i], self[j] if i <= j
      end
    end
  end
end


class Face
  include Selectable
  include ChainCompletion
  attr_accessor :segments, :solid, :created_by_op, :created_by_segment
  def initialize op=nil
    @created_by_op = op
    @segments = []
    @selection_pass_color = [1.0, 1.0, 1.0]
    @solid = nil
  end
  
  def draw
    raise "#{self.class} cannot draw itself"
  end
  
  def area
    0.0
  end
  
  def tesselate
    []
  end
  
  def intersections_with other
    raise "#{self.class} does not implement intersections"
  end
  
  def cut_at curve
    raise "#{self.class} does not implement trimming"
  end
  
  def dup
    copy = super
    copy.segments = segments.map{|s| s.dup }
    return copy
  end
end

class PlanarFace < Face
  attr_accessor :plane
  attr_reader :polygon
  def initialize
    super()
    @plane = Plane.new
  end
  
  def pretesselate
    ch = loop( @segments.first )
    if ch
      @polygon = Polygon.from_loop( ch ).to_cw!
    else
      raise "Trying to build face #{self} from non-closed segment loop"
    end
  end
  
  def draw
    pretesselate unless @polygon
    normal = @plane.normal_vector#.invert
    GL.Normal( normal.x, normal.y, normal.z )
    tess = GLU::NewTess()
    GLU::TessCallback( tess, GLU::TESS_VERTEX, lambda{|v| GL::Vertex v if v} )
    GLU::TessCallback( tess, GLU::TESS_BEGIN, lambda{|which| GL::Begin which } )
    GLU::TessCallback( tess, GLU::TESS_END, lambda{ GL::End() } )
    GLU::TessCallback( tess, GLU::TESS_ERROR, lambda{|errCode| raise "Tessellation Error: #{GLU::ErrorString errCode}" } )
    GLU::TessCallback( tess, GLU::TESS_COMBINE, 
    lambda do |coords, vertex_data, weight|
      vertex = [coords[0], coords[1], coords[2]]
      vertex
    end )
    GLU::TessProperty( tess, GLU::TESS_WINDING_RULE, GLU::TESS_WINDING_POSITIVE )
    GLU::TessBeginPolygon( tess, nil )
      GLU::TessBeginContour tess
        for point in @polygon.points
          GLU::TessVertex( tess, point.elements, point.elements )
        end
      GLU::TessEndContour tess
    GLU::TessEndPolygon tess
    GLU::DeleteTess tess
    # draw normal
    # center = @polygon.points.inject{|sum, p| sum + p } / @polygon.points.size
    # ntip = center + normal * 0.05
    # GL.Begin( GL::LINES )
    #   GL.Vertex( center.x, center.y, center.z )
    #   GL.Vertex( ntip.x, ntip.y, ntip.z )
    # GL.End
  end
  
  def tesselate
    @polygon or pretesselate
    @polygon.tesselate
  end
  
  def intersections_with other
    case other
    when PlanarFace
      # generate arbitrary point on planes
      p = InfiniteLine.new( Vector[0,0,0], @plane.u_vec ).intersect_with(other.plane) || InfiniteLine.new( Vector[0,0,0], @plane.v_vec ).intersect_with(other.plane)
      # calculate intersection between infinite planes
      infinite_intersection = InfiniteLine.new( p, @plane.normal.cross_product(other.plane.normal) )
      # intersect with boundary segments to find finite intersection line
      Line.new( *@segments.map{|s| infinite_intersection.intersect_with s }.compact )
    else
      []
    end
  end
  
  def cut_at line
    # cut all intersecting segments 
    segments = @segments.dup
    new_pairs = []
    segments.each_with_index do |s, i|
      for p in [line.pos1, line.pos2]
        if s.touches?(p, true)
          segments[i] = s.cut_at_point p
          new_pairs << segments[i]
        end
      end
    end
    segments.flatten!
    # rebuild loops for new faces
    loop, closed = loop( new_pairs.first.first, segments )
    chain = []
    i_start = ((loop[1] == new_pairs.first.last) ? 1 : 0)
    for i in i_start...loop.size
      chain << loop[i]
      break if new_pairs.include? loop[i]
    end
    other_chain = segments - chain
    chain << line.dup
    other_chain << line.dup
    f1, f2 = dup, dup
    f1.segments = chain
    f2.segments = other_chain
    [f1, f2]
  end
  
  def area
    @polygon or pretesselate
    @polygon.area
  end
end

class CircularFace < Face
  attr_accessor :plane, :radius
  def initialize( plane, radius, height, start_angle, end_angle )
    super()
    @plane       = plane.dup
    @radius      = radius
    @height      = height
    @start_angle = start_angle
    @end_angle   = end_angle
    # build outlines
    lower_arc = Arc3D.new( @plane, @radius, start_angle, end_angle )
    puts lower_arc.center
    upper_arc = lower_arc.dup
    upper_arc.center = @plane.origin + @plane.normal * @height
    borders = [ Line.new( lower_arc.pos1, upper_arc.pos1), Line.new( lower_arc.pos2, upper_arc.pos2) ]
    @segments =  [lower_arc, upper_arc] + borders
  end
  
  def draw
    arc = Arc3D.new( @plane, @radius, @start_angle, @end_angle )
    for line in arc.tesselate
      corner1 = line.pos1
      corner2 = line.pos1 + @plane.normal * @height
      corner3 = line.pos2 + @plane.normal * @height
      corner4 = line.pos2
      GL.Begin( GL::POLYGON )
        normal = @plane.origin.vector_to( line.pos1 ).normalize
        GL.Normal( normal.x, normal.y, normal.z )
        GL.Vertex( corner1.x, corner1.y, corner1.z )
        GL.Vertex( corner2.x, corner2.y, corner2.z )
        normal = @plane.origin.vector_to( line.pos2 ).normalize
        GL.Normal( normal.x, normal.y, normal.z )
        GL.Vertex( corner3.x, corner3.y, corner3.z )
        GL.Vertex( corner4.x, corner4.y, corner4.z )
      GL.End
    end
  end
  
  def tesselate
    tris = []
    arc = Arc3D.new( @plane, @radius, @start_angle, @end_angle )
    for line in arc.tesselate
      corner1 = line.pos1
      corner2 = line.pos1 + @plane.normal * @height
      corner3 = line.pos2 + @plane.normal * @height
      corner4 = line.pos2
      tri1 = [corner1, corner2, corner3]
      tri2 = [corner3, corner4, corner1]
      tris << tri1 << tri2
    end
    return tris
  end
end

class FreeformFace < Face
  def initialize
    
  end
end


class Solid
  attr_accessor :faces
  def initialize
    @faces = []
  end
  
  def add_face f
    f.solid = self
    @faces.push f
  end
  
  def surface_area
   @faces.inject(0){|sum,f| sum + f.area }
  end
  alias area surface_area
  
  def volume_and_cog
    GC.enable
    bbox = bounding_box
    if bbox
      left  = bbox.map{|v| v.x }.min
      right = bbox.map{|v| v.x }.max
      upper = bbox.map{|v| v.y }.max
      lower = bbox.map{|v| v.y }.min
      front = bbox.map{|v| v.z }.max
      back  = bbox.map{|v| v.z }.min
      divisions = 5
      max_change = 0.00001
      # divide bounding volume into subvolumes
      x_span = (right - left)  / divisions
      y_span = (upper - lower) / divisions
      z_span = (front - back)  / divisions
      box_volume = x_span * y_span * z_span
      max_change_per_box = max_change * divisions / box_volume
      subvolumes = []
      cog = Vector[0,0,0]
      cancel = false
      progress = ProgressDialog.new( GetText._("<b>Calculating solid volume...</b>") ){ cancel = true }
      progress.fraction = 0.0
      subvolumes_finished = 0
      increment = 1.0 / divisions**3
      @faces.select{|f| f.is_a? PlanarFace }.each{|f| f.pretesselate }
      for ix in 0...divisions
        box_left = left + (ix * x_span)
        for iy in 0...divisions
          box_lower = lower + (iy * y_span)
          for iz in 0...divisions
            box_back = back + (iz * z_span)
            break if cancel
            # shoot samples into each subvolume until it converges
            #subvolumes << GtkThread.start(box_left, box_lower, box_back) do |le,lo,ba|
              le,lo,ba = box_left, box_lower, box_back
              shots_fired = 0.0
              hits = 0.0
              change = 1.0
              old_share = 1.0
              begin
                sx = le + (rand * x_span)
                sy = lo + (rand * y_span)
                sz = ba + (rand * z_span)
                hits += 1 if self.contains? Vector[sx,sy,sz]
                shots_fired += 1
                if shots_fired % 15 == 0
                  share = hits / shots_fired
                  change = (share - old_share).abs
                  old_share = share
                  #progress.fraction = progress.fraction
                end
              end while change > max_change_per_box
              # calculate volume for this box
              vol = box_volume * (hits / shots_fired)
              cog += Vector[box_left + x_span/2.0, box_lower + y_span/2.0, box_back + z_span/2.0] * vol
              subvolumes << vol
              # update progressbar
              Gtk.queue do
                progress.fraction += increment
                progress.text = GetText._("sampling bucket") + " #{subvolumes_finished}/#{divisions**3}" 
                subvolumes_finished += 1
              end
           # end
          end
        end
      end
      volume = subvolumes.inject(0){|total,v| total + v } #.value }
      cog /= volume
      Gtk::main_iteration while Gtk::events_pending?
      progress.close
      cancel ? nil : [volume, cog]
    else
      [0.0, Vector[0,0,0]]
    end
  end
  
  def contains? p
    l = InfiniteLine.new( p, Vector[0,1,0] )
    intersections = 0
    for f in @faces.select{|f| f.is_a? PlanarFace } #XXX should work for all faces
      sect = l.intersect_with f.plane
      # only consider the ray going in one direction
      if sect and sect.y > p.y
        # check if within bounds of face
        sect = f.plane.part2plane sect
        #sect = Point.new( sect.x, sect.z )
        intersections += 1 if f.polygon.contains? sect
      end
    end
    intersections % 2 != 0
  end
  
  def bounding_box
    points = @faces.map{|f| f.segments.map{|seg| seg.snap_points } }.flatten
    return bounding_box_from points
  end
  
  def tesselate heal=false
    tris = @faces.inject([]){|triangles,f| triangles + f.tesselate }
    if heal
      vertices = tris.flatten
      vertices.each{|p1| vertices.each{|p2| p1.take_coords_from p2 if p1.near_to p2 } }
    end
    # make sure we have no redundant points and triangles are properly connected
    tris.each_combination do |tri1, tri2|
      3.times do |pi1|
        3.times do |pi2|
          if tri1[pi1] == tri2[pi2]
            tri2[pi2] = tri1[pi1]
          end
        end
      end
    end
    tris
  end
  
  def boolean_union
    
  end
  alias + boolean_union
  
  def boolean_subtraction
    
  end
  alias - boolean_subtraction
  
  def boolean_difference
    
  end
  alias & boolean_difference
  
  def intersections_with other
    cut_faces = []
    for f1 in @faces
      for f2 in other.faces
        curve = f1.intersection_with f2
        cut_faces += f1.cut_with curve
        cut_faces += f2.cut_with curve
      end
    end
    cut_faces
  end
  
  def dup
    copy = super
    copy.faces = faces.dup#map{|f| f.dup }
    return copy
  end
end


# abstract base class for operators
class Operator
  include Units
  attr_reader :settings, :solid, :part, :dimensions
  attr_accessor :name, :enabled, :previous
  def initialize part
    @name ||= "operator"
    @settings ||= {:loops => []}
    @save_settings = @settings.dup
    @solid = nil
    @part = part
    @dimensions = []
    @enabled = true
    @previous = nil
    #create_toolbar
  end
  
  def operate
    if @previous
      @solid = @previous.solid ? @previous.solid.dup : nil
      segs = @settings[:loops].flatten if @settings[:loops]
      if segs
        sketches = segs.map{|seg| seg.sketch }.compact.uniq
        sketches.each{|sk| sk.refetch_plane_from_solid @previous.solid }
      end
    else
      @solid = Solid.new
    end
    if @enabled
      new_faces = real_operate 
      new_faces.each{|f| f.created_by_op = self }
    end
  end
  
  def real_operate
    raise "Error in #{self} : Operator#real_operate must be overriden by child class and report all newly created faces"
  end
  
  def show_toolbar
    @save_settings = @settings.dup
    toolbar = Gtk::Toolbar.new
    toolbar.toolbar_style = Gtk::Toolbar::BOTH
    toolbar.icon_size = Gtk::IconSize::SMALL_TOOLBAR
    fill_toolbar toolbar
    toolbar.append( Gtk::SeparatorToolItem.new){}
    toolbar.append( Gtk::Stock::CANCEL, GetText._("Exit operator without saving changes"),"Operator/Cancel"){ cancel }
    toolbar.append( Gtk::Stock::OK, GetText._("Save changes and exit operator"),"Operator/Ok"){ ok }
    return toolbar
  end

  def draw_gl_interface

  end
  
  def ok
    @part.build( self )
    $manager.working_level_up
    $manager.glview.redraw
  end
  
  def cancel
    @settings = @save_settings
    ok
  end

  def show_changes
    @part.build self
    $manager.glview.redraw 
  end
  
private
  def fill_toolbar 
    raise "Error in #{self} : Operator#fill_toolbar must be overriden by child class"
  end
end


class Component
  @@used_ids = []
  attr_reader :information, :component_id
  attr_accessor :thumbnail
  
  def self.new_id
    id = rand 99999999999999999999999999999999999999999 while @@used_ids.include? id
    @@used_ids.push id
    id
  end
  
  def initialize
    @component_id = Component.new_id
    @thumbnail = nil
  end

  def draw_cog
    if @cog
      qobj = GLU.NewQuadric
      GLU.QuadricDrawStyle(qobj, GLU::FILL)
      GLU.QuadricNormals(qobj, GLU::SMOOTH)
      GL.Enable(GL::LIGHTING)
      GL.PushMatrix
        GL.Translate(@cog.x, @cog.y, @cog.z)
        GLU.Sphere(qobj, 0.015, 12, 12)
      GL.PopMatrix
      $manager.glview.draw_coordinate_axes @cog
    end
  end
  
  def dup
    copy = super
    copy.component_id = new_id
    copy
  end
  
  def name
    information[:name]
  end
end

class Part < Component
  attr_accessor :displaylist, :wire_displaylist, :selection_displaylist, :wire_selection_displaylist, :history_limit, :solid, :information, :cog
  attr_reader :operators, :working_planes, :unused_sketches, :solid
  def initialize name
    super()
    @unused_sketches = []
    @working_planes = [ WorkingPlane.new(self) ]
    @operators = []
    @history_limit = 0
    @information = {:name     => name,
                    :author   => "",
                    :approved => "",
                    :version  => "0.1",
                    :material => $manager.project.materials.first}
    @displaylist = $manager.glview.add_displaylist
    @wire_displaylist = $manager.glview.add_displaylist
    @selection_displaylist = $manager.glview.add_displaylist
    @wire_selection_displaylist = $manager.glview.add_displaylist
    @solid = Solid.new
  end

  def add_operator( op, index=@history_limit )
    @operators.insert( index, op )
    op.previous = @operators[index-1] unless index == 0
    @operators[index+1].previous = op if @operators[index+1]
    @history_limit += 1 if index <= @history_limit
  end
  
  def move_operator_up op
    i = @operators.index op
    unless i == 0 
      remove_operator op
      add_operator( op, i-1 )
    end
  end
  
  def move_operator_down op
    i = @operators.index op
    unless i == @operators.size - 1
      remove_operator op
      add_operator( op, i+1 )
    end
  end

  def remove_operator( op )
    i = @operators.index op
    @operators.delete_at i 
    @operators[i].previous = (i >= 1 ? @operators[i-1] : nil) if @operators[i]
    @history_limit -= 1 if i < @history_limit
    if @operators[i]
      build @operators[i] 
    else
      @solid = @operators.empty? ? Solid.new : @operators.last.solid
      build_displaylist
    end
  end

  def build( from_op=@operators.first )
    if @history_limit >= 1
      raise "Operator must come before history limit" unless @operators.index(from_op) < @history_limit
      @operators.index( from_op ).upto( @history_limit - 1 ) do |i|
        op = @operators[i]
        yield op if block_given?  # update progressbar
        op.operate
      end
      solid = @operators[@history_limit - 1].solid
    else
      solid = Solid.new
    end
    if solid
      @solid = solid
      build_displaylist
      $manager.glview.rebuild_selection_pass_colors
      $manager.component_changed self
      self.all_sketches.each{|sk| sk.refetch_plane_from_solid }
      $manager.has_been_changed = true
    else
      dia = Gtk::MessageDialog.new( nil, Gtk::Dialog::DESTROY_WITH_PARENT,
                                         Gtk::MessageDialog::WARNING,
                                         Gtk::MessageDialog::BUTTONS_OK,
                                         GetText._("Part could not be built"))
      dia.secondary_text = GetText._("Please recheck all operator settings and close any open sketch regions!")
      dia.run
      dia.destroy
    end
  end
  
  def bounding_box
    @solid.bounding_box
  end

  def build_displaylist
    # generate mesh and write to displaylist
    GL.NewList( @displaylist, GL::COMPILE )
      # draw shaded faces
      @solid.faces.each{|f| f.draw }
    GL.EndList
    build_wire_displaylist
  end
  
  def build_wire_displaylist
    GL.NewList( @wire_displaylist, GL::COMPILE )
      all_segs = @solid.faces.map{|face| face.segments }.flatten
      GL.Disable(GL::LIGHTING)
      GL.LineWidth( 1.5 )
      all_segs.each{|s| s.draw }
    GL.EndList
  end
  
  def build_selection_displaylist
    GL.NewList( @selection_displaylist, GL::COMPILE )
      @solid.faces.each do |face|
        c = face.selection_pass_color
        GL.Color3f( c[0],c[1],c[2] )
        face.draw
      end
    GL.EndList
  end
  
  def build_wire_selection_displaylist
    GL.NewList( @wire_selection_displaylist, GL::COMPILE )
      all_segs = @solid.faces.map{|face| face.segments }.flatten
      GL.Disable(GL::LIGHTING)
      GL.LineWidth( 12.0 )
      all_segs.each do |s|
        c = s.selection_pass_color
        GL.Color3f( c[0],c[1],c[2] )
        s.draw
      end
    GL.EndList
  end
  
  def display_properties
    dia = PartInformationDialog.new(self) do |info|
      @information = info if info
      $manager.op_view.update
      $manager.glview.redraw
    end
  end
  
  def area
    @solid.area
  end
  
  def volume_and_cog
    @solid.volume_and_cog
  end
  
  def mass from_volume=@solid.volume_and_cog.first
    from_volume * @information[:material].density
  end
  
  def update_cog
    vc = volume_and_cog
    @cog = vc.last if vc
  end
  
  def clean_up
    $manager.glview.delete_displaylist @displaylist
    $manager.glview.delete_displaylist @wire_displaylist
    $manager.glview.delete_displaylist @selection_displaylist
    @displaylist = nil
    @wire_displaylist = nil
    @selection_displaylist = nil
  end
  
  def all_sketches
    (@unused_sketches + @operators.map{|op| op.settings[:sketch] }).compact
  end
  
  def dimensions
    (all_sketches.map{|sk| sk.dimensions } + @operators.map{|op| op.dimensions }).flatten.uniq
  end
  
  def constraints
    all_sketches.map{|sk| sk.constraints }.flatten
  end
  
  def dup
    copy = super
    copy.unused_sketches = @unused_sketches.dup
    copy.working_planes = @working_planes.dup
    copy.operators = @operators.dup
    copy.information = @information.dup
    copy.solid = @solid.dup
    @displaylist = $manager.glview.add_displaylist
    @wire_displaylist = $manager.glview.add_displaylist
    @selection_displaylist = $manager.glview.add_displaylist
  end
end


class Assembly < Component
  attr_accessor :components, :cog
  def initialize name
    super()
    @component_id = component_id() 
    @components = []
    @contact_set = []
    @information = {:name      => name,
                    :author    => "",
                    :approved  => "",
                    :version   => "0.1"}
  end

  def remove_component( comp )
    if comp.is_a? String
      @components.delete_if {|c| c.name == comp }
    elsif comp.is_a? Instance
      @components.delete comp 
    end
  end
  
  def build_displaylist
   @components.each{|c| c.build_displaylist }
  end

  def add_constraint(part1, face1, part2, face2)

  end

  def remove_constraint(part1, face1, part2, face2)

  end

  def update_constraints

  end

  def transparent=( bool )
    @components.each {|c| c.transparent = bool}
  end
  
  def contained_parts
    parts = @components.select{|c| c.class == Part }
    return parts + @components.select{|c| c.class == Assembly }.map{|a| a.contained_parts }.flatten
  end

  def display_properties
    dia = AssemblyInformationDialog.new(self) do |info|
      @information = info if info
      $manager.op_view.update
    end
  end
  
  def area
    @components.inject{|area, c| area + c.area }
  end
  
  def volume_mass_and_cog
    volume = 0
    mass = 0
    cog = Vector[0,0,0]
    @components.each do |c| 
      v,co = c.volume_and_cog
      m = c.mass v
      volume += v
      mass += m
      cog += co * m
    end
    if mass != 0
      cog /= mass
      [volume, mass, cog]
    else
      [0, 0, Vector[0,0,0]]
    end
  end
  
  def update_cog
    @cog = volume_mass_and_cog.last
  end
  
  def bounding_box
    @components.map{|c| c.bounding_box }.flatten.compact
  end
  
  def dimensions
    @components.map{|c| c.dimensions }.flatten
  end
  
  def constraints
    @components.map{|c| c.constraints }.flatten
  end
end


class Instance
  include Selectable
  @@used_ids ||= []
  attr_reader :parent, :transparent, :component_id
  attr_accessor :visible, :real_component, :position, :rotation
  def initialize( component, parent=nil )
    raise "Parts must have a parent" if component.class == Part and not parent
    @real_component = component
    @position = Vector[0,0,0]
    @rotation = Quaternion.new
    @parent = parent
    @transparent = false
    @visible = true
    @selection_pass_color = [1.0, 1.0, 1.0]
    @instance_id = rand 99999999999999999999999999999999999999999 while @@used_ids.include? @instance_id
    @@used_ids.push @instance_id
  end
  
  def dup
    copy = super
    copy.real_component = @real_component
    copy
  end
  
  def class
    @real_component.class
  end
  
  def method_missing( method, *args )
    @real_component.send( method, *args )
  end
  
  def selected= bool
   self.components.each{|c| c.selected = bool } if self.class == Assembly
   @selected = bool
  end
  
  def transparent= bool
    @transparent = bool
    self.components.each{|c| c.transparent = bool} if self.class == Assembly
  end
  
  def ancestors   # including self
    ancestors = [self]
    ancestors << ancestors.last.parent while ancestors.last.parent
    ancestors
  end
  
  def part2world p
    for a in ancestors.reverse 
      p += a.position
      #XXX rotation
    end
    p
  end
  
  def world2part p
    for a in ancestors
      p -= a.position
      #XXX rotation
    end
    p
  end
  
  def bounding_box
    @real_component.bounding_box.map{|p| part2world p }
  end
end




