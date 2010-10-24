
class Hash
  def self.from_two_arrays keys, values
    hash = {}
    keys.size.times { |i| hash[keys[i]] = values[i] }
    hash
  end
end
class Array
  def debug_info action
    puts
    puts "#{action} code block:"
    puts
    p self
    puts
  end
  def token
    self[0].token rescue self[0]
  end
  def append other
    if other.is_a? Array
      self + other
    else
      self.push other
    end
  end
  def compile context
    debug_info 'Compiling' if $DEBUG
    compile_all(context).last
  end
  def run context
    run_all(context).last
  end
  def compile_all context
    map { |item| item.compile context }
  end
  def run_all context
    debug_info 'Running' if $DEBUG
    map { |item| item.run context }
  end
  def context= new_value
    each { |item| item.context = new_value }
  end
end
class Object
  def run context; self; end
  def compile context; self; end
  def simple; self; end
  def is_intrinsic?; false; end
end
class Array; def is_intrinsic?; true; end; end
class Number; def is_intrinsic?; true; end; end
class String; def is_intrinsic?; true; end; end

module Rasp
  def self.name_of_member_to_call obj, original_name
    name = original_name.to_s.dup
    return name if obj.respond_to? name
    name.gsub!( /([A-Z])/ ) { |letter| "_#{letter.downcase}" }
    name.gsub!( /^_/, '' )
    return name if obj.respond_to? name
    name.gsub!( /(_[a-z])/ ) { |letter| letter.upcase[1,1] }
    return name if obj.respond_to? name
    name.gsub!( /^([a-z])/ ) { |letter| letter.upcase }
    return name if obj.respond_to? name
    name.downcase!
    return name if obj.respond_to? name
    name.gsub!( '_', '' )
    return name if obj.respond_to? name

    matches = obj.methods.select { |method_name| method_name.downcase.gsub( '_', '' ) == name }
    return matches[0] if matches.size == 1

    return original_name
  end

  class Context
    attr_accessor :local_variables
    attr_accessor :methods
    attr_accessor :parent_context
    attr_accessor :constants
    attr_accessor :errors_fatal
    attr_accessor :self_object

    def all_constant?; @all_constant; end
    def all_constant!; @all_constant = true; end

    def errors_fatal?
      return errors_fatal unless errors_fatal.nil?
      return parent_context.errors_fatal? unless parent_context.nil?
      true
    end

    def root_context
      return parent_context.root_context unless parent_context.nil?
      return self
    end

    def initialize options=nil
      @self_object = nil
      @parent_context = nil
      @methods = {}
      @local_variables = {}
      @constants = []
      options.each { |key, value| instance_variable_set('@' + key.to_s, value) } if options
      @all_constant = false
      @explicit = false
    end

    def get_method name, failure_fatal = true
      puts "Getting method #{name} in #{self}" if $DEBUG

      method = nil
      #name_on_object = Rasp::name_of_member_to_call( self_object, name )
      name_on_object = name.downcase
      method ||= self_object.method( name_on_object ) if self_object.respond_to? name_on_object
      method ||= methods[name.downcase]
      method ||= parent_context.get_method(name, failure_fatal) if parent_context
      raise "Unable to find method: #{name}" if method.nil? && failure_fatal
      method
    end

    def define_method name, args, body, exit_symbol, returns
      throw :constant_context if all_constant?
      throw :variable if variable_exists? name
      methods[name.downcase] = Method.new(:name => name, :arguments => args, :body => body, :context => self, :exit_symbol => exit_symbol, :returns => returns)
    end
    def define_native_method name, &block
      throw :constant_context if all_constant?
      throw :variable if variable_exists? name
      puts "Defining #{name.downcase}" if $DEBUG
      methods[name.downcase] = RubyMethod.new(:name => name, :block => block, :context => self)
    end

    def variable_context variable_name
      return self if local_variables.key? variable_name.downcase
      return parent_context.variable_context( variable_name ) unless parent_context.nil?
    end

    def define_variable variable_name, self_value = false
      return false if all_constant?
      return false if local_variables.key? variable_name.downcase
      return false if method_exists? variable_name and !self_value
      puts "Defining #{variable_name} (#{variable_name.class}) in #{self}" if $DEBUG
      local_variables[variable_name.downcase] = Empty.get
      return true
    end

    def [] variable_name
      return self_object if variable_name.downcase == 'me' unless self_object.nil?
      #name_on_object = Rasp::name_of_member_to_call( self_object, variable_name )
      name_on_object = variable_name.downcase
      return self_object.__send__( name_on_object ) if self_object.respond_to? name_on_object
      context = variable_context(variable_name)
      if context.nil?
        if method = get_method(variable_name, false)
          raise "#{variable_name} does not return a value" if method.respond_to?( :returns ) && !method.returns
          raise "Incorrect number of arguments for #{variable_name}; got 0, expected #{method.arity}" unless method.arity.zero? or method.arity == -1
          return method.call
        end

        if explicit?
          raise "Variable undefined: #{variable_name} (known: #{known_variables}); current context: #{self}"
        else
          define_variable variable_name
          context = self
        end
      end
      context.local_variables[variable_name.downcase]
    end

    def known_variables
      l_known = local_variables.keys.join(', ')
      p_known = parent_context.known_variables if parent_context
      return "#{l_known}; #{p_known}"
    end

    def []= variable_name, new_value
      throw :constant_context if all_constant?
      throw :constant if is_constant? variable_name
      context = variable_context(variable_name)
      unless context
        throw :variable_undefined if explicit?
        context = self
      end
      context.local_variables[variable_name.downcase] = new_value
    end

    def explicit?
      return parent_context.explicit? if parent_context
      @explicit
    end
    def explicit!
      @explicit = true
    end

    def exists? name
      variable_exists?(name) || method_exists?(name)
    end

    def variable_exists? name
      !variable_context(name).nil?
    end

    def method_exists? name
      !get_method(name, false).nil?
    end

    def is_constant? name
      constants.include? name.downcase
    end

    def define_constant name, value
      self[name] = value
      constants.push name.downcase
      value
    end
  end

  class MetaObject
    attr_accessor :__context__
    def simple
      throw :no_default_property
    end
    def method_missing target, *args
      name = Rasp::name_of_member_to_call( self, target )
      if name != target
        __send__ name, *args
      else
        super
      end
    end
    def generous_respond_to? method
      name = Rasp::name_of_member_to_call( self, method )
      respond_to? name
    end
    def initialize
      class_initialize if generous_respond_to? :class_initialize
    end
    def self.create_finalizer obj
      proc {|id| obj.class_terminate if obj.generous_respond_to? :class_terminate }
    end
  end

  # SYNTAX ERRORS
  # 1052  Cannot have multiple default property/method in a Class
  # 1044  Cannot use parentheses when calling a Sub
  # 1053  Class initialize or terminate do not have arguments
  # 1058  'Default' specification can only be on Property Get
  # 1057  'Default' specification must also specify 'Public'
  # 1005  Expected '('
  # 1006  Expected ')'
  # 1011  Expected '='
  # 1021  Expected 'Case'
  # 1047  Expected 'Class'
  # 1025  Expected end of statement
  # 1014  Expected 'End'
  # 1023  Expected expression
  # 1015  Expected 'Function'
  # 1010  Expected identifier
  # 1012  Expected 'If'
  # 1046  Expected 'In'
  # 1026  Expected integer constant
  # 1049  Expected Let or Set or Get in property declaration
  # 1045  Expected literal constant
  # 1019  Expected 'Loop'
  # 1020  Expected 'Next'
  # 1050  Expected 'Property'
  # 1022  Expected 'Select'
  # 1024  Expected statement
  # 1016  Expected 'Sub'
  # 1017  Expected 'Then'
  # 1013  Expected 'To'
  # 1018  Expected 'Wend'
  # 1027  Expected 'While' or 'Until'
  # 1028  Expected 'While,' 'Until,' or end of statement
  # 1029  Expected 'With'
  # 1030  Identifier too long
  # 1014  Invalid character
  # 1039  Invalid 'exit' statement
  # 1040  Invalid 'for' loop control variable
  # 1013  Invalid number
  # 1037  Invalid use of 'Me' keyword
  ## 1038 'loop' without 'do'
  # 1048  Must be defined inside a Class
  # 1042  Must be first statement on the line
  ## 1041 Name redefined
  # 1051  Number of arguments must be consistent across properties specification
  # 1001  Out of Memory
  # 1054  Property Set or Let must have at least one argument
  ## 1002 Syntax error
  # 1055  Unexpected 'Next'
  # 1015  Unterminated string constant
  #
  # RUNTIME ERRORS
  # 429   ActiveX component can't create object
  # 507   An exception occurred
  # 449   Argument not optional
  # 17  Can't perform requested operation
  # 430   Class doesn't support Automation
  # 506   Class not defined
  ## 11 Division by zero
  # 48  Error in loading DLL
  # 5020  Expected ')' in regular expression
  # 5019  Expected ']' in regular expression
  # 432   File name or class name not found during Automation operation
  # 92  For loop not initialized
  # 5008  Illegal assignment
  ## 51 Internal error
  # 505   Invalid or unqualified reference
  # 481   Invalid picture
  # 5 Invalid procedure call or argument
  # 5021  Invalid range in character set
  # 94  Invalid use of Null
  # 448   Named argument not found
  # 447   Object doesn't support current locale setting
  # 445   Object doesn't support this action
  # 438   Object doesn't support this property or method
  # 451   Object not a collection
  # 504   Object not safe for creating
  # 503   Object not safe for initializing
  # 502   Object not safe for scripting
  # 424   Object required
  # 91  Object variable not set
  # 7 Out of Memory
  # 28  Out of stack space
  # 14  Out of string space
  # 6 Overflow
  # 35  Sub or function not defined
  # 9 Subscript out of range
  # 5017  Syntax error in regular expression
  # 462   The remote server machine does not exist or is unavailable
  # 10  This array is fixed or temporarily locked
  # 13  Type mismatch
  # 5018  Unexpected quantifier
  # 500   Variable is undefined
  # 458   Variable uses an Automation type not supported in VBScript
  # 450   Wrong number of arguments or invalid property assignment
  #
  class ScriptError < RuntimeError
    def exception; self; end
    attr_accessor :error_symbol
    attr_accessor :statement
    attr_accessor :token
    attr_accessor :inner
    def initialize error_symbol, statement, token=nil
      self.error_symbol = error_symbol
      self.statement = statement
      self.token = token.nil? ? (statement.nil? ? nil : statement.token) : token

      @number, @description = \
        case error_symbol
        when :divide_by_zero
          [11, 'Division by zero']
        when :syntax_error
          [1002, 'Syntax error']
        when :name_redefined
          [1041, 'Name redefined']
        when :loop_without_do
          [1038, "'loop' without 'do'"]
        else
          [51, 'Internal error']
        end
    end
    attr_reader :number
    attr_accessor :description
    def location
      puts "token nil!" if token.nil?
      puts "token #{token.class} can't position!" unless token.nil? || token.respond_to?( :position )
      unless token.nil? || !token.respond_to?( :position )
        token.position + ' '
      end
    end
    def to_s
      "#{location}Microsoft VBScript runtime error: #{description}"
    end
  end

  class Statement
    def initialize options
      @token = nil
      options.each { |key, value| instance_variable_set('@' + key.to_s, value) }
    end
    attr_writer :token
    def token
      t = @token
      t = t.token while t.respond_to? :token
      t
    end
    def compile context
    end
    def run context
      begin
        run_statement context
      rescue ScriptError => error
        error.statement = self
        error.token = self.token # Maybe?
        raise error if context.errors_fatal?
        context.root_context['err'].load_from_ruby_exception error
      rescue StandardError => error
        wrapper = ScriptError.new :internal_error, self
        wrapper.inner = error
# FIXME
        raise error
        raise wrapper if context.errors_fatal?
        context.root_context['err'].load_from_ruby_exception wrapper
#     ensure
#       GC.start
      end
    end
  end

  class ControlStructure < Statement
    def initialize options
      super options
    end
  end

  # For, Do, While
  class Loop < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :init
    attr_accessor :pre
    attr_accessor :body
    attr_accessor :post

    def run_statement context
      init.run context
      loop do
        pre.run(context) or return
        body.run context
        post.run(context) or return
      end
    end
  end

  # For Each
  class Each < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :variable
    attr_accessor :collection
    attr_accessor :body

    def run_statement context
      collection.run(context).each do |item|
        context[variable] = item
        body.run context
      end
    end
  end

  # On Error ...
  class OnError < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :fatal

    def run_statement context
      context.errors_fatal = fatal
    end
  end

  # Option Explicit
  class Explicit < ControlStructure
    def compile context
      context.explicit!
    end
    def run_statement context
    end
  end

  # If
  class Conditional < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :condition
    attr_accessor :true_part
    attr_accessor :false_part

    def run_statement context
      if condition.run(context).simple
        true_part.run context
      else
        false_part.run context
      end
    end
  end

  # Select Case
  class Select < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :expression
    attr_accessor :alternatives

    def run_statement context
      value = expression.run(context).simple
      for alt in alternatives
        if alt[0] == :else || alt[0].find {|a| Rasp::Expression::Operator::Equal.new(:lvalue => value, :rvalue => a).run(context).simple }
          return alt[1].run(context)
        end
      end
    end
  end

  # Dim
  class Define < Statement
    def initialize options
      super options
    end

    attr_accessor :variable_name

    def compile context
      unless context.define_variable(variable_name)
        error = ScriptError.new(:name_redefined, self)
        raise error if context.errors_fatal?
        context.root_context['err'].load_from_ruby_exception error
      end
    end
    def run_statement context
    end
  end

  # Function
  class MethodDefine < Statement
    def initialize options
      super options
    end

    attr_accessor :name
    attr_accessor :arguments
    attr_accessor :body
    attr_accessor :exit_symbol
    attr_accessor :returns
    attr_accessor :scope

    def run_statement context
      context.define_method name, arguments, body, exit_symbol, returns
    end
  end

  # Class
  class ClassDefine < Statement
    def initialize options
      super options
    end

    attr_accessor :name
    attr_accessor :content

    def compile context
      klass = Class.new( MetaObject )
      class_context = Context.new(:parent_context => context)
      class_context.define_variable 'Me'
      get_destructor = nil
      content.flatten.each do |item|
        if item.is_a? Rasp::MethodDefine
          method = Method.new(:name => item.name, :arguments => item.arguments, :body => item.body, :context => context, :exit_symbol => item.exit_symbol, :returns => item.returns)
          # FIXME: Really shouldn't play with the name they're trying to define :(
          klass.send :define_method, item.name.downcase do |*args|
            method.call_with_context( self.__context__, *args )
          end
          if item.name.downcase == 'class_terminate'
            get_destructor = lambda do |context|
              lambda do |id|
                method.call_with_context( context )
              end
            end
          end
        end
      end
      # FIXME: This finalizer won't ever run because I've created a
      # circular reference :(
      klass.send :define_method, :initialize do
        #super
        self.__context__ = class_context.clone
        self.__context__.self_object = self
        self.__context__['Me'] = self
        ObjectSpace.define_finalizer( self, get_destructor.call( self.__context__ ) ) unless get_destructor.nil?
        #puts "Defining finalizer" unless get_destructor.nil?
        #get_destructor.call( self.__context ).call( 0 ) unless get_destructor.nil?
      end

      context[self.name] = klass
    end

    def run_statement context
    end
  end

  # =, Let, Set
  class Assignment < Statement
    def initialize options
      @object = nil
      @constant = nil
      super options
    end

    attr_accessor :lvalue
    attr_accessor :expression
    attr_accessor :constant
    attr_accessor :object

    def run_statement context
# FIXME: Why are the next two lines required?!
      @object = nil unless defined? @object
      @constant = nil unless defined? @constant

      value = expression.run(context)
      value = value.simple unless object

      if constant
        context.define_constant lvalue, value
      elsif lvalue.is_a? String
        context[lvalue] = value
      else
        if lvalue.is_a? Rasp::Expression::MethodCall
          # Convert it to a member-call on the default method
          name = if lvalue.respond_to? :method_name
            if lvalue.method_name.respond_to? :variable_name
              lvalue.method_name.variable_name
            else
              lvalue.method_name
            end
          elsif lvalue.respond_to? :variable_name
            lvalue.variable_name
          end.downcase
          args = lvalue.respond_to?(:arguments) ? lvalue.arguments : []

          puts "lvalue is a method call... this must be an assignment to the default property" if $DEBUG

          lvalue = Rasp::Expression::MemberCall.new(
            :object => Rasp::Expression::Variable.new(:variable_name => name), 
            :member => Rasp::Expression::MethodCall.new(:method_name => 'ASP_Default', :arguments => args))
        end

        args = lvalue.member.arguments.run_all(context) if lvalue.member.respond_to?(:arguments)
        args.push value
        name = if lvalue.member.respond_to? :method_name
          lvalue.member.method_name
        elsif lvalue.member.respond_to? :variable_name
          lvalue.member.variable_name
        end.downcase

        o = lvalue.object.run( context )
        name = Rasp::name_of_member_to_call( o, name )

        if o.respond_to?( :ole_methods ) && name == 'asp_default'
          name = o.ole_methods.find {|m| m.dispid == 0 }.name
        end
        name = '[]' if name == 'asp_default' and !o.respond_to?( :asp_default= ) and o.respond_to?( :[]= )
        if o.is_a? WIN32OLE
          o.setproperty( name, *args )
        else
          o.__send__(name + '=', *args)
        end
      end
    end
  end
  class Exit < Statement
    def initialize options
      super options
    end
    attr_accessor :symbol
    def run_statement context
      throw symbol
    end
  end

  # Response.Write
  class Print < Statement
    def initialize options
      super options
    end

    attr_accessor :expression

    def run_statement context
      puts expression.run(context).simple
    end
  end

  class Randomize < Statement
    def initialize options
      super options
    end

    attr_accessor :expression

    def run_statement context
      ignore = expression.run(context).simple
    end
  end

  class RubyMethod < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :name
    attr_accessor :block
    attr_accessor :context

    def arity
      block.arity
    end

    def call *argument_values
      block.call( *argument_values )
    end

    def returns; true; end
  end
  class Method < ControlStructure
    def initialize options
      super options
    end

    attr_accessor :name
    attr_accessor :body
    attr_accessor :arguments
    attr_accessor :context
    attr_accessor :exit_symbol
    attr_accessor :returns

    def arity
      arguments.length
    end

    def call *argument_values
      call_with_context context, *argument_values
    end
    def call_with_context context, *argument_values
      c = Context.new(:parent_context => context)
      c.errors_fatal = true

      # The name of the method is also a variable, through which the
      # return value will be retrieved
      c.define_variable name, true

      # The method's arguments are defined as locally-scoped
      # variables
      args = Hash.from_two_arrays arguments, argument_values
      args.each { |name, value| c.define_variable(name); c[name] = value }

      catch exit_symbol do
        body.compile(c)
        body.run(c)
      end

      # The return value is the current value of the variable sharing
      # its name with this method
      c[self.name]
    end
  end

  module Expression
    class Atom
      def initialize options
        options.each { |key, value| instance_variable_set('@' + key.to_s, value) }
      end
      attr_writer :token
      def token
        t = @token
        t = t.token while t.respond_to? :token
        t
      end
      def compile context
      end
    end

    class Literal < Atom
      def initialize options
        super options
      end

      attr_accessor :value

      def run context
        value
      end
    end

    class NewObject < Atom
      def initialize options
        super options
      end

      attr_accessor :class_name

      def run context
        context[class_name].new
      end
    end

    class Variable < Atom
      def initialize options
        super options
      end

      attr_accessor :variable_name

      def run context
        puts "Getting variable #{variable_name}" if $DEBUG
        context[variable_name]
      end
    end

    class MemberCall < Atom
      def initialize options
        super options
      end

      attr_accessor :object
      attr_accessor :member

      def run context, *arguments
        puts "Calling member #{member.to_s} on #{object.to_s}" if $DEBUG

        name = if member.respond_to? :method_name
          member.method_name
        elsif member.respond_to? :variable_name
          member.variable.name
        else
          member
        end.downcase
        o = object.run( context )
        name = Rasp::name_of_member_to_call( o, name )
        args = member.respond_to?(:arguments) ? member.arguments : arguments

        args = args.run_all( context )

        if o.respond_to?( :ole_methods ) && name == 'asp_default'
          name = o.ole_methods.find {|m| m.dispid == 0 }.name
        end
        name = '[]' if name == 'asp_default' and !o.respond_to?( :asp_default ) and o.respond_to?( :[] )
        o.__send__( name, *args )
      end
    end
    class MemberSet < Atom
      def initialize options
        super options
      end

      attr_accessor :object
      attr_accessor :name
      attr_accessor :arguments
      attr_accessor :expression
      attr_accessor :action

      def run context
        value = expression.run(context)
        value = value.simple if :action == :let
        args = arguments.run_all(context)
        args.push value
        object.run.__send__ name + '=', *args
      end
    end

    class MethodCall < Atom
      def initialize options
        super options
      end

      attr_accessor :method_name
      attr_accessor :arguments
      attr_accessor :expect_return

      def run context
        self.method_name = method_name.variable_name if method_name.respond_to?( :variable_name )
        if method_name.is_a? Rasp::Expression::MemberCall
          return method_name.run( context, *arguments )
          #puts "method_name.object"
          #p method_name.object
          #puts "-- "
          #puts "method_name.member"
          #p method_name.member
          #puts "-- "
          #puts "arguments"
          #p arguments
          #puts "-- "
        end
        if method = context.get_method(method_name, false)
          args = arguments.run_all(context)
          raise "#{method_name} does not return a value" if expect_return && !method.returns
          unless method.arity.zero? && args.length > 0
            required = method.arity
            required = -required - 1 if required < 0
            expected = required
            expected = "at least #{expected}" if method.arity < 0
            raise "Incorrect number of arguments for #{method_name}; got #{args.length}, expected #{expected}" unless required == args.length or (args.length > required and method.arity < 0)
            return method.call(*args)
          else
            object = Rasp::Expression::MethodCall.new(:method_name => method_name, :arguments => [], :expect_return => true)
          end
        elsif context.exists? method_name
          object = Rasp::Expression::Variable.new(:variable_name => method_name)
        else
          raise "No such method: #{method_name}"
        end

        puts "Didn't find a method #{method_name}, maybe it's a default method call on an object... (#{context})" if $DEBUG

        # Convert it to a member-call on the default method
        return Rasp::Expression::MemberCall.new(
          :object => object, 
          :member => Rasp::Expression::MethodCall.new(:method_name => 'ASP_Default', :arguments => arguments)
        ).run(context)
      end
    end

    module Operator
      class Operator < Rasp::Expression::Atom
        def initialize options
          super options
        end
      end

      class BinaryOperator < Operator
        def initialize options
          super options
        end

        attr_accessor :lvalue
        attr_accessor :rvalue
      end

      class UnaryOperator < Operator
        def initialize options
          super options
        end

        attr_accessor :value
      end

      class And < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple & rvalue.run(context).simple
        end
      end
      class Or < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple | rvalue.run(context).simple
        end
      end
      class Xor < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple ^ rvalue.run(context).simple
        end
      end
      class Eqv < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple ^ ~rvalue.run(context).simple
        end
      end
      class Imp < BinaryOperator
        def initialize options
          super options
        end

        def run context
          ~lvalue.run(context).simple | rvalue.run(context).simple
        end
      end

      class TypeOf < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).class.to_s == rvalue
        end
      end

      class Equal < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple == rvalue.run(context).simple
        end
      end
      class ObjEqual < BinaryOperator
        def initialize options
          super options
        end

        def run context
          #left = lvalue.run( context )
          #right = rvalue.run( context )

          #left.__id__ == right.__id__
          lvalue.run(context).__id__ == rvalue.run(context).__id__
        end
      end
      class NotEqual < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple != rvalue.run(context).simple
        end
      end
      class GreaterThan < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple > rvalue.run(context).simple
        end
      end
      class GreaterThanEqual < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple >= rvalue.run(context).simple
        end
      end
      class LessThan < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple < rvalue.run(context).simple
        end
      end
      class LessThanEqual < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple <= rvalue.run(context).simple
        end
      end

      class Concat < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple.to_s + rvalue.run(context).simple.to_s
        end
      end

      class Plus < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple + rvalue.run(context).simple
        end
      end
      class Minus < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple - rvalue.run(context).simple
        end
      end
      class Multiply < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple * rvalue.run(context).simple
        end
      end
      class Divide < BinaryOperator
        def initialize options
          super options
        end

        def run context
          begin
            lvalue.run(context).simple / rvalue.run(context).simple
          rescue ZeroDivisionError => error
            raise ScriptError.new(:divide_by_zero, nil, self.token)
          end
        end
      end
      class IntDivide < BinaryOperator
        def initialize options
          super options
        end

        def run context
          (lvalue.run(context).simple / rvalue.run(context).simple).to_i
        end
      end
      class Modulo < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple % rvalue.run(context).simple
        end
      end
      class Exponent < BinaryOperator
        def initialize options
          super options
        end

        def run context
          lvalue.run(context).simple ** rvalue.run(context).simple
        end
      end

      class UnaryMinus < UnaryOperator
        def initialize options
          super options
        end

        def run context
          -value.run(context).simple
        end
      end
      class UnaryPlus < UnaryOperator
        def initialize options
          super options
        end

        def run context
          value.run(context).simple
        end
      end
      class Not < UnaryOperator
        def initialize options
          super options
        end

        def run context
          ~value.run(context).simple
        end
      end
    end
  end
end

def test1
  c = Rasp::Context.new
  a_expr = Rasp::Expression::Literal.new(:value => 1)
  assignment = Rasp::Assignment.new(:lvalue => :a, :expression => a_expr)
  a_ref = Rasp::Expression::Variable.new(:variable_name => :a)
  comp = Rasp::Expression::Operator::GreaterThan.new(:lvalue => a_ref, :rvalue => 2)
  truepart = Rasp::Print.new(:expression => 'Foo')
  falsepart = Rasp::Print.new(:expression => 'Bar')
  if_stmt = Rasp::Conditional.new(:condition => comp, :true_part => truepart, :false_part => falsepart)

  file = [assignment, if_stmt]
  file.run c

  # a = 1
  # If a > 2 Then
  #    Response.Write "Foo"
  # Else
  #   Response.Write "Bar"
  # End If
end

def test2
  a_expr = Rasp::Expression::Literal.new(:value => 4)
  a_expr_2 = Rasp::Expression::Literal.new(:value => 23)
  a_assignment = Rasp::Assignment.new(:lvalue => :a, :expression => a_expr)
  a_assignment_2 = Rasp::Assignment.new(:lvalue => :a, :expression => a_expr_2)
  a_def = Rasp::Define.new(:variable_name => :a)
  a_ref = Rasp::Expression::Variable.new(:variable_name => :a)
  b_expr = Rasp::Expression::Literal.new(:value => 51)
  b_expr_2 = Rasp::Expression::Literal.new(:value => 17)
  b_assignment = Rasp::Assignment.new(:lvalue => :b, :expression => b_expr)
  b_assignment_2 = Rasp::Assignment.new(:lvalue => :b, :expression => b_expr_2)
  b_ref = Rasp::Expression::Variable.new(:variable_name => :b)
  method_call = Rasp::Expression::MethodCall.new(:method_name => :frob, :arguments => [])

  a_out = Rasp::Print.new(:expression => a_ref.dup)
  b_out = Rasp::Print.new(:expression => b_ref.dup)
  sep_out = Rasp::Print.new(:expression => '-')

  method_body = [a_def, a_assignment_2, b_assignment_2, a_out.dup, b_out.dup, sep_out.dup]

  method_def = Rasp::MethodDefine.new(:name => :frob, :arguments => [], :body => method_body)

  file = [method_def, a_assignment, b_assignment, a_out, b_out, sep_out, method_call, a_out, b_out]
  file.run Rasp::Context.new

  # Sub frob
  #    Dim a
  #    a = 23
  #    b = 17
  #
  #    Response.Write a
  #    Response.Write b
  #    Response.Write "-"
  # End Sub
  #
  # a = 4
  # b = 51
  #
  # Response.Write a
  # Response.Write b
  # Response.Write "-"
  #
  # frob
  #
  # Response.Write a
  # Response.Write b
end

#puts 'test1:'
#test1
#puts '-- '

#puts 'test2:'
#test2
#puts '-- '

