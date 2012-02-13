# Define where state machine descriptions will be rendered
def init
  super
  sections.place(:state_machine_details).before(:children)
end

# Renders state machine details in the main content of the class's documentation
def state_machine_details
  erb(:state_machines) if state_machines
end

# Gets a list of state machines prased for this class
def state_machines
  @state_machines ||= begin
    if state_machines = object['state_machines']
      # Load up state_machine so that we can re-use the existing drawing implementation
      require 'tempfile'
      require 'state_machine/core'
      
      # Set up target path
      base_path = File.dirname(serializer.serialized_path(object))
      
      state_machines.each do |name, state_machine|
        image_name = "#{object.name}_#{name}"
        image_path = "#{File.join(base_path, image_name)}.png"
        
        # Generate a machine with the parsed transitions
        c = Class.new { extend StateMachine::MacroMethods }
        machine = c.state_machine(name, :initial => state_machine[:options][:initial]) do
          state_machine[:transitions].each do |transition|
            self.transition(transition)
          end
        end
        
        # Draw to the file and serialize to the doc folder
        file = Tempfile.new(['state_machine', '.png'])
        begin
          if machine.draw(:name => File.basename(file.path, '.png'), :path => File.dirname(file.path), :orientation => 'landscape')
            serializer.serialize(image_path, file.read)
            state_machine[:image] = image_path
          end
        ensure
          # Clean up tempfile
          file.close
          file.unlink
        end
      end
    end
  end
end
