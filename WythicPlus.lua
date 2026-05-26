-- Wythic+ Combat Log Helper
-- 로그인 시 전투 로그 활성화를 도와주는 애드온

local ADDON_NAME = "WythicPlus"
local PREFIX = "|cff00ccff[Wythic+]|r "

-- Saved variables (persisted across sessions)
WythicPlusDB = WythicPlusDB or {}

----------------------------------------------------------------
-- Static popup
----------------------------------------------------------------
StaticPopupDialogs["WYTHICPLUS_COMBAT_LOG"] = {
    text = "|cff00ccffWythic+|r\n\n전투 로그를 활성화하시겠습니까?\n|cff888888WCL 로깅에 필요합니다.|r",
    button1 = "켜기",
    button2 = "취소",
    OnAccept = function()
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 활성화되었습니다.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------------------------
-- Login event
----------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, _, isInitialLogin)
    if not isInitialLogin then return end

    -- Already logging
    if LoggingCombat() then
        print(PREFIX .. "전투 로그가 이미 활성화되어 있습니다.")
        return
    end

    -- Auto mode: skip popup, just enable
    if WythicPlusDB.autoEnable then
        LoggingCombat(true)
        print(PREFIX .. "전투 로그가 자동으로 활성화되었습니다.")
        return
    end

    -- Show confirmation popup
    StaticPopup_Show("WYTHICPLUS_COMBAT_LOG")
end)

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

    elseif msg == "off" then
        LoggingCombat(false)
        print(PREFIX .. "전투 로그가 비활성화되었습니다.")

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

    else
        print("|cff00ccff[Wythic+] 명령어:|r")
        print("  /wp on     — 전투 로그 켜기")
        print("  /wp off    — 전투 로그 끄기")
        print("  /wp auto   — 자동 활성화 토글 (팝업 없이)")
        print("  /wp status — 현재 상태 확인")
    end
end
