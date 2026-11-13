::LearningWeapons.HooksMod.hook("scripts/ui/screens/tooltip/tooltip_events", function(q) {
	q.general_queryUIElementTooltipData = @(__original) function( _entityId, _elementId, _elementOwner )
	{
		local ret = __original(_entityId, _elementId, _elementOwner);

		if (_elementId != "character-screen.left-panel-header-module.Experience")
			return ret;

		if (_entityId == null)
			return ret;

		// Tactical.getEntityByID also resolves roster brothers while on the world
		// map, which is where the character screen is normally used.
		local entity = ::Tactical.getEntityByID(_entityId);
		if (entity == null || entity.getType() != ::Const.EntityType.Player || !entity.isPlayerControlled())
			return ret;

		if (ret == null)
			ret = [];

		local entries = ::LearningWeapons.getTooltipEntries(entity);
		foreach (entry in entries)
			ret.push(entry);

		return ret;
	};
});
