-- Wythic+ Combat Log Helper
-- 로그인 시 사이트 소개 + 전투 로그 활성화를 도와주는 애드온

local ADDON_NAME = "WythicPlus"
local PREFIX = "|cff00ccff[Wythic+]|r "

-- Saved variables (persisted across sessions)
WythicPlusDB = WythicPlusDB or {}

----------------------------------------------------------------
-- Minimap Indicator (green/red dot)
----------------------------------------------------------------
local minimapIndicator

local function UpdateIndicator()
    if not minimapIndicator then return end
    if LoggingCombat() then
        minimapIndicator.dot:SetVertexColor(0, 0.85, 0, 1)
    else
        minimapIndicator.dot:SetVertexColor(0.85, 0, 0, 1)
    end
end

local function CreateMinimapIndicator()
    local btn = CreateFrame("Button", "WythicPlusMinimapBtn", Minimap)
    btn:SetSize(20, 20)
    btn:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 4, 4)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(9)
    btn:RegisterForClicks("AnyUp")

    -- Dark border (circle)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetSize(18, 18)
    border:SetPoint("CENTER")
    border:SetColorTexture(0, 0, 0, 0.7)
    local borderMask = btn:CreateMaskTexture()
    borderMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    borderMask:SetAllPoints(border)
    border:AddMaskTexture(borderMask)

    -- Colored dot (circle)
    local dot = btn:CreateTexture(nil, "ARTWORK")
    dot:SetSize(12, 12)
    dot:SetPoint("CENTER")
    dot:SetColorTexture(1, 1, 1, 1)
    local dotMask = btn:CreateMaskTexture()
    dotMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    dotMask:SetAllPoints(dot)
    dot:AddMaskTexture(dotMask)
    btn.dot = dot

    -- Periodic state check (every 2s)
    local elapsed = 0
    btn:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 2 then
            elapsed = 0
            UpdateIndicator()
        end
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
        GameTooltip:AddLine("|cff888888클릭하여 전환|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click to toggle
    btn:SetScript("OnClick", function()
        if LoggingCombat() then
            LoggingCombat(false)
            print(PREFIX .. "전투 로그가 비활성화되었습니다.")
        else
            LoggingCombat(true)
            print(PREFIX .. "전투 로그가 활성화되었습니다.")
        end
        UpdateIndicator()
    end)

    minimapIndicator = btn
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
    if not minimapIndicator then
        CreateMinimapIndicator()
    end

    if not isInitialLogin then return end

    -- First time: show onboarding
    if not WythicPlusDB.introSeen then
        CreateOnboardingFrame():Show()
        return
    end

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
