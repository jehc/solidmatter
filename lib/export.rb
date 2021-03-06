#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'ui/file_open_dialog.rb'
require 'ui/export_dialog.rb'


class Exporter
  def export parts
    ExportDialog.new do |filetype, heal_mesh|
      dia = FileOpenDialog.new filetype
      if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
        filename = dia.filename
        filename += filetype unless filename =~ Regexp.new(filetype)
        data = case filetype
          when '.stl' : generate_stl parts, heal_mesh
        end
        File::open(filename,"w"){|f| f << data }
      end
      dia.destroy
    end
  end

  def generate_stl parts, heal_mesh
    stl = "solid #{@name}\n"
    for p in parts
      for tri in p.solid.tesselate heal_mesh
        n = tri[0].vector_to(tri[1]).cross_product(tri[0].vector_to tri[2]).normalize
        n = Vector[0.0, 0.0, 0.0] if n.x.nan?
        stl += "  facet normal #{n.x} #{n.y} #{n.z}\n"
        stl += "    outer loop\n"
        for v in tri
          stl += "    vertex #{v.x} #{v.y} #{v.z}\n"
        end
        stl += "    endloop\n"
        stl += "  endfacet\n"
      end
    end
    stl += "endsolid #{@name}\n"
    return stl
  end
end


