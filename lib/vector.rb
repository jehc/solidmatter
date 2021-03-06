#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'matrix'

class Vector
  attr_accessor :elements
  alias dot_product inner_product
  alias length r
  
  def vec4
    Vector[ self[0], self[1], self[2], 1 ]
  end
  
  def vec3!
    @elements.delete_at 3
    self
  end
  
  def x
    @elements[0]
  end
  
  def y
    @elements[1]
  end
  
  def z
    @elements[2]
  end
  
  def x=(v)
    @elements[0] = v
  end

  def y=(v)
    @elements[1] = v
  end
  
  def z=(v)
    @elements[2] = v
  end
  
  def add( v )
    @elements[0] += v.x
    @elements[1] += v.y
    @elements[2] += v.z
  end
  
  def /( value )
    Vector[x/value, y/value, z/value]
  end
  
  def cross_product(vec)
    Vector[
      (@elements[1] * vec[2]) - (@elements[2] * vec[1]),
      (@elements[2] * vec[0]) - (@elements[0] * vec[2]),
      (@elements[0] * vec[1]) - (@elements[1] * vec[0])
    ]
  end
  
  def length=(new_len)
    new_vec = self * (new_len / self.length )
    3.times{|i| @elements[i] = new_vec[i]}
    self
  end
  
  def normalize!
    self.length = 1
    return self
  end
  
  def normalize
    new_vec = self.dup
    new_vec.normalize!
    return new_vec
  end

  def reverse!
    @elements.size.times{|i| @elements[i] = -@elements[i] }
    return self
  end
  alias invert! reverse!
  
  def reverse
    new_vec = self.dup
    new_vec.reverse!
    return new_vec
  end
  alias invert reverse
  
  def angle( vec )
    dot = self.normalize.dot_product(vec.normalize)
    return (Math.acos( dot ) / (2 * Math::PI)) * 360
  end
  
  def vector_to( v )
    v - self
  end
  
  def distance_to v
   (vector_to v).length
  end
  
  def near_to other
    distance_to(other) < $preferences[:merge_threshold]
  end
  
  def take_coords_from vec
    vec.elements.size.times{|i| @elements[i] = vec[i] }
  end
  
  def project_xy
   Vector[ self[0], self[1], 0 ]
  end
  
  def project_xz
   Vector[ self[0], 0, self[2] ]
  end
  
  def project_yz
   Vector[ 0, self[1], self[2] ]
  end
  
  def orthogonal_to? other
    dot_product(other).nearly_equals 0
  end
  
  def parallel_to? other
    cross_product(other).length.nearly_equals 0
  end
  
  def to_polar
    a1 = Math.atan2(y,x)
    a2 = Math::PI/2 - atan( z / Math.sqrt(x**2 + y**2) )
    [a1, a2]
  end
  
  def dup
    copy = super
    copy.elements = @elements.dup
    return copy
  end
end

class Numeric
  def nearly_equals other
    (self - other).abs < $preferences[:merge_threshold]
  end
end






