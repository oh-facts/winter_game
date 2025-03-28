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
	Impolo_Sword;
	Impolo_East;
	Impolo;
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
	art_id : ArtId;
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

art_store_init :: () -> Art_Store {
	out : Art_Store;
	out.slots.count = 256;
	out.slots.data = push_array(arena, Art_Slot, xx out.slots.count);
	
	return out;
}

art_store : Art_Store;

tex_from_art :: (scope : *tex.Scope, art_id : ArtId) -> r.Handle {
	out : r.Handle;
	
	art := get_art(*art_store, art_id);
	
	out = tex.handle_from_hash(scope, art.hash);
	return out;
}

tex_id_from_art :: (scope : *tex.Scope, art_id : ArtId) -> u64 {
	return tex_from_art(scope, art_id).U64[1];
}

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
	
	for 0 .. ArtId.COUNT - 1 {
		src := get_art(*art_store, it);
		dst := art_saves + cast(int) it;
		<< dst = src.base;
	}
	
	for 0 .. ArtId.COUNT - 1 {
		src := get_art(*art_store, it);
		dst := art_saves + cast(int) it;
		
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
	count : int;
	if file_data {
		head := file_data.data;
		
		count = << cast(*int) head;
		head += size_of(int);
		
		art_saves : *Art_Save = xx head;
		head += size_of(Art_Save) * count;
		
		for 0 .. count - 1{
			src := art_saves + it;
			dst := get_art(*art_store, xx it);
			
			name := alloc_string(src.path.count);
			offset : int = xx src.path.data;
			
			dst.base = src;
			
			memcpy(name.data, file_data.data + offset, src.path.count);
			dst.path = name;
		}
	}
	
	free(file_data);
	
	// load sprites
	
	for 0 .. count - 1 {
		art := get_art(*art_store, xx it);
		
		filename := tprint("%/%", data_folder, art.path);
		
		data := read_entire_file(art.path);
		
		art.hash =  tex.hash_from_key_data(art.path, .{.[xx it]}, data);
		
	}
}