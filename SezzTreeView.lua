--[[

	s:UI Flat TreeView Control

	Martin Karer / Sezz, 2014
	http://www.sezz.at

--]]

local MAJOR, MINOR = "Sezz:Controls:TreeView-0.1", 1;
local APkg = Apollo.GetPackage(MAJOR);
if (APkg and (APkg.nVersion or 0) >= MINOR) then return; end

local SezzTreeView = APkg and APkg.tPackage or {};
local log, CallbackHandler;
local Apollo = Apollo;

-- Lua API
local tinsert, pairs, ipairs, strmatch = table.insert, pairs, ipairs, string.match;

-----------------------------------------------------------------------------

local kstrNodePrefix = "SezzTreeViewNode";

-----------------------------------------------------------------------------
-- Colors/Styling
-----------------------------------------------------------------------------

local knNodeIndent = 18;
local knNodeHeight = 28;
local kstrNodeBGColorDefault = "ff121314";
local kstrNodeBGColorHover = "ff1C1C1F";
local kstrNodeBGColorActive = "ff27272B";

-----------------------------------------------------------------------------
-- Window Definitions
-----------------------------------------------------------------------------

local function CreateNodeXml(strName, strText, nNodeIndent)
	return {
		__XmlNode = "Form",
		Class = "Window",
		Name = strName,
		LAnchorPoint = 0, TAnchorPoint = 0, RAnchorPoint = 1, BAnchorPoint = 0,
		LAnchorOffset = 0, TAnchorOffset = 0, RAnchorOffset = 0, BAnchorOffset = knNodeHeight,
		IgnoreMouse = 1, Escapable = 0, NoClip = 0, Border = 0, Overlapped = 0, NoClip = 0, RelativeToClient = 1,
		{
			__XmlNode = "Control",
			Class = "Window",
			Name = "Node",
			Sprite = "BasicSprites:WhiteFill",
			Picture = 1,
			BGColor = kstrNodeBGColorDefault,
			LAnchorPoint = 0, TAnchorPoint = 0, RAnchorPoint = 1, BAnchorPoint = 0,
			LAnchorOffset = 0, TAnchorOffset = 0, RAnchorOffset = 0, BAnchorOffset = knNodeHeight,
			IgnoreMouse = 0, Escapable = 0, NoClip = 0, Border = 0, Overlapped = 0, NoClip = 0, RelativeToClient = 1,
			-- Events
			{ __XmlNode = "Event", Name = "MouseEnter",			Function = "OnNodeMouseEnter" },
			{ __XmlNode = "Event", Name = "MouseExit",			Function = "OnNodeMouseExit" },
			{ __XmlNode = "Event", Name = "MouseButtonDown",	Function = "OnNodeMouseDown" },
			{ __XmlNode = "Event", Name = "MouseButtonUp",		Function = "OnNodeMouseUp" },
			-- Pixies
			{
				__XmlNode = "Pixie",
				Font = "CRB_Pixel",
				Text = strText,
				LAnchorPoint = 0, TAnchorPoint = 0, RAnchorPoint = 1, BAnchorPoint = 1,
				LAnchorOffset = 30 + nNodeIndent, TAnchorOffset = 0, RAnchorOffset = 0, BAnchorOffset = 0,
				DT_VCENTER = true,
				BGColor = "white",
			},
			{
				__XmlNode = "Pixie",
				Line = true,
				LAnchorPoint = 0, TAnchorPoint = 1, RAnchorPoint = 1, BAnchorPoint = 1,
				LAnchorOffset = 0, TAnchorOffset = 0, RAnchorOffset = 0, BAnchorOffset = 0,
				BGColor = kstrNodeBGColorHover,
			},
		},
	};
end

local function CreateIconPixieXml(strSprite, nLevel)
	return {
		strSprite = strSprite,
		cr = "white",
		loc = {
			fPoints = { 0, 0, 0, 1 },
			nOffsets = { 9 + nLevel * knNodeIndent, knNodeHeight / 2 - 8, 9 + nLevel * knNodeIndent + 16, 0 },
		},
	};
end

-----------------------------------------------------------------------------
-- Node Events
-----------------------------------------------------------------------------

function SezzTreeView:OnNodeMouseEnter(wndHandler, wndControl)
	if (wndHandler ~= wndControl) then return; end

	if (not self.wndActiveNode or self.wndActiveNode ~= wndControl) then
		wndControl:SetBGColor(kstrNodeBGColorHover);
	end

	self.CallbackHandler:Fire("MouseEnter", wndControl:GetName());
end

function SezzTreeView:OnNodeMouseExit(wndHandler, wndControl)
	if (wndHandler ~= wndControl) then return; end

	if (not self.wndActiveNode or self.wndActiveNode ~= wndControl) then
		wndControl:SetBGColor(kstrNodeBGColorDefault);
	end

	self.CallbackHandler:Fire("MouseExit", wndControl:GetName());
end

function SezzTreeView:OnNodeMouseDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick)
	if (wndHandler ~= wndControl) then return; end

	if (eMouseButton == GameLib.CodeEnumInputMouse.Left) then
		wndControl:SetBGColor(kstrNodeBGColorActive);

		if (bDoubleClick) then
			-- Expand/Collapse
			local wndNode = wndControl:GetParent();
			local strNode = wndNode:GetName();

			if (#self.tNodes[strNode].tChildren > 0) then
				local tIconOffsets = self.tNodes[strNode].tPixieIcon.loc.nOffsets;
				if (not (nLastRelativeMouseX and nLastRelativeMouseY and nLastRelativeMouseX >= tIconOffsets[1] and nLastRelativeMouseX <= tIconOffsets[3] and nLastRelativeMouseY >= tIconOffsets[2])) then
					self:ToggleNode(strNode);
				end
			end

			self.CallbackHandler:Fire("NodeDoubleClick", strNode);
		end
	end
end

function SezzTreeView:OnNodeMouseUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	if (wndHandler ~= wndControl) then return; end

	if (eMouseButton == GameLib.CodeEnumInputMouse.Left) then
		local wndNode = wndControl:GetParent();
		local strNode = wndNode:GetName();

		if (not self.wndActiveNode or self.wndActiveNode ~= wndControl) then
			if (self.wndActiveNode) then
				local wndPreviousActiveNode = self.wndActiveNode;
				self.wndActiveNode = nil;
				self:OnNodeMouseExit(wndPreviousActiveNode, wndPreviousActiveNode);
			end

			-- Highlight Node
			self.wndActiveNode = wndControl;
			wndControl:SetBGColor(kstrNodeBGColorActive);
			self.CallbackHandler:Fire("NodeSelected", strNode);
		end

		-- Expand/Collapse
		if (#self.tNodes[strNode].tChildren > 0) then
			local tIconOffsets = self.tNodes[strNode].tPixieIcon.loc.nOffsets;
			if (nLastRelativeMouseX and nLastRelativeMouseY and nLastRelativeMouseX >= tIconOffsets[1] and nLastRelativeMouseX <= tIconOffsets[3] and nLastRelativeMouseY >= tIconOffsets[2]) then
				self:ToggleNode(strNode);
			end
		end
	end
end

-----------------------------------------------------------------------------
-- Constructor
-----------------------------------------------------------------------------

function SezzTreeView:New(wndParent, nLevel)
	local self = setmetatable({
		wndParent = wndParent,
		nLevel = nLevel or 1,
		bRendered = true,
		nNodes = 0,
	}, { __index = self });

	self.strRootNode = wndParent:GetName() or kstrNodePrefix;
	self.tNodes = {
		[self.strRootNode] = {
			tChildren = {},
			nLevel = 0,
		},
	};

	self.CallbackHandler = CallbackHandler:New(SezzTreeView);
	Apollo.RegisterEventHandler("VarChange_FrameCount", "VisibleItemsCheck", self);

	return self;
end

-----------------------------------------------------------------------------
-- Add Nodes
-----------------------------------------------------------------------------

local function AddNode(self, strParentNodeName, strText, strIcon, tData)
	local tParentNode = self.tNodes[strParentNodeName];
	local nLevel = tParentNode.nLevel;
	local strName = kstrNodePrefix..self.nNodes;

	-- Create Node
	local tXmlNodeDefinition = CreateNodeXml(strName, strText, nLevel * knNodeIndent);
	local wndParent = strParentNodeName == self.strRootNode and self.wndParent or self.tNodes[strParentNodeName].wndNode;
	local xmlDoc = XmlDoc.CreateFromTable({ __XmlNode = "Forms", tXmlNodeDefinition});
	local wndNode = Apollo.LoadForm(xmlDoc, strName, wndParent, self);

	-- Add Icon
	local tPixieIcon = CreateIconPixieXml(tParentNode.bCollapsed and "SezzTreeViewSprites:CaretRight" or "SezzTreeViewSprites:CaretDown", nLevel);
	tPixieIcon.nId = wndNode:AddPixie(tPixieIcon);

	-- Parent to Child Relation
	tinsert(self.tNodes[strParentNodeName].tChildren, wndNode);
	self.tNodes[strName] = {
		nLevel = nLevel + 1,
		strText = strText,
		tChildren = {},
		tPixieIcon = tPixieIcon,
		tData = tData,
		wndNode = wndNode,
	};

	-- Done
	self.nNodes = self.nNodes + 1;
	return strName;
end

function SezzTreeView:AddNode(strText, strIcon, tData)
	return AddNode(self, self.strRootNode, strText, strIcon, tData);
end

function SezzTreeView:AddChildNode(strParentNodeName, strText, strIcon, tData)
	return AddNode(self, strParentNodeName, strText, strIcon, tData);
end

-----------------------------------------------------------------------------
-- Node Properties
-----------------------------------------------------------------------------

function SezzTreeView:GetNodeText(strNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end
	return tNode.strText;
end

function SezzTreeView:GetNodeData(strNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end
	return tNode.tData;
end

-----------------------------------------------------------------------------
-- Render/Update
-----------------------------------------------------------------------------

function SezzTreeView:ArrangeNodes(wndParent)
	local tRootNode = self.tNodes[wndParent:GetName() or kstrNodePrefix];
	local tNodes = tRootNode.tChildren;
	local nLevel = tRootNode.nLevel;

	local nTreeHeight = 0;

	for i, wndNode in ipairs(tNodes) do
		local tNode = self.tNodes[wndNode:GetName()];

		wndNode:Show(true, true);
		wndNode:Enable(true);

		local nNodeHeight = knNodeHeight; -- height of this node + visible children
		local tChildNodes = self.tNodes[wndNode:GetName()].tChildren;

		if (#tChildNodes == 0 or tNode.bCollapsed) then
			-- no children or collapsed
			if (#tChildNodes == 0) then
				-- hide icon
				tNode.tPixieIcon.strSprite = "";
				tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
			end

			-- disable child nodes
			for _, wndChildNode in ipairs(tChildNodes) do
				wndChildNode:Enable(false);
				wndChildNode:Show(false, true);
			end
		else
			-- expanded children
			nNodeHeight = nNodeHeight + self:ArrangeNodes(wndNode);
		end

		nTreeHeight = nTreeHeight + nNodeHeight;

		-- Update Node Container Position (TODO: Compare Performance - Move/SetAnchorOffsets)
		local nPosY = nTreeHeight - nNodeHeight + (nLevel == 0 and 0 or knNodeHeight);
		local nAnchorOffsetL, nAnchorOffsetT, nAnchorOffsetR, nAnchorOffsetB = wndNode:GetAnchorOffsets();
		nAnchorOffsetT = nPosY;
		nAnchorOffsetB = nPosY + nNodeHeight;
		wndNode:SetAnchorOffsets(nAnchorOffsetL, nAnchorOffsetT, nAnchorOffsetR, nAnchorOffsetB);
	end

	return nTreeHeight;
end

function SezzTreeView:Render()
	self:ArrangeNodes(self.wndParent);
	self.wndParent:SetAnchorOffsets(self.wndParent:GetAnchorOffsets()); -- Fix invisible VScrollBar
	self.bRendered = true;
	self:VisibleItemsCheckForced();
end

-----------------------------------------------------------------------------
-- Expand/Collapse
-----------------------------------------------------------------------------

function SezzTreeView:CollapseNode(strNode)
	local tNode = self.tNodes[strNode];
	tNode.bCollapsed = true;

	if (tNode.wndNode and tNode.tPixieIcon) then
		tNode.tPixieIcon.strSprite = "TestTree:CaretRight";
		tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
	end

	if (self.bRendered and #tNode.tChildren > 0) then
		self:Render();
		self.CallbackHandler:Fire("NodeCollapsed", strNode);
	end
end

function SezzTreeView:ExpandNode(strNode)
	local tNode = self.tNodes[strNode];
	tNode.bCollapsed = false;

	if (tNode.wndNode and tNode.tPixieIcon) then
		tNode.tPixieIcon.strSprite = "TestTree:CaretDown";
		tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
	end

	if (self.bRendered and #tNode.tChildren > 0) then
		self:Render();
		self.CallbackHandler:Fire("NodeExpanded", strNode);
	end
end

function SezzTreeView:ToggleNode(strNode)
	if (self.tNodes[strNode].bCollapsed) then
		self:ExpandNode(strNode);
	else
		self:CollapseNode(strNode);
	end
end

-----------------------------------------------------------------------------
-- Shitty Performance Workaround
-- Doesn't help much if you have a huge tree, will iterate child nodes later
-----------------------------------------------------------------------------

function SezzTreeView:VisibleItemsCheck(strVar, nFrameCount)
	if (self.nNodes == 0 or not self.bRendered) then return; end

	local wndContainer = self.wndParent;
	local nScrollPos = wndContainer:GetVScrollPos();
	local nContainerHeight = wndContainer:GetHeight();
	local bDisableRest = false;

	if (not self.nPrevScrollPos or not self.nPrevHeight or self.nPrevScrollPos ~= nScrollPos or self.nPrevHeight ~= nContainerHeight) then
		self.nPrevScrollPos = nScrollPos;
		self.nPrevHeight = nContainerHeight;

		for _, wndNode in ipairs(wndContainer:GetChildren()) do
			if (bDisableRest) then
				wndNode:Enable(false);
			else
				local _, nPosY = wndNode:GetPos();
				local nHeight = wndNode:GetHeight();
				local bEnable = (nPosY < nContainerHeight and nPosY + nHeight > 0);
				wndNode:Enable(bEnable);

				if (nPosY > nContainerHeight) then
					bDisableRest = true;
				end
			end
		end
	end
end

function SezzTreeView:VisibleItemsCheckForced()
	self.nPrevHeight = nil;
	self.nPrevScrollPos = nil;
	self:VisibleItemsCheck(0, 0);
end

-----------------------------------------------------------------------------
-- Apollo Registration
-----------------------------------------------------------------------------

function SezzTreeView:OnLoad()
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2") and Apollo.GetAddon("GeminiConsole") and Apollo.GetPackage("Gemini:Logging-1.2").tPackage;
	if (GeminiLogging) then
		log = GeminiLogging:GetLogger({
			level = GeminiLogging.DEBUG,
			pattern = "%d %n %c %l - %m",
			appender ="GeminiConsole"
		});
	else
		log = setmetatable({}, { __index = function() return function(self, ...) local args = #{...}; if (args > 1) then Print(string.format(...)); elseif (args == 1) then Print(tostring(...)); end; end; end });
	end

	Apollo.LoadSprites("FontAwesome.xml");
	CallbackHandler = Apollo.GetPackage("Gemini:CallbackHandler-1.0").tPackage

	-- Font Awesome Sprites
	-- Sprite loading snippet by Wildstar NASA (MIT)
	local strPrefix = Apollo.GetAssetFolder();
	local tToc = XmlDoc.CreateFromFile("toc.xml"):ToTable();
	for k, v in ipairs(tToc) do
		local strPath = strmatch(v.Name, "(.*)[\\/]SezzTreeView");
		if (strPath ~= nil and strPath ~= "") then
			strPrefix = strPrefix .. "\\" .. strPath .. "\\";
			break;
		end
	end

	local tSpritesXML = {
		__XmlNode = "Sprites",
		{
			__XmlNode="Sprite", Name="CaretDown", Cycle="1",
			{
				__XmlNode="Frame", Texture= strPrefix .."FontAwesome.tga",
				x0="16", x1="16", x2="16", x3="16", x4="16", x5="32",
				y0="0", y1="0", y2="0", y3="0", y4="0", y5="16",
				HotspotX="0", HotspotY="0", Duration="1.000",
				StartColor="white", EndColor="white",
			},
		},
		{
			__XmlNode="Sprite", Name="CaretRight", Cycle="1",
			{
				__XmlNode="Frame", Texture= strPrefix .."FontAwesome.tga",
				x0="0", x1="0", x2="0", x3="0", x4="0", x5="16",
				y0="0", y1="0", y2="0", y3="0", y4="0", y5="16",
				HotspotX="0", HotspotY="0", Duration="1.000",
				StartColor="white", EndColor="white",
			},
		},
	};

	local xmlSprites = XmlDoc.CreateFromTable(tSpritesXML);
	Apollo.LoadSprites(xmlSprites, "SezzTreeViewSprites");
end

function SezzTreeView:OnDependencyError(strDep, strError)
	return false;
end

-----------------------------------------------------------------------------

Apollo.RegisterPackage(SezzTreeView, MAJOR, MINOR, { "Gemini:CallbackHandler-1.0" });
