#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-02-06.
#  Copyright (c) 2008. All rights reserved.

require 'libglade2'
require 'multi_user.rb'

class AccountEditor
  def initialize account
    @account = account
    @glade = GladeXML.new( "../data/glade/account_editor.glade", nil, 'solidmatter' ) {|handler| method(handler)}
    @glade['login_entry'].text    = @account.login 
    @glade['password_entry'].text = @account.password
    # ------- create server view ------- #
    pix = Gtk::CellRendererPixbuf.new
		text = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new GetText._('Projects on server')
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@sview = @glade['server_view']
		@sview.append_column( column )
		# ------- create user view ------- #
		column = Gtk::TreeViewColumn.new GetText._("User's projects")
		column.pack_start(pix,false)
		column.set_cell_data_func(pix) do |col, cell, model, iter|
			cell.pixbuf = iter.get_value(0)
		end
		column.pack_start(text, true)
		column.set_cell_data_func(text) do |col, cell, model, iter|
			cell.markup = iter.get_value(1)
		end
		@uview = @glade['user_view']
		@uview.append_column column 
		@sview.selection.mode = Gtk::SELECTION_MULTIPLE
		@uview.selection.mode = Gtk::SELECTION_MULTIPLE
		@callback = Proc.new if block_given?
		update
  end
  
  def ok_handle
    @account.login    = @glade['login_entry'].text
    @account.password = @glade['password_entry'].text
    @callback.call
    @glade['account_editor'].destroy
  end
  
  def move_to_user
    selected_server_project_ids.each{|id| @account.project_ids.push id }
    update
  end
  
  def remove_from_user
    selected_user_project_ids.each{|id| @account.project_ids.delete id }
    update
  end
  
  def selected_server_project_ids
    sel = []
    @sview.selection.selected_each do |model, path, iter|
      sel.push( (@account.server.projects.map{|p| p.project_id } - @account.project_ids)[path.indices[0]] )
    end
    return sel
  end
  
  def selected_user_project_ids
    sel = []
    @uview.selection.selected_each do |model, path, iter|
      sel.push( @account.project_ids[path.indices[0]] )
    end
    return sel
  end
  
  def update
    all_projects = @account.server.projects
    server_projects = all_projects.reject{|p| @account.project_ids.include? p.project_id }
    # projects view
    model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    im = Gtk::Image.new('../data/icons/middle/user-home_middle.png').pixbuf
    for project in server_projects
		  iter = model.append
  		iter[0] = im
  		iter[1] = project.name
		end
		@sview.model = model
		# users view
		model = Gtk::ListStore.new(Gdk::Pixbuf, String)
    for project in @account.project_ids.map{|id| all_projects.select{|p| p.project_id == id }.first }
		  iter = model.append
  		iter[0] = im
  		iter[1] = project.name
		end
		@uview.model = model
  end
end
