minimapWidget = nil
minimapButton = nil
minimapWindow = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRootPanel())
  minimapWindow:setContentMinimumHeight(64)

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')

  if not minimapWidget then
    print("ERROR: Could not find minimap widget in UI")
    return
  end

  -- Desabilitar scrollbars
  local scrollBar = minimapWindow:getChildById('miniwindowScrollBar')
  if scrollBar then
    scrollBar:hide()
    scrollBar:setVisible(false)
  end

  local contentsPanel = minimapWindow:getChildById('contentsPanel')
  if contentsPanel then
    if contentsPanel.setVerticalScrollBar then
      contentsPanel:setVerticalScrollBar(false)
    end
    if contentsPanel.setHorizontalScrollBar then
      contentsPanel:setHorizontalScrollBar(false)
    end
    -- Ajustar para preencher toda a área, incluindo onde estava a scrollbar
    contentsPanel:setMarginRight(0)
  end

  if minimapWidget.setVerticalScrollBar then
    minimapWidget:setVerticalScrollBar(false)
  end
  if minimapWidget.setHorizontalScrollBar then
    minimapWidget:setHorizontalScrollBar(false)
  end

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)

  minimapWindow:setup()
  minimapWindow:show()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onServerTime = onChangeWorldTime
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end

  local resizeBorder = minimapWindow:getChildById('resizeBorder')
  resizeBorder.onMousePress = function(self, mousePos, mouseButton)
    local parent = minimapWindow:getParent()
    if parent and parent:getClassName() == 'UIMiniWindowContainer' then
      local pos = minimapWindow:getPosition()
      local size = minimapWindow:getSize()

      -- Create placeholder to keep space in sidebar
      local placeholder = g_ui.createWidget('UIWidget')
      placeholder:setHeight(size.height)
      placeholder:setWidth(size.width)
      placeholder:setId('minimapPlaceholder')
      placeholder.save = true
      placeholder.close = function() end
      placeholder.saveParentIndex = function() end
      placeholder.saveParentPosition = function() end

      local index = parent:getChildIndex(minimapWindow)
      parent:insertChild(index, placeholder)
      minimapWindow.placeholder = placeholder

      -- Create placeholder for the second sidebar (LeftExtraPanel) if visible
      local leftExtraPanel = modules.game_interface.getLeftExtraPanel()
      if leftExtraPanel and leftExtraPanel:isVisible() then
        local placeholderExtra = g_ui.createWidget('UIWidget')
        placeholderExtra:setHeight(size.height)
        placeholderExtra:setWidth(leftExtraPanel:getWidth() - leftExtraPanel:getPaddingLeft() - leftExtraPanel:getPaddingRight())
        placeholderExtra:setId('minimapPlaceholderExtra')
        placeholderExtra.save = true
        placeholderExtra.close = function() end
        placeholderExtra.saveParentIndex = function() end
        placeholderExtra.saveParentPosition = function() end
        leftExtraPanel:insertChild(1, placeholderExtra)
        minimapWindow.placeholderExtra = placeholderExtra
      end

      minimapWindow:setParent(modules.game_interface.getRootPanel())
      minimapWindow:setPosition(pos)
      minimapWindow:setSize(size)
    end
  end

  local originalResizeRelease = resizeBorder.onMouseRelease
  resizeBorder.onMouseRelease = function(self, mousePos, mouseButton)
    if originalResizeRelease then originalResizeRelease(self, mousePos, mouseButton) end

    if minimapWindow:getWidth() < 180 then
      if minimapWindow.placeholder then
        local parent = minimapWindow.placeholder:getParent()
        minimapWindow:setParent(parent)
        local index = parent:getChildIndex(minimapWindow.placeholder)
        parent:insertChild(index, minimapWindow)

        minimapWindow.placeholder:destroy()
        minimapWindow.placeholder = nil

        if minimapWindow.placeholderExtra then
          minimapWindow.placeholderExtra:destroy()
          minimapWindow.placeholderExtra = nil
        end

        minimapWindow:setWidth(parent:getWidth() - parent:getPaddingLeft() - parent:getPaddingRight())
      else
        -- Fallback
        local leftPanel = modules.game_interface.getLeftPanel()
        minimapWindow:setParent(leftPanel)
        minimapWindow:setWidth(leftPanel:getWidth() - leftPanel:getPaddingLeft() - leftPanel:getPaddingRight())
      end
    end
  end

  local originalOnHeightChange = minimapWindow.onHeightChange
  minimapWindow.onHeightChange = function(self, height)
    if originalOnHeightChange then originalOnHeightChange(self, height) end
    if self.placeholder then
      self.placeholder:setHeight(height)
      local parent = self.placeholder:getParent()
      if parent and parent.fitAll then parent:fitAll(self.placeholder) end
    end
    if self.placeholderExtra then
      self.placeholderExtra:setHeight(height)
      local parent = self.placeholderExtra:getParent()
      if parent and parent.fitAll then parent:fitAll(self.placeholderExtra) end
    end
    -- Garantir que scrollbar permaneça escondida
    local scrollBar = self:getChildById('miniwindowScrollBar')
    if scrollBar then
      scrollBar:hide()
      scrollBar:setVisible(false)
    end
  end
end

function terminate()
  if g_game.isOnline() then
    saveConfig()
    saveMap()
  end

  if minimapWindow.placeholder then
    local parent = minimapWindow.placeholder:getParent()
    minimapWindow:setParent(parent)
    local index = parent:getChildIndex(minimapWindow.placeholder)
    parent:insertChild(index, minimapWindow)
    minimapWindow.placeholder:destroy()
    minimapWindow.placeholder = nil
  end

  if minimapWindow.placeholderExtra then
    minimapWindow.placeholderExtra:destroy()
    minimapWindow.placeholderExtra = nil
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onServerTime = onChangeWorldTime
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Shift+M')

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end

function onChangeWorldTime(hour, minute)
  if not minimapWindow then return end

  local rosePanel = minimapWindow:recursiveGetChildById('rosePanel')
  if not rosePanel then return end

  local ambients = rosePanel:getChildById('ambients')
  if not ambients then return end

  local position = math.floor((124 / (24 * 60)) * ((hour * 60) + minute))
  local mainWidth = 31
  local secondaryWidth = 0

  if (position + 31) >= 124 then
    secondaryWidth = ((position + 31) - 124) + 1
    mainWidth = 31 - secondaryWidth
  end

  local mainWidget = ambients:getChildById('main')
  local secondaryWidget = ambients:getChildById('secondary')

  if mainWidget then
    mainWidget:setWidth(mainWidth)
  end

  if secondaryWidget then
    secondaryWidget:setWidth(secondaryWidth)

    if secondaryWidth == 0 then
      secondaryWidget:hide()
    else
      secondaryWidget:setImageClip('0 0 ' .. secondaryWidth .. ' 31')
      secondaryWidget:show()
    end
  end

  if mainWidth == 0 then
    if mainWidget then mainWidget:hide() end
  else
    if mainWidget then
      mainWidget:setImageClip(position .. ' 0 ' .. mainWidth .. ' 31')
      mainWidget:show()
    end
  end
end

function online()
  loadMap()
  loadConfig()

  -- Force initial camera position update
  updateCameraPosition()

  -- Schedule another update after a short delay to ensure player position is available
  addEvent(function()
    updateCameraPosition()
  end, 100)
end

function offline()
  saveConfig()
  saveMap()
end

function saveConfig()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local char = player:getName()

  local settings = {}
  settings.detached = (minimapWindow:getParent() == modules.game_interface.getRootPanel())
  settings.width = minimapWindow:getWidth()
  settings.height = minimapWindow:getHeight()
  local pos = minimapWindow:getPosition()
  settings.pos = {x = pos.x, y = pos.y}

  g_settings.setNode('Minimap_Expansion_' .. char, settings)
end

function loadConfig()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local char = player:getName()

  local settings = g_settings.getNode('Minimap_Expansion_' .. char)
  if settings and settings.detached then
    local parent = minimapWindow:getParent()
    if parent and parent:getClassName() == 'UIMiniWindowContainer' then
       local size = {width = settings.width, height = settings.height}
       local pos = {x = settings.pos.x, y = settings.pos.y}

       local placeholder = g_ui.createWidget('UIWidget')
       placeholder:setHeight(size.height)
       placeholder:setWidth(size.width)
       placeholder:setId('minimapPlaceholder')
       placeholder.save = true
       placeholder.close = function() end
       placeholder.saveParentIndex = function() end
       placeholder.saveParentPosition = function() end

       local index = parent:getChildIndex(minimapWindow)
       parent:insertChild(index, placeholder)
       minimapWindow.placeholder = placeholder

       -- Restore placeholder for second sidebar if needed
       local leftExtraPanel = modules.game_interface.getLeftExtraPanel()
       if leftExtraPanel and leftExtraPanel:isVisible() then
         local placeholderExtra = g_ui.createWidget('UIWidget')
         placeholderExtra:setHeight(size.height)
         placeholderExtra:setWidth(leftExtraPanel:getWidth() - leftExtraPanel:getPaddingLeft() - leftExtraPanel:getPaddingRight())
         placeholderExtra:setId('minimapPlaceholderExtra')
         placeholderExtra.save = true
         placeholderExtra.close = function() end
         placeholderExtra.saveParentIndex = function() end
         placeholderExtra.saveParentPosition = function() end
         leftExtraPanel:insertChild(1, placeholderExtra)
         minimapWindow.placeholderExtra = placeholderExtra
       end

       minimapWindow:setParent(modules.game_interface.getRootPanel())
       minimapWindow:setPosition(pos)
       minimapWindow:setSize(size)
    end
  end
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  local minimapFile = '/minimap.otmm'
  local dataMinimapFile = '/data' .. minimapFile
  local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'

  if g_resources.fileExists(dataMinimapFile) then
    loaded = g_minimap.loadOtmm(dataMinimapFile)
  end
  if not loaded and g_resources.fileExists(versionedMinimapFile) then
    loaded = g_minimap.loadOtmm(versionedMinimapFile)
  end
  if not loaded and g_resources.fileExists(minimapFile) then
    loaded = g_minimap.loadOtmm(minimapFile)
  end
  if not loaded then
    print("Minimap couldn't be loaded, file missing?")
  end

  if minimapWidget then
    minimapWidget:load()
    minimapWidget:setZoom(0)
  end
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  local minimapFile = '/minimap' .. clientVersion .. '.otmm'
  g_minimap.saveOtmm(minimapFile)
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function onClickRoseButton(dir)
  if not minimapWidget then return end

  if dir == 'north' then
    minimapWidget:move(0, 1)
  elseif dir == 'north-east' then
    minimapWidget:move(-1, 1)
  elseif dir == 'east' then
    minimapWidget:move(-1, 0)
  elseif dir == 'south-east' then
    minimapWidget:move(-1, -1)
  elseif dir == 'south' then
    minimapWidget:move(0, -1)
  elseif dir == 'south-west' then
    minimapWidget:move(1, -1)
  elseif dir == 'west' then
    minimapWidget:move(1, 0)
  elseif dir == 'north-west' then
    minimapWidget:move(1, 1)
  end
end

function zoomIn()
  if minimapWidget then
    minimapWidget:zoomIn()
  end
end

function zoomOut()
  if minimapWidget then
    minimapWidget:zoomOut()
  end
end

function upLayer()
  if minimapWidget then
    minimapWidget:floorUp(1)
  end
end

function downLayer()
  if minimapWidget then
    minimapWidget:floorDown(1)
  end
end

function resetMap()
  if minimapWidget then
    minimapWidget:reset()
    local player = g_game.getLocalPlayer()
    if player then
      local pos = player:getPosition()
      if pos then
        minimapWidget:setCameraPosition(pos)
      end
    end
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
  else
    fullmapView = false
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end