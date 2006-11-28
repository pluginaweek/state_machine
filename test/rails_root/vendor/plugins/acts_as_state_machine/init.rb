init_path = "#{RAILS_ROOT}/../../init.rb"
silence_warnings { eval(IO.read(init_path), binding, init_path) }