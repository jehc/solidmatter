#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.


class BackgroundMenu < Gtk::Menu
  def initialize
    super()
    items = [
      Gtk::ImageMenuItem.new(GetText._("_Return")).set_image( Gtk::Image.new(Gtk::Stock::UNDO, Gtk::IconSize::MENU) ),
      Gtk::SeparatorMenuItem.new,
      Gtk::ImageMenuItem.new(Gtk::Stock::PASTE)
    ]
    items[0].sensitive = ($manager.work_sketch or 
                          $manager.work_operator or 
                          $manager.work_component != $manager.project.main_assembly) ? true : false
    items[2].sensitive = $manager.clipboard ? true : false
    # return
    items[0].signal_connect("activate") do
      $manager.working_level_up
    end
    # paste
    items[2].signal_connect("activate") do
      $manager.paste_from_clipboard
    end
    items.each{|i| append i }
    show_all
  end
end


class ComponentMenu < Gtk::Menu
  def initialize( part, location )
    super()
    items = [
      Gtk::ImageMenuItem.new(Gtk::Stock::EDIT),
      Gtk::SeparatorMenuItem.new,
      Gtk::MenuItem.new( GetText._("Duplicate instance")),
      Gtk::MenuItem.new( GetText._("Duplicate original")),
      Gtk::ImageMenuItem.new(Gtk::Stock::CUT),
      Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
      Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
      Gtk::ImageMenuItem.new(Gtk::Stock::DELETE),
      Gtk::SeparatorMenuItem.new,
      Gtk::CheckMenuItem.new( GetText._("Visible")),
      Gtk::CheckMenuItem.new( GetText._("Show center of gravity")),
      Gtk::SeparatorMenuItem.new,
      Gtk::ImageMenuItem.new(Gtk::Stock::PROPERTIES)
    ]
    items[4].sensitive = (not $manager.selection.empty?)
    items[5].sensitive = (not $manager.selection.empty?)
    items[6].sensitive = $manager.clipboard ? true : false
    items[7].sensitive = (not $manager.selection.empty?)
    items[9].active = part.visible
    items[10].active = part.cog ? true : false
    

    # edit part
    items[0].signal_connect("activate") do
      $manager.change_working_level $manager.selection.first
    end
    # duplicate instance
    items[2].signal_connect("activate") do
      $manager.duplicate_instance
    end
    # duplicate original
    items[3].signal_connect("activate") do
      # dupli orig
    end
    # cut
    items[4].signal_connect("activate") do
      $manager.cut_to_clipboard
    end
    # copy
    items[5].signal_connect("activate") do
      $manager.copy_to_clipboard
    end
    # paste
    items[6].signal_connect("activate") do
      $manager.paste_from_clipboard
    end
    # delete
    items[7].signal_connect("activate") do
      $manager.delete_op_view_selected if location == :op_view
      $manager.delete_selected        if location == :glview
    end
    # visible
    items[9].signal_connect("activate") do |w|
      part.visible = w.active?
      $manager.glview.redraw
    end
    # center of gravity
    items[10].signal_connect("activate") do |w|
      w.active? ? part.update_cog : part.cog = nil
      $manager.glview.redraw
    end
    # properties
    items[12].signal_connect("activate") do
      part.display_properties
    end
    items.each{|i| append i }
    show_all
  end
end

class OperatorMenu < Gtk::Menu
  def initialize operator
    super()
    items = [
      Gtk::ImageMenuItem.new(GetText._("Edit operator")).set_image( Gtk::Image.new('../data/icons/small/wheel_small.png') ),
      Gtk::ImageMenuItem.new(GetText._("Edit sketch")).set_image( Gtk::Image.new('../data/icons/small/sketch_small.png') ),
      Gtk::SeparatorMenuItem.new,
      Gtk::CheckMenuItem.new( GetText._("Enabled")),
      Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
    ]
    # edit operators
    items[0].signal_connect("activate") do
      $manager.exit_current_mode
      $manager.operator_mode operator
    end
    # edit sketch
    items[1].signal_connect("activate") do
      sk = operator.settings[:sketch]
      $manager.exit_current_mode
      $manager.sketch_mode sk
    end
    # enable/disable
    items[3].active = operator.enabled
    items[3].signal_connect("activate") do
      $manager.enable_operator operator
    end
    # delete
    items[4].signal_connect("activate") do
      $manager.project.delete_object operator
    end
    items.each{|i| append i }
    show_all
  end
end


class SketchMenu < Gtk::Menu
  def initialize sketch
    super()
    items = [
      Gtk::MenuItem.new( GetText._("Duplicate sketch")),
      Gtk::SeparatorMenuItem.new,
      Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
    ]
    # duplicate
    items[0].signal_connect("activate") do
      $manager.new_sketch sketch
    end
    # delete
    items[2].signal_connect("activate") do
      $manager.delete_op_view_selected
    end
    items.each{|i| append i }
    show_all
  end
end

class SketchToolMenu < Gtk::Menu
  def initialize tool
    super()
    items = [
      Gtk::CheckMenuItem.new( GetText._("Snap to points")),
      Gtk::CheckMenuItem.new( GetText._("Snap to grid")),
      Gtk::CheckMenuItem.new( GetText._("Use guides")),
      Gtk::CheckMenuItem.new( GetText._("Add constraints automatically")),
      Gtk::CheckMenuItem.new( GetText._("Create reference geometry")),
      Gtk::SeparatorMenuItem.new,
      Gtk::ImageMenuItem.new(Gtk::Stock::STOP)
    ]
    items[0].active = $manager.point_snap
    items[1].active = $manager.grid_snap
    items[2].active = $manager.use_sketch_guides
    items[3].active = $manager.use_auto_constrain
    items[4].active = tool.create_reference_geometry
    # snap points
    items[0].signal_connect("activate") do |w|
      $manager.point_snap = w.active?
    end
    # snap grid
    items[1].signal_connect("activate") do |w|
      $manager.grid_snap = w.active?
    end
    # guides
    items[2].signal_connect("activate") do |w|
      $manager.use_sketch_guides = w.active?
    end
    # constraints
    items[3].signal_connect("activate") do |w|
      $manager.use_auto_constrain = w.active?
    end
    # reference
    items[4].signal_connect("activate") do |w|
      tool.create_reference_geometry = w.active?
    end
    # stop
    items[6].signal_connect("activate") do |w|
      $manager.cancel_current_tool
    end
    items.each{|i| append i }
    show_all
  end
end

class SketchSelectionToolMenu < Gtk::Menu
  def initialize
    super()
    items = [
      Gtk::ImageMenuItem.new(GetText._("_Return")).set_image( Gtk::Image.new(Gtk::Stock::UNDO, Gtk::IconSize::MENU) ),
      Gtk::SeparatorMenuItem.new,
      Gtk::ImageMenuItem.new(Gtk::Stock::CUT),
      Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
      Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
      Gtk::ImageMenuItem.new(Gtk::Stock::DELETE),
      Gtk::SeparatorMenuItem.new,
      Gtk::CheckMenuItem.new( GetText._("Snap to points")),
      Gtk::CheckMenuItem.new( GetText._("Snap to grid")),
      Gtk::CheckMenuItem.new( GetText._("Use guides"))
    ]
    items[0].sensitive = ($manager.work_sketch or 
                          $manager.work_operator or 
                          $manager.work_component != $manager.project.main_assembly) ? true : false
    items[2].sensitive = (not $manager.selection.empty?)
    items[3].sensitive = (not $manager.selection.empty?)
    items[4].sensitive = $manager.clipboard ? true : false
    items[5].sensitive = (not $manager.selection.empty?)
    items[7].active = $manager.point_snap
    items[8].active = $manager.grid_snap
    items[9].active = $manager.use_sketch_guides
    # return
    items[0].signal_connect("activate") do |w|
      $manager.working_level_up
    end
    # cut
    items[2].signal_connect("activate") do |w|
      $manager.cut_to_clipboard
    end
    # copy
    items[3].signal_connect("activate") do |w|
      $manager.copy_to_clipboard
    end
    # paste
    items[4].signal_connect("activate") do |w|
      $manager.paste_from_clipboard
    end
    # delete
    items[5].signal_connect("activate") do |w|
      $manager.delete_selected
    end
    # snap points
    items[7].signal_connect("activate") do |w|
      $manager.point_snap = w.active?
    end
    # snap grid
    items[8].signal_connect("activate") do |w|
      $manager.grid_snap = w.active?
    end
    # guides
    items[9].signal_connect("activate") do |w|
      $manager.use_sketch_guides = w.active?
    end
    items.each{|i| append i }
    show_all
  end
end
