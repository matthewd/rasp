module Rasp::AST

class Statement < Node
end
class Assignment < Statement
  attr_accessor :var, :newval
  def initialize(var, newval)
    @var, @newval = var, newval
  end
  def bytecode(g)
    if g.state.scope.variables.key? var
      ref = g.state.scope.variable(var).reference
    else
      ref = g.state.scope.global.variable(var).reference
    end

    @newval.bytecode(g)
    ref.set_bytecode(g)
    g.pop
  end
end
class SetAssignment < Assignment
end
class ConstAssignment < Assignment
  def bytecode(g)
    if g.constants.key? @var
      raise "Duplicate constant: #@var"
    end

    # @newval is syntactically guaranteed to be a Literal.
    g.constants[@var] = @newval.value
  end
end
class Declaration < Statement
  attr_accessor :vars
  def initialize(vars)
    @vars = vars
  end
  def bytecode(g)
    vars.each do |var|
      g.state.scope.variable(var)
    end
  end
end
class ErrorControl < Statement
  attr_accessor :continue
  def initialize(continue)
    @continue = continue
  end
end
class ExitStatement < Statement
  attr_accessor :type
  def initialize(type)
    @type = type
  end
end
class OptionExplicit < Statement
  def bytecode(g)
    # Compile option only
  end
end
class Randomize < Statement
  attr_accessor :seed
  def initialize(seed=nil)
    @seed = seed
  end
end

end
