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
end
class Declaration < Statement
  attr_accessor :var
  def initialize(var)
    @name = var
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
end
class Randomize < Statement
  attr_accessor :seed
  def initialize(seed=nil)
    @seed = seed
  end
end

end
