' PDF2PDFOCR
'
' This VBS script must be used in Windows installations (Cygwin).
' to let the final user use the "Send To" menu option in Windows Explorer.
' Please copy it to "shell:sendto" folder and create a shortcut.
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

' Return true is OS is 64 bits
Function Is64BitOS()
    Const Path = "winmgmts:root\cimv2:Win32_Processor='cpu0'"
    Is64BitOS = (GetObject(Path).AddressWidth = 64)
End Function

' Read a value from default registry.
' If value cannot be found and architecture is 64 bit, then try 32 bit registry
function readRegistry (strRegistryKey, strValue, strDefault)
	Dim WSHShell, value
	On Error Resume Next
	Set WSHShell = CreateObject("WScript.Shell")
	value = WSHShell.RegRead(strRegistryKey & "\" & strValue)
	if err.number = 0 then
		readRegistry=value
	else
		if Is64BitOS() then
			regCommand = execCommand("FOR /F ""usebackq skip=2 tokens=1-2*"" %A IN (`REG QUERY " & strRegistryKey & " /v " & strValue & " /reg:32 2^>nul`) do @echo %C")
			outRegCommand = regCommand(0)
			outRegStr = join(outRegCommand)
			if outRegStr <> "" then
				readRegistry = outRegStr
			else
				readRegistry = strDefault
			end if
		else
			readRegistry=strDefault
		end if
	end if
	set WSHShell = nothing
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

' Find cygwin root dir
path_cygwin = readRegistry("HKEY_LOCAL_MACHINE\SOFTWARE\Cygwin\setup", "rootdir", "")
if path_cygwin = "" then
	path_cygwin = readRegistry("HKEY_CURRENT_USER\SOFTWARE\Cygwin\setup", "rootdir", "")
end if
' WScript.echo "Cygwin path is: " & path_cygwin

' Get actual options from script to show help
helpOut = execCommand(path_cygwin & "\bin\bash.exe --login pdf2pdfocr.sh -?")
WScript.Echo helpOut(1)(0)
WScript.StdOut.Write("Please enter options. Press Enter for default [-s -t] > ")
WScript.StdIn.Read(0)
options = WScript.StdIn.ReadLine()
if options = "" then
	options = "-s -t"
end if
' MsgBox options

' Call pdf2pdfocr script to all files passed as arguments
set objArgs = WScript.Arguments 
for i = 0 to objArgs.Count - 1 
	WScript.Echo "Processing " & objArgs(i) & " ..."
	scriptOut = execCommand(path_cygwin & "\bin\bash.exe --login pdf2pdfocr.sh " & options & " """ & objArgs(i) & """")
	' Cygwin send "clear screen sequence" in stdout. I will remove them
	WScript.Echo " --> Output:"
	For j = 0 to uBound(scriptOut(0))
		message = scriptOut(0)(j)
		message = Replace (message, Chr(27)&"[H"&Chr(27)&"[J", "", 1, -1, vbTextCompare)
		WScript.Echo message
	Next
	WScript.Echo " --> Errors/Warnings:"
	For k = 0 to uBound(scriptOut(1))
		message = scriptOut(1)(k)
		message = Replace (message, Chr(27)&"[H"&Chr(27)&"[J", "", 1, -1, vbTextCompare)
		WScript.Echo message
	Next
	WScript.Echo "---------------------------------------"
next
Pause("Press Enter to continue...")