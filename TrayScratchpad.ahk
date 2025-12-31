#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

global gGui := 0
global gEdit := 0
global gVisible := false
global gFadeAlpha := 0
global gFadeTimer := 0
global gShowTimer := 0
global gHotkey := ""
global gHotkeyLabel := ""
global gMenuReady := false
global gHotkeyGui := 0
global gHotkeyCtrl := 0

; 托盘菜单
InitHotkey()
A_TrayMenu.Delete()
A_TrayMenu.Add("打开/隐藏", (*) => ToggleGui())
A_TrayMenu.Add()
A_TrayMenu.Add("设置快捷键...", (*) => ShowHotkeyDialog())
A_TrayMenu.Add(gHotkeyLabel, (*) => 0)
A_TrayMenu.Disable(gHotkeyLabel)
A_TrayMenu.Add()
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "打开/隐藏"
A_TrayMenu.ClickCount := 1
gMenuReady := true

; 单击托盘图标：打开/隐藏
OnMessage(0x404, TrayIconMsg) ; WM_USER + something (tray callback)
OnMessage(0x0006, GuiActivateMsg) ; WM_ACTIVATE

ToggleGui() {
    global gGui, gEdit, gVisible
    if !IsObject(gGui) {
        gGui := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "临时文本")
        gGui.MarginX := 10
        gGui.MarginY := 10

        gEdit := gGui.AddEdit("w520 h220 WantTab", "")
        gEdit.SetFont("s10", "Segoe UI")

        btnCopy := gGui.AddButton("xm y+8 w80", "复制")
        btnCopy.OnEvent("Click", (*) => CopyText())

        btnClear := gGui.AddButton("x+8 w80", "清空")
        btnClear.OnEvent("Click", (*) => ClearText())

        btnClose := gGui.AddButton("x+8 w80", "关闭")
        btnClose.OnEvent("Click", (*) => HideAndDiscard())

        ; 关闭窗口(X)时：隐藏并丢弃
        gGui.OnEvent("Close", GuiClose)
        gGui.OnEvent("Escape", GuiClose)

        ; 先显示再隐藏，强制完成布局计算
        gGui.Show("AutoSize Hide")
    }

    if (gVisible) {
        HideAndDiscard()
    } else {
        ShowAtBottomRight()
    }
}

ShowAtBottomRight() {
    global gGui, gShowTimer
    margin := 0
    monitor := MonitorGetPrimary()
    MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)
    gGui.Show("AutoSize NA x-10000 y-10000")
    if (gShowTimer)
        SetTimer(gShowTimer, 0)
    gShowTimer := FinishShow.Bind(right, bottom, margin)
    SetTimer(gShowTimer, -40)
}

FinishShow(right, bottom, margin) {
    global gGui, gEdit, gVisible, gShowTimer
    if !IsObject(gGui) {
        gShowTimer := 0
        return
    }
    gGui.Show("AutoSize NA x-10000 y-10000")
    Sleep(10)  ; 等待窗口完成布局
    WinGetPos(, , &w, &h, "ahk_id " gGui.Hwnd)
    x := right - w - margin
    y := bottom - h - margin
    gGui.Hide()  ; 先隐藏
    gGui.Show("x" x " y" y " NA")  ; 重新显示在正确位置
    WinSetTransparent(0, "ahk_id " gGui.Hwnd)
    FadeInGui(gGui.Hwnd)
    WinActivate("ahk_id " gGui.Hwnd)
    gEdit.Focus()
    gVisible := true
    gShowTimer := 0
}

FadeInGui(hwnd) {
    global gFadeAlpha, gFadeTimer
    gFadeAlpha := 0
    if (gFadeTimer)
        SetTimer(gFadeTimer, 0)
    gFadeTimer := FadeStep.Bind(hwnd)
    SetTimer(gFadeTimer, 15)
}

FadeStep(hwnd) {
    global gFadeAlpha, gFadeTimer
    gFadeAlpha += 25
    if (gFadeAlpha >= 255) {
        gFadeAlpha := 255
        WinSetTransparent(255, "ahk_id " hwnd)
        SetTimer(gFadeTimer, 0)
        gFadeTimer := 0
        return
    }
    WinSetTransparent(gFadeAlpha, "ahk_id " hwnd)
}

InitHotkey() {
    defaultHotkey := "#j"
    if !SetHotkey(defaultHotkey) {
        global gHotkeyLabel
        gHotkeyLabel := "快捷键: 未设置"
    }
}

SetHotkey(newHotkey, showError := false) {
    global gHotkey, gHotkeyLabel, gMenuReady
    newHotkey := Trim(newHotkey)
    if (newHotkey = "")
        return false
    if (gHotkey = newHotkey)
        return true
    try {
        Hotkey(newHotkey, HotkeyToggle, "On")
    } catch as e {
        if (showError)
            MsgBox("快捷键不可用: " newHotkey "`n" e.Message, "快捷键")
        return false
    }
    if (gHotkey != "") {
        try Hotkey(gHotkey, "Off")
        try Hotkey(gHotkey, "Delete")
    }
    gHotkey := newHotkey
    newLabel := "快捷键: " FormatHotkeyForDisplay(newHotkey)
    if (gMenuReady && gHotkeyLabel != "") {
        try A_TrayMenu.Rename(gHotkeyLabel, newLabel)
        try A_TrayMenu.Disable(newLabel)
    }
    gHotkeyLabel := newLabel
    return true
}

FormatHotkeyForDisplay(hk) {
    mods := ""
    if InStr(hk, "#")
        mods .= "Win+"
    if InStr(hk, "^")
        mods .= "Ctrl+"
    if InStr(hk, "!")
        mods .= "Alt+"
    if InStr(hk, "+")
        mods .= "Shift+"

    key := RegExReplace(hk, "[#^!+]")
    key := Trim(key)
    if (StrLen(key) = 1)
        key := StrUpper(key)
    if (mods != "" && key = "")
        return SubStr(mods, 1, -1)
    if (mods != "" && key != "")
        return mods key
    return key
}

HotkeyToggle(*) {
    ToggleGui()
}

ShowHotkeyDialog() {
    global gHotkeyGui, gHotkeyCtrl, gHotkey
    if !IsObject(gHotkeyGui) {
        gHotkeyGui := Gui("+AlwaysOnTop +ToolWindow", "设置快捷键")
        gHotkeyGui.MarginX := 10
        gHotkeyGui.MarginY := 10
        gHotkeyGui.AddText("", "按下新快捷键：")
        gHotkeyCtrl := gHotkeyGui.AddHotkey("w220")
        btnSave := gHotkeyGui.AddButton("w80", "保存")
        btnSave.OnEvent("Click", (*) => SaveHotkey())
        btnCancel := gHotkeyGui.AddButton("x+8 w80", "取消")
        btnCancel.OnEvent("Click", (*) => gHotkeyGui.Hide())
        gHotkeyGui.OnEvent("Close", (*) => gHotkeyGui.Hide())
    }
    gHotkeyCtrl.Value := gHotkey
    gHotkeyGui.Show()
    gHotkeyCtrl.Focus()
}

SaveHotkey() {
    global gHotkeyGui, gHotkeyCtrl
    newHotkey := gHotkeyCtrl.Value
    if (Trim(newHotkey) = "") {
        MsgBox("请按下一个快捷键。", "快捷键")
        return
    }
    if SetHotkey(newHotkey, true)
        gHotkeyGui.Hide()
}

CopyText() {
    global gEdit
    A_Clipboard := gEdit.Value
}

ClearText() {
    global gEdit
    gEdit.Value := ""
}

HideAndDiscard() {
    global gGui, gEdit, gVisible, gFadeTimer, gShowTimer
    if (gShowTimer) {
        SetTimer(gShowTimer, 0)
        gShowTimer := 0
    }
    if (gFadeTimer) {
        SetTimer(gFadeTimer, 0)
        gFadeTimer := 0
    }
    if IsObject(gEdit)
        gEdit.Value := ""   ; 丢弃文本
    if IsObject(gGui) && gGui.Hwnd && WinExist("ahk_id " gGui.Hwnd) {
        WinSetTransparent(255, "ahk_id " gGui.Hwnd)
        gGui.Hide()
    }
    gVisible := false
}

GuiClose(*) {
    HideAndDiscard()
    return true
}

GuiActivateMsg(wParam, lParam, msg, hwnd) {
    global gGui, gVisible
    if (!gVisible || !IsObject(gGui))
        return
    if (hwnd != gGui.Hwnd)
        return
    if ((wParam & 0xFFFF) = 0) { ; WA_INACTIVE
        HideAndDiscard()
        return 0
    }
}

TrayIconMsg(wParam, lParam, msg, hwnd) {
    ; lParam = 0x0201 左键按下, 0x0203 左键双击, 0x0204 右键按下等
    if (lParam = 0x0201) { ; WM_LBUTTONDOWN
        ToggleGui()
        return 0
    }
}
