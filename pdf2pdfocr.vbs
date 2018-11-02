' PDF2PDFOCR
'
' This VBS script must be used in Windows installations.
' to let the final user use the "Send To" menu option in Windows Explorer.
' Please copy it to "shell:sendto" folder or create a shortcut.
' Ref.: http://www.howtogeek.com/howto/windows-vista/customize-the-windows-vista-send-to-menu/
'

' ******* FUNCTIONS ***

' Run command - see https://www.codeproject.com/Tips/507798/Differences-between-Run-and-Exec-VBScript
function execCommand(cmd)
	Set WSHShell = CreateObject("Wscript.Shell")
	comspec = WSHShell.ExpandEnvironmentStrings("%comspec%")
	Set objExec = WSHShell.Exec(comspec & " /c " & cmd)
	Do
		WScript.StdOut.WriteLine(objExec.StdOut.ReadLine())
	Loop While Not objExec.Stdout.atEndOfStream
	WScript.StdOut.WriteLine(objExec.StdOut.ReadAll)
	WScript.StdErr.WriteLine(objExec.StdErr.ReadAll)
	'
	execCommand = true
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
' Set up paths
python_venv_path = strHomeFolder & "\pdf2pdfocr-venv\Scripts\python"
pdf2pdfocr_path = strHomeFolder & "\pdf2pdfocr-venv\Scripts\pdf2pdfocr.py"
' Get actual options from script to show help
helpOut = execCommand(python_venv_path & " " & pdf2pdfocr_path & " --help")
WScript.StdOut.WriteLine("Please enter options.")
default_option = "-stp -j 0.9"
WScript.StdOut.WriteLine("Use <Enter> for default [" & default_option & "] or <.> for last used option [" & lastOptionUsed & "].")
WScript.StdOut.Write(">> ")
WScript.StdIn.Read(0)
options = WScript.StdIn.ReadLine()
RewriteLastOptionFile = True
if options = "" then
	options = default_option
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
	scriptOut = execCommand(python_venv_path & " " & pdf2pdfocr_path & " " & options & " -i """ & objArgs(i) & """")
	WScript.Echo "---------------------------------------"
next
Pause("Press Enter to continue...")