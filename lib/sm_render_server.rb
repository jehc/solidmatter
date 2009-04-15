#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2009-02-27.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
require 'thread'
require 'drb'
require 'gnome2'
require 'gtkglext'
require 'project.rb'
require 'vector.rb'
require 'gl_view.rb'
require 'geometry.rb'
require 'export.rb'
require 'gtk_threadsafe.rb'
require 'preferences.rb'


class Manager
  attr_accessor :focus_view, :clipboard, :point_snap, :grid_snap, :use_sketch_guides, :filename,
                :selection, :work_component, :work_sketch, :work_operator, :project,
                :glview, :keys_pressed, :keymap, :has_been_changed
              
  def initialize
    @focus_view = true
    @keys_pressed = []
    @point_snap = true
    @grid_snap = false
    @use_sketch_guides = false
    # @keymap = { 65505 => :Shift,
    #             65507 => :Ctrl,
    #             65406 => :Alt,
    #             65307 => :Esc,
    #             65288 => :Backspace,
    #             65535 => :Del}  
    new_project
  end
  
public
  def project_name
    "XXX"
  end
  
  def new_project
      puts "clean"
      #@glview.ground.clean_up if @not_starting_up
      puts "new proj"
      @project = Project.new
      puts "main asse"
      @work_component = @project.main_assembly
      @work_sketch = nil
      puts "redraw"
      @glview.redraw if @not_starting_up
      @not_starting_up = true
      yield if block_given?
  end

  
  def component_changed comp
  end

  def add_object( inst, insert=true )
    @project.add_object( inst, insert )
    @client.component_added inst if inst.is_a? Instance and @client and @client.working
  end

  def open_file filename
    puts "loading"
    @project = Project.load filename
    puts "changing"
    change_working_level @project.main_assembly 
    puts "building"
    @project.rebuild
    puts "build all"
    @project.all_parts.each{|p| p.build }
    puts "zoom"
    @glview.zoom_onto @project.all_part_instances.select{|i| i.visible }
    puts "finished"
  end

  def change_working_level component
    # display only current part's sketches
    @work_component.unused_sketches.each{|sk| sk.visible = false } if @work_component.class == Part
    @work_component = component
    @work_component.unused_sketches.each{|sk| sk.visible = true } if @work_component.class == Part
    # make other components transparent
    @project.main_assembly.transparent = @focus_view ? true : false
    @work_component.transparent = false
    @glview.redraw
  end
  
  def working_level_up
    cancel_current_tool
    unless exit_current_mode
      parent = @work_component.parent 
      change_working_level( parent ) if parent
    end
  end
  
  def upmost_working_level?
    @work_component == @project.main_assembly
  end
  
  def top_ancestor comp
    while comp
      break if comp.parent == @work_component
      comp = comp.parent
    end
    # comp now contains the topmost ancestor of the original comp that is directly in the work assembly.
    # if not, the component selected is in an assembly on top of the work asm and neglected
    return comp
  end
  
  def next_assembly
    working_level_up while @work_component.class == Part
    @work_component
  end
  
  # return from drawing, tool or operator mode
  def exit_current_mode
    if @work_sketch
      @work_sketch.visible = false unless @work_component.unused_sketches.include? @work_sketch
      @work_sketch.plane.animate -1
      @work_sketch.plane.visible = false
      op = @work_sketch.op
      op.part.build op if op
      @work_sketch = nil
      @glview.redraw
      return true
    elsif @work_operator
      @work_operator = nil
      return true
    elsif @work_tool
      @work_tool = nil
      cancel_current_tool
      return false
    end
    return false
  end
  
  def sketch_mode sketch
    # roll back operators up to this point in history
    op = sketch.op
    if op
      i = op.part.operators.index op
      old_limit = op.part.history_limit
      op.part.history_limit = i
      op.previous ? op.part.build(op.previous) : op.part.build
      op.part.history_limit = old_limit
    end
    @work_sketch = sketch
    sketch.parent.cog = nil
    sketch.plane.visible = true
    sketch.visible = true
  end
  
  def operator_mode op
    @work_operator = op
  end
  
  def tool_mode tool
    @work_tool = tool
  end
  
  def enable_operator op
    op.enabled = (not op.enabled)
    op.part.build op
    @glview.redraw
  end
end





# override classes from Solidmatter that are not needed for the service
class Manager
  def method_missing(m,*a)
    # # if its an accessor method
    # if /.+\=/ =~ m.to_s
    #   # add getters and setters to class
    #   class << self; self end.send( "attr_accessor", m.to_s.chop.to_sym )
    #   # recall method
    #   self.send(m,*a)
    # else
    #   # let's see how far we get ;)
      Dummy.new
    #end
  end
end
 
class Dummy
  def method_missing(m,*a)
    Dummy.new
  end
end
 
# deletes all methods in a class
class Module
  def override
    meths = instance_methods - Object.new.methods
    for meth in meths
      class_eval "undef #{meth}"
    end
    class_eval "
      def initialize(*a)
      end
      def method_missing(m,*a)
        Dummy.new
      end
    "
  end
end
 
class ProgressDialog
  override
end
 
# class OpView
#   override
# end



class RenderWin < Gtk::Window
  def initialize
    super
    self.reallocate_redraws = true
    self.title = "Solidmatter render server"
    self.window_position = Gtk::Window::POS_CENTER
    self.set_size_request(320,240)
    signal_connect('delete-event'){ Gtk.main_quit }
    glview = GLView.new
    $manager.glview = glview
    vbox = Gtk::VBox.new false
    vbox.pack_start( glview, true, true )
    add vbox
    show_all
  end
end

$preferences[:thumb_res] = 150
$preferences[:screenshot_step] = 4
FakeCompInfo = Struct.new(:volume, :mass, :area, :material, :thumb, :comp_id)

class Service
  def initialize
    $manager = Manager.new
    @win = RenderWin.new
  end
  
  def start
    DRb.start_service( "druby://:#{ARGV[0]||5000}", self )
  end
  
  def stop
    DRb.stop_service
    Gtk.main_quit
    nil
  end
  
  def load pr_name
    puts "doing loading project #{pr_name}"
    @pr_name = pr_name
    wait = true
    Gtk.queue do
      $manager.open_file "../../../public/project_base/#{pr_name.downcase}.smp"
      wait = false
    end
    sleep 0.1 while wait
    nil
  end
  
  def render_component comp_id
      wait = true
      Gtk.queue do
        comps = $manager.project.all_parts + $manager.project.all_assemblies
        comp = comps.find{|c| c.component_id == comp_id.to_i }
        if comp
          $manager.glview.redraw
          im = $manager.glview.image_of_parts( comp.class == Assembly ? comp.contained_parts : comp )
          im.save "../../../public/project_base/#{@pr_name.downcase}/images/#{comp_id}.png"
        end
        wait = false
      end
      sleep 0.1 while wait
    nil
  end
  
  def find_components kwds
    pr = $manager.project
    comps = pr.all_parts + pr.all_assemblies
    comps.select{|c| kwds.all?{|kwd| /#{kwd}/i =~ c.information[:name] } }.map do |c|
      [c.component_id.to_s, c.information[:name], c.information[:author]]
    end
  end
  
  def all_parts
    $manager.project.all_parts.map{|c| [c.component_id.to_s, c.information[:name], c.information[:author]] }
  end
  
  def all_assemblies
    $manager.project.all_assemblies.map{|c| [c.component_id.to_s, c.information[:name], c.information[:author]] }
  end
  
  def calculate_physical_data c_info
    pr = $manager.project
    comps = pr.all_parts + pr.all_assemblies
    c = comps.find{|e| e.component_id.to_s == c_info.comp_id }
    return unless c
    c_info.area = 1#c.area
    if c.class == Assembly
      c_info.volume, c_info.mass, dummy = 1,2,3#c.volume_mass_and_cog
      #c_info.thumb = $manager.glview.image_of_parts( c.contained_parts )
    else
      c_info.volume, dummy = 1,2 #c.volume_and_cog
      c_info.mass = 3 #c.mass info.volume.to_f
      c_info.material = c.information[:material].name
      File::open( "../../../public/project_base/#{@pr_name.downcase}.smp" ) do |file|
        thumb, dummy = Marshal::restore file #$manager.glview.image_of_parts [c]
        #thumb.save( "../../../public/images/generated/#{@pr_name.downcase}.png" )
      end
    end
    c_info
  end
  
  def generate_stl comp_id
    pr = $manager.project
    comps = pr.all_parts + pr.all_assemblies
    c = comps.find{|e| e.component_id.to_s == comp_id }
    return unless c
    stl = Exporter.new.generate_stl [c], false
    File::open( "../../../public/downloads/#{@pr_name.downcase}.stl", 'w' ){|f| f << stl }
  end
end



GetText.bindtextdomain 'solidmatter'
Thread.abort_on_exception = true

Gtk.init
Gtk::GL.init
Service.new.start
puts "Render node ready"
$stdout.flush
Gtk.main_with_queue 100



