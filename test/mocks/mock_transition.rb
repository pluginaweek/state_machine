class MockTransition
  attr_accessor :from_name,
                :to_name
  
  def initialize(from_name, to_name, perform)
    @from_name, @to_name, @perform = from_name.to_sym, to_name.to_sym, perform
  end
  
  def perform(record, args)
    if @perform
      record.state_name = @to_name
    end
    
    @perform
  end
end