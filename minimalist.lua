--minimalist for CC made by Featherwhisker
local versionStr = "minimalist 1.0"
local oldPrintError = printError
local pullEvent = os.pullEvent
local pullEventRaw = os.pullEventRaw
local isInProgram = true
local newRequire = dofile("/rom/modules/main/cc/require.lua").make
local dir = "/"
local function makeNewEnv(args,prog)
	local newArgs = table.copy(args)
	newArgs[0] = prog
	local newEnv = setmetatable({arg=newArgs},{__index=_G})
	newEnv.require,newEnv.package = newRequire(newEnv,"")
	newEnv.shell = {
		path = function() return dir end,
		dir = function() return dir end,
		execute = function(command,...)
			local prog = loadfile(command,command,makeNewEnv({...},command))
			if prog then
				return prog(...)
			end
		end,
		run = function(...)
			local a = {}
			local b = ""
			for i,v in pairs(a) do
				if i ~= 1 then
					b = b .. " "
				end
				b = b .. v
			end
			local args = b:split(" ")
			local prog = args[1]
			table.remove(args,1)
			local prog1 = loadfile(prog,prog,makeNewEnv(args,prog))
			if prog1 then
				return prog1(...)
			end
		end,
	}
	return newEnv
end
local defaults = {
	clr = function()
		term.clear()
		term.setCursorPos(1,1)
	end,
	echo = function(...)
		local a = {...}
		local b = ""
		for i,v in pairs(a) do
			if i ~= 1 then
				b = b.." "
			end
			b = b..v
		end
		print(b)
	end,
	rm = function(path)
		if path == nil then
			print("No such file")
			return
		end
		if fs.exists(path) then
			fs.delete(path)
		else
			print("No such file")
		end
	end,
	ls = function(dir1)
		if not dir1 then
			dir1 = dir
		end
		if not fs.exists(dir1) then
			printError("A valid directory is required!")
			return
		end
		local maxX = term.getSize()
		local lines = {}
		local current = 1
		for _,v in pairs(fs.list(dir1)) do
			if not lines[current] then
				lines[current] = {"","",""}
			end
			local color = "0"
			if fs.isDir(fs.combine(dir1,v)) then
				color = "5"
			end
			if v:sub(1,1) ~= "." then
				if #lines[current][1] + #v > maxX then
					current = current + 1
					lines[current] = {"","",""}
				end
				lines[current][1] = lines[current][1] .. v .. " "
				lines[current][2] = lines[current][2] .. color:rep(#v + 1)
				lines[current][3] = lines[current][3] .. ("f"):rep(#v + 1)
			end
		end
		for i,v in pairs(lines) do
			term.blit(v[1],v[2],v[3])
			print("")
		end
	end,
	tw = function(fileName,shouldAppend)
		if not fileName then
			printError("A file name is required!")
			return
		end
		local mode = "w"
		if shouldAppend and (shouldAppend:lower() == "append" or shouldAppend:lower() == "a") then
			mode = "a"
		end
		local a = fs.open(dir..fileName,mode)
		local edit = true
		local size = term.getSize()
		parallel.waitForAny(function()
			while edit do
				local _,b = pullEventRaw("char")
				local pos = term.getCursorPos()
				if pos <= size then
					term.write(b)
					a.write(b)
				end
			end
		end,
		function()
			while edit do
				local _,b = pullEventRaw("key")
				if b == keys.enter then
					a.write("\n")
					print("")
					a.flush()
				elseif b == keys.rightCtrl then
					print("")
					edit = false
				elseif b == keys.backspace then
					local posX,posY = term.getCursorPos()
					if posX ~= 1 then
						term.setCursorPos(posX-1,posY)
						a.seek("cur",-1)
					end
				end
			end
		end)
		a.close()
	end,
	import = function()
		print("Drag the files over the terminal")
		local _, files = os.pullEvent("file_transfer")
		for _, v in ipairs(files.getFiles()) do
			local a = fs.open(fs.combine(dir,v.getName()), "wb")
			print("Transferring "..v.getName())
			a.write(v.readAll())
			a.close()
			v.close()
		end
	end,
	version = function()
		print(versionStr)
	end,
	reboot = os.reboot,
	exit = os.reboot,
	shutdown = os.shutdown
}
local function getInput()
	term.blit(":","8","f")
	term.setCursorBlink(true)
	local input = read()
	local args = input:split(" ")
	local prog = args[1]
	table.remove(args,1)
	local prog1
	if defaults[prog] then
		prog1 = defaults[prog]
	elseif prog ~= nil then
		local a = ""
		local b = prog:split(".")
		if b[#b] ~= "lua" then
			a = ".lua"
		end
		prog1 = loadfile(fs.combine(dir,prog..a),prog,makeNewEnv(args,prog))
	end
	isInProgram = true
	if prog1 then
		local a,b = pcall(prog1,table.unpack(args))
		if not a then
			printError(b)
		end
	else
		printError("Invalid program!")
	end
	isInProgram = false
end
local function handleTerminate()
	while true do
		pullEventRaw("terminate")
		if not isInProgram then
			os.shutdown()
		end
	end
end
local function addGlobals()
	function string:split(sep)
		if sep == " " or sep == nil then
			sep = "%s"
		end
		local a = {}
		for b in self:gmatch("([^"..sep.."]+)") do
			table.insert(a, b)
		end
		return a
	end
	function os.version()
		return versionStr
	end
	function table.copy(oldTable)
		local newTable = {}
		for i,v in pairs(oldTable) do
			if type(v) == "table" then
				newTable[i] = table.copy(v)
			else
				newTable[i] = v
			end
		end
		return newTable
	end
end
local function init()
	term.clear()
	term.setCursorPos(1,1)
	term.blit("minimalist","8888888888","ffffffffff")
	term.setCursorPos(1,2)
	if fs.exists(fs.combine(dir,"init.lua")) then
		local a = loadfile(fs.combine(dir,"init.lua"))
		if a then
			pcall(a)
		end
	end
	isInProgram = false
	while true do
		getInput()
	end
end
local function inject()
	term.clear()
	term.setCursorBlink(false)
	_G.printError = oldPrintError
	_G.os.pullEventRaw = pullEventRaw
	addGlobals()
	local a,b = pcall(parallel.waitForAny,init,handleTerminate)
	if not a then
		printError(b)
	end
	while true do
		sleep()
	end
end
_G.printError = inject
_G.os.pullEventRaw = nil
os.queueEvent("key")