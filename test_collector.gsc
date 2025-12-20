#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_powerups;

// Precache Fx Here
#precache( "fx", "dlc3/stalingrad/fx_main_anomoly_loop_trail_talk");
#precache( "fx", "fire/fx_fire_trail_destruct_sm");
#precache( "fx", "zombie/fx_crafting_dust_zmb");
#precache( "fx", "explosions/fx_exp_bomb_demo_mp");
#precache( "fx", "zombie/fx_idgun_ug_hole_lg_zod_zmb");
#precache( "fx", "light/fx_glow_green_antenna");
#precache( "fx", "zombie/fx_powerup_grab_green_zmb");

//**********************
//UPDATE - DEC 10*******
//**********************
//The below code is working in-game, but I feel like it's not the most efficient

//**********************
//UPDATE - DEC 13*******
//**********************
//Add collector fx delay until after first kill

//**********************
//UPDATE - DEC 20*******
//**********************
//Added wait if soul is travelling before accepting next soul

function autoexec init()
{
	level waittill ("initial_blackscreen_passed");

	callback::on_ai_spawned( &watch_for_death );

	level.collectors = [];

	level.collectors_complete = 0; // if you want to track completed collectors
	level.max_distance = 400; // Sets the maximum range for collector
	level.line_of_sight = 0; // Set to 1 to Enable
	level.travel_rate = 100; // Velocity of the collection fx
	level.kills_needed = 5; // uhh
	level.activation_flag = "";
	level.fx_sound = ""; // sound alias name to play on the fx
	level.collection_sound = "evt_nuked"; // sound alias to play on collector once collected

	level._effect["travel_fx"] = "light/fx_glow_green_antenna"; // trail fx
	level._effect["collection_fx"] = "zombie/fx_powerup_grab_green_zmb"; // collection fx

	collectors = GetEntArray( "custom_soul_box", "targetname" );
	level.total_fillers = collectors.size;

	array::thread_all( collectors, &init_collectors );
}

function init_collectors()
{
	level.collectors[level.collectors.size] = self;

	self Hide ();

	if( !isdefined( self.script_int ) ) 
	{
		self.script_int = level.kills_needed;
	}

	self.max_kills = self.script_int;

	wait (0.05);

	self.is_traveling = false;

	self thread wait_to_activate();
}

function wait_to_activate()
{
	if ( !isdefined(self.script_flag) || self.script_flag == "" )
	{
		self.active = true;
		self Show ();
	}

	else if ( isdefined(self.script_notify) && isdefined (self.script_flag) )
	{
		flag = self.script_flag;
		self.active = false;
		
		if (!level flag::exists(flag)) //claude ai update to avoid duplicate flag init
		{
			level flag::init ( flag );
		}

		level flag::wait_till ( flag );
		
		self.active = true;
		self Show ();
	}
}

function watch_for_death()
{
	//self = zombie
	// Put an Endon here for when collection has completed
	if (level.collectors.size == 0)
		return;

	self waittill( "death" );
	collector = ArrayGetClosest( self.origin, level.collectors );
	if( isdefined( collector ) ) 
	{
		if( can_collect( self.origin, collector ) ) 
		{
			collector thread soul_travel( self.origin );
		}
	}
}

function can_collect( origin, collector )
{
	if( Distance( origin, collector.origin ) > level.max_distance ) 
	{
		return false;
	}
	/*
	if( level.line_of_sight && !BulletTracePassed( origin, collector.origin + ( 0, 0, 50 ), false, self ) ) 
	{
		return false;
	}
	*/
	if( !isdefined(collector.active) || !collector.active )
	{
		return false;
	}
	if( isdefined(collector.is_traveling) && collector.is_traveling)
	{
		return false;
	}

	return true;
}

function soul_travel( origin )
{
	//self = collector model
	//origin = zombie origin

	self.is_traveling = true;

	target = self.origin;
	fx_origin = util::spawn_model( "tag_origin", origin + ( 0, 0, 30 ) );
	self thread cleanup_fx_origin( fx_origin );
	fx = PlayFXOnTag( level._effect["travel_fx"], fx_origin, "tag_origin" );
	fx_origin PlaySound( level.fx_sound );
	time = Distance( origin, target ) / level.travel_rate;
	fx_origin MoveTo( target , time );
	wait( time - .05 );
	fx_origin MoveTo( target, .5 );
	fx_origin waittill( "movedone" );
	self PlaySound( level.collection_sound );
	PlayFX( level._effect["collection_fx"], target );

	self.is_traveling = false;
	
	if (isdefined(self.script_firefx) && self.script_int == self.max_kills)
	{
		PlayFXOnTag(self.script_firefx, self, "tag_origin");
		self MoveTo (target + (0, 0, 30), 1);
	}

	if( isdefined( fx_origin ) ) 
	{
		fx_origin Delete();
	}
	self each_count();
}

function each_count() //self = collector
{
	if (!isdefined(self) || self.script_int <= 0 ) //claude ai suggest to confirm exists
		return;

	self.script_int--;

	IPrintLnBold ("Souls remaining " + self.script_int);

	if( self.script_int <= 0 ) 
	{
		soul_move = struct::get (self.target, "targetname");
		//move_to = util::spawn_model( "tag_origin", soul_move.origin );
		if (isdefined(soul_move))
		{
			//how_long = self.script_waittime;
			//IPrintLnBold ("Time to move: " + how_long );
			self MoveTo (soul_move.origin, 3);
			wait (3);
			//soul_move Delete ();
		}
		
		if (isdefined(self.script_notify))
		{
			flag = self.script_notify;
			level notify ( flag );
			level flag::set ( flag );
		}

		if(level.collectors.size > 1)
		{
			ArrayRemoveValue( level.collectors, self );
		}

		self Delete ();
	}
}

function cleanup_fx_origin( fx_origin )
{
	fx_origin endon( "death" );
	self waittill( "collection_complete" );
	if( isdefined( fx_origin ) ) 
	{
		fx_origin Delete();
	}
}

function single_reward()
{
	// Make up some logic if you want a reward upon completion of a single collector
	// level.collectors_complete++;
}




