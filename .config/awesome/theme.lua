require("awful.util")
theme = dofile("/usr/share/awesome/themes/default/theme.lua")
theme.wallpaper_cmd = { "awsetbg -T " .. awful.util.getdir("config") .. "/wallpapers/crissXcross-test.png" }
return theme
