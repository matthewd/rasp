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
    : {[]}
    | html_block
  html_block
    : opt_html directive opt_newline { val[0].push Rasp::Print.new(:token => val[0], :expression => val[1]) }
    | opt_html html opt_newline { val[0].push Rasp::Print.new(:token => val[0], :expression => val[1]) }
    | opt_html '<%' file '%>' opt_newline { val[0].push val[2] }
  opt_newline
    : /* nothing */ {nil}
    | opt_newline any_newline {nil}
  file
    : {[]}
    | file filecontent { val[0].append val[1] }
  filecontent
    : statement
    | class_def
    | method_def
  class_def
    : CLASS identifier end_statement
      class_body
      END CLASS end_statement { Rasp::ClassDefine.new(:token => val[0], :name => val[1], :content => val[3]) }
  class_body
    : /* nothing */ {[]}
    | class_body class_body_item { val[0].append val[1] }
  class_body_item
    : class_member
    | class_method_def
    | class_property_def
    | any_newline {[]}
  class_member
    : scope ident_def end_statement
  ident_def_list
    : ident_def { [Rasp::Define.new(:token => val[0], :variable_name => val[0][0], :dimensions => val[0][1])] }
    | ident_def_list ',' ident_def { val[0].push(Rasp::Define.new(:token => val[2], :variable_name => val[2][0], :dimensions => val[2][1])) }
  ident_def
    : identifier { [val[0], 0] }
    | ident_def arg_paren ')' { [val[0][0], val[0][1] + 1] }
  class_method_def
    : scope method_def { val[1].scope = val[0]; val[1] }
    | method_def
  method_def
    : sub_def
    | function_def
  class_property_def
    : scope property_def { val[1].scope = val[0]; val[1] }
    | property_def
  scope
    : PUBLIC { :public }
    | PRIVATE { :private }
  property_stmt
    : PROPERTY GET { :property_get }
    | PROPERTY LET { :property_let }
    | PROPERTY SET { :property_set }
  property_def
    : property_stmt identifier full_arg_def_list end_statement
      method_body
      END PROPERTY end_statement
      {
        case val[0]
        when :property_get
          Rasp::MethodDefine.new :token => val[0], :returns => true, :exit_symbol => :exit_property, :name => val[1], :arguments => val[2], :body => val[4]
        when :property_let
          Rasp::MethodDefine.new :token => val[0], :exit_symbol => :exit_property, :name => val[1], :arguments => val[2], :body => val[4]
        when :property_set
          Rasp::MethodDefine.new :token => val[0], :exit_symbol => :exit_property, :name => val[1], :arguments => val[2], :body => val[4]
        end
      }
  sub_def
    : SUB identifier full_arg_def_list end_statement
      method_body
      END SUB end_statement
      { Rasp::MethodDefine.new :token => val[0], :exit_symbol => :exit_sub, :name => val[1], :arguments => val[2], :body => val[4] }
  function_def
    : FUNCTION identifier full_arg_def_list end_statement
      method_body
      END FUNCTION end_statement
      { Rasp::MethodDefine.new :token => val[0], :returns => true, :exit_symbol => :exit_function, :name => val[1], :arguments => val[2], :body => val[4] }
  full_arg_def_list
    : arg_paren ')' {[]}
    | arg_paren arg_def_list ')' { val[1] }
    | {[]}
  arg_def_list
    : arg_def { [val[0]] }
    | arg_def_list ',' arg_def { val[0].push val[2] }
  arg_def
    : identifier
    | BYREF identifier { val[1] }
    | BYVAL identifier { val[1] }
  statements
    : /* nothing */ {[]}
    | statements statement { val[0].append val[1] }
    | statements '%>' html_values '<%' { val[0].append val[2] }
  method_body
    : statements
  statement
    : end_statement {nil}
    | simple_statement end_statement
    | full_if_block
    | single_line_if
    | do_loop
    | for_next
    | for_each
    | select_block
    | with_block
    | EXPLICIT { Rasp::Explicit.new(:token => val[0]) }
    | RANDOMIZE opt_expression { Rasp::Randomize.new(:token => val[0], :expression => val[1]) }
  html_values
    : /* nothing */ {[]}
    | html_values html { val[0].push Rasp::Print.new(:token => val[0], :expression => val[1]) }
    | html_values '<%=' expression '%>' { val[0].push Rasp::Print.new(:token => val[0], :expression => val[2]) }
  with_block # FIXME
    : WITH expression end_statement statements END WITH end_statement
      { val[3] }
  select_block
    : SELECT CASE expression end_statement
      case_or_case_else
      END SELECT end_statement
      { Rasp::Select.new :token => val[0], :expression => val[2], :alternatives => val[4] }
  case_or_case_else
    : optional_case case_block { val[0].push val[1] }
    | optional_case CASE ELSE statements { val[0].push [:else, val[3]] }
  case_block
    : CASE expression_list end_statement statements { [val[1], val[3]] }
  optional_case
    : optional_case case_block { val[0].push val[1] }
    | /* nothing */ {[]}
  optional_step
    : STEP expression { val[1] }
    | /* nothing */ { 1 }
  for_each
    : FOR EACH identifier IN expression end_statement statements NEXT end_statement
      { Rasp::Each.new :token => val[0], :exit_symbol => :exit_for, :variable => val[2], :collection => val[4], :body => val[6] }
  do_loop
    : DO end_statement statements LOOP end_statement
      { Rasp::Loop.new :token => val[0], :exit_symbol => :exit_do, :pre => true, :body => val[4], :post => true }
    | DO WHILE expression end_statement statements LOOP end_statement
      { Rasp::Loop.new :token => val[0], :exit_symbol => :exit_do, :pre => val[2], :body => val[4], :post => true }
    | DO end_statement statements LOOP WHILE expression end_statement
      { Rasp::Loop.new :token => val[0], :exit_symbol => :exit_do, :pre => true, :post => val[5], :body => val[2] }
    | DO UNTIL expression end_statement statements LOOP end_statement
      { Rasp::Loop.new :token => val[0], :exit_symbol => :exit_do, :pre => Rasp::Expression::Operator::Not.new(:value => val[2]), :body => val[4], :post => true }
    | DO end_statement statements LOOP UNTIL expression end_statement
      { Rasp::Loop.new :token => val[0], :exit_symbol => :exit_do, :pre => true, :body => val[2], :post => Rasp::Expression::Operator::Not.new(:value => val[5]) }
    | WHILE expression end_statement statements WEND end_statement
      { Rasp::Loop.new :token => val[0], :pre => val[1], :body => val[3], :post => true }
  for_next
    : FOR identifier '=' expression TO expression optional_step end_statement statements NEXT end_statement
      { Rasp::Loop.new(
        :token => val[0], :exit_symbol => :exit_for,
        :init => Rasp::Assignment.new(:lvalue => val[1], :expression => val[3]),
        :pre => Rasp::Conditional.new(
          :condition => Rasp::Expression::Operator::LessThan.new(
            :lvalue => val[6], 
            :rvalue => 0),
          :true_part => Rasp::Expression::Operator::GreaterThanEqual.new(
            :lvalue => Rasp::Expression::Variable.new(:variable_name => val[1]), 
            :rvalue => val[5]),
          :false_part => Rasp::Expression::Operator::LessThanEqual.new(
            :lvalue => Rasp::Expression::Variable.new(:variable_name => val[1]), 
            :rvalue => val[5])),
        :body => val[8],
        :post => [
          Rasp::Assignment.new(
            :lvalue => val[1], 
            :expression => Rasp::Expression::Operator::Plus.new(
              :lvalue => Rasp::Expression::Variable.new(:variable_name => val[1]), 
              :rvalue => val[6]))]) }
  single_line_if
    : IF expression THEN simple_statement_chain opt_comment any_newline
      { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[3], :false_part => nil }
    | IF expression THEN single_line_if
      { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[3], :false_part => nil }
    | IF expression THEN simple_statement_chain ELSE single_line_if
      { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[3], :false_part => val[5] }
    | IF expression THEN simple_statement_chain ELSE simple_statement_chain opt_comment any_newline
      { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[3], :false_part => val[5] }
  full_if_block
    : IF expression THEN end_statement
      statements
      optional_else_or_elseif
      END IF end_statement
      { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[4], :false_part => val[5] }
  optional_else_or_elseif
    : ELSEIF expression THEN end_statement statements optional_else_or_elseif { Rasp::Conditional.new :token => val[0], :condition => val[1], :true_part => val[4], :false_part => val[5] }
    | else_block
    | /* nothing */ {[]}
  else_block
    : ELSE end_statement statements { val[2] }
  simple_statement_chain
    : simple_statement_chain ':' simple_statement { [val[0], val[2]] }
    | simple_statement
  simple_statement
    : assignment
    | objvalue
    | const_assignment
    | sub_call
    | exit_statement
    | on_error_statement
    | DIM ident_def_list { val[1] }
  on_error_statement
    : IGNORE_ERRORS { Rasp::OnError.new :token => val[0], :fatal => false }
    | THROW_ERRORS { Rasp::OnError.new :token => val[0], :fatal => true }
  exitable
    : SUB {:exit_sub}
    | FUNCTION {:exit_function}
    | PROPERTY {:exit_property}
    | DO {:exit_do}
    | FOR {:exit_for}
  exit_statement
    : EXIT exitable { Rasp::Exit.new :token => val[0], :symbol => val[1] }
  assignment
    : objvalue '=' expression { Rasp::Assignment.new :token => val[0], :lvalue => (val[0].respond_to?(:variable_name) ? val[0].variable_name : val[0]), :expression => val[2] }
    | SET objvalue '=' expression { Rasp::Assignment.new :token => val[0], :object => true, :lvalue => (val[1].respond_to?(:variable_name) ? val[1].variable_name : val[1]), :expression => val[3] }
  const_assignment
    : CONST identifier '=' literal { Rasp::Assignment.new :token => val[0], :lvalue => val[1], :expression => val[3], :constant => true }
  objvalue
    : objvalue arg_paren opt_expression_list ')' { Rasp::Expression::MethodCall.new :token => val[0], :expect_return => true, :method_name => val[0], :arguments => val[2] }
    | objvalue '.' objmember { Rasp::Expression::MemberCall.new :token => val[0], :object => val[0], :member => val[2] }
    | with_dot objmember {val[1]}#{ throw 'WITH not implemented for member call' }
    | identifier { Rasp::Expression::Variable.new :token => val[0], :variable_name => val[0] }
  identifier
    : ident
    | '[' ident ']' { val[1] }
  objmember
    : identifier
  opt_expression
    : /* nothing */ {[]}
    | expression
  expression
    : objexpression
    | intrinsic_expression
  # Note that this doesn't actually cover all intrinsic expressions...
  # specifically, a variable reference is always treated as an
  # objexpression (via objvalue).
  intrinsic_expression
    : literal

    | '+' expression =UPLUS { Rasp::Expression::Operator::UnaryPlus.new :token => val[0], :value => val[1] }
    | '-' expression =UMINUS { Rasp::Expression::Operator::UnaryMinus.new :token => val[0], :value => val[1] }
    | expression '^' expression { Rasp::Expression::Operator::Exponent.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '*' expression { Rasp::Expression::Operator::Multiply.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '/' expression { Rasp::Expression::Operator::Divide.new :token => val[0], :lvalue => val[0], :rvalue => val[2], :token => val[1] }
    | expression '\\\\' expression { Rasp::Expression::Operator::IntDivide.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression MOD expression { Rasp::Expression::Operator::Modulo.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '+' expression { Rasp::Expression::Operator::Plus.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '-' expression { Rasp::Expression::Operator::Minus.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '&' expression { Rasp::Expression::Operator::Concat.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }

    | expression '=' expression =COMPARISON { Rasp::Expression::Operator::Equal.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '<>' expression { Rasp::Expression::Operator::NotEqual.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '<=' expression { Rasp::Expression::Operator::LessThanEqual.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '>=' expression { Rasp::Expression::Operator::GreaterThanEqual.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '<' expression { Rasp::Expression::Operator::LessThan.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression '>' expression { Rasp::Expression::Operator::GreaterThan.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }

    | NOT expression { Rasp::Expression::Operator::Not.new :token => val[0], :value => val[1] }
    | expression AND expression { Rasp::Expression::Operator::And.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression OR expression { Rasp::Expression::Operator::Or.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression XOR expression { Rasp::Expression::Operator::Xor.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression EQV expression { Rasp::Expression::Operator::Eqv.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }
    | expression IMP expression { Rasp::Expression::Operator::Imp.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }

    | objexpression IS objexpression { Rasp::Expression::Operator::ObjEqual.new :token => val[0], :lvalue => val[0], :rvalue => val[2] }

    | '(' intrinsic_expression ')' { val[1] }
  objexpression
    : objvalue
    | NEW identifier { Rasp::Expression::NewObject.new :token => val[0], :class_name => val[1] }
    | '(' objexpression ')' { val[1] }
  literal
    : integer { val[0].to_i }
    | float { val[0].to_f }
    | string { val[0].to_s }
    | TRUE { true }
    | FALSE { false }
  string
    : '"' string_contents '"' { val[1] }
    | '"' '"' { '' }
  string_contents
    : string_atom
    | string_contents string_atom { val[0] + val[1] }
  string_atom
    : escaped_atom { '"' }
    | string_text
  sub_call
    : objvalue '.' identifier opt_expression_list { Rasp::Expression::MemberCall.new :token => val[0], :object => val[0], :member => Rasp::Expression::MethodCall.new(:method_name => val[2], :arguments => val[3]) }
    | identifier opt_expression_list { Rasp::Expression::MethodCall.new :token => val[0], :method_name => val[0], :arguments => val[1] }
    | with_dot identifier opt_expression_list { throw 'WITH not implemented for sub call' }
    | CALL function_call { val[1].expect_return = false; val[1] }
  function_call
    : identifier arg_paren opt_expression_list ')' { Rasp::Expression::MethodCall.new :token => val[0], :expect_return => true, :method_name => val[0], :arguments => val[2] }
    | identifier { Rasp::Expression::MethodCall.new :token => val[0], :expect_return => true, :method_name => val[0], :arguments => [] }
  any_newline
    : newline {"\n"}
    | fake_newline {""}
  end_statement
    : ':' {nil}
    | comment any_newline {nil}
    | any_newline {nil}
  opt_comment
    : /* nothing */ {nil}
    | comment {val[0]}
  opt_expression_list
    : /* nothing */ {[]}
    | expression_list
  expression_list
    : expression { [val[0]] }
    | expression_list ',' expression { val[0].push val[2] }

end

---- inner
def run_parse object, method
  @yydebug = true

  yyparse object, method
end
def on_error error_token_id, error_value, value_stack
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
