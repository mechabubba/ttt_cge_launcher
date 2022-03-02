-- https://func.zone
AddCSLuaFile()

if CLIENT then
   SWEP.PrintName = "CGE Launcher"
   SWEP.Slot = 6
   SWEP.ViewModelFOV = 72
   SWEP.ViewModelFlip = false
   SWEP.Icon = "vgui/ttt/icon_cge"
   SWEP.EquipMenuData = {
      type = "Weapon",
      desc = "Stands for \"Concussion Grenade Launcher\"; a crowd\ncontrol weapon.\nFires non-lethal disorenting grenades, which explode\non impact with another player."
   }
end

-- Apparently, Sound() doesn't actually precache anything except for sound scripts.
sound.Add({ name = "cge_explosion1", sound = "glauncher/glauncher1.wav" })
sound.Add({ name = "cge_explosion2", sound = "glauncher/glauncher2.wav" })

SWEP.Base = "weapon_tttbase"
SWEP.ViewModel = "models/weapons/v_smg1.mdl"
SWEP.WorldModel = "models/weapons/w_smg1.mdl"
SWEP.HoldType = "smg"

SWEP.Primary.Delay = 0.5
SWEP.Primary.Recoil = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.025
SWEP.Primary.ClipSize = 10
SWEP.Primary.ClipMax = 10
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Sound  = Sound("cge_explosion1")
SWEP.Primary.Sound2 = Sound("cge_explosion2")
SWEP.Primary.Empty  = Sound("Weapon_SMG1.Empty")

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = { ROLE_DETECTIVE, ROLE_TRAITOR }
SWEP.AutoSpawnable = false
SWEP.InLoadoutFor = nil
SWEP.LimitedStock = false
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.IronSightsPos = Vector(-3.58, -9.2, 2.55)
SWEP.IronSightsAng = Vector(2.599, -2.3, -3.6)

function SWEP:CanPrimaryAttack()
   if self:Clip1() <= 0 then
      self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
      self:EmitSound(self.Primary.Empty)
      return false
   end

   return true
end

function SWEP:PrimaryAttack()
   if not self:CanPrimaryAttack() then return end

   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
   self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

   if SERVER then
      local owner = self:GetOwner()
      self:EmitSound(math.random() > 0.5 and self.Primary.Sound or self.Primary.Sound2)
      owner:ViewPunch(Angle(util.SharedRandom(self:GetClass(), -0.2, -0.1, 0) * self.Primary.Recoil, util.SharedRandom(self:GetClass(), -0.1, 0.1, 1) * self.Primary.Recoil, 0))

      self:LaunchGrenade()
      self:TakePrimaryAmmo(1)
   end
end

function SWEP:LaunchGrenade()
   local conc = ents.Create("ttt_cge_proj")
   if not IsValid(conc) then return end

   local owner = self:GetOwner()
   conc:SetOwner(owner)
   conc:SetPos(owner:GetShootPos())
   conc:Spawn()

   local phys = conc:GetPhysicsObject()
   if not IsValid(phys) then conc:Remove() return end

   local velocity = owner:GetAimVector()
   phys:SetVelocity((velocity * 1500) + (VectorRand() * 10)) -- random cone
end