
require 'syntax'

class Syntax::Tokenizer
	def token tok
	  @callback.call( tok )
	end
end

class Syntax::Token
	def downcase; to_s.downcase; end
end
class PositionedToken < Syntax::Token
	attr_accessor :position
	def initialize data, group, position
		super data, group
		self.position = position
	end
end
class VbScriptTokenizer < Syntax::Tokenizer
	def initialize
		@type = nil
		@filename = ""
		@follow_includes = false
		@virtual_root = nil
		@swallow = true
	end
	attr_accessor :type

	attr_accessor :filename
	def setup
		@mode = nil
		@file_type = @type
		@allow_keyword = true
		@last_space = true
		@asp_expr = false
		self.last_pos = 0
	end

	def start_group(a, b=nil)
		a, b = map_group(a, b)
		if a
			flush_chunk
			@group = a
			append b
			flush_chunk
			#super :token_sep
		end
	end

	attr_accessor :follow_includes
	attr_accessor :virtual_root
	attr_accessor :swallow

	attr_accessor :last_pos
	alias :scan_without_storing_position :scan
	def scan_after_storing_position pattern
		self.last_pos = pos
		scan_without_storing_position pattern
	end
	alias :scan :scan_after_storing_position

	def position
		pre = @text.string.slice( 0, last_pos + 1 )
		line = pre.count( "\n" ) + 1
		char = pre.reverse.index( "\n" )
		char = pre.length if line == 1
		"#{filename}(#{line}, #{char})"
	end
	def append data
		if @chunk.empty?
			@chunk = data
		else
			@chunk << data
		end
	end
	def flush_chunk
		tok = @chunk || ""
		@chunk = ""

		unless tok.empty?
			tok = PositionedToken.new( tok, @group, position ) unless tok.is_a? Syntax::Token
			token( tok )
		end
	end
	def start_region(a, b=nil)
		start_group a, b
	end
	def end_region(a, b=nil)
		start_group(a, b) if b
	end

	def map_group(group, value)
		group = :ident if group == :'asp constant'
		return nil, nil if group == :space || group == :line_continuation || ((group == :comment) && @swallow)
		return value, value if group == :operator || group == :asp_marker
		#return :keyword, value if group.to_s.upcase == group.to_s
		return :ident, value if group.to_s.upcase == group.to_s and @allow_keyword == false
		return group, value
	end

	def step
		allow_next_keyword = true
		is_space = false

		unless @mode
			@file_type = check( /\s*</ ) ? :asp : :vbs unless @file_type
			case @file_type
			when :asp
				@mode = :html
			when :vbs
				@mode = :normal
			else
				@mode = check( /\s*</ ) ? :html : :normal
			end
		end

		case @mode
		when :html
			@mode = :normal
			start_group :html, scan_until( /(?=<!-- *#include)|(?=<%)|(?![^X]|X)/i )
			if scan(/<% *=/)
				start_group :asp_marker, '<%='
				@asp_expr = true
			elsif directive = scan( /<!-- *#include +(virtual|file)="([^"]*)" *-->/i )
				if follow_includes
					path = subgroup(2)
					if subgroup(1).downcase == 'virtual' && subgroup(2)[0] == ?/
						path = Pathname.new( virtual_root + path.sub( /./, '' ) )
					else
						path = Pathname.new( path )
						current_dir = Pathname.new( filename ).parent
						path = current_dir + path
					end

					c = Syntax::Convertors::Meta.for_syntax 'vbscript'
					c.start_group = lambda {|group, content| start_group group, content }
					c.type = :asp
					c.follow_includes = true
					c.virtual_root = virtual_root
					puts "Entering #{path}"
					c.convert File.read( path ), path
					puts "Leaving #{path}"
					@mode = :html
				else
					start_group :directive, directive
					@mode = :html
				end
			else
				start_group :asp_marker, scan( /<%/ )
				@asp_expr = false
			end
			is_space = true
		when :normal
			if nl = scan(/\r\n?|\n/)
				start_group :newline, nl
				is_space = true
			elsif nl = scan(/:/)
				start_group :operator, nl
				is_space = true
			elsif continue = scan(/_ *(\r\n?|\n)/)
				start_group :line_continuation, continue
				is_space = true
			elsif @file_type == :asp and marker = scan( /%>/ )
				unless @asp_expr
					start_group :fake_newline, ' '
				end
				@mode = :html
				start_group :asp_marker, marker
			elsif comment = scan(/(Rem +|').*/i)
				start_group :comment, comment

				# FIXME: This is just for testing convenience
				if comment == "'__END__"
					# Swallow the whole file
					scan( /(X|[^X])*/ )
				end
			elsif quote = scan(/"/)
				start_group :operator, quote
				start_region :string_text, scan(/([^"%]|%[^>])+%?/)
				@mode = :string

			elsif reserved = scan( /(TypeOf)\b/i )
				start_group :reserved, reserved

			elsif constant = scan( /True\b/i )
				start_group :TRUE, constant
			elsif constant = scan( /False\b/i )
				start_group :FALSE, constant

			# FIXME
			elsif constant = scan( /(Empty|Nothing|Null|Err)\b/i )
				start_group :ident, constant

			# FIXME
			elsif constant = scan( /(Response|Request|Server)\b/i )
				start_group :ident, constant

			elsif operator = scan( /With\b/i )
				start_group :WITH, operator
			elsif operator = scan( /Class\b/i )
				start_group :CLASS, operator
			elsif operator = scan( /Sub\b/i )
				start_group :SUB, operator
			elsif operator = scan( /Function\b/i )
				start_group :FUNCTION, operator
			elsif operator = scan( /Property\b/i )
				start_group :PROPERTY, operator
			elsif operator = scan( /End\b/i )
				start_group :END, operator
			elsif operator = scan( /Exit\b/i )
				start_group :EXIT, operator
			elsif operator = scan( /Get\b/i )
				start_group :GET, operator

			elsif keyword = scan( /New\b/i )
				start_group :NEW, keyword

			elsif operator = scan( /On +Error +Resume +Next\b/i )
				start_group :IGNORE_ERRORS, operator
			elsif operator = scan( /On +Error +Goto +0\b/i )
				start_group :THROW_ERRORS, operator
			elsif operator = scan( /Option +Explicit\b/i )
				start_group :EXPLICIT, operator
			elsif operator = scan( /Call\b/i )
				start_group :CALL, operator
			elsif operator = scan( /Randomize\b/i )
				start_group :RANDOMIZE, operator
			elsif operator = scan( /Private\b/i )
				start_group :PRIVATE, operator
			elsif operator = scan( /Public\b/i )
				start_group :PUBLIC, operator
			elsif operator = scan( /Erase\b/i )
				start_group :ERASE, operator
			elsif operator = scan( /Const\b/i )
				start_group :CONST, operator
			elsif operator = scan( /Dim\b/i )
				start_group :DIM, operator
			elsif operator = scan( /ReDim\b/i )
				start_group :REDIM, operator
			elsif operator = scan( /Preserve\b/i )
				start_group :PRESERVE, operator
			elsif operator = scan( /Let\b/i )
				start_group :LET, operator
			elsif operator = scan( /Set\b/i )
				start_group :SET, operator
			elsif operator = scan( /Do\b/i )
				start_group :DO, operator
			elsif operator = scan( /Loop\b/i )
				start_group :LOOP, operator
			elsif operator = scan( /For\b/i )
				start_group :FOR, operator
			elsif operator = scan( /In\b/i ) # FIXME: Not actually a reserved word! :(
				start_group :IN, operator
			elsif operator = scan( /To\b/i ) # FIXME: Not actually a reserved word! :(
				start_group :TO, operator
			elsif operator = scan( /Step\b/i ) # FIXME: Not actually a reserved word! :(
				start_group :STEP, operator
			elsif operator = scan( /Next\b/i )
				start_group :NEXT, operator
			elsif operator = scan( /Each\b/i )
				start_group :EACH, operator
			elsif operator = scan( /If\b/i )
				start_group :IF, operator
			elsif operator = scan( /With\b/i )
				start_group :WITH, operator
			elsif operator = scan( /Then\b/i )
				start_group :THEN, operator
			elsif operator = scan( /Else\b/i )
				start_group :ELSE, operator
			elsif operator = scan( /ElseIf\b/i )
				start_group :ELSEIF, operator
			elsif operator = scan( /Select\b/i )
				start_group :SELECT, operator
			elsif operator = scan( /Case\b/i )
				start_group :CASE, operator
			elsif operator = scan( /While\b/i )
				start_group :WHILE, operator
			elsif operator = scan( /Until\b/i )
				start_group :UNTIL, operator
			elsif operator = scan( /Wend\b/i )
				start_group :WEND, operator

			# FIXME
			elsif builtin = scan( /(IsArray|LBound|UBound|Abs|Asc|AscB|AscW|Chr|ChrB|ChrW|CBool|CByte|CDate|CDbl|CInt|CLng|CSng|CStr|DateSerial|DateValue|Hex|Oct|Fix|Int|Sgn|TimeSerial|TimeValue|Date|Time|Day|Month|Weekday|Year|Hour|Minute|Second|Now|Atn|Cos|Sin|Tan|Exp|Log|Sqr|Rnd|CreateObject|IsObject|InStr|InStrB|Len|LenB|LCase|UCase|Left|LeftB|Mid|MidB|Right|RightB|Space|StrComp|String|LTrim|RTrim|Trim|IsDate|IsEmpty|IsNull|IsNumeric|VarType)(?= *\()/i )
				start_group :ident, builtin

			elsif operator = scan( /ByVal\b/i )
				start_group :BYVAL, operator
			elsif operator = scan( /ByRef\b/i )
				start_group :BYREF, operator

			elsif operator = scan( /Mod\b/i )
				start_group :MOD, operator
			elsif operator = scan( /Is\b/i )
				start_group :IS, operator
			elsif operator = scan( /Not\b/i )
				start_group :NOT, operator
			elsif operator = scan( /And\b/i )
				start_group :AND, operator
			elsif operator = scan( /Or\b/i )
				start_group :OR, operator
			elsif operator = scan( /Xor\b/i )
				start_group :XOR, operator
			elsif operator = scan( /Eqv\b/i )
				start_group :EQV, operator
			elsif operator = scan( /Imp\b/i )
				start_group :IMP, operator

			elsif digits = scan(/\d*\.\d+/)
				start_group :float, digits

			elsif digits = scan(/\d+/)
				start_group :integer, digits

			elsif words = scan(/\w+/)
				start_group :ident, words

			elsif punct = scan(/[,]/)
				start_group :operator, punct
				is_space = true

			elsif punct = scan(/[(]/)
				start_group @last_space ? :operator : :arg_paren, punct
				is_space = true

			elsif punct = scan(/[.]/)
				start_group @last_space ? :with_dot : :operator, punct
				allow_next_keyword = false

			elsif punct = scan(/[)]/)
				start_group :operator, punct
				allow_next_keyword = false
				is_space = false

			elsif punct = scan(/[-+*\\\/^&=]|[<>]=|<>|[<>]/)
				start_group :operator, punct
				allow_next_keyword = false
				is_space = true

			elsif space = scan(/\s/)
				start_group :space, space
				is_space = true

			elsif ext_ident = scan(/\[([^\]]*)\]/)
				start_group :operator, '['
				start_group :ident, subgroup( 1 )
				start_group :operator, ']'

			else
				start_group :unknown, scan(/./)
			end
		when :string
			if @file_type == :asp and marker = scan( /%>/ )
				raise "Syntax error: Can't have %> in a string!"
			elsif escaped = scan(/""/)
				start_group :escaped_atom, escaped
				start_group :string_text, scan(/([^"%]|%[^>])+%?/)
			elsif quote = scan(/"/)
				end_region :string_text
				start_group :operator, quote
				@mode = :normal
			else
				start_group :string_text, scan(/./)
			end
		end

		@allow_keyword = allow_next_keyword
		@last_space = is_space
	end
end

Syntax::SYNTAX['vbscript'] = VbScriptTokenizer

