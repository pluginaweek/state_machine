filename = "#{File.dirname(__FILE__)}/../active_model/locale.rb"
translations = eval(IO.read(filename), binding, filename)
translations[:en][:activerecord] = translations[:en].delete(:activemodel)

if ::ActiveRecord::VERSION::MAJOR < 3
  translations[:en][:activerecord][:errors][:messages].each do |key, message|
    message.gsub!('%{', '{{')
    message.gsub!('}', '}}')
  end
end

translations
