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
	local skill = skills.getSkillByID("special.learning_weapons_progress");

	if (skill == null)
	{
		skill = ::new("scripts/skills/special/learning_weapons_progress_skill");
		skills.add(skill);
	}

	return skill;
};

// Restores any perk groups that were already unlocked. This is cheap and makes
// the mod resilient if another mod rebuilds the perk tree after the unlock.
::LearningWeapons.ensureUnlockedGroups <- function( _actor )
{
	local skill = ::LearningWeapons.getProgressSkill(_actor);

	if (skill == null)
		return;

	local perkTree = _actor.getPerkTree();
	if (perkTree == null)
		return;

	foreach (groupID, progress in skill.m.Progress)
	{
		if (progress.Unlocked && !perkTree.hasPerkGroup(groupID))
			perkTree.addPerkGroup(groupID);
	}
};

::LearningWeapons.getWeaponGroupsForSkill <- function( _skill )
{
	local ret = [];

	if (_skill == null || ::MSU.isNull(_skill))
		return ret;

	local weapon = _skill.getItem();
	if (weapon == null || ::MSU.isNull(weapon))
		return ret;

	if (!weapon.isItemType(::Const.Items.ItemType.Weapon))
		return ret;

	return ::Reforged.getWeaponPerkGroups(weapon);
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

::LearningWeapons.getTooltipEntries <- function( _actor )
{
	::LearningWeapons.ensureUnlockedGroups(_actor);

	local skill = ::LearningWeapons.getProgressSkill(_actor);
	if (skill == null)
		return [];

	local thresholds = ::LearningWeapons.getThresholds();
	local ret = [
		{
			id = 99,
			type = "title",
			text = "Weapon Progression"
		},
		{
			id = 100,
			type = "text",
			icon = "ui/icons/special.png",
			text = "Kills (special kills) needed to unlock each weapon perk group:"
		}
	];

	local id = 101;
	foreach (groupID in ::LearningWeapons.WeaponGroupIDs)
	{
		local progress = skill.getProgress(groupID);
		local perkGroup = ::DynamicPerks.PerkGroups.findById(groupID);
		local name = perkGroup != null ? perkGroup.getName() : groupID;
		local status = progress.Unlocked ? " [color=#4caf50]Unlocked[/color]" : "";

		ret.push({
			id = id,
			type = "text",
			icon = "ui/icons/special.png",
			text = name + ": " + progress.Kills + "/" + thresholds.Normal + " kills, " + progress.SpecialKills + "/" + thresholds.Special + " special" + status
		});

		id = id + 1;
	}

	return ret;
};
