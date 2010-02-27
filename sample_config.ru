$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'rack'

sessioned = MobileSession.new App
run sessioned
