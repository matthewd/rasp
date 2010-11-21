# Stolen from poison; original code Copyright (c) 2010 Brian Ford.
module Rasp
  class Code
    def vb_rnd
      Kernel.rand
    end

    instance_methods.each do |m|
      alias_method m.to_s.sub(/^vb_/, 'vb:').intern, m if m.to_s =~ /^vb_/
    end
  end
  class Function < Code
    attr_accessor :name
    def arity; method(:call).arity; end
  end

  class Compiler
    module LocalVariables
      include Rubinius::Compiler::LocalVariables

      def new_local(name)
        variable = Rubinius::Compiler::LocalVariable.new allocate_slot
        variables[name] = variable
      end
      def variable(name)
        variables[name] || new_local(name)
      end

      def lookup_variable(g, var)
        if g.state.scope.variables.key?(var)
          loop_var = g.state.scope.variable(var).reference
        #elsif g.state.scope.global.variables.key?(var)
        #  loop_var = g.state.scope.global.variable(var).reference
        #elsif g.state.scope.global.supervariables.key?(var)
        #  loop_var = g.state.scope.global.supervariables[var].reference
        else
          # Couldn't find it anywhere.
          if explicit?
            raise "Unknown variable #{var}"
          else
            #loop_var = g.state.scope.global.variable(var).reference
            loop_var = g.state.scope.variable(var).reference
          end
        end
      end
    end

    attr_reader :g

    def initialize
      @g = Generator.new
    end

    def compile(ast, filename="(rasp)", line_number=1)
      @code = Rasp::Code.new

      g.name = :call
      g.file = filename.intern
      g.set_line line_number

      g.required_args = 0
      g.total_args = 0
      g.splat_index = nil

      g.local_count = 0
      g.local_names = []

      ast.compiler = self

      ast.prescan g
      ast.bytecode g
      g.ret
      g.close

      g.local_count = ast.local_count
      g.local_names = ast.local_names

      g.encode
      cm = g.package ::Rubinius::CompiledMethod
      puts cm.decode if $DEBUG

      ss = ::Rubinius::StaticScope.new Object
      ::Rubinius.attach_method g.name, cm, ss, @code

      @code
    end

    def compile_function(ast, filename="(function)", line_number=1)
      parent = g.state.scope

      gg = Generator.new
      gg.name = :"vb:#{ast.name}"
      gg.file = filename.intern
      gg.set_line line_number

      arg_names = ast.args || []
      p arg_names

      gg.required_args = arg_names.size
      gg.total_args = arg_names.size
      gg.splat_index = nil

      gg.local_count = 0
      gg.local_names = []

      args = arg_names.map {|arg| ast.new_local(arg) }
      args.each do |arg|
        #arg.reference.set_bytecode(gg)
        #gg.pop
      end

      result = ast.new_local(ast.name) if ast.returns_value?

      gg.push_state parent
      ast.prescan gg
      ast.bytecode gg
      gg.pop_state

      if ast.returns_value?
        result.reference.get_bytecode(gg)
      else
        gg.push_nil
      end
      gg.ret
      gg.close

      gg.local_count = ast.local_count
      gg.local_names = ast.local_names

      gg.encode
      cm = gg.package ::Rubinius::CompiledMethod
      puts cm.decode if $DEBUG

      code = Rasp::Function.new
      code.name = ast.name
      ss = ::Rubinius::StaticScope.new Object
      ::Rubinius.attach_method gg.name, cm, ss, @code

      code
    end
  end

  class Generator < Rubinius::Generator
    attr_accessor :constants
    def initialize
      super
      @constants = {}
    end

    def giz(label)
      a, b = new_label, new_label

      dup
      gif a

      meta_push_0
      meta_send_op_equal find_literal(:==)
      git label
      goto b

      a.set!
      pop
      goto label

      b.set!
    end
    def gnz(label)
      a, b = new_label, new_label

      dup
      gif a

      meta_push_0
      meta_send_op_equal find_literal(:==)
      gif label
      goto b

      a.set!
      pop

      b.set!
    end
  end
end
