#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'gtk2'
require 'image.rb'

class FileOpenDialog < Gtk::FileChooserDialog
  def initialize mode=:open
    title = case mode
      when :save   : GetText._("Save project as..")
      when :open   : GetText._("Choose project file")
      else
        GetText._("Export as...")
    end
    super( title,  nil,
           mode == :open ? Gtk::FileChooser::ACTION_OPEN : Gtk::FileChooser::ACTION_SAVE,
           nil,
           [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
           [mode == :open ? Gtk::Stock::OPEN : Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT] )
    set_property('do-overwrite-confirmation', true) 
    self.current_folder = $preferences[:project_dir]
    # add solid|matter file filter
    if mode == :save or mode == :open
      filter = Gtk::FileFilter.new
      filter.name = GetText._("Solid|matter project")
      filter.add_pattern "*.smp"
      add_filter filter
    else
      # add export-format specific file filter
      mode = [mode] unless mode.is_a? Array
      for m in mode
        filter = Gtk::FileFilter.new
        filter.name = GetText._("#{m} files")
        filter.add_pattern "*#{m}"
        add_filter filter
      end
    end
    # add default filter
    filter = Gtk::FileFilter.new
    filter.name = GetText._("All filetypes")
    filter.add_pattern "*"
    add_filter filter
    # add preview widget
    signal_connect("update-preview") do
      filename = self.preview_filename
      begin
        image = nil
        File::open( filename ) do |file|
          scene = Marshal::restore file 
          image = scene[0]
        end
        gtkim = native2gtk image
        self.preview_widget = gtkim
        self.preview_widget_active = true
      rescue
        self.preview_widget_active = false
      end
    end
  end
end

  
