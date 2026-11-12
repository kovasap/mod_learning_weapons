::LearningWeapons.HooksMod.hook("scripts/entity/tactical/actor", function(q) {
	// Remember the last body part that was hit. actor.onDamageReceived is where
	// the fatal blow is applied, so this is still available when the victim dies.
	q.onDamageReceived = @(__original) function( _attacker, _skill, _hitInfo )
	{
		if (_hitInfo != null)
			this.m.LW_LastHitBodyPart = _hitInfo.BodyPart;

		return __original(_attacker, _skill, _hitInfo);
	};

	// Snapshot everything about the victim that would otherwise be unavailable
	// by the time the killer's onActorKilled hook runs. Hooking kill rather than
	// onDeath is important because several enemies override onDeath and some do
	// not always call the base implementation.
	q.kill = @(__original) function( _killer = null, _skill = null, _fatalityType = this.Const.FatalityType.None, _silent = false )
	{
		local offhand = this.getItems().getItemAtSlot(this.Const.ItemSlot.Offhand);

		// CurrentProperties (and therefore getArmor) still holds the pre-hit
		// values at this point, because Skills.update() runs after the lethal
		// hit. Read the base values instead: onDamageReceived has already
		// applied the fatal blow to them. Only the "armor left or not" state
		// matters for the special kill rules, so the raw values suffice.
		local armor = this.m.BaseProperties.Armor;

		this.m.LW_DeathInfo = {
			FatalityType = _fatalityType,
			ArmorHead = armor[this.Const.BodyPart.Head],
			ArmorBody = armor[this.Const.BodyPart.Body],
			HasShield = offhand != null && offhand.isItemType(this.Const.Items.ItemType.Shield),
			LastHitBodyPart = this.m.LW_LastHitBodyPart,
			IsStunned = this.getSkills().hasSkill("effects.stunned") || this.getSkills().hasSkill("effects.dazed")
		};

		return __original(_killer, _skill, _fatalityType, _silent);
	};

	// Riposte attacks are executed inside onRiposte, so a flag around the
	// original call reliably identifies kills made by a riposte.
	q.onRiposte = @(__original) function( _info )
	{
		local wasRiposting = this.m.LW_IsRiposting;
		this.m.LW_IsRiposting = true;
		local ret = __original(_info);
		this.m.LW_IsRiposting = wasRiposting;
		return ret;
	};

	q.onActorKilled = @(__original) function( _actor, _tile, _skill )
	{
		local ret = __original(_actor, _tile, _skill);

		// Only brothers (i.e. the player's own characters) learn weapons.
		if (this.getType() != this.Const.EntityType.Player || !this.isPlayerControlled())
			return ret;

		if (_actor == null || this.isAlliedWith(_actor))
			return ret;

		local deathInfo = _actor.m.LW_DeathInfo;
		if (deathInfo == null || deathInfo.FatalityType == this.Const.FatalityType.Unconscious)
			return ret;

		local weaponGroups = ::LearningWeapons.getWeaponGroupsForSkill(_skill);
		if (weaponGroups.len() == 0)
			return ret;

		local killerTile = this.getTile();
		local victimTile = _actor.getTile();
		local range = killerTile != null && victimTile != null ? killerTile.getDistanceTo(victimTile) : -1;

		local adjacentAllies = 0;
		if (killerTile != null)
		{
			for (local i = 0; i != 6; i = ++i)
			{
				if (!killerTile.hasNextTile(i))
					continue;

				local nextTile = killerTile.getNextTile(i);
				if (!nextTile.IsOccupiedByActor)
					continue;

				local entity = nextTile.getEntity();
				if (entity != null && entity != this && entity.isAlive() && entity.isAlliedWith(this) && !entity.isNonCombatant())
					adjacentAllies = adjacentAllies + 1;
			}
		}

		local data = {
			Range = range,
			ArmorHead = deathInfo.ArmorHead,
			ArmorBody = deathInfo.ArmorBody,
			FatalityType = deathInfo.FatalityType,
			LastHitBodyPart = deathInfo.LastHitBodyPart,
			IsRiposting = this.m.LW_IsRiposting == true,
			HasShield = deathInfo.HasShield,
			AdjacentAllies = adjacentAllies,
			IsStunned = deathInfo.IsStunned
		};

		foreach (groupID in weaponGroups)
		{
			local isSpecial = ::LearningWeapons.isSpecialKill(groupID, data);
			::LearningWeapons.addKill(this, groupID, isSpecial);
		}

		return ret;
	};
});
