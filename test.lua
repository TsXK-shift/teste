-- ╔══════════════════════════════════════════════════════╗
-- ║        STK TRADINGS — VALUE CHECKER  (v2.1 FIXED)   ║
-- ║        Script para Executores Roblox                 ║
-- ║  • Imagens carregam direto via URL (sem download)    ║
-- ║  • Fallback: baixa assets se URL falhar              ║
-- ║  • Cards estáveis no scroll                          ║
-- ║  • Busca funcionando em todas as abas                ║
-- ╚══════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════
--  DETECÇÃO DO EXECUTOR
-- ════════════════════════════════════════════════════════
local function getExecutorName()
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok and name then return tostring(name) end
    end
    if syn and syn.request then return "Synapse X"
    elseif KRNL_LOADED       then return "Krnl"
    elseif fluxus            then return "Fluxus"
    elseif electron          then return "Electron"
    elseif scriptware        then return "Script-Ware"
    elseif Delta             then return "Delta"
    elseif Xeno              then return "Xeno"
    elseif Wave              then return "Wave"
    elseif Sync              then return "Sync"
    elseif http_request      then return "Executor (HTTP)"
    else return "Roblox (Modo Normal)"
    end
end
local executorName = getExecutorName()

-- ════════════════════════════════════════════════════════
--  HTTP HELPER (multi-executor)
-- ════════════════════════════════════════════════════════
local function httpGet(url)
    local fn = (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
    if not fn then return nil end
    local ok, result = pcall(fn, { Url = url, Method = "GET" })
    if ok and result and result.Body then
        return result.Body
    end
    return nil
end

local function httpGetBinary(url)
    local fn = (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
    if not fn then return nil end
    local ok, result = pcall(fn, { Url = url, Method = "GET" })
    if ok and result then
        return result.Body
    end
    return nil
end

-- ════════════════════════════════════════════════════════
--  CATEGORIAS
-- ════════════════════════════════════════════════════════
local CATEGORIES = {
    { label = "Limited Knives",  icon = "🔪", url = "https://www.stktradings.com/item-list/limited-knives"  },
    { label = "Crafting",        icon = "⚒️",  url = "https://www.stktradings.com/item-list/crafting"         },
    { label = "Shop Knives",     icon = "🛒", url = "https://www.stktradings.com/item-list/shop-knives"      },
    { label = "Crate Knives",    icon = "📦", url = "https://www.stktradings.com/item-list/crate-knives"     },
    { label = "Limited Killers", icon = "💀", url = "https://www.stktradings.com/item-list/limited-killers"  },
    { label = "Shop Killers",    icon = "🛍️",  url = "https://www.stktradings.com/item-list/shop-killers"     },
    { label = "Bundles",         icon = "🎁", url = "https://www.stktradings.com/item-list/bundles"          },
    { label = "Cabins",          icon = "🏠", url = "https://www.stktradings.com/item-list/cabins"           },
    { label = "Consumables",     icon = "🧪", url = "https://www.stktradings.com/item-list/consumables"      },
    { label = "Misc",            icon = "✨", url = "https://www.stktradings.com/item-list/misc"             },
}

-- ════════════════════════════════════════════════════════
--  HTML PARSER
-- ════════════════════════════════════════════════════════
local function decodeHtml(s)
    if not s then return "N/A" end
    return s
        :gsub("&amp;",  "&"):gsub("&lt;",   "<"):gsub("&gt;",   ">"):gsub("&quot;", '"')
        :gsub("&#(%d+);", function(n) local num = tonumber(n) return (num and num < 128) and string.char(num) or "" end)
        :gsub("%s+", " "):match("^%s*(.-)%s*$") or s
end

local function fixUrl(src)
    if not src or src == "" then return "" end
    if src:sub(1, 4) == "http" then return src end
    if src:sub(1, 2) == "//"   then return "https:" .. src end
    if src:sub(1, 1) == "/"    then return "https://www.stktradings.com" .. src end
    return src
end

local function slugToName(slug)
    return slug:gsub("%-", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
end

local function parseItems(html)
    local items = {}
    if not html then return items end
    local positions = {}
    local cursor = 1
    while true do
        local p = html:find('class="roblox%-item"', cursor)
        if not p then break end
        table.insert(positions, p)
        cursor = p + 1
    end
    for i, pos in ipairs(positions) do
        local endPos = positions[i + 1] and (positions[i + 1] - 1) or #html
        local chunk  = html:sub(pos, endPos)
        local item   = {}
        local src = chunk:match('<img[^>]*%ssrc="([^"]+)"') or chunk:match("<img[^>]*%ssrc='([^']+)'")
        item.image = fixUrl(src or "")
        local alt = chunk:match('<img[^>]*%salt="([^"]+)"') or chunk:match("<img[^>]*%salt='([^']+)'")
        if alt and alt:match("%S") then
            item.name = decodeHtml(alt)
        elseif item.image ~= "" then
            local slug = item.image:match("/([^/%.]+)%.[^/%.]+$") or "Unknown"
            item.name = slugToName(slug)
        else
            item.name = "Unknown"
        end
        local val = chunk:match("<strong>([^<]+)</strong>")
        item.value  = val and decodeHtml(val) or "N/A"
        local dem   = chunk:match('title="Demand">([^<]+)<')
        item.demand = dem and decodeHtml(dem) or "N/A"
        local tr    = chunk:match('title="Trend">([^<]+)<')
        item.trend  = tr and decodeHtml(tr) or "N/A"
        if item.image ~= "" or item.name ~= "Unknown" then
            table.insert(items, item)
        end
    end
    return items
end

-- ════════════════════════════════════════════════════════
--  SISTEMA DE IMAGEM — ESTRATÉGIA MULTICAMADA
--  Camada 1: URL direta (rbxthumb ou external — funciona na
--            maioria dos executores sem qualquer download)
--  Camada 2: asset local (getcustomasset) se já baixado
--  Camada 3: download do binário e salva localmente
-- ════════════════════════════════════════════════════════
local ASSET_FOLDER  = "ValueCheck/assets/"
local IMAGE_CACHE   = {}   -- url → string (asset:// ou url)
local PENDING_DL    = {}   -- urls sendo baixadas agora
local HAS_FS        = (makefolder and writefile and isfile and getcustomasset) ~= nil

local function ensureFolder()
    if not HAS_FS then return end
    pcall(function()
        if not isfolder("ValueCheck")        then makefolder("ValueCheck")        end
        if not isfolder(ASSET_FOLDER:sub(1,-2)) then makefolder(ASSET_FOLDER:sub(1,-2)) end
    end)
end

-- sanitiza nome de arquivo
local function urlToFilename(url)
    local filename = url:match("/([^/]+%.[^/%.]+)$") or url:match("/([^/]+)$") or "img"
    return filename:gsub("[^%w%.%-_]", "_")
end

-- resolve imagem de forma assíncrona; chama callback(resolvedSrc)
local function resolveImage(item, callback)
    local url = item.image
    if not url or url == "" then callback(""); return end

    -- Já está no cache
    if IMAGE_CACHE[url] then callback(IMAGE_CACHE[url]); return end

    task.spawn(function()
        -- ── Camada 1: tentar carregar direto pela URL ──────────────────
        -- A maioria dos executores modernos (Synapse, KRNL, Delta, Wave,
        -- Xeno, Sync, Fluxus…) consegue usar Image = "URL" diretamente.
        -- Vamos assumir que sim e retornar imediatamente; se a imagem
        -- não aparecer, a Camada 3 já terá salvado localmente.
        IMAGE_CACHE[url] = url
        callback(url)

        -- ── Camada 2: arquivo local já existe? ────────────────────────
        if HAS_FS then
            local fname = urlToFilename(url)
            local path  = ASSET_FOLDER .. fname
            local ok2, exists = pcall(isfile, path)
            if ok2 and exists then
                local ok3, asset = pcall(getcustomasset, path)
                if ok3 and asset then
                    IMAGE_CACHE[url] = asset
                    -- Se o callback aceitar update posterior, pode chamar de novo;
                    -- aqui atualizamos só o cache para a próxima renderização.
                    return
                end
            end

            -- ── Camada 3: baixar e salvar (background, sem travar UI) ──
            if PENDING_DL[url] then return end
            PENDING_DL[url] = true
            local body = httpGetBinary(url)
            if body and #body > 0 then
                local ext  = url:match("%.(%a+)$") or "jpg"
                local wpath = ASSET_FOLDER .. fname
                local okW, errW = pcall(writefile, wpath, body)
                if okW then
                    local ok4, asset = pcall(getcustomasset, wpath)
                    if ok4 and asset then
                        IMAGE_CACHE[url] = asset
                    end
                end
            end
            PENDING_DL[url] = nil
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  DADOS
-- ════════════════════════════════════════════════════════
local allData   = {}
local currentCat = { label = "All", icon = "🌐", type = "all" }  -- inicializado aqui!

-- ════════════════════════════════════════════════════════
--  PALETA DE CORES
-- ════════════════════════════════════════════════════════
local C = {
    bg        = Color3.fromRGB(10,  10,  16),
    sidebar   = Color3.fromRGB(16,  16,  26),
    card      = Color3.fromRGB(24,  24,  38),
    cardHover = Color3.fromRGB(32,  32,  50),
    accent    = Color3.fromRGB(100, 100, 255),
    accentDim = Color3.fromRGB(40,  40, 100),
    text      = Color3.fromRGB(230, 230, 245),
    textMuted = Color3.fromRGB(110, 110, 140),
    green     = Color3.fromRGB(52,  211, 153),
    red       = Color3.fromRGB(251, 100, 120),
    yellow    = Color3.fromRGB(251, 191, 36),
    orange    = Color3.fromRGB(251, 146, 60),
    border    = Color3.fromRGB(38,  38,  60),
    white     = Color3.fromRGB(255, 255, 255),
    titleBar  = Color3.fromRGB(14,  14,  22),
}

local function demandColor(d)
    local dl = (d or ""):lower()
    if dl:find("very high") then return C.green
    elseif dl:find("high")  then return Color3.fromRGB(110, 231, 183)
    elseif dl:find("very low") then return C.red
    elseif dl:find("low")   then return Color3.fromRGB(253, 164, 175)
    elseif dl:find("normal") or dl:find("moderate") then return C.yellow
    else return C.textMuted end
end

local function trendInfo(t)
    local tl = (t or ""):lower()
    if tl:find("ris") or tl:find("up") or tl:find("high") then
        return "▲", C.green
    elseif tl:find("drop") or tl:find("down") or tl:find("fall") or tl:find("low") then
        return "▼", C.red
    else
        return "●", C.textMuted
    end
end

-- ════════════════════════════════════════════════════════
--  DESTRUIR GUI ANTIGA
-- ════════════════════════════════════════════════════════
if PlayerGui:FindFirstChild("_STK_Checker") then
    PlayerGui._STK_Checker:Destroy()
end

-- ════════════════════════════════════════════════════════
--  SCREEN GUI
-- ════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "_STK_Checker"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

local WIN_W, WIN_H = 950, 610

local Win = Instance.new("Frame")
Win.Name             = "Window"
Win.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Win.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel  = 0
Win.ClipsDescendants = true
Win.Parent           = ScreenGui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 14)

local WinStroke = Instance.new("UIStroke")
WinStroke.Color     = C.border
WinStroke.Thickness = 1.5
WinStroke.Parent    = Win

-- ─── Barra de título ──────────────────────────────────
local TBar = Instance.new("Frame")
TBar.Name             = "TitleBar"
TBar.Size             = UDim2.new(1, 0, 0, 52)
TBar.BackgroundColor3 = C.titleBar
TBar.BorderSizePixel  = 0
TBar.ZIndex           = 5
TBar.Parent           = Win

local TBarLine = Instance.new("Frame")
TBarLine.Size             = UDim2.new(1, 0, 0, 1)
TBarLine.Position         = UDim2.new(0, 0, 1, -1)
TBarLine.BackgroundColor3 = C.border
TBarLine.BorderSizePixel  = 0
TBarLine.ZIndex           = 6
TBarLine.Parent           = TBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size                = UDim2.new(1, -200, 1, 0)
TitleLbl.Position            = UDim2.new(0, 16, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                = "⚔  STK Tradings  ·  Value Checker"
TitleLbl.TextColor3          = C.text
TitleLbl.TextSize            = 15
TitleLbl.Font                = Enum.Font.GothamBold
TitleLbl.TextXAlignment      = Enum.TextXAlignment.Left
TitleLbl.ZIndex              = 6
TitleLbl.Parent              = TBar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size                = UDim2.new(0, 400, 0, 14)
SubLbl.Position            = UDim2.new(0, 16, 1, -18)
SubLbl.BackgroundTransparency = 1
SubLbl.Text                = "stktradings.com  ·  dados em tempo real  ·  " .. executorName
SubLbl.TextColor3          = C.textMuted
SubLbl.TextSize            = 9
SubLbl.Font                = Enum.Font.Gotham
SubLbl.TextXAlignment      = Enum.TextXAlignment.Left
SubLbl.ZIndex              = 6
SubLbl.Parent              = TBar

local function winBtn(color, lbl, xOff)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 26, 0, 26)
    b.Position         = UDim2.new(1, xOff, 0.5, -13)
    b.BackgroundColor3 = color
    b.Text             = lbl
    b.TextColor3       = C.white
    b.TextSize         = 11
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.ZIndex           = 7
    b.Parent           = TBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play() end)
    return b
end

local CloseBtn   = winBtn(Color3.fromRGB(255, 90, 85),  "✕", -44)
local MinBtn     = winBtn(Color3.fromRGB(255, 185, 40), "–", -78)
local RefreshBtn = winBtn(Color3.fromRGB(60, 60, 90),   "↺", -112)

-- Drag
do
    local drag, ds, ws = false, nil, nil
    TBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag, ds, ws = true, i.Position, Win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            Win.Position = UDim2.new(ws.X.Scale, ws.X.Offset + d.X, ws.Y.Scale, ws.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
end

-- ─── Body ────────────────────────────────────────────
local Body = Instance.new("Frame")
Body.Name                = "Body"
Body.Size                = UDim2.new(1, 0, 1, -52)
Body.Position            = UDim2.new(0, 0, 0, 52)
Body.BackgroundTransparency = 1
Body.ClipsDescendants    = true
Body.Parent              = Win

-- ════════════════════════════════════════════════════════
--  SIDEBAR
-- ════════════════════════════════════════════════════════
local SIDEBAR_W = 178

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name                = "Sidebar"
Sidebar.Size                = UDim2.new(0, SIDEBAR_W, 1, 0)
Sidebar.BackgroundColor3    = C.sidebar
Sidebar.BorderSizePixel     = 0
Sidebar.ScrollBarThickness  = 0
Sidebar.CanvasSize          = UDim2.new(0, 0, 0, 0)
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Parent              = Body

local SbPad = Instance.new("UIPadding")
SbPad.PaddingLeft   = UDim.new(0, 8)
SbPad.PaddingRight  = UDim.new(0, 8)
SbPad.PaddingTop    = UDim.new(0, 14)
SbPad.PaddingBottom = UDim.new(0, 14)
SbPad.Parent        = Sidebar

local SbLayout = Instance.new("UIListLayout")
SbLayout.Padding             = UDim.new(0, 4)
SbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SbLayout.Parent              = Sidebar

local SbTitle = Instance.new("TextLabel")
SbTitle.Size                = UDim2.new(1, 0, 0, 24)
SbTitle.BackgroundTransparency = 1
SbTitle.Text                = "SEÇÕES"
SbTitle.TextColor3          = C.textMuted
SbTitle.TextSize            = 9
SbTitle.Font                = Enum.Font.GothamBold
SbTitle.TextXAlignment      = Enum.TextXAlignment.Left
SbTitle.LayoutOrder         = -1
SbTitle.Parent              = Sidebar

local SbTitlePad = Instance.new("UIPadding")
SbTitlePad.PaddingLeft = UDim.new(0, 6)
SbTitlePad.Parent      = SbTitle

local SbDiv = Instance.new("Frame")
SbDiv.Size             = UDim2.new(1, 0, 0, 1)
SbDiv.BackgroundColor3 = C.border
SbDiv.BorderSizePixel  = 0
SbDiv.LayoutOrder      = 0
SbDiv.Parent           = Sidebar

-- ════════════════════════════════════════════════════════
--  PAINEL PRINCIPAL
-- ════════════════════════════════════════════════════════
local PANEL_X = SIDEBAR_W + 8

local Panel = Instance.new("Frame")
Panel.Name                = "Panel"
Panel.Size                = UDim2.new(1, -(PANEL_X + 6), 1, -8)
Panel.Position            = UDim2.new(0, PANEL_X, 0, 4)
Panel.BackgroundTransparency = 1
Panel.ClipsDescendants    = false
Panel.Parent              = Body

local SearchWrap = Instance.new("Frame")
SearchWrap.Size             = UDim2.new(1, 0, 0, 38)
SearchWrap.BackgroundColor3 = C.card
SearchWrap.BorderSizePixel  = 0
SearchWrap.Parent           = Panel
Instance.new("UICorner", SearchWrap).CornerRadius = UDim.new(0, 9)

local SWStroke = Instance.new("UIStroke")
SWStroke.Color     = C.border
SWStroke.Thickness = 1
SWStroke.Parent    = SearchWrap

local SearchIconLbl = Instance.new("TextLabel")
SearchIconLbl.Size                = UDim2.new(0, 38, 1, 0)
SearchIconLbl.BackgroundTransparency = 1
SearchIconLbl.Text                = "🔍"
SearchIconLbl.TextSize            = 13
SearchIconLbl.Font                = Enum.Font.Gotham
SearchIconLbl.TextXAlignment      = Enum.TextXAlignment.Center
SearchIconLbl.Parent              = SearchWrap

local SearchBox = Instance.new("TextBox")
SearchBox.Size                = UDim2.new(1, -44, 1, 0)
SearchBox.Position            = UDim2.new(0, 38, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText     = "Buscar item..."
SearchBox.PlaceholderColor3   = C.textMuted
SearchBox.Text                = ""
SearchBox.TextColor3          = C.text
SearchBox.TextSize            = 13
SearchBox.Font                = Enum.Font.Gotham
SearchBox.TextXAlignment      = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus    = false
SearchBox.Parent              = SearchWrap

local InfoBar = Instance.new("Frame")
InfoBar.Size                = UDim2.new(1, 0, 0, 26)
InfoBar.Position            = UDim2.new(0, 0, 0, 44)
InfoBar.BackgroundTransparency = 1
InfoBar.Parent              = Panel

local CatNameLbl = Instance.new("TextLabel")
CatNameLbl.Size               = UDim2.new(0.6, 0, 1, 0)
CatNameLbl.BackgroundTransparency = 1
CatNameLbl.Text               = ""
CatNameLbl.TextColor3         = C.accent
CatNameLbl.TextSize           = 11
CatNameLbl.Font               = Enum.Font.GothamBold
CatNameLbl.TextXAlignment     = Enum.TextXAlignment.Left
CatNameLbl.Parent             = InfoBar

local CountLbl = Instance.new("TextLabel")
CountLbl.Size               = UDim2.new(0.4, 0, 1, 0)
CountLbl.Position           = UDim2.new(0.6, 0, 0, 0)
CountLbl.BackgroundTransparency = 1
CountLbl.Text               = ""
CountLbl.TextColor3         = C.textMuted
CountLbl.TextSize           = 10
CountLbl.Font               = Enum.Font.Gotham
CountLbl.TextXAlignment     = Enum.TextXAlignment.Right
CountLbl.Parent             = InfoBar

local Divider = Instance.new("Frame")
Divider.Size             = UDim2.new(1, 0, 0, 1)
Divider.Position         = UDim2.new(0, 0, 0, 72)
Divider.BackgroundColor3 = C.border
Divider.BorderSizePixel  = 0
Divider.Parent           = Panel

local ItemScroll = Instance.new("ScrollingFrame")
ItemScroll.Name                   = "ItemScroll"
ItemScroll.Size                   = UDim2.new(1, 0, 1, -80)
ItemScroll.Position               = UDim2.new(0, 0, 0, 78)
ItemScroll.BackgroundTransparency = 1
ItemScroll.ScrollBarThickness     = 5
ItemScroll.ScrollBarImageColor3   = C.accent
ItemScroll.BorderSizePixel        = 0
ItemScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
ItemScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
ItemScroll.Parent                 = Panel

local ItemGrid = Instance.new("UIGridLayout")
ItemGrid.CellSize            = UDim2.new(0, 147, 0, 208)
ItemGrid.CellPadding         = UDim2.new(0, 8,   0, 8)
ItemGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
ItemGrid.SortOrder           = Enum.SortOrder.LayoutOrder
ItemGrid.Parent              = ItemScroll

local GridPad = Instance.new("UIPadding")
GridPad.PaddingBottom = UDim.new(0, 10)
GridPad.Parent        = ItemScroll

-- ════════════════════════════════════════════════════════
--  OVERLAY DE LOADING
-- ════════════════════════════════════════════════════════
local LoadBG = Instance.new("Frame")
LoadBG.Name                = "LoadBG"
LoadBG.Size                = UDim2.new(1, 0, 1, 0)
LoadBG.BackgroundColor3    = C.bg
LoadBG.BackgroundTransparency = 0.05
LoadBG.ZIndex              = 30
LoadBG.Visible             = true
LoadBG.Parent              = Win

local LoadCard = Instance.new("Frame")
LoadCard.Size             = UDim2.new(0, 340, 0, 150)
LoadCard.Position         = UDim2.new(0.5, -170, 0.5, -75)
LoadCard.BackgroundColor3 = C.card
LoadCard.BorderSizePixel  = 0
LoadCard.ZIndex           = 31
LoadCard.Parent           = LoadBG
Instance.new("UICorner", LoadCard).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", LoadCard).Color = C.border

local LoadTitleLbl = Instance.new("TextLabel")
LoadTitleLbl.Size                = UDim2.new(1, -20, 0, 36)
LoadTitleLbl.Position            = UDim2.new(0, 10, 0, 16)
LoadTitleLbl.BackgroundTransparency = 1
LoadTitleLbl.Text                = "⚔  Carregando dados do STK..."
LoadTitleLbl.TextColor3          = C.text
LoadTitleLbl.TextSize            = 16
LoadTitleLbl.Font                = Enum.Font.GothamBold
LoadTitleLbl.ZIndex              = 32
LoadTitleLbl.Parent              = LoadCard

local LoadStatusLbl = Instance.new("TextLabel")
LoadStatusLbl.Size               = UDim2.new(1, -20, 0, 20)
LoadStatusLbl.Position           = UDim2.new(0, 10, 0, 56)
LoadStatusLbl.BackgroundTransparency = 1
LoadStatusLbl.Text               = "Iniciando conexão..."
LoadStatusLbl.TextColor3         = C.textMuted
LoadStatusLbl.TextSize           = 12
LoadStatusLbl.Font               = Enum.Font.Gotham
LoadStatusLbl.ZIndex             = 32
LoadStatusLbl.Parent             = LoadCard

local ProgBg = Instance.new("Frame")
ProgBg.Size             = UDim2.new(1, -20, 0, 8)
ProgBg.Position         = UDim2.new(0, 10, 0, 90)
ProgBg.BackgroundColor3 = C.border
ProgBg.BorderSizePixel  = 0
ProgBg.ZIndex           = 32
ProgBg.Parent           = LoadCard
Instance.new("UICorner", ProgBg).CornerRadius = UDim.new(0, 4)

local ProgFill = Instance.new("Frame")
ProgFill.Size             = UDim2.new(0, 0, 1, 0)
ProgFill.BackgroundColor3 = C.accent
ProgFill.BorderSizePixel  = 0
ProgFill.ZIndex           = 33
ProgFill.Parent           = ProgBg
Instance.new("UICorner", ProgFill).CornerRadius = UDim.new(0, 4)

local ProgLabel = Instance.new("TextLabel")
ProgLabel.Size               = UDim2.new(1, -20, 0, 18)
ProgLabel.Position           = UDim2.new(0, 10, 0, 110)
ProgLabel.BackgroundTransparency = 1
ProgLabel.Text               = "0 / " .. #CATEGORIES .. " categorias"
ProgLabel.TextColor3         = C.textMuted
ProgLabel.TextSize           = 10
ProgLabel.Font               = Enum.Font.Gotham
ProgLabel.ZIndex             = 32
ProgLabel.Parent             = LoadCard

-- ════════════════════════════════════════════════════════
--  RENDER DE CARDS
--  FIX: não destroi + recria tudo; usa pool de filhos e
--       apenas esconde os que não passam no filtro,
--       evitando o desaparecimento de texto no scroll.
-- ════════════════════════════════════════════════════════

-- Pool de cards reusáveis
local cardPool = {}

local function getCardChild(parent, class, name)
    return parent:FindFirstChild(name) or Instance.new(class)
end

local function renderItems(items, filter)
    -- Guarda posição do scroll para não resetar
    local savedCanvas = ItemScroll.CanvasPosition

    filter = (filter or ""):lower():gsub("^%s+",""):gsub("%s+$","")

    -- Esconde todos antes de reconfigurar
    for _, c in ipairs(cardPool) do
        c.Visible = false
        c.Parent  = nil
    end

    local count  = 0
    local order  = 0
    local needed = 0

    -- Conta quantos cards vamos precisar
    for _, item in ipairs(items) do
        local pass = filter == "" or item.name:lower():find(filter, 1, true)
        if pass then needed = needed + 1 end
    end

    -- Garante pool suficiente
    while #cardPool < needed do
        local Card = Instance.new("Frame")
        Card.BackgroundColor3 = C.card
        Card.BorderSizePixel  = 0
        Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

        local CS = Instance.new("UIStroke", Card)
        CS.Name      = "Stroke"
        CS.Color     = C.border
        CS.Thickness = 1

        local ImgBg = Instance.new("Frame", Card)
        ImgBg.Name             = "ImgBg"
        ImgBg.Size             = UDim2.new(1, -10, 0, 120)
        ImgBg.Position         = UDim2.new(0, 5, 0, 5)
        ImgBg.BackgroundColor3 = C.bg
        ImgBg.BorderSizePixel  = 0
        Instance.new("UICorner", ImgBg).CornerRadius = UDim.new(0, 8)

        local Img = Instance.new("ImageLabel", ImgBg)
        Img.Name                = "Img"
        Img.Size                = UDim2.new(1, 0, 1, 0)
        Img.BackgroundTransparency = 1
        Img.Image               = ""
        Img.ScaleType           = Enum.ScaleType.Fit
        Img.BorderSizePixel     = 0

        local ImgFallback = Instance.new("TextLabel", ImgBg)
        ImgFallback.Name               = "Fallback"
        ImgFallback.Size               = UDim2.new(1, 0, 1, 0)
        ImgFallback.BackgroundTransparency = 1
        ImgFallback.Text               = "?"
        ImgFallback.TextColor3         = C.border
        ImgFallback.TextSize           = 36
        ImgFallback.Font               = Enum.Font.GothamBold
        ImgFallback.ZIndex             = 1

        local NameLbl = Instance.new("TextLabel", Card)
        NameLbl.Name               = "NameLbl"
        NameLbl.Size               = UDim2.new(1, -8, 0, 30)
        NameLbl.Position           = UDim2.new(0, 4, 0, 129)
        NameLbl.BackgroundTransparency = 1
        NameLbl.TextColor3         = C.text
        NameLbl.TextSize           = 9
        NameLbl.Font               = Enum.Font.GothamSemibold
        NameLbl.TextWrapped        = true
        NameLbl.TextXAlignment     = Enum.TextXAlignment.Center

        local ValBg = Instance.new("Frame", Card)
        ValBg.Name             = "ValBg"
        ValBg.Size             = UDim2.new(1, -10, 0, 24)
        ValBg.Position         = UDim2.new(0, 5, 0, 160)
        ValBg.BackgroundColor3 = C.accentDim
        ValBg.BorderSizePixel  = 0
        Instance.new("UICorner", ValBg).CornerRadius = UDim.new(0, 7)

        local ValLbl = Instance.new("TextLabel", ValBg)
        ValLbl.Name               = "ValLbl"
        ValLbl.Size               = UDim2.new(1, 0, 1, 0)
        ValLbl.BackgroundTransparency = 1
        ValLbl.TextColor3         = C.accent
        ValLbl.TextSize           = 13
        ValLbl.Font               = Enum.Font.GothamBold
        ValLbl.TextXAlignment     = Enum.TextXAlignment.Center

        local DmTrBar = Instance.new("Frame", Card)
        DmTrBar.Name               = "DmTrBar"
        DmTrBar.Size               = UDim2.new(1, -10, 0, 18)
        DmTrBar.Position           = UDim2.new(0, 5, 0, 186)
        DmTrBar.BackgroundTransparency = 1

        local DemLbl = Instance.new("TextLabel", DmTrBar)
        DemLbl.Name               = "DemLbl"
        DemLbl.Size               = UDim2.new(0.55, 0, 1, 0)
        DemLbl.BackgroundTransparency = 1
        DemLbl.TextSize           = 9
        DemLbl.Font               = Enum.Font.GothamSemibold
        DemLbl.TextXAlignment     = Enum.TextXAlignment.Left

        local TrLbl = Instance.new("TextLabel", DmTrBar)
        TrLbl.Name               = "TrLbl"
        TrLbl.Size               = UDim2.new(0.45, 0, 1, 0)
        TrLbl.Position           = UDim2.new(0.55, 0, 0, 0)
        TrLbl.BackgroundTransparency = 1
        TrLbl.TextSize           = 9
        TrLbl.Font               = Enum.Font.GothamSemibold
        TrLbl.TextXAlignment     = Enum.TextXAlignment.Right

        table.insert(cardPool, Card)
    end

    -- Reusa e configura cards
    local poolIdx = 0
    for _, item in ipairs(items) do
        local pass = filter == "" or item.name:lower():find(filter, 1, true)
        if not pass then continue end

        count   = count + 1
        order   = order + 1
        poolIdx = poolIdx + 1
        local Card = cardPool[poolIdx]

        -- Configura valores de texto (sempre estáveis)
        Card:FindFirstChild("NameLbl").Text         = item.name
        Card:FindFirstChild("ValBg"):FindFirstChild("ValLbl").Text = " " .. item.value

        local DemLbl = Card:FindFirstChild("DmTrBar"):FindFirstChild("DemLbl")
        local TrLbl  = Card:FindFirstChild("DmTrBar"):FindFirstChild("TrLbl")
        DemLbl.Text       = item.demand
        DemLbl.TextColor3 = demandColor(item.demand)

        local tIcon, tColor = trendInfo(item.trend)
        TrLbl.Text       = tIcon .. " " .. item.trend
        TrLbl.TextColor3 = tColor

        -- Fallback com inicial
        Card:FindFirstChild("ImgBg"):FindFirstChild("Fallback").Text = item.name:sub(1,1):upper()

        -- Imagem: resolve de forma assíncrona, não bloqueia UI
        local Img = Card:FindFirstChild("ImgBg"):FindFirstChild("Img")
        Img.Image = IMAGE_CACHE[item.image] or ""

        if Img.Image == "" then
            local capturedImg  = Img
            local capturedItem = item
            resolveImage(capturedItem, function(src)
                -- Verifica se o card ainda está sendo usado para este item
                if capturedImg and capturedImg.Parent then
                    capturedImg.Image = src or ""
                end
            end)
        end

        -- Hover
        local CardStroke = Card:FindFirstChild("Stroke")
        Card.MouseEnter:Connect(function()
            TweenService:Create(Card,        TweenInfo.new(0.12), {BackgroundColor3 = C.cardHover}):Play()
            TweenService:Create(CardStroke,  TweenInfo.new(0.12), {Color = C.accent, Thickness = 1.5}):Play()
        end)
        Card.MouseLeave:Connect(function()
            TweenService:Create(Card,        TweenInfo.new(0.12), {BackgroundColor3 = C.card}):Play()
            TweenService:Create(CardStroke,  TweenInfo.new(0.12), {Color = C.border, Thickness = 1}):Play()
        end)

        Card.LayoutOrder = order
        Card.Visible     = true
        Card.BackgroundColor3 = C.card
        CardStroke.Color      = C.border
        CardStroke.Thickness  = 1
        Card.Parent = ItemScroll
    end

    -- Atualiza labels de categoria e contagem
    CatNameLbl.Text = (currentCat.icon or "") .. "  " .. (currentCat.label or ""):upper()
    CountLbl.Text   = count .. " item" .. (count ~= 1 and "s" or "")
                    .. (filter ~= "" and ("  ·  \"" .. filter .. "\"") or "")

    -- Restaura posição do scroll (evita reset ao buscar)
    task.defer(function()
        if ItemScroll and ItemScroll.Parent then
            ItemScroll.CanvasPosition = savedCanvas
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  GERENCIAMENTO DE ABAS
-- ════════════════════════════════════════════════════════
local tabList = {}

local function getAllMergedItems()
    local merged = {}
    for _, catItems in pairs(allData) do
        for _, item in ipairs(catItems) do
            table.insert(merged, item)
        end
    end
    return merged
end

local function setActiveTab(cat)
    currentCat = cat
    for _, t in ipairs(tabList) do
        local active = t.cat.label == cat.label
        TweenService:Create(t.btn, TweenInfo.new(0.18), {
            BackgroundColor3 = active and C.accent or C.sidebar,
        }):Play()
        t.btn.TextColor3 = active and C.white or C.textMuted
    end
    local items
    if cat.type == "all" then
        items = getAllMergedItems()
    else
        items = allData[cat.label] or {}
    end
    -- Reset scroll ao trocar de aba
    ItemScroll.CanvasPosition = Vector2.new(0, 0)
    renderItems(items, SearchBox.Text)
end

-- Botão "All"
local allBtn = Instance.new("TextButton")
allBtn.Name             = "Tab_All"
allBtn.Size             = UDim2.new(1, 0, 0, 38)
allBtn.BackgroundColor3 = C.sidebar
allBtn.Text             = "🌐  All"
allBtn.TextColor3       = C.textMuted
allBtn.TextSize         = 11
allBtn.Font             = Enum.Font.GothamSemibold
allBtn.BorderSizePixel  = 0
allBtn.TextXAlignment   = Enum.TextXAlignment.Left
allBtn.AutoButtonColor  = false
allBtn.LayoutOrder      = 0
allBtn.Parent           = Sidebar
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 8)
local BtnPadAll = Instance.new("UIPadding")
BtnPadAll.PaddingLeft = UDim.new(0, 10)
BtnPadAll.Parent      = allBtn

local allCatEntry = { label = "All", icon = "🌐", type = "all" }
table.insert(tabList, { btn = allBtn, cat = allCatEntry })
allBtn.MouseButton1Click:Connect(function() setActiveTab(allCatEntry) end)
allBtn.MouseEnter:Connect(function()
    if currentCat.label ~= "All" then TweenService:Create(allBtn, TweenInfo.new(0.1), {BackgroundColor3 = C.card}):Play() end
end)
allBtn.MouseLeave:Connect(function()
    if currentCat.label ~= "All" then TweenService:Create(allBtn, TweenInfo.new(0.1), {BackgroundColor3 = C.sidebar}):Play() end
end)

-- Categorias normais
for i, cat in ipairs(CATEGORIES) do
    local Btn = Instance.new("TextButton")
    Btn.Name             = "Tab_" .. cat.label
    Btn.Size             = UDim2.new(1, 0, 0, 38)
    Btn.BackgroundColor3 = C.sidebar
    Btn.Text             = cat.icon .. "  " .. cat.label
    Btn.TextColor3       = C.textMuted
    Btn.TextSize         = 11
    Btn.Font             = Enum.Font.GothamSemibold
    Btn.BorderSizePixel  = 0
    Btn.TextXAlignment   = Enum.TextXAlignment.Left
    Btn.AutoButtonColor  = false
    Btn.LayoutOrder      = i
    Btn.Parent           = Sidebar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local BtnPad = Instance.new("UIPadding")
    BtnPad.PaddingLeft = UDim.new(0, 10)
    BtnPad.Parent      = Btn

    table.insert(tabList, { btn = Btn, cat = cat })
    local mycat = cat
    Btn.MouseButton1Click:Connect(function() setActiveTab(mycat) end)
    Btn.MouseEnter:Connect(function()
        if currentCat.label ~= mycat.label then TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = C.card}):Play() end
    end)
    Btn.MouseLeave:Connect(function()
        if currentCat.label ~= mycat.label then TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = C.sidebar}):Play() end
    end)
end

-- ════════════════════════════════════════════════════════
--  BUSCA — debounce para não travar UI com 759 itens
-- ════════════════════════════════════════════════════════
local searchDebounce = nil

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if searchDebounce then task.cancel(searchDebounce) end
    searchDebounce = task.delay(0.18, function()
        local items = currentCat.type == "all" and getAllMergedItems() or (allData[currentCat.label] or {})
        renderItems(items, SearchBox.Text)
    end)
end)

-- ════════════════════════════════════════════════════════
--  CONTROLES DA JANELA
-- ════════════════════════════════════════════════════════
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = minimized and UDim2.new(0, WIN_W, 0, 52) or UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Win, TweenInfo.new(0.2), {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, WIN_W, 0, 0),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, 0),
    }):Play()
    task.delay(0.22, function() ScreenGui:Destroy() end)
end)

-- ════════════════════════════════════════════════════════
--  CARREGAMENTO DOS DADOS
-- ════════════════════════════════════════════════════════
local function fetchAll()
    ensureFolder()
    LoadBG.Visible = true
    LoadBG.BackgroundTransparency = 0.05
    ProgFill.Size = UDim2.new(0, 0, 1, 0)

    -- Limpa pool ao recarregar
    for _, c in ipairs(cardPool) do
        c.Parent = nil
        c.Visible = false
    end

    local totalCats = #CATEGORIES
    for i, cat in ipairs(CATEGORIES) do
        LoadStatusLbl.Text = "Buscando: " .. cat.icon .. " " .. cat.label .. "..."
        ProgLabel.Text     = (i - 1) .. " / " .. totalCats .. " categorias"
        TweenService:Create(ProgFill, TweenInfo.new(0.2), { Size = UDim2.new((i-1)/totalCats, 0, 1, 0) }):Play()
        task.wait(0.05)

        local html = httpGet(cat.url)
        allData[cat.label] = html and parseItems(html) or {}
        if not html then warn("[STKChecker] Falha: " .. cat.label) end

        TweenService:Create(ProgFill, TweenInfo.new(0.18), { Size = UDim2.new(i/totalCats, 0, 1, 0) }):Play()
        task.wait(0.25)
    end

    LoadStatusLbl.Text = "✓ Dados carregados!"
    ProgLabel.Text     = totalCats .. " / " .. totalCats .. " categorias"
    task.wait(0.6)

    TweenService:Create(LoadBG, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
    task.wait(0.35)
    LoadBG.Visible = false

    setActiveTab(allCatEntry)
end

RefreshBtn.MouseButton1Click:Connect(function()
    allData    = {}
    IMAGE_CACHE = {}
    task.spawn(fetchAll)
end)

-- ════════════════════════════════════════════════════════
--  INICIAR
-- ════════════════════════════════════════════════════════
task.spawn(fetchAll)

print("[STKChecker] ⚔ STK Tradings Value Checker v2.1 carregado! Executor: " .. executorName)
