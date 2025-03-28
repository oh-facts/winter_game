data_folder : string;
ell : r.Handle;
font : *r.Font;
// TODO(mizu): For now, make an art store that stores the arts. Make it a hashmap that uses art id as key. Maybe put art data inside of animation?
// This way I can trivially deal with animated tiles, among other things.

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

Pather :: struct {
	path : string;
} 

Art_Save :: struct {
	frame_x : int;
	frame_y : int;
	using pather : Pather;
	origin : Vector2;
}

Art :: struct {
	using base : Art_Save;
	hash : u128;
}

arts : [ArtId.COUNT]Art;

editor_titlebar_art : r.Handle;
editor_home_art : r.Handle;
editor_data_folder : string;
art_folder : string;

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

// TODO(mizu): save file should be with relative paths. Convert to active when loading assets

save_assets :: () {
	path := tprint("%/art.data", data_folder);
	
	save_arena := arena_init();
	data := push_array(save_arena, u8, 0);
	
	count : *int = xx push_struct(save_arena, int);
	<< count = xx ArtId.COUNT;
	// arts
	art_saves : *Art_Save = xx push_array(save_arena, Art_Save, xx ArtId.COUNT);
	
	for arts {
		src := it;
		dst := art_saves + it_index;
		<< dst = src.base;
	}
	
	for arts {
		src := it;
		dst := art_saves + it_index;
		
		push_array(save_arena, u8, xx 0);
		
		dst.path.data = xx (save_arena.used - ARENA_HEADER_SIZE);
		
		name : *u8 = push_array(save_arena, u8, xx src.path.count);
		
		memcpy(name, src.path.data, src.path.count);
		dst.path.count = src.path.count;
	}
	
	write_entire_file(path, data, xx save_arena.used - ARENA_HEADER_SIZE);
}

load_assets :: () {
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder = join(base_path, "../data");
	art_folder = join(data_folder, "/art");
	editor_data_folder = join(data_folder, "/editor");
	
	path := tprint("%/art.data", data_folder);
	file_data := read_entire_file(path);
	
	if file_data {
		head := file_data.data;
		
		count : int = << cast(*int) head;
		head += size_of(int);
		
		art_saves : *Art_Save = xx head;
		head += size_of(Art_Save) * count;
		
		for 0 .. count - 1{
			src := art_saves + it;
			dst := *arts[it];
			
			name := alloc_string(src.path.count);
			offset : int = xx src.path.data;
			
			dst.base = src;
			
			memcpy(name.data, file_data.data + offset, src.path.count);
			dst.path = name;
		}
	}
	
	free(file_data);
	
	// load sprites
	for *arts {
		filename := tprint("%/%", data_folder, it.path);
		
		data := read_entire_file(it.path);
		it.hash =  tex.hash_from_key_data(it.path, .{.[xx it_index]}, data);
		
	}
}