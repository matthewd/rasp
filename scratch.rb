require 'rasp/parser'
r = VBScript.parse(File.read('t/math.vbs'), :consume => true)

puts r.dump
