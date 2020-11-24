-- mpv script to play torrents in mpv (https://github.com/aitet/mpv-btfs-hook)

local settings = {
   download_directory = "/tmp/btfs",
}
local open_videos = {}

-- http://lua-users.org/wiki/StringRecipes
local function ends_with(str, ending)
        return ending == "" or str:sub(-#ending) == ending
end

local function dirLookup(dir)
   local p = io.popen('find "'..dir..'" -type f | head -n 1')  --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.
   for file in p:lines() do                         --Loop through all files
       return file
   end
end

function play_torrent()
        local url = mp.get_property("stream-open-filename")

        -- find if the url is a torrent or magnet link
        if (url:find("magnet:") == 1  or ends_with(url, "torrent")) then
                os.execute("mkdir -p " .. settings.download_directory)

        	mp.msg.verbose("Checks /etc/mtab if any btfs filesystems are mounted")
		local check_empty = os.execute("grep '^btfs' /etc/mtab 2>&1 >/dev/null")
		if check_empty == true then
        		mp.msg.verbose("Found mounted btfs")
        		os.execute("fusermount -u " .. settings.download_directory)
		end
                -- Mount the torrent with btfs
        	mp.msg.verbose("Mouting directory:" .. settings.download_directory)
                os.execute("btfs " .. url .. " " .. settings.download_directory)

                -- get the filename in the mounted dir
		local path = dirLookup(settings.download_directory)

		open_videos[url] = {url=url}
                mp.set_property("stream-open-filename", path)
        end
end

function torrent_cleanup()
	local url = mp.get_property("stream-open-filename")
        if open_videos[url] then
        	mp.msg.verbose("Unmouting directory:" .. settings.download_directory)
        	os.execute("fusermount -u " .. settings.download_directory)
      		open_videos[url] = {}
	end
end

mp.add_hook("on_load", 50, play_torrent)
mp.add_hook("on_unload", 10, torrent_cleanup)
