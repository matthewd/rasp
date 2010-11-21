module Rasp::AST

class File < Node
  include Rasp::Compiler::LocalVariables

  attr_accessor :compiler
  attr_accessor :statements
  def global; self; end
  def explicit?; @explicit; end
  def explicit!; @explicit = true; end
  def initialize(statements)
    @statements = statements
  end
  def globals; @globals ||= {}; end
  def bytecode(g)
    g.push_state self
    statements.each do |s|
      s.bytecode(g)
    end
    g.pop_state
  end
  def prescan(g)
    g.push_state self
    statements.each do |s|
      s.prescan(g)
    end
    g.pop_state
  end

  def define_function(name, ast)
    p ast
    code = compiler.compile_function(ast)
    p code
  end
end

class LocalScope < Node
end

class FunctionDef < Node
  attr_accessor :name, :args, :body
  def initialize(name, args, body)
    @name, @args, @body = name, args, body
  end
  def bytecode(g)
  end
  def prescan(g)
    g.state.scope.define_function(@name, Rasp::AST::Function.new(@name, @args, @body))
  end
end
class SubDef < Node
  attr_accessor :name, :args, :body
  def initialize(name, args, body)
    @name, @args, @body = name, args, body
  end
  def bytecode(g)
  end
  def prescan(g)
    g.state.scope.define_function(@name, Rasp::AST::Sub.new(@name, @args, @body))
  end
end
class PropertyDef < Node
  attr_accessor :ptype, :name, :args, :body
  def initialize(ptype, name, args, body)
    @ptype, @name, @args, @body = ptype, name, args, body
  end
  def bytecode(g)
  end
  def prescan(g)
    klass = case ptype
            when :get; Rasp::AST::PropertyGet
            when :let; Rasp::AST::PropertyLet
            when :set; Rasp::AST::PropertySet
            end
    g.state.scope.define_function(@name, klass.new(@name, @args, @body))
  end
end

class Function < LocalScope
  include Rasp::Compiler::LocalVariables

  attr_accessor :name, :args, :body
  def initialize(name, args, body)
    @name, @args, @body = name, args, body
  end
  def explicit?; global.explicit?; end
  def bytecode(g)
    @global = g.state.scope.global
    g.push_state self
    @body.each do |s|
      s.bytecode(g)
    end
    g.pop_state
  end
  attr_reader :global
  def prescan(g)
    @global = g.state.scope.global
    g.push_state self
    @body.each do |s|
      s.prescan(g)
    end
    g.pop_state
  end
  def returns_value?; true; end
end
class Sub < Function
  def returns_value?; false; end
end
class PropertyGet < Function
end
class PropertyLet < Sub
end
class PropertySet < PropertyLet
end

end
