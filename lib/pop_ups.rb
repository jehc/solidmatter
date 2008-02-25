#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2007-12-26.
#  Copyright (c) 2007. All rights reserved.

class ComponentMenu < Gtk::Menu
  def initialize( manager, part )
    super()
    items = [
			Gtk::MenuItem.new("Duplicate instance"),
			Gtk::MenuItem.new("Duplicate original"),
			Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
			Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE),
			Gtk::SeparatorMenuItem.new,
			Gtk::CheckMenuItem.new("Visible"),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::PROPERTIES)
		]
		# duplicate instance
		items[0].signal_connect("activate") do
      @manager.duplicate_instance
		end
		# duplicate original
		items[1].signal_connect("activate") do
      # dupli orig
		end
		# copy
		items[2].signal_connect("activate") do
			manager.copy_to_clipboard
		end
		# paste
		items[3].signal_connect("activate") do
			manager.paste_from_clipboard
		end
		# delete
		items[4].signal_connect("activate") do
			manager.delete_op_view_selected
		end
		# visible
		items[6].signal_connect("activate") do
      part.visible = items[6].active?
      manager.glview.redraw
		end
		# properties
		items[8].signal_connect("activate") do
			part.display_properties
		end
		items[6].active = part.visible
		items.each{|i| append i }
		show_all
  end
end

class OperatorMenu < Gtk::Menu
  def initialize( manager, operator )
    super()
    items = [
			Gtk::CheckMenuItem.new("Enabled"),
			Gtk::SeparatorMenuItem.new,
			Gtk::MenuItem.new("Edit dimensions"),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
		]
		# enable/disable
		items[0].signal_connect("activate") do
      manager.enable_selected_operator
		end
		# edit dimensions
		items[2].signal_connect("activate") do
		  
		end
		# delete
		items[3].signal_connect("activate") do
      manager.delete_op_view_selected
		end
		items[0].active = operator.enabled
		items.each{|i| append i }
		show_all
  end
end

class SketchToolMenu < Gtk::Menu
  def initialize( manager, tool )
    super()
    items = [
			Gtk::CheckMenuItem.new("Snap to points"),
			Gtk::CheckMenuItem.new("Snap to grid"),
			Gtk::CheckMenuItem.new("Use guides"),
			Gtk::CheckMenuItem.new("Create reference geometry"),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::STOP)
		]
		# snap points
		items[0].signal_connect("activate") do |w|
      manager.point_snap = w.active?
		end
		# snap grid
		items[1].signal_connect("activate") do |w|
      manager.grid_snap = w.active?
		end
		# guides
		items[2].signal_connect("activate") do |w|
			manager.use_sketch_guides = w.active?
		end
		# reference
		items[3].signal_connect("activate") do |w|
			tool.create_reference_geometry = w.active?
		end
		# stop
		items[5].signal_connect("activate") do |w|
      manager.cancel_current_tool
		end
		items[0].active = manager.point_snap
		items[1].active = manager.grid_snap
		items[2].active = manager.use_sketch_guides
		items[3].active = tool.create_reference_geometry
		items.each{|i| append i }
		show_all
  end
end

class SketchSelectionToolMenu < Gtk::Menu
  def initialize manager
    super()
    items = [
			Gtk::CheckMenuItem.new("Snap to points"),
			Gtk::CheckMenuItem.new("Snap to grid"),
			Gtk::CheckMenuItem.new("Use guides"),
			Gtk::SeparatorMenuItem.new,
			Gtk::ImageMenuItem.new(Gtk::Stock::COPY),
			Gtk::ImageMenuItem.new(Gtk::Stock::PASTE),
			Gtk::ImageMenuItem.new(Gtk::Stock::DELETE)
		]
		# snap points
		items[0].signal_connect("activate") do |w|
      manager.point_snap = w.active?
		end
		# snap grid
		items[1].signal_connect("activate") do |w|
      manager.grid_snap = w.active?
		end
		# guides
		items[2].signal_connect("activate") do |w|
			manager.use_sketch_guides = w.active?
		end
		# copy
		items[4].signal_connect("activate") do |w|
      manager.copy_to_clipboard
		end
		# paste
		items[5].signal_connect("activate") do |w|
      manager.paste_from_clipboard
		end
		# delete
		items[6].signal_connect("activate") do |w|
      manager.delete_selected
		end
		items[0].active = manager.point_snap
		items[1].active = manager.grid_snap
		items[2].active = manager.use_sketch_guides
		items.each{|i| append i }
		show_all
  end
end