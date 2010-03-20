filename = "#{File.dirname(__FILE__)}/../active_model/locale.rb"
translations = eval(IO.read(filename), binding, filename)
translations[:en][:activerecord] = translations[:en].delete(:activemodel)
translations
