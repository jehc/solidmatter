#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-07.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'export.rb'
require 'image.rb'
            
class RenderDialog
  def initialize
    @glade = GladeXML.new( "../data/glade/render_dialog.glade", nil, 'solidmatter' ) {|handler| method(handler)}
  end

  def ok
    close
    GC.enable
    parts = $manager.project.main_assembly.contained_parts.select{|p| p.visible }
    luxdata = generate_luxrender parts, $manager.glview.allocation.width-2, $manager.glview.allocation.height-2, false
    File::open("/tmp/lux.lxs",'w'){|f| f << luxdata }
    Thread.start{ `luxconsole /tmp/lux.lxs` }
    $manager.glview.visible = false
    $manager.render_view.visible = true
    $manager.set_status_text "Rendering started..."
    start_time = Time.now
    @render_thread = Thread.start do
      sleep $preferences[:lux_display_interval] / 2.0 + 2  # to compensate luxrender startup
      loop do
        sleep $preferences[:lux_display_interval]
        Gtk.queue{ $manager.set_status_text "Render time: #{time_from start_time}" }
        if File.exist? "/tmp/lux.png"
          #`cp /tmp/lux.png /tmp/luxcopy.png`
          Gtk.queue do
            gtkim = Gtk::Image.new("/tmp/lux.png")
            $manager.render_image.pixbuf = gtkim.pixbuf
          end
        end
        # for some reason we need to collect regularly
        GC.start 
      end
    end
  end
  
  def close
    @glade['render_dialog'].destroy
  end
  
  def save_image
    dia = FileOpenDialog.new '.png'
    if dia.run == Gtk::Dialog::RESPONSE_ACCEPT
      filename = dia.filename
      filename += '.png' unless filename =~ /.png/
      im = Image.new "/tmp/lux.png"
      im.save filename
    end
    dia.destroy
  end
  
  def stop_rendering
    `killall luxconsole`
    @render_thread.kill if @render_thread
    $manager.render_view.visible = false
    $manager.glview.visible = true 
  end
  
  def generate_luxrender parts, width, height, heal_mesh
    lxs =  "# Lux Render Scene File\n"
    lxs << "# Exported by Solid|matter\n"
    # setup camera
    cam = $manager.glview.cameras[$manager.glview.current_cam_index]
    lxs << "LookAt #{cam.position.x} #{cam.position.y} #{cam.position.z} #{cam.target.x} #{cam.target.y} #{cam.target.z} 0 1 0 \n"
    lxs << 'Camera "perspective" "float fov" [49.134342] "float hither" [0.100000] "float yon" [100.000000] 
                   "float lensradius" [0.010000] "bool autofocus" ["true"] "float shutteropen" [0.000000] 
                   "float shutterclose" [1.000000] "float screenwindow" [-1.000000 1.000000 -0.750000 0.750000]
           '
    # setup frame and render settings
    lxs << "Film \"fleximage\" \"integer xresolution\" [#{width}] \"integer yresolution\" [#{height}] \"integer haltspp\" [0] 
                 \"float reinhard_prescale\" [1.000000] \"float reinhard_postscale\" [1.800000] \"float reinhard_burn\" [6.000000] 
                 \"bool premultiplyalpha\" [\"true\"] \"integer displayinterval\" [8] \"integer writeinterval\" [#{$preferences[:lux_display_interval]}] 
                 \"string filename\" [\"lux\"] \"bool write_tonemapped_tga\" [\"true\"] 
                 \"bool write_tonemapped_exr\" [\"false\"] \"bool write_untonemapped_exr\" [\"false\"] \"bool write_tonemapped_igi\" [\"false\"] 
                 \"bool write_untonemapped_igi\" [\"false\"] \"bool write_resume_flm\" [\"false\"] \"bool restart_resume_flm\" [\"false\"] 
                 \"integer reject_warmup\" [3] \"bool debug\" [\"false\"] \"float colorspace_white\" [0.314275 0.329411] 
                 \"float colorspace_red\" [0.630000 0.340000] \"float colorspace_green\" [0.310000 0.595000]
                 \"float colorspace_blue\" [0.155000 0.070000] \"float gamma\" [2.200000]
           PixelFilter \"mitchell\" \"float B\" [0.667000] \"float C\" [0.166500]
           Sampler \"metropolis\" \"float largemutationprob\" [0.400000]
           SurfaceIntegrator \"path\" \"integer maxdepth\" [8] \"string strategy\" [\"auto\"] \"string rrstrategy\" [\"efficiency\"]
           VolumeIntegrator \"single\" \"float stepsize\" [1.000000]
           Accelerator \"tabreckdtree\" \"integer intersectcost\" [80] \"integer traversalcost\" [1] \"float emptybonus\" [0.200000]
                       \"integer maxprims\" [1] \"integer maxdepth\" [-1]
          "
    lxs << "WorldBegin\n"
    # create lights
    lxs << 'AttributeBegin
              LightGroup "default"
              LightSource "infinite" 
                "color L" [0.0565629 0.220815 0.2]
                "float gain" [1.000000]
            AttributeEnd
           '
    lxs << 'TransformBegin
            Transform [-0.290864646435 1.35517116785 -0.0551890581846 0.0  -0.771100819111 -0.19988335669 0.604524731636 0.0  0.566393196583 0.21839119494 0.794672250748 0.0  4.07624530792 1.00545394421 5.90386199951 1.0]
            LightGroup "default"
            Texture "Lamp:light:L" "color" "blackbody"
            "float temperature" [6500.000000]
            LightSource "point" "texture L" ["Lamp:light:L"]
            "float gain" [28.924402]
            TransformEnd
            '
    puts "static stuff finished"
    # create materials
    lxs << "MakeNamedMaterial \"default_mat\" \"string type\" [\"matte\"] \"color Kd\" [0.9 0.9 0.9]"
    parts.each{|p| lxs << p.information[:material].to_lux }
    # convert geometry
    for p in parts
      puts "building part"
      lxs << "AttributeBegin\n"
      lxs << "Transform [#{p.position.to_a.join ' '} #{p.position.to_a.join ' '} 1.0]\n"
      lxs << "NamedMaterial \"#{p.information[:material].name}\""
      tris = p.solid.tesselate heal_mesh
      puts "tesselated"
      lxs << 'Shape "trianglemesh" "integer indices" ['
      tris.size.times{|i| lxs << "#{i*3} #{i*3+1} #{i*3+2} \n" }
      puts "generated indices"
      lxs << "]\n"
      lxs << '"point P" ['
      tris.flatten.each{|v| lxs << v.to_a.map{|e| e * 1.0 }.join(" ") << "\n" }
      puts "generated vertices"
      lxs << "]\n"
      lxs << "AttributeEnd\n"
    end
    # create groundplane
    $manager.glview.ground.calculate_dimensions
    y = $manager.glview.ground.g_plane.origin.y
    tris = [ [Vector[-100, y, -100], Vector[-100, y, 100], Vector[100, y, -100]], 
             [Vector[-100, y, 100],  Vector[100, y, 100],  Vector[100, y, -100]] ]
    lxs << "AttributeBegin\n"
    lxs << 'NamedMaterial "default_mat"
    '
    lxs << 'Shape "trianglemesh" "integer indices" ['
    tris.size.times{|i| lxs << "#{i*3} #{i*3+1} #{i*3+2} \n" }
    lxs << "]\n"
    lxs << '"point P" ['
    tris.flatten.each{|v| lxs << v.to_a.join(" ") << "\n" }
    lxs << "]\n"
    lxs << "AttributeEnd\n"
    lxs << "WorldEnd\n"
  end
  
  def time_from start
    total_seconds = (Time.now - start).round
    seconds = total_seconds % 60
    minutes = ((total_seconds - seconds) / 60) % 60
    hours = ((total_seconds - seconds) / 60 - minutes) / 60
    [hours, minutes, seconds].map{|a| a.to_s.rjust(2, "0") }.join ":"
  end
end

