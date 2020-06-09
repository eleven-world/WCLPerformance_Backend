local addon_name, Addon = ...

local Core = LibStub("AceAddon-3.0"):NewAddon("WCLPerformance_Backend", "AceTimer-3.0", "AceComm-3.0", "AceSerializer-3.0")
Addon.addon = Core
-- local Core = WCLPerf
Core.addon_name = "WCLPerformance_Backend"

-- LibStub:GetLibrary("AceComm-3.0"):Embed(Core)


Core.black_list = {}
Core.invite_message = "组我更新WCL数据库"

function Core:OnInitialize()
	if not self.message then 
		self.loader = self:ScheduleRepeatingTimer("GetMessage", 10) 
	end
	self.ticker = self:ScheduleRepeatingTimer("SendUpdate", 120)
end


function Core:SendUpdate()
	print("SendUpdate")
	if not self.message then return nil end
	if GetNumGroupMembers() > 1 then
		self:SendCommMessage(self:GetUpdataPrefix(), "START_UPDATE", "RAID",nil, nil, Core.PrintProgress)
		self:SendCommMessage(self:GetUpdataPrefix(), self.message, "RAID",nil, nil, Core.PrintProgress)
	end
end

function Core.PrintProgress( ... )
	print(...) 
end

function Core:GetMessage()
	if self.message and self.loader then
		self:CancelTimer(self.loader)
		return nil
	end
	local message = self:GenerateUpdateString()
	if message then
		print("message", message)
		self.message = message
	end
end

function Core:GenerateUpdateString()
	self:GetData()
	if self.data and self.date then
		local message_data = {date = self.date, data = self.data}
		local LibDeflate = LibStub:GetLibrary("LibDeflate")
    	local data_string = self:Serialize(message_data)
    	local compressed_string = LibDeflate:CompressDeflate(data_string)
    	local encoded_string = LibDeflate:EncodeForWoWAddonChannel(compressed_string)
    	return encoded_string
	end
end

function Core:GetCurrentDate()
	return date("%y%m%d", GetServerTime() - 4 * 3600)	--update at 4:00 am
end

function Core:GetUpdataPrefix()
	local prefix = "WCLPUR" --WCLP, Update, Raid
	prefix = prefix .. self:GetCurrentDate()
	return prefix
end


function Core:GetData()
	local db_addon_name = "WCLPerformance_Database_Nyalotha"
	if not IsAddOnLoaded(db_addon_name) then LoadAddOn(db_addon_name) end
	self.data = self:GetDatabase()
	self.date = date("%y%m%d", tonumber(GetAddOnMetadata(db_addon_name, "X-Update-Date")))
end


Core.healer_spec = {[105] = true, [65] = true, [256] = true, [257] = true, [264] = true, [270] = true,}

function Core:GetDatabase()
	if not WCLPerf_Database then return nil end
	local db = {}
	for zone, _ in pairs(WCLPerf_Database) do
		if not db[zone] then db[zone] = {data = {}, update = WCLPerf_Database[zone].update} end
		for metric, _ in pairs(WCLPerf_Database[zone].data) do
			if not db[zone].data[metric] then db[zone].data[metric] = {} end
			for encounter, _ in pairs(WCLPerf_Database[zone].data[metric]) do
				if not db[zone].data[metric][encounter] then db[zone].data[metric][encounter] = {} end
				for difficulty, _ in pairs(WCLPerf_Database[zone].data[metric][encounter]) do
					if difficulty == 16 then
						if not db[zone].data[metric][encounter][difficulty] then db[zone].data[metric][encounter][difficulty] = {} end
						for spec, v in pairs(WCLPerf_Database[zone].data[metric][encounter][difficulty]) do
							if (metric == "hps" and Core.healer_spec[spec]) or (metric == "dps" and not Core.healer_spec[spec]) then
								db[zone].data[metric][encounter][difficulty][spec] = v
							end
						end
					end
				end
			end
		end
	end
	return db
end


local tracker = Core.tracker or CreateFrame("Frame")
tracker:RegisterEvent("CHAT_MSG_RAID")
tracker:RegisterEvent("CHAT_MSG_PARTY")
tracker:RegisterEvent("CHAT_MSG_WHISPER")
tracker:RegisterEvent("GROUP_ROSTER_UPDATE")
tracker:SetScript("OnEvent", function(self, event, msg, sender)
	if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY" then
		Core.black_list[sender] = GetTime() + 3600
	elseif event == "CHAT_MSG_WHISPER" then
		if msg == Core.invite_message then
			C_PartyInfo.InviteUnit(sender)
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		if not IsInRaid() then
			C_PartyInfo.ConvertToRaid()
		end
	end
end)
