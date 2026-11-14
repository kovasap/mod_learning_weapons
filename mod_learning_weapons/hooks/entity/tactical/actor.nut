::LearningWeapons.HooksMod.hook("scripts/entity/tactical/actor", function(q) {
	q.onInit = @(__original) function()
	{
		__original();
		::LearningWeapons.clearAllTransientForActor(this);
	};

	q.onFinish = @(__original) function()
	{
		__original();
		::LearningWeapons.clearAllTransientForActor(this);
	};

	// Repel and Hook call setCurrentMovementType(Involuntary) right before
	// teleporting the displaced target. Tracking this here reliably detects a
	// successful displacement even when another mod (such as Hardened) wraps
	// repel/hook.onUse without forwarding the boolean return value.
	q.setCurrentMovementType = @(__original) function( _t )
	{
		__original(_t);

		if (_t == this.Const.Tactical.MovementType.Involuntary)
			::LearningWeapons.storeTransient(::LearningWeapons.Transient.Displaced, this, true);
	};

	// Remember the body part and pre-hit state of the hit currently being
	// resolved, and track Hammer's "Can Opener" progression across hits.
	//
	// State is kept in ::LearningWeapons.Transient instead of on this.m: engine
	// objects reject unknown fields, and this state must not be serialized.
	q.onDamageReceived = @(__original) function( _attacker, _skill, _hitInfo )
	{
		if (!this.isAlive())
			return __original(_attacker, _skill, _hitInfo);

		local skills = this.getSkills();
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.LastHitBodyPart, this, _hitInfo != null ? _hitInfo.BodyPart : null);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.PreHitInfo, this, {
			WasBleeding = skills != null && skills.hasSkill("effects.bleeding"),
			IsStunned = skills != null && skills.hasSkill("effects.stunned"),
			HadZoC = this.hasZoneOfControl()
		});

		local trackCanOpener = !this.isPlayerControlled();
		local armorBefore = null;
		local hpBefore = 0;
		local injuriesBefore = 0;
		local canOpenerState = null;

		if (trackCanOpener)
		{
			armorBefore = ::LearningWeapons.getArmorState(this);
			hpBefore = this.getHitpoints();
			local hpMax = this.getHitpointsMax();
			injuriesBefore = skills != null ? skills.getAllSkillsOfType(this.Const.SkillType.TemporaryInjury).len() : 0;

			canOpenerState = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.CanOpener, this);
			if (canOpenerState == null)
			{
				local startedUntouchedWithFullArmor = armorBefore.HeadMax > 0 &&
					armorBefore.BodyMax > 0 &&
					armorBefore.Head >= armorBefore.HeadMax &&
					armorBefore.Body >= armorBefore.BodyMax &&
					hpBefore >= hpMax &&
					injuriesBefore == 0;

				canOpenerState = {
					Disqualified = !startedUntouchedWithFullArmor,
					Completed = false,
					AttackerID = null,
					LastHP = hpBefore,
					LastArmorHead = armorBefore.Head,
					LastArmorBody = armorBefore.Body
				};
				::LearningWeapons.storeTransient(::LearningWeapons.Transient.CanOpener, this, canOpenerState);
			}
			else if (!canOpenerState.Disqualified && !canOpenerState.Completed)
			{
				// Catch out-of-band damage between hits (e.g. Lindwurm acid reducing armor directly).
				if (hpBefore < canOpenerState.LastHP ||
					armorBefore.Head < canOpenerState.LastArmorHead ||
					armorBefore.Body < canOpenerState.LastArmorBody ||
					injuriesBefore > 0)
				{
					canOpenerState.Disqualified = true;
				}
			}
		}

		local ret = __original(_attacker, _skill, _hitInfo);

		local deathArmor = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.PostHitArmorOnDeath, this);
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.PostHitArmorOnDeath, this);

		if (trackCanOpener && canOpenerState != null && !canOpenerState.Disqualified && !canOpenerState.Completed)
		{
			local armorAfter = (!this.isAlive() && deathArmor != null) ? deathArmor : ::LearningWeapons.getArmorState(this);
			local hpAfter = this.isAlive() ? this.getHitpoints() : 0;
			local postSkills = this.getSkills();
			local injuriesAfter = (!this.isAlive() || postSkills == null) ? injuriesBefore : postSkills.getAllSkillsOfType(this.Const.SkillType.TemporaryInjury).len();
			local tookDamage = (armorAfter.Head < armorBefore.Head) || (armorAfter.Body < armorBefore.Body) || (hpAfter < hpBefore);

			if (injuriesAfter > injuriesBefore)
			{
				canOpenerState.Disqualified = true;
			}
			else if (tookDamage)
			{
				local validAttacker = _attacker != null &&
					!::MSU.isNull(_attacker) &&
					_attacker.getType() == this.Const.EntityType.Player &&
					_attacker.isPlayerControlled() &&
					_attacker.isAlive() &&
					!_attacker.isDying() &&
					!_attacker.isAlliedWith(this);

				local isHammerHit = false;
				if (validAttacker)
				{
					local skillGroups = ::LearningWeapons.getWeaponGroupsForSkill(_skill, _attacker);
					if (skillGroups.find("pg.rf_hammer") != null)
					{
						isHammerHit = true;
					}
					else if (_skill != null && !_skill.isActive() && _skill.getItem() == null)
					{
						isHammerHit = ::LearningWeapons.getEquippedWeaponGroups(_attacker).find("pg.rf_hammer") != null;
					}
				}

				if (!validAttacker || !isHammerHit || (canOpenerState.AttackerID != null && canOpenerState.AttackerID != _attacker.getID()))
				{
					canOpenerState.Disqualified = true;
				}
				else
				{
					canOpenerState.AttackerID = _attacker.getID();
					canOpenerState.LastHP = hpAfter;
					canOpenerState.LastArmorHead = armorAfter.Head;
					canOpenerState.LastArmorBody = armorAfter.Body;

					if (armorAfter.Head <= 0 && armorAfter.Body <= 0)
					{
						canOpenerState.Completed = true;
						::LearningWeapons.completeAchievement(_attacker, "pg.rf_hammer");
					}
				}
			}
		}

		if (this.isAlive())
		{
			::LearningWeapons.clearTransient(::LearningWeapons.Transient.LastHitBodyPart, this);
			::LearningWeapons.clearTransient(::LearningWeapons.Transient.PreHitInfo, this);
		}
		else
		{
			::LearningWeapons.clearTransient(::LearningWeapons.Transient.CanOpener, this);
		}

		return ret;
	};

	// Snapshot everything about the victim that would otherwise be unavailable
	// by the time the killer's onActorKilled hook runs (after onDeath drops items
	// and clears skills). Hooking kill rather than onDeath is important because
	// several enemies override onDeath and some do not call the base method.
	q.kill = @(__original) function( _killer = null, _skill = null, _fatalityType = this.Const.FatalityType.None, _silent = false )
	{
		// Mirror the original's early-out so we never touch the state of an actor
		// that was already dead or was never fully initialized.
		if (!this.isAlive())
			return __original(_killer, _skill, _fatalityType, _silent);

		local items = this.getItems();
		local offhand = items != null ? items.getItemAtSlot(this.Const.ItemSlot.Offhand) : null;
		local armorState = ::LearningWeapons.getArmorState(this);
		local preHit = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.PreHitInfo, this);
		local skills = this.getSkills();

		local wasBleeding = preHit != null ? preHit.WasBleeding : (skills != null && skills.hasSkill("effects.bleeding"));
		local isStunned = preHit != null ? preHit.IsStunned : (skills != null && skills.hasSkill("effects.stunned"));
		local hadZoC = preHit != null ? preHit.HadZoC : this.hasZoneOfControl();
		local victimTile = this.isPlacedOnMap() ? this.getTile() : null;
		local wasEngagedWithFriendly = (_killer != null && victimTile != null)
			? ::LearningWeapons.isEnemyEngagedWithFriendly(this, victimTile, _killer, hadZoC)
			: false;

		::LearningWeapons.storeTransient(::LearningWeapons.Transient.PostHitArmorOnDeath, this, armorState);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.DeathInfo, this, {
			FatalityType = _fatalityType,
			ArmorHead = armorState.Head,
			ArmorBody = armorState.Body,
			BodyArmorRatio = armorState.BodyItemRatio,
			HasShield = offhand != null && offhand.isItemType(this.Const.Items.ItemType.Shield),
			LastHitBodyPart = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.LastHitBodyPart, this),
			WasBleeding = wasBleeding,
			IsStunned = isStunned,
			VictimTile = victimTile,
			WasEngagedWithFriendly = wasEngagedWithFriendly
		});

		// Consumed by the killer's onActorKilled, which runs inside __original.
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.LastHitBodyPart, this);
		::LearningWeapons.clearTransient(::LearningWeapons.Transient.PreHitInfo, this);

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

	// Spearwall attacks are executed via getAttackOfOpportunity().useForFree()
	// inside onAttackOfOpportunity when _isOnEnter is true and effects.spearwall
	// is active, so _skill in onActorKilled is the thrust skill rather than
	// actives.spearwall. Track a flag around the call just like onRiposte.
	q.onAttackOfOpportunity = @(__original) function( _entity, _isOnEnter )
	{
		local skills = this.getSkills();
		local isSpearwall = _isOnEnter && skills != null && skills.hasSkill("effects.spearwall");
		if (!isSpearwall)
			return __original(_entity, _isOnEnter);

		local wasSpearwalling = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Spearwalling, this, false);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.Spearwalling, this, true);
		local ret = __original(_entity, _isOnEnter);
		::LearningWeapons.storeTransient(::LearningWeapons.Transient.Spearwalling, this, wasSpearwalling);
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

		local killerTile = this.isPlacedOnMap() ? this.getTile() : null;
		local victimTile = deathInfo.VictimTile != null ? deathInfo.VictimTile : (_actor.isPlacedOnMap() ? _actor.getTile() : null);
		local range = killerTile != null && victimTile != null ? killerTile.getDistanceTo(victimTile) : -1;

		local data = {
			Range = range,
			ArmorHead = deathInfo.ArmorHead,
			ArmorBody = deathInfo.ArmorBody,
			BodyArmorRatio = deathInfo.BodyArmorRatio,
			FatalityType = deathInfo.FatalityType,
			LastHitBodyPart = deathInfo.LastHitBodyPart,
			WasBleeding = deathInfo.WasBleeding,
			IsStunned = deathInfo.IsStunned,
			HasShield = deathInfo.HasShield,
			WasEngagedWithFriendly = deathInfo.WasEngagedWithFriendly,
			IsRiposting = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Riposting, this, false) == true,
			IsSpearwalling = ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Spearwalling, this, false) == true
		};

		foreach (groupID in weaponGroups)
		{
			local isSpecial = ::LearningWeapons.isSpecialKill(groupID, data);
			::LearningWeapons.addKill(this, groupID, isSpecial);
		}

		return ret;
	};
});
