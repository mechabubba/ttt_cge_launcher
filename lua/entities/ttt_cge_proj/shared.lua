-- this is pretty much just a hacked together discombob entity w/ some experimentation
AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

ENT.Type = "anim"
ENT.Model = Model("models/weapons/w_eq_fraggrenade_thrown.mdl")

if SERVER then
	util.AddNetworkString("cge_debug")
end

local zzzap = Sound("npc/assassin/ball_zap1.wav") -- ZAP

local config = {
	radius = 400,       -- number, radius of the sphere in which props will be affected.
	fuse = {
		enable = false, -- boolean, whether to enable the grenade fuse.
		time = 5        -- number, the grenade fuse, aka the time until explosion.
	},
	amplifier = 2000,   -- number, testing...
	push_force = 256,   -- number, force applied to players.
	push_force_phys = 1500, -- number, force applied to physics props.
	up_force_mult = 3   -- number, up force multiplier, applied to any affected props.
}

local function dprint(...)
	print("[ttt_cge_proj]", unpack(...))
end

function ENT:Initialize()
	self:SetModel(self.Model)
	if SERVER then self:PhysicsInit(SOLID_VPHYSICS) end
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()

	if IsValid(phys) then
		phys:Wake()
		if config.fuse.enable then
			timer.Simple(config.fuse.time, function()
				if IsValid(self) then
					dprint("exploded on fuse, BOOM !!!")
					self:Explode(nil)
				end
			end)
		end
	end
end

--[[
	# how this fucker should work
	1) get pos of every entity in a range
	2) get force vector for each player
	2.5) add a *smidgeon* of upward force
	3) get norms, clamp them in a range; x = (x > 0.1) and ((x < 3000) and x or 3000) or 0
	3.5) if norm is zero, dont do anything
	4) apply force to entities. Entity.SetVelocity is for players, PhysicsObject.ApplyForceCenter is for physics props

	# whats going on here
	- each entity has a vector representing its position in a 3d "field"
	- we pretend the origin is the explosions vector (lets just say 0, 0, 0)
	- from there we take the relative positions of each entity within a range and plug them into the vector field
	- the norm of the vector from our vector field is our *velocity;* as we get closer to the center, the norm increases exponentially
	- the output we get from the vector field is the velocity broken into its x y and z components
	- we simply add that to the players velocity and we're hundo skundo

	# why its not working
	i dont know.

	```lua
	-- code example
	local origin = explosion_origin;
	local pos = affected_ent_pos;
	local rel = origin - pos;

	local force = Vector()
	force.x = amplifier * (x / (x^2 + y^2 + z^2))
	force.y = amplifier * (y / (x^2 + y^2 + z^2))
	force.z = amplifier * ((z * 4) / (x^2 + y^2 + z^2))
	-- the LengthSqr() operation is just (x^2 + y^2 + z^2). 
	-- square rooting the above value is the Length() operation and would make them all unit vectors.

	-- f[x, y, z] = { -- vector field. see visually (slightly modified for the third dimension): https://media.discordapp.net/attachments/907023115744317490/908792729650200626/unknown.png
	--     amplifier * (x / (x^2 + y^2 + z^2)),
	--     amplifier * (y / (x^2 + y^2 + z^2)),
	--     amplifier * (z / (x^2 + y^2 + z^2))
	-- }
	force = rel + force -- apply force onto relative position
	```
]]

function ENT:Explode(hit)
	if SERVER then
		if not IsValid(self) then return end

		local rad = config.radius
		local origin = self:GetPos() -- the origin is the explosions position.
		local cube = ents.FindInBox(origin - Vector(rad, rad, rad), origin + Vector(rad, rad, rad))

		dprint("origin:", origin)

		--[[
		net.Start("cge_debug")
			net.WriteEntity(self)
			net.WriteVector(origin)
			net.WriteVector(Vector(-rad, -rad, -rad))
			net.WriteVector(Vector(rad, rad, rad))
		net.Broadcast()
		]]

		for _, ent in ipairs(cube) do
			if ent == self then continue end
			if IsValid(ent) then
				local phys = ent:GetPhysicsObject()
				if not IsValid(phys) then continue end

				local pos = ent:GetPos() -- the entitys position.
				local rel = origin - pos -- the entitys position relative to explosion. this is what we want to do math on.

				local force = Vector()
				force.x = config.amplifier * (rel.x / rel:LengthSqr())
				force.y = config.amplifier * (rel.y / rel:LengthSqr())
				force.z = config.amplifier * (rel.z / rel:LengthSqr()) + 200

				-- check to see if its a good idea to do this (generally not if theres no force or we're dividing by zero somewhere)
				local length = force:Length()
				if length == 0 or length == math.huge then continue end
				force = rel + force -- this is a vector pointing from the entities position relative to the explosion to where they should be flung.

				-- now we can apply this force to the player.
				if ent:IsPlayer() and not ent:IsFrozen() then
					dprint("-----------")
					dprint("# " .. ent:GetName())
					dprint("entity pos:", pos)
					dprint("       rel:", rel)
					dprint("     force:", force)
					dprint("-----------")
					ent:SetVelocity(force) -- this *adds* velocity, not sets it.
				elseif IsValid(phys) then
					phys:ApplyForceCenter(force)
				end
			end
		end

		self:Remove()
		sound.Play(zzzap, origin, 100, 100)

		local effect = EffectData()
		effect:SetStart(origin)
		effect:SetOrigin(origin)
		util.Effect("Explosion", effect, true, true)
		util.Effect("cball_explode", effect, true, true)
	end
end

--[[
-- old one, mostly stolen from ttt_confgrenade_proj.lua in the ttt source
-- 
function ENT:Explode(hit)
	if SERVER then
		if not IsValid(self) then return end

		local origin = self:GetPos()
		local sphere = ents.FindInSphere(origin, config.radius) 

		self:Remove()

		for _, obj in ipairs(sphere) do
			if IsValid(obj) then
				local obj_pos = obj:LocalToWorld(obj:OBBCenter())
				-- local distance = obj:Distance(origin)
				local direction = (obj_pos - origin):GetNormal()
				local phys = obj:GetPhysicsObject()
			
				if obj:IsPlayer() and not obj:IsFrozen() then
					local push = direction * config.push_force -- direction * ((radius / distance) * push_force)
					local up_force = 2

					if IsValid(hit) and hit:IsPlayer() and obj == hit then
						-- give the hit player a bit of a higher up force
						up_force = up_force * config.up_force_multiplier
					end
					push.z = math.abs(push.z) + up_force

					-- (un)comment if you want to prevent excessive upwards force
					--local vel = target:GetVelocity() + push
					--vel.z = math.min(vel.z, push_force)

					obj:SetVelocity(obj:GetVelocity() + push)

				elseif IsValid(phys) then
					phys:ApplyForceCenter(direction * -1 * config.push_force_phys)
				end
			end
		end
		sound.Play(zzzap, origin, 100, 100)

		local effect = EffectData()
		effect:SetStart(origin)
		effect:SetOrigin(origin)
		util.Effect("Explosion", effect, true, true)
		util.Effect("cball_explode", effect, true, true)
	end
end
]]

function ENT:PhysicsCollide(data, phys)
	if self.touched then
		return false
	else
		self.touched = true
	end

	if config.fuse.enable then
		if data.HitEntity:IsPlayer() then
			-- https://forum.facepunch.com/gmoddev/nzjt/Changing-collision-rules-within-a-callback-is-likely-to-cause-crashes/1/
			timer.Simple(0, function()
				dprint("collided with " .. data.HitEntity:Name() .. ", BOOM !!!")
				self:Explode(data.HitEntity)
			end)
		end
	else
		timer.Simple(0, function()
			dprint("collided with ground, BOOM !!!")
			self:Explode(data.HitEntity)
		end)
	end
end

function ENT:Draw()
	self:DrawModel()
	-- debug shit lmao
	--[[
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Right(), 90)
	render.DrawBox(self:GetPos(), ang, self:GetPos() - Vector(config.radius, config.radius, config.radius), self:GetPos() + Vector(config.radius, config.radius, config.radius), Color(0, 255, 0, 127))
	]]
end

-- more debug shit lmao
--[[
if CLIENT then
	net.Receive("cge_debug", function(len, ply)
		print("cube time")
		local ent = net.ReadEntity()
		local origin = net.ReadVector()
		local vec1 = net.ReadVector() -- min
		local vec2 = net.ReadVector() -- max

		local ang = ent:GetAngles()
		ang:RotateAroundAxis(ent:GetAngles():Right(), 90)
		--cam.Start3D(EyePos(), ang, 0.1)
			render.DrawBox(origin, EyeAngles(), vec1, vec2, Color(0, 255, 0, 127))
		--cam.End3D()
	end)
end
]]