-- STK TRADINGS VALUE CHECKER v3.2
-- Fixes:
--   [1] DL_TOTAL nao sobe mais ao trocar categoria (DL_QUEUED rastreia URLs ja contadas)
--   [2] Imagens carregam em TODOS executores com FS (HAS_FS-based, nao IS_XENO)
--       Delta, Wave, Fluxus, Xeno, Synapse, KRNL → todos usam download quando FS disponivel
--   [3] NameLbl oculto quando imagem carrega; aparece so se imagem falhar
--   [4] Filtros de ordenacao: DEFAULT | RECENT | VALUE | RARITY | NAME
--   [5] parseItems extrai data-id, data-value, data-demand numericos para ordenacao precisa

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════
--  DETECCAO DE EXECUTOR
-- ══════════════════════════════════════════════
local execName = "Unknown"
do
    if identifyexecutor then
        local ok, n = pcall(identifyexecutor)
        if ok and n then execName = tostring(n) end
    elseif syn and syn.request then execName = "Synapse X"
    elseif KRNL_LOADED         then execName = "Krnl"
    elseif fluxus              then execName = "Fluxus"
    elseif electron            then execName = "Electron"
    elseif scriptware          then execName = "Script-Ware"
    elseif http_request        then execName = "Unknown (HTTP)"
    end
end

-- ══════════════════════════════════════════════
--  HTTP HELPER
-- ══════════════════════════════════════════════
local httpFn = (syn and syn.request)
            or (http and http.request)
            or http_request
            or request

local function httpGet(url)
    if not httpFn then return nil end
    local ok, r = pcall(httpFn, { Url = url, Method = "GET" })
    return (ok and r and r.Body and #r.Body > 0) and r.Body or nil
end

-- ══════════════════════════════════════════════
--  CATEGORIAS
-- ══════════════════════════════════════════════
local CATEGORIES = {
    { label = "LIMITED KNIVES",  url = "https://www.stktradings.com/item-list/limited-knives"  },
    { label = "CRAFTING",        url = "https://www.stktradings.com/item-list/crafting"         },
    { label = "SHOP KNIVES",     url = "https://www.stktradings.com/item-list/shop-knives"      },
    { label = "CRATE KNIVES",    url = "https://www.stktradings.com/item-list/crate-knives"     },
    { label = "LIMITED KILLERS", url = "https://www.stktradings.com/item-list/limited-killers"  },
    { label = "SHOP KILLERS",    url = "https://www.stktradings.com/item-list/shop-killers"     },
    { label = "BUNDLES",         url = "https://www.stktradings.com/item-list/bundles"          },
    { label = "CABINS",          url = "https://www.stktradings.com/item-list/cabins"           },
    { label = "CONSUMABLES",     url = "https://www.stktradings.com/item-list/consumables"      },
    { label = "MISC",            url = "https://www.stktradings.com/item-list/misc"             },
}

-- ══════════════════════════════════════════════
--  HTML PARSER
-- ══════════════════════════════════════════════
local function decodeHtml(s)
    if not s then return "N/A" end
    return (s
        :gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"')
        :gsub("&#(%d+);", function(n)
            local v = tonumber(n)
            return (v and v < 128) and string.char(v) or ""
        end)
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$") or s)
end

local function fixUrl(src)
    if not src or src == "" then return "" end
    if src:sub(1,4) == "http" then return src end
    if src:sub(1,2) == "//"   then return "https:"..src end
    if src:sub(1,1) == "/"    then return "https://www.stktradings.com"..src end
    return src
end

local function slugToName(slug)
    return (slug:gsub("%-"," "):gsub("(%a)([%w]*)", function(a,b) return a:upper()..b end))
end

-- Converte string de valor para numero (ex: "1,250,000" → 1250000)
local function parseValueNum(s)
    if not s or s == "N/A" or s == "" then return 0 end
    return tonumber(s:gsub("[,%s]","")) or 0
end

-- Score de demand para ordenacao: Very High=5 High=4 Normal=3 Low=2 Very Low=1
local function demandToScore(d, numericDem)
    if numericDem and numericDem > 0 then return numericDem end
    local dl = (d or ""):lower()
    if dl:find("very high") then return 5
    elseif dl:find("high")  then return 4
    elseif dl:find("normal") or dl:find("moderate") then return 3
    elseif dl:find("very low") then return 1
    elseif dl:find("low") then return 2
    end
    return 0
end

local function parseItems(html)
    local items, positions, cursor = {}, {}, 1
    if not html then return items end
    while true do
        local p = html:find('class="roblox%-item"', cursor)
        if not p then break end
        table.insert(positions, p); cursor = p + 1
    end
    for i, pos in ipairs(positions) do
        local endPos = positions[i+1] and (positions[i+1]-1) or #html
        local chunk  = html:sub(pos, endPos)
        local item   = {}

        -- data-id → recencia (maior id = mais novo)
        local rawId = chunk:match('data%-id="(%d+)"') or chunk:match("data%-id='(%d+)'")
        item.id = tonumber(rawId) or 0

        -- imagem
        local src = chunk:match('<img[^>]*%ssrc="([^"]+)"') or chunk:match("<img[^>]*%ssrc='([^']+)'")
        item.image = fixUrl(src or "")

        -- nome via alt ou slug da URL
        local alt = chunk:match('<img[^>]*%salt="([^"]+)"') or chunk:match("<img[^>]*%salt='([^']+)'")
        if alt and alt:match("%S") then
            item.name = decodeHtml(alt)
        elseif item.image ~= "" then
            local slug = item.image:match("/([^/%.]+)%.[^/%.]+$") or "Unknown"
            item.name  = slugToName(slug)
        else
            item.name = "Unknown"
        end

        -- valor display (formato item-list: <strong>...</strong>)
        local val  = chunk:match("<strong>([^<]+)</strong>")
        item.value = val and decodeHtml(val) or "N/A"

        -- valor numerico: prefere data-value, senao parseia display
        local rawVal = chunk:match('data%-value="(%d+)"') or chunk:match("data%-value='(%d+)'")
        if rawVal then
            item.valueNum = tonumber(rawVal) or 0
        else
            item.valueNum = parseValueNum(item.value)
        end

        -- demand display
        local dem  = chunk:match('title="Demand">([^<]+)<')
        item.demand = dem and decodeHtml(dem) or "N/A"

        -- demand numerico: prefere data-demand (1-5), senao converte texto
        local rawDem = chunk:match('data%-demand="(%d+)"') or chunk:match("data%-demand='(%d+)'")
        item.demandNum = tonumber(rawDem) or 0

        -- trend
        local tr   = chunk:match('title="Trend">([^<]+)<')
        item.trend = tr and decodeHtml(tr) or "N/A"

        if item.image ~= "" or item.name ~= "Unknown" then
            table.insert(items, item)
        end
    end
    return items
end

-- ══════════════════════════════════════════════
--  ORDENACAO
-- ══════════════════════════════════════════════
local currentSort = "default"

local function sortItems(items)
    if currentSort == "default" then return items end
    local sorted = {}
    for i, v in ipairs(items) do sorted[i] = v end
    if currentSort == "name" then
        table.sort(sorted, function(a,b) return a.name:lower() < b.name:lower() end)
    elseif currentSort == "value" then
        table.sort(sorted, function(a,b) return (a.valueNum or 0) > (b.valueNum or 0) end)
    elseif currentSort == "rarity" then
        table.sort(sorted, function(a,b)
            return demandToScore(a.demand, a.demandNum) > demandToScore(b.demand, b.demandNum)
        end)
    elseif currentSort == "recent" then
        table.sort(sorted, function(a,b) return (a.id or 0) > (b.id or 0) end)
    end
    return sorted
end

-- ══════════════════════════════════════════════
--  SISTEMA DE IMAGEM (HAS_FS-based)
--
--  FIX [1]: DL_QUEUED rastreia URLs ja contadas → DL_TOTAL nao sobe ao trocar categoria
--  FIX [2]: HAS_FS (nao IS_XENO) controla se usa download ou URL direta
--           Delta, Xeno, Wave, etc. → todos com FS usam download (mais confiavel)
--           Executores sem FS → URL direta como fallback
-- ══════════════════════════════════════════════
local ASSET_FOLDER  = "ValueCheck/assets"
local IMAGE_CACHE   = {}   -- url → rbxasset:// ou url direta
local PENDING_DL    = {}   -- downloads em progresso ativo
local DL_QUEUED     = {}   -- urls ja contadas em DL_TOTAL (evita duplicar contador)
local DL_QUEUE      = {}
local DL_ACTIVE     = 0
local DL_MAX        = 4
local DL_TOTAL      = 0
local DL_DONE       = 0

local HAS_FS = (makefolder ~= nil and writefile ~= nil
             and isfile    ~= nil and getcustomasset ~= nil
             and isfolder  ~= nil)

local HAS_LISTFILES = (listfiles ~= nil)

local function ensureFolders()
    if not HAS_FS then return end
    pcall(function()
        if not isfolder("ValueCheck") then makefolder("ValueCheck") end
        if not isfolder(ASSET_FOLDER) then makefolder(ASSET_FOLDER) end
    end)
end

local function urlToFilename(url)
    local fn = url:match("/([^/?#]+)$") or "img"
    fn = fn:gsub("[^%w%.%-_]","_")
    if not fn:match("%.%a+$") then fn = fn .. ".png" end
    return fn
end

-- Callbacks aguardando imagem ficar pronta
local imageCallbacks = {}

local function onImageReady(url, fn)
    if IMAGE_CACHE[url] then fn(IMAGE_CACHE[url]); return end
    if not imageCallbacks[url] then imageCallbacks[url] = {} end
    table.insert(imageCallbacks[url], fn)
end

local function fireImageCallbacks(url)
    local src = IMAGE_CACHE[url]
    if not src then return end
    local cbs = imageCallbacks[url]
    if not cbs then return end
    imageCallbacks[url] = nil
    for _, fn in ipairs(cbs) do pcall(fn, src) end
end

-- Download binario → writefile → getcustomasset
local function downloadImage(url, cb)
    if PENDING_DL[url] then if cb then cb(nil) end; return end
    PENDING_DL[url] = true
    DL_ACTIVE = DL_ACTIVE + 1
    task.spawn(function()
        local result = nil
        local body = httpGet(url)
        if body and #body > 100 then
            local fname = urlToFilename(url)
            local path  = ASSET_FOLDER .. "/" .. fname
            local ok = pcall(writefile, path, body)
            if ok then
                local ok2, asset = pcall(getcustomasset, path)
                if ok2 and asset and asset ~= "" then
                    IMAGE_CACHE[url] = asset
                    result = asset
                end
            end
        end
        DL_ACTIVE     = DL_ACTIVE - 1
        DL_DONE       = DL_DONE + 1
        PENDING_DL[url] = nil
        if cb then cb(result) end
        if #DL_QUEUE > 0 then
            local nxt = table.remove(DL_QUEUE, 1)
            nxt()
        end
    end)
end

-- Enfileira download sem duplicar DL_TOTAL (FIX [1])
local function queueDownload(url, onDone)
    if DL_QUEUED[url] then return end  -- ja contada: nao incrementa DL_TOTAL novamente
    DL_QUEUED[url] = true
    DL_TOTAL = DL_TOTAL + 1
    local function doIt()
        downloadImage(url, function(asset)
            if asset and onDone then onDone(asset) end
        end)
    end
    if DL_ACTIVE < DL_MAX then
        doIt()
    else
        table.insert(DL_QUEUE, doIt)
    end
end

-- Resolve imagem: download (HAS_FS) ou URL direta (FIX [2])
-- onLoaded → callback quando imagem ficou pronta
-- onFailed → callback quando nao ha imagem valida
local function resolveImage(url, imgLabel, onLoaded, onFailed)
    if not url or url == "" then
        if onFailed then onFailed() end
        return
    end

    -- Ja no cache → aplica direto
    if IMAGE_CACHE[url] then
        imgLabel.Image = IMAGE_CACHE[url]
        if onLoaded then onLoaded() end
        return
    end

    -- Registra callback para quando o download terminar
    onImageReady(url, function(src)
        if imgLabel and imgLabel.Parent then
            imgLabel.Image = src
            if onLoaded then onLoaded() end
        end
    end)

    -- Ja em progresso? apenas aguarda callback
    if PENDING_DL[url] or DL_QUEUED[url] then return end

    if HAS_FS then
        -- Download local (funciona em Delta, Xeno, Wave, Fluxus, Synapse, KRNL...)
        queueDownload(url, function()
            fireImageCallbacks(url)
        end)
    else
        -- Sem FS: URL direta (executes sem filesystem)
        IMAGE_CACHE[url] = url
        imgLabel.Image   = url
        fireImageCallbacks(url)
        -- onLoaded sera chamado pelo fireImageCallbacks via callback registrado acima
    end
end

-- ══════════════════════════════════════════════
--  PRE-CACHE LOCAL (listfiles para checar tudo de uma vez)
-- ══════════════════════════════════════════════
local function preCacheLocalAssets(allItems)
    if not HAS_FS then return end
    local cachedSet = {}
    if HAS_LISTFILES then
        local ok, files = pcall(listfiles, ASSET_FOLDER)
        if ok and files then
            for _, fpath in ipairs(files) do
                local fname = fpath:match("[^/\\]+$") or fpath
                cachedSet[fname] = fpath
            end
        end
    end
    for _, item in ipairs(allItems) do
        local url = item.image
        if url and url ~= "" and not IMAGE_CACHE[url] then
            local fname = urlToFilename(url)
            if HAS_LISTFILES then
                if cachedSet[fname] then
                    local ok2, asset = pcall(getcustomasset, ASSET_FOLDER .. "/" .. fname)
                    if ok2 and asset and asset ~= "" then
                        IMAGE_CACHE[url] = asset
                        DL_QUEUED[url]   = true  -- ja tem localmente, nao precisa baixar
                    end
                end
            else
                local path = ASSET_FOLDER .. "/" .. fname
                local okF, exists = pcall(isfile, path)
                if okF and exists then
                    local ok2, asset = pcall(getcustomasset, path)
                    if ok2 and asset and asset ~= "" then
                        IMAGE_CACHE[url] = asset
                        DL_QUEUED[url]   = true
                    end
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  DADOS
-- ══════════════════════════════════════════════
local allData    = {}
local currentCat = { label = "ALL", type = "all" }

local function getAllItems()
    local merged = {}
    for _, catItems in pairs(allData) do
        for _, item in ipairs(catItems) do table.insert(merged, item) end
    end
    return merged
end

local function getCurrentItems()
    if currentCat.type == "all" then
        return getAllItems()
    end
    return allData[currentCat.label] or {}
end

-- ══════════════════════════════════════════════
--  CORES
-- ══════════════════════════════════════════════
local C = {
    bg        = Color3.fromRGB(10,  10,  16),
    sidebar   = Color3.fromRGB(16,  16,  26),
    card      = Color3.fromRGB(24,  24,  38),
    cardHover = Color3.fromRGB(32,  32,  50),
    accent    = Color3.fromRGB(100, 100, 255),
    accentDim = Color3.fromRGB(35,  35,  90),
    text      = Color3.fromRGB(230, 230, 245),
    textMuted = Color3.fromRGB(110, 110, 140),
    green     = Color3.fromRGB(52,  211, 153),
    red       = Color3.fromRGB(251, 100, 120),
    yellow    = Color3.fromRGB(251, 191,  36),
    border    = Color3.fromRGB(38,  38,  60),
    white     = Color3.fromRGB(255, 255, 255),
    titleBar  = Color3.fromRGB(14,  14,  22),
    imgBg     = Color3.fromRGB(18,  18,  30),
    sortBg    = Color3.fromRGB(22,  22,  36),
}

local function demandColor(d)
    local dl = (d or ""):lower()
    if     dl:find("very high") then return C.green
    elseif dl:find("high")      then return Color3.fromRGB(110,231,183)
    elseif dl:find("very low")  then return C.red
    elseif dl:find("low")       then return Color3.fromRGB(253,164,175)
    elseif dl:find("normal") or dl:find("moderate") then return C.yellow
    else return C.textMuted end
end

local function trendInfo(t)
    local tl = (t or ""):lower()
    if     tl:find("ris") or tl:find("up")                       then return "^ ", C.green
    elseif tl:find("drop") or tl:find("down") or tl:find("fall") then return "v ", C.red
    else return "- ", C.textMuted end
end

-- ══════════════════════════════════════════════
--  DESTRUIR GUI ANTIGA
-- ══════════════════════════════════════════════
if PlayerGui:FindFirstChild("_STK_Checker") then
    PlayerGui._STK_Checker:Destroy()
end

-- ══════════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "_STK_Checker"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

-- ══════════════════════════════════════════════
--  JANELA
-- ══════════════════════════════════════════════
local WIN_W, WIN_H = 960, 620

local Win = Instance.new("Frame")
Win.Name             = "Win"
Win.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Win.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel  = 0
Win.ClipsDescendants = true
Win.Parent           = ScreenGui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 14)
local WS = Instance.new("UIStroke", Win); WS.Color = C.border; WS.Thickness = 1.5

-- ─── Barra de titulo ──────────────────────────
local TBar = Instance.new("Frame")
TBar.Name             = "TitleBar"
TBar.Size             = UDim2.new(1, 0, 0, 52)
TBar.BackgroundColor3 = C.titleBar
TBar.BorderSizePixel  = 0
TBar.ZIndex           = 5
TBar.Parent           = Win

local TBarLine = Instance.new("Frame", TBar)
TBarLine.Size             = UDim2.new(1, 0, 0, 1)
TBarLine.Position         = UDim2.new(0, 0, 1, -1)
TBarLine.BackgroundColor3 = C.border
TBarLine.BorderSizePixel  = 0
TBarLine.ZIndex           = 6

local TitleLbl = Instance.new("TextLabel", TBar)
TitleLbl.Size                   = UDim2.new(1, -250, 1, -16)
TitleLbl.Position               = UDim2.new(0, 16, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                   = "STK TRADINGS  -  VALUE CHECKER"
TitleLbl.TextColor3             = C.text
TitleLbl.TextSize               = 14
TitleLbl.Font                   = Enum.Font.GothamBold
TitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
TitleLbl.ZIndex                 = 6

local SubLbl = Instance.new("TextLabel", TBar)
SubLbl.Size                   = UDim2.new(0, 500, 0, 13)
SubLbl.Position               = UDim2.new(0, 16, 1, -18)
SubLbl.BackgroundTransparency = 1
SubLbl.Text                   = "stktradings.com  -  " .. execName .. (HAS_FS and " [FS]" or " [URL]")
SubLbl.TextColor3             = C.textMuted
SubLbl.TextSize               = 9
SubLbl.Font                   = Enum.Font.Gotham
SubLbl.TextXAlignment         = Enum.TextXAlignment.Left
SubLbl.ZIndex                 = 6

-- Indicador de download (mostra quando HAS_FS e tem downloads pendentes)
local DlStatusLbl = Instance.new("TextLabel", TBar)
DlStatusLbl.Size                   = UDim2.new(0, 380, 0, 13)
DlStatusLbl.Position               = UDim2.new(0, 16, 1, -18)
DlStatusLbl.BackgroundTransparency = 1
DlStatusLbl.Text                   = ""
DlStatusLbl.TextColor3             = C.yellow
DlStatusLbl.TextSize               = 9
DlStatusLbl.Font                   = Enum.Font.GothamBold
DlStatusLbl.TextXAlignment         = Enum.TextXAlignment.Left
DlStatusLbl.ZIndex                 = 7
DlStatusLbl.Visible                = false

local blinkConn = nil
local function startDownloadIndicator()
    if not HAS_FS then return end
    if blinkConn then return end  -- ja rodando
    DlStatusLbl.Visible = true
    SubLbl.Visible      = false
    local blink = false
    blinkConn = RunService.Heartbeat:Connect(function()
        local pending = DL_TOTAL - DL_DONE
        if pending <= 0 and DL_TOTAL > 0 then
            DlStatusLbl.Text    = "Assets OK: " .. DL_DONE .. " em cache"
            task.delay(1.5, function()
                DlStatusLbl.Visible = false
                SubLbl.Visible      = true
            end)
            blinkConn:Disconnect(); blinkConn = nil
            return
        end
        if pending > 0 then
            blink = not blink
            DlStatusLbl.Text = blink
                and ("Baixando assets: " .. DL_DONE .. " / " .. DL_TOTAL .. " ...")
                or  ("Baixando assets: " .. DL_DONE .. " / " .. DL_TOTAL)
        end
    end)
end

-- Botoes da barra de titulo
local function winBtn(col, lbl, xOff)
    local b = Instance.new("TextButton", TBar)
    b.Size             = UDim2.new(0, 26, 0, 26)
    b.Position         = UDim2.new(1, xOff, 0.5, -13)
    b.BackgroundColor3 = col
    b.Text             = lbl
    b.TextColor3       = C.white
    b.TextSize         = 11
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.ZIndex           = 7
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0.3}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0}):Play() end)
    return b
end

local CloseBtn   = winBtn(Color3.fromRGB(255, 90, 85),  "X", -44)
local MinBtn     = winBtn(Color3.fromRGB(255,185, 40),  "-", -78)
local RefreshBtn = winBtn(Color3.fromRGB(60,  60, 90),  "R", -112)

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
            Win.Position = UDim2.new(ws.X.Scale, ws.X.Offset+d.X, ws.Y.Scale, ws.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
end

-- ══════════════════════════════════════════════
--  BODY
-- ══════════════════════════════════════════════
local Body = Instance.new("Frame", Win)
Body.Name                   = "Body"
Body.Size                   = UDim2.new(1, 0, 1, -52)
Body.Position               = UDim2.new(0, 0, 0, 52)
Body.BackgroundTransparency = 1
Body.ClipsDescendants       = true

-- ══════════════════════════════════════════════
--  SIDEBAR
-- ══════════════════════════════════════════════
local SB_W = 172

local Sidebar = Instance.new("ScrollingFrame", Body)
Sidebar.Name                = "Sidebar"
Sidebar.Size                = UDim2.new(0, SB_W, 1, 0)
Sidebar.BackgroundColor3    = C.sidebar
Sidebar.BorderSizePixel     = 0
Sidebar.ScrollBarThickness  = 0
Sidebar.CanvasSize          = UDim2.new(0, 0, 0, 0)
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y

local SbPad = Instance.new("UIPadding", Sidebar)
SbPad.PaddingLeft   = UDim.new(0, 8)
SbPad.PaddingRight  = UDim.new(0, 8)
SbPad.PaddingTop    = UDim.new(0, 12)
SbPad.PaddingBottom = UDim.new(0, 12)

local SbLayout = Instance.new("UIListLayout", Sidebar)
SbLayout.Padding             = UDim.new(0, 3)
SbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local SbTitle = Instance.new("TextLabel", Sidebar)
SbTitle.Size                   = UDim2.new(1, 0, 0, 22)
SbTitle.BackgroundTransparency = 1
SbTitle.Text                   = "SECOES"
SbTitle.TextColor3             = C.textMuted
SbTitle.TextSize               = 9
SbTitle.Font                   = Enum.Font.GothamBold
SbTitle.TextXAlignment         = Enum.TextXAlignment.Left
SbTitle.LayoutOrder            = -2
local SbTP = Instance.new("UIPadding", SbTitle); SbTP.PaddingLeft = UDim.new(0,6)

local SbDiv = Instance.new("Frame", Sidebar)
SbDiv.Size             = UDim2.new(1, 0, 0, 1)
SbDiv.BackgroundColor3 = C.border
SbDiv.BorderSizePixel  = 0
SbDiv.LayoutOrder      = -1

-- ══════════════════════════════════════════════
--  PAINEL PRINCIPAL
-- ══════════════════════════════════════════════
local PANEL_X = SB_W + 6

local Panel = Instance.new("Frame", Body)
Panel.Name                   = "Panel"
Panel.Size                   = UDim2.new(1, -(PANEL_X + 4), 1, -6)
Panel.Position               = UDim2.new(0, PANEL_X, 0, 3)
Panel.BackgroundTransparency = 1
Panel.ClipsDescendants       = false

-- ─── Barra de busca ─────────────────────────
local SearchWrap = Instance.new("Frame", Panel)
SearchWrap.Size             = UDim2.new(1, 0, 0, 36)
SearchWrap.BackgroundColor3 = C.card
SearchWrap.BorderSizePixel  = 0
Instance.new("UICorner", SearchWrap).CornerRadius = UDim.new(0, 9)
local SWS = Instance.new("UIStroke", SearchWrap); SWS.Color = C.border; SWS.Thickness = 1

local SearchIconLbl = Instance.new("TextLabel", SearchWrap)
SearchIconLbl.Size                   = UDim2.new(0, 34, 1, 0)
SearchIconLbl.BackgroundTransparency = 1
SearchIconLbl.Text                   = "?"
SearchIconLbl.TextSize               = 13
SearchIconLbl.Font                   = Enum.Font.Gotham
SearchIconLbl.TextXAlignment         = Enum.TextXAlignment.Center

local SearchBox = Instance.new("TextBox", SearchWrap)
SearchBox.Size                   = UDim2.new(1, -40, 1, 0)
SearchBox.Position               = UDim2.new(0, 36, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText        = "Buscar item..."
SearchBox.PlaceholderColor3      = C.textMuted
SearchBox.Text                   = ""
SearchBox.TextColor3             = C.text
SearchBox.TextSize               = 13
SearchBox.Font                   = Enum.Font.Gotham
SearchBox.TextXAlignment         = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus       = false

-- ─── Info bar (categoria + contagem) ────────
local InfoBar = Instance.new("Frame", Panel)
InfoBar.Size                   = UDim2.new(1, 0, 0, 22)
InfoBar.Position               = UDim2.new(0, 0, 0, 42)
InfoBar.BackgroundTransparency = 1

local CatNameLbl = Instance.new("TextLabel", InfoBar)
CatNameLbl.Size                   = UDim2.new(0.55, 0, 1, 0)
CatNameLbl.BackgroundTransparency = 1
CatNameLbl.TextColor3             = C.accent
CatNameLbl.TextSize               = 11
CatNameLbl.Font                   = Enum.Font.GothamBold
CatNameLbl.TextXAlignment         = Enum.TextXAlignment.Left

local CountLbl = Instance.new("TextLabel", InfoBar)
CountLbl.Size                   = UDim2.new(0.45, 0, 1, 0)
CountLbl.Position               = UDim2.new(0.55, 0, 0, 0)
CountLbl.BackgroundTransparency = 1
CountLbl.TextColor3             = C.textMuted
CountLbl.TextSize               = 10
CountLbl.Font                   = Enum.Font.Gotham
CountLbl.TextXAlignment         = Enum.TextXAlignment.Right

-- ─── Sort Bar ───────────────────────────────
--  Botoes: DEFAULT | RECENT | VALUE | RARITY | NAME
local SORT_Y = 68
local SORT_H = 24

local SortBar = Instance.new("Frame", Panel)
SortBar.Name                   = "SortBar"
SortBar.Size                   = UDim2.new(1, 0, 0, SORT_H)
SortBar.Position               = UDim2.new(0, 0, 0, SORT_Y)
SortBar.BackgroundTransparency = 1

local SortLayout = Instance.new("UIListLayout", SortBar)
SortLayout.FillDirection       = Enum.FillDirection.Horizontal
SortLayout.Padding             = UDim.new(0, 5)
SortLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
SortLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

local SORT_DEFS = {
    { key = "default", label = "DEFAULT", tip = "Ordem original" },
    { key = "recent",  label = "RECENT",  tip = "Mais novos primeiro" },
    { key = "value",   label = "VALUE",   tip = "Maior valor primeiro" },
    { key = "rarity",  label = "RARITY",  tip = "Maior demanda primeiro" },
    { key = "name",    label = "NAME",    tip = "A-Z" },
}

-- forward declaration para callbacks dos botoes
local renderItems

local sortBtns = {}

local function updateSortBtns()
    for _, sb in ipairs(sortBtns) do
        local active = sb.key == currentSort
        TweenService:Create(sb.btn, TweenInfo.new(0.12), {
            BackgroundColor3 = active and C.accent or C.sortBg,
        }):Play()
        sb.lbl.TextColor3 = active and C.white or C.textMuted
    end
end

for _, sd in ipairs(SORT_DEFS) do
    local Wrap = Instance.new("Frame", SortBar)
    Wrap.Size             = UDim2.new(0, 72, 0, SORT_H)
    Wrap.BackgroundColor3 = C.sortBg
    Wrap.BorderSizePixel  = 0
    Instance.new("UICorner", Wrap).CornerRadius = UDim.new(0, 6)

    local Btn = Instance.new("TextButton", Wrap)
    Btn.Size             = UDim2.new(1, 0, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text             = ""
    Btn.BorderSizePixel  = 0
    Btn.AutoButtonColor  = false

    local Lbl = Instance.new("TextLabel", Wrap)
    Lbl.Size                   = UDim2.new(1, 0, 1, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text                   = sd.label
    Lbl.TextColor3             = C.textMuted
    Lbl.TextSize               = 9
    Lbl.Font                   = Enum.Font.GothamBold
    Lbl.TextXAlignment         = Enum.TextXAlignment.Center

    table.insert(sortBtns, { key = sd.key, btn = Btn, wrap = Wrap, lbl = Lbl })

    local sk = sd.key
    Btn.MouseButton1Click:Connect(function()
        if currentSort == sk then return end
        currentSort = sk
        updateSortBtns()
        if renderItems then
            renderItems(getCurrentItems(), SearchBox.Text)
        end
    end)
    Btn.MouseEnter:Connect(function()
        if currentSort ~= sk then
            TweenService:Create(Wrap,TweenInfo.new(0.1),{BackgroundColor3=C.card}):Play()
        end
    end)
    Btn.MouseLeave:Connect(function()
        if currentSort ~= sk then
            TweenService:Create(Wrap,TweenInfo.new(0.1),{BackgroundColor3=C.sortBg}):Play()
        end
    end)
end

updateSortBtns()

-- ─── Divider ────────────────────────────────
local DIV_Y    = SORT_Y + SORT_H + 4
local SCROLL_Y = DIV_Y + 5

local Divider = Instance.new("Frame", Panel)
Divider.Size             = UDim2.new(1, 0, 0, 1)
Divider.Position         = UDim2.new(0, 0, 0, DIV_Y)
Divider.BackgroundColor3 = C.border
Divider.BorderSizePixel  = 0

-- ══════════════════════════════════════════════
--  SCROLL DE ITENS
-- ══════════════════════════════════════════════
local ItemScroll = Instance.new("ScrollingFrame", Panel)
ItemScroll.Name                   = "ItemScroll"
ItemScroll.Size                   = UDim2.new(1, 0, 1, -SCROLL_Y)
ItemScroll.Position               = UDim2.new(0, 0, 0, SCROLL_Y)
ItemScroll.BackgroundTransparency = 1
ItemScroll.ScrollBarThickness     = 5
ItemScroll.ScrollBarImageColor3   = C.accent
ItemScroll.BorderSizePixel        = 0
ItemScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
ItemScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y

local ItemGrid = Instance.new("UIGridLayout", ItemScroll)
ItemGrid.CellSize            = UDim2.new(0, 147, 0, 208)
ItemGrid.CellPadding         = UDim2.new(0, 8,   0, 8)
ItemGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
ItemGrid.SortOrder           = Enum.SortOrder.LayoutOrder

local GridPad = Instance.new("UIPadding", ItemScroll)
GridPad.PaddingTop    = UDim.new(0, 4)
GridPad.PaddingLeft   = UDim.new(0, 4)
GridPad.PaddingRight  = UDim.new(0, 4)
GridPad.PaddingBottom = UDim.new(0, 10)

-- ══════════════════════════════════════════════
--  OVERLAY DE LOADING
-- ══════════════════════════════════════════════
local LoadBG = Instance.new("Frame", Win)
LoadBG.Name                   = "LoadBG"
LoadBG.Size                   = UDim2.new(1, 0, 1, 0)
LoadBG.BackgroundColor3       = C.bg
LoadBG.BackgroundTransparency = 0.05
LoadBG.ZIndex                 = 30
LoadBG.Visible                = true

local LoadCard = Instance.new("Frame", LoadBG)
LoadCard.Size             = UDim2.new(0, 340, 0, 155)
LoadCard.Position         = UDim2.new(0.5, -170, 0.5, -77)
LoadCard.BackgroundColor3 = C.card
LoadCard.BorderSizePixel  = 0
LoadCard.ZIndex           = 31
Instance.new("UICorner", LoadCard).CornerRadius = UDim.new(0, 14)
local LCS = Instance.new("UIStroke", LoadCard); LCS.Color = C.border

local LoadTitleLbl = Instance.new("TextLabel", LoadCard)
LoadTitleLbl.Size                   = UDim2.new(1, -20, 0, 36)
LoadTitleLbl.Position               = UDim2.new(0, 10, 0, 16)
LoadTitleLbl.BackgroundTransparency = 1
LoadTitleLbl.Text                   = "STK  -  Carregando dados..."
LoadTitleLbl.TextColor3             = C.text
LoadTitleLbl.TextSize               = 16
LoadTitleLbl.Font                   = Enum.Font.GothamBold
LoadTitleLbl.ZIndex                 = 32

local LoadStatusLbl = Instance.new("TextLabel", LoadCard)
LoadStatusLbl.Size                   = UDim2.new(1, -20, 0, 20)
LoadStatusLbl.Position               = UDim2.new(0, 10, 0, 56)
LoadStatusLbl.BackgroundTransparency = 1
LoadStatusLbl.Text                   = "Iniciando conexao..."
LoadStatusLbl.TextColor3             = C.textMuted
LoadStatusLbl.TextSize               = 12
LoadStatusLbl.Font                   = Enum.Font.Gotham
LoadStatusLbl.ZIndex                 = 32

local ProgBg = Instance.new("Frame", LoadCard)
ProgBg.Size             = UDim2.new(1, -20, 0, 8)
ProgBg.Position         = UDim2.new(0, 10, 0, 90)
ProgBg.BackgroundColor3 = C.border
ProgBg.BorderSizePixel  = 0
ProgBg.ZIndex           = 32
Instance.new("UICorner", ProgBg).CornerRadius = UDim.new(0, 4)

local ProgFill = Instance.new("Frame", ProgBg)
ProgFill.Size             = UDim2.new(0, 0, 1, 0)
ProgFill.BackgroundColor3 = C.accent
ProgFill.BorderSizePixel  = 0
ProgFill.ZIndex           = 33
Instance.new("UICorner", ProgFill).CornerRadius = UDim.new(0, 4)

local ProgLabel = Instance.new("TextLabel", LoadCard)
ProgLabel.Size                   = UDim2.new(1, -20, 0, 18)
ProgLabel.Position               = UDim2.new(0, 10, 0, 110)
ProgLabel.BackgroundTransparency = 1
ProgLabel.Text                   = "0 / " .. #CATEGORIES .. " categorias"
ProgLabel.TextColor3             = C.textMuted
ProgLabel.TextSize               = 10
ProgLabel.Font                   = Enum.Font.Gotham
ProgLabel.ZIndex                 = 32

-- ══════════════════════════════════════════════
--  POOL DE CARDS
-- ══════════════════════════════════════════════
local cardPool = {}

local function buildCard()
    local Card = Instance.new("Frame")
    Card.BackgroundColor3 = C.card
    Card.BorderSizePixel  = 0
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Name = "Stroke"; Stroke.Color = C.border; Stroke.Thickness = 1

    local ImgBg = Instance.new("Frame", Card)
    ImgBg.Name             = "ImgBg"
    ImgBg.Size             = UDim2.new(1, -10, 0, 120)
    ImgBg.Position         = UDim2.new(0, 5, 0, 5)
    ImgBg.BackgroundColor3 = C.imgBg
    ImgBg.BorderSizePixel  = 0
    ImgBg.ZIndex           = 2
    Instance.new("UICorner", ImgBg).CornerRadius = UDim.new(0, 8)

    local Img = Instance.new("ImageLabel", ImgBg)
    Img.Name                   = "Img"
    Img.Size                   = UDim2.new(1, 0, 1, 0)
    Img.BackgroundTransparency = 1
    Img.Image                  = ""
    Img.ScaleType              = Enum.ScaleType.Fit
    Img.BorderSizePixel        = 0
    Img.ZIndex                 = 3

    -- Letra inicial: exibida quando imagem nao carregou
    local FallLbl = Instance.new("TextLabel", ImgBg)
    FallLbl.Name                   = "FallLbl"
    FallLbl.Size                   = UDim2.new(1, 0, 1, 0)
    FallLbl.BackgroundTransparency = 1
    FallLbl.TextColor3             = C.textMuted
    FallLbl.TextSize               = 34
    FallLbl.Font                   = Enum.Font.GothamBold
    FallLbl.ZIndex                 = 4

    -- FIX [3]: NameLbl so aparece quando imagem NAO carregou
    --          Quando imagem existe (ja na propria imagem do item) → oculto
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
    NameLbl.ZIndex             = 5

    local ValBg = Instance.new("Frame", Card)
    ValBg.Name             = "ValBg"
    ValBg.Size             = UDim2.new(1, -10, 0, 24)
    ValBg.Position         = UDim2.new(0, 5, 0, 160)
    ValBg.BackgroundColor3 = C.accentDim
    ValBg.BorderSizePixel  = 0
    ValBg.ZIndex           = 5
    Instance.new("UICorner", ValBg).CornerRadius = UDim.new(0, 7)

    local ValLbl = Instance.new("TextLabel", ValBg)
    ValLbl.Name                   = "ValLbl"
    ValLbl.Size                   = UDim2.new(1, 0, 1, 0)
    ValLbl.BackgroundTransparency = 1
    ValLbl.TextColor3             = C.accent
    ValLbl.TextSize               = 13
    ValLbl.Font                   = Enum.Font.GothamBold
    ValLbl.TextXAlignment         = Enum.TextXAlignment.Center
    ValLbl.ZIndex                 = 6

    local DmTrBar = Instance.new("Frame", Card)
    DmTrBar.Name               = "DmTrBar"
    DmTrBar.Size               = UDim2.new(1, -10, 0, 18)
    DmTrBar.Position           = UDim2.new(0, 5, 0, 186)
    DmTrBar.BackgroundTransparency = 1
    DmTrBar.ZIndex             = 5

    local DemLbl = Instance.new("TextLabel", DmTrBar)
    DemLbl.Name               = "DemLbl"
    DemLbl.Size               = UDim2.new(0.55, 0, 1, 0)
    DemLbl.BackgroundTransparency = 1
    DemLbl.TextSize           = 9
    DemLbl.Font               = Enum.Font.GothamSemibold
    DemLbl.TextXAlignment     = Enum.TextXAlignment.Left
    DemLbl.ZIndex             = 6

    local TrLbl = Instance.new("TextLabel", DmTrBar)
    TrLbl.Name               = "TrLbl"
    TrLbl.Size               = UDim2.new(0.45, 0, 1, 0)
    TrLbl.Position           = UDim2.new(0.55, 0, 0, 0)
    TrLbl.BackgroundTransparency = 1
    TrLbl.TextSize           = 9
    TrLbl.Font               = Enum.Font.GothamSemibold
    TrLbl.TextXAlignment     = Enum.TextXAlignment.Right
    TrLbl.ZIndex             = 6

    Card.MouseEnter:Connect(function()
        TweenService:Create(Card,   TweenInfo.new(0.12), {BackgroundColor3=C.cardHover}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.12), {Color=C.accent, Thickness=1.5}):Play()
    end)
    Card.MouseLeave:Connect(function()
        TweenService:Create(Card,   TweenInfo.new(0.12), {BackgroundColor3=C.card}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.12), {Color=C.border, Thickness=1}):Play()
    end)

    return Card
end

-- ══════════════════════════════════════════════
--  RENDER (pool reusavel + FIX [1] + FIX [3])
-- ══════════════════════════════════════════════
renderItems = function(items, filter)
    filter = (filter or ""):lower():match("^%s*(.-)%s*$") or ""

    -- Aplica ordenacao atual (FIX [4])
    local sorted = sortItems(items)

    -- Oculta todos os cards do pool
    for _, c in ipairs(cardPool) do
        c.Parent  = nil
        c.Visible = false
    end

    -- Conta quantos passam no filtro
    local needed = 0
    for _, item in ipairs(sorted) do
        if filter == "" or item.name:lower():find(filter, 1, true) then
            needed = needed + 1
        end
    end

    while #cardPool < needed do
        table.insert(cardPool, buildCard())
    end

    local count, poolIdx = 0, 0

    for _, item in ipairs(sorted) do
        if filter ~= "" and not item.name:lower():find(filter, 1, true) then continue end

        count   = count + 1
        poolIdx = poolIdx + 1
        local Card = cardPool[poolIdx]

        local Img     = Card.ImgBg.Img
        local FallLbl = Card.ImgBg.FallLbl
        local NameLbl = Card.NameLbl
        local ValLbl  = Card.ValBg.ValLbl
        local DemLbl  = Card.DmTrBar.DemLbl
        local TrLbl   = Card.DmTrBar.TrLbl

        NameLbl.Text      = item.name
        ValLbl.Text       = item.value
        DemLbl.Text       = item.demand
        DemLbl.TextColor3 = demandColor(item.demand)
        local tIcon, tColor = trendInfo(item.trend)
        TrLbl.Text        = tIcon .. item.trend
        TrLbl.TextColor3  = tColor

        Card.BackgroundColor3 = C.card
        Card.Stroke.Color     = C.border
        Card.Stroke.Thickness = 1
        Card.LayoutOrder      = poolIdx

        -- FIX [3]: helpers para mostrar/ocultar NameLbl
        local function onImgLoaded()
            if Img and Img.Parent then
                FallLbl.Visible = false
                NameLbl.Visible = false  -- imagem tem nome proprio
                Card.ImgBg.BackgroundTransparency = 1
            end
        end

        local function showFallback()
            Img.Image      = ""
            FallLbl.Text   = item.name:sub(1,1):upper()
            FallLbl.Visible = true
            NameLbl.Visible = true  -- sem imagem → mostra nome
            Card.ImgBg.BackgroundColor3       = C.imgBg
            Card.ImgBg.BackgroundTransparency = 0
        end

        -- Ja no cache?
        local cached = IMAGE_CACHE[item.image]
        if cached and cached ~= "" then
            Img.Image = cached
            FallLbl.Visible = false
            NameLbl.Visible = false
            Card.ImgBg.BackgroundTransparency = 1
        else
            showFallback()
            if item.image and item.image ~= "" then
                -- FIX [1]: resolveImage usa DL_QUEUED → nao duplica DL_TOTAL ao trocar aba
                resolveImage(item.image, Img, onImgLoaded, nil)
            end
        end

        Card.Visible = true
        Card.Parent  = ItemScroll
    end

    CatNameLbl.Text = currentCat.label
    CountLbl.Text   = count .. " item" .. (count ~= 1 and "s" or "")
                    .. (filter ~= "" and ("  \"" .. filter .. "\"") or "")
end

-- ══════════════════════════════════════════════
--  ABAS DE CATEGORIA
-- ══════════════════════════════════════════════
local tabList = {}

local function setActiveTab(cat)
    currentCat = cat
    for _, t in ipairs(tabList) do
        local active = t.cat.label == cat.label
        TweenService:Create(t.btn, TweenInfo.new(0.18), {
            BackgroundColor3 = active and C.accent or C.sidebar,
        }):Play()
        t.btn.TextColor3 = active and C.white or C.textMuted
    end
    ItemScroll.CanvasPosition = Vector2.new(0, 0)
    renderItems(getCurrentItems(), SearchBox.Text)
end

local function makeTabBtn(label, order)
    local Btn = Instance.new("TextButton", Sidebar)
    Btn.Size             = UDim2.new(1, 0, 0, 36)
    Btn.BackgroundColor3 = C.sidebar
    Btn.Text             = label
    Btn.TextColor3       = C.textMuted
    Btn.TextSize         = 10
    Btn.Font             = Enum.Font.GothamSemibold
    Btn.BorderSizePixel  = 0
    Btn.TextXAlignment   = Enum.TextXAlignment.Left
    Btn.AutoButtonColor  = false
    Btn.LayoutOrder      = order
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local P = Instance.new("UIPadding", Btn); P.PaddingLeft = UDim.new(0, 10)
    return Btn
end

local allCatEntry = { label = "ALL", type = "all" }
local allBtn = makeTabBtn("ALL", 0)
table.insert(tabList, { btn = allBtn, cat = allCatEntry })
allBtn.MouseButton1Click:Connect(function() setActiveTab(allCatEntry) end)
allBtn.MouseEnter:Connect(function()
    if currentCat.label ~= "ALL" then TweenService:Create(allBtn,TweenInfo.new(0.1),{BackgroundColor3=C.card}):Play() end
end)
allBtn.MouseLeave:Connect(function()
    if currentCat.label ~= "ALL" then TweenService:Create(allBtn,TweenInfo.new(0.1),{BackgroundColor3=C.sidebar}):Play() end
end)

for i, cat in ipairs(CATEGORIES) do
    local Btn = makeTabBtn(cat.label, i)
    table.insert(tabList, { btn = Btn, cat = cat })
    local mc = cat
    Btn.MouseButton1Click:Connect(function() setActiveTab(mc) end)
    Btn.MouseEnter:Connect(function()
        if currentCat.label ~= mc.label then TweenService:Create(Btn,TweenInfo.new(0.1),{BackgroundColor3=C.card}):Play() end
    end)
    Btn.MouseLeave:Connect(function()
        if currentCat.label ~= mc.label then TweenService:Create(Btn,TweenInfo.new(0.1),{BackgroundColor3=C.sidebar}):Play() end
    end)
end

-- ══════════════════════════════════════════════
--  BUSCA (debounce 180ms)
-- ══════════════════════════════════════════════
local searchTask = nil
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if searchTask then task.cancel(searchTask) end
    searchTask = task.delay(0.18, function()
        renderItems(getCurrentItems(), SearchBox.Text)
    end)
end)

-- ══════════════════════════════════════════════
--  CONTROLES DA JANELA
-- ══════════════════════════════════════════════
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
        Size     = UDim2.new(0, WIN_W, 0, 0),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, 0),
    }):Play()
    task.delay(0.22, function() ScreenGui:Destroy() end)
end)

-- ══════════════════════════════════════════════
--  CARREGAMENTO PRINCIPAL
-- ══════════════════════════════════════════════
local function fetchAll()
    ensureFolders()

    -- Reset completo de estado
    allData        = {}
    IMAGE_CACHE    = {}
    imageCallbacks = {}
    DL_QUEUED      = {}
    DL_TOTAL       = 0
    DL_DONE        = 0
    DL_ACTIVE      = 0
    DL_QUEUE       = {}
    PENDING_DL     = {}
    if blinkConn then blinkConn:Disconnect(); blinkConn = nil end
    DlStatusLbl.Visible = false
    SubLbl.Visible      = true

    LoadBG.Visible                = true
    LoadBG.BackgroundTransparency = 0.05
    ProgFill.Size                 = UDim2.new(0, 0, 1, 0)

    local total = #CATEGORIES

    for i, cat in ipairs(CATEGORIES) do
        LoadStatusLbl.Text = "Buscando: " .. cat.label .. "..."
        ProgLabel.Text     = (i-1) .. " / " .. total .. " categorias"
        TweenService:Create(ProgFill, TweenInfo.new(0.2), {Size=UDim2.new((i-1)/total,0,1,0)}):Play()
        task.wait(0.04)

        local html = httpGet(cat.url)
        allData[cat.label] = html and parseItems(html) or {}
        if not html then warn("[STK] Falha HTTP: " .. cat.label) end

        TweenService:Create(ProgFill, TweenInfo.new(0.18), {Size=UDim2.new(i/total,0,1,0)}):Play()
        task.wait(0.22)
    end

    -- Pre-cache assets que ja existem localmente
    LoadStatusLbl.Text = "Verificando assets locais..."
    local allItemsList = getAllItems()
    preCacheLocalAssets(allItemsList)

    LoadStatusLbl.Text = "Dados carregados!"
    ProgLabel.Text     = total .. " / " .. total .. " categorias"
    task.wait(0.4)

    TweenService:Create(LoadBG, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
    task.wait(0.3)
    LoadBG.Visible = false

    -- Exibe aba atual
    setActiveTab(currentCat)

    -- Background: baixa assets sem cache (HAS_FS)
    -- FIX [1]: conta cada URL uma unica vez via DL_QUEUED
    if HAS_FS then
        task.spawn(function()
            -- Conta pendentes ainda nao enfileirados por resolveImage
            local pendingUrls = {}
            for _, item in ipairs(allItemsList) do
                local url = item.image
                if url and url ~= "" and not IMAGE_CACHE[url] and not DL_QUEUED[url] then
                    DL_QUEUED[url] = true   -- marca como contada
                    DL_TOTAL       = DL_TOTAL + 1
                    table.insert(pendingUrls, url)
                end
            end

            if #pendingUrls > 0 or DL_TOTAL > DL_DONE then
                startDownloadIndicator()
                for _, url in ipairs(pendingUrls) do
                    if not PENDING_DL[url] then
                        local captUrl = url
                        local function doIt()
                            downloadImage(captUrl, function(asset)
                                if asset then fireImageCallbacks(captUrl) end
                            end)
                        end
                        if DL_ACTIVE < DL_MAX then
                            doIt()
                        else
                            table.insert(DL_QUEUE, doIt)
                        end
                        -- Respira para nao travar UI a cada batch completo
                        if DL_ACTIVE >= DL_MAX then task.wait(0.02) end
                    end
                end
            end
        end)
    end
end

RefreshBtn.MouseButton1Click:Connect(function()
    task.spawn(fetchAll)
end)

-- ══════════════════════════════════════════════
--  INICIAR
-- ══════════════════════════════════════════════
task.spawn(fetchAll)

print(string.format(
    "[STK] Value Checker v3.2 | Executor: %s | Imagens: %s",
    execName,
    HAS_FS and "download local" or "URL direta"
))
