-- Open in Neovim
-- Opens files in iTerm2 with Neovim, creating a new tab for each file
-- Saved as an application droplet to handle file open events

on open theItems
	repeat with f in theItems
		set p to POSIX path of f
		my openInITermAndVim(p)
	end repeat
end open

on openInITermAndVim(p)
	set d to do shell script "dirname " & quoted form of p
	set cmd to "/bin/zsh -lc " & quoted form of ("cd -- " & quoted form of d & " && exec nvim -- " & quoted form of p)
	
	tell application "iTerm"
		activate
		
		if (count of windows) = 0 then
			create window with default profile command cmd
		else
			tell current window
				create tab with default profile command cmd
			end tell
		end if
	end tell
end openInITermAndVim
