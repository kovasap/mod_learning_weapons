this.learning_weapons_progress_skill <- this.inherit("scripts/skills/skill", {
	m = {
		Progress = {}
	},
	function create()
	{
		this.m.ID = "special.learning_weapons_progress";
		this.m.Name = "Learning Weapons";
		this.m.Description = "";
		this.m.Icon = "";
		this.m.Type = this.Const.SkillType.Special;
		this.m.Order = this.Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsHidden = true;
		this.m.IsSerialized = true;
	}

	function getProgress( _groupID )
	{
		if (!(_groupID in this.m.Progress))
		{
			this.m.Progress[_groupID] <- {
				Kills = 0,
				SpecialKills = 0,
				Unlocked = false
			};
		}

		return this.m.Progress[_groupID];
	}

	function onSerialize( _out )
	{
		this.skill.onSerialize(_out);

		_out.writeU8(this.m.Progress.len());

		foreach (groupID, progress in this.m.Progress)
		{
			_out.writeString(groupID);
			_out.writeU16(progress.Kills);
			_out.writeU16(progress.SpecialKills);
			_out.writeBool(progress.Unlocked);
		}
	}

	function onDeserialize( _in )
	{
		this.skill.onDeserialize(_in);

		this.m.Progress = {};

		local len = _in.readU8();
		for (local i = 0; i != len; i = ++i)
		{
			local groupID = _in.readString();
			this.m.Progress[groupID] <- {
				Kills = _in.readU16(),
				SpecialKills = _in.readU16(),
				Unlocked = _in.readBool()
			};
		}
	}
});
