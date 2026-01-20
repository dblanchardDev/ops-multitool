# spell-checker: disable
<#
.SYNOPSIS
	Simple Textbased PowerShell Menu

.NOTES
	Author : Michael Albert
	E-Mail : info@michlstechblog.info
	License: none, feel free to modify

	Modification by David Blanchard, includes:
		- Change entries parameter from hash table to ordered dictionary
		- Add the option to display menu with quit option.
		- Other small changes and adding help comments.
#>


function InteractiveMenu {
	<#
	.SYNOPSIS
		Ask user to choose an option from a text based menu.
	.PARAMETER prompt
		Text prompt to display to user above the entries.
	.PARAMETER entries
		Ordered dictionary of entries to display to user. The key is internal, whereas the value will be displayed to the user. E.g. [ordered]@{[string]"ReturnString1"[string]"Menu Entry 1";[string]"ReturnString2"=[string]"Menu Entry 2"}
	.OUTPUTS
		String. The key corresponding to the entry chosen by the user.
	.EXAMPLE
		$options = [ordered]@{"mk"="Marketing";"ac"="Accounting";"sl"="Sales";"sp"="Support"}
		$selection = InteractiveMenu "Choose a department" $options
	#>
	[OutputType([String])]
	param(
		[parameter(Mandatory=$true)]
		[System.String]
		$prompt,
		[parameter(Mandatory=$true)]
		[System.Collections.Specialized.OrderedDictionary]
		$entries
	)

	# Orginal Konsolenfarben zwischenspeichern
	[System.Int16]$iSavedBackgroundColor=[System.Console]::BackgroundColor
	[System.Int16]$iSavedForegroundColor=[System.Console]::ForegroundColor
	# Menu Colors
	# inverse fore- and backgroundcolor
	[System.Int16]$iMenuForeGroundColor=$iSavedForegroundColor
	[System.Int16]$iMenuBackGroundColor=$iSavedBackgroundColor
	[System.Int16]$iMenuBackGroundColorSelectedLine=$iMenuForeGroundColor
	[System.Int16]$iMenuForeGroundColorSelectedLine=$iMenuBackGroundColor
	# Alternative, colors
	#[System.Int16]$iMenuBackGroundColor=0
	#[System.Int16]$iMenuForeGroundColor=7
	#[System.Int16]$iMenuBackGroundColorSelectedLine=10
	# Init
	[System.Int16]$iMenuStartLineAbsolute=0
	[System.Int16]$iMenuLoopCount=0
	[System.Int16]$iMenuSelectLine=1
	[System.Int16]$iMenuEntries=$entries.Count
	[Hashtable]$hMenu=@{};
	[Hashtable]$hMenuHotKeyList=@{};
	[Hashtable]$hMenuHotKeyListReverse=@{};
	[System.Int16]$iMenuHotKeyChar=0
	[System.String]$sValidChars=""
	[System.Console]::WriteLine(" "+$prompt)
	# Für die eindeutige Zuordnung Nummer -> Key
	$iMenuLoopCount=1
	# Start Hotkeys mit "1"!
	$iMenuHotKeyChar=49
	foreach ($sKey in $entries.Keys){
		$hMenu.Add([System.Int16]$iMenuLoopCount,[System.String]$sKey)
		# Hotkey zuordnung zum Menueintrag
		$hMenuHotKeyList.Add([System.Int16]$iMenuLoopCount,[System.Convert]::ToChar($iMenuHotKeyChar))
		$hMenuHotKeyListReverse.Add([System.Convert]::ToChar($iMenuHotKeyChar),[System.Int16]$iMenuLoopCount)
		$sValidChars+=[System.Convert]::ToChar($iMenuHotKeyChar)
		$iMenuLoopCount++
		$iMenuHotKeyChar++
		# Weiter mit Kleinbuchstaben
		if($iMenuHotKeyChar -eq 58){$iMenuHotKeyChar=97}
		# Weiter mit Großbuchstaben
		elseif($iMenuHotKeyChar -eq 123){$iMenuHotKeyChar=65}
		# Jetzt aber ende
		elseif($iMenuHotKeyChar -eq 91){
			Write-Error " Menu too big!"
			exit(99)
		}
	}
	# Remember Menu start
	[System.Int16]$iBufferFullOffset=0
	$iMenuStartLineAbsolute=[System.Console]::CursorTop
	do{
		####### Draw Menu  #######
		[System.Console]::CursorTop=($iMenuStartLineAbsolute-$iBufferFullOffset)
		for ($iMenuLoopCount=1;$iMenuLoopCount -le $iMenuEntries;$iMenuLoopCount++){
			[System.Console]::Write("`r")
			[System.String]$sPreMenuline=""
			$sPreMenuline="  "+$hMenuHotKeyList[[System.Int16]$iMenuLoopCount]
			$sPreMenuline+=": "
			if ($iMenuLoopCount -eq $iMenuSelectLine){
				[System.Console]::BackgroundColor=$iMenuBackGroundColorSelectedLine
				[System.Console]::ForegroundColor=$iMenuForeGroundColorSelectedLine
			}
			if ($entries.Item([System.String]$hMenu.Item($iMenuLoopCount)).Length -gt 0){
				[System.Console]::Write($sPreMenuline+$entries.Item([System.String]$hMenu.Item($iMenuLoopCount)))
			}
			else{
				[System.Console]::Write($sPreMenuline+$hMenu.Item($iMenuLoopCount))
			}
			[System.Console]::BackgroundColor=$iMenuBackGroundColor
			[System.Console]::ForegroundColor=$iMenuForeGroundColor
			[System.Console]::WriteLine("")
		}
		[System.Console]::BackgroundColor=$iMenuBackGroundColor
		[System.Console]::ForegroundColor=$iMenuForeGroundColor
		[System.Console]::Write("  Your choice: " )
		if (($iMenuStartLineAbsolute+$iMenuLoopCount) -gt [System.Console]::BufferHeight){
			$iBufferFullOffset=($iMenuStartLineAbsolute+$iMenuLoopCount)-[System.Console]::BufferHeight
		}
		####### End Menu #######
		####### Read Kex from Console
		$oInputChar=[System.Console]::ReadKey($true)
		# Down Arrow?
		if ([System.Int16]$oInputChar.Key -eq [System.ConsoleKey]::DownArrow){
			if ($iMenuSelectLine -lt $iMenuEntries){
				$iMenuSelectLine++
			}
		}
		# Up Arrow
		elseif([System.Int16]$oInputChar.Key -eq [System.ConsoleKey]::UpArrow){
			if ($iMenuSelectLine -gt 1){
				$iMenuSelectLine--
			}
		}
		elseif([System.Char]::IsLetterOrDigit($oInputChar.KeyChar)){
			[System.Console]::Write($oInputChar.KeyChar.ToString())
		}
		[System.Console]::BackgroundColor=$iMenuBackGroundColor
		[System.Console]::ForegroundColor=$iMenuForeGroundColor
	} while(([System.Int16]$oInputChar.Key -ne [System.ConsoleKey]::Enter) -and ($sValidChars.IndexOf($oInputChar.KeyChar) -eq -1))

	# reset colors
	[System.Console]::ForegroundColor=$iSavedForegroundColor
	[System.Console]::BackgroundColor=$iSavedBackgroundColor
	if($oInputChar.Key -eq [System.ConsoleKey]::Enter){
		[System.Console]::Writeline($hMenuHotKeyList[$iMenuSelectLine])
		return([System.String]$hMenu.Item($iMenuSelectLine))
	}
	else{
		[System.Console]::Writeline("")
		return($hMenu[$hMenuHotKeyListReverse[$oInputChar.KeyChar]])
	}
}


function InteractiveMenuWithQuit {
	<#
	.SYNOPSIS
		Ask user to choose an option from a text based menu, adding an option to quit.
	.PARAMETER prompt
		Text prompt to display to user above the entries.
	.PARAMETER entries
		Ordered dictionary of entries to display to user. The key is internal, whereas the value will be displayed to the user. E.g. [ordered]@{[string]"ReturnString1"[string]"Menu Entry 1";[string]"ReturnString2"=[string]"Menu Entry 2"}
	.OUTPUTS
		String. The key corresponding to the entry chosen by the user. If the user quits, this value will be null.
	.EXAMPLE
		$options = [ordered]@{"mk"="Marketing";"ac"="Accounting";"sl"="Sales";"sp"="Support"}
		$selection = InteractiveMenuWithQuit "Choose a department" $options
	#>

	[OutputType([String])]
	param(
		[parameter(Mandatory=$true)]
		[System.String]
		$prompt,
		[parameter(Mandatory=$true)]
		[System.Collections.Specialized.OrderedDictionary]
		$entries,
		[System.String]
		$quitLabel = "QUIT"
	)

	$QuitKey = "______QUIT______"
	$entries.Add($QuitKey, "<< $($quitLabel.ToUpper()) >>")
	$selection = InteractiveMenu $prompt $entries

	if ($selection -eq $QuitKey) {
		$selection = $null
	}

	return $selection
}