::LearningWeapons.getThresholds <- function()
{
	local normal = ::LearningWeapons.Const.NormalThreshold;
	local special = ::LearningWeapons.Const.SpecialThreshold;

	if ("World" in getroottable() && ::World != null && !::MSU.isNull(::World) &&
		::World.Assets != null && !::MSU.isNull(::World.Assets) &&
		::World.Assets.getOrigin() != null &&
		::World.Assets.getOrigin().getID() == ::LearningWeapons.Const.TestScenarioID)
	{
		normal = ::LearningWeapons.Const.TestNormalThreshold;
		special = ::LearningWeapons.Const.TestSpecialThreshold;
	}

	return {
		Normal = normal,
		Special = special
	};
};

::LearningWeapons.getProgressSkill <- function( _actor )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return null;

	local skills = _actor.getSkills();
	if (skills == null)
		return null;

	local skill = skills.getSkillByID("special.learning_weapons_progress");

	if (skill == null)
	{
		skill = ::new("scripts/skills/special/learning_weapons_progress_skill");
		skills.add(skill);
	}

	return skill;
};

// Makes the perk tree match the recorded progress: weapon perk groups that have
// not been unlocked yet are removed and unlocked ones are restored.
//
// This is safe to call repeatedly and is used both when a brother is created
// and whenever the perk tree may have been rebuilt by another mod (Reforged, for
// example, rebuilds the perk trees of starting brothers after spawning them).
::LearningWeapons.applyProgressionToPerkTree <- function( _actor )
{
	if (_actor == null || ::MSU.isNull(_actor) || !::MSU.isKindOf(_actor, "player"))
		return;

	local perkTree = _actor.getPerkTree();
	if (perkTree == null)
		return;

	local skill = ::LearningWeapons.getProgressSkill(_actor);

	foreach (groupID in ::LearningWeapons.WeaponGroupIDs)
	{
		local unlocked = skill != null && skill.getProgress(groupID).Unlocked;

		if (unlocked)
		{
			if (!perkTree.hasPerkGroup(groupID))
				perkTree.addPerkGroup(groupID);
		}
		else if (perkTree.hasPerkGroup(groupID))
		{
			perkTree.removePerkGroup(groupID);
		}
	}
};

::LearningWeapons.getWeaponGroupsForWeapon <- function( _weapon )
{
	local ret = [];

	if (_weapon == null || ::MSU.isNull(_weapon))
		return ret;

	if (!_weapon.isItemType(::Const.Items.ItemType.Weapon))
		return ret;

	// Reforged maps the Firearm weapon type to the crossbow perk group, so a
	// weapon that is both (e.g. a firelance is a spear/firearm) can produce the
	// same group twice. Only count each managed group once.
	foreach (groupID in ::Reforged.getWeaponPerkGroups(_weapon))
	{
		if (ret.find(groupID) == null && ::LearningWeapons.WeaponGroupIDs.find(groupID) != null)
			ret.push(groupID);
	}

	return ret;
};

::LearningWeapons.getEquippedWeaponGroups <- function( _actor )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return [];

	local items = _actor.getItems();
	local weapon = items != null ? items.getItemAtSlot(::Const.ItemSlot.Mainhand) : null;
	return ::LearningWeapons.getWeaponGroupsForWeapon(weapon);
};

::LearningWeapons.getWeaponGroupsForSkill <- function( _skill, _actor )
{
	if (_skill == null || ::MSU.isNull(_skill))
		return [];

	local weapon = _skill.getItem();

	// Some weapon skills (e.g. Quick Shot or Deathblow) are granted by perks and
	// have no item of their own. They still use the equipped weapon, so fall
	// back to the mainhand weapon for weapon skills.
	if ((weapon == null || ::MSU.isNull(weapon)) && _skill.m.IsWeaponSkill && _actor != null && !::MSU.isNull(_actor))
	{
		local items = _actor.getItems();
		weapon = items != null ? items.getItemAtSlot(::Const.ItemSlot.Mainhand) : null;
	}

	return ::LearningWeapons.getWeaponGroupsForWeapon(weapon);
};

// Reads true remaining and maximum head/body armor directly from BaseProperties
// plus equipped Head/Body armor items. Inside actor.kill() (before Skills.update()
// has run, and before onDeath/dropAll unequips dead actors' gear), actor.getArmor()
// still holds pre-hit CurrentProperties values while BaseProperties.Armor alone
// misses equipped human/orc/undead armor items.
::LearningWeapons.getArmorState <- function( _actor )
{
	if (_actor == null || ::MSU.isNull(_actor))
	{
		return {
			Head = 0,
			HeadMax = 0,
			Body = 0,
			BodyMax = 0,
			BodyItemRatio = -1.0
		};
	}

	local baseProperties = _actor.m.BaseProperties;
	local innateHead = baseProperties != null ? baseProperties.Armor[::Const.BodyPart.Head] * baseProperties.ArmorMult[::Const.BodyPart.Head] : 0;
	local innateHeadMax = baseProperties != null ? baseProperties.ArmorMax[::Const.BodyPart.Head] * baseProperties.ArmorMult[::Const.BodyPart.Head] : 0;
	local innateBody = baseProperties != null ? baseProperties.Armor[::Const.BodyPart.Body] * baseProperties.ArmorMult[::Const.BodyPart.Body] : 0;
	local innateBodyMax = baseProperties != null ? baseProperties.ArmorMax[::Const.BodyPart.Body] * baseProperties.ArmorMult[::Const.BodyPart.Body] : 0;

	local items = _actor.getItems();
	local headItem = items != null ? items.getItemAtSlot(::Const.ItemSlot.Head) : null;
	local bodyItem = items != null ? items.getItemAtSlot(::Const.ItemSlot.Body) : null;

	local itemHead = headItem != null ? headItem.getArmor() : 0;
	local itemHeadMax = headItem != null ? headItem.getArmorMax() : 0;
	local itemBody = bodyItem != null ? bodyItem.getArmor() : 0;
	local itemBodyMax = bodyItem != null ? bodyItem.getArmorMax() : 0;

	return {
		Head = innateHead + itemHead,
		HeadMax = innateHeadMax + itemHeadMax,
		Body = innateBody + itemBody,
		BodyMax = innateBodyMax + itemBodyMax,
		BodyItemRatio = itemBodyMax > 0 ? (itemBody * 1.0 / itemBodyMax) : -1.0
	};
};

// Checks whether an enemy at _victimTile is engaged in melee with any unit
// friendly to _killer. Evaluated before onDeath so positions and ZoC are intact.
::LearningWeapons.isEnemyEngagedWithFriendly <- function( _victim, _victimTile, _killer, _victimHadZoC )
{
	if (_victim == null || _victimTile == null || _killer == null)
		return false;

	if (_victimTile.Properties.Effect != null && _victimTile.Properties.Effect.Type == "smoke")
		return false;

	for (local i = 0; i != 6; i = ++i)
	{
		if (!_victimTile.hasNextTile(i))
			continue;

		local nextTile = _victimTile.getNextTile(i);
		if (!nextTile.IsOccupiedByActor)
			continue;

		if (::Math.abs(_victimTile.Level - nextTile.Level) > 1)
			continue;

		if (nextTile.Properties.Effect != null && nextTile.Properties.Effect.Type == "smoke")
			continue;

		local entity = nextTile.getEntity();
		if (entity == null || !entity.isAlive() || entity.isDying() || entity.isNonCombatant())
			continue;

		if (!_killer.isAlliedWith(entity))
			continue;

		if (entity.hasZoneOfControl() || _victimHadZoC)
			return true;
	}

	return false;
};

// Evaluates kill-based special achievements. Polearms (Savior) and Hammers
// (Can Opener) are non-kill achievements handled in their own hooks.
::LearningWeapons.isSpecialKill <- function( _groupID, _data )
{
	switch (_groupID)
	{
	case "pg.rf_axe":
		return _data.LastHitBodyPart == ::Const.BodyPart.Head;

	case "pg.rf_bow":
		return _data.Range >= 5;

	case "pg.rf_cleaver":
		return _data.FatalityType == ::Const.FatalityType.Decapitated && _data.WasBleeding;

	case "pg.rf_crossbow":
		return _data.ArmorHead > 0 && _data.ArmorBody > 0;

	case "pg.rf_dagger":
		return _data.BodyArmorRatio >= 0.75;

	case "pg.rf_flail":
		return _data.HasShield && _data.LastHitBodyPart == ::Const.BodyPart.Head;

	case "pg.rf_mace":
		return _data.IsStunned;

	case "pg.rf_spear":
		return _data.IsSpearwalling;

	case "pg.rf_sword":
		return _data.IsRiposting;

	case "pg.rf_throwing":
		return _data.Range == 2 && !_data.WasEngagedWithFriendly;
	}

	return false;
};

::LearningWeapons.checkUnlock <- function( _actor, _groupID )
{
	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return;

	local progress = skill.getProgress(_groupID);
	local thresholds = ::LearningWeapons.getThresholds();

	if (!progress.Unlocked && progress.Kills >= thresholds.Normal && progress.SpecialKills >= thresholds.Special)
	{
		progress.Unlocked = true;

		local perkTree = _actor.getPerkTree();
		if (perkTree != null && !perkTree.hasPerkGroup(_groupID))
		{
			perkTree.addPerkGroup(_groupID);

			if (::Tactical.isActive() && ("EventLog" in ::Tactical) && ::Tactical.EventLog != null)
			{
				local perkGroup = ::DynamicPerks.PerkGroups.findById(_groupID);
				local name = perkGroup != null ? perkGroup.getName() : _groupID;
				::Tactical.EventLog.log("[b]" + ::Const.UI.getColorizedEntityName(_actor) + " has unlocked the [color=" + ::Const.UI.Color.PositiveValue + "]" + name + "[/color] perk group![/b]");
			}
		}
	}
};

::LearningWeapons.completeAchievement <- function( _actor, _groupID, _deferUnlockCheck = false )
{
	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return;

	local progress = skill.getProgress(_groupID);
	if (progress.SpecialKills < 1)
	{
		progress.SpecialKills = 1;

		if (::Tactical.isActive() && ("EventLog" in ::Tactical) && ::Tactical.EventLog != null)
		{
			local achievement = (_groupID in ::LearningWeapons.Achievements) ? ::LearningWeapons.Achievements[_groupID] : null;
			local achievementName = achievement != null ? achievement.Name : _groupID;
			::Tactical.EventLog.log("[b]" + ::Const.UI.getColorizedEntityName(_actor) + " completed the [color=" + ::Const.UI.Color.PositiveValue + "]" + achievementName + "[/color] achievement![/b]");
		}
	}

	if (!_deferUnlockCheck)
		::LearningWeapons.checkUnlock(_actor, _groupID);
};

::LearningWeapons.addKill <- function( _actor, _groupID, _isSpecial )
{
	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return;

	local progress = skill.getProgress(_groupID);
	progress.Kills = progress.Kills + 1;

	if (_isSpecial)
		::LearningWeapons.completeAchievement(_actor, _groupID, true);

	::LearningWeapons.checkUnlock(_actor, _groupID);
};

// ---------------------------------------------------------------------------
// Transient combat state
//
// This is deliberately kept outside of the actor's `m` table. Adding new fields
// to engine objects at runtime is not safe (some of them are class instances and
// reject unknown fields), and this data must never end up in a savegame.
// Entries are keyed by entity ID and cleaned up when used or when combat ends.
// ---------------------------------------------------------------------------
::LearningWeapons.Transient <- {
	LastHitBodyPart = {},
	PreHitInfo = {},
	DeathInfo = {},
	PostHitArmorOnDeath = {},
	Riposting = {},
	Spearwalling = {},
	Displaced = {},
	CanOpener = {}
};

::LearningWeapons.storeTransient <- function( _store, _actor, _value )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return;

	_store.rawset(_actor.getID(), _value);
};

::LearningWeapons.loadTransient <- function( _store, _actor, _default = null )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return _default;

	local id = _actor.getID();
	return _store.rawin(id) ? _store.rawget(id) : _default;
};

::LearningWeapons.clearTransient <- function( _store, _actor )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return;

	local id = _actor.getID();
	if (_store.rawin(id))
		_store.rawdelete(id);
};

::LearningWeapons.clearAllTransientForActor <- function( _actor )
{
	if (_actor == null || ::MSU.isNull(_actor))
		return;

	foreach (_, store in ::LearningWeapons.Transient)
	{
		::LearningWeapons.clearTransient(store, _actor);
	}
};

::LearningWeapons.resetTransient <- function()
{
	foreach (_, store in ::LearningWeapons.Transient)
	{
		store.clear();
	}
};

::LearningWeapons.registerNestedTooltips <- function()
{
	local achievementTooltips = {};

	foreach (_, achievement in ::LearningWeapons.Achievements)
	{
		achievementTooltips[achievement.Key] <- ::MSU.Class.BasicTooltip(
			achievement.Name,
			::Reforged.Mod.Tooltips.parseString(achievement.Description)
		);
	}

	::Reforged.NestedTooltips.Tooltips.LearningWeaponsAchievement <- achievementTooltips;
	::Reforged.Mod.Tooltips.setTooltips(::Reforged.NestedTooltips.Tooltips);
	::LearningWeapons.TooltipsRegistered = true;
};

::LearningWeapons.getTooltipEntries <- function( _actor )
{
	if (!::LearningWeapons.TooltipsRegistered)
		::LearningWeapons.registerNestedTooltips();

	// The tooltip is the only place the player can see the progress, so make sure
	// the perk tree is in sync even if another mod rebuilt it in the meantime.
	::LearningWeapons.applyProgressionToPerkTree(_actor);

	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return [];

	local thresholds = ::LearningWeapons.getThresholds();
	local killTargetText = thresholds.Normal == 1 ? "1 kill" : (thresholds.Normal + " kills");
	local ret = [
		{
			id = 99,
			type = "header",
			text = "Weapon Progression"
		},
		{
			id = 100,
			type = "text",
			text = ::Reforged.Mod.Tooltips.parseString("Unlock a weapon perk group by getting " + killTargetText + " and completing its special achievement while wielding that weapon type ([hybrid weapons|Concept.HybridWeapon] count for both).")
		}
	];

	local id = 101;
	foreach (groupID in ::LearningWeapons.WeaponGroupIDs)
	{
		local progress = skill.getProgress(groupID);
		local perkGroup = ::DynamicPerks.PerkGroups.findById(groupID);
		local name = perkGroup != null ? perkGroup.getName() : groupID;
		local achievement = (groupID in ::LearningWeapons.Achievements) ? ::LearningWeapons.Achievements[groupID] : null;
		local achievementDone = progress.SpecialKills >= thresholds.Special;

		local checkIcon = achievementDone
			? "<span class='lw-achievement-status'>[img]gfx/ui/icons/unlocked_small.png[/img]</span>"
			: "<span class='lw-achievement-status'>[img]gfx/ui/icons/cancel.png[/img]</span>";
		local achievementText = achievement != null
			? ::Reforged.Mod.Tooltips.parseString(format("Complete [%s|LearningWeaponsAchievement.%s]", achievement.Name, achievement.Key))
			: "Complete achievement";
		local status = progress.Unlocked ? " [color=" + ::Const.UI.Color.PositiveValue + "]Unlocked[/color]" : "";

		ret.push({
			id = id,
			type = "text",
			icon = "ui/icons/special.png",
			rawHTMLInText = true,
			text = name + ": " + progress.Kills + "/" + thresholds.Normal + " kills, " + checkIcon + " " + achievementText + status
		});

		id = id + 1;
	}

	return ret;
};
