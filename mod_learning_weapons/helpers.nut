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

::LearningWeapons.getWeaponGroupsForSkill <- function( _skill, _actor )
{
	local ret = [];

	if (_skill == null || ::MSU.isNull(_skill))
		return ret;

	local weapon = _skill.getItem();

	// Some weapon skills (e.g. Quick Shot or Deathblow) are granted by perks and
	// have no item of their own. They still use the equipped weapon, so fall
	// back to the mainhand weapon for weapon skills.
	if ((weapon == null || ::MSU.isNull(weapon)) && _skill.m.IsWeaponSkill && _actor != null && !::MSU.isNull(_actor))
	{
		local items = _actor.getItems();
		weapon = items != null ? items.getItemAtSlot(::Const.ItemSlot.Mainhand) : null;
	}

	if (weapon == null || ::MSU.isNull(weapon))
		return ret;

	if (!weapon.isItemType(::Const.Items.ItemType.Weapon))
		return ret;

	// Reforged maps the Firearm weapon type to the crossbow perk group, so a
	// weapon that is both (e.g. a firelance is a spear/firearm) can produce the
	// same group twice. Only count each managed group once per kill.
	foreach (groupID in ::Reforged.getWeaponPerkGroups(weapon))
	{
		if (ret.find(groupID) == null && ::LearningWeapons.WeaponGroupIDs.find(groupID) != null)
			ret.push(groupID);
	}

	return ret;
};

// The dagger/hammer/mace/spear rules were added on top of the initial weapon
// list because Reforged also has perk groups for those weapon types.
::LearningWeapons.isSpecialKill <- function( _groupID, _data )
{
	switch (_groupID)
	{
	case "pg.rf_axe":
		return _data.LastHitBodyPart == ::Const.BodyPart.Head;

	case "pg.rf_bow":
		return _data.Range >= 5;

	case "pg.rf_cleaver":
		return _data.FatalityType == ::Const.FatalityType.Decapitated;

	case "pg.rf_crossbow":
		return _data.ArmorHead > 0 || _data.ArmorBody > 0;

	case "pg.rf_dagger":
		return _data.Range == 1;

	case "pg.rf_flail":
		return _data.HasShield;

	case "pg.rf_hammer":
		return _data.ArmorHead <= 0 && _data.ArmorBody <= 0;

	case "pg.rf_mace":
		return _data.IsStunned;

	case "pg.rf_polearm":
		return _data.AdjacentAllies >= 2;

	case "pg.rf_spear":
		return _data.AdjacentAllies >= 1;

	case "pg.rf_sword":
		return _data.IsRiposting;

	case "pg.rf_throwing":
		return _data.Range == 2;
	}

	return false;
};

::LearningWeapons.addKill <- function( _actor, _groupID, _isSpecial )
{
	local skill = ::LearningWeapons.getProgressSkill(_actor);

	if (skill == null)
		return;

	local progress = skill.getProgress(_groupID);
	progress.Kills = progress.Kills + 1;

	if (_isSpecial)
		progress.SpecialKills = progress.SpecialKills + 1;

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
				::Tactical.EventLog.logEx(::Const.UI.getColorizedEntityName(_actor) + " has unlocked the " + name + " perk group!");
			}
		}
	}
};

// ---------------------------------------------------------------------------
// Transient combat state
//
// This is deliberately kept outside of the actor's `m` table. Adding new fields
// to engine objects at runtime is not safe (some of them are class instances and
// reject unknown fields), and this data must never end up in a savegame.
// Entries are keyed by entity ID and removed as soon as they have been used.
// ---------------------------------------------------------------------------
::LearningWeapons.Transient <- {
	LastHitBodyPart = {},
	DeathInfo = {},
	Riposting = {}
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

::LearningWeapons.getTooltipEntries <- function( _actor )
{
	// The tooltip is the only place the player can see the progress, so make sure
	// the perk tree is in sync even if another mod rebuilt it in the meantime.
	::LearningWeapons.applyProgressionToPerkTree(_actor);

	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return [];

	local thresholds = ::LearningWeapons.getThresholds();
	local ret = [
		{
			id = 99,
			type = "header",
			text = "Weapon Progression"
		},
		{
			id = 100,
			type = "text",
			text = "Unlock a weapon perk group by getting " + thresholds.Normal + " kills and " + thresholds.Special + " special kills with that weapon type."
		}
	];

	local id = 101;
	foreach (groupID in ::LearningWeapons.WeaponGroupIDs)
	{
		local progress = skill.getProgress(groupID);
		local perkGroup = ::DynamicPerks.PerkGroups.findById(groupID);
		local name = perkGroup != null ? perkGroup.getName() : groupID;
		local status = progress.Unlocked ? " [color=" + ::Const.UI.Color.PositiveValue + "]Unlocked[/color]" : "";

		ret.push({
			id = id,
			type = "text",
			icon = "ui/icons/special.png",
			text = name + ": " + progress.Kills + "/" + thresholds.Normal + " kills, " + progress.SpecialKills + "/" + thresholds.Special + " special kills" + status
		});

		id = id + 1;
	}

	return ret;
};
