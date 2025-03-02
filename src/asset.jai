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
	Displacement;
	Noise;
	Editor_Titlebar;
	COUNT;
}

Art :: struct {
	id : ArtId;
	frame_x : int;
	frame_y : int;
	hash : u128;
	path : string;
}

arts : [14]Art = .[.{id = .TerrainTemplate, path = "art/terrain_template.png"}, 
									 .{id = .TerrainGrass, path = "art/terrain_grass.png"},
									 .{id = .PropsForest, path = "art/forest_props.png"},
									 .{id = .TilesForest, path = "art/forest_tileset.png"},
									 .{id = .Impolo, path = "art/impolo-idle.png"},
									 .{id = .Impolo_East, path = "art/impolo-east.png"},
									 .{id = .Impolo_Sword, path = "art/impolo-sword.png"},
									 .{id = .Ell, path = "art/ell.png"},
									 .{id = .Tree, path = "art/tree.png"},
									 .{id = .Ball, path = "art/ball.png"},
									 .{id = .Siren, path = "art/siren.png"},
									 .{id = .Displacement, path = "art/displacement.png"},
									 .{id = .Noise, path = "art/noise.png"},
									 .{id = .Editor_Titlebar, path = "editor/titlebar.png"}];

load_all_assets :: () {
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder = join(base_path, "../data");
	
	// load sprites
	for *arts {
		filename := tprint("%/%", data_folder, it.path);
		
		data := read_entire_file(filename);
		it.hash =  tex.hash_from_key_data(it.path, .{.[xx it_index]}, data);
	}
	
	// load font
	{
		filename := tprint("%/%", data_folder, "fonts/font.data");
		data := read_entire_file(filename);
		font = xx data.data;
		filename = tprint("%/%", data_folder, "fonts/font.png");
		
		temp_file_data := read_entire_file(filename);
		defer free(temp_file_data);
		
		font.bmp = bitmap(temp_file_data);
		font.img = r.image(font.bmp);
	}
}