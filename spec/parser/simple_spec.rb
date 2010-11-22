require 'rasp'

describe "Option Explicit" do
  it "parses to an OptionExplicit node" do
    Rasp::Parser.nodes("Option Explicit", :statement).node_summary.should == "OptionExplicit"
  end
end

describe "Single Line If" do
  it "parses simple case" do
    Rasp::Parser.nodes("If True Then x", :statement).node_summary.should == "If<TrueValue,[NullCall],0>"
  end
end

