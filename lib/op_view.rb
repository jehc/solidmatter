#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'operators.rb'
require 'pop_ups.rb'

def icon_for_op( op )
  case op.class
    when ExtrudeOperator then '../data/icons/extrude.png'
    else nil
  end
end

class OpView < Gtk::ScrolledWindow
  attr_accessor :manager, :base_component
  def initialize
    super
    @base_component = nil
    self.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
    # set up view
    pix = Gtk::CellRendererPixbuf.new
    text = Gtk::CellRendererText.new
    @column = Gtk::TreeViewColumn.new(GetText._('Operators'))
    @column.reorderable = true
    @column.pack_start(pix,false)
    @column.set_cell_data_func(pix) do |column, cell, model, iter|
      cell.pixbuf = iter.get_value(0)
    end
    @column.pack_start(text, true)
    @column.set_cell_data_func(text) do |column, cell, model, iter|
      cell.markup = iter.get_value(1)
    end
    @tv = Gtk::TreeView.new
    @tv.reorderable = true
    #@tv.hover_selection = true
    @tv.append_column( @column )
    @tv.set_size_request(100,0)
    self.add( @tv )
    # define pop-up menus
    @tv.signal_connect("button_press_event") do |widget, event|
      # right click
      if event.button == 3 
        path = @tv.get_path_at_pos(event.x, event.y)
        sel = path2component path.first
        if self.selections.include? sel
          sel = self.selections.first 
        else
          @tv.set_cursor( path.first, nil, false )
        end
        menu = case sel
        when Operator
          OperatorMenu.new sel
        when Instance
          ComponentMenu.new sel, :op_view
        when Sketch
          SketchMenu.new sel
        end
        menu.popup(nil, nil, event.button, event.time) if menu
      end
    end
    @tv.signal_connect('row_activated') do 
      sel = self.selections[0]
      $manager.exit_current_mode
      if sel.is_a? Sketch
        $manager.sketch_mode sel 
      elsif sel.is_a? Operator
        $manager.operator_mode sel
      else
        $manager.change_working_level sel 
      end
    end
    @tv.signal_connect("motion_notify_event") do |widget, e|
      unless Gtk::events_pending?
        path = @tv.get_path_at_pos(e.x, e.y)
        if path
          comp = path2component path.first
          draw_highlighted comp unless comp.is_a? Operator or comp.is_a? Sketch
        else
          $manager.glview.redraw
        end
      end
    end
    @tv.signal_connect("cursor_changed") do |w|
      sel = self.selections.first 
      $manager.select sel
      draw_highlighted sel
    end
  end
  
  def draw_highlighted comp
    return unless comp
    $manager.glview.immediate_draw_routines << lambda do
      GL.Color4f( 0.9, 0.2, 0, 0.5 )
      GL.Disable(GL::POLYGON_OFFSET_FILL)
      parts = (comp.class == Assembly) ? comp.contained_parts : [comp]
      for list in parts.map{|p| p.displaylist }
        GL.CallList list
      end
      GL.Enable(GL::POLYGON_OFFSET_FILL)
    end
    $manager.glview.redraw
    $manager.glview.immediate_draw_routines.pop
  end
  
  def select comp
    path = ""
    while comp
      path = comp.parent.components.index(comp).to_s + ":" + path
      break if comp.parent == @base_component
      comp = comp.parent
    end
    path = "0:" + path
    path.chop!
    path = Gtk::TreePath.new path
    @tv.set_cursor( path, nil, false )
  end
  
  def selections
    sels = []
    @tv.selection.selected_each do |model, path, iter|
      # dive down hierarchy to real selection
      sels.push( path2component path )
    end
    return sels
  end
  
  def path2component path
    comps = [@base_component]
    sel = nil
    path.indices.each do |i|
      sel = comps[i]
      comps = sel.components if sel.class == Assembly
      comps = (sel.operators + sel.unused_sketches) if sel.class == Part
      comps = [sel.settings[:sketch]] if sel.is_a? Operator and sel.settings[:sketch]
    end
    sel
  end

  def update
    if @base_component
      if @base_component.class == Part
        @column.title = GetText._('Operators')
        model = Gtk::TreeStore.new(Gdk::Pixbuf, String)
        base_iter = model.append(nil)
        base_iter[0] = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
        base_iter[1] = @base_component.information[:name]
        @base_component.operators.each do |op|
          op_iter = model.append( base_iter )
          op_iter[0] = Gtk::Image.new('../data/icons/small/wheel_small.png').pixbuf
          op_iter[1] = op.name
          sketch = op.settings[:sketch]
          if sketch
            sketch_iter = model.append op_iter
            sketch_iter[0] = Gtk::Image.new('../data/icons/small/sketch_small.png').pixbuf
            sketch_iter[1] = sketch.name
          end
        # sketch_iter[0] = render_icon(Gtk::Stock::NEW, Gtk::IconSize::MENU, "icon1")
        end
        @base_component.unused_sketches.each do |sketch|
          sketch_iter = model.append( base_iter )
          sketch_iter[0] = Gtk::Image.new('../data/icons/small/sketch_small.png').pixbuf
          sketch_iter[1] = sketch.name
        end
        @tv.model = model
        @tv.expand_all
      elsif @base_component.class == Assembly
        # recursively visualize assemblies
        @column.title = 'Parts'
        model = Gtk::TreeStore.new(Gdk::Pixbuf, String)
        base_iter = model.append(nil)
        base_iter[0] = Gtk::Image.new('../data/icons/small/assembly_small.png').pixbuf
        base_iter[1] = @base_component.information[:name]
        recurse_visualize( model, base_iter, @base_component.components )
        @tv.model = model
        @tv.expand_all
      end
    end
  end
  
  def recurse_visualize( model, base_iter, comps )
    comps.each do |comp|
      iter = model.append( base_iter )
      if comp.class == Assembly
        iter[0] = Gtk::Image.new('../data/icons/small/assembly_small.png').pixbuf
        iter[1] = comp.information[:name]
        recurse_visualize( model, iter, comp.components )
      else
        iter[0] = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
        iter[1] = comp.information[:name]
      end
    end
  end
  
  def set_base_component( comp )
    @base_component = comp
    update
  end
end












