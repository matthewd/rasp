module Rasp::AST

class Statement < Node
end
class Assignment < Statement
  attr_accessor :var, :value
  def initialize(var, value)
    @var, @value = var, value
  end
end
class SetAssignment < Assignment
end
class ConstAssignment < Assignment
  def bytecode(g)
    if g.constants.key? @var
      raise "Duplicate constant: #@var"
    end

    # @value is syntactically guaranteed to be a Literal.
    g.constants[@var] = @value.value
  end
end
class Declaration < Statement
  attr_accessor :vars
  def initialize(vars)
    @vars = vars
  end
  def bytecode(g)
    # Compiler directive
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
