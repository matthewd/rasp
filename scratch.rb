
require 'citrus'
Citrus.load 'scratch'
$CITRUS_DEBUG = true
r = VBScript.parse(File.read('t/math.vbs'), :consume => true)

puts r.dump

