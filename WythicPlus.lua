-- Wythic+ Combat Log Helper
-- 로그인 시 사이트 소개 + 전투 로그 활성화를 도와주는 애드온

local ADDON_NAME = "WythicPlus"
local PREFIX = "|cff00ccff[Wythic+]|r "

-- Saved variables (persisted across sessions)
WythicPlusDB = WythicPlusDB or {}

----------------------------------------------------------------
-- Minimap Button (standard icon on minimap edge)
----------------------------------------------------------------
local minimapBtn
local DEFAULT_ANGLE = 220 -- degrees

local function UpdateIndicator()
    if not minimapBtn then return end
    if LoggingCombat() then
        minimapBtn.border:SetVertexColor(0, 0.85, 0, 1)
    else
        minimapBtn.border:SetVertexColor(0.85, 0, 0, 1)
    end
end

local function IsMinimapSquare()
    return ElvUI ~= nil or Minimap.backdrop ~= nil
end

local function SetMinimapButtonPosition(angle)
    local rad = math.rad(angle)
    local cos, sin = math.cos(rad), math.sin(rad)
    local half = Minimap:GetWidth() / 2 + 8
    local x, y

    if IsMinimapSquare() then
        -- Square minimap: project to square edge
        local ac, as = math.abs(cos), math.abs(sin)
        if ac > as then
            x = half * (cos > 0 and 1 or -1)
            y = half * sin / ac
        else
            y = half * (sin > 0 and 1 or -1)
            x = half * cos / as
        end
    else
        -- Round minimap
        x = cos * half
        y = sin * half
    end

    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapIndicator()
    local btn = CreateFrame("Button", "WythicPlusMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Wy+ logo icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\WythicPlus\\Textures\\icon")
    btn.icon = icon

    -- Border (tinted green/red by combat log status)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border = border

    -- Highlight on hover
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Position from saved angle
    minimapBtn = btn
    WythicPlusDB.minimapAngle = WythicPlusDB.minimapAngle or DEFAULT_ANGLE
    SetMinimapButtonPosition(WythicPlusDB.minimapAngle)

    -- Shift+left drag to reposition
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        if not IsShiftKeyDown() then return end
        btn.dragging = true
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            WythicPlusDB.minimapAngle = angle
            SetMinimapButtonPosition(angle)
        end)
    end)
    btn:SetScript("OnDragStop", function()
        btn.dragging = false
        btn:SetScript("OnUpdate", nil)
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Wythic+", 0, 0.8, 1)
        if LoggingCombat() then
            GameTooltip:AddLine("전투 로그: |cff00ff00활성|r")
        else
            GameTooltip:AddLine("전투 로그: |cffff0000비활성|r")
        end
        GameTooltip:AddLine("|cff888888좌클릭: 소개 · 우클릭: 메뉴|r", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("|cff888888Shift+드래그: 이동|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Left click: show onboarding / Right click: context menu
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            local f = _G["WythicPlusOnboarding"] or CreateOnboardingFrame()
            f.pages[1]:Show()
            f.pages[2]:Hide()
            f:Show()
        else
            MenuUtil.CreateContextMenu(btn, function(_, root)
                root:CreateTitle("Wythic+")

                local logging = LoggingCombat()
                root:CreateButton(logging and "전투 로그 끄기" or "전투 로그 켜기", function()
                    if logging then
                        LoggingCombat(false)
                        print(PREFIX .. "전투 로그가 비활성화되었습니다.")
                    else
                        LoggingCombat(true)
                        print(PREFIX .. "전투 로그가 활성화되었습니다.")
                    end
                    UpdateIndicator()
                end)

                root:CreateCheckbox("자동 활성화 (로그인 시 팝업 없이)", function()
                    return WythicPlusDB.autoEnable
                end, function()
                    WythicPlusDB.autoEnable = not WythicPlusDB.autoEnable
                    if WythicPlusDB.autoEnable then
                        print(PREFIX .. "자동 활성화 모드 |cff00ff00켜짐|r")
                    else
                        print(PREFIX .. "자동 활성화 모드 |cffff0000꺼짐|r")
                    end
                end)
            end)
        end
    end)

    UpdateIndicator()
end

----------------------------------------------------------------
-- Onboarding Frame (2-step intro)
----------------------------------------------------------------
local function CreateOnboardingFrame()
    local f = CreateFrame("Frame", "WythicPlusOnboarding", UIParent, "BackdropTemplate")
    f:SetSize(420, 280)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 10 },
    })

    f.pages = {}

    -- Page 1: Branding
    local p1 = CreateFrame("Frame", nil, f)
    p1:SetAllPoints()

    local title1 = p1:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title1:SetPoint("TOP", 0, -30)
    title1:SetFont(title1:GetFont(), 28, "OUTLINE")
    title1:SetText("|cff00ccffWythic+|r")

    local sub = p1:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOP", title1, "BOTTOM", 0, -10)
    sub:SetText("WoW M+ 쐐기돌 메타 분석 도구")

    local desc = p1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOP", sub, "BOTTOM", 0, -20)
    desc:SetWidth(340)
    desc:SetJustifyH("CENTER")
    desc:SetText(
        "상위 런 데이터를 기반으로\n" ..
        "스펙 티어 · 조합 추천 · 빌드 가이드를\n" ..
        "제공합니다."
    )

    local url = p1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    url:SetPoint("TOP", desc, "BOTTOM", 0, -20)
    url:SetText("|cff00ccffwythic.com|r")

    local nextBtn = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    nextBtn:SetSize(120, 28)
    nextBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 20)
    nextBtn:SetText("다음 >")

    f.pages[1] = p1

    -- Page 2: Combat Log
    local p2 = CreateFrame("Frame", nil, f)
    p2:SetAllPoints()
    p2:Hide()

    local title2 = p2:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title2:SetPoint("TOP", 0, -30)
    title2:SetFont(title2:GetFont(), 28, "OUTLINE")
    title2:SetText("|cff00ccffWythic+|r")

    local q = p2:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    q:SetPoint("TOP", title2, "BOTTOM", 0, -24)
    q:SetText("전투 로그를 활성화하시겠습니까?")

    local note = p2:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOP", q, "BOTTOM", 0, -10)
    note:SetText("|cff888888WCL 로깅에 필요합니다.|r")

    local enableBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    enableBtn:SetSize(100, 28)
    enableBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -10, 20)
    enableBtn:SetText("켜기")

    local laterBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    laterBtn:SetSize(100, 28)
    laterBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 10, 20)
    laterBtn:SetText("다음에")

    f.pages[2] = p2

    -- Button logic
    nextBtn:SetScript("OnClick", function()
        p1:Hide()
        p2:Show()
    end)

    enableBtn:SetScript("OnClick", function()
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 활성화되었습니다.")
        WythicPlusDB.introSeen = true
        f:Hide()
        UpdateIndicator()
    end)

    laterBtn:SetScript("OnClick", function()
        WythicPlusDB.introSeen = true
        f:Hide()
    end)

    tinsert(UISpecialFrames, "WythicPlusOnboarding")
    return f
end

----------------------------------------------------------------
-- Login event
----------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, _, isInitialLogin)
    -- Always create minimap indicator
    if not minimapBtn then
        CreateMinimapIndicator()
    end

    -- First time: show onboarding (regardless of login type)
    if not WythicPlusDB.introSeen then
        CreateOnboardingFrame():Show()
        return
    end

    if not isInitialLogin then return end

    -- Already logging
    if LoggingCombat() then
        print(PREFIX .. "전투 로그가 이미 활성화되어 있습니다.")
        return
    end

    -- Auto mode
    if WythicPlusDB.autoEnable then
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 자동으로 활성화되었습니다.")
        UpdateIndicator()
        return
    end

    -- Confirmation popup
    StaticPopup_Show("WYTHICPLUS_COMBAT_LOG")
end)

----------------------------------------------------------------
-- Static popup (for returning users)
----------------------------------------------------------------
StaticPopupDialogs["WYTHICPLUS_COMBAT_LOG"] = {
    text = "|cff00ccffWythic+|r\n\n전투 로그를 활성화하시겠습니까?\n|cff888888WCL 로깅에 필요합니다.|r",
    button1 = "켜기",
    button2 = "취소",
    OnAccept = function()
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 활성화되었습니다.")
        UpdateIndicator()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------------------------
-- Slash commands: /wythic, /wp
----------------------------------------------------------------
SLASH_WYTHICPLUS1 = "/wythic"
SLASH_WYTHICPLUS2 = "/wp"

SlashCmdList["WYTHICPLUS"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "on" then
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 활성화되었습니다.")
        UpdateIndicator()

    elseif msg == "off" then
        LoggingCombat(false)
        print(PREFIX .. "전투 로그가 비활성화되었습니다.")
        UpdateIndicator()

    elseif msg == "auto" then
        WythicPlusDB.autoEnable = not WythicPlusDB.autoEnable
        if WythicPlusDB.autoEnable then
            print(PREFIX .. "자동 활성화 모드 |cff00ff00켜짐|r (로그인 시 팝업 없이 바로 활성화)")
        else
            print(PREFIX .. "자동 활성화 모드 |cffff0000꺼짐|r (로그인 시 확인 팝업)")
        end

    elseif msg == "status" then
        local logging = LoggingCombat()
        local auto = WythicPlusDB.autoEnable
        print(PREFIX .. "전투 로그: " .. (logging and "|cff00ff00활성|r" or "|cffff0000비활성|r"))
        print(PREFIX .. "자동 활성화: " .. (auto and "|cff00ff00켜짐|r" or "|cffff0000꺼짐|r"))

    elseif msg == "reset" then
        WythicPlusDB.introSeen = false
        print(PREFIX .. "온보딩 초기화. 다음 로그인 시 소개 화면이 다시 표시됩니다.")

    else
        print("|cff00ccff[Wythic+] 명령어:|r")
        print("  /wp on     — 전투 로그 켜기")
        print("  /wp off    — 전투 로그 끄기")
        print("  /wp auto   — 자동 활성화 토글 (팝업 없이)")
        print("  /wp status — 현재 상태 확인")
        print("  /wp reset  — 소개 화면 다시 보기")
    end
end
