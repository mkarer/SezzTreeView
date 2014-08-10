--[[

	s:UI Flat TreeView Control

	Martin Karer / Sezz, 2014
	http://www.sezz.at

--]]

local MAJOR, MINOR = "Sezz:Controls:TreeView-0.1", 1;
local APkg = Apollo.GetPackage(MAJOR);
if (APkg and (APkg.nVersion or 0) >= MINOR) then return; end

local SezzTreeView = APkg and APkg.tPackage or {};
local Apollo = Apollo;
local tLibError = Apollo.GetPackage("Gemini:LibError-1.0")
local fnErrorHandler = tLibError and tLibError.tPackage and tLibError.tPackage.Error or Print

-- Lua API
local tinsert, pairs, ipairs, strmatch, tremove, xpcall = table.insert, pairs, ipairs, string.match, table.remove, xpcall;

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
local kstrNodeIndicatorColorActive = "ff23D3FF";

-----------------------------------------------------------------------------
-- Window Definitions
-----------------------------------------------------------------------------

local tXmlTreeViewNode = {
	__XmlNode = "Form",
	Class = "Window",
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
			LAnchorOffset = 30, TAnchorOffset = 0, RAnchorOffset = 0, BAnchorOffset = 0,
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

local function CreateNodeXml(strName, strText, nNodeIndent)
	tXmlTreeViewNode.Name = strName;
	tXmlTreeViewNode[1][5].Text = strText;
	tXmlTreeViewNode[1][5].LAnchorOffset = 30 + nNodeIndent;

	return tXmlTreeViewNode;
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

local tXmlTreeViewNodeActiveIndicator = {
	strSprite = "BasicSprites:WhiteFill",
	cr = kstrNodeIndicatorColorActive,
	loc = {
		fPoints = { 0, 0.15, 0, 0.85 },
		nOffsets = { 0, 0, 3, 0 },
	},
};

-----------------------------------------------------------------------------
-- Node Events
-----------------------------------------------------------------------------

function SezzTreeView:OnNodeMouseEnter(wndHandler, wndControl)
	if (wndHandler ~= wndControl) then return; end

	if (not self.wndActiveNode or self.wndActiveNode ~= wndControl) then
		wndControl:SetBGColor(kstrNodeBGColorHover);
	end

	self:Fire("MouseEnter", wndControl:GetName());
end

function SezzTreeView:OnNodeMouseExit(wndHandler, wndControl)
	if (wndHandler ~= wndControl) then return; end

	if (not self.wndActiveNode or self.wndActiveNode ~= wndControl) then
		wndControl:SetBGColor(kstrNodeBGColorDefault);
	end

	self:Fire("MouseExit", wndControl:GetName());
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
					self:Fire("NodeDoubleClick", strNode, true);
				end
			else
				self:Fire("NodeDoubleClick", strNode);
			end
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
				local strPreviousActiveNode = wndPreviousActiveNode:GetParent():GetName();

				if (self.tNodes[strPreviousActiveNode].nIndicatorPixieId) then
					wndPreviousActiveNode:DestroyPixie(self.tNodes[strPreviousActiveNode].nIndicatorPixieId);
					self.tNodes[strPreviousActiveNode].nIndicatorPixieId = nil;
				end

				self.wndActiveNode = nil;
				self:OnNodeMouseExit(wndPreviousActiveNode, wndPreviousActiveNode);
			end

			-- Highlight Node
			self.wndActiveNode = wndControl;
			wndControl:SetBGColor(kstrNodeBGColorActive);
			if (not self.tNodes[strNode].nIndicatorPixieId) then
				self.tNodes[strNode].nIndicatorPixieId = wndControl:AddPixie(tXmlTreeViewNodeActiveIndicator);
			end

			self:Fire("NodeSelected", strNode);
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

function SezzTreeView:New(wndParent)
	local self = setmetatable({
		wndParent = wndParent,
		nLevel = 1,
		bRendered = true,
		nNodes = 0,
		tCallbacks = {},
	}, { __index = self });

	self.strRootNode = wndParent:GetName() or kstrNodePrefix;
	self.tNodes = {
		[self.strRootNode] = {
			tChildren = {},
			nLevel = 0,
			bIsRootNode = true,
		},
	};

	Apollo.RegisterEventHandler("VarChange_FrameCount", "VisibleItemsCheck", self);

	return self;
end

-----------------------------------------------------------------------------
-- Callbacks
-- I'm too stupid to use Callbackhandeler
-----------------------------------------------------------------------------

function SezzTreeView:RegisterCallback(strEvent, strFunction, tEventHandler)
	if (not self.tCallbacks[strEvent]) then
		self.tCallbacks[strEvent] = {};
	end

	tinsert(self.tCallbacks[strEvent], { strFunction, tEventHandler });
end

function SezzTreeView:Fire(strEvent, ...)
	if (self.tCallbacks[strEvent]) then
		for _, tCallback in ipairs(self.tCallbacks[strEvent]) do
			local strFunction = tCallback[1];
			local tEventHandler = tCallback[2];
			local tArgs = { ... };

			xpcall(function() tEventHandler[strFunction](tEventHandler, unpack(tArgs)); end, fnErrorHandler);
		end
	end
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
		tParentNode = tParentNode,
		strName = strName,
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

function SezzTreeView:RemoveNode(strNode, bSkipRedraw)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end

	-- Remove Children
	for _, wndChildNode in ipairs(tNode.tChildren) do
		self:RemoveNode(wndChildNode:GetName());
	end

	-- Remove Node from Parent
	local tParentNode = tNode.tParentNode;
	for i, wndChildNode in ipairs(tParentNode.tChildren) do
		if (wndChildNode:GetName() == strNode) then
			tremove(tParentNode.tChildren, i);
			break;
		end
	end

	-- Update Parent Node Arrow Sprite
	if (#tParentNode.tChildren > 0 and tParentNode.wndNode and tParentNode.tPixieIcon.nId) then
		local strSprite = tParentNode.bCollapsed and "CaretRight" or "CaretDown";
		if (strSprite ~= tParentNode.wndNode:GetPixieInfo(tParentNode.tPixieIcon.nId).strSprite) then
			tParentNode.tPixieIcon.strSprite = "SezzTreeViewSprites:"..strSprite;
			tParentNode.wndNode:UpdatePixie(tParentNode.tPixieIcon.nId, tParentNode.tPixieIcon);
		end
	end

	-- Destroy Node
	if (tNode.wndNode) then
		if (self.wndActiveNode and self.wndActiveNode:GetParent():GetName() == strNode) then
			self.wndActiveNode = nil;
		end

		tNode.wndNode:Destroy();
	end

	self.tNodes[strNode] = nil;

	-- Redraw Tree
	if (self.bRendered and not bSkipRedraw) then
		self:Render();
	end
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

function SezzTreeView:GetNodeLevel(strNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end
	return tNode.nLevel;
end

function SezzTreeView:SelectNode(strNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end

	local tParentNode = tNode.tParentNode;
	while (tParentNode and tParentNode.bCollapsed) do
		self:ExpandNode(tParentNode.strName);
		tParentNode = tParentNode.tParentNode;
	end

	local wndNode = tNode.wndNode:FindChild("Node");
	self:OnNodeMouseUp(wndNode, wndNode, GameLib.CodeEnumInputMouse.Left);
end

function SezzTreeView:GetParentNode(strNode, bIncludeRootNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end

	if (not tNode.tParentNode or (not bIncludeRootNode and tNode.tParentNode.bIsRootNode)) then
		return;
	else
		return tNode.tParentNode.strName;
	end
end

function SezzTreeView:IterateNodes(strNode)
	local tNode = self.tNodes[strNode];
	local tChildren = {};
	if (tNode) then
		for _, wndNode in pairs(tNode.tChildren) do
			tinsert(tChildren, self.tNodes[wndNode:GetName()]);
		end
	end

	return ipairs(tChildren);
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
		local strSprite;

		if (#tChildNodes == 0 or tNode.bCollapsed) then
			-- no children or collapsed
			strSprite = (#tChildNodes == 0) and "" or "CaretRight";

			-- disable child nodes
			for _, wndChildNode in ipairs(tChildNodes) do
				wndChildNode:Enable(false);
				wndChildNode:Show(false, true);
			end
		else
			-- expanded children
			nNodeHeight = nNodeHeight + self:ArrangeNodes(wndNode);
			strSprite = "CaretDown";
		end

		nTreeHeight = nTreeHeight + nNodeHeight;

		-- Update Arrow Sprite
		if (strSprite ~= tNode.wndNode:GetPixieInfo(tNode.tPixieIcon.nId).strSprite) then
			tNode.tPixieIcon.strSprite = "SezzTreeViewSprites:"..strSprite;
			tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
		end

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
	if (not tNode) then return; end
	tNode.bCollapsed = true;

	if (tNode.wndNode and tNode.tPixieIcon) then
		tNode.tPixieIcon.strSprite = "SezzTreeViewSprites:CaretRight";
		tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
	end

	if (self.bRendered and #tNode.tChildren > 0) then
		self:Render();
		self:Fire("NodeCollapsed", strNode);
	end
end

function SezzTreeView:ExpandNode(strNode)
	local tNode = self.tNodes[strNode];
	if (not tNode) then return; end

	local tParentNode = tNode.tParentNode;
	while (tParentNode and tParentNode.bCollapsed) do
		self:ExpandNode(tParentNode.strName);
		tParentNode = tParentNode.tParentNode;
	end

	tNode.bCollapsed = false;

	if (tNode.wndNode and tNode.tPixieIcon) then
		tNode.tPixieIcon.strSprite = "SezzTreeViewSprites:CaretDown";
		tNode.wndNode:UpdatePixie(tNode.tPixieIcon.nId, tNode.tPixieIcon);
	end

	if (self.bRendered and #tNode.tChildren > 0) then
		self:Render();
		self:Fire("NodeExpanded", strNode);
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
	-- Font Awesome Sprites
	-- Sprite loading snippet by Wildstar NASA (MIT)
	local strPrefix = Apollo.GetAssetFolder();
	local tToc = XmlDoc.CreateFromFile(Apollo.GetAssetFolder() .. "\\toc.xml"):ToTable();
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

Apollo.RegisterPackage(SezzTreeView, MAJOR, MINOR, {});
