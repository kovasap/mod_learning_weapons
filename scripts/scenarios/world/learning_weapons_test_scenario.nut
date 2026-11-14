this.learning_weapons_test_scenario <- this.inherit("scripts/scenarios/world/starting_scenario", {
	m = {},
	function create()
	{
		this.m.ID = "scenario.learning_weapons_test";
		this.m.Name = "Learning Weapons - Test";
		this.m.Description = "[p=c][img]gfx/ui/events/event_80.png[/img][/p][p]A testing origin for the Learning Weapons mod.\n\n[color=#bcad8c]Weapon Students:[/color] Start with one brother for every weapon type.\n[color=#bcad8c]Quick Learners:[/color] Weapon perk groups require only 1 normal kill and 1 special achievement.[/p]";
		this.m.Difficulty = 1;
		this.m.Order = 1;
	}

	function isValid()
	{
		return true;
	}

	function onSpawnAssets()
	{
		local roster = this.World.getPlayerRoster();

		local brothers = [
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/fighting_axe", Ammo = null },
			{ Background = "hunter_background", Weapon = "scripts/items/weapons/hunting_bow", Ammo = "scripts/items/ammo/quiver_of_arrows" },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/butchers_cleaver", Ammo = null },
			{ Background = "hunter_background", Weapon = "scripts/items/weapons/crossbow", Ammo = "scripts/items/ammo/quiver_of_bolts" },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/dagger", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/flail", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/warhammer", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/morning_star", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/pike", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/boar_spear", Ammo = null },
			{ Background = "hedge_knight_background", Weapon = "scripts/items/weapons/arming_sword", Ammo = null },
			{ Background = "poacher_background", Weapon = "scripts/items/weapons/javelin", Ammo = null }
		];

		for (local i = 0; i != brothers.len(); i = ++i)
		{
			local bro = roster.create("scripts/entity/tactical/player");
			bro.m.HireTime = this.Time.getVirtualTimeF();
			bro.setStartValuesEx([brothers[i].Background]);
			bro.setPlaceInFormation(3 + i);
			bro.improveMood(1.0, "Joined a mercenary company");

			local items = bro.getItems();

			// Remove whatever the background brought so every brother starts with
			// exactly the weapon we want to test.
			foreach (item in items.getAllItems())
			{
				if (item.isEquipped())
					items.unequip(item);
			}

			items.equip(this.new(brothers[i].Weapon));

			if (brothers[i].Ammo != null)
				items.equip(this.new(brothers[i].Ammo));

			items.equip(this.new("scripts/items/armor/gambeson"));
			items.equip(this.new("scripts/items/helmets/nasal_helmet"));
		}

		this.World.Assets.getStash().add(this.new("scripts/items/supplies/ground_grains_item"));
		this.World.Assets.getStash().add(this.new("scripts/items/supplies/ground_grains_item"));
		this.World.Assets.getStash().add(this.new("scripts/items/supplies/ground_grains_item"));
	}

	function onSpawnPlayer()
	{
		local settlements = this.World.EntityManager.getSettlements();
		local randomVillage = settlements[0];

		foreach (settlement in settlements)
		{
			if (!settlement.isMilitary() && !settlement.isIsolatedFromRoads() && settlement.getSize() >= 3 && !settlement.isSouthern())
			{
				randomVillage = settlement;
				break;
			}
		}

		local randomVillageTile = randomVillage.getTile();
		local navSettings = this.World.getNavigator().createSettings();
		navSettings.ActionPointCosts = this.Const.World.TerrainTypeNavCost_Flat;

		while (true)
		{
			local x = this.Math.rand(this.Math.max(2, randomVillageTile.SquareCoords.X - 4), this.Math.min(this.Const.World.Settings.SizeX - 2, randomVillageTile.SquareCoords.X + 4));
			local y = this.Math.rand(this.Math.max(2, randomVillageTile.SquareCoords.Y - 4), this.Math.min(this.Const.World.Settings.SizeY - 2, randomVillageTile.SquareCoords.Y + 4));

			if (!this.World.isValidTileSquare(x, y))
				continue;

			local tile = this.World.getTileSquare(x, y);

			if (tile.Type == this.Const.World.TerrainType.Ocean || tile.Type == this.Const.World.TerrainType.Shore || tile.IsOccupied)
				continue;

			if (tile.getDistanceTo(randomVillageTile) <= 1)
				continue;

			local path = this.World.getNavigator().findPath(tile, randomVillageTile, navSettings, 0);
			if (!path.isEmpty())
			{
				randomVillageTile = tile;
				break;
			}
		}

		this.World.State.m.Player = this.World.spawnEntity("scripts/entity/world/player_party", randomVillageTile.Coords.X, randomVillageTile.Coords.Y);
		this.World.Assets.updateLook(12);
		this.World.getCamera().setPos(this.World.State.m.Player.getPos());
	}
});
