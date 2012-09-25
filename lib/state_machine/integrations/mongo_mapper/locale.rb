filename = "#{File.dirname(__FILE__)}/../active_model/locale.rb"
translations = eval(IO.read(File.expand_path(filename)), binding, filename)
translations[:en][:mongo_mapper] = translations[:en].delete(:activemodel)
translations
