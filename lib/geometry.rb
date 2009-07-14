#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'matrix.rb'
require 'units.rb'


module Selectable
  attr_accessor :selection_pass_color, :selected
end


def bounding_box_from points
  xs = points.map{|p| p.x }
  ys = points.map{|p| p.y }
  zs = points.map{|p| p.z }
  min_x = xs.min ; max_x = xs.max
  min_y = ys.min ; max_y = ys.max
  min_z = zs.min ; max_z = zs.max
  corners = [
    Vector[min_x, min_y, min_z],
    Vector[min_x, min_y, max_z],
    Vector[min_x, max_y, min_z],
    Vector[max_x, min_y, min_z],
    Vector[min_x, max_y, max_z],
    Vector[max_x, max_y, min_z],
    Vector[max_x, min_y, max_z],
    Vector[max_x, max_y, max_z]]
  points.empty? ? [] : corners
end

def sparse_bounding_box_from points
  if points.empty?
    nil
  else
    xs = points.map{|p| p.x }
    ys = points.map{|p| p.y }
    zs = points.map{|p| p.z }
    min_x = xs.min ; max_x = xs.max
    min_y = ys.min ; max_y = ys.max
    min_z = zs.min ; max_z = zs.max
    center = Vector[(min_x + max_x)/2.0, (min_y + max_y)/2.0, (min_z + max_z)/2.0,]
    width  = (min_x - max_x).abs
    height = (min_y - max_y).abs
    depth  = (min_z - max_z).abs
    [center, width, height, depth]
  end
end


class InfiniteLine
  def initialize( pos, dir )
    @pos = pos
    @dir = dir
  end
  
  def intersect_with plane
    po, pn = plane.origin, plane.normal
    t = (po - @pos).dot_product(pn) / @dir.dot_product(pn)
    @pos + (@dir * t)
  end
end


class Segment
  include Selectable
  attr_accessor :reference, :sketch, :resolution, :constraints
  def initialize( sketch )
    @sketch = sketch
    @reference = false
    @constraints = []
    @selection_pass_color = [1.0, 1.0, 1.0]
  end
  
  def snap_points
    []
  end
  
  def bounding_box
    bounding_box_from snap_points.map{|p| Tool.sketch2part(p, @sketch.plane.plane) }
  end
  
  def cut_at points
    cut_segments = [self]
    for p in points
      cut_segments.each_with_index do |seg,i|
        if seg.touches? p
          cut_segments[i] = seg.cut_at_point(p)
          cut_segments.flatten!
          cut_segments.compact!
          retry
        end
      end
    end
    cut_segments
  end
  
  def +( vec )
    raise "Segment #{self} does not make translated copies of itself"
  end
  
  def draw
    raise "Segment #{self} is not able to draw itself"
  end
end


class Vector # should be discarded in favor of point
  attr_writer :constraints
  attr_accessor :segment
  def constraints
    @constraints ||= []
    @constraints
  end
  
  def dynamic_points
    [self]
  end

  def draw
    GL.Color3f(0.98,0.87,0.18)
    GL.PointSize(8.0)
    GL.Begin( GL::POINTS )
      GL.Vertex( x,y,z )
    GL.End
  end
end


class Line < Segment
  attr_accessor :pos1, :pos2
  def initialize( start, ende, sketch=nil )
    super sketch
    @pos1 = start.dup
    @pos2 = ende.dup
    @pos1.segment = self
    @pos2.segment = self
  end

  def midpoint
    (@pos1 + @pos2) / 2.0
  end

  def snap_points
    super + [@pos1, @pos2, midpoint]
  end
  
  def dynamic_points
     [@pos1, @pos2]
  end

  def tesselate
    [self]
  end
  
  def to_vec
    @pos1.vector_to(@pos2)
  end
  
  def length
    to_vec.length
  end

  def draw
    GL.Begin( GL::LINES )
      GL.Vertex( @pos1.x, @pos1.y, @pos1.z )
      GL.Vertex( @pos2.x, @pos2.y, @pos2.z )
    GL.End
  end

  def +( vec )
    Line.new( @pos1 + vec, @pos2 + vec, @sketch )
  end
  
  def horizontal?
    @pos1.y == @pos2.y
  end
  
  def vertical?
    @pos1.x == @pos2.y
  end
  
  def orthogonal_to? other
    case other
    when Vector
      self.to_vec.orthogonal_to? other
    when Line
      self.to_vec.orthogonal_to? other.to_vec
    end
  end
  
  def parallel_to? other
    case other
    when Vector
      self.to_vec.parallel_to? other
    when Line
      self.to_vec.parallel_to? other.to_vec
    end
  end
  
  def offset_from parallel_line
    raise "Lines are not parallel" unless parallel_to? parallel_line
    parallel_line.pos1.distance_to( closest_point parallel_line.pos1 ) 
  end
  
  def closest_point point
    dir = to_vec.normalize
    @pos1 + dir * @pos1.vector_to(point).dot_product(dir)
  end
  
  def touches?( p, with_endpoints=false )
    # check if on infinite line
    return false unless closest_point(p).near_to p
    # check if within bounds
    l = length
    if with_endpoints
      @pos1.distance_to(p) <= l and 
      @pos2.distance_to(p) <= l
    else
      @pos1.distance_to(p) < l and 
      @pos2.distance_to(p) < l
    end
  end
  
  def intersections_with other
    case other
    when Line
      return [] if parallel_to? other
      #XXX in 3d we need to check if distance to other is zero as well
      d = self.to_vec
      e = other.to_vec
      n = d.cross_product e
      sr = @pos1.vector_to other.pos1
      if n.z.abs > n.x.abs and n.z.abs > n.y.abs
        t = (sr.x * e.y - rs.y * e.x) / n.z
        u = (sr.x * d.y - rs.y * d.x) / n.z
      elsif n.x.abs > n.y.abs
        t = (sr.y * e.z - rs.z * e.y) / n.x
        u = (sr.y * d.z - rs.z * d.y) / n.x
      else
        t = (sr.z * e.x - sr.x * e.z) / n.y
        u = (sr.z * d.x - sr.x * d.z) / n.y
      end
      p = @pos1 + d * t
      # check if p lies on both segments
      for seg in [self, other]
        return [] unless seg.touches?( p, true )
      end
      [p]
    when Arc2D
      puts "Delegating to arc"
      other.intersections_with self
    end
  end
  
  def cut_at_point p
    cpy1, cpy2 = dup, dup
    cpy1.pos1 = p
    cpy2.pos2 = p
    [cpy1, cpy2]
  end

  def dup
    copy = super
    copy.pos1 = @pos1.dup
    copy.pos2 = @pos2.dup
    copy
  end
end

class Arc2D < Segment
  attr_accessor :center, :radius, :start_angle, :end_angle, :points
  def initialize( center, radius, start_angle, end_angle, sketch=nil )
    super sketch
    @center = center
    @radius = radius
    @start_angle = start_angle
    @end_angle = end_angle
    @points = []
  end
  
  def point_at angle
    x = Math.cos( (angle/360.0) * 2*Math::PI ) * @radius + @center.x
    z = Math.sin( (angle/360.0) * 2*Math::PI ) * @radius + @center.z
    Vector[ x, @center.y, z ]
  end
  
  def angle_of p
    p = closest_point p
    Math.acos((p.x - @center.x) / @radius) / (2 * Math::PI) * 360
  end
  
  def pos1
    point_at @start_angle
  end
  
  def pos2
    point_at @end_angle
  end
  
#  def own_and_neighbooring_points
#    points = []
#    for seg in @sketch.segments
#      for pos in [seg.pos1, seg.pos2]
#        if [pos1, pos2].any?{|p| p.x == pos.x and p.y == pos.y and p.z == pos.z }
#          points.push pos
#        end
#      end
#    end
#    points.push @center
#    return points.uniq
#  end

  def snap_points
    super + [pos1, pos2, midpoint, @center]
  end
  
  def midpoint
    point_at( (@start_angle + @end_angle) / 2.0 )
  end
  
  def dynamic_points
    [@center]
  end
  
  def closest_point p
    @center + @center.vector_to( p ).normalize * @radius
  end
  
  def touches?( p, with_endpoints=false )
    on_circle = @center.distance_to( p ).nearly_equals @radius
    return false unless on_circle
    a = angle_of p
    if with_endpoints
      a >= @start_angle and a <= @end_angle
    else
      a > @start_angle and a < @end_angle
    end
  end
  
  def tangent? line
    self.touches? line.closest_point @center
  end
  
  def intersections_with line
    cp = line.closest_point @center
    if tangent? line
      puts "returning exactly one solution"
      [cp]
#    elsif @center.distance_to( cp ) > @radius+0.5
#      puts "no solution"
#      []
    else
      p1, p2 = line.pos1 - @center, line.pos2 - @center
      d = line.to_vec
      l = d.length
      f = p1.x * p2.z - p2.x * p1.z
      sgn = (d.z < 0  ?  -1 : 1)
      delta = @radius**2 * l**2 - f**2
      if delta < 0
        puts "no solution because of delta"
        return []
      elsif delta.nearly_equals 0
        puts "one sol because of delte"
        [cp]
      else
        x1 = ( f * d.z + sgn * d.x * Math.sqrt(delta) ) / l**2
        x2 = ( f * d.z - sgn * d.x * Math.sqrt(delta) ) / l**2
        z1 = (-f * d.x + d.z.abs *   Math.sqrt(delta) ) / l**2
        z2 = (-f * d.x - d.z.abs *   Math.sqrt(delta) ) / l**2
        candidates = [Vector[x1,0,z1] + @center, Vector[x2,0,z2] + @center]
        # check if points are really on both segments
        candidates.select{|c| [self,line].all?{|seg| seg.touches? c } }
      end
    end
  end
  
  def cut_at_point p
    a = angle_of p
    cpy1, cpy2 = dup, dup
    cpy1.start_angle = a
    cpy2.end_angle = a
    [cpy1, cpy2]
  end
  
  def tesselate
    span = (@start_angle - @end_angle).abs
    if span > 0
      angle = @start_angle
      increment = span.to_f / $preferences[:surface_resolution]
      @points.clear
      begin
        @points.push point_at angle
        angle += increment
        angle = angle - 360 if angle > 360
      end until (angle - @end_angle).abs < increment
      @points << point_at( @end_angle )
    end
    @lines = []
    for i in 0...(@points.size-1)
      line = Line.new( @points[i], @points[i+1] )
      line.selection_pass_color = @selection_pass_color
      @lines.push line
    end
    return @lines
  end
  
  def draw
    tesselate #if @points.empty?
    GL.Begin( GL::LINE_STRIP )
      for p in @points
        #p = @plane.plane2part p unless @sketch
        GL.Vertex( p.x, p.y, p.z )
      end
    GL.End
  end
  
  def +( vec )
    copy = dup
    copy.center = @center + vec
    copy
  end
  
  def dup
    copy = super
    copy.center = self.center.dup
    copy.points.clear
    copy
  end
end

class Circle2D < Arc2D
  def initialize( center, radius, sketch)
    super center, radius, 0.0, 360.0, sketch
  end
  
  def Circle2D::from3points( p1, p2, p3, sketch )
    
  end
  
  def Circle2D::from_opposite_points( p1, p2, sketch )
    center = p1 + (p1.vector_to(p2) / 2.0)
    radius = center.distance_to p1
    Circle2D.new( center, radius, sketch)
  end
  
  def snap_points
    quadrants = [0, 90, 180, 270].map{|a| point_at a }
    super + quadrants
  end
end


class Arc3D < Arc2D
  attr_accessor :plane
  def initialize( plane, radius, start_angle, end_angle )
    @plane = plane.dup
    super( Vector[0,0,0], radius, start_angle, end_angle)
  end
  
  def point_at angle
    @plane.plane2part( super )
  end
  
  def center
    @plane.origin
  end
  
  def center= c
    @plane.origin = c.dup
  end
  
  def dup
    copy = super
    copy.plane = @plane.dup
    copy
  end
end

class Circle3D < Arc3D
  def initialize( plane, radius)
    super plane, radius, 0.0, 360.0
  end
end


class Spline < Segment
  attr_accessor :cvs, :degree
  def initialize( cvs, degree=3, sketch=nil )
    super sketch
    @cvs = cvs
    @degree = degree
  end
  
  def order
    @degree + 1
  end
  
  def pos1
    @cvs.first
  end
  
  def pos2
    @cvs.last
  end
  
  def midpoint
    
  end

  def snap_points
    super + [@cvs.first, @cvs.last]
  end
  
  def dynamic_points
     @cvs
  end

  def tesselate
    tess_vertices = []
    if @cvs.size >= 2
      first_p = @cvs[0] + @cvs[1].vector_to(@cvs[0])
      last_p = @cvs[-1] + @cvs[-2].vector_to(@cvs[-1])
      nurb = GLU.NewNurbsRenderer
      knots = (0..(@cvs.size+order+2)).to_a
      points = ([first_p] + @cvs + [last_p]).map{|cv| cv.elements[0..3] }.flatten
      GLU.NurbsProperty( nurb, GLU::DISPLAY_MODE, GLU::OUTLINE_POLYGON)
      GLU.NurbsProperty( nurb, GLU::SAMPLING_METHOD, GLU::OBJECT_PATH_LENGTH )
      GLU.NurbsProperty( nurb, GLU::SAMPLING_TOLERANCE, $preferences[:surface_resolution] )
      GLU.NurbsProperty( nurb, GLU::NURBS_MODE, GLU::NURBS_TESSELLATOR )
      # register callbacks
      GLU.NurbsCallback( nurb, GLU::NURBS_BEGIN, lambda{ } )
      GLU.NurbsCallback( nurb, GLU::NURBS_END, lambda{ } )
      GLU.NurbsCallback( nurb, GLU::NURBS_VERTEX, lambda{|v| puts "hooray"; tess_vertices << Vector[v[0],v[1],v[2]] if v } )
      GLU.NurbsCallback( nurb, GLU::NURBS_ERROR, lambda{|errCode| raise "Nurbs tessellation Error: #{GLU::ErrorString errCode}" } )
      # tesselate curve
      GLU.BeginCurve nurb
        GLU.NurbsCurve( nurb, @cvs.size+order+2, knots, 3, points, order, GL::MAP1_VERTEX_3 )
      GLU.EndCurve nurb
      GLU.DeleteNurbsRenderer nurb
    end
    tess_vertices
  end
  
  def length
    0
  end

  def draw
    if @cvs.size >= 2
      first_p = @cvs[0] + @cvs[1].vector_to(@cvs[0])
      last_p = @cvs[-1] + @cvs[-2].vector_to(@cvs[-1])
      # render curve
      nurb = GLU.NewNurbsRenderer
      knots = (0..(@cvs.size+order+2)).to_a
      points = ([first_p] + @cvs + [last_p]).map{|cv| cv.elements[0..3] }.flatten
      GLU.NurbsProperty( nurb, GLU::SAMPLING_METHOD, GLU::OBJECT_PATH_LENGTH )
      GLU.NurbsProperty( nurb, GLU::SAMPLING_TOLERANCE, $preferences[:surface_resolution] )
      GLU.BeginCurve nurb
        GLU.NurbsCurve( nurb, @cvs.size+order+2, knots, 3, points, order, GL::MAP1_VERTEX_3 )
      GLU.EndCurve nurb
      GLU.DeleteNurbsRenderer nurb
    end
    # draw vertices
    @cvs.each{|p| p.draw }
  end

  def dup
    copy = super
    copy.cvs.map!{|p| p.dup }
  end
end


class Plane
  attr_accessor :origin, :rotation, :u_vec, :v_vec
  def Plane.from3points( p1=nil, p2=nil, p3=nil)
    origin = p1 ? p1 : Vector[0.0, 0.0, 0.0]
    u_vec  = Vector[1.0, 0.0, 0.0]
    v_vec  = Vector[0.0, 0.0, 1.0]
    if p1 and p2 and p3
      u_vec = origin.vector_to(p2).normalize
      v_vec = origin.vector_to(p3).normalize
    end
    Plane.new(origin, u_vec, v_vec)
  end
  
  def initialize( o=nil, u=nil, v=nil )
    @origin = o ? o : Vector[0.0, 0.0, 0.0]
    @u_vec  = u ? u.normalize : Vector[1.0, 0.0, 0.0]
    @v_vec  = v ? v.normalize : Vector[0.0, 0.0, 1.0]
  end
  
  def normal_vector
    return @v_vec.cross_product( @u_vec )
  end
  alias normal normal_vector
  
  def normal_vector= normal
    normal.normalize!
    help_vec = Vector[normal.y, normal.x, normal.z]
    @u_vec = normal.cross_product( help_vec ).normalize
    @v_vec = normal.cross_product( @u_vec ).normalize.invert
  end
  alias normal= normal_vector=
  
  def closest_point( p )
    distance = normal_vector.dot_product( @origin.vector_to p )
    return p - ( normal_vector * distance )
  end
  
  def plane2part segment
    case segment
    when Line
      Line.new( plane2part(segment.pos1), plane2part(segment.pos2))
#    when Arc2D
#      pl = Plane.new
#      Arc3D.new( plane2part(segment.center), 
#               segment.radius,
#               segment.start_angle,
#               segment.end_angle,
#               segment.plane.dup || segment.sketch.plane.dup)
    when Vector
      @u_vec * segment.x + normal * segment.y + @v_vec * segment.z + @origin
    end
  end
  
  def transform_like plane
      @origin = plane.origin
      @u_vec = plane.u_vec
      @v_vec = plane.v_vec
  end
  
  def dup
    copy = super
    copy.origin = @origin.dup
    copy.u_vec = @u_vec
    copy.v_vec = @v_vec
    copy
  end
end


class Polygon
  attr_accessor :points
  def Polygon::from_chain chain
    redundant_chain_points = chain.map{|s| s.tesselate }.flatten.map{|line| [line.pos1, line.pos2] }.flatten
    chain_points = []
    for p in redundant_chain_points #XXX this should be possible with .uniq
      chain_points.push p unless chain_points.include? p
    end
    poly = Polygon.new( chain_points )
    poly.close
    return poly
  end
  
  def initialize( points=[] )
    @points = points
    @normal = Vector[0,1,0]
  end
  
  def close
    @points.push @points.first unless @points.last == @points.first    
  end
  
  def push p
    @points.push p
  end
  
  def area
    mesh_area
  end
  
  def mesh_area
    tesselate.inject(0.0) do |area, triangle|
      edge_vec1 = triangle[0].vector_to triangle[1]
      edge_vec2 = triangle[0].vector_to triangle[2]
      tr_area = (edge_vec1.cross_product edge_vec2).length * 0.5
      area + tr_area
    end
  end
  
  def monte_carlo_area
    samples = $preferences[:area_samples]
    xs = @points.map{|p| p.x }.sort
    zs = @points.map{|p| p.z }.sort
    left = xs.first
    right = xs.last
    upper = zs.last
    lower = zs.first
    a = 0.0
    samples.times do
      x = left + rand * (right-left).abs
      z = lower + rand * (upper-lower).abs
      a += 1 if contains? Vector[x,z,0]
    end
    (a / samples) * (right-left).abs * (upper-lower).abs
  end

  def contains? point_or_poly
    if point_or_poly.is_a? Polygon
      poly = point_or_poly
      return poly.points.all?{|p| self.contains? p }
    else
      point = point_or_poly
      # shoot a ray from the point upwards and count the number ob edges it intersects
      intersections = 0
      0.upto( @points.size - 2 ) do |i|
        e1 = @points[i]
        e2 = @points[i+1]
        # check if edge intersects up-axis
        if (e1.x <= point.x and point.x <= e2.x) or (e1.x >= point.x and point.x >= e2.x)
          left_dist = (e1.x - point.x).abs
          right_dist = (e2.x - point.x).abs
          intersection_point = (e1 * right_dist + e2 * left_dist) * (1.0 / (left_dist + right_dist))
          intersections += 1 if intersection_point.z > point.y
        end
      end
      return intersections % 2 != 0
     end
  end
  
  def to_cw!
    @points.reverse! unless clockwise?
    self
  end
  
  def to_ccw!
    @points.reverse! if clockwise?
    self
  end
  
  def clockwise?
    cross = @points[0].vector_to( @points[1] ).cross_product( @points[1].vector_to( @points[2] ) )
    dot = cross.dot_product @normal
    return dot < 0
  end
  
  def tesselate
    vertices = []
    tess = GLU::NewTess()
    GLU::TessCallback( tess, GLU::TESS_VERTEX, lambda{|v| vertices << Vector[v[0],v[1],v[2]] if v } )
    GLU::TessCallback( tess, GLU::TESS_BEGIN, lambda{|which| vertices << which.to_s } )
    GLU::TessCallback( tess, GLU::TESS_END, lambda{ } )
    GLU::TessCallback( tess, GLU::TESS_ERROR, lambda{|errCode| raise "Tessellation Error: #{GLU::ErrorString errCode}" } )
    GLU::TessCallback( tess, GLU::TESS_COMBINE, 
      lambda do |coords, vertex_data, weight|
        vertex = [coords[0], coords[1], coords[2]]
        vertex
      end 
    )
    GLU::TessProperty( tess, GLU::TESS_WINDING_RULE, GLU::TESS_WINDING_POSITIVE )
    GLU::TessBeginPolygon( tess, nil )
      GLU::TessBeginContour tess
        @points.each{|p| GLU::TessVertex( tess, p.elements, p.elements ) }
      GLU::TessEndContour tess
    GLU::TessEndPolygon tess
    GLU::DeleteTess tess
    # vertices should now be filled with interleaved points and drawing instructions
    # as grouping is triggered through the next instruction string we put a random one at the end 
    vertices << GL::TRIANGLES.to_s
    triangles = []
    container = []
    last_geom_type = nil
    for point_or_instruct in vertices
      case point_or_instruct
      when String    
        case last_geom_type
        when GL::TRIANGLES.to_s
          triangles += triangles2triangles container
        when GL::TRIANGLE_STRIP.to_s
          triangles += triangle_strip2triangles container
        when GL::TRIANGLE_FAN.to_s
          triangles += triangle_fan2triangles container
        when nil
        else 
          raise "We dont handle this GL geometry type yet: #{point_or_instruct}"
        end
        last_geom_type = point_or_instruct
        container = []
      when Vector
        container << point_or_instruct
      end
    end
    return triangles
  end
  
  def triangle_strip2triangles points
    triangles = []
    points.each_with_index do |p,i|
      break unless points[i+2]
      triangles << ( i % 2 == 0 ? [p, points[i+1], points[i+2]] : [points[i+1], p, points[i+2]] )
    end
    triangles
  end
  
  def triangle_fan2triangles points
    center = points.shift
    triangles = []
    points.each_with_index do |p,i|
      break unless points[i+1]
      triangles << [center, p, points[i+1]]
    end
    triangles
  end
  
  def triangles2triangles points
    triangles = []
    triangles << [points.shift, points.shift, points.shift] until points.empty?
    triangles
  end
end



