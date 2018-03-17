  ' Wscript.Arguments(0) => domain name
  ' Wscript.Arguments(1) => username
  ' Wscript.Arguments(2) => password
  ' Wscript.Arguments(3) => forwarding mail address

  On Error Resume Next
  Err.Clear
  
  If Wscript.Arguments.Count = 3 Or Wscript.Arguments.Count = 4 Then
    Dim obApp
    Set obApp = CreateObject("hMailServer.Application")

    If Err.Number = 0 Then
      Call obApp.Authenticate(Wscript.Arguments(1) & "@" & Wscript.Arguments(0), Wscript.Arguments(2))
   
      If Err.Number = 0 Then
        Dim obDomain
        Set obDomain = obApp.Domains.ItemByName(Wscript.Arguments(0))
   
        If Err.Number = 0 Then
          Dim obAccount
          Set obAccount = obDomain.Accounts.ItemByAddress(Wscript.Arguments(1) & "@" & Wscript.Arguments(0))
   
          If Err.Number = 0 Then
            If obAccount.ValidatePassword(Wscript.Arguments(2)) Then
              If Wscript.Arguments.Count = 4 Then ' activate forwarding
                obAccount.ForwardAddress      = Wscript.Arguments(3)
                obAccount.ForwardEnabled      = true
                obAccount.ForwardKeepOriginal = false
              Else ' deactivate forwarding
                obAccount.ForwardAddress      = ""
                obAccount.ForwardEnabled      = false
                obAccount.ForwardKeepOriginal = true
              End If
              obAccount.Save

              WScript.StdOut.WriteLine "0" ' forwarding set
            Else
              WScript.StdOut.WriteLine "1" ' password is not correct
            End If
          Else
            WScript.StdOut.WriteLine "2" ' account does not exist
          End If
          
          obAccount = Nothing
        Else
          WScript.StdOut.WriteLine "3" ' domain does not exist
        End If
        
        obDomain = Nothing
      Else
        WScript.StdOut.WriteLine "4" ' password is not correct
	  End If
    Else
      WScript.StdOut.WriteLine "5" ' hMailServer.Application not available
    End If
    
    Set obApp = Nothing
  Else
    WScript.StdOut.WriteLine "6" ' wrong number of arguments
  End If