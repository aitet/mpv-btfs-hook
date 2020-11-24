-- mpv script to play torrents in mpv (https://github.com/aitet/mpv-btfs-hook)

local settings = {
   download_directory = "/tmp/btfs/",
}
local open_videos = {}

-- http://lua-users.org/wiki/StringRecipes
local function ends_with(str, ending)
        return ending == "" or str:sub(-#ending) == ending
end

local function dirLookup(dir)
   local p = io.popen('find "'..dir..'" -type f')  --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.
   for file in p:lines() do                         --Loop through all files
       return file
   end
end

function play_torrent()
        local url = mp.get_property("stream-open-filename")

        -- find if the url is a torrent or magnet link
        if (url:find("magnet:") == 1  or ends_with(url, "torrent")) then
                os.execute("mkdir -p " .. settings.download_directory)
		local is_empty = dirLookup(settings.download_directory)
		if is_empty then
        		os.execute("fusermount -u " .. settings.download_directory)
		end
                -- Mount the torrent with btfs and exit if it can't execute the command
        	mp.msg.verbose("Mouting directory:" .. settings.download_directory)
                os.execute("btfs " .. url .. " " .. settings.download_directory)

		--
		local path = dirLookup(settings.download_directory)
                -- get the filename in the mounted dir
                mp.set_property("stream-open-filename", path)
        end
end

function torrent_cleanup()
        local url = mp.get_property("stream-open-filename")

        -- find if the url is a torrent or magnet link
        if (url:find("magnet:") == 1  or ends_with(url, "torrent")) then
        	mp.msg.verbose("Unmouting directory:" .. settings.download_directory)
        	os.execute("fusermount -u " .. settings.download_directory)
      		open_videos[url] = {}
	end
end

mp.add_hook("on_load", 50, play_torrent)
mp.add_hook("on_unload", 10, torrent_cleanup)
