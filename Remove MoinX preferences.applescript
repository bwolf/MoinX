try
	do shell script "rm  ~/Library/Preferences/org.antbear.MoinX.plist"
	display dialog "Preferences file removed"
on error
	display dialog "There was an error removing the preferences file.
Maybe the file was already removed."
end try