resource.AddFile("sound/events/fish1.ogg")
resource.AddFile("sound/events/you_know_what_that_means.ogg")
resource.AddFile("sound/ambient/atmosphere/terrain_rumble1.wav")
resource.AddFile("models/events/fishey.mdl")

local fishingPlayers = {}
local noNoclipPlayers = {}

local function SpawnAndFlingFish(target)
    if not IsValid(target) then return end

    target:EmitSound("events/fish1.ogg", 75, 100)

    local fish = ents.Create("prop_physics")
    if IsValid(fish) then
        fish:SetModel("models/events/fishey.mdl")

        local angle = math.rad(math.random(0, 360))
        local radius = math.random(100, 180)
        local spawnPos = target:GetPos() + Vector(math.cos(angle) * radius, math.sin(angle) * radius, math.random(50, 100))

        fish:SetPos(spawnPos)

        local randAngle = Angle(math.random(0, 360), math.random(0, 360), math.random(0, 360))
        fish:SetAngles(randAngle)

        fish:Spawn()
        fish:Activate()

        local targetPos = target:EyePos() or target:GetPos()
        local direction = (targetPos - spawnPos):GetNormalized()
        local phys = fish:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetBuoyancyRatio(0)
            phys:ApplyForceCenter(direction * 9000)
        end

        timer.Simple(5, function()
            if IsValid(fish) then
                fish:Remove()
            end
        end)
    end
end

local function StartFishFlinging(target, interval)
    local fishTimer = "FishFling_" .. target:EntIndex()
    timer.Create(fishTimer, interval, 0, function()
        if not IsValid(target) or target:Health() <= 0 then
            timer.Remove(fishTimer)
            fishingPlayers[target:SteamID()] = nil
            return
        end
        SpawnAndFlingFish(target)
    end)
end

local function StopFishFlinging(target)
    local fishTimer = "FishFling_" .. target:EntIndex()
    timer.Remove(fishTimer)
end

local function ShakePlayerCamera(target)
    if not IsValid(target) then return end
    util.ScreenShake(target:GetPos(), 50, 50, 7.5, 500)
end

local function SetupTimers(target, multiplier)
    multiplier = multiplier / 2
    local finalEventTimer = "FinalEvent_" .. target:EntIndex()

    local initialInterval = 0.2 / multiplier
    local rampUpRate = 0.005
    local eventDuration = 30

    timer.Create("RampUpFishFlinging", 1, 0, function()
        if not IsValid(target) or target:Health() <= 0 then
            timer.Remove("RampUpFishFlinging")
            StopFishFlinging(target)
            return
        end

        initialInterval = initialInterval - rampUpRate
        if initialInterval < 0.05 then initialInterval = 0.05 end

        StopFishFlinging(target)
        StartFishFlinging(target, initialInterval)
    end)

    timer.Create(finalEventTimer, eventDuration, 1, function()
        if IsValid(target) and target:Health() > 0 then
            timer.Remove("RampUpFishFlinging")
            StopFishFlinging(target)
            target:EmitSound("ambient/atmosphere/terrain_rumble1.wav")
            ShakePlayerCamera(target)

            timer.Simple(1, function()
                if not IsValid(target) then return end

                local Jeoff = ents.Create("prop_physics")
                if IsValid(Jeoff) then
                    Jeoff:SetModel("models/events/fishey.mdl")
                    Jeoff:SetModelScale(20, 0)
                    Jeoff:SetPos(target:GetPos())
                    Jeoff:Spawn()
                    Jeoff:Activate()

                    Jeoff:EmitSound("events/fish1.ogg", 100, 25)
                    Jeoff:EmitSound("events/fish1.ogg", 100, 25)
                    Jeoff:EmitSound("events/fish1.ogg", 100, 25)
                    Jeoff:EmitSound("events/fish1.ogg", 100, 25)
                    Jeoff:EmitSound("physics/metal/metal_large_debris1.wav", 100, 100)
                    target:Kill()

                    hook.Add("PlayerSpawn", "RemoveBigFish_" .. target:EntIndex(), function(ply)
                        if ply == target then
                            if IsValid(Jeoff) then
                                Jeoff:Remove()
                            end
                            hook.Remove("PlayerSpawn", "RemoveBigFish_" .. target:EntIndex())
                        end
                    end)
                end
            end)
        end
    end)

    hook.Add("PlayerDeath", "ResetFishFling_" .. target:EntIndex(), function(ply)
        if ply == target then
            StopFishFlinging(target)
            timer.Remove("RampUpFishFlinging")
            timer.Remove(finalEventTimer)
            fishingPlayers[target:SteamID()] = nil
            hook.Remove("PlayerDeath", "ResetFishFling_" .. target:EntIndex())
            hook.Remove("PlayerSpawn", "RemoveBigFish_" .. target:EntIndex())
        end
    end)
end

local function DousePlayerWithFish(target, multiplier)
    multiplier = multiplier / 2
    target:EmitSound("events/you_know_what_that_means.ogg")

    timer.Simple(1.3, function()
        if not IsValid(target) or target:Health() <= 0 then
            fishingPlayers[target:SteamID()] = nil
            return
        end
        StartFishFlinging(target, 0.2 / multiplier)
        SetupTimers(target, multiplier)
    end)
end

local function LockPlayerMovement(target, lock)
    if lock then
        target:SetMoveType(MOVETYPE_NONE)
    else
        target:SetMoveType(MOVETYPE_WALK)
    end
end

local function DisableNoclip(target)
    target:SetMoveType(MOVETYPE_WALK)
    noNoclipPlayers[target:SteamID()] = true
end

local function EnableNoclip(target)
    noNoclipPlayers[target:SteamID()] = nil
end

hook.Add("PlayerNoClip", "DisableNoclipForPlayers", function(ply)
    if noNoclipPlayers[ply:SteamID()] then
        return false
    end
end)

-- notetoself - add ulx stopfishing

function ulx.fish(calling_ply, target_ply, amount, disable_noclip, lock_movement)
    if not IsValid(target_ply) or target_ply:Health() <= 0 then
        ULib.tsayError(calling_ply, "Cannot fish a dead player!")
        return
    end

    if fishingPlayers[target_ply:SteamID()] then
        ULib.tsayError(calling_ply, "Player is already being fished!", target_ply)
        return
    end

    fishingPlayers[target_ply:SteamID()] = true
    ulx.fancyLogAdmin(calling_ply, "#A fished #T!", target_ply, amount)
    DousePlayerWithFish(target_ply, amount)

    if disable_noclip then
        DisableNoclip(target_ply)
    end

    if lock_movement then
        LockPlayerMovement(target_ply, true)
    end

    hook.Add("PlayerDeath", "UnlockMovementOnDeath_" .. target_ply:EntIndex(), function(ply)
        if ply == target_ply then
            if lock_movement then
                LockPlayerMovement(target_ply, false)
            end
            if disable_noclip then
                EnableNoclip(target_ply)
            end
            fishingPlayers[target_ply:SteamID()] = nil
            hook.Remove("PlayerDeath", "UnlockMovementOnDeath_" .. target_ply:EntIndex())
        end
    end)
end

local fish = ulx.command("Fun", "ulx fish", ulx.fish, "!fish")
fish:addParam{type = ULib.cmds.PlayerArg}
fish:addParam{type = ULib.cmds.NumArg, hint = "fish amount", min = 1, max = 10, default = 4, ULib.cmds.round}
fish:addParam{type = ULib.cmds.BoolArg, hint = "disable noclip", ULib.cmds.optional}
fish:addParam{type = ULib.cmds.BoolArg, hint = "lock movement", ULib.cmds.optional}
fish:defaultAccess(ULib.ACCESS_ADMIN)
fish:help("Fling fish at a player until they die.")
