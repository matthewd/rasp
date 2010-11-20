# Stolen from poison; original code Copyright (c) 2010 Brian Ford.
module Rasp
  class Code
  end

  class Compiler
    attr_reader :g

    def initialize
      @g = Generator.new
    end

    def compile(ast, filename="(rasp)", line_number=1)
      g.name = :call
      g.file = filename.intern
      g.set_line line_number

      g.required_args = 0
      g.total_args = 0
      g.splat_index = nil

      g.local_count = 0
      g.local_names = []

      ast.bytecode self
      g.ret
      g.close

      g.encode
      cm = g.package ::Rubinius::CompiledMethod
      puts cm.decode if $DEBUG

      code = Rasp::Code.new
      ss = ::Rubinius::StaticScope.new Object
      ::Rubinius.attach_method g.name, cm, ss, code

      code
    end
  end

  class Generator < Rubinius::Generator
    def giz(label)
      dup_top
      gif label

      meta_push_0
      meta_send_op_eq find_literal(:==)
      git label
    end
    def gnz(label)
      f = new_label
      dup_top
      gif f # if it's false, don't compare to zero; just continue

      meta_push_0
      meta_send_op_eq find_literal(:==)
      gif label

      f.set!
    end
  end
end
