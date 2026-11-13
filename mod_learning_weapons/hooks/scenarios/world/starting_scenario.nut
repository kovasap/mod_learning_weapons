::LearningWeapons.HooksMod.hookTree("scripts/scenarios/world/starting_scenario", function(q) {
	// Dynamic Perks calls onBuildPerkTree at the end of every perk tree build.
	// Reforged uses this to rebuild the perk tree of every starting brother after
	// the origin spawned him, which would add random weapon perk groups back.
	// Re-apply the recorded progression so those groups stay locked.
	q.onBuildPerkTree = @(__original) function( _perkTree )
	{
		__original(_perkTree);

		if (_perkTree == null || ::MSU.isNull(_perkTree))
			return;

		local actor = _perkTree.getActor();
		if (actor == null || ::MSU.isNull(actor) || actor.getType() != ::Const.EntityType.Player)
			return;

		::LearningWeapons.applyProgressionToPerkTree(actor);
	};
});
