<%

Dim o
Set o = Server.CreateObject("Scripting.Dictionary")

o.Add "foo", "bar"
o.Add "baz", "quux"

Response.Write o("foo") & vbCrLf & vbCrLf

o("foo") = o("baz")

Response.Write o("foo")

%>
