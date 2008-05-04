module Factory
  # Build actions for the class
  def self.build(klass, &block)
    name = klass.to_s.underscore
    define_method("#{name}_attributes", block)
    
    module_eval <<-end_eval
      def valid_#{name}_attributes(attributes = {})
        #{name}_attributes(attributes)
        attributes
      end
      
      def new_#{name}(attributes = {})
        #{klass}.new(valid_#{name}_attributes(attributes))
      end
      
      def create_#{name}(*args)
        record = new_#{name}(*args)
        record.save!
        record.reload
        record
      end
    end_eval
  end
  
  build AutoShop do |attributes|
    attributes.reverse_merge!(
      :name => "Joe's Auto Body",
      :num_customers => 0
    )
  end
  
  build Car do |attributes|
    attributes[:highway] = create_highway unless attributes.include?(:highway)
    attributes[:auto_shop] = create_auto_shop unless attributes.include?(:auto_shop)
    attributes.reverse_merge!(
      :seatbelt_on => false,
      :insurance_premium => 50
    )
  end
  
  build Highway do |attributes|
    attributes.reverse_merge!(
      :name => 'Route 66'
    )
  end
  
  build Motorcycle do |attributes|
    valid_car_attributes(attributes)
  end
  
  build Switch do |attributes|
    attributes.reverse_merge!(
      :state => 'off'
    )
  end
  
  build Vehicle do |attributes|
    valid_car_attributes(attributes)
  end
end
