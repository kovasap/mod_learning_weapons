::LearningWeapons.HooksMod.hook("scripts/entity/tactical/player", function(q) {
	// Dynamic Perks builds the perk tree in its own setStartValuesEx hook at
	// QueueBucket.VeryLate. This hook is registered in AfterHooks, so the tree
	// exists and can be stripped of all weapon perk groups.
	q.setStartValuesEx = @(__original) function( _backgrounds, _addTraits = true )
	{
		__original(_backgrounds, _addTraits);

		if (this.getType() != this.Const.EntityType.Player)
			return;

		local perkTree = this.getPerkTree();
		if (perkTree != null)
		{
			foreach (groupID in ::LearningWeapons.WeaponGroupIDs)
			{
				if (perkTree.hasPerkGroup(groupID))
					perkTree.removePerkGroup(groupID);
			}
		}

		::LearningWeapons.getProgressSkill(this);
	};
});
