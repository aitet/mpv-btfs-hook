-- mpv script to play torrents in mpv (https://github.com/aitet/mpv-btfs-hook)
-- You can make it so btfs keeps files or limit the rate of download via the btfs_flags (see the btfs man page for more info)

local settings = {
   download_directory = "/tmp/btfs",
   btfs_flags = "",
}


(require "mp.options").read_options(settings, "btfs-hook")

local open_videos = {}

-- http://lua-users.org/wiki/StringRecipes
local function ends_with(str, ending)
        return ending == "" or str:sub(-#ending) == ending
end

local function dirLookup(dir)
   local p = io.popen('until [ -f ' .. dir .. '/* ]; do sleep 0.5 ;done ; find "'..dir..'" -type f | head -n 1')  --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.
   for file in p:lines() do                         --Loop through all files
       return file
   end
end

function play_torrent()
        local url = mp.get_property("stream-open-filename")

        -- find if the url is a torrent or magnet link
        if (url:find("magnet:") == 1  or ends_with(url, "torrent")) then
		-- set random seed and get folder name between 1000 to 9999.
		math.randomseed(os.time())
		local folder = math.random(1000,9999)
		local dir = settings.download_directory .. "/" .. folder

                os.execute("mkdir -p " .. dir )
                -- Mount the torrent with btfs
        	mp.msg.verbose("Mouting directory:" .. dir)
                os.execute("btfs " .. settings.btfs_flags .. " '" .. url .. "' " .. dir)

                -- get the filename in the mounted dir
		local path = dirLookup(dir)

		open_videos[url] = {url=url,path=path,dir=dir}
                mp.set_property("stream-open-filename", path)
        end
end

function torrent_cleanup()
	local url = mp.get_property("path")
        if open_videos[url] then
		local dir = open_videos[url].dir
        	mp.msg.verbose("Unmouting directory:" .. dir)
        	os.execute("fusermount -zu " .. dir)
		os.execute("rmdir '" .. dir .. "'")
      		open_videos[url] = {}
	end
end

mp.add_hook("on_load", 50, play_torrent)
mp.add_hook("on_unload", 10, torrent_cleanup)
