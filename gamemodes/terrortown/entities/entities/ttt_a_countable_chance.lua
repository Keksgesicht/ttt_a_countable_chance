if SERVER then
  AddCSLuaFile()
  resource.AddFile("vgui/ttt/icon_acc.vmt")
  resource.AddFile("vgui/ttt/perks/hud_acc.png")
  resource.AddWorkshop("907187332")
  util.AddNetworkString("ACCBuyed")
  util.AddNetworkString("ACCKill")
  util.AddNetworkString("ACCError")
  util.AddNetworkString("ACCRespawn")
  util.AddNetworkString("ACCRespawnCount")
end

EQUIP_ACC = (GenerateNewEquipmentID and GenerateNewEquipmentID() ) or 8

if CLIENT then
  
  function GetChances(ctimes, big)	
	local c_string
	local times_list =
	  { [ 2 ] = "Second",
		[ 3 ] = "Third",
		[ 4 ] = "Fourth",
		[ 5 ] = "Fifth",
		[ 6 ] = "Sixth",
		[ 7 ] = "Seventh",
		[ 8 ] = "Eighth",
		[ 9 ] = "Ninth",
		[ 10 ] = "Tenth",
		[ 11 ] = "Eleventh",
		[ 12 ] = "Twelfth" }
	if big then
	  if times_list[ ctimes ] then
	    return times_list[ ctimes ]
	  else
		c_string = ctimes .. "th"
	    return c_string
	  end
    else
      if times_list[ ctimes ] then
		return string.lower(times_list[ ctimes ])
	  else
		c_string = ctimes .. "th"
	    return string.lower( c_string )
	  end
	end
  end

  local_RespawnCount = 2
  GER_org = GetEquipmentForRole
  GetEquipmentForRole = 
	function(role)
	  local items = GER_org(role)
	  for k, item in pairs(items) do
		if item.id == EQUIP_ACC then
		  item.name = "A " .. GetChances(local_RespawnCount, true) .. " Chance"
		  item.desc = "Life for a ".. GetChances(local_RespawnCount, false) .. " time but only with a given Chance. \nYour Chance will change per kill.\nIt also works if the round should end."
		end
	  end
	  return items
	end

  -- feel for to use this function for your own perk, but please credit Zaratusa
  -- your perk needs a "hud = true" in the table, to work properly
  local defaultY = ScrH() / 2 + 20
  local function getYCoordinate(currentPerkID)
    local amount, i, perk = 0, 1
    while (i < currentPerkID) do
      perk = GetEquipmentItem(LocalPlayer():GetRole(), i)
      if (istable(perk) and perk.hud and LocalPlayer():HasEquipmentItem(perk.id)) then
        amount = amount + 1
      end
      i = i * 2
    end

    return defaultY - 80 * amount
  end

  local yCoordinate = defaultY
  -- best performance, but the has about 0.5 seconds delay to the HasEquipmentItem() function
  hook.Add("TTTBoughtItem", "TTTACC2", function()
      if (LocalPlayer():HasEquipmentItem(EQUIP_ACC)) then
        yCoordinate = getYCoordinate(EQUIP_ACC)
      end
    end)
  local material = Material("vgui/ttt/perks/hud_acc.png")
  hook.Add("HUDPaint", "TTTACC", function()
      if (LocalPlayer():HasEquipmentItem(EQUIP_ACC)) then
        surface.SetMaterial(material)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(20, yCoordinate, 64, 64)
      end
    end)

end

local ACountableChance = {
  id = EQUIP_ACC,
  loadout = false,
  type = "item_passive",
  material = "vgui/ttt/icon_acc",
  name = "A Second Chance",
  desc = "Life for a second time but only with a given Chance. \nYour Chance will change per kill.\nIt also works if the round should end.",
  hud = true
}

local detectiveCanUse = CreateConVar("ttt_countablechance_det", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Detective be able to use the Countable Chance.")
local traitorCanUse = CreateConVar("ttt_countablechance_tr", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Traitor be able to use the Countable Chance.")

if (detectiveCanUse:GetBool()) then
  table.insert(EquipmentItems[ROLE_DETECTIVE], ACountableChance)
end
if (traitorCanUse:GetBool()) then
  table.insert(EquipmentItems[ROLE_TRAITOR], ACountableChance)
end

if SERVER then

  local player_count = 1
  local traitor_count = 1
  
  local function GetPlayerCount()
    local count = 0
	for k,v in pairs(player.GetAll()) do
	  count = count + 1
	end
    return count
  end
  
  local function GetTraitorCount()
    local count = 0
	for k,v in pairs(player.GetAll()) do
      if v:GetRole() == ROLE_TRAITOR then
		count = count + 1
	  end
    end
    return count
  end
  
  hook.Add("TTTOrderedEquipment", "TTTACC", function(ply, equipment, is_item)
      if is_item == EQUIP_ACC then		
        ply.shouldacc = true
        if ply:GetRole() == ROLE_TRAITOR then
		  player_count = GetPlayerCount()
          ply.SecondChanceChance = 20
        elseif ply:GetRole() == ROLE_DETECTIVE then
		  traitor_count = GetTraitorCount()
          ply.SecondChanceChance = 40
        end
		ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance, 0, 99)
        net.Start("ACCBuyed")
        net.WriteInt(ply.SecondChanceChance, 8)
        net.Send(ply)
      end
    end)

  local plymeta = FindMetaTable( "Player" );

  function SecondChance( victim, inflictor, attacker)
    local SecondChanceRandom = math.random(1,100)
    local PlayerChance = math.Clamp(math.Round(victim.SecondChanceChance, 0), 0, 99)
    if victim.shouldacc == true and SecondChanceRandom <= PlayerChance then
      victim.NOWINACC = true
      victim:SetNWInt("ACCthetimeleft", 10)
      timer.Create("TTTACC" .. victim:EntIndex() , 1 ,10, function()
          if IsValid(victim) then
            victim:SetNWInt("ACCthetimeleft", victim:GetNWInt("ACCthetimeleft") - 1)
            if ( victim:GetNWInt("ACCthetimeleft") <= 9 ) then
              victim:SetNWBool("ACCCanRespawn", true)
            end
            if ( victim:GetNWInt("ACCthetimeleft") <= 0 ) then
              victim:ACCHandleRespawn(true)
            end
          end
        end )
      net.Start("ACCRespawn")
      net.WriteBit(true)
      net.Send(victim)
	  victim.RespawnCount = victim.RespawnCount + 1
	  net.Start("ACCRespawnCount")
      net.WriteInt(victim.RespawnCount, 8)
      net.Send(victim)
    elseif victim.shouldacc == true and SecondChanceRandom > PlayerChance then
      victim.shouldacc = false
      net.Start("ACCRespawn")
      net.WriteBit(false)
      net.Send(victim)
    end
  end

  local Positions = {}
  for i = 0,360,22.5 do table.insert( Positions, Vector(math.cos(i),math.sin(i),0) ) end -- Populate Around Player
  table.insert(Positions, Vector(0, 0, 1)) -- Populate Above Player

  local function FindACCPosition(ply) -- I stole a bit of the Code from NiandraLades because its good
    local size = Vector(32, 32, 72)

    local StartPos = ply:GetPos() + Vector(0, 0, size.z / 2)

    local len = #Positions

    for i = 1, len do
      local v = Positions[i]
      local Pos = StartPos + v * size * 1.5

      local tr = {}
      tr.start = Pos
      tr.endpos = Pos
      tr.mins = size / 2 * -1
      tr.maxs = size / 2
      local trace = util.TraceHull(tr)

      if (!trace.Hit) then
        return Pos - Vector(0, 0, size.z / 2)
      end
    end

    return false
  end

  local function FindCorpse(ply) -- From TTT Ulx Commands, sorry
    for _, ent in pairs( ents.FindByClass( "prop_ragdoll" )) do
      if ent.uqid == ply:UniqueID() and IsValid(ent) then
        return ent or false
      end
    end
  end

  function plymeta:ACCHandleRespawn(corpse)
  if !IsValid(self) then return end
    local body = FindCorpse(self)

    if !IsValid(body) then
      if SERVER then
        net.Start("ACCError")
        net.WriteBool(false)
        net.Send(self)
      end
      self.shouldacc = false
      self.NOWINACC = false
      return
    end

    if corpse then
      local spawnPos = FindACCPosition(body)

      if !spawnPos then
        if SERVER then
          net.Start("ACCError")
          net.WriteBool(true)
          net.Send(self)
        end
        self:ACCHandleRespawn(false)
        return
      end

      self:SpawnForRound(true)
      self:SetPos(spawnPos)
      self:SetEyeAngles(Angle(0, body:GetAngles().y, 0))
    else
      self:SpawnForRound(true)
    end

    timer.Remove("TTTACC" .. self:EntIndex())
    self:SetNWBool("ACCCanRespawn", false)
    self:SetNWInt("ACCthetimeleft", 10)
    self.shouldacc = false
    self.NOWINACC = false
    local credits = CORPSE.GetCredits(body, 0)
    self:SetCredits(credits)
    body:Remove()
    DamageLog("SecondChance: " .. self:Nick() .. " has been respawned.")
  end

  hook.Add( "KeyPress", "ACCRespawn", function( ply, key )
      if ply:GetNWBool("ACCCanRespawn") then
        if key == IN_RELOAD then
          ply:ACCHandleRespawn(true)
        elseif key == IN_JUMP then
          ply:ACCHandleRespawn(false)
        end
      end
    end )

  function CUSTOMWIN()
    for k,v in pairs(player.GetAll()) do
      if v.NOWINACC == true then return WIN_NONE end
    end
  end

  function ResettinAsc()
    for k,v in pairs(player.GetAll()) do
      v.shouldacc = false
      v.NOWINACC = false
      v:SetNWBool("ACCCanRespawn", false)
      v:SetNWInt("ACCthetimeleft", 10)
      v.SecondChanceChance = 0
	  v.RespawnCount = 2
	  net.Start("ACCRespawnCount")
      net.WriteInt(v.RespawnCount, 8)
      net.Send(v)
      timer.Remove("TTTACC" .. v:EntIndex())
    end
  end

  function CheckifAsc(ply, attacker, dmg)
    if IsValid(attacker) and ply != attacker and attacker:IsPlayer() then
	  if attacker:HasEquipmentItem(EQUIP_ACC) then
		if attacker:GetRole() == ROLE_TRAITOR and (ply:GetRole() == ROLE_INNOCENT or ply:GetRole() == ROLE_DETECTIVE) then
          attacker.SecondChanceChance = attacker.SecondChanceChance + math.Round( ((0.77 * 0.82 ^ player_count) * 100) / (attacker.RespawnCount - 1), 2 )
		elseif attacker:GetRole() == ROLE_DETECTIVE and ply:GetRole() == ROLE_TRAITOR then
          attacker.SecondChanceChance = attacker.SecondChanceChance + math.Round( ((1.44 * 0.58 ^ traitor_count) * 100) / (attacker.RespawnCount - 1), 2 )
		end
		attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance, 0, 99)
		net.Start("ACCKill")
		net.WriteInt(attacker.SecondChanceChance,8)
		net.Send(attacker)
	  end
    end
  end
end

if CLIENT then

  function DrawACCHUD()
    if LocalPlayer():GetNWBool("ACCCanRespawn") then
      draw.RoundedBox( 20, ScrW() / 2-945, ScrH() / 2-440, 300 , 100 ,Color(255,80,80,255) )
      surface.SetDrawColor(255,255,255,255)
      local w = LocalPlayer():GetNWInt("ACCthetimeleft") * 20
      draw.SimpleText("Time Left: " .. LocalPlayer():GetNWInt("ACCthetimeleft"), DermaDefault, ScrW() / 2-800, ScrH() / 2-390, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
      draw.SimpleText("Press R to Respawn on your Corpse,", DermaDefault, ScrW() / 2-800, ScrH() / 2-375, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
      draw.SimpleText("Press Space to Respawn on Spawn", DermaDefault, ScrW() / 2-800, ScrH() / 2-360, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
      surface.DrawRect(ScrW() / 2-900, ScrH() / 2-420, w, 20)
      surface.SetDrawColor(0,0,0,255)
      surface.DrawOutlinedRect(ScrW() / 2-900, ScrH() / 2-420, 200, 20)
    end
  end

  hook.Add("HUDPaint", "DrawACCHUD", DrawACCHUD)
end

hook.Add("DoPlayerDeath", "ACCChance", CheckifAsc )
hook.Add("TTTPrepareRound", "ACCRESET", ResettinAsc )
hook.Add("PlayerDeath", "ACCCHANCE", SecondChance )
hook.Add("TTTCheckForWin", "ACCCHECKFORWIN", CUSTOMWIN)

hook.Add("PlayerDisconnected", "ACCDisconnect", function(ply)
    if IsValid(ply) then
      ply.shouldacc = false
      ply:SetNWInt("ACCthetimeleft", 10)
      ply.NOWINACC = false
      ply.SecondChanceChance = 0
	  ply.RespawnCount = 2
      ply:SetNWBool("ACCCanRespawn", false)
      timer.Remove("TTTACC" .. ply:EntIndex())
    end
  end )

hook.Add("PlayerSpawn","ACCReset", function(ply)
    if IsValid(ply) and ply:IsTerror() then
      ply.shouldacc = false
      ply:SetNWInt("ACCthetimeleft", 10)
      ply.NOWINACC = false
      ply.SecondChanceChance = 0
      ply:SetNWBool("ACCCanRespawn", false)
      timer.Remove("TTTACC" .. ply:EntIndex())
    end
  end )

if CLIENT then
  net.Receive("ACCBuyed",function()
      local chance = net.ReadInt(8)
      chat.AddText( GetChances(local_RespawnCount, true) .. "Chance: ", Color(255,255,255), "You will be revived with a chance of " .. chance .. "% !" )
      chat.PlaySound()
    end)
  net.Receive("ACCKill",function()
      local chance = net.ReadInt(8)
      chat.AddText( GetChances(local_RespawnCount, true).. "Chance: ", Color(255,255,255), "Your chance of has been changed to " .. chance .. "% !" )
      chat.PlaySound()
    end)
  net.Receive("ACCRespawn",function()
      local respawn = net.ReadBool()
      if respawn then
        chat.AddText( GetChances(local_RespawnCount, true) .. "Chance: ", Color(255,255,255), "Press Reload to spawn at your body. Press Space to spawn at the map spawn." )
      else
        chat.AddText( GetChances(local_RespawnCount, true) .. "Chance: ", Color(255,255,255), "You will not be revived." )
      end
      chat.PlaySound()
    end)
  net.Receive("ACCError",function()
      local spawnpos = net.ReadBool()
      if spawnpos then
        chat.AddText( GetChances(local_RespawnCount, true) .. "Chance: ", COLOR_RED, "ERROR", COLOR_WHITE, ": " , Color(255,255,255), "Body not found! No respawn.")
      else
        chat.AddText( GetChances(local_RespawnCount, true) .. "Chance: ", COLOR_RED, "ERROR", COLOR_WHITE, ": " , Color(255,255,255), "No Valid Spawnpoints! Spawning at Map Spawn.")
      end
      chat.PlaySound()
    end)
  net.Receive("ACCRespawnCount", function()
	  local_RespawnCount = 2
	  local_RespawnCount = net.ReadInt(8)
	end)

    hook.Add("TTTBodySearchEquipment", "ACCCorpseIcon", function(search, eq)
        search.eq_acc = util.BitSet(eq, EQUIP_ACC)
      end )

    hook.Add("TTTBodySearchPopulate", "ACCCorpseIcon", function(search, raw)
        if (!raw.eq_acc) then
          return end

          local highest = 0
          for _, v in pairs(search) do
            highest = math.max(highest, v.p)
          end

          search.eq_acc = {img = "vgui/ttt/icon_acc", text = "They maybe will have a Second Chance...", p = highest + 1}
      end )
end
