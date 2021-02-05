--[[

script to make mpv play torrents/magnets directly using btfs

original script: https://gist.github.com/huglovefan/4c68bc40661b6701ca5fc6ce1157f192

requires:
- linux
- btfs
- xterm (optional)

usage:
- open a magnet link or torrent url using mpv and it should Just Work
- urls must end with ".torrent" to be detected by this

]]

-- see "btfs --help"
local btfs_args = {
	-- temporary directory to store downloaded data
	-- '--data-directory=', Using xdg by default
	-- you may want to make sure this is on a real filesystem and not tmpfs
	-- otherwise it might fill your ram when watching a big enough file

	-- these are in kB/s
	--'--max-download-rate=4900',
	'--max-upload-rate=500',
}

local mountdir = '/tmp/mpvbtfs'

-- Use xdg path
local xdgpath = os.getenv('XDG_DATA_HOME')
if (string.len(xdgpath) < 1) then
	datadir = (os.getenv('HOME')..'/.local/share/btfs')
else
	datadir = string.format('%s/btfs', xdgpath)
end
table.insert(btfs_args, [[--data-directory=]]..datadir)

-- list files from the mountpoint that should added to the playlist
local list_files = function (mountpoint)
	local p = assert(io.popen([[
	mountpoint=]]..shellquote(mountpoint)..'\n'..[[
	# -V = version sort. should sort anime episodes correctly
	find "$mountpoint" -type f | sort -V
	]]))
	local files = {}
	for line in p:lines() do
		table.insert(files, line)
		files[line] = #files -- save the position for the sort below
	end
	p:close()
	-- put files before directories but keep the sort order
	local count_slashes = function (path) return #path-#path:gsub('/', '') end
	table.sort(files, function (p1, p2)
		local c1 = count_slashes(p1)
		local c2 = count_slashes(p2)
		if c1 ~= c2 then
			return c1 < c2
		else
			return files[p1] < files[p2]
		end
	end)
	return files
end

--------------------------------------------------------------------------------

shellquote = function (s)
	return '\'' .. s:gsub('\'', '\'\\\'\'') .. '\''
end

local exec_ok = os.execute
if _VERSION == 'Lua 5.1' then
	exec_ok = function (...)
		return 0 == os.execute(...)
	end
end

--------------------------------------------------------------------------------

-- mountpoints mounted by us (will be unmounted on shutdown)
local mounted_points = {}

local do_unmount = function (mountpoint)
	os.execute([[
	mountpoint=]]..shellquote(mountpoint)..'\n'..[[
	fusermount -u "$mountpoint"
	rmdir "$mountpoint"
	]])
	mounted_points[mountpoint] = nil
end

local do_mount = function (url, mountpoint)
	if type(btfs_args) == 'table' then
		for i = 1, #btfs_args do
			btfs_args[i] = shellquote(btfs_args[i])
		end
		btfs_args = table.concat(btfs_args, ' ')
	end
	local title = ('btfs - '..mountpoint:match('[^/]+$'))
	if not exec_ok([[
	mountpoint=]]..shellquote(mountpoint)..'\n'..[[
	url=]]..shellquote(url)..'\n'..[[
	mkdir -p "$mountpoint" || exit 1
	{
	# if command -v xterm >/dev/null; then
	# 	exec xterm -title ]]..shellquote(title)..[[ -e btfs -f ]]..btfs_args..[[ "$url" "$mountpoint"
	# else
		exec btfs -f ]]..btfs_args..[[ "$url" "$mountpoint" >/dev/null 2>&1
	#fi
	} &
	pid=$!
	while true; do
		if [ ! -e /proc/$pid ]; then
			exit 1
		fi
		if mountpoint -q "$mountpoint"; then
			set -- "$mountpoint"/*
			if [ $# -gt 1 ] || [ -e "$1" ]; then
				exit 0
			fi
		fi
		command sleep 0.25 || exit 1
	done
	]]) then
		return false
	end
	mounted_points[mountpoint] = true
	return true
end

local is_mounted = function (mountpoint)
	return exec_ok('mountpoint -q '..shellquote(mountpoint))
end

--------------------------------------------------------------------------------

-- gets the info hash or torrent filename for use as the mount directory name
local parse_url = function (url)
	return url:match('^magnet:%?xt=urn:btih:*.')
	    or url:gsub('[?#].*', '', 1):match('/([^/]+%.torrent)$')
end

mp.add_hook('on_load', 11, function ()
	local url = mp.get_property('stream-open-filename')
	if not url then
		return
	end

	local dirname = parse_url(url)
	if not dirname then
		return
	end

	local mountpoint = (mountdir..'/'..dirname)
	if not is_mounted(mountpoint) then
		if not do_mount(url, mountpoint) then
			print('mount failed!')
			return
		end
	end

	local files = list_files(mountpoint)
	if #files == 0 then
		print('nothing to play!')
	elseif #files == 1 then
		mp.set_property("file-local-options/force-media-title", files[1]:match('[^/]+$'))
		mp.set_property('stream-open-filename', 'file://'..files[1])
	else
		local playlist = {'#EXTM3U'}
		for _, line in ipairs(files) do
			table.insert(playlist, '#EXTINF:0,'..line:match('[^/]+$'))
			table.insert(playlist, 'file://'..line)
		end
		mp.set_property('stream-open-filename', 'memory://'..table.concat(playlist, '\n'))
	end
end)

mp.register_event('shutdown', function ()
	for mountpoint in pairs(mounted_points) do
		do_unmount(mountpoint)
	end
end)
