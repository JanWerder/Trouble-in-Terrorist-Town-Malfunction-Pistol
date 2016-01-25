
AddCSLuaFile()

SWEP.HoldType			= "pistol"

if CLIENT then
   SWEP.PrintName = "Malfunction Pistol"
   SWEP.Slot = 6

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "Forces the player you shoot to fire\na uncontrolled round of shots."
   };

   SWEP.Icon = "vgui/ttt/icon_malfunction"
   SWEP.IconLetter = "a"
end

SWEP.Base = "weapon_tttbase"
SWEP.Primary.Recoil	= 1.35
SWEP.Primary.Damage = 0
SWEP.Primary.Delay = 0.38
SWEP.Primary.Cone = 0.02
SWEP.Primary.ClipSize = 3
SWEP.Primary.Automatic = true
SWEP.Primary.DefaultClip = 3
SWEP.Primary.ClipMax = 3

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID = AMMO_MALFUNCTIONGUN

SWEP.IsSilent = true

SWEP.UseHands			= true
SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 54
SWEP.ViewModel  = "models/weapons/cstrike/c_pist_fiveseven.mdl"
SWEP.WorldModel = "models/weapons/w_pist_fiveseven.mdl"

SWEP.Primary.Sound = Sound( "weapons/usp/usp1.wav" )
SWEP.Primary.SoundLevel = 50

SWEP.IronSightsPos = Vector( -5.91, -4, 2.84 )
SWEP.IronSightsAng = Vector(-0.5, 0, 0)

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED

function SWEP:Deploy()
   self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
   return true
end

-- We were bought as special equipment, and we have an extra to give
function SWEP:WasBought(buyer)
   if IsValid(buyer) then -- probably already self.Owner
      buyer:GiveAmmo( 3, "Pistol" )
   end
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

   if not self:CanPrimaryAttack() then return end

   self:EmitSound( self.Primary.Sound )

   self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

   self:ShootMalfunctionBullet()

   self:TakePrimaryAmmo( 1 )

   if IsValid(self.Owner) then
      self.Owner:SetAnimation( PLAYER_ATTACK1 )

      self.Owner:ViewPunch( Angle( math.Rand(-0.2,-0.1) * self.Primary.Recoil, math.Rand(-0.1,0.1) *self.Primary.Recoil, 0 ) )
   end

   if ( (game.SinglePlayer() && SERVER) || CLIENT ) then
      self:SetNetworkedFloat( "LastShootTime", CurTime() )
   end
end

function SWEP:ShootMalfunctionBullet()
  local cone = self.Primary.Cone
  local bullet = {}
  bullet.Num       = 1
  bullet.Src       = self.Owner:GetShootPos()
  bullet.Dir       = self.Owner:GetAimVector()
  bullet.Spread    = Vector( cone, cone, 0 )
  bullet.Tracer    = 1
  bullet.Force     = 2
  bullet.Damage    = self.Primary.Damage
  bullet.TracerName = self.Tracer
  bullet.Callback = ForceTargetToShoot

  self.Owner:FireBullets( bullet )
end

function ForceTargetToShoot(ply, path, dmginfo)
  local ent = path.Entity
  if not IsValid(ent) then return end

  if CLIENT and IsFirstTimePredicted() then
     if ent:GetClass() == "prop_ragdoll" then
        ScorchUnderRagdoll(ent)
     end
     return
  end

  if SERVER then

     local dur = ent:IsPlayer() and 5 or 10

     -- disallow if prep or post round
     if ent:IsPlayer() and (not GAMEMODE:AllowPVP()) then return end

     if ent:IsPlayer() then

       local repeats = 1
        if ent:GetActiveWeapon().Primary.ClipSize < 0 then
          local weapons = ent:GetWeapons()
          local preferedWeapons =  {}
          for i=4,#weapons do
            if weapons[i] then
              if weapons[i]:GetClass() ~= "weapon_ttt_confgrenade" and weapons[i]:GetClass() ~= "weapon_ttt_smokegrenade" and weapons[i]:GetClass() ~= "weapon_zm_molotov" then
                  table.insert(preferedWeapons,i)
              end
            end
          end

          if #preferedWeapons > 0 then
          ent:SelectWeapon(weapons[preferedWeapons[math.random(1, #preferedWeapons)]]:GetClass())

          local clipsize = ent:GetActiveWeapon().Primary.ClipSize
          repeats = (clipsize/2)+math.random(-clipsize*0.05,clipsize*0.05)
          else
            repeats = 6
          end
        else
          local clipsize = ent:GetActiveWeapon().Primary.ClipSize
          repeats = (clipsize/2)+math.random(-clipsize*0.05,clipsize*0.05)
        end

        ent.isUnderMalfunctionInfluence = ply
        print(ent:GetActiveWeapon().Primary.Delay*repeats+0.1)
        timer.Create("influenceDisable", ent:GetActiveWeapon().Primary.Delay*repeats+0.1, 1,
        function()
          ent.isUnderMalfunctionInfluence = nil
        end)

        timer.Create("burstFire", ent:GetActiveWeapon().Primary.Delay, repeats,
        function()
          ent:GetActiveWeapon():PrimaryAttack()
        end)


     end
  end
end

function EntityTakeDamage( target, dmg )
  if dmg:GetAttacker().isUnderMalfunctionInfluence and isActivatedPreventsWrongDamageLogs then
    dmg:SetAttacker(dmg:GetAttacker().isUnderMalfunctionInfluence)
  end
end

hook.Add( "EntityTakeDamage", "PreventsWrongDamageLogs", EntityTakeDamage )

isActivatedPreventsWrongDamageLogs = true
concommand.Add( "ttt_malfunction_pistol_allocate_damage_to_traitor", function( ply, cmd, args )
	if args[1] == 1 then
    isActivatedPreventsWrongDamageLogs = true
  else
    isActivatedPreventsWrongDamageLogs = false
  end
end, AutoComplete )

function AutoComplete(cmd, stringargs)
  local tbl = {}
  table.insert(tbl, "ttt_malfunction_pistol_allocate_damage_to_traitor 1")
  table.insert(tbl, "ttt_malfunction_pistol_allocate_damage_to_traitor 0")
  return tbl
end
