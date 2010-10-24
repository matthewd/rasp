
Class Foo
	Public Sub DoStuff
		Out Something
	End Sub
	Public Sub Out(s)
		WScript.Echo s
	End Sub
	Public Function Something
		Something = "Some return value"
	End Function
	Public Sub Class_Terminate
		WScript.Echo "Terminating!"
	End Sub
End Class

Dim o: Set o = New Foo

o.DoStuff

