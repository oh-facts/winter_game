data_folder : string;
ell : r.Handle;
font : *r.Font;

ArtId :: enum {
	TerrainTemplate;
	TerrainGrass;
	PropsForest;
	TilesForest;
	Impolo;
	Ell;
	Tree;
	Ball;
}

Art :: struct {
	id : ArtId;
	name : string;
	path : string;
	tex : r.Handle;
	bmp : Bitmap;
}

arts : [8]Art = .[.{id = .TerrainTemplate, path = "art/terrain_template.png"}, 
									.{id = .TerrainGrass, path = "art/terrain_grass.png"},
									.{id = .PropsForest, path = "art/forest_props.png"},
									.{id = .TilesForest, path = "art/forest_tileset.png"},
									.{id = .Impolo, path = "art/impolo-east.png"},
									.{id = .Ell, path = "art/ell.png"},
									.{id = .Tree, path = "art/tree.png"},
									.{id = .Ball, path = "art/ball.png"}];

load_all_assets :: () {
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder = join(base_path, "../data");
	
	// load sprites
	for *arts {
		filename := tprint("%/%", data_folder, it.path);
		it.bmp = bitmap(arena, filename);
		it.tex = r.image(it.bmp, .NEAREST);
	}
	
	// load font
	{
		filename := tprint("%/%", data_folder, "fonts/font.data");
		data := read_entire_file(filename);
		font = xx data.data;
		filename = tprint("%/%", data_folder, "fonts/font.png");
		font.bmp = bitmap(arena, filename);
		font.img = r.image(font.bmp);
	}
}