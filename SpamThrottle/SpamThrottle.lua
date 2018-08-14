--[[
	SpamThrottle - Remove redundant and annoying chat messages
	Version:	Vanilla 1.13a
	Date:		24 July 2018
	Author:	Orukxu a.k.a. Mopar
	This is a port of SpamThrottle to work with Vanilla WoW, release 1.12.1 and 1.12.2.
	I am also the author of the retail version (no longer maintained).
	Only allows a particular message to be displayed once, rather than repeated.	
	A timeout (call the gapping value) controls how often the exact same message
	may be repeated, and this value is settable by the user. There is also a keyword
	list to filter by keywords, and a player name list to filter by specific players.
	Both lists are unlimited in size.
	
	Also allows (optional) blocking of chat channel join/leave spam,
	and other chat channel control messages.
	Portions of this code were adapted from the following addons:
	- SpamEraser
	- ASSFilter

	Special thanks to Github's sipertruk for multiple-chat frame handling code.
]]

--============================
--= Settings, Defaults, and Local Variables
--============================
local DebugMsg = false;
local ErrorMsg = true;
local BlockReason = false;
local DebugMode = false;
local BlockReportMode = false;

local MessageList = {}
local MessageCount = {}
local MessageTime = {}
local MessageLatestTime = {}
for i=1, NUM_CHAT_WINDOWS do
	MessageList["ChatFrame"..i] = {}
	MessageTime["ChatFrame"..i] = {}
	MessageLatestTime["ChatFrame"..i] = {}
	MessageCount["ChatFrame"..i] = {}
end
local LastPurgeTime = time()
local LastAuditTime = time()
local FilteredCount = 0;
local UniqueCount = 0;
local PlayerListAuditGap = 10;
local DelayHookInitTime = time();
local DelayHookReHooked;
local Prefix1 = "|c"

Default_SpamThrottle_Config = {
		Version = SpamThrottleProp.Version;
		STActive = true;
		STDupFilter = true;
		STColor = false;
		STGoldSeller = true;
		STFuzzy = true;
		STChinese = true;
		STCtrlMsgs = false;
		STYellMsgs = true;
		STSayMsgs = true;
		STWispMsgs = true;
		STWispBack = false;
		STReverse = false;
		STGap = 600;
		STBanPerm = false;
		STBanTimeout = 600;
		STWhiteChannel1 = "";
		STWhiteChannel2 = "";
		STWhiteChannel3 = "";
}

Default_SpamThrottle_KeywordFilterList = { "Blessed Blade of the Windseeker", "item4game", "moneyforgames", "goldinsider", "sinbagame", "sinbagold", "sinbaonline", "susangame", "4gamepower", "iloveugold", "okogames", "okogomes", "item4wow", "gold4mmo", "wtsitem", "golddeal", "mmogo", "lovewowhaha", "hadoukenlol", "naxxgames", "mmogs", "money-circle", "mojoviking", "y2lgold" }

Default_SpamThrottle_PlayerFilterList = { };

SpamThrottle_PlayerBanTime = {};

local SpamThrottle_GlobalBanList = {}

SpamThrottle_LastClickedItem = nil;
SpamThrottle_LastClickedTable = nil;
SpamThrottle_LastClickedValue = nil;

local SpamThrottle_Map = { 42, 82, 76, 34, 61, 91, 9, 90, 13, 24, 19, 77, 65, 85, 54, 27, 86, 22, 3, 62, 89, 50, 44, 0, 30, 70, 23, 73, 25, 84, 2, 56, 15, 64, 66, 32, 49, 79, 75, 16, 53, 40, 80, 10, 48, 51, 43, 6, 92, 81, 4, 14, 58, 26, 20, 57, 12, 11, 71, 41, 68, 39, 18, 74, 37, 1, 87, 5, 60, 55, 29, 36, 17, 72, 21, 78, 8, 47, 33, 46, 69, 67, 7, 31, 38, 35, 52, 83, 59, 28, 63, 45, 93, 88, 28, 14, 78, 12, 39, 90, 70, 27, 66, 79, 50, 91, 52, 19, 40, 51, 71, 81, 29, 44, 85, 93, 55, 58, 72, 53, 16, 4, 62, 49, 21, 33, 56, 59, 10, 18, 43, 15, 37, 61, 87, 13, 7, 46, 24, 5, 83, 89, 86, 8, 47, 25, 65, 32, 22, 63, 48, 75, 82, 68, 20, 2, 92, 80, 30, 77, 3, 6, 84, 9, 54, 31, 45, 57, 74, 67, 38, 69, 36, 23, 1, 17, 26, 35, 41, 88, 76, 64, 42, 34, 60, 73, 0, 11, 66, 31, 19, 64, 3, 35, 4, 22, 36, 88, 12, 50, 91, 1, 82, 69, 63, 24, 52, 6, 87, 57, 55, 13, 39, 37, 29, 51, 71, 73, 72, 48, 75, 26, 43, 85, 45, 86, 14, 5, 77, 25, 41, 16, 61, 15, 34, 67, 33, 62, 53, 2, 65, 79, 80, 30, 32, 74, 58, 84, 90, 27, 8, 59, 44, 23, 49, 18, 46, 83, 68, 17, 93, 92, 54, 70, 42, 21, 20, 10, 60, 76, 89, 9, 78, 56, 38, 40, 28, 7, 0, 11, 47, 81, 89, 75, 26, 81, 40, 13, 71, 52, 50, 12, 41, 21, 67, 93, 32, 35, 80, 14, 0, 11, 43, 47, 2, 72, 28, 45, 31, 16, 9, 90, 44, 66, 51, 85, 88, 22, 61, 6, 92, 82, 58, 36, 73, 34, 18, 8, 55, 69, 78, 84, 5, 15, 29, 86, 1, 53, 20, 42, 19, 48, 59, 33, 91, 23, 68, 10, 65, 39, 7, 62, 27, 76, 4, 60, 25, 3, 74, 83, 37, 64, 17, 54, 38, 87, 77, 70, 24, 63, 30, 49, 57, 56, 79, 46, 80, 44, 74, 56, 49, 29, 31, 47, 93, 2, 65, 69, 17, 62, 13, 25, 73, 6, 84, 59, 15, 70, 24, 87, 72, 85, 4, 37, 75, 48, 38, 28, 54, 34, 0, 92, 9, 50, 10, 91, 58, 52, 45, 23, 63, 35, 36, 78, 66, 40, 57, 77, 90, 39, 5, 30, 53, 1, 26, 51, 76, 19, 71, 43, 88, 41, 16, 42, 81, 21, 46, 82, 33, 11, 89, 18, 12, 68, 83, 60, 64, 8, 86, 20, 27, 55, 14, 7, 67, 79, 3, 22, 32, 61, 22, 84, 39, 33, 29, 67, 50, 51, 9, 78, 41, 47, 86, 34, 40, 75, 73, 82, 4, 60, 55, 80, 77, 37, 52, 11, 85, 10, 1, 6, 27, 43, 28, 8, 57, 42, 66, 46, 83, 81, 79, 65, 90, 31, 61, 87, 62, 45, 25, 59, 88, 20, 92, 13, 35, 32, 2, 91, 15, 93, 72, 36, 23, 54, 76, 26, 64, 5, 74, 30, 44, 18, 17, 0, 48, 69, 71, 58, 16, 19, 49, 21, 63, 14, 38, 70, 12, 53, 7, 56, 24, 89, 68, 3, 67, 39, 70, 72, 38, 42, 73, 36, 50, 12, 53, 58, 7, 71, 91, 52, 32, 64, 26, 83, 82, 37, 47, 56, 9, 46, 66, 74, 65, 51, 87, 17, 8, 25, 18, 92, 15, 80, 89, 40, 29, 57, 76, 60, 90, 13, 10, 20, 24, 44, 84, 62, 22, 43, 34, 63, 31, 2, 6, 35, 45, 41, 49, 54, 85, 79, 5, 75, 69, 19, 0, 23, 86, 11, 68, 14, 48, 33, 61, 21, 59, 93, 55, 88, 81, 30, 77, 78, 4, 1, 3, 28, 16, 27, 76, 34, 90, 44, 91, 61, 52, 17, 32, 0, 55, 93, 72, 48, 16, 82, 38, 37, 84, 10, 58, 7, 69, 21, 31, 56, 27, 49, 71, 28, 88, 24, 11, 75, 18, 85, 86, 80, 39, 83, 81, 54, 74, 79, 40, 65, 35, 45, 14, 60, 3, 59, 92, 68, 23, 64, 13, 78, 57, 50, 9, 73, 77, 46, 62, 36, 42, 8, 47, 53, 30, 6, 25, 1, 2, 12, 89, 43, 63, 41, 20, 51, 33, 4, 67, 15, 66, 5, 29, 22, 87, 26, 70, 19, 7, 70, 88, 62, 68, 9, 31, 58, 61, 93, 10, 69, 29, 12, 85, 41, 32, 30, 6, 89, 34, 39, 33, 66, 21, 81, 51, 80, 71, 8, 38, 50, 37, 72, 0, 57, 4, 16, 49, 44, 52, 26, 11, 20, 54, 43, 18, 35, 60, 91, 15, 82, 47, 1, 42, 19, 74, 86, 13, 3, 84, 63, 17, 27, 48, 55, 45, 36, 24, 64, 90, 53, 56, 75, 92, 14, 67, 25, 87, 22, 76, 5, 73, 28, 78, 23, 46, 59, 83, 65, 77, 79, 2, 40, 93, 15, 37, 28, 13, 69, 80, 2, 48, 19, 75, 20, 65, 18, 43, 77, 33, 21, 68, 79, 45, 40, 16, 36, 35, 6, 10, 73, 32, 60, 55, 56, 41, 24, 74, 7, 38, 85, 47, 11, 14, 49, 63, 84, 83, 8, 5, 54, 9, 81, 87, 52, 90, 53, 82, 34, 76, 46, 51, 64, 3, 30, 17, 66, 23, 67, 42, 44, 88, 72, 71, 27, 70, 31, 57, 58, 25, 26, 92, 4, 89, 22, 12, 50, 39, 91, 59, 29, 61, 0, 86, 1, 78, 62 };

local SpamThrottle_Native = {
	"ff1eff0",
	"ff0070d",
	"fffffff",
	"ffffff0",
	"ffa335e",
	"ffff800",
	"fffff00",
	"ffFFd20"
}

SpamThrottle_UTF8Convert = {};
SpamThrottle_UTF8Convert[tonumber("391",16)] = "A";
SpamThrottle_UTF8Convert[tonumber("392",16)] = "B";
SpamThrottle_UTF8Convert[tonumber("395",16)] = "E";
SpamThrottle_UTF8Convert[tonumber("396",16)] = "Z";
SpamThrottle_UTF8Convert[tonumber("397",16)] = "H";
SpamThrottle_UTF8Convert[tonumber("399",16)] = "I";
SpamThrottle_UTF8Convert[tonumber("39A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("39C",16)] = "M";
SpamThrottle_UTF8Convert[tonumber("39D",16)] = "N";
SpamThrottle_UTF8Convert[tonumber("39F",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("3A1",16)] = "P";
SpamThrottle_UTF8Convert[tonumber("3A4",16)] = "T";
SpamThrottle_UTF8Convert[tonumber("3A5",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("3A6",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("3A7",16)] = "X";
SpamThrottle_UTF8Convert[tonumber("405",16)] = "S";
SpamThrottle_UTF8Convert[tonumber("406",16)] = "I";
SpamThrottle_UTF8Convert[tonumber("408",16)] = "J";
SpamThrottle_UTF8Convert[tonumber("410",16)] = "A";
SpamThrottle_UTF8Convert[tonumber("412",16)] = "B";
SpamThrottle_UTF8Convert[tonumber("415",16)] = "E";
SpamThrottle_UTF8Convert[tonumber("41A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("41C",16)] = "M";
SpamThrottle_UTF8Convert[tonumber("41D",16)] = "H";
SpamThrottle_UTF8Convert[tonumber("41E",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("420",16)] = "P";
SpamThrottle_UTF8Convert[tonumber("421",16)] = "C";
SpamThrottle_UTF8Convert[tonumber("422",16)] = "T";
SpamThrottle_UTF8Convert[tonumber("423",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("425",16)] = "X";
SpamThrottle_UTF8Convert[tonumber("428",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("429",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("435",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("448",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("449",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("460",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("461",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("49A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49B",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("49C",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49D",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("49E",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49F",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("4A0",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("4A1",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("4AE",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("4AF",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("51C",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("51D",16)] = "w";

--============================
--= SpamThrottle_msgPrep
--============================
function SpamThrottle_msgPrep(msg)
	local theString ="";
	local Nlen = string.len(msg);
	
	local c1;
	local r = 0;
	local skip = 0;
	
	for i = 1, Nlen do
		c1 = string.byte(string.sub(msg,i,i)) - 32;
		local oldc1 = c1;
		
		if skip > 0 then
			skip = skip - 1;
		else
			if c1 >= 160 and c1 <= 191 then
				skip = 1;
			elseif c1 >= 192 and c1 <= 207 then
				skip = 2;
			elseif c1 >= 208 then
				skip = 3;
			elseif c1 >= 0 and c1 < 95 then
				for j = 0, 9 do
					c1 = SpamThrottle_Map[math.mod(c1 + r + (j*94),94)+1]
				end
			end
		end
		
		r = r + oldc1;
		theString = theString .. string.format("%c",c1 + 32);
	end
	
	theString = SpamThrottle_addEscapes(theString);
	return theString;
end

--============================
--= SpamThrottle_addEscapes
--============================
function SpamThrottle_addEscapes(msg)
	local newMsg = "";
	local Nlen = string.len(msg);
	
	for i = 1, Nlen do
		c1 = string.byte(string.sub(msg,i,i));
		if c1 == 124 then
			newMsg = newMsg .. "|"
		end
		newMsg = newMsg .. string.format("%c",c1);
	end
	
	return newMsg;
end

--============================
--= SpamThrottle_removeEscapes
--============================
function SpamThrottle_removeEscapes(msg)
	local newMsg = "";
	local Nlen = string.len(msg);
	
	for i = 1, Nlen do
		c1 = string.byte(string.sub(msg,i,i));
		if c1 == 124 then
			i = i + 1;
		end
		newMsg = newMsg .. string.format("%c",c1);
	end
	
	return newMsg;
end

--============================
--= Static Popup Dialog Definitions
--============================
StaticPopupDialogs["SPAMTHROTTLE_ADD_KEYWORD"] = {
	text = "%s";
    button1 = "Okay";
    button2 = "Cancel";
    hasEditBox = 1,
    whileDead = 1,
    hideOnEscape = 1,
    timeout = 0,
	enterClicksFirstButton = 1,
    OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText("");
    end,
    OnAccept = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddKeyword(variable);
    end,
	EditBoxOnEnterPressed = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddKeyword(variable);
		this:GetParent():Hide();
	end,
    OnAlt = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
    end
 }

StaticPopupDialogs["SPAMTHROTTLE_ADD_PLAYERBAN"] = {
	text = "%s";
    button1 = "Okay";
    button2 = "Cancel";
    hasEditBox = 1,
    whileDead = 1,
    hideOnEscape = 1,
    timeout = 0,
	enterClicksFirstButton = 1,
    OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText("");
    end,
    OnAccept = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddPlayerban(variable);
    end,
	EditBoxOnEnterPressed = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddPlayerban(variable);
		this:GetParent():Hide();
	end,
    OnAlt = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
    end
 }

--============================
--= Unit popup options (right clicking on character name in chat)
--= This is really dirty. It would cause taint on later versions of WoW.
--============================
UnitPopupButtons["SPAMTHROTTLE_ADD_PLAYERBAN"] = {
	text = "Ban player chat",
	dist = 0
}

UnitPopupButtons["SPAMTHROTTLE_REMOVE_PLAYERBAN"] = {
	text = "Unban player chat",
	dist = 0
}

table.insert(UnitPopupMenus["FRIEND"], 1, "SPAMTHROTTLE_ADD_PLAYERBAN");
table.insert(UnitPopupMenus["FRIEND"], 2, "SPAMTHROTTLE_REMOVE_PLAYERBAN");

local SpamThrottleUnitPopup_OnClick = UnitPopup_OnClick;
function UnitPopup_OnClick(self)	
	local theFrame = UIDROPDOWNMENU_INIT_MENU
	local theName = FriendsDropDown.name;
	local theButton = this.value;
	
	if theFrame == "FriendsDropDown" then
		if theButton == "SPAMTHROTTLE_ADD_PLAYERBAN" then
			if theName ~= UnitName("player") then
				local banType;
				if SpamThrottle_Config.STBanPerm then
					banType = " (" .. SpamThrottleChatMsg.Permanent .. ")";
				else
					banType = " (" .. SpamThrottleChatMsg.Timeout .. "=" .. SpamThrottle_Config.STBanTimeout .. ")";
				end
				SpamThrottle_AddPlayerban(theName);
				SpamThrottleMessage(true,theName,SpamThrottleChatMsg.BanAdded,banType);
			end
		elseif theButton == "SPAMTHROTTLE_REMOVE_PLAYERBAN" then
			if theName ~= UnitName("player") then
				SpamThrottle_RemovePlayerban(theName);
				SpamThrottleMessage(true,theName,SpamThrottleChatMsg.BanRemoved);
			end
		else
			-- do nothing
		end
	end
	SpamThrottleUnitPopup_OnClick(self);
end

--============================
--= Count UTF8 codes in the message
--============================
function SpamThrottle_UTF8Count(msg)
	local Nlen = string.len(msg);
	local theCount = 0;
	local c1, s1;
	
	if (msg == nil) then return 0; end;
	
	for i = 1, Nlen do
		s1 = string.sub(msg,i,i);
		c1 = string.byte(s1);
		if c1 > 192 and c1 <= 225 then -- it's a UTF-8 2 byte code
			theCount = theCount + 1
		end
	end
	return theCount;
end

--============================
--= Message function that prints variable to default chat frame
--============================
function SpamThrottleMessage(visible, ...)
	for i = 1,arg.n do
		if type(arg[i]) == "nil" then
			arg[i] = "(nil)";
		elseif type(arg[i]) == "boolean" and arg[i] then
			arg[i] = "(true)";
		elseif type(arg[i]) == "boolean" and not arg[i] then
			arg[i] = "(false)";
		end
	end

	if (visible) then
		DEFAULT_CHAT_FRAME:AddMessage("SpamThrottle: " .. table.concat (arg, " "), 0.5, 0.5, 1);
	end
end


--============================
--= Delay the hook of the chat messaging function
--============================

local UFStartTime = time();
local UFInitialized;
local UpdateFrame;

function UFOverHookEvents()
	if(time() - UFStartTime > 5 and UFInitialized == nil) then
		SpamThrottle_OrigChatFrame_OnEvent = ChatFrame_OnEvent;
		ChatFrame_OnEvent = SpamThrottle_ChatFrame_OnEvent;
		SpamThrottleMessage(true,"Chat message hook is now enabled.");
    	UFStartTime = nil;
		UFInitialized = true;
		this:Hide();
      	this:SetScript("OnUpdate", nil);
      	this = nil;
   end
end

local UpdateFrame = CreateFrame("Frame", nil);
UpdateFrame:SetScript("OnUpdate",UFOverHookEvents);
UpdateFrame:RegisterEvent("OnUpdate");


--============================
-- Local function to normalize chat strings to avoid attempts to bypass SpamThrottle
--============================
local function SpamThrottle_strNorm(msg, Author)
	local Nmsg = "";
	local c = "";
	local lastc = "";
	local Bmsg = "";

	if (msg == nil) then return end;
	
	if (not SpamThrottle_Config.STFuzzy) then
		return string.upper(Author) .. msg;
	end

	Nmsg = string.gsub(msg,"\\/\\/","W");
	Nmsg = string.gsub(Nmsg,"/\\/\\","M");
	Nmsg = string.gsub(Nmsg,"/-\\","A");
	Nmsg = string.gsub(Nmsg,"0","O");
	Nmsg = string.gsub(Nmsg,"3","E");
	Nmsg = string.gsub(Nmsg,"...hic!","");
	Nmsg = string.gsub(Nmsg,"%d","");
	Nmsg = string.gsub(Nmsg,"%c","");
	Nmsg = string.gsub(Nmsg,"%p","");
	Nmsg = string.gsub(Nmsg,"%s","");
	Nmsg = string.upper(Nmsg);
	Nmsg = string.gsub(Nmsg,"SH","S");
	
	local Nlen = string.len(Nmsg);

	for i = 1, Nlen do
		if i ~= Nlen then
			s1 = string.sub(Nmsg,i,i);
			s2 = string.sub(Nmsg,i+1,i+1);
			c1 = string.byte(s1);
			c2 = string.byte(s2);
			
			if c1 > 192 and c1 <= 225 then -- it's a UTF-8 2 byte code
				p1 = c1 - math.floor(c1/32)*32;
				p2 = c2 - math.floor(c2/64)*64;
				p = p1*64+p2;
				
				if SpamThrottle_UTF8Convert[p] ~= nil then
					Bmsg = Bmsg .. SpamThrottle_UTF8Convert[p];
					i = i + 1;
				else
					Bmsg = Bmsg .. s1;
				end
			else
				if c1 == 151 and c2 == 139 then
					Bmsg = Bmsg .. "O";
					i = i + 1;
				else
					Bmsg = Bmsg .. s1;
				end
			end
		else
			Bmsg = Bmsg .. string.sub(Nmsg,i,i);
		end
	end
	Nmsg = Bmsg;
	Bmsg = "";

	for i = 1, string.len(Nmsg) do			-- for c in string.gmatch(Nmsg,"%u") do
		c = string.sub(Nmsg,i,i)	
		if (c ~= lastc) then
			Bmsg = Bmsg .. c;
		end
		lastc = c;
	end
	Nmsg = Bmsg

	if (Author ~= nil) then
		Nmsg = string.upper(Author) .. Nmsg;
	end

	return Nmsg
end


--============================
--= Utility function to count the number of entries in a table
--============================
function table.length(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--============================
--= Utility function to find the index of element in table T
--============================
function table.find(table, element) -- find element v of T satisfying f(v)
 	for key, value in ipairs(table) do
   		if value == element then
			return key
		end
  	end
	return nil
end

--============================
--= Utility function to check each variable in two tables making sure their variable type match.
--============================
function SpamThrottle_TableTypeMatch(table1, table2)
	for key,value in pairs(table1) do
		if type(table1[key]) ~= type(table2[key]) then
			return false
		end
	end
	return true;
end


--============================
--= OnLoad registers events and prints the welcome message
--============================
function SpamThrottle_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
UpdateFrame:Show();
	SpamThrottleMessage(true,SpamThrottleChatMsg.WelcomeMsg);
end

--============================
--= Initialize SpamThrottle
--============================
function SpamThrottle_init()
	
	-- Install or upgrade, Load Variable from default and show config window
	
	if type(SpamThrottle_Config) ~= "table" or not SpamThrottle_TableTypeMatch(Default_SpamThrottle_Config, SpamThrottle_Config) or (SpamThrottle_Config.Version ~= Default_SpamThrottle_Config.Version) then
		SpamThrottle_Config = {};
		SpamThrottle_Config = Default_SpamThrottle_Config;
		SpamThrottle_KeywordFilterList = {};
		SpamThrottle_KeywordFilterList = Default_SpamThrottle_KeywordFilterList;
		SpamThrottle_PlayerFilterList = {};
		SpamThrottle_PlayerFilterList = Default_SpamThrottle_PlayerFilterList;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadDefault);
	end
	
	if type(SpamThrottle_KeywordFilterList) ~= "table" then
		SpamThrottle_KeywordFilterList = {};
		SpamThrottle_KeywordFilterList = Default_SpamThrottle_KeywordFilterList;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadKeywordDefault);
	end

	if type(SpamThrottle_PlayerFilterList) ~= "table" then
		SpamThrottle_PlayerFilterList = {};
		SpamThrottle_PlayerFilterList = Default_SpamThrottle_PlayerFilterList;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadPlayerbanDefault);
	end
end


--============================
--= OnEvent is the main event handler for registered events
--============================
function SpamThrottle_OnEvent()
	if event == "PLAYER_ENTERING_WORLD" then
		SpamThrottle_init();
	end
end

--============================
--= User Interface Handling Functions
--============================

function SpamThrottleConfigFrame_OnShow()
	local theStatusValue;
	
	SpamThrottleConfigFrameLoadSettings(SpamThrottle_Config);
	SpamThrottle_LastClickedItem = nil;
	SpamThrottle_LastClickedTable = nil;
	SpamThrottle_LastClickedValue = nil;
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_KeywordFilterList));
	SpamThrottleStatusValue1:SetTextColor(1,1,1);
	SpamThrottleStatusValue1:SetText(theStatusValue);
	SpamThrottleStatusValue1:Show();
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_PlayerFilterList));
	SpamThrottleStatusValue2:SetTextColor(1,1,1);
	SpamThrottleStatusValue2:SetText(theStatusValue);
	SpamThrottleStatusValue2:Show();
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_GlobalBanList));
	SpamThrottleStatusValue4:SetTextColor(1,1,1);
	SpamThrottleStatusValue4:SetText(theStatusValue);
	SpamThrottleStatusValue4:Show();
	
	theStatusValue = string.format("%7d",UniqueCount);
	SpamThrottleStatusValue5:SetTextColor(1,1,1);
	SpamThrottleStatusValue5:SetText(theStatusValue);
	SpamThrottleStatusValue5:Show();
	
	theStatusValue = string.format("%7d",FilteredCount);
	SpamThrottleStatusValue6:SetTextColor(1,1,1);
	SpamThrottleStatusValue6:SetText(theStatusValue);
	SpamThrottleStatusValue6:Show();
	
	for key,value in pairs(SpamThrottleStatusMsg) do
		local nametag = getglobal("SpamThrottle" .. key);
		
		nametag:SetTextColor(1,1,1);
		nametag:SetText(value);
		nametag:Show();
	end
end

function SpamThrottleConfigFrameOkay_OnClick()
	SpamThrottleConfigFrameSaveSettings(SpamThrottle_Config);
	SpamThrottleConfigFrame:Hide();
end

function SpamThrottleConfigFrameLoadSettings(configset)
	SpamThrottle_SetAlphas(SpamThrottle_Config.STActive);
	SpamThrottle_SetBanSliderAlpha(SpamThrottle_Config.STBanPerm);
	for key,value in pairs(configset) do
		SpamThrottleMessage(DebugMsg, key, value, "type=",type(value));
		if key == "Version" then
			-- do nothing
		elseif type(value) == "boolean"  then
			local nametag = getglobal(key .. "_CheckButton");
			if type(nametag) ~= "nil" then
				if value then
					nametag:SetChecked(1);
				else
					nametag:SetChecked(0);
				end
				nametag.tooltipText = SpamThrottleConfigObjectTooltip[key];

				nametag = getglobal(key .. "_CheckButtonText");
				nametag:SetText(SpamThrottleConfigObjectText[key]);
				nametag:SetTextColor(1,1,1);
				
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end

		elseif type(value) == "number" then
			local nametag = getglobal(key .. "_Slider");
			if type(nametag) ~= "nil" then
				nametag:SetValue(value);

				nametag = getglobal(key .. "_SliderLow");
				nametag:SetText("0");
				nametag = getglobal(key .. "_SliderHigh");
				nametag:SetText("3600");

				nametag = getglobal(key .. "_SliderText");
				nametag:SetText(SpamThrottleConfigObjectText[key]);
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end
		
		elseif type(value) == "string" then
			local nametag = getglobal(key .. "_EditBox");
			if type(nametag) ~= "nil" then
				nametag:SetText(value);
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end
		end
	end
end

function SpamThrottleConfigFrameSaveSettings(configset)
	for key,oldvalue in pairs(configset) do
		if key == "Version" then
			-- do nothing
			
		elseif type(oldvalue) == "boolean"  then
			local nametag = getglobal(key .. "_CheckButton");
			if type(nametag) ~= "nil" then
				local newvalue = not not nametag:GetChecked();
				if newvalue ~= oldvalue then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
			
		elseif type(oldvalue) == "number" then
			local nametag = getglobal(key .. "_Slider");
			if type(nametag) ~= "nil" then
				local newvalue = nametag:GetValue();
				if (oldvalue ~= newvalue) then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
		
		elseif type(oldvalue) == "string" then
			local nametag = getglobal(key .. "_EditBox");
			if type(nametag) ~= "nil" then
				local newvalue = nametag:GetText();
				if (oldvalue ~= newvalue) then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end					
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
		end
	end
end

function SpamThrottle_SetAlphas(myStatus)
	local theAlpha = 1.0;

	if not myStatus then
		theAlpha = 0.5;
	end
	
	STDupFilter_CheckButton:SetAlpha(theAlpha);	
	STColor_CheckButton:SetAlpha(theAlpha);
	STFuzzy_CheckButton:SetAlpha(theAlpha);
	STGoldSeller_CheckButton:SetAlpha(theAlpha);
	STChinese_CheckButton:SetAlpha(theAlpha);
	STCtrlMsgs_CheckButton:SetAlpha(theAlpha);
	STYellMsgs_CheckButton:SetAlpha(theAlpha);
	STSayMsgs_CheckButton:SetAlpha(theAlpha);
	STWispMsgs_CheckButton:SetAlpha(theAlpha);
	STReverse_CheckButton:SetAlpha(theAlpha);
	STGap_Slider:SetAlpha(theAlpha);
	
	if myStatus then
		STDupFilter_CheckButton:Enable();
		STColor_CheckButton:Enable();
		STFuzzy_CheckButton:Enable();
		STGoldSeller_CheckButton:Enable();
		STChinese_CheckButton:Enable();
		STCtrlMsgs_CheckButton:Enable();
		STYellMsgs_CheckButton:Enable();
		STSayMsgs_CheckButton:Enable();
		STWispMsgs_CheckButton:Enable();
		STReverse_CheckButton:Enable();
	else
		STDupFilter_CheckButton:Disable();
		STColor_CheckButton:Disable();
		STFuzzy_CheckButton:Disable();
		STGoldSeller_CheckButton:Disable();
		STChinese_CheckButton:Disable();
		STCtrlMsgs_CheckButton:Disable();
		STYellMsgs_CheckButton:Disable();
		STSayMsgs_CheckButton:Disable();
		STWispMsgs_CheckButton:Disable();
		STReverse_CheckButton:Disable();
	end
	
	SpamThrottle_SetWispBackAlpha(myStatus);
end

function SpamThrottle_SetWispBackAlpha(myStatus)
	local theAlpha = 1.0;
	
	if not myStatus then
		theAlpha = 0.5;
	end
	
	STWispBack_CheckButton:SetAlpha(theAlpha);
	
	if myStatus then
		STWispBack_CheckButton:Enable();
	else
		STWispBack_CheckButton:Disable();
	end
end


function SpamThrottle_SetBanSliderAlpha(myStatus)	
	if myStatus then
		STBanTimeout_Slider:SetAlpha(0.5);
	else
		STBanTimeout_Slider:SetAlpha(1.0);
	end
end


function SpamThrottle_KeywordList_Update()
	local tableLen = table.length(SpamThrottle_KeywordFilterList);
	local line; -- 1 through 9 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	
	FauxScrollFrame_Update(KeywordListScrollFrame, tableLen, 9, 16);

	for line = 1,9 do
		local nametag = getglobal("SpamThrottleKeywordItem" .. line)
		lineplusoffset = line + FauxScrollFrame_GetOffset(KeywordListScrollFrame);
					
		if lineplusoffset <= tableLen then
			local listword = string.gsub(SpamThrottle_KeywordFilterList[lineplusoffset]," ","_");
			nametag:SetText(listword);
			if nametag ~= SpamThrottle_LastClickedItem then
				nametag:SetTextColor(1,1,1);
			else
				nametag:SetTextColor(1,1,0);
			end
			nametag:Show();
		else
			nametag:Hide();
		end
	end
end

function SpamThrottle_AddKeyword(theKeyword)
	theKeyword = string.gsub(theKeyword,"_"," ");
	local index = table.find(SpamThrottle_KeywordFilterList,theKeyword)
	if index ~= nil then return end;

	table.insert(SpamThrottle_KeywordFilterList,theKeyword);
	table.sort(SpamThrottle_KeywordFilterList);
	SpamThrottle_KeywordList_Update();
end

function SpamThrottle_AddPlayerban(thePlayer)
	thePlayer = string.upper(string.gsub(thePlayer," ",""));
	local index = table.find(SpamThrottle_PlayerFilterList,thePlayer)
	if index then return end;

	SpamThrottle_PlayerBanTime[thePlayer] = time();
	
	table.insert(SpamThrottle_PlayerFilterList,thePlayer);
	table.sort(SpamThrottle_PlayerFilterList);
	SpamThrottle_PlayerbanList_Update();
end

function SpamThrottle_RemovePlayerban(thePlayer)
	thePlayer = string.upper(string.gsub(thePlayer," ",""));
	SpamThrottle_PlayerBanTime[thePlayer] = nil;
		
	local index = table.find(SpamThrottle_PlayerFilterList,thePlayer)
	if not index then return end;
	table.remove(SpamThrottle_PlayerFilterList,index);
	SpamThrottle_PlayerbanList_Update();
end

function SpamThrottleKeywordList_OnClick(nametag)
	local value = nametag:GetText();

	if SpamThrottle_LastClickedItem ~= nil then
		SpamThrottle_LastClickedItem:SetTextColor(1,1,1);
	end
	
	SpamThrottle_LastClickedItem = nametag;
	SpamThrottle_LastClickedTable = SpamThrottle_KeywordFilterList;
	SpamThrottle_LastClickedValue = nametag:GetText();
	
	nametag:SetTextColor(1,1,0);
	nametag:Show();
end

function SpamThrottlePlayerList_OnClick(nametag)
	local value = nametag:GetText();

	if SpamThrottle_LastClickedItem ~= nil then
		SpamThrottle_LastClickedItem:SetTextColor(1,1,1);
	end
	
	SpamThrottle_LastClickedItem = nametag;
	SpamThrottle_LastClickedTable = SpamThrottle_PlayerFilterList;
	SpamThrottle_LastClickedValue = nametag:GetText();
	
	nametag:SetTextColor(1,1,0);
	nametag:Show();
end

function SpamThrottle_RemoveLastClicked()
	if SpamThrottle_LastClickedItem then
		local index = table.find(SpamThrottle_LastClickedTable,string.gsub(SpamThrottle_LastClickedValue,"_"," "));
		table.remove(SpamThrottle_LastClickedTable,index);
	else
		return;
	end
	
	if SpamThrottle_LastClickedTable == SpamThrottle_KeywordFilterList then
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottle_KeywordList_Update();
	elseif SpamThrottle_LastClickedTable == SpamThrottle_PlayerFilterList then
		SpamThrottle_RemovePlayerban(SpamThrottle_LastClickedValue);
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottle_PlayerbanList_Update();
	else
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottleMessage(ErrorMsg,"Attempt to remove item=",SpamThrottle_LastClickedItem," from non-existent table=",SpamThrottle_LastClickedTable);
	end
end

function SpamThrottle_PlayerbanList_Update()
	local tableLen = table.length(SpamThrottle_PlayerFilterList);
	local line; -- 1 through 9 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	
	FauxScrollFrame_Update(PlayerbanListScrollFrame, tableLen, 9, 16);

	for line = 1,9 do
		local nametag = getglobal("SpamThrottlePlayerbanItem" .. line)
		lineplusoffset = line + FauxScrollFrame_GetOffset(PlayerbanListScrollFrame);
					
		if lineplusoffset <= tableLen then
			nametag:SetText(SpamThrottle_PlayerFilterList[lineplusoffset]);
			if nametag ~= SpamThrottle_LastClickedItem then
				nametag:SetTextColor(1,1,1);
			else
				nametag:SetTextColor(1,1,0);
			end
			nametag:Show();
		else
			nametag:Hide();
		end
	end
end

--============================
--= DecodeMessage - Print a detailed breakdown byte-by-byte of the message
--============================
function SpamThrottle_DecodeMessage(msg,Author)
	local theString ="";
	local Nlen = string.len(msg);
	
	for i = 1, Nlen do
		if i ~= Nlen then
			s1 = string.sub(msg,i,i);
			s2 = string.sub(msg,i+1,i+1);
			c1 = string.byte(s1);
			c2 = string.byte(s2);
			
			if c1 > 192 and c1 <= 225 then -- it's a UTF-8 2 byte code
				p1 = c1 - math.floor(c1/32)*32;
				p2 = c2 - math.floor(c2/64)*64;
				p = p1*64+p2;
				
				if SpamThrottle_UTF8Convert[p] == nil then
					SpamThrottleMessage(true,Author,": Unhandled UTF code: ",string.format("%x",p));
				end
				theString = theString .. string.format("[UTF8-%x]",p);
				i = i + 1;
			else -- it's a normal char
				theString = theString .. string.format("[%s-%x]",s1,c1);
			end
		end
	end
	SpamThrottleMessage(true,"Decoded:",theString);
end


--============================
--= RecordMessage - save it in our database
--============================
function SpamThrottle_RecordMessage(msg,Author)
	if (playername ~= "") then
		local Msg = SpamThrottle_strNorm(msg,Author);
		
		SpamThrottleMessage(DebugMsg,"received normalized message ",Msg);
		
		local frameName = this:GetName()
		if (MessageList[frameName][Msg] == nil) then  -- If we have NOT seen this text before
			UniqueCount = UniqueCount + 1
			MessageList[frameName][Msg] = true;
			MessageCount[frameName][Msg] = 1;
			MessageTime[frameName][Msg] = time();
			MessageLatestTime[frameName][Msg] = time();
		else
			MessageCount[frameName][Msg] = (MessageCount[frameName][Msg] or 0) + 1;
		end		
	end
end


--============================
--= QQCheck - Determine if the message contains a QQ name
--= Make sure to send it the original message
--============================
function SpamThrottle_QQCheck(msg,Author)
	local testResult = false;
	
	if msg == nil then return false end
	
	if string.find(msg, "QQ[ :~%d][ :~%d][ :~%d][ :~%d][ :~%d][ :~%d][ :~%d]") then
		testResult = true;
	end
	
	local Nlen = string.len(msg);
	
	for i = 1, string.len(msg) do
		if string.byte(string.sub(msg,i,i)) > 225 then
			testResult = true;
		end
	end
	
	if testResult then
		SpamThrottleMessage(DebugMsg,"QQCheck flagged: (",Author,") ",msg);
	end
	
	return testResult;
end

--============================
--= SpamScoreBlock - Determine the spam score and perma-block if exceeded
--= Returns TRUE if blocked
--= Returns FALSE if clear
--============================
function SpamThrottle_SpamScoreBlock(msg,NormalizedMessage,Author)
	local theScore = 0;
	local theThreshold = 4;
	local BlockFlag = false;
	
	local index = table.find(SpamThrottle_PlayerFilterList,string.upper(Author));
	if index then return true; end
	
	for key, value in pairs(SpamThrottleGSO2) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then
			theScore = theScore + 2
		end
	end
	
	for key, value in pairs(SpamThrottleGSO1) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then
			theScore = theScore + 1
		end
	end
	
	for key, value in pairs(SpamThrottleGSC2) do
		if (string.find(msg,value) ~= nil) then
			theScore = theScore + 2
		end
	end
	
	for key, value in pairs(SpamThrottleGSC1) do
		if (string.find(msg,value) ~= nil) then
			theScore = theScore + 1
		end
	end
	
	for key, value in pairs(SpamThrottleGSUC5) do
		if (string.find(string.upper(msg),value) ~= nil) then
			theScore = theScore + 5
		end
	end

	for key, value in pairs(SpamThrottleSWLO) do
		local testval = SpamThrottle_strNorm(value,Author);
		if (string.find(NormalizedMessage,testval) ~= nil and string.len(NormalizedMessage) == string.len(testval)) then
			theScore = theScore + 100
		end
	end
	
	
	if theScore > theThreshold then
		BlockFlag = true;
		SpamThrottle_AddPlayerban(Author);
		SpamThrottle_PlayerbanList_Update();
		SpamThrottleMessage(false, "Blocked "..Author.." gold advertising: "..msg);
	end
	
	return BlockFlag;
end

--============================
--= NonNativeBlock - Determine if non-native block is called for
--============================
function SpamThrottle_NonNativeBlock(msg,Author)
	local BlockFlag = false;
	i = string.find(msg,Prefix1);
	
	if (i ~= nil) then
		local theValue = string.sub(msg,i+2,i+8);
		
		isAllowed = false;
		for key, value in pairs(SpamThrottle_Native) do
			if (string.find(msg,Prefix1..value) ~= nil) then
				isAllowed = true;
			end
		end
		
		if (isAllowed ~= true) then
			BlockFlag = true;
		end
	end

	return BlockFlag;
end

--============================
--= ShouldBlock - Determine whether message should be blocked.
--= return = 0, don't block.
--= return = 1, use graytext to de-emphasize
--= return = 2, block altogether.
--============================
function SpamThrottle_ShouldBlock(msg,Author,event,channel)
	local BlockFlag = false;
	local NormalizedMessage = "";
	
	
	NormalizedMessage = SpamThrottle_strNorm(msg, Author);
	UpperCaseMessage = string.upper(msg);
	OriginalMessage = msg;
	

	if (NormalizedMessage == nil) then	-- If no message just tell caller to block altogether
		return 2;
	end

	if (SpamThrottle_Config.STActive == false or Author == UnitName("player")) then	-- If filter not active or it's our message, just let it go thru
		return 0;
	end

	if (SpamThrottle_Config.STWhiteChannel1 ~= "" or SpamThrottle_Config.STWhiteChannel2 ~= "" or SpamThrottle_Config.STWhiteChannel3 ~= "") then
		local normChannel = SpamThrottle_strNorm(channel,"");
		local testval1 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel1,"");
		local testval2 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel2,"");
		local testval3 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel3,"");
						
		if (testval1 ~= "" and string.find(normChannel,testval1) ~= nil) then return 0; end;
		if (testval2 ~= "" and string.find(normChannel,testval2) ~= nil) then return 0; end;
		if (testval3 ~= "" and string.find(normChannel,testval3) ~= nil) then return 0; end;
	end

	if time() - LastPurgeTime > SpamThrottle_Config.STGap then
		SpamThrottleMessage(DebugMsg,"purging database to free memory");
		LastPurgeTime = time();
		for i=1, NUM_CHAT_WINDOWS do
			for key, value in pairs(MessageTime["ChatFrame"..i]) do
				if time() - LastPurgeTime > 300 then
					SpamThrottleMessage(DebugMsg,"Removing key ",key," as it is older than timeout.");
					MessageList["ChatFrame"..i][key] = nil;
					MessageTime["ChatFrame"..i][key] = nil;
					MessageLatestTime["ChatFrame"..i][key] = nil;
					MessageCount["ChatFrame"..i][key] = nil;
				end
			end
		end
	end
	
	if string.find(msg, SpamThrottleGeneralMask) then
		SpamThrottleMessage(BlockReason,"General Mask Block: ",msg);
		BlockFlag = true;
	end
	
	if SpamThrottle_SpamScoreBlock(msg,NormalizedMessage,Author) then
		SpamThrottleMessage(BlockReason,"Spam Score Block ",SpamThrottle_SpamScoreBlock(msg,NormalizedMessage,Author),": ",msg);		
		BlockFlag = true;
	end
	
	if STGoldSeller then
		if SpamThrottle_NonNativeBlock(OriginalMessage,Author) then
			SpamThrottleMessage(BlockReason,"Non Native Block: ",msg);
			BlockFlag = true;
		end
	end

	if not SpamThrottle_Config.STBanPerm then
		if time() - LastAuditTime > PlayerListAuditGap then
			SpamThrottleMessage(DebugMsg, "auditing player filter list and expiring timeouts");
			LastAuditTime = time();
			for key,value in pairs(SpamThrottle_PlayerBanTime) do
				if time() - value > SpamThrottle_Config.STBanTimeout then
					SpamThrottleMessage(DebugMsg, "removing playername " .. key .. " from player filter list");
					SpamThrottle_PlayerBanTime[string.upper(key)] = nil;
					local index = table.find(SpamThrottle_PlayerFilterList,string.upper(key));
					if index then table.remove(SpamThrottle_PlayerFilterList,index) end;
					SpamThrottle_PlayerbanList_Update();
				end
			end
		end
	end

	for key, value in pairs(SpamThrottle_KeywordFilterList) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then
			BlockFlag = true;
			SpamThrottleMessage(BlockReason,"Keyword Filter on ",testval,": ",msg);			
		end
	end

	if SpamThrottle_Config.STReverse then -- Completely different processing if this is the case
		if BlockFlag then -- we have a match with the keyword filter, let it go through.
			return 0;
		else
			if SpamThrottle_Config.STColor then
				return 1;
			else
				return 2;
			end
		end
	end
	
	for key, value in pairs(SpamThrottle_PlayerFilterList) do
		local testval = string.upper(string.gsub(value," ",""));
		if (string.find(string.upper(Author),testval) ~= nil) then
			BlockFlag = true;
			SpamThrottleMessage(BlockReason,"Playername Filter on ",testval,": ",msg);			
		end
	end

	if (SpamThrottle_Config.STChinese) then
		if (string.find(OriginalMessage,"[\228-\233]") ~=nil) then BlockFlag = true; end
		if SpamThrottle_QQCheck(OriginalMessage,Author) then
			BlockFlag = true;
			SpamThrottleMessage(BlockReason,"QQ message: ",msg);
		end
	end

	local frameName = this:GetName()
	MessageLatestTime[frameName][NormalizedMessage] = time();

	if (event == "CHAT_MSG_YELL" or event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_EMOTE") then
		if (SpamThrottle_Config.STDupFilter and MessageList[frameName][NormalizedMessage] ~= nil) then	-- this should always be true, but worth checking to avoid an error
			if time() - MessageTime[frameName][NormalizedMessage] <= SpamThrottle_Config.STGap then
				BlockFlag = true;
			end
		end
	else -- it is a channel message, handled differently than yell msgs (or they were)
		if (SpamThrottle_Config.STDupFilter and MessageList[frameName][NormalizedMessage] ~= nil) then	-- If duplicate message filter enabled AND we have seen this exact text before
			if MessageTime[frameName][NormalizedMessage] and time() - MessageTime[frameName][NormalizedMessage] <= SpamThrottle_Config.STGap then
				BlockFlag = true;
			end
		end
	end

	if BlockFlag then
		FilteredCount = FilteredCount + 1;
	end
	
	if SpamThrottle_Config.STColor then
		if BlockFlag then
			return 1;
		end
	end
	
	if BlockFlag then
		return 2;
	end
		
	return 0;
end

--============================
--= ChatFrame_OnEvent - The main event handler
--============================
function SpamThrottle_ChatFrame_OnEvent(event)
-- arg1 is the actual message
-- arg2 is the player name
-- arg4 is the composite channel name (e.g. "3. global")
-- arg8 is the channel number (e.g. "3")
-- arg9 is the channel name (e.g. "global")

	local hideColor = "|cFF5C5C5C";
	local oppFacColor = "|cA0A00000";
	local theColor = hideColor;

	if SpamThrottle_Config == nil then SpamThrottle_init(); end
	
	if not SpamThrottle_Config.STActive then
		SpamThrottle_OrigChatFrame_OnEvent(event);
		return;
	end;

	if (SpamThrottle_Config.STCtrlMsgs) then -- Remove the left/joined channel spam and a few other notification messages
		if (event == "CHANNEL_INVITE_REQUEST" or event == "CHAT_MSG_CHANNEL_JOIN" or event == "CHAT_MSG_CHANNEL_LEAVE" or event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER") then		
			return;
		end
	end
			
	if arg2 then -- if this is not a server message
		if (event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_EMOTE" or (event == "CHAT_MSG_YELL" and SpamThrottle_Config.STYellMsgs) or (event == "CHAT_MSG_SAY" and SpamThrottle_Config.STSayMsgs) or (event == "CHAT_MSG_WHISPER" and SpamThrottle_Config.STWispMsgs)) then
						
			-- Code to handle message goes here. Just return if we are going to ignore it.
			local channelFound

			if event == "CHAT_MSG_CHANNEL" then
				for index, value in this.channelList do
					if ((arg7 > 0) and (this.zoneChannelList[index] == arg7)) or strupper(value) == strupper(arg9) then
						channelFound = value
					end
				end
				if not channelFound then return end
			end
			
			if arg1 and arg2 then	-- only execute this code once although event handler is called many times per message
				local NormalizedMessage = SpamThrottle_strNorm(arg1, arg2);
				
--				if arg2 == "Tdhgc" then
--					SpamThrottle_DecodeMessage(arg1,arg2);
--					SpamThrottleMessage(true,"Normalized=",NormalizedMessage);
--				end
				
				--if time() == MessageLatestTime[NormalizedMessage] then return end;
			end

			local BlockType = SpamThrottle_ShouldBlock(arg1,arg2,event,arg9);
			SpamThrottle_RecordMessage(arg1,arg2);
			
			if SpamThrottle_Config.STWispBack and event == "CHAT_MSG_WHISPER" and not SpamThrottle_Config.STReverse then
				if BlockType == 1 or BlockType == 2 then
					SendChatMessage(SpamThrottleChatMsg.WhisperBack, "WHISPER", nil, arg2);
					SpamThrottleMessage(BlockReportMode, "BLOCKED [",arg4,"] {",arg2,"} ",arg1);
					return;
				end
			end

			if BlockType == 2 then
				SpamThrottleMessage(BlockReportMode, "BLOCKED [",arg4,"] {",arg2,"} ",arg1);
				return;
			end
			
			if BlockType == 3 then
				theColor = oppFacColor;
			end
			
			if BlockType == 1 or BlockType == 3 then
				local CleanText = "";
				CleanText = string.gsub(arg1,"|c%x%x%x%x%x%x%x%x", "");
				CleanText = string.gsub(CleanText,"|r", "");
				CleanText = string.gsub(CleanText,"|H.-|h", "");
				CleanText = string.gsub(CleanText,"|h", "");
				
				if event == "CHAT_MSG_YELL" then
					CleanText = theColor .. "[" .. arg2 .. "] yells: " .. CleanText .. "|r";
				else
					if event == "CHAT_MSG_SAY" then
						CleanText = theColor .. "[" .. arg2 .. "] says: " .. CleanText .. "|r";
					else
						if event == "CHAT_MSG_WHISPER" then
							CleanText = theColor .. "[" .. arg2 .. "] whispers: " .. CleanText .. "|r";
						else
							if event == "CHAT_MSG_EMOTE" then
								CleanText = theColor .. arg2 .. " " .. CleanText .. "|r";
							else
								CleanText = theColor .. "[" .. arg4 .. "] [" .. arg2 .. "]: " .. CleanText .. "|r";
							end
						end
					end
				end
				
				this:AddMessage(CleanText);
				return;
			end
		end
	end

	local theStatusValue = string.format("%7d",UniqueCount);
	SpamThrottleStatusValue5:SetText(theStatusValue);

	theStatusValue = string.format("%7d",FilteredCount);
	SpamThrottleStatusValue6:SetText(theStatusValue);

	SpamThrottle_OrigChatFrame_OnEvent(event);
end


--============================
--= Register the Slash Command
--============================
SlashCmdList["SPTHRTL"] = function(_msg)
	if (_msg) then
		local _, _, cmd, arg1 = string.find(string.upper(_msg), "([%w]+)%s*(.*)$");		
		if ("OFF" == cmd) then -- disable the filter
			local confirmMsg = "|cFFFFFFFFSpamThrottle: |cFF00BEFFFilter Disabled|cFFFFFFFF"
			SpamThrottle_Config.STActive = false;
			DEFAULT_CHAT_FRAME:AddMessage(confirmMsg);
		elseif ("ON" == cmd) then -- enable the filter
			local confirmMsg = "|cFFFFFFFFSpamThrottle: |cFF00BEFFFilter Enabled"
			SpamThrottle_Config.STActive = true;
			if SpamThrottle_Config.STColor then
				confirmMsg = confirmMsg .. " (color mode)|cFFFFFFFF."
			else
				confirmMsg = confirmMsg .. " (hide mode)|cFFFFFFFF."
			end
			DEFAULT_CHAT_FRAME:AddMessage(confirmMsg);
		elseif ("COLOR" == cmd) then -- change the spam to a darker color to make it easy for your eyes to skip (but you still see it)
			SpamThrottle_Config.STColor = true;
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFColor|cFFFFFFFF mode enabled.");
		elseif ("HIDE" == cmd) then -- completely hide the spam
			SpamThrottle_Config.STColor = false;
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFHide|cFFFFFFFF mode enabled.");
		elseif ("FUZZY" == cmd) then -- enable the fuzzy matching filter (default)
			SpamThrottle_Config.STFuzzy = true;
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFFuzzy|cFFFFFFFF match filter enabled.");
		elseif ("NOFUZZY" == cmd) then -- disable the fuzzy matching filter, instead requiring exact matches
			SpamThrottle_Config.STFuzzy = false;
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFFuzzy|cFFFFFFFF match filter disabled - strict match mode.");
		elseif ("CBLOCK" == cmd) then -- block messages with chinese/japanese/korean characters
				SpamThrottle_Config.STChinese = true;
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFChinese/Japanese/Korean|cFFFFFFFF messages are now blocked.");
		elseif ("NOCBLOCK" == cmd) then -- allow messages with chinese/japanese/korean characters
				SpamThrottle_Config.STChinese = false;
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFChinese/Japanese/Korean|cFFFFFFFF messages are now allowed.");
		elseif ("RESET" == cmd) then -- reset the unique message list
			MessageList = {}
			MessageCount = {}
			MessageTime = {}
			MessageLatestTime = {}
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: |cFF00BEFFReset|cFFFFFFFF of unique message database complete.");
		elseif (tonumber(_msg) ~= nil) then
			local gapseconds = tonumber(_msg);
			if (gapseconds >= 0 and gapseconds <= 10000) then
				SpamThrottle_Config.STGap = tonumber(_msg);
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: gapping now set to |cFF00BEFF" .. SpamThrottle_Config.STGap .. "|cFFFFFFFF seconds.");
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFSpamThrottle: gapping value can only be set from 0 to 10000 seconds.");
			end
		elseif ("HELP" == cmd) then
			SpamThrottleMessage(true,"Type /st or /spamthrottle to display the configuration options menu.");
			
		elseif ("TEST" == cmd) then
			-- Placeholder for testing
		
		else -- Just show the configuration frame
			SpamThrottleConfigFrame:Show();
		end
	end
end

SLASH_SPTHRTL1 = "/spamthrottle";
SLASH_SPTHRTL2 = "/st";
