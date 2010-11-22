require 'citrus'
Citrus.load( File.dirname(__FILE__) + '/parser' )

class << Rasp::Parser
  def read(string, root=nil)
    self.parse(string, :consume => true, :root => root)
  end
end

