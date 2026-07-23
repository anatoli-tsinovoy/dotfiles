-- Open in Neovim
-- Opens files in Ghostty with Neovim, creating a new tab for each file
-- Saved as an application droplet to handle file open events

on open theItems
	repeat with f in theItems
		set p to POSIX path of f
		my openInGhosttyAndVim(p)
	end repeat
end open

on openInGhosttyAndVim(p)
	set d to do shell script "dirname " & quoted form of p
	set cmd to "/bin/zsh -lc " & quoted form of ("cd -- " & quoted form of d & " && exec nvim -- " & quoted form of p)
	
	tell application "Ghostty"
		activate
		
		set surfaceConfiguration to new surface configuration
		set command of surfaceConfiguration to cmd
		
		if (count of windows) = 0 then
			new window with configuration surfaceConfiguration
		else
			new tab in front window with configuration surfaceConfiguration
		end if
	end tell
end openInGhosttyAndVim
