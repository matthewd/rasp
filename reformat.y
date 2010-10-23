class VbScriptRaccParser
prechigh
	left arg_paren
	left '.'

	# http://msdn.microsoft.com/library/en-us/dnasdj01/html/asp1200.asp
	# and
	# http://www.ronshardwebapps.com/tips/febtutorialoperators1.asp
	# both claim that '^' comes before UMINUS, yet
	# http://msdn.microsoft.com/library/en-us/script56/html/vsgrpoperatorprecedence.asp
	# claims the opposite :/
	#
	# A manual test shows that UMINUS does actually bind more tightly
	# than '^'.

	nonassoc UMINUS UPLUS
	left '^'
	left '*' '/'
	left '\\\\'
	left MOD
	left '+' '-'
	left '&'

	left COMPARISON '<>' '<' '>' '<=' '>=' IS

	left NOT
	left AND
	left OR
	left XOR
	left EQV
	left IMP

	left '(' ')' ','

	left '='

	left TO IN STEP
	left ELSEIF ELSE
	left ':'
	left newline fake_newline
	left '%>'
preclow
options no_result_var

#
# TODO
#

#
#  * Re-order rules to provide some logical groupings
#
#
#  * With block
#
#  * With operator
#
#  * Arrays
#
#  * Default method
#
#  * Defining a default method
#
#  * Set value on a method - Property Set/Let with params
#
#  * Imp/Eqv operators
#
#  * ASP environment - Request, Response, Server
#
#  * VBScript environment - WScript
#
#  * CreateObject for native implementation (dictionary, fso)
#
#  * Randomize - Can I seed ruby's generator?
#

#
#  * Booleans happily cast to integers and back
#

rule
	rootfile
		: file
		| html_block
	opt_html
		: {''}
		| html_block
	html_block
		: opt_html directive opt_newline { val[0] << val[1] << val[2] }
		| opt_html html opt_newline { val[0] << val[1] << val[2] }
		| opt_html '<%' file '%>' opt_newline { val[0] << '<%' << val[2] << (val[2] =~ /\n\z/ ? '' : "\n") << '%>' << val[4] }
	opt_newline
		: /* nothing */ {''}
		| opt_newline any_newline { val[0] + (val[1] || '') }
	file
		: {''}
		| file filecontent { val[0] << val[1] }
	filecontent
		: statement
		| class_def
		| method_def
	class_def
		: CLASS identifier end_statement
			class_body
			END CLASS end_statement { "Class #{val[1]}#{NL val[2]}#{I val[3]}End Class#{val[6]}" }
	class_body
		: /* nothing */ {''}
		| class_body class_body_item { val[0] << val[1] }
	class_body_item
		: class_member
		| class_method_def
		| class_property_def
		| any_newline
	class_member
		: scope ident_def end_statement { "#{val[0]} #{val[1]}#{val[2]}" }
	ident_def_list
		: ident_def
		| ident_def_list ',' ident_def { "#{val[0]}, #{val[2]}" }
	ident_def
		: identifier { val[0] }
		| ident_def arg_paren ')' { "#{val[0]}()" }
		| ident_def arg_paren integer ')' { "#{val[0]}(#{val[2]})" }
	class_method_def
		: scope method_def { "#{val[0]} #{val[1]}" }
		| method_def
	method_def
		: sub_def
		| function_def
	class_property_def
		: scope property_def { "#{val[0]} #{val[1]}" }
		| property_def
	scope
		: PUBLIC { 'Public' }
		| PRIVATE { 'Private' }
	property_stmt
		: PROPERTY GET { 'Property Get' }
		| PROPERTY LET { 'Property Let' }
		| PROPERTY SET { 'Property Set' }
	property_def
		: property_stmt identifier full_arg_def_list end_statement
			method_body
			END PROPERTY end_statement
			{ "#{val[0]} #{val[1]}#{Bracket val[2]}#{NL val[3]}#{I val[4]}End Property#{val[7]}" }
	sub_def
		: SUB identifier full_arg_def_list end_statement
			method_body
			END SUB end_statement
			{ "Sub #{val[1]}#{Bracket val[2]}#{NL val[3]}#{I val[4]}End Sub#{val[7]}" }
	function_def
		: FUNCTION identifier full_arg_def_list end_statement
			method_body
			END FUNCTION end_statement
			{ "Function #{val[1]}#{Bracket val[2]}#{NL val[3]}#{I val[4]}End Function#{val[7]}" }
	full_arg_def_list
		: arg_paren ')' {''}
		| arg_paren arg_def_list ')' { val[1] }
		| {''}
	arg_def_list
		: arg_def { val[0] }
		| arg_def_list ',' arg_def { "#{val[0]}, #{val[2]}" }
	arg_def
		: identifier
		| BYREF identifier { "ByRef #{val[1]}" }
		| BYVAL identifier { "ByVal #{val[1]}" }
	statements
		: /* nothing */ {''}
		| statements statement { val[0] << val[1] }
		| statements '%>' html_values '<%' { val[0] << '%>' << val[2] << '<%' }
	method_body
		: statements
	statement
		: end_statement { val[0].gsub(/^ */, '') }
		| simple_statement end_statement { val[0] + val[1] }
		| full_if_block
		| single_line_if
		| do_loop
		| for_next
		| for_each
		| select_block
		| with_block
		| EXPLICIT { "Option Explicit\n" }
	html_values
		: /* nothing */ {''}
		| html_values html { val[0] << val[1] }
		| html_values '<%=' expression '%>' { val[0] << '<%=' << val[2] << '%>' }
	with_block
		: WITH expression end_statement statements END WITH end_statement
			{ "With #{val[1]}#{NL val[2]}#{I val[3]}End With#{val[6]}" }
	select_block
		: SELECT CASE expression end_statement
			case_or_case_else
			END SELECT end_statement
			{ "Select Case #{val[2]}#{NL val[3]}#{I val[4]}End Select#{val[7]}" }
	case_or_case_else
		: optional_case case_block { val[0] << val[1] }
		| optional_case CASE ELSE end_statement statements { val[0] << "Case Else#{NL val[3]}#{I val[4]}" }
	case_block
		: CASE expression_list end_statement statements { "Case #{val[1]}#{NL val[2]}#{I val[3]}" }
	optional_case
		: optional_case case_block { val[0] << val[1] }
		| /* nothing */ {''}
	optional_step
		: STEP expression { " Step #{val[1]}" }
		| /* nothing */ { '' }
	for_each
		: FOR EACH identifier IN expression end_statement statements NEXT end_statement
			{ "For Each #{val[2]} In #{val[4]}#{NL val[5]}#{I val[6]}Next#{val[8]}" }
	do_loop
		: DO end_statement statements LOOP end_statement
			{ "Do#{NL val[1]}#{I val[2]}Loop#{val[4]}" }
		| DO WHILE expression end_statement statements LOOP end_statement
			{ "Do While #{val[2]}#{NL val[3]}#{I val[4]}Loop#{val[6]}" }
		| DO end_statement statements LOOP WHILE expression end_statement
			{ "Do#{NL val[1]}#{I val[2]}Loop While #{val[5]}#{val[6]}" }
		| DO UNTIL expression end_statement statements LOOP end_statement
			{ "Do Until #{val[2]}#{NL val[3]}#{I val[4]}Loop#{val[6]}" }
		| DO end_statement statements LOOP UNTIL expression end_statement
			{ "Do#{NL val[1]}#{I val[2]}Loop Until #{val[5]}#{val[6]}" }
		| WHILE expression end_statement statements WEND end_statement
			{ "While #{val[1]}#{NL val[2]}#{I val[3]}Wend#{val[5]}" }
	for_next
		: FOR identifier '=' expression TO expression optional_step end_statement statements NEXT end_statement
			{ "For #{val[1]} = #{val[3]} To #{val[5]}#{val[6]}#{NL val[7]}#{I val[8]}Next#{val[10]}" }
	single_line_if
		: IF expression THEN simple_statement_chain opt_comment any_newline
			{ a = "If #{val[1]} Then"; b = "#{val[3]}#{val[4]}\n"; (a.size + b.size) > 70 ? "#{a} _\n#{I b}" : "#{a} #{b}" }
		| IF expression THEN single_line_if
			{ "If #{val[1]} Then _\n#{I val[3]}" }
		| IF expression THEN simple_statement_chain ELSE single_line_if
			{ "If #{val[1]} Then #{val[3]} Else #{val[5]}" }
		| IF expression THEN simple_statement_chain ELSE simple_statement_chain opt_comment any_newline
			{ "If #{val[1]} Then #{val[3]} Else #{val[5]}#{val[6]}\n" }
	full_if_block
		: IF expression THEN end_statement
			statements
			optional_else_or_elseif
			END IF end_statement
			{ "If #{val[1]} Then#{NL val[3]}#{I val[4]}#{val[5]}End If#{val[8]}" }
	optional_else_or_elseif
		: ELSEIF expression THEN end_statement statements optional_else_or_elseif
			{ "ElseIf #{val[1]} Then#{NL val[3]}#{I val[4]}#{val[5]}" }
		| else_block
		| /* nothing */ {''}
	else_block
		: ELSE end_statement statements { "Else#{NL val[1]}#{I val[2]}" }
	simple_statement_chain
		: simple_statement_chain ':' simple_statement { "#{val[0]}: #{val[2]}" }
		| simple_statement
	simple_statement
		: assignment
		| objvalue
		| const_assignment
		| sub_call
		| exit_statement
		| on_error_statement
		| DIM ident_def_list { "Dim #{val[1]}" }
		| RANDOMIZE opt_expression { val[1] ? "Randomize #{val[1]}" : "Randomize" }
	on_error_statement
		: IGNORE_ERRORS { "On Error Resume Next" }
		| THROW_ERRORS { "On Error Goto 0" }
	exitable
		: SUB { 'Sub' }
		| FUNCTION { 'Function' }
		| PROPERTY { 'Property' }
		| DO { 'Do' }
		| FOR { 'For' }
	exit_statement
		: EXIT exitable { "Exit #{val[1]}" }
	assignment
		: objvalue '=' expression { "#{val[0]} = #{val[2]}" }
		| SET objvalue '=' expression { "Set #{val[1]} = #{val[3]}" }
	const_assignment
		: CONST identifier '=' literal { "Const #{val[1]} = #{val[3]}" }
		| CONST identifier '=' '-' literal { "Const #{val[1]} = -#{val[4]}" }
	objvalue
		: objvalue arg_paren opt_expression_list ')' { "#{val[0]}#{Bracket val[2]}" }
		| objvalue '.' objmember { "#{val[0]}.#{val[2]}" }
		| with_dot objmember { ".#{val[1]}" }
		| identifier
	identifier
		: ident { check_ident val[0] }
		| '[' ident ']' { "[#{check_ident val[1]}]" }
	objmember
		: identifier { check_member val[0] }
	opt_expression
		: /* nothing */ { nil }
		| expression
	expression
		: objexpression
		| intrinsic_expression
	# Note that this doesn't actually cover all intrinsic expressions...
	# specifically, a variable reference is always treated as an
	# objexpression (via objvalue).
	intrinsic_expression
		: literal

		| '+' expression =UPLUS { val[1] }
		| '-' expression =UMINUS { "-#{val[1]}" }
		| expression '^' expression { "#{val[0]} ^ #{val[2]}" }
		| expression '*' expression { "#{val[0]} * #{val[2]}" }
		| expression '/' expression { "#{val[0]} / #{val[2]}" }
		| expression '\\\\' expression { "#{val[0]} \\ #{val[2]}" }
		| expression MOD expression { "#{val[0]} Mod #{val[2]}" }
		| expression '+' expression { "#{val[0]} + #{val[2]}" }
		| expression '-' expression { "#{val[0]} - #{val[2]}" }
		| expression '&' expression { "#{val[0]} & #{val[2]}" }

		| expression '=' expression =COMPARISON { "#{val[0]} = #{val[2]}" }
		| expression '<>' expression { "#{val[0]} <> #{val[2]}" }
		| expression '<=' expression { "#{val[0]} <= #{val[2]}" }
		| expression '>=' expression { "#{val[0]} >= #{val[2]}" }
		| expression '<' expression { "#{val[0]} < #{val[2]}" }
		| expression '>' expression { "#{val[0]} > #{val[2]}" }

		| NOT expression { "Not #{val[1]}" }
		| expression AND expression { "#{val[0]} And #{val[2]}" }
		| expression OR expression { "#{val[0]} Or #{val[2]}" }
		| expression XOR expression { "#{val[0]} Xor #{val[2]}" }
		| expression EQV expression { "#{val[0]} Eqv #{val[2]}" }
		| expression IMP expression { "#{val[0]} Imp #{val[2]}" }

		| objexpression IS objexpression { "#{val[0]} Is #{val[2]}" }

		| '(' intrinsic_expression ')' { "(#{val[1]})" }
	objexpression
		: objvalue
		| NEW identifier { "New #{val[1]}" }
		| '(' objexpression ')' { "(#{val[1]})" }
	literal
		: integer { val[0].to_i.to_s }
		| float { val[0].to_f.to_s }
		| string { '"' + val[0].to_s.gsub('"', '""') + '"' }
		| TRUE { 'True' }
		| FALSE { 'False' }
	string
		: '\"' string_contents '\"' { val[1] }
		| '\"' '\"' { '' }
	string_contents
		: string_atom
		| string_contents string_atom { val[0] + val[1] }
	string_atom
		: escaped_atom { '"' }
		| string_text
	sub_call
		: objvalue '.' objmember opt_expression_list { val[3] ? "#{val[0]}.#{val[2]} #{val[3]}" : "#{val[0]}.#{val[2]}" }
		| identifier opt_expression_list { val[1] ? "#{val[0]} #{val[1]}" : val[0] }
		| with_dot identifier opt_expression_list { val[2] ? ".#{val[1]} #{val[2]}" : ".#{val[1]}" }
		| CALL function_call { "Call #{val[1]}" }
	function_call
		: identifier arg_paren opt_expression_list ')' { "#{val[0]}#{Bracket val[2]}" }
		| identifier
	any_newline
		: newline { "\n" }
		| fake_newline { '' }
	end_statement
		: ':' { ': ' }
		| comment any_newline { " #{val[0]}#{val[1]}" }
		| any_newline { val[0] }
	opt_comment
		: /* nothing */ { '' }
		| comment { " #{val[0]}" }
	opt_expression_list
		: /* nothing */ { nil }
		| expression_list
	expression_list
		: expression { val[0] }
		| expression_list ',' expression { "#{val[0]}, #{val[2]}" }

end

---- inner
def run_parse object, method
	@yydebug = true

	yyparse object, method
end
def on_error error_token_id, error_value, value_stack
	$stderr.puts "on_error: " + [error_token_id, error_value.group, error_value, value_stack.size, value_stack.last(5)].inspect

	errno = case token_to_str(error_token_id).to_sym
	when :LOOP
		:loop_without_do
	when :TYPEOF, :reserved, :error
		:syntax_error
	else
		:unknown
	end
	exception = Rasp::ScriptError.new( errno == :unknown ? :parse_error : errno, nil )
	exception.token = error_value
	exception.description = "Parse error on value \"#{error_value}\" (#{token_to_str error_token_id})" if errno == :unknown
	raise exception
end
