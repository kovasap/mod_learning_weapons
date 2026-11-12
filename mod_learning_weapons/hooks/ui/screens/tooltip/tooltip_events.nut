::LearningWeapons.HooksMod.hook("scripts/ui/screens/tooltip/tooltip_events", function(q) {
	q.general_queryUIElementTooltipData = @(__original) function( _entityId, _elementId, _elementOwner )
	{
		local ret = __original(_entityId, _elementId, _elementOwner);

		if (_elementId != "character-screen.left-panel-header-module.Experience")
			return ret;

		if (_entityId == null)
			return ret;

		local entity = ::Tactical.getEntityByID(_entityId);
		if (entity == null || entity == ::MSU.getDummyPlayer() || entity.getType() != ::Const.EntityType.Player)
			return ret;

		if (ret == null)
			ret = [];

		local entries = ::LearningWeapons.getTooltipEntries(entity);
		foreach (entry in entries)
			ret.push(entry);

		return ret;
	};
});
