module Rasp::AST

class Loop < Node
  attr_accessor :type, :body
  def initialize(type, body)
    @type, @body = type, body
  end

  def bytecode(g)
    top = g.new_label
    top.set!

    @body.bytecode(g)
    g.goto top
  end
end
class DoWhile < Loop
  attr_accessor :condition
  def initialize(type, condition, invert, body)
    super(type, body)
    @condition = invert ? NotExpr.new(condition) : condition
  end
  def bytecode(g)
    top = g.new_label
    done = g.new_label
    top.set!

    @condition.bytecode(g)
    g.meta_push_0
    g.meta_send_op_eq
    g.giz done

    @body.bytecode(g)
    g.goto top

    done.set!
  end
end
class LoopWhile < DoWhile
  def bytecode(g)
    top = g.new_label
    top.set!

    @body.bytecode(g)

    @condition.bytecode(g)
    g.gnz top
  end
end
class ForLoop < Loop
  attr_accessor :var, :start, :finish, :step
  def initialize(var, start, finish, step, body)
    super(:for, body)
    @var, @start, @finish, @step = var, start, finish, step
  end
  def bytecode(g)
    # TODO
  end
end
class ForEachLoop < Loop
  attr_accessor :var, :collection
  def initialize(var, collection, body)
    super(:for, body)
    @var, @collection = var, collection
  end
  def bytecode(g)
    # TODO
  end
end

class If < Node
  attr_accessor :condition, :true_body, :false_body
  def initialize(condition, true_body, false_body)
    @condition, @true_body, @false_body = condition, true_body, false_body
  end

  def bytecode(g)
    done = g.new_label
    false_label = g.new_label

    @condition.bytecode(g)
    g.giz false_label

    @true_body.bytecode(g)
    g.goto done

    false_label.set!
    @false_body.bytecode(g)

    done.set!
  end
end

class SelectCase < Container
  attr_accessor :expr, :cases, :else_body
  def initialize(expr, cases, else_body)
    @expr, @cases, @else_body = expr, cases, else_body
  end

  def bytecode(g)
    done = new_label
    @expr.bytecode(g)
    @cases.each do |c|
      c.bytecode(g, done)
    end
    @else_body.bytecode(g) if @else_body
    done.set!
  end
end
class Case < Node
  attr_accessor :matches, :body
  def initialize(matches, body)
    @matches, @body = matches, body
  end
  def bytecode(g, done)
    body_label = new_label unless matches.size == 1
    failed_match = new_label

    matches.each do |m|
      dup_top
      m.bytecode(g)
      meta_send_op_eq find_literal(:==)
      if m == matches.last
        giz failed_match
      else
        gnz body_label
      end
    end

    body_label.set! unless matches.size == 1
    @body.bytecode(g)
    goto done

    failed_match.set!
  end
end

end
