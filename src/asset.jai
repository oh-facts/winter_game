// TODO(mizu): For when you come later, work on freeing memory from here and tex cache

exe_folder : string;
data_folder : string;
editor_data_folder : string;
art_folder : string;

font : *r.Font;
editor_titlebar_art : r.Handle;
editor_home_art : r.Handle;

// NOTE(mizu): Merge animation and art store?

ArtId :: enum #specified {
	TerrainTemplate :: 0;
	TerrainGrass :: 1;
	PropsForest :: 2;
	TilesForest :: 3;
	Impolo :: 4;
	Impolo_East :: 5;
	Impolo_Sword :: 6;
	Ell :: 7;
	Tree :: 8;
	Ball :: 9;
	Siren :: 10;
	Fat :: 11;
	Aos :: 12;
	Psy_Man_Dead :: 13;
	Psy_Man :: 14;
	COUNT :: 15;
}

Asset_Filepath :: struct {
	path : string;
} 

Art_Save :: struct {
	frame_x : int;
	frame_y : int;
	using filepath : Asset_Filepath;
	origin : Vector2;
	art_id : ArtId;
}

Art :: struct {
	using base : Art_Save;
	hash : u128;
}

Art_Node :: struct {
	using v : Art;
	next : *Art_Node;
}

Art_Slot :: struct {
	first : *Art_Node;
	last : *Art_Node;
}

Art_Store :: struct {
	slots : []Art_Slot;
}

hash_from_art :: (art_id : ArtId) -> int {
	hash := 5381;
	
	hash = ((hash << 5) + hash) + xx art_id;
	
	return hash;
}

get_art :: (as : *Art_Store, art_id : ArtId) -> *Art {
	out : *Art;
	hash := hash_from_art(art_id);
	slot_index := hash % xx as.slots.count;
	slot := as.slots.data + slot_index;
	
	node : *Art_Node;
	{
		cur := slot.first;
		
		while cur {
			if cur.art_id == art_id {
				node = cur;
			}
			cur = cur.next;
		}
	}
	
	if !node {
		node = xx push_struct(arena, Art_Node);
		node.art_id = art_id;
		
		if !slot.last {
			slot.first = node;
			slot.last = node;
		} else {
			slot.last.next = node;
			slot.last = node;
		}
	}
	
	out = *node.v;
	
	return out;
}

art_store : Art_Store;

asset_init :: () {
	
	// init data folder paths
	{
		exe_folder = path_strip_filename(get_path_of_running_executable());
		data_folder = join(exe_folder, "../data");
		art_folder = join(data_folder, "/art");
		editor_data_folder = join(data_folder, "/editor");
	}
	
	// init art store
	{
		art_store.slots.count = 256;
		art_store.slots.data = push_array(arena, Art_Slot, xx art_store.slots.count);
	}
	
	// load assets
	{
		load_assets();
	}
	
	// load editor assets
	{
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
	
	// load fonts
	{
		filename := tprint("%/%", data_folder, "fonts/font.data");
		data := read_entire_file(filename);
		font = xx data.data;
		filename = tprint("%/%", data_folder, "fonts/font.png");
		
		temp_file_data := read_entire_file(filename);
		defer free(temp_file_data);
		
		font.bmp = bitmap(temp_file_data);
		font.img = r.image(font.bmp, .Linear);
	}
}

tex_from_art :: (scope : *tex.Scope, art_id : ArtId) -> r.Handle {
	out : r.Handle;
	
	art := get_art(*art_store, art_id);
	
	out = tex.handle_from_hash(scope, art.hash);
	return out;
}

tex_id_from_art :: (scope : *tex.Scope, art_id : ArtId) -> u64 {
	return tex_from_art(scope, art_id).U64[1];
}

save_assets :: () {
	path := tprint("%/art.data", data_folder);
	
	save_arena := arena_init();
	data := push_array(save_arena, u8, 0);
	
	count : *int = xx push_struct(save_arena, int);
	<< count = xx ArtId.COUNT;
	// arts
	art_saves : *Art_Save = xx push_array(save_arena, Art_Save, xx ArtId.COUNT);
	
	for 0 .. ArtId.COUNT - 1 {
		src := get_art(*art_store, it);
		dst := art_saves + cast(int) it;
		<< dst = src.base;
	}
	
	for 0 .. ArtId.COUNT - 1 {
		src := get_art(*art_store, it);
		
		dst := art_saves + cast(int)it;
		
		push_array(save_arena, u8, xx 0);
		
		dst.path.data = xx (save_arena.used - ARENA_HEADER_SIZE);
		
		name : *u8 = push_array(save_arena, u8, xx src.path.count);
		
		memcpy(name, src.path.data, src.path.count);
		dst.path.count = src.path.count;
	}
	
	write_entire_file(path, data, xx save_arena.used - ARENA_HEADER_SIZE);
	
	arena_free(save_arena);
}

submit_assets :: () {
	for 0 .. ArtId.COUNT - 1 {
		art := get_art(*art_store, xx it);
		
		filename := tprint("%/%", art_folder, art.path);
		
		data := read_entire_file(filename);
		
		art.hash =  tex.hash_from_key_data(art.path, .{.[xx it]}, data);
		
	}
}

load_assets :: () {
	
	// load from disk
	count : int;
	{
		path := tprint("%/art.data", data_folder);
		file_data := read_entire_file(path);
		if file_data {
			head := file_data.data;
			
			count = << cast(*int) head;
			head += size_of(int);
			
			art_saves : *Art_Save = xx head;
			head += size_of(Art_Save) * count;
			
			for 0 .. count - 1 {
				src := art_saves + it;
				dst := get_art(*art_store, src.art_id);
				
				name := alloc_string(src.path.count);
				offset : int = xx src.path.data;
				
				dst.base = src;
				
				memcpy(name.data, file_data.data + offset, src.path.count);
				dst.path = name;
			}
		}
		
		free(file_data);
	}
	
	// submit to texture cache
	submit_assets();
}