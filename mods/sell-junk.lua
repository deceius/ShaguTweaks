local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local GetItemIDFromLink = ShaguTweaks.GetItemIDFromLink

local module = ShaguTweaks:register({
  title = T["Sell Junk"],
  description = T["Adds a “Sell Junk” button to every merchant window, that sells all grey items."],
  expansions = { ["vanilla"] = true, ["tbc"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local processed = {}

local function CreateGoldString(money)
  if type(money) ~= "number" then return "-" end
  local gold = floor(money/ 100 / 100)
  local silver = floor(mod((money/100),100))
  local copper = floor(mod(money,100))
  local str = ""
  if gold > 0 then str = str .. "|cffffffff" .. gold .. "|cffffd700g" end
  if silver > 0 or gold > 0 then str = str .. "|cffffffff " .. silver .. "|cffc7c7cfs" end
  str = str .. "|cffffffff " .. copper .. "|cffeda55fc"
  return str
end

local function HasGreyItems()
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local name = GetContainerItemLink(bag, slot)
      if name and string.find(name, "ff9d9d9d") then return true end
    end
  end
  return nil
end

local function GetNextGreyItem()
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local name = GetContainerItemLink(bag, slot)
      if name and string.find(name, "ff9d9d9d") and not processed[bag.."x"..slot] then
        processed[bag.."x"..slot] = true
        return bag, slot
      end
    end
  end
  return nil, nil
end

module.enable = function(self)
  local autovendor = CreateFrame("Frame", nil, MerchantFrame)
  autovendor:Hide()

  -- Create the button using CheckButton to support Disable/Enable states
  autovendor.button = CreateFrame("CheckButton", "ShaguSellJunkButton", MerchantFrame, "ItemButtonTemplate")
  autovendor.button:SetWidth(34)
  autovendor.button:SetHeight(34)
  
  -- Tooltip logic
  autovendor.button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(T["Sell Grey Items"])
    GameTooltip:Show()
  end)
  autovendor.button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Hide the default blue border
  local normalTex = autovendor.button:GetNormalTexture()
  if normalTex then normalTex:SetAlpha(0) end

  -- Set Icon
  local btnIcon = getglobal(autovendor.button:GetName().."IconTexture")
  btnIcon:SetTexture("Interface\\Icons\\inv_misc_coin_06")
  btnIcon:SetAllPoints(autovendor.button)

  autovendor:SetScript("OnShow", function()
    processed = {}
    this.price = 0
    this.count = 0
  end)

  autovendor:SetScript("OnHide", function()
    if this.count > 0 then
      DEFAULT_CHAT_FRAME:AddMessage(T["Your vendor trash has been sold and you earned"] .. " " .. CreateGoldString(this.price))
    end
  end)

  autovendor:SetScript("OnUpdate", function()
    if (this.tick or 1) > GetTime() then return else this.tick = GetTime() + .1 end
    local bag, slot = GetNextGreyItem()
    if not bag or not slot then
      this:Hide()
      -- Disable button once finished
      autovendor.button:Disable()
      btnIcon:SetDesaturated(true)
      return
    end
    
    local _, icount = GetContainerItemInfo(bag, slot)
    local itemID = GetItemIDFromLink(GetContainerItemLink(bag, slot))
    local price = ShaguTweaks.SellValueDB and ShaguTweaks.SellValueDB[itemID] or 0
    this.price = this.price + (price * (icount or 1))
    this.count = this.count + 1
    
    ClearCursor()
    UseContainerItem(bag, slot)
  end)

  autovendor:RegisterEvent("MERCHANT_SHOW")
  autovendor:RegisterEvent("MERCHANT_CLOSED")
  autovendor:SetScript("OnEvent", function()
    if event == "MERCHANT_SHOW" then
      if MerchantRepairText then MerchantRepairText:SetText("") end
      if MerchantRepairAllButton then
        MerchantRepairAllButton:SetWidth(36)
        MerchantRepairAllButton:SetHeight(36)
      end
      if MerchantRepairItemButton then
        MerchantRepairItemButton:SetWidth(36)
        MerchantRepairItemButton:SetHeight(36)
      end

      autovendor.button:ClearAllPoints()
      if MerchantRepairItemButton:IsShown() then
        autovendor.button:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -4, 0)
      else
        autovendor.button:SetPoint("RIGHT", MerchantBuyBackItemItemButton, "LEFT", -14, 0)
      end

      autovendor.button:Show()
      if HasGreyItems() then
        autovendor.button:Enable()
        btnIcon:SetDesaturated(false)
      else
        autovendor.button:Disable()
        btnIcon:SetDesaturated(true)
      end

    elseif event == "MERCHANT_CLOSED" then
      autovendor:Hide()
    end
  end)

  autovendor.button:SetScript("OnClick", function()
    autovendor:Show()
  end)

  if not HookMerchantFrame_Update then
    local HookMerchantFrame_Update = MerchantFrame_Update
    function _G.MerchantFrame_Update()
      if MerchantFrame.selectedTab == 1 then
        autovendor.button:Show()
        if HasGreyItems() then
          autovendor.button:Enable()
          btnIcon:SetDesaturated(false)
        else
          autovendor.button:Disable()
          btnIcon:SetDesaturated(true)
        end
      else
        autovendor.button:Hide()
      end
      HookMerchantFrame_Update()
    end
  end
end