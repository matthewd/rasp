# rasp

A VBScript runtime, running on the Rubinius VM.


Untested, undocumented, and ill-advised.



## Usage

Given `t/easy.vbs`:

    Option Explicit
    
    Const MIN = 1
    Const MAX = 10
    
    Function fib(n)
       If n < 3 Then
          fib = 1
       Else
          fib = fib(n - 2) + fib(n - 1)
       End If
    End Function
    
    Dim i
    For i = MIN To MAX
       WScript.Echo "fib(" & i & ") = " & fib(i)
    Next

Run:

    bin/rasp t/easy.vbs --run

And you'll see:

    fib(1) = 1
    fib(2) = 1
    fib(3) = 2
    fib(4) = 3
    fib(5) = 5
    fib(6) = 8
    fib(7) = 13
    fib(8) = 21
    fib(9) = 34
    fib(10) = 55

