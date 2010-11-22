require 'citrus'
Citrus.load( File.dirname(__FILE__) + '/parser' )

class << Rasp::Parser
  def nodes(string, root=nil)
    string = string.sub(/\n?$/, "\n")
    self.parse(string, :consume => true, :root => root).value
  end
end

