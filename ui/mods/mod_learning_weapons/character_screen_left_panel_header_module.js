var LearningWeapons = {};

LearningWeapons.CharacterScreenLeftPanelHeaderModule_updateControls = CharacterScreenLeftPanelHeaderModule.prototype.updateControls;

CharacterScreenLeftPanelHeaderModule.prototype.updateControls = function (_data)
{
	LearningWeapons.CharacterScreenLeftPanelHeaderModule_updateControls.call(this, _data);

	if (this.mXPProgressbar === null || _data === null || typeof(_data) !== 'object')
	{
		return;
	}

	// Vanilla binds the experience bar tooltip without an entity ID, so the
	// backend has no way of knowing which brother's weapon progress to show.
	// updateControls only receives the character data (which has no ID), so ask
	// the datasource for the full selected brother instead.
	var selectedBrother = this.mDataSource.getSelectedBrother();
	if (selectedBrother === null || !(CharacterScreenIdentifier.Entity.Id in selectedBrother))
	{
		return;
	}

	this.mXPProgressbar.unbindTooltip();
	this.mXPProgressbar.bindTooltip({
		contentType: 'ui-element',
		elementId: TooltipIdentifier.CharacterScreen.LeftPanelHeaderModule.Experience,
		entityId: selectedBrother[CharacterScreenIdentifier.Entity.Id]
	});
};
