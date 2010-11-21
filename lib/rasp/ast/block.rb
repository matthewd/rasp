module Rasp::AST

class File < Node
  include Rasp::Compiler::LocalVariables

  attr_accessor :statements
  def explicit?; @explicit; end
  def explicit!; @explicit = true; end
  def lookup_variable(g, var)
    if g.state.scope.variables.key?(var)
      loop_var = g.state.scope.variable(var).reference
    elsif g.state.scope.global.variables.key?(var)
      loop_var = g.state.scope.global.variable(var).reference
    #elsif g.state.scope.global.supervariables.key?(var)
    #  loop_var = g.state.scope.global.supervariables[var].reference
    else
      # Couldn't find it anywhere.
      if explicit?
        raise "Unknown variable #{var}"
      else
        loop_var = g.state.scope.global.variable(var).reference
      end
    end
  end
  def initialize(statements)
    @statements = statements
  end
  def global; self; end
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
end

end
