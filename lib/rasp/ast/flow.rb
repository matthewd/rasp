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
  # Contrary to my original expectation, not having used VBScript in
  # ages, all three of (start, finish, step) are fixed at loop start.

  attr_accessor :var, :start, :finish, :step
  def initialize(var, start, finish, step, body)
    super(:for, body)
    @var, @start, @finish, @step = var, start, finish, step
  end
  def bytecode(g)
    # TODO
    if g.state.scope.variables.key? var
      loop_var = g.state.scope.variable(var).reference
    else
      loop_var = g.state.scope.global.variable(var).reference
    end
    @finish.bytecode(g)
    @step.bytecode(g) if @step
    unless Rasp::AST::Literal === @step || @step.nil?
      g.dup
      g.meta_push_0
      g.send_stack :<, 1
    end

    @start.bytecode(g)
    loop_var.set_bytecode(g)
    loop_body = g.new_label
    loop_body.set!
    @body.each do |s|
      #s.bytecode(g)
    end

    if Rasp::AST::Literal === @step || @step.nil?
      # Step is constant

      if @step
        g.dup_many 2 # @step, @finish, ...
        loop_var.get_bytecode(g)
        g.send_stack :+, 1
      else
        g.dup # @finish, ...
        loop_var.get_bytecode(g)
        g.send_vcall :inc
      end
      g.dup
      loop_var.set_bytecode(g)

      if @step.nil? || @step.value > 0
        # Always working forwards
        g.send_stack :>, 1
      elsif @step.value < 0
        # Always working backwards
        g.send_stack :<, 1
      else
        # Constant step of zero?! Twit.
        raise "For loop cannot have a zero step"
      end

      g.gif loop_body

      if @step
        g.pop_many 2
      else
        g.pop
      end
    else
      raise "dynstep!"
      # Dynamic step; have to work out which way we're going at runtime
      # Experimentation shows this isn't as scary as it seems; the
      # reference implementation only evaluates the Step value once, as
      # the loop starts.
      #
      # In theory, we could apply some clever logic based on the size of
      # @body, to decide whether we're better off paying an extra git
      # per iteration at runtime vs having two separate copies of the
      # loop. No idea whether that'd be actually useful.

      check_backwards = g.new_label
      end_loop = g.new_label

      g.dup_many 3 # loop_backwards, @step, @finish, ...
      loop_var.get_bytecode(g)
      g.send_stack :+, 1
      g.dup
      loop_var.set_bytecode(g)

      g.git check_backwards
      g.send_stack :>, 1
      g.gif loop_body
      g.goto end_loop

      check_backwards.set!
      g.send_stack :<, 1
      g.gif loop_body

      end_loop.set!
      g.pop_many 3
    end
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
    body_label = g.new_label unless matches.size == 1
    failed_match = g.new_label

    matches.each do |m|
      g.dup
      m.bytecode(g)
      g.meta_send_op_eq find_literal(:==)
      if m == matches.last
        g.giz failed_match
      else
        g.gnz body_label
      end
    end

    body_label.set! unless matches.size == 1
    @body.bytecode(g)
    g.goto done

    failed_match.set!
  end
end

end
