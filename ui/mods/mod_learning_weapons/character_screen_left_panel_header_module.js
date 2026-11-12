var LearningWeapons = {};

LearningWeapons.CharacterScreenLeftPanelHeaderModule_updateControls = CharacterScreenLeftPanelHeaderModule.prototype.updateControls;

CharacterScreenLeftPanelHeaderModule.prototype.updateControls = function (_data)
{
	LearningWeapons.CharacterScreenLeftPanelHeaderModule_updateControls.call(this, _data);

	if (this.mXPProgressbar === null || _data === null || typeof(_data) !== 'object')
	{
		return;
	}

	// Vanilla does not pass an entity ID for the experience bar tooltip, so the
	// backend cannot know which brother's weapon progress to display.
	if (!(CharacterScreenIdentifier.Entity.Id in _data))
	{
		return;
	}

	this.mXPProgressbar.unbindTooltip();
	this.mXPProgressbar.bindTooltip({
		contentType: 'ui-element',
		elementId: TooltipIdentifier.CharacterScreen.LeftPanelHeaderModule.Experience,
		entityId: _data[CharacterScreenIdentifier.Entity.Id]
	});
};
