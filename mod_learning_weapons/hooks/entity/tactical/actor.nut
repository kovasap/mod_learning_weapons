::LearningWeapons.HooksMod.hook("scripts/entity/tactical/actor", function(q) {
	// Remember the body part of the hit that is currently being resolved. The
	// fatal blow is applied inside the original function, so the kill hook needs
	// this value before the call. Clear it again for non-lethal hits so that
	// deaths from other sources (bleeding, scripts) don't inherit a stale body
	// part and e.g. count as axe headshots.
	//
	// The value is kept in ::LearningWeapons.Transient instead of on this.m:
	// engine objects reject unknown fields, and this state must not be serialized.
	q.onDamageReceived = @(__original) function( _attacker, _skill, _hitInfo )
	{
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.LastHitBodyPart, this, _hitInfo != null ? _hitInfo.BodyPart : null);

		local ret = __original(_attacker, _skill, _hitInfo);

		if (this.isAlive())
			::LearningWeapons.clearTransient(::LearningWeapons.Transient.LastHitBodyPart, this);

		return ret;
	};

	// Snapshot everything about the victim that would otherwise be unavailable
	// by the time the killer's onActorKilled hook runs. Hooking kill rather than
	// onDeath is important because several enemies override onDeath and some do
	// not always call the base implementation.
	q.kill = @(__original) function( _killer = null, _skill = null, _fatalityType = this.Const.FatalityType.None, _silent = false )
	{
		// Mirror the original's early-out so we never touch the state of an actor
		// that was already dead or was never fully initialized.
		if (!this.isAlive())
			return __original(_killer, _skill, _fatalityType, _silent);

		local items = this.getItems();
		local offhand = items != null ? items.getItemAtSlot(this.Const.ItemSlot.Offhand) : null;

		// CurrentProperties (and therefore getArmor) still holds the pre-hit
		// values at this point, because Skills.update() runs after the lethal
		// hit. Read the base values instead: onDamageReceived has already
		// applied the fatal blow to them. Only the "armor left or not" state
		// matters for the special kill rules, so the raw values suffice.
		local baseProperties = this.m.BaseProperties;
		local armor = baseProperties != null ? baseProperties.Armor : null;
		local skills = this.getSkills();
		local isStunned = skills != null && (skills.hasSkill("effects.stunned") || skills.hasSkill("effects.dazed"));

		::LearningWeapons.storeTransient(::LearningWeapons.Transient.DeathInfo, this, {
			FatalityType = _fatalityType,
			ArmorHead = armor != null ? armor[this.Const.BodyPart.Head] : 0,
			ArmorBody = armor != null ? armor[this.Const.BodyPart.Body] : 0,
			HasShield = offhand != null && offhand.isItemType(this.Const.Items.ItemType.Shield),
			LastHitBodyPart = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.LastHitBodyPart, this),
			IsStunned = isStunned
		});

		// Consumed by the killer's onActorKilled, which runs inside __original.
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.LastHitBodyPart, this);

		local ret = __original(_killer, _skill, _fatalityType, _silent);

		// If no killer consumed the snapshot (e.g. a scripted death), drop it.
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.DeathInfo, this);

		return ret;
	};

	// Riposte attacks are executed inside onRiposte, so a flag around the
	// original call reliably identifies kills made by a riposte.
	q.onRiposte = @(__original) function( _info )
	{
		local wasRiposting = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Riposting, this, false);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.Riposting, this, true);
		local ret = __original(_info);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.Riposting, this, wasRiposting);
		return ret;
	};

	q.onActorKilled = @(__original) function( _actor, _tile, _skill )
	{
		local ret = __original(_actor, _tile, _skill);

		// Only brothers (i.e. the player's own characters) learn weapons.
		if (this.getType() != this.Const.EntityType.Player || !this.isPlayerControlled())
			return ret;

		if (!this.isAlive() || this.isDying())
			return ret;

		if (_actor == null || this.isAlliedWith(_actor))
			return ret;

		local deathInfo = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.DeathInfo, _actor);
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.DeathInfo, _actor);

		if (deathInfo == null || deathInfo.FatalityType == this.Const.FatalityType.Unconscious)
			return ret;

		local weaponGroups = ::LearningWeapons.getWeaponGroupsForSkill(_skill, this);
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
			IsRiposting = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Riposting, this, false) == true,
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
