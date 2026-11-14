local hookPolearmDisplacementSkill = function( _scriptPath )
{
	::LearningWeapons.HooksMod.hook(_scriptPath, function(q) {
		q.onUse = @(__original) function( _user, _targetTile )
		{
			local target = (_targetTile != null && _targetTile.IsOccupiedByActor) ? _targetTile.getEntity() : null;
			local eligible = _user != null &&
				!::MSU.isNull(_user) &&
				_user.getType() == ::Const.EntityType.Player &&
				_user.isPlayerControlled() &&
				_user.isAlive() &&
				!_user.isDying() &&
				_user.isPlacedOnMap() &&
				target != null &&
				target.isAlive() &&
				!target.isDying() &&
				!_user.isAlliedWith(target) &&
				::LearningWeapons.getWeaponGroupsForSkill(this, _user).find("pg.rf_polearm") != null;

			local destTile = null;
			local injuredFriendlyTiles = [];

			if (eligible)
			{
				destTile = this.findTileToKnockBackTo(_user.getTile(), _targetTile);
				::LearningWeapons.clearTransient(::LearningWeapons.Transient.Displaced, target);

				for (local i = 0; i != 6; i = ++i)
				{
					if (!_targetTile.hasNextTile(i))
						continue;

					local nextTile = _targetTile.getNextTile(i);
					if (!nextTile.IsOccupiedByActor)
						continue;

					local ally = nextTile.getEntity();
					if (ally == null || !ally.isAlive() || ally.isDying() || !_user.isAlliedWith(ally))
						continue;

					local allySkills = ally.getSkills();
					if (allySkills != null && allySkills.hasSkillOfType(::Const.SkillType.Injury))
						injuredFriendlyTiles.push(nextTile);
				}
			}

			local ret = __original(_user, _targetTile);

			if (eligible)
			{
				local didDisplace = (ret == true) || ::LearningWeapons.loadTransient(::LearningWeapons.Transient.Displaced, target, false);
				::LearningWeapons.clearTransient(::LearningWeapons.Transient.Displaced, target);

				if (didDisplace && destTile != null && injuredFriendlyTiles.len() > 0)
				{
					foreach (allyTile in injuredFriendlyTiles)
					{
						if (destTile.getDistanceTo(allyTile) > _targetTile.getDistanceTo(allyTile))
						{
							::LearningWeapons.completeAchievement(_user, "pg.rf_polearm");
							break;
						}
					}
				}
			}

			return ret;
		};
	});
};

hookPolearmDisplacementSkill("scripts/skills/actives/repel");
hookPolearmDisplacementSkill("scripts/skills/actives/hook");
