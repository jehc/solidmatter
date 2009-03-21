#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2009-03-19.
#  Copyright (c) 2008. All rights reserved.

require 'thread'
require 'drb'
require 'preferences.rb'

$preferences[:render_proxy_port] ||= 5000

FakeCompInfo = Struct.new(:volume, :mass, :area, :material, :thumb, :comp_id)

class Service
  NUM_WORKERS = 20
  START_PORT = 4010
  def initialize
    @workers = {}
    @available_ports = (START_PORT...(START_PORT+NUM_WORKERS)).to_a
    @times_loaded = Hash.new 0
    @mutex = Mutex.new
  end
  
  def start
    DRb.start_service( "druby://:#{$preferences[:render_proxy_port]}", self )
  end
  
  def stop
    DRb.stop_service
    nil
  end
  
  # dispatch all requests to the appropriate worker
  def method_missing( meth, *args )
    pr_name, *args = args
    load pr_name
    @workers[pr_name].first.send( meth, *args )
  end
  
private
  def load pr_name
    unless @workers[pr_name]
      # free least used project if neccessary
      if @available_ports.empty?
        @mutex.synchronize do
          least_used = @workers.keys.min_by{|pr| @times_loaded[pr] }
          worker, port = @workers[least_used]
          worker.stop
          @workers.delete least_used
          @available_ports << port
        end
      end
      # spawn new worker process for his project
      @mutex.synchronize do
        p = @available_ports.pop
        puts "loading render server"
        server = IO.popen "ruby sm_render_server.rb #{p}"
        puts server.gets
        puts "loaded render server"
        worker = DRbObject.new_with_uri "druby://localhost:#{p}"
        worker.load pr_name
        @workers[pr_name] = [worker, p]
        @times_loaded[pr_name] += 1
      end
    end
  end
end

Service.new.start
puts "Render proxy is listening..."
DRb.thread.join
