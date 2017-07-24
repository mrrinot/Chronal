List = {};

function List.new ()
  return {first = 0, last = -1, size = 0}
end

function List.push (list, value)
  local first = list.first - 1
  list.first = first
  list[first] = value
  list.size = list.size + 1;
end

function List.popTop (list)
  local first = list.first
  if list.size <= 0 then return nil end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  list.size = list.size - 1;
  return value
end

function List.popBottom (list)
  local last = list.last
  if list.first > last then return nil end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.size = list.size - 1;
  list.last = last - 1
  return value
end

function Lerp(pos1, pos2, t)
  x = (1 - t) * pos1.X + t * pos2.X;
  y = (1 - t) * pos1.Y + t * pos2.Y;
  return Vector(x, y);
end

-- EndRegion Usefull Functions

local	chronal_mod = RegisterMod( "chronal", 1);
local	chronal_item = Isaac.GetItemIdByName( "Chronal Accelerator" )

local debugText = "null";
local rewinding = false;
local rewindFrameCount = 0;
local rewindMinDuration = 6;
local lastPos = nil;

local chargeFrameCount = 0;

local dataQueue = List.new();

function chronal_mod:triggerItem() -- local function which is called whenever we trigger our item (either by using it or by getting hit)
  local player = Isaac.GetPlayer(0);
  rewinding = true;
end

function chronal_mod:rewind()
  local player = Isaac.GetPlayer(0);
  local pPos = player.Position;
  if (lastPos == nil) then
    lastPos = List.popTop(dataQueue);
    if (lastPos == nil) then return end
  end

  Isaac.DebugString("FROM pos "..lastPos.pos.X.." "..lastPos.pos.Y);
  Isaac.DebugString("TO pos "..pPos.X.." "..pPos.Y);
  local newPos = Lerp(pPos, lastPos.pos, 1/6);
  Isaac.DebugString("newLerpPos = "..newPos.X.." "..newPos.Y.."\n");
  player.Position = newPos;
end

function chronal_mod:onUpdate()
  local player = Isaac.GetPlayer(0);
  debugText = Isaac.GetFrameCount();

  if (rewinding == true) then
    rewindFrameCount = rewindFrameCount + 1;
    chronal_mod.rewind();
  else
    chargeFrameCount = chargeFrameCount + 1;
  end

  if (rewindFrameCount >= rewindMinDuration) then
    Isaac.DebugString("duration = "..rewindFrameCount);
    rewindFrameCount = 0;
    rewinding = false;
    lastPos = nil;
  end

  if (player:HasCollectible(chronal_item)) then
    if (chargeFrameCount % 6 == 0) then
      List.push(dataQueue, {pos = player.Position});
      Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, player.Position, Vector(0, 0), player);
      Isaac.DebugString("pushed pos = "..player.Position.X.." "..player.Position.Y);
      if (dataQueue.size > 50) then
        List.popBottom(dataQueue);
      end
    end
  end

end

function chronal_mod:resetData()
  while (dataQueue.size > 0) do
    List.popTop(dataQueue);
  end
  end

function chronal_mod:catchUseItem(pl, hook, button)
  local player = Isaac.GetPlayer(0);
  if (button == ButtonAction.ACTION_ITEM) then
--      player:SetActiveCharge(player:GetActiveCharge() - 10);
--      chronal_mod.triggerItem();
    return 1;
  end
end

-- function chronal_mod:take_damage()
-- 	if(player:GetActiveItem()== chronal_item) then
-- 		triggerchronal();
-- 	end
-- end

function chronal_mod:debug_text()
  Isaac.RenderText("Charges: " .. dataQueue.size, 400, 50, 255, 0, 0, 255)
  Isaac.RenderText("Frame: " .. debugText, 100, 50, 255, 0, 0, 255)
end

function chronal_mod:onInput(entity, hook, action)
  if (entity ~= nil) then
    local player = entity:ToPlayer();
    if player and rewinding and hook == InputHook.IS_ACTION_PRESSED then
      if action ~= ButtonAction.ACTION_ITEM) then
      return false;
      end
      end
    end
  end

chronal_mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, chronal_mod.onInput);
chronal_mod:AddCallback( ModCallbacks.MC_USE_ITEM, chronal_mod.triggerItem, chronal_item );
--chronal_mod:AddCallback( ModCallbacks.MC_POST_UPDATE, chronal_mod.trackCharges, EntityType.ENTITY_PLAYER );
chronal_mod:AddCallback( ModCallbacks.MC_POST_PEFFECT_UPDATE, chronal_mod.onUpdate);
-- chronal_mod:AddCallback( ModCallbacks.MC_ENTITY_TAKE_DMG, chronal_mod.take_damage, EntityType.ENTITY_PLAYER)
chronal_mod:AddCallback( ModCallbacks.MC_POST_RENDER, chronal_mod.debug_text);
chronal_mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, chronal_mod.resetData);
