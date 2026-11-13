::LearningWeapons.HooksMod.hook("scripts/entity/tactical/player", function(q) {
	// Dynamic Perks builds the perk tree in its own setStartValuesEx hook at
	// QueueBucket.VeryLate. This hook is registered in the Last bucket, so it
	// wraps Dynamic Perks' hook and the tree already exists at this point.
	q.setStartValuesEx = @(__original) function( _backgrounds, _addTraits = true )
	{
		__original(_backgrounds, _addTraits);

		if (this.getType() != this.Const.EntityType.Player)
			return;

		::LearningWeapons.applyProgressionToPerkTree(this);
	};
});
