<%

Const zx = 73

Sub w(s)
	Response.Write s & vbCrLf
End Sub
Dim a
'For a = 5 To -2 Step -1
For a = -2 To 5
	w ""
	w "a = " & a & " :: " & zx
	Select Case a
		Case 1
			w " Foo"
		Case 2, 3
			w " Bar"
		Case 4
			w " Quux"
		Case Else
			w " Baz"
	End Select
	If a > 2 Then
		w " X-Foo"
	Else
		w " X-Bar"
	End If

	If a < 4 Then w " a less 4": w " lesslessless" Else w " a gte 4": w " gtgtgt"

	If a > 4 Then w " a gt 4" Else If a > 2 Then w " a gt 2 but le 4" Else w " a le 2"

	w ""
	%><p><%=a%></p><%=a + 7%><%
Next

%>
