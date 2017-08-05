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

local	chronal_mod = RegisterMod( "Chronal", 1);
local	chronal_item = Isaac.GetItemIdByName( "Chronal Accelerator" )

local debugText = "null";

local lastData = nil;
local dataQueue = List.new();

local chargeFrameCount = 0;
local rewinding = false;
local lastFrameRewinding = false;
local rewindFrameCount = 0;
local dataGatheringFrequency = 2;
local framesPerCharge = 15;

function chronal_mod:changePlayerInfos()
  local player = Isaac.GetPlayer(0);
  local pPos = player.Position;

  local newPos = Lerp(pPos, lastData.playerInfos.pos, 1 / (framesPerCharge / 3) );

  player.Position = newPos;
  player.Velocity = lastData.playerInfos.velocity * (-1 / ( framesPerCharge / 3));
  player:AddCoins(lastData.playerInfos.coinCount - player:GetNumCoins() > 0 and lastData.playerInfos.coinCount - player:GetNumCoins() or 0);
  player:AddBombs(lastData.playerInfos.bombCount - player:GetNumBombs() > 0 and lastData.playerInfos.bombCount - player:GetNumBombs() or 0);
  player:AddKeys(lastData.playerInfos.keyCount - player:GetNumKeys() > 0 and lastData.playerInfos.keyCount - player:GetNumKeys() or 0);
  player:AddHearts(lastData.playerInfos.hearts - player:GetHearts() > 0 and lastData.playerInfos.hearts - player:GetHearts() or 0);
  local mask;
  local beforeBHearts = 0;
  local afterBHearts = 0;
  mask = lastData.playerInfos.blackHearts;
  while (mask > 0) do
    if (mask & 1 == 1) then
      beforeBHearts = beforeBHearts + 1;
    end
    mask = mask >> 1;
  end
  mask = player:GetBlackHearts();
  while (mask > 0) do
    if (mask & 1 == 1) then
      afterBHearts = afterBHearts + 1;
    end
    mask = mask >> 1;
  end
  local beforeSHearts = lastData.playerInfos.soulHearts - beforeBHearts;
  local afterSHearts = player:GetSoulHearts() - afterBHearts;
  player:AddSoulHearts(beforeSHearts - afterSHearts > 0 and beforeSHearts - afterSHearts or 0);
  player:AddBlackHearts(beforeBHearts - afterBHearts > 0 and beforeBHearts - afterBHearts or 0);
  player:AddEternalHearts(lastData.playerInfos.eternalHearts - player:GetEternalHearts() > 0 and lastData.playerInfos.eternalHearts - player:GetEternalHearts() or 0);
end

function chronal_mod:changeEntitiesInfos()
  local ents = Isaac.GetRoomEntities();

  for k,v in pairs(ents) do
    Isaac.DebugString(k.." "..v.Type);
    if v:IsEnemy() or v.Type == EntityType.ENTITY_PROJECTILE then
      Isaac.DebugString("FREEZE !");
      v:AddFreeze(EntityRef(player), 2);
      if (v:IsBoss()) then
        Isaac.DebugString("MEGA FREEZE !");
        v:AddFreeze(EntityRef(v), 5);
      end
    end
  end
  Isaac.DebugString("\n");
end

function chronal_mod:rewind()
  if (lastData == nil) then
    lastData = List.popTop(dataQueue);
    if (lastData == nil) then return end
  end
  chronal_mod.changePlayerInfos();
  chronal_mod.changeEntitiesInfos();
end

function chronal_mod:evaluateRewinding()
  player = Isaac.GetPlayer(0);
  lastFrameRewinding = rewinding;

  if Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) and player:GetActiveCharge() > -1 then
    rewinding = true;
    player.ControlsEnabled = false;
    player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE;
  else
    player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL;
    player.ControlsEnabled = true;
    rewinding = false; 
  end
end

function chronal_mod:onUpdate()
  local player = Isaac.GetPlayer(0);
  debugText = Isaac.GetFrameCount();

  if (player:HasCollectible(chronal_item)) then
    chronal_mod.evaluateRewinding();

    if (lastFrameRewinding == false and rewinding == true) then -- First frame rewinding
      chargeFrameCount = 0;
      rewindFrameCount = 0;
--      Isaac.DebugString("Decharging First ! "..rewindFrameCount .. " < = > " .. framesPerCharge);
      player:SetActiveCharge(player:GetActiveCharge() - 1);
    elseif (lastFrameRewinding == true and rewinding == false) then -- Not rewinding anymore

    end

    if (lastFrameRewinding == true and rewinding == true and rewindFrameCount % framesPerCharge == 0) then -- Second to last rewinding frame
--      Isaac.DebugString("Decharging ! "..rewindFrameCount .. " < = > " .. framesPerCharge);
      player:SetActiveCharge(player:GetActiveCharge() - 1);
    end

    if (rewinding == true) then -- Every rewinding frame
      if (rewindFrameCount % (dataGatheringFrequency) == 0) then
        lastData = nil;
      end
      rewindFrameCount = rewindFrameCount + 1;
      chronal_mod.rewind();
    else -- Rewinding == FALSE
      chargeFrameCount = chargeFrameCount + 1;
    end

    if (chargeFrameCount % dataGatheringFrequency == 0 and chargeFrameCount > dataGatheringFrequency * 10) then
      local data = {};
      data.playerInfos = {};
      data.playerInfos.pos = player.Position;
      data.playerInfos.hearts = player:GetHearts();
      data.playerInfos.soulHearts = player:GetSoulHearts();
      data.playerInfos.eternalHearts = player:GetEternalHearts();
      data.playerInfos.blackHearts = player:GetBlackHearts();
      data.playerInfos.coinCount = player:GetNumCoins();
      data.playerInfos.keyCount = player:GetNumKeys();
      data.playerInfos.bombCount = player:GetNumBombs();
      data.playerInfos.orientation = player:GetHeadDirection();
      data.playerInfos.velocity = player.Velocity;
      List.push(dataQueue, data);
      if (dataQueue.size > 6 * framesPerCharge / dataGatheringFrequency) then
        List.popBottom(dataQueue);
      end
    end
  end
end

function onPostUpdate()

end

function chronal_mod:resetData()
  while (dataQueue.size > 0) do
    List.popTop(dataQueue);
  end
  rewinding = false;
  lasData = nil;
  chargeFrameCount = 0;
  rewindFrameCount = 0;
end

-- function chronal_mod:take_damage()
-- 	if(player:GetActiveItem()== chronal_item) then
-- 		triggerchronal();
-- 	end
-- end


function chronal_mod:onInput(entity, hook, action)
  if (entity ~= nil) then
    local player = entity:ToPlayer();
    if player then
      if action == ButtonAction.ACTION_ITEM and Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex) and player:HasCollectible(chronal_item) then
        return not Input.GetActionValue(ButtonAction.ACTION_ITEM, player.ControllerIndex);
      end

--      if rewinding and action ~= ButtonAction.ACTION_ITEM then
--        if hook == InputHook.GET_ACTION_VALUE then 
--          return 0.0;
--        elseif hook == InputHook.IS_ACTION_PRESSED then 
--          return false;
--        end
--      end
    end
  end
end

function chronal_mod:debug_text()
  local player = Isaac.GetPlayer(0);
  Isaac.RenderText("Charges: " .. dataQueue.size, 400, 50, 255, 0, 0, 255)
  Isaac.RenderText("Frame: " .. debugText, 40, 65, 255, 255, 255, 255)
  Isaac.RenderText("BH ".. player:GetBlackHearts().." "..player:GetSoulHearts().." "..player:GetEternalHearts(), 40, 75, 255, 255, 255, 255, 255);
  Isaac.RenderText("Charged frames ".. chargeFrameCount, 40, 85, 255, 255, 255, 255, 255);
  Isaac.RenderText("Rewinding frames ".. framesPerCharge, 40, 100, 255, 255, 255, 255, 255);
  Isaac.RenderText("Rewinding ".. (rewinding == true and '1' or '0'), 400, 65, 255, 255, 255, 255, 255);
end

chronal_mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, chronal_mod.onInput);
chronal_mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, chronal_mod.onUpdate);
-- chronal_mod:AddCallback( ModCallbacks.MC_ENTITY_TAKE_DMG, chronal_mod.take_damage, EntityType.ENTITY_PLAYER)
chronal_mod:AddCallback(ModCallbacks.MC_POST_RENDER, chronal_mod.debug_text);
chronal_mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, chronal_mod.resetData);
