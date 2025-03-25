data_folder : string;
ell : r.Handle;
font : *r.Font;

ArtId :: enum {
	TerrainTemplate;
	TerrainGrass;
	PropsForest;
	TilesForest;
	Impolo;
	Impolo_East;
	Impolo_Sword;
	Ell;
	Tree;
	Ball;
	Siren;
	Fat;
	Aos;
	Psy_Man_Dead;
	Psy_Man;
	COUNT;
}

Art_Save :: struct {
	id : ArtId;
	frame_x : int;
	frame_y : int;
	path : string;
	origin : Vector2;
}

Art :: struct {
	using base : Art_Save;
	hash : u128;
}

arts : []Art;
editor_titlebar_art : r.Handle;
editor_home_art : r.Handle;
editor_data_folder : string;

load_editor_assets :: () {
	
	load_editor_asset :: (path : string) -> r.Handle {
		filename := tprint("%/%", editor_data_folder, path);
		data := read_entire_file(filename);
		bmp := bitmap(data);
		
		out := r.image(bmp, .Linear);
		
		bitmap_free(*bmp);
		free(data);
		
		return out;
	}
	
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder = join(base_path, "../data");
	editor_data_folder = join(base_path, "../data/editor");
	
	editor_titlebar_art = load_editor_asset("titlebar.png");
	editor_home_art = load_editor_asset("home.png");
}

load_font :: () {
	filename := tprint("%/%", data_folder, "fonts/font.data");
	data := read_entire_file(filename);
	font = xx data.data;
	filename = tprint("%/%", data_folder, "fonts/font.png");
	
	temp_file_data := read_entire_file(filename);
	defer free(temp_file_data);
	
	font.bmp = bitmap(temp_file_data);
	font.img = r.image(font.bmp, .Linear);
}

/*
arts : [18]Art = .[.{id = .TerrainTemplate, path = "art/terrain_template.png"},
									 .{id = .TerrainGrass, path = "art/terrain_grass2.png"},
									 .{id = .PropsForest, path = "art/forest_props.png"},
									 .{id = .TilesForest, path = "art/forest_tileset.png"},
									 .{id = .Impolo, path = "art/impolo-idle.png"},
									 .{id = .Impolo_East, path = "art/impolo-east.png"},
									 .{id = .Impolo_Sword, path = "art/impolo-sword.png"},
									 .{id = .Ell, path = "art/ell.png"},
									 .{id = .Tree, path = "art/tree.png"},
									 .{id = .Ball, path = "art/ball.png"},
									 .{id = .Siren, path = "art/siren.png"},
									 .{id = .Editor_Titlebar, path = "editor/titlebar.png"},
									 .{id = .Fat, path = "art/fat/1.png"},
									 .{id = .Editor_Window_Notch, path = "editor/window_notch.png"},
									 .{id = .Aos, path = "art/aos.png"},
									 .{id = .Editor_Home_Bg, path = "editor/home.png"}, 
									 .{id = .Psy_Man_Dead, path = "art/psy_man_dead.png"},
									 .{id = .Psy_Man, path = "art/psy_man.png"}];
*/

load_all_assets :: () {
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder = join(base_path, "../data");
	
	// load sprites
	for *arts {
		filename := tprint("%/%", data_folder, it.path);
		
		data := read_entire_file(filename);
		it.hash =  tex.hash_from_key_data(it.path, .{.[xx it_index]}, data);
		
		if it.id == {
			case .Impolo;
			it.frame_x = 1;
			it.frame_y = 1;
			it.origin = .{64, 96};
			
			case .TilesForest;
			it.frame_x = 8;
			it.frame_y = 15;
			
			case .Tree;
			it.frame_x = 3;
			it.frame_y = 1;
			it.origin = .{256, 380};
			
			case .Ball;
			it.frame_x = 1;
			it.frame_y = 1;
			it.origin  = .{16, 32};
			
			case .Siren;
			it.frame_x = 1;
			it.frame_y = 1;
			it.origin = .{250, 500};
			
			case .Impolo_East;
			it.frame_x = 8;
			it.frame_y = 1;
			it.origin = .{64, 96};
			
			case .Aos;
			it.frame_x = 2;
			it.frame_y = 1;
			it.origin = .{65, 110};
			
			case .Psy_Man_Dead;
			it.frame_x = 1;
			it.frame_y = 1;
			it.origin = .{90, 110};
			
			case .Psy_Man;
			it.frame_x = 1;
			it.frame_y = 1;
			it.origin = .{32, 110};
		}
		
	}
}

save_assets :: () {
	
}

load_assets :: () {
	
}