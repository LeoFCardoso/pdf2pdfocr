' PDF2PDFOCR
'
' This VBS script must be used in Windows installations.
' to let the final user use the "Send To" menu option in Windows Explorer.
' Please copy it to "shell:sendto" folder or create a shortcut.
' Ref.: http://www.howtogeek.com/howto/windows-vista/customize-the-windows-vista-send-to-menu/
'

' ******* FUNCTIONS ***

' Run command, without any window and return stdout and stderr as arrays of strings
' Uses temp files
' Stdout - position 0
' Stderr - position 1
function execCommand(cmd)
	Set WSHShell = CreateObject("Wscript.Shell")
	Set fso = CreateObject("Scripting.FileSystemObject")
	tempOut = fso.GetTempName
	tempErr = fso.GetTempName
	path = fso.GetSpecialFolder(2) 'TemporaryFolder
	tempOut = path & "\" & tempOut
	tempErr = path & "\" & tempErr
	full_command = cmd & " > " & tempOut & " 2> " & tempErr
	WSHShell.Run "%comspec% /c " & full_command, 0, true
	arResultsOut = Split ("")
	if CreateObject("Scripting.FileSystemObject").GetFile(tempOut).size > 0 Then
		arResultsOut = Split(fso.OpenTextFile(tempOut).ReadAll,vbcrlf)
	end if
	arResultsErr = Split ("")
	if CreateObject("Scripting.FileSystemObject").GetFile(tempErr).size > 0 Then
		arResultsErr = Split(fso.OpenTextFile(tempErr).ReadAll,vbcrlf)
	end if
	fso.DeleteFile tempOut
	fso.DeleteFile tempErr
	Dim functionOut(1)
	functionOut(0) = arResultsOut
	functionOut(1) = arResultsErr
	execCommand = functionOut
end function

' Credits - http://stackoverflow.com/questions/4692542/force-a-vbs-to-run-using-cscript-instead-of-wscript
Sub forceCScriptExecution
    Dim Arg, Str
    If Not LCase( Right( WScript.FullName, 12 ) ) = "\cscript.exe" Then
        For Each Arg In WScript.Arguments
            If InStr( Arg, " " ) Then Arg = """" & Arg & """"
            Str = Str & " " & Arg
        Next
        CreateObject( "WScript.Shell" ).Run _
            "cscript //nologo //I """ & _
            WScript.ScriptFullName & _
            """ " & Str
        WScript.Quit
    End If
End Sub

' Emulate pause CMD
Sub Pause(strPause)
     WScript.Echo (strPause)
     z = WScript.StdIn.Read(1)
End Sub
	
' ******* MAIN ***
forceCScriptExecution

' Get last options used
Set oShell = CreateObject("WScript.Shell")
strHomeFolder = oShell.ExpandEnvironmentStrings("%USERPROFILE%")
strLastOptionFile = strHomeFolder & "\.pdf2pdfocr.txt"
Const ForReading = 1
Set objFSO = CreateObject("Scripting.FileSystemObject")
On Error Resume Next
Set objFile = objFSO.OpenTextFile(strLastOptionFile, ForReading)
If Err.Number <> 0 Then
    lastOptionUsed = ""
Else
	lastOptionUsed = objFile.ReadAll
	objFile.Close
End If
On Error Goto 0
' Get actual options from script to show help
helpOut = execCommand("python " & strHomeFolder & "\pdf2pdfocr\pdf2pdfocr.py --help")
For Each helpMessage In helpOut(0)
	WScript.StdOut.WriteLine(helpMessage)
Next
WScript.StdOut.WriteLine("Please enter options.")
WScript.StdOut.WriteLine("Use <Enter> for default [-s -t] or <.> for last used option [" & lastOptionUsed & "].")
WScript.StdOut.Write(">> ")
WScript.StdIn.Read(0)
options = WScript.StdIn.ReadLine()
RewriteLastOptionFile = True
if options = "" then
	options = "-s -t"
	RewriteLastOptionFile = False
end if
if options = "." then
	options = lastOptionUsed
	RewriteLastOptionFile = False
end if
if RewriteLastOptionFile Then
	Set objFileW = objFSO.CreateTextFile(strLastOptionFile)
	objFileW.Write(options)
	objFileW.Close
end if
' Call pdf2pdfocr script to all files passed as arguments
set objArgs = WScript.Arguments 
for i = 0 to objArgs.Count - 1 
	WScript.Echo "Processing " & objArgs(i) & " ..."
	scriptOut = execCommand("python " & strHomeFolder & "\pdf2pdfocr\pdf2pdfocr.py " & options & " -j 0.9 -i """ & objArgs(i) & """")
	WScript.Echo " --> Output:"
	For j = 0 to uBound(scriptOut(0))
		message = scriptOut(0)(j)
		WScript.Echo message
	Next
	WScript.Echo " --> Errors/Warnings:"
	For k = 0 to uBound(scriptOut(1))
		message = scriptOut(1)(k)
		WScript.Echo message
	Next
	WScript.Echo "---------------------------------------"
next
Pause("Press Enter to continue...")