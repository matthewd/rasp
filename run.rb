
require 'convertor'
require 'parser'
require 'rasp'
require 'vbscript.tab'

require 'parsedate'
#require 'win32ole'
require 'pathname'

filename = ARGV[0] || 'samples/test2.vbs'

Root = Rasp::Context.new

class AspNativeObject
	def run context; self; end
end
class Err < AspNativeObject
	attr_accessor :number
	attr_accessor :description
	def clear
		self.number = 0
		self.description = ''
	end
	def load_from_ruby_exception error
		self.number = error.number
		self.description = error.description
	end
end
class WScript < AspNativeObject
	def echo string
		puts string
	end
end
class Object
	def asp_default *a
		self[*a]
	end
	def asp_default= *a
		self.[]=(*a)
	end
end

class AspSession < AspNativeObject
	def initialize; @data = {}; end
	def asp_default= key, value
		@data[key] = value
	end
	def asp_default key; @data.key?(key) ? @data[key] : Empty.get; end
end
class AspRequest < AspNativeObject
end
class AspResponse < AspNativeObject
	def write string
		print string
	end
end
class AspServer < AspNativeObject
	#def create_object name
	#	WIN32OLE.new name
	#end
end
class AspNil
	def run; self; end
	def nil?; true; end
end
class Empty < AspNil
	def simple; self; end
	def to_int; 0; end
	alias :to_i :to_int
	def to_str; ''; end
	alias :to_s :to_str
	def self.handle_as_zero( *sym )
		sym.each do |s|
			define_method( s ) { |*a| to_int.__send__( s, *a ) }
		end
	end
	handle_as_zero :+, :-, :*, :/, :&, :|, :^, :%, :<, :>, :<=, :>=
	def self.get; @@instance; end
	@@instance = self.new
end
class Null < Empty
	def self.get; @@instance; end
	@@instance = self.new
end
class Nothing < AspNil
	def self.get; @@instance; end
	@@instance = self.new
end

# Common constants
Root['vbCrLf'] = "\r\n"
Root['vbCr'] = "\r"
Root['vbLf'] = "\n"
Root['vbNewline'] = "\r\n"
Root['Empty'] = Empty.get
Root['Null'] = Null.get
Root['Nothing'] = Nothing.get
Root['True'] = true
Root['False'] = false
Root['Err'] = Err.new

# ASP
Root['Response'] = AspResponse.new
Root['Request'] = AspRequest.new
Root['Server'] = AspServer.new
Root['Session'] = AspSession.new

# WSH
Root['WScript'] = WScript.new

Root.define_native_method( 'Rnd' ) { || rand }
Root.define_native_method( 'CLng' ) { |v| v.to_i }
Root.define_native_method( 'CStr' ) { |v| v.to_s }
Root.define_native_method( 'CDbl' ) { |v| v.to_f }
Root.define_native_method( 'CBool' ) { |v| v.to_b }
Root.define_native_method( 'CDate' ) { |v| Time.local( *ParseDate.parsedate( v ) ) }

Root.define_native_method( 'IsEmpty' ) { |v| v.is_a? Empty }
Root.define_native_method( 'IsNull' ) { |v| v.is_a? Null }

#Root.define_native_method( 'CreateObject' ) { |v| WIN32OLE.new( v ) }

Root.all_constant!

convertor = Syntax::Convertors::CodeTree.for_syntax 'vbscript'
convertor.follow_includes = true
convertor.follow_includes = false ## XXX
convertor.virtual_root = Pathname.new( filename ).parent
#convertor.type = :asp
proper_filename = File.expand_path(filename).gsub('/', '\\')
proper_filename = File.expand_path(filename) unless File.exists?( proper_filename )
ast = nil
if File.exists?( filename + 'c' ) && false
	data = nil
	File.open( filename + 'c', 'r' ) do |file|
		file.binmode
		data = file.gets( nil )
	end
	ast = Marshal.load( data )
end
begin
	if ast.nil?
		ast = convertor.convert(File.read(filename), proper_filename)
		File.open( filename + 'c', 'w' ) do |out|
			out.binmode
			out.write Marshal.dump( ast )
		end
	end
rescue Rasp::ScriptError => error
	puts "#{error.location}Microsoft VBScript compilation error: #{error.description}"
else
	#require 'pp'; pp ast; exit ## XXX
	begin
		context = Rasp::Context.new(:parent_context => Root)
		ast.compile context
	rescue Rasp::ScriptError => error
		puts "#{error.location}Microsoft VBScript compilation error: #{error.description}"
	else
		begin
			ast.run context
		rescue Rasp::ScriptError => error
			puts "#{error.location}Microsoft VBScript runtime error: #{error.description}"
		end
	end
end
puts ""

