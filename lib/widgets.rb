#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gnome2'
require "units.rb"

class SearchEntry < Gtk::ToolItem 
  def initialize
    super()
    no_show_all = true
    @icon = Gtk::Image.new( Gtk::Stock::FIND, Gtk::IconSize::SMALL_TOOLBAR )
    @entry = Gtk::ComboBoxEntry.new
    @label = Gtk::Label.new GetText._("Search") 
    entry_box = Gtk::HBox.new false
    entry_box.pack_start( @icon, false, false, 6 )
    entry_box.pack_start( @entry, false )
    vbox = Gtk::VBox.new false
    vbox.pack_start( entry_box, false, false, 3 )
    #vbox.pack_start( @label)
    add vbox
    set_mode
    @entry.signal_connect("changed"){|w| select_matching_objects( w.active_text ) }
    signal_connect("toolbar-reconfigured"){|w| set_mode }
  end
  
  def set_mode
    if [Gtk::Toolbar::BOTH_HORIZ, Gtk::Toolbar::ICONS, Gtk::Toolbar::TEXT].any?{|style| style == toolbar_style }
      @label.hide
    else
      @label.show
    end
  end
  
  def select_matching_objects( str )
    str.downcase!
    if $manager.work_component.class == Assembly
      $manager.selection.deselect_all
      unless str.empty?
        comps_to_check = [$manager.work_component]
        while not comps_to_check.empty?
          new_comps = []
          comps_to_check.each do |c|
            $manager.selection.add c if c.information[:name].downcase.include? str
            new_comps += c.components if c.class == Assembly
          end
          comps_to_check = new_comps
        end
      end
      $manager.glview.zoom_selection
      $manager.glview.redraw
    end
  end
end


#class ShadingButton < Gtk::MenuToolButton
#  def initialize
#    icon = Gtk::Image.new( '../data/icons/middle/shaded.png' )
#    super( icon, GetText._('Shading') )
#    menu = Gtk::Menu.new
#    items = [
#      Gtk::ImageMenuItem.new( GetText._("Shaded") ).set_image(      Gtk::Image.new('../data/icons/small/shaded.png') ),
#      Gtk::ImageMenuItem.new( GetText._("Overlay") ).set_image(     Gtk::Image.new('../data/icons/small/overlay.png') ),
#      Gtk::ImageMenuItem.new( GetText._("Wireframe") ).set_image(   Gtk::Image.new('../data/icons/small/wireframe.png') ),
#      Gtk::ImageMenuItem.new( GetText._("Hidden Lines") ).set_image(Gtk::Image.new('../data/icons/small/hidden_lines.png') )
#    ]
#    items[0].signal_connect("activate") do
#      @previous = $manager.glview.displaymode
#      $manager.glview.set_displaymode :shaded
#      icon.file = '../data/icons/middle/shaded.png'
#    end
#    items[1].signal_connect("activate") do
#      @previous = $manager.glview.displaymode
#      $manager.glview.set_displaymode :overlay
#      icon.file = '../data/icons/middle/overlay.png'
#    end
#    items[2].signal_connect("activate") do
#      @previous = $manager.glview.displaymode
#      $manager.glview.set_displaymode :wireframe
#      icon.file = '../data/icons/middle/wireframe.png'
#    end
#    items[3].signal_connect("activate") do
#      @previous = $manager.glview.displaymode
#      $manager.glview.set_displaymode :hidden_lines
#      icon.file = '../data/icons/middle/hidden_lines.png'
#    end
#    items.each{|i| menu.append i }
#    menu.show_all
#    self.menu = menu
#    signal_connect("clicked") do
#      prev = $manager.glview.displaymode
#      $manager.glview.set_displaymode @previous
#      icon.file = "../data/icons/middle/#{@previous.to_s}.png"
#      @previous = prev
#    end
#    @previous = :wireframe
#  end
#end


class MultiToolButton < Gtk::MenuToolButton
  def initialize( name, icon, items, main_callback, item_callback )
    @icon = Gtk::Image.new icon
    super( @icon, GetText._(name) )
    menu = Gtk::Menu.new
    items.each do |name, handle, ic|
      item = Gtk::ImageMenuItem.new( GetText._(name) ).set_image( Gtk::Image.new(ic) )
      item.signal_connect("activate"){ item_callback.call handle }
      @icon.file = ic.gsub('small', 'middle')
      menu.append item
    end
    menu.show_all
    self.menu = menu
    signal_connect("clicked"){ main_callback.call }
  end
end

class ShadingButton < MultiToolButton
  def initialize
    items = [
      ["Shaded",       :shaded,       '../data/icons/small/shaded.png'      ],
      ["Overlay",      :overlay,      '../data/icons/small/overlay.png'     ],
      ["Wireframe",    :wireframe,    '../data/icons/small/wireframe.png'   ],
      ["Hidden Lines", :hidden_lines, '../data/icons/small/hidden_lines.png']
    ]
    main_callback = lambda do
      prev = $manager.glview.displaymode
      $manager.glview.set_displaymode @previous
      @icon.file = "../data/icons/middle/#{@previous.to_s}.png"
      @previous = prev
    end
    @previous = :wireframe
    item_callback = lambda do |handle|
      @previous = $manager.glview.displaymode
      $manager.glview.set_displaymode handle
    end
    super( 'Shading', items.first[2], items, main_callback, item_callback )
  end
end


class SelectionToolsButton < MultiToolButton
  def initialize
    items = [
      ["Select components", :select,          '../data/icons/small/list-add_small.png'],
      ["Select operators",  :operator_select, '../data/icons/middle/list-add_small.png'],
      ["Tweak geometry",    :tweak,           '../data/icons/middle/list-add_small.png']
    ]
    item_callback = lambda do |handle|
      $manager.activate_tool handle.to_s
    end
    super( 'Shading', items.first[2], items, lambda{ }, item_callback )
  end
end


class FloatingWidget < Gtk::Window
  def initialize( x,y, *args, &b )
    super()
    # set style
    #self.modal = true
    self.transient_for = $manager.main_win
    self.keep_above = true
    self.decorated = false
    self.skip_taskbar_hint = true
    self.skip_pager_hint = true
    destroy or return unless setup_ui *args, &b
    # position right next to cursor
    x,y = convert2screen( x,y )
    move( x,y )
    show_all
    # we position again after showing, as the window manager may ignore the first call
    move( x,y )
  end
  
  # convert glview to screen coords
  def convert2screen( x,y )
    win = $manager.main_win
    glv = $manager.glview
    x_offset = win.allocation.width - glv.allocation.width
    y_offset = win.allocation.height - glv.parent.allocation.height
    return $manager.main_win.position.first + x + x_offset, $manager.main_win.position.last + y + y_offset
  end
  
  def setup_ui
    raise "ERROR: Widget cannot draw itself"
  end
end


class MeasureEntry < Gtk::VBox
  include Units
  def initialize( label=nil, convert_units=true, max_value=20 )
    super false
    @convert_units = convert_units
    @entry = Gtk::SpinButton.new( 0, max_value, 0.05 )
    @entry.update_policy = Gtk::SpinButton::UPDATE_IF_VALID
    @entry.activates_default = true
    @btn = Gtk::Button.new
    @btn.image = Gtk::Image.new('../data/icons/small/preferences-system_small.png')
    @btn.relief = Gtk::RELIEF_NONE
    @entry.set_size_request( 60, -1 )
    @btn.set_size_request( 30, 30 )
    hbox = Gtk::HBox.new
    add hbox
    hbox.add @entry
    hbox.add @btn
    if label
      @label = Gtk::Label.new label
      add @label
    end
    # create popup menu
    menu = Gtk::Menu.new
    [Gtk::MenuItem.new(GetText._("Measure value")),
     Gtk::MenuItem.new(GetText._("Bind to measured value"))
    ].each{|i| menu.append(i)}
    menu.show_all
    @btn.signal_connect("button_press_event"){|w,e| menu.popup(nil, nil, 3, e.time)}
  end
  
  def value
   @convert_units ? ununit(@entry.value) : @entry.value
  end
  
  def value=( val )
   @entry.value = (@convert_units ? enunit( val, false ) : val)
  end
  
  def on_change_value
   @entry.signal_connect('value_changed'){|w| yield value }
  end
end


class FloatingEntry < FloatingWidget
  def setup_ui value
    main_box = Gtk::HBox.new false
    add main_box
    
    entry = MeasureEntry.new
    entry.value = value
    main_box.add entry
    
    ok_btn = Gtk::Button.new 
    ok_btn.image = Gtk::Image.new(Gtk::Stock::APPLY, Gtk::IconSize::MENU)
    ok_btn.relief = Gtk::RELIEF_NONE
    main_box.add ok_btn
    
    cancel_btn = Gtk::Button.new
    cancel_btn.image = Gtk::Image.new(Gtk::Stock::CLOSE, Gtk::IconSize::MENU)
    cancel_btn.relief = Gtk::RELIEF_NONE
    main_box.add cancel_btn
    
    # set ok button to react to pressing enter
    ok_btn.can_default = true
    ok_btn.has_default = true
    self.default = ok_btn
    # connect actions
    ok_btn.signal_connect('clicked'){ yield entry.value, :ok if block_given? ; destroy }
    cancel_btn.signal_connect('clicked'){ yield value, :cancel ; destroy }
    entry.on_change_value{ yield entry.value, :changed if block_given? }
    true
  end
end


class SketchConstraintChooser < FloatingWidget
  def setup_ui segments, &b
    main_box = Gtk::HBox.new false
    s1, s2 = segments[0], segments[1]
    show_widget = false
    if (s1.is_a? Line and not s2) or [s1,s2].all?{|s| s.is_a? Vector }
      add_button :horizontal, main_box, &b
      add_button :vertical, main_box, &b
      show_widget = true
    end
    if [s1,s2].all?{|s| s.is_a? Line }
      add_button :equal, main_box, &b
      add_button :parallel, main_box, &b
      show_widget = true
    end
    if  [s1,s2].all?{|s| s.is_a? Arc2D }
      add_button :equal, main_box, &b
      show_widget = true
    end
    add main_box
    show_widget
  end
  
  def add_button name, box
    btn = Gtk::Button.new 
    btn.image = Gtk::Image.new("../data/icons/small/#{name}.png")
    btn.signal_connect('clicked'){ yield name }
    btn.tooltip_text = name.to_s.capitalize
    box.add btn
  end
end


class SelectionView < Gtk::TreeView
  def initialize title
    super()
    @items = {}
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		self.append_column( column )
		self.selection.mode = Gtk::SELECTION_MULTIPLE
		self.modify_base(Gtk::STATE_NORMAL, Gdk::Color::parse("#FFFF00"))
		update
  end
  
  def add_item( item, name )
    @items[name] = item
  end
  
  def remove_item item
    @items.delete_if{|k,v| v == item }
  end
  
  def selected_items
    sel = []
    self.selection.selected_each do |model, path, iter|
      sel.push( @items[iter[0]] )
    end
    return sel
  end

  def update
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/small/part_small.png').pixbuf
    for name, item in @items
		  iter = model.append
  		iter[0] = im
  		iter[1] = name
		end
		self.model = model
  end
end


class RegionButton < Gtk::ToggleToolButton
  def initialize op
    super()
    self.icon_widget = Gtk::Image.new('../data/icons/middle/sketch_middle.png').show
    self.label = GetText._("Sketch")
    self.signal_connect("clicked") do |b| 
      if self.active?
        $manager.activate_tool("region_select", true) do |loops|
          unless loops.empty?
            op.settings[:loops] = loops
            sketch = loops.first.first.sketch
            if op.settings[:sketch]
              op.part.unused_sketches.push op.settings[:sketch]
              op.settings[:sketch].op = nil
            end
            op.settings[:sketch] = sketch
            sketch.op = op
            op.part.unused_sketches.delete sketch
            $manager.op_view.update
            op.show_changes
          end
          self.active = false
        end
        $manager.current_tool.selection = op.settings[:loops] || []
        $manager.glview.redraw
      else
        $manager.cancel_current_tool
      end
    end
  end
end
