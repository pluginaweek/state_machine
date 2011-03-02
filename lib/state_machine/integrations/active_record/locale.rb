filename = "#{File.dirname(__FILE__)}/../active_model/locale.rb"
translations = eval(IO.read(filename), binding, filename)
translations[:en][:activerecord] = translations[:en].delete(:activemodel)

# Only i18n 0.4.0+ has the new %{key} syntax
if !defined?(I18n::VERSION) || I18n::VERSION < '0.4.0'
  translations[:en][:activerecord][:errors][:messages].each do |key, message|
    message.gsub!('%{', '{{')
    message.gsub!('}', '}}')
  end
end

translations
