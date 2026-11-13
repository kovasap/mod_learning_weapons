::LearningWeapons <- {
	ID = "mod_learning_weapons",
	Version = "0.1.0",
	Name = "Learning Weapons",
	Const = {
		NormalThreshold = 20,
		SpecialThreshold = 5,
		TestNormalThreshold = 1,
		TestSpecialThreshold = 1,
		TestScenarioID = "scenario.learning_weapons_test"
	},
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
	]
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
