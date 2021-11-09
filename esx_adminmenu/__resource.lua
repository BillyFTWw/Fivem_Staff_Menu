resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

description 'deobfuscated by billy_ftw#4163 <3'

server_scripts {
  '@mysql-async/lib/MySQL.lua',
  'config.lua',
  'shared/sh_queue.lua',
  'server/server.lua'
}

client_scripts {
  "NativeUI/UIMenu/UIMenu.lua",
  "NativeUI/UIMenu/MenuPool.lua",
  "NativeUI/Wrapper/Utility.lua",
  "NativeUI.lua",
  "NativeUI/UIElements/Sprite.lua",
  "NativeUI/UIElements/UIResText.lua",
  "NativeUI/UIElements/UIResRectangle.lua",
  "NativeUI/UIElements/UIVisual.lua",
  "NativeUI/UIMenu/elements/Badge.lua",
  "NativeUI/UIMenu/elements/Colours.lua",
  "NativeUI/UIMenu/elements/ColoursPanel.lua",
  "NativeUI/UIMenu/elements/StringMeasurer.lua",
  "NativeUI/UIMenu/items/UIMenuItem.lua",
  "NativeUI/UIMenu/items/UIMenuListItem.lua",
  "NativeUI/UIMenu/items/UIMenuColouredItem.lua",
  "NativeUI/UIMenu/windows/UIMenuHeritageWindow.lua",
  "NativeUI/UIMenu/panels/UIMenuColourPanel.lua",
  'config.lua',
  'shared/sh_queue.lua',
  'client/client.lua'
}
client_script "@esx_anticheat/acloader.lua"