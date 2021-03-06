#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on unknown date.
#  Copyright (c) 2008. All rights reserved.

require 'rubygems'
#require 'ruby-prof'
require 'thread'
require 'ui/main_win.rb'
require 'preferences.rb'
require 'gtk_threadsafe.rb'

GetText.bindtextdomain 'solidmatter'
Thread.abort_on_exception = true

Gtk.init
Gtk::GL.init
win = SolidMatterMainWin.new
$main_win = win
Gtk.main_with_queue 100


# TODO :
# select features groups
# select other half of constraint
# cam animation nich mehr linear
# limit der selektierbaren objekte von 768 auf 16.7M hochschrauben
# operatoren parallelisieren
# drag and drop im op-view
# undo/redo stack
# vererbung von parts
# use gtkuimanager for the menu
# use gtkbuilder instead of libglade
# op_view klappzustand speichern
# direkt die iters manipulieren in server_win damit beim update scrollstand erhalten belibt
# checken ob clean_up von workplane und sketch richtig erfolgt
# sketch button sollte eingedrückt bleiben wenn plane gewählt wird
# sicherheitsprüfungen im server ( is_valid(projectname, client_id) schreiben)
# nicht selektierbare objekte sollten wie der background wirken und bei click die selection aufheben
# shortcuts über accelerators
# when selecting regions, select inner regions first
# automatically apply operator if there is only one unused sketch region
# parts/operators should communicate somehow that they could not be built correctly
# region select von vertikalen planes
# refactor delete_op_view_selected code into delete_object
# schnitte zwischen regions
# click wird nicht richtig registriert in region select tool wenn zu langsam
# unterscheidung von instanzen bei selection unmöglich da beide die selbe displaylist haben
# rebuild selectionpasscolors sollte für alle objekttypen farben erstellen, nur select sollte nach typ unterscheiden
# menu selection should be shown in statusbar
# wennn neues projekt mit part erstellt wird sollte danach auf part gewechselt werden
# start avahi service directly from dbus
# make constraining to COG possible
