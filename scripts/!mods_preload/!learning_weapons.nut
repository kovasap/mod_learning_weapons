::LearningWeapons <- {
	ID = "mod_learning_weapons",
	Version = "0.1.0",
	Name = "Learning Weapons",
	Const = {
		NormalThreshold = 20,
		SpecialThreshold = 1,
		TestNormalThreshold = 1,
		TestSpecialThreshold = 1,
		TestScenarioID = "scenario.learning_weapons_test"
	},
	TooltipsRegistered = false,
	// These are all the weapon perk groups from Reforged's pgc.rf_weapon collection.
	WeaponGroupIDs = [
		"pg.rf_axe",
		"pg.rf_bow",
		"pg.rf_cleaver",
		"pg.rf_crossbow",
		"pg.rf_dagger",
		"pg.rf_flail",
		"pg.rf_hammer",
		"pg.rf_mace",
		"pg.rf_polearm",
		"pg.rf_spear",
		"pg.rf_sword",
		"pg.rf_throwing"
	],
	Achievements = {
		"pg.rf_axe": {
			Key = "Executioner",
			Name = "Executioner",
			Description = "Kill an enemy with a [headshot|Concept.ChanceToHitHead]."
		},
		"pg.rf_bow": {
			Key = "Sniper",
			Name = "Sniper",
			Description = "Get a kill at range 5 or more."
		},
		"pg.rf_cleaver": {
			Key = "MercyKiller",
			Name = "Mercy Killer",
			Description = "[Decapitate|Concept.Fatality] a [bleeding|Skill+bleeding_effect] enemy."
		},
		"pg.rf_crossbow": {
			Key = "ShellCracker",
			Name = "Shell Cracker",
			Description = "Get a kill on an enemy that still has armor remaining on both [head|Concept.ArmorHead] and [body|Concept.ArmorBody] when they die."
		},
		"pg.rf_dagger": {
			Key = "Assassin",
			Name = "Assassin",
			Description = "Kill an enemy with a [chestpiece|Concept.ArmorBody] of 75% condition or higher."
		},
		"pg.rf_flail": {
			Key = "Talented",
			Name = "Talented",
			Description = "Kill an enemy wielding a shield with a [headshot|Concept.ChanceToHitHead]."
		},
		"pg.rf_hammer": {
			Key = "CanOpener",
			Name = "Can Opener",
			Description = "Fully destroy an enemy's armor ([head|Concept.ArmorHead] and [chest|Concept.ArmorBody]) from 100% to 0% without [injuring|Concept.InjuryTemporary] them. This can happen over multiple hits, but the enemy cannot take damage from any other source."
		},
		"pg.rf_mace": {
			Key = "HeavyHitter",
			Name = "Heavy Hitter",
			Description = "Kill a [stunned|Skill+stunned_effect] enemy."
		},
		"pg.rf_polearm": {
			Key = "Savior",
			Name = "Savior",
			Description = "Move an enemy away from an [injured|Concept.Injury] friendly unit with [Repel|Skill+repel] or [Hook|Skill+hook]."
		},
		"pg.rf_spear": {
			Key = "HoldYourGround",
			Name = "Hold your ground!",
			Description = "Kill an enemy with [Spearwall|Skill+spearwall]."
		},
		"pg.rf_sword": {
			Key = "Duelist",
			Name = "Duelist",
			Description = "Kill an enemy with a [Riposte|Skill+riposte]."
		},
		"pg.rf_throwing": {
			Key = "ComeAtMe",
			Name = "Come at me!",
			Description = "Get a kill at range 2 on an enemy not [engaged|Concept.ZoneOfControl] with any friendly units."
		}
	}
};

::LearningWeapons.HooksMod <- ::Hooks.register(::LearningWeapons.ID, ::LearningWeapons.Version, ::LearningWeapons.Name);
::LearningWeapons.HooksMod.require([
	"mod_reforged",
	"mod_dynamic_perks",
	"mod_msu"
]);

// This bucket is deliberately after Dynamic Perks' VeryLate hook that registers
// its player.setStartValuesEx hook. Our hook must wrap theirs so that it runs
// after the perk tree has been built. Hooks registered in AfterHooks are not
// finalized, so Last is the latest bucket we can use.
::LearningWeapons.HooksMod.queue(function() {
	::include("mod_learning_weapons/load.nut");
}, ::Hooks.QueueBucket.Last);

// Register achievement nested tooltips after Reforged populates its Concept
// tooltips in FirstWorldInit so nested Concept links inside our descriptions
// resolve cleanly.
::LearningWeapons.HooksMod.queue(">mod_reforged", function() {
	::LearningWeapons.registerNestedTooltips();
}, ::Hooks.QueueBucket.FirstWorldInit);
