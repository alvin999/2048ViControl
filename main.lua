-- main.lua

-- Tile 類別：代表單一方塊
local Tile = {}
Tile.__index = Tile

function Tile.new(value, gridX, gridY, tile_size, padding)
    local self = setmetatable({}, Tile)
    self.value = value
    self.gridX = gridX
    self.gridY = gridY
    self.tile_size = tile_size
    self.padding = padding
    
    -- 計算實際繪製座標
    self.x = (gridX - 1) * (tile_size + padding) + padding
    self.y = (gridY - 1) * (tile_size + padding) + padding + 50
    self.targetX = self.x
    self.targetY = self.y
    
    -- 狀態標記
    self.is_merging = false -- 標記為合併來源（將被刪除）
    self.is_new = false
    self.scale = 1.0 -- 用於新方塊的彈出動畫
    
    return self
end

function Tile:update(dt)
    -- 平滑移動
    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    local distance = math.sqrt(dx^2 + dy^2)
    
    if distance > 1 then
        local speed = 12 -- 移動速度
        self.x = self.x + dx * speed * dt
        self.y = self.y + dy * speed * dt
    else
        self.x = self.targetX
        self.y = self.targetY
    end
    
    -- 新方塊的彈出動畫
    if self.is_new and self.scale < 1.0 then
        self.scale = math.min(1.0, self.scale + dt * 6)
    elseif self.scale >= 1.0 then
        self.is_new = false
    end
end

function Tile:isMoving()
    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    return math.abs(dx) > 0.5 or math.abs(dy) > 0.5
end

function Tile:draw(morandi_colors)
    local draw_x = self.x
    local draw_y = self.y
    local draw_size = self.tile_size
    
    -- 新方塊的縮放效果
    if self.is_new then
        local offset = (self.tile_size * (1 - self.scale)) / 2
        draw_x = draw_x + offset
        draw_y = draw_y + offset
        draw_size = self.tile_size * self.scale
    end
    
    -- 繪製方塊背景
    if morandi_colors[self.value] then
        love.graphics.setColor(morandi_colors[self.value])
    else
        love.graphics.setColor(morandi_colors[0])
    end
    love.graphics.rectangle("fill", draw_x, draw_y, draw_size, draw_size)
    
    -- 繪製數字
    if self.value ~= 0 then
        if self.value <= 8 then
            love.graphics.setColor(0.3, 0.3, 0.3)
        else
            love.graphics.setColor(0.9, 0.9, 0.9)
        end
        love.graphics.printf(tostring(self.value), draw_x + 3, draw_y + draw_size / 2 - 15, draw_size, "center")
    end
end

-- 遊戲類別
local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)
    
    -- 遊戲板的尺寸
    self.board_size = 4 
    self.tile_size = 100
    self.padding = 10
    self.screen_width = self.board_size * self.tile_size + (self.board_size + 1) * self.padding
    self.screen_height = self.board_size * self.tile_size + (self.board_size + 1) * self.padding + 100
    
    -- 遊戲板的數據（邏輯層）
    self.board = {}
    
    -- 方塊物件陣列（視覺層）
    self.tiles = {}
    
    -- 動畫狀態
    self.is_animating = false
    
    -- 分數
    self.score = 0
    
    -- 遊戲狀態
    self.is_game_over = false
    self.game_won = false
    
    -- 莫蘭迪色系設定
    self.morandi_colors = {
        [0]     = {0.87, 0.83, 0.79},
        [2]     = {0.93, 0.89, 0.86},
        [4]     = {0.91, 0.85, 0.83},
        [8]     = {0.87, 0.79, 0.83},
        [16]    = {0.85, 0.76, 0.78},
        [32]    = {0.79, 0.82, 0.80},
        [64]    = {0.73, 0.76, 0.75},
        [128]   = {0.68, 0.71, 0.73},
        [256]   = {0.62, 0.65, 0.66},
        [512]   = {0.57, 0.60, 0.61},
        [1024]  = {0.52, 0.54, 0.55},
        [2048]  = {0.46, 0.49, 0.50},
    }

    self:init()
    return self
end

function Game:init()
    -- 設定視窗大小
    love.window.setMode(self.screen_width, self.screen_height)
    
    -- 載入並設定自訂字型
    self.font = love.graphics.newFont("BitcountPropSingleInk.ttf", 30)
    love.graphics.setFont(self.font)
    
    -- 初始化遊戲板
    for y = 1, self.board_size do
        self.board[y] = {}
        for x = 1, self.board_size do
            self.board[y][x] = 0
        end
    end
    
    -- 生成初始方塊
    self:addNewTile()
    self:addNewTile()
end

function Game:update(dt)
    -- 更新所有方塊
    local all_tiles_stopped = true
    for _, tile in ipairs(self.tiles) do
        tile:update(dt)
        if tile:isMoving() then
            all_tiles_stopped = false
        end
    end
    
    -- 當所有方塊停止移動時，結束動畫
    if all_tiles_stopped and self.is_animating then
        self.is_animating = false
        self:finalizeMoves()
    end
end

function Game:draw()
    -- 繪製背景
    love.graphics.setBackgroundColor(0.96, 0.96, 0.94)
    
    -- 繪製遊戲板
    self:drawBoard()
    
    -- 繪製分數
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.printf("Score: " .. self.score, 0, 10, self.screen_width, "center")

    -- 繪製遊戲狀態訊息
    if self.game_won then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", 0, 0, self.screen_width, self.screen_height)
        
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("You Won", 0, self.screen_height / 2 - 20, self.screen_width, "center")
        love.graphics.printf("Score: " .. self.score, 0, self.screen_height / 2 + 20, self.screen_width, "center")
    elseif self.is_game_over then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", 0, 0, self.screen_width, self.screen_height)

        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Game Over", 0, self.screen_height / 2 - 20, self.screen_width, "center")
        love.graphics.printf("Score: " .. self.score, 0, self.screen_height / 2 + 20, self.screen_width, "center")
    end
end

function Game:drawBoard()
    -- 繪製背景網格（空白格子）
    for y = 1, self.board_size do
        for x = 1, self.board_size do
            local x_pos = (x - 1) * (self.tile_size + self.padding) + self.padding
            local y_pos = (y - 1) * (self.tile_size + self.padding) + self.padding + 50
            
            love.graphics.setColor(self.morandi_colors[0])
            love.graphics.rectangle("fill", x_pos, y_pos, self.tile_size, self.tile_size)
        end
    end
    
    -- 先繪製所有非合併來源的方塊（目標方塊和移動方塊）
    for _, tile in ipairs(self.tiles) do
        if not tile.is_merging then
            tile:draw(self.morandi_colors)
        end
    end
    
    -- 再繪製所有合併來源的方塊（疊加在目標方塊之上）
    for _, tile in ipairs(self.tiles) do
        if tile.is_merging then
            tile:draw(self.morandi_colors)
        end
    end
end

function Game:addNewTile()
    local empty_tiles = {}
    for y = 1, self.board_size do
        for x = 1, self.board_size do
            if self.board[y][x] == 0 then
                table.insert(empty_tiles, {x = x, y = y})
            end
        end
    end
    
    if #empty_tiles > 0 then
        local random_tile = empty_tiles[math.random(#empty_tiles)]
        local value = math.random() < 0.9 and 2 or 4
        self.board[random_tile.y][random_tile.x] = value
        
        -- 建立新的 Tile 物件
        local new_tile = Tile.new(value, random_tile.x, random_tile.y, self.tile_size, self.padding)
        new_tile.is_new = true
        new_tile.scale = 0.1 -- 從小開始彈出
        table.insert(self.tiles, new_tile)
    end
end

function Game:keypressed(key)
    if not self.is_game_over and not self.game_won and not self.is_animating then
        local moved = false
        if key == "up" or key == "k" then
            moved = self:moveTiles("up")
        elseif key == "down" or key == "j" then
            moved = self:moveTiles("down")
        elseif key == "left"  or key == "h" then
            moved = self:moveTiles("left")
        elseif key == "right" or key == "l" then
            moved = self:moveTiles("right")
        end

        -- 處理重新開始指令，不論遊戲狀態都可以執行
        if key == "r" then
            self:restart()
            return -- 執行完重新開始後就結束函式
        end

        -- 處理退出遊戲的指令
        if key == "q" then
            love.event.quit()
        end
        
        if moved then
            self.is_animating = true
        end
    end
end

function Game:moveTiles(direction)
    local moved = false
    local merged = {} -- 記錄已合併的位置
    local moved_tiles_info = {} -- 記錄所有移動和合併的資訊
    
    -- 使用臨時棋盤來計算新的狀態
    local temp_board = {}
    for y = 1, self.board_size do
        temp_board[y] = {}
        for x = 1, self.board_size do
            temp_board[y][x] = self.board[y][x]
        end
    end
    
    local start_x, end_x, step_x = 1, self.board_size, 1
    local start_y, end_y, step_y = 1, self.board_size, 1

    if direction == "right" then
        start_x, end_x, step_x = self.board_size, 1, -1
    elseif direction == "down" then
        start_y, end_y, step_y = self.board_size, 1, -1
    end
    
    for y = start_y, end_y, step_y do
        for x = start_x, end_x, step_x do
            local current_tile_value = temp_board[y][x]
            if current_tile_value ~= 0 then
                local target_x, target_y = x, y
                local next_x, next_y = x, y
                
                if direction == "up" then next_y = next_y - 1
                elseif direction == "down" then next_y = next_y + 1
                elseif direction == "left" then next_x = next_x - 1
                elseif direction == "right" then next_x = next_x + 1
                end
                
                -- 找到可移動的最遠位置
                while next_x >= 1 and next_x <= self.board_size and next_y >= 1 and next_y <= self.board_size and temp_board[next_y][next_x] == 0 do
                    target_x, target_y = next_x, next_y
                    if direction == "up" then next_y = next_y - 1
                    elseif direction == "down" then next_y = next_y + 1
                    elseif direction == "left" then next_x = next_x - 1
                    elseif direction == "right" then next_x = next_x + 1
                    end
                end
                
                -- 檢查是否可以合併
                local merge_x, merge_y = target_x, target_y
                if direction == "up" then merge_y = merge_y - 1
                elseif direction == "down" then merge_y = merge_y + 1
                elseif direction == "left" then merge_x = merge_x - 1
                elseif direction == "right" then merge_x = merge_x + 1
                end
                
                local merge_key = merge_y * self.board_size + merge_x
                
                if merge_x >= 1 and merge_x <= self.board_size and merge_y >= 1 and merge_y <= self.board_size 
                   and temp_board[merge_y][merge_x] == current_tile_value 
                   and not merged[merge_key] then
                    -- 合併
                    local new_value = current_tile_value * 2
                    temp_board[merge_y][merge_x] = new_value
                    temp_board[y][x] = 0
                    self.score = self.score + new_value
                    moved = true
                    merged[merge_key] = true
                    
                    -- 記錄合併來源方塊（將移動到目標位置後消失）
                    table.insert(moved_tiles_info, {
                        value = current_tile_value,
                        start_x = x,
                        start_y = y,
                        end_x = merge_x,
                        end_y = merge_y,
                        is_merging = true -- 標記為合併來源
                    })
                    
                    -- 記錄合併目標方塊（新值）
                    table.insert(moved_tiles_info, {
                        value = new_value,
                        start_x = merge_x,
                        start_y = merge_y,
                        end_x = merge_x,
                        end_y = merge_y,
                        is_merging_target = true -- 標記為合併目標
                    })
                    
                    if new_value == 2048 then
                        self.game_won = true
                    end
                elseif target_x ~= x or target_y ~= y then
                    -- 只移動
                    temp_board[target_y][target_x] = current_tile_value
                    temp_board[y][x] = 0
                    moved = true
                    
                    -- 記錄移動資訊
                    table.insert(moved_tiles_info, {
                        value = current_tile_value,
                        start_x = x,
                        start_y = y,
                        end_x = target_x,
                        end_y = target_y
                    })
                end
            end
        end
    end
    
    -- 如果有移動，同步邏輯層和視覺層
    if moved then
        -- 更新正式棋盤
        self.board = temp_board
        
        -- 根據 moved_tiles_info 重建 tiles 陣列
        self.tiles = {}
        
        -- 先創建所有在最終位置的方塊
        for y = 1, self.board_size do
            for x = 1, self.board_size do
                local value = self.board[y][x]
                if value ~= 0 then
                    local new_tile = Tile.new(value, x, y, self.tile_size, self.padding)
                    table.insert(self.tiles, new_tile)
                end
            end
        end
        
        -- 根據 moved_tiles_info 更新動畫屬性
        for _, info in ipairs(moved_tiles_info) do
            for _, tile in ipairs(self.tiles) do
                if tile.gridX == info.end_x and tile.gridY == info.end_y and tile.value == info.value then
                    -- 設定動畫起始位置
                    tile.x = (info.start_x - 1) * (self.tile_size + self.padding) + self.padding
                    tile.y = (info.start_y - 1) * (self.tile_size + self.padding) + self.padding + 50
                    tile.targetX = (info.end_x - 1) * (self.tile_size + self.padding) + self.padding
                    tile.targetY = (info.end_y - 1) * (self.tile_size + self.padding) + self.padding + 50
                    
                    if info.is_merging then
                        tile.is_merging = true
                    end
                    
                    if info.is_merging_target then
                        tile.is_new = true
                        tile.scale = 0.1
                    end
                    break
                end
            end
        end
    end
    
    return moved
end

function Game:createTilesFromMoveInfo(info_table)
    local new_tiles = {}
    for _, info in ipairs(info_table) do
        local tile = Tile.new(info.value, info.start_x, info.start_y, self.tile_size, self.padding)
        tile.targetX = (info.end_x - 1) * (self.tile_size + self.padding) + self.padding
        tile.targetY = (info.end_y - 1) * (self.tile_size + self.padding) + self.padding + 50
        tile.gridX = info.end_x
        tile.gridY = info.end_y
        
        if info.is_merging then
            tile.is_merging = true -- 合併來源，動畫結束後刪除
        end
        
        if info.is_merging_target then
            tile.is_new = true -- 合併目標，有彈出效果
            tile.scale = 1.0 -- 但不需要從小彈出（因為是合併產生的）
        end
        
        table.insert(new_tiles, tile)
    end
    return new_tiles
end

function Game:finalizeMoves()
    -- 刪除所有合併來源的方塊
    local new_tiles = {}
    for _, tile in ipairs(self.tiles) do
        if not tile.is_merging then
            table.insert(new_tiles, tile)
        end
    end
    self.tiles = new_tiles
    
    -- 新增新方塊
    self:addNewTile()
    
    -- 檢查遊戲是否結束
    if self:isGameOver() then
        self.is_game_over = true
    end

    function Game:restart()
    -- 重設遊戲板
    self.board = {}
    for y = 1, self.board_size do
        self.board[y] = {}
        for x = 1, self.board_size do
            self.board[y][x] = 0
        end
    end
    
    -- 清空所有方塊物件
    self.tiles = {}
    
    -- 重設遊戲狀態變數
    self.is_animating = false
    self.score = 0
    self.is_game_over = false
    self.game_won = false
    
    -- 生成新的初始方塊
    self:addNewTile()
    self:addNewTile()
    end
end

function Game:isGameOver()
    for y = 1, self.board_size do
        for x = 1, self.board_size do
            if self.board[y][x] == 0 then
                return false
            end
        end
    end

    for y = 1, self.board_size do
        for x = 1, self.board_size do
            local value = self.board[y][x]
            if x < self.board_size and value == self.board[y][x+1] then return false end
            if y < self.board_size and value == self.board[y+1][x] then return false end
        end
    end
    
    return true
end

-- 建立全域遊戲實例
local game

-- LÖVE 框架必需的回調函式
function love.load()
    game = Game.new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.keypressed(key)
    game:keypressed(key)
end