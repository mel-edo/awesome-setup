-- Discord Rich Presence integration for mpv Media Player
--
-- Please consult the readme for information about usage and configuration:
-- https://github.com/cniw/mpv-discordRPC


local options = require 'mp.options'
local msg = require 'mp.msg'

-- set [options]
local o = {
	rpc_wrapper = "lua-discordRPC",
	-- Available option, to set `rpc_wrapper`:
	-- * lua-discordRPC
	-- * python-pypresence
	periodic_timer = 15,
	-- Recommendation value, to set `periodic_timer`:
	-- value >= 1 second, if use lua-discordRPC,
	-- value >= 3 second, if use pypresence (for the python3::asyncio process),
	-- value <= 15 second, because discord-rpc updates every 15 seconds.
	playlist_info = "yes",
	-- Valid value to set `playlist_info`: (yes|no)
	loop_info = "yes",
	-- Valid value to set `loop_info`: (yes|no)
	cover_art = "yes",
	-- Valid value to set `cover_art`: (yes|no)
	mpv_version = "yes",
	-- Valid value to set `mpv_version`: (yes|no)
	active = "yes",
	-- Set Discord RPC active automatically when mpv started.
	-- Valid value to `set_active`: (yes|no)
	key_toggle = "D",
	-- Key for toggle active/inactive the Discord RPC.
	-- Valid value to set `key_toggle`: same as valid value for mpv key binding.
	-- You also can set it in input.conf by adding this next line (without double quote).
	-- "D script-binding mpv_discordRPC/active-toggle"
}
options.read_options(o)

-- set `script_info`
local script_info = {
	name = mp.get_script_name(),
	description = "Discord Rich Presence integration for mpv Media Player",
	upstream = "https://github.com/cniw/mpv-discordRPC",
	version = "1.4.1-UNKNOWN",
}

-- set `mpv_version`
local mpv_version = mp.get_property("mpv-version"):sub(5)

-- set `startTime`
local startTime = os.time(os.date("*t"))

local function main()
	-- set `details`
	local details = mp.get_property("media-title")
	local metadataTitle = mp.get_property_native("metadata/by-key/Title")
	local metadataArtist = mp.get_property_native("metadata/by-key/Artist")
	local metadataAlbum = mp.get_property_native("metadata/by-key/Album")
	if metadataTitle ~= nil then
		details = metadataTitle
	end
	if metadataArtist ~= nil then
		details = ("%s\nby %s"):format(details, metadataArtist)
	end
	if metadataAlbum ~= nil then
		details = ("%s\non %s"):format(details, metadataAlbum)
	end
	if details == nil then
		details = "No file"
	end
	-- set `state`, `smallImageKey`, and `smallImageText`
	local state, smallImageKey, smallImageText
	local idle = mp.get_property_bool("idle-active")
	local coreIdle = mp.get_property_bool("core-idle")
	local pausedFC = mp.get_property_bool("paused-for-cache")
	local pause = mp.get_property_bool("pause")
	local play = coreIdle and false or true
	if idle then
		state = "(Idle)"
		smallImageKey = "player_stop"
		smallImageText = "Idle"
	elseif pausedFC then
		state = ""
		smallImageKey = "player_pause"
		smallImageText = "Buffering"
	elseif pause then
		state = ""
		smallImageText = "Paused"
		smallImageKey = "player_pause"
	elseif play then
		state = "(Playing) "
		smallImageKey = "player_play"
		smallImageText = "Playing"
	end
	if not idle then
		-- set `playlist_info`
		local playlist = ""
		if o.playlist_info == "yes" then
			playlist = (" - Playlist: [%s/%s]"):format(mp.get_property("playlist-pos-1"), mp.get_property("playlist-count"))
		end
		-- set `loop_info`
		local loop = ""
		if o.loop_info == "yes" then
			local loopFile = mp.get_property_bool("loop-file") == false and "" or "file"
			local loopPlaylist = mp.get_property_bool("loop-playlist") == false and "" or "playlist"
			if loopFile ~= "" then
				if loopPlaylist ~= "" then
					loop = ("%s, %s"):format(loopFile, loopPlaylist)
				else
					loop = loopFile
				end
			elseif loopPlaylist ~= "" then
				loop = loopPlaylist
			else
				loop = "disabled"
			end
			loop = (" - Loop: %s"):format(loop)
		end
		state = state .. mp.get_property("options/term-status-msg")
		smallImageText = ("%s%s%s"):format(smallImageText, playlist, loop)
	end
	-- set time
	local timeNow = os.time(os.date("*t"))
	local timeRemaining = os.time(os.date("*t", mp.get_property("playtime-remaining")))
	local timeUp = timeNow + timeRemaining
	-- set `largeImageKey` and `largeImageText`
	local largeImageKey = "mpv"
	local largeImageText = "mpv Media Player"
	-- set `mpv_version`
	if o.mpv_version == "yes" then
		largeImageText = mpv_version
	end
	-- set `cover_art`
	if o.cover_art == "yes" then
		local catalogs = require("catalogs")
		for i in pairs(catalogs) do
			local title = catalogs[i].title
			for j in pairs(title) do
				local lower_title = title[j] ~= nil and title[j]:lower() or ""
				local lower_details = details ~= nil and details:lower() or ""
				if lower_details:find(lower_title, 1, true) ~= nil then
					local number = catalogs[i].number
					largeImageKey = ("coverart_%s"):format(number):gsub("[ /~]", "_"):lower()
					largeImageText = title[j]
				end
			end
			local album = catalogs[i].album
			for j in pairs(album) do
				local lower_album = album[j] ~= nil and album[j]:lower() or ""
				local lower_metadataAlbum = metadataAlbum ~= nil and metadataAlbum:lower() or ""
				if lower_album == lower_metadataAlbum then
					local artist = catalogs[i].artist
					for k in pairs(artist) do
						local lower_artist = artist[k] ~= nil and artist[k]:lower() or ""
						local lower_metadataArtist = metadataArtist ~= nil and metadataArtist:lower() or ""
						if lower_artist == lower_metadataArtist then
							local number = catalogs[i].number
							largeImageKey = ("coverart_%s"):format(number):gsub("[ /~]", "_"):lower()
							largeImageText = album[j]
						end
					end
				end
			end
		end
	end
	-- streaming mode
	local url = mp.get_property("path")
	local stream = mp.get_property("stream-path")
	if url ~= nil then
		-- checking protocol: http, https
		if string.match(url, "^https?://.*") ~= nil then
			largeImageKey = "mpv_stream"
			largeImageText = url
		end
		-- checking site: YouTube, Crunchyroll, SoundCloud, LISTEN.moe
		if string.match(url, "www.youtube.com/watch%?v=([a-zA-Z0-9-_]+)&?.*$") ~= nil or string.match(url, "youtu.be/([a-zA-Z0-9-_]+)&?.*$") ~= nil then
			largeImageKey = "youtube"	-- alternative "youtube_big" or "youtube-2"
			largeImageText = "YouTube"
		elseif string.match(url, "www.crunchyroll.com/.+/.*-([0-9]+)??.*$") ~= nil then
			largeImageKey = "crunchyroll"	-- alternative "crunchyroll_big"
			largeImageText = "Crunchyroll"
		elseif string.match(url, "soundcloud.com/.+/.*$") ~= nil then
			largeImageKey = "soundcloud"	-- alternative "soundcloud_big"
			largeImageText = "SoundCloud"
		elseif string.match(url, "listen.moe/.*stream$") ~= nil or string.match(url, "listen.moe/.*opus$") ~= nil or string.match(url, "listen.moe/.*fallback$") ~= nil or string.match(url, "listen.moe/.*m3u$") ~= nil then
			largeImageKey = "listen_moe"	-- alternative "listen_moe_big"
			largeImageText = string.match(url, "kpop") ~= nil and "LISTEN.moe - KPOP" or "LISTEN.moe - JPOP"
		end
	end
	-- set `presence`
	local presence = {
		state = state,
		details = details,
		-- startTimestamp = math.floor(startTime),
		endTimestamp = math.floor(timeUp),
		largeImageKey = largeImageKey,
		largeImageText = largeImageText,
		smallImageKey = smallImageKey,
		smallImageText = smallImageText,
	}
	if url ~= nil and stream == nil then
		presence.state = "(Loading)"
		presence.startTimestamp = math.floor(startTime)
		presence.endTimestamp = nil
	end
	if idle then
		presence = {
			state = presence.state,
			details = presence.details,
			startTimestamp = math.floor(startTime),
			-- endTimestamp = presence.endTimestamp,
			largeImageKey = presence.largeImageKey,
			largeImageText = presence.largeImageText,
			smallImageKey = presence.smallImageKey,
			smallImageText = presence.smallImageText
		}
	end
	-- run Rich Presence
	if tostring(o.rpc_wrapper) == "lua-discordRPC" then
		-- run Rich Presence with lua-discordRPC
		local appId = "448016723057049601"
		local RPC = require(o.rpc_wrapper)
		RPC.initialize(appId, true)
		if o.active == "yes" then
			presence.details = presence.details:len() > 127 and presence.details:sub(1, 127) or presence.details
			RPC.updatePresence(presence)
		else
			RPC.shutdown()
		end
	elseif tostring(o.rpc_wrapper) == "python-pypresence" then
		-- set python path
		local pythonPath
		local lib
		pythonPath = mp.get_script_directory() .. "/" .. o.rpc_wrapper .. ".py"
		lib = package.cpath:match("%p[\\|/]?%p(%a+)")
		if lib == "dll" then
			pythonPath = pythonPath:gsub("/","\\\\")
		end
		-- run Rich Presence with pypresence
		local todo = idle and "idle" or "not-idle"
		local command = ('python "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s"'):format(pythonPath, todo, presence.state, presence.details, math.floor(startTime), math.floor(timeUp), presence.largeImageKey, presence.largeImageText, presence.smallImageKey, presence.smallImageText, o.periodic_timer)
		mp.register_event('shutdown', function()
			todo = "shutdown"
			command = ('python "%s" "%s"'):format(pythonPath, todo)
			io.popen(command)
			os.exit()
		end)
		if o.active == "yes" then
			io.popen(command)
		end
	end
end

-- print script info
msg.info(string.format(script_info.description))
msg.info(string.format("Upstream: %s", script_info.upstream))
msg.info(string.format("Version: %s", script_info.version))

-- print option values
msg.verbose(string.format("rpc_wrapper    : %s", o.rpc_wrapper))
msg.verbose(string.format("periodic_timer : %s", o.periodic_timer))
msg.verbose(string.format("playlist_info  : %s", o.playlist_info))
msg.verbose(string.format("loop_info      : %s", o.loop_info))
msg.verbose(string.format("cover_art      : %s", o.cover_art))
msg.verbose(string.format("mpv_version    : %s", o.mpv_version))
msg.verbose(string.format("active         : %s", o.active))
msg.verbose(string.format("key_toggle     : %s", o.key_toggle))

-- toggling active or inactive
mp.add_key_binding(o.key_toggle, "active-toggle", function()
		o.active = o.active == "yes" and "no" or "yes"
		local status = o.active == "yes" and "active" or "inactive"
		mp.osd_message(("[%s] Status: %s"):format(script_info.name, status))
		msg.info(string.format("Status: %s", status))
	end,
	{repeatable=false})

-- run `main` function
mp.add_periodic_timer(o.periodic_timer, main)
