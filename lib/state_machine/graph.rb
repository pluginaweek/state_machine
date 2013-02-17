begin
  require 'rubygems'
  gem 'ruby-graphviz', '>=0.9.17'
  require 'graphviz'
rescue LoadError => ex
  $stderr.puts "Cannot draw the machine (#{ex.message}). `gem install ruby-graphviz` >= v0.9.17 and try again."
  raise
end

require 'state_machine/assertions'

module StateMachine
  # Provides a set of higher-order features on top of the raw GraphViz graphs
  class Graph < GraphViz
    include Assertions
    
    # The name of the font to draw state names in
    attr_reader :font
    
    # The graph's full filename
    attr_reader :file_path
    
    # The image format to generate the graph in
    attr_reader :file_format
    
    # Creates a new graph with the given name.
    # 
    # Configuration options:
    # * <tt>:path</tt> - The path to write the graph file to.  Default is the
    #   current directory (".").
    # * <tt>:format</tt> - The image format to generate the graph in.
    #   Default is "png'.
    # * <tt>:font</tt> - The name of the font to draw state names in.
    #   Default is "Arial".
    # * <tt>:orientation</tt> - The direction of the graph ("portrait" or
    #   "landscape").  Default is "portrait".
    def initialize(name, options = {})
      options = {:path => '.', :format => 'png', :font => 'Arial', :orientation => 'portrait'}.merge(options)
      assert_valid_keys(options, :path, :format, :font, :orientation)
      
      @font = options[:font]
      @file_path = File.join(options[:path], "#{name}.#{options[:format]}")
      @file_format = options[:format]
      
      super('G', :rankdir => options[:orientation] == 'landscape' ? 'LR' : 'TB')
    end
    
    # Generates the actual image file based on the nodes / edges added to the
    # graph.  The path to the file is based on the configuration options for
    # this graph.
    def output
      super(@file_format => @file_path)
    end
    
    # Adds a new node to the graph.  The font for the node will be automatically
    # set based on the graph configuration.  The generated node will be returned.
    # 
    # For example,
    # 
    #   graph = StateMachine::Graph.new('test')
    #   graph.add_nodes('parked', :label => 'Parked', :width => '1', :height => '1', :shape => 'ellipse')
    def add_nodes(*args)
      node = v0_api? ? add_node(*args) : super
      node.fontname = @font
      node
    end
    
    # Adds a new edge to the graph.  The font for the edge will be automatically
    # set based on the graph configuration.  The generated edge will be returned.
    # 
    # For example,
    # 
    #   graph = StateMachine::Graph.new('test')
    #   graph.add_edges('parked', 'idling', :label => 'ignite')
    def add_edges(*args)
      edge = v0_api? ? add_edge(*args) : super
      edge.fontname = @font
      edge
    end
    
    private
    # Determines whether the old v0 api is in use
    def v0_api?
      version[0] == '0' || version[0] == '1' && version[1] == '0' && version[2] <= '2'
    end
    
    # The ruby-graphviz version data
    def version
      Constants::RGV_VERSION.split('.')
    end
  end
end
