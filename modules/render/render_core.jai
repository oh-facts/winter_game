Corner_00 :: 0;
Corner_01 :: 1;
Corner_10 :: 2;
Corner_11 :: 3;
Corner_COUNT :: 4;

COLOR_WHITE :: Vector4.{1, 1, 1, 1};
COLOR_BLACK :: Vector4.{0, 0, 0, 1};

COLOR_RED :: Vector4.{1, 0, 0, 1};
COLOR_GREEN :: Vector4.{0, 1, 0, 1};
COLOR_BLUE :: Vector4.{0, 0, 1, 1};
COLOR_YELLOW :: Vector4.{1, 1, 0, 1};
COLOR_CYAN :: Vector4.{0, 1, 1, 1};
COLOR_MAGENTA :: Vector4.{1, 0, 1, 1};

COLOR_ORANGE :: Vector4.{0.79, 0.33, 0, 1};

Tex_Params :: enum {
	Linear;
	Nearest;
}

// NOTE(mizu):
// U32 : w, h
// U64 : ptr, tex_id

Handle :: struct {
	U32 : [2]u32;
	U64 : [2]u64;
}

Rect2 :: struct {
	src : RectF32;
	dst : RectF32;
	border_color : Vector4;
	fade : [Corner_COUNT]Vector4;
	tex_id : u64;
	pad : [2]u32;
	border_thickness : float32;
	radius : float32;
	pad2 : [2]float32;
};

// NOTE(mizu): The last thing you were doing was moving beam data to render pass

Batch :: struct {
	base : *u8;
	count : u32;
	size : s64;
	cap : s64;
	next : *Batch;
};

BatchList :: struct {
	first : *Batch;
	last : *Batch;
	count : u32;
};

Pass_Kind :: enum {
	Sprite;
	UI;
	Beam;
	Begin_Water;
	End_Water;
	Voxel;
}

Pass :: struct {
	next : *Pass;
	kind : Pass_Kind;
	batches : BatchList;
	beam_pos : Vector2;
	scissor : RectF32;
}

// TODO(mizu): I am thinking I make a pass list list for highest level data like screen size 

// NOTE(mizu): Might be too much for now
// Another (good) idea is to have the submit 
// function inside each mode.
// This is so I can get rid of the stupid camera I made
// Also make a struct for mode
// maybe give it a update mode, submit mode
// much like the window update and submit you
// made in the mizu mizu 1 million engine
// Also make it easy to draw to images, etc. etc
// And also see if you can copy all batches to 
// one big buffer, then do a big call. 
// So basically one draw call per pass instead of one draw call per batch
// Idk, if it would run better (all those memcpys)
// but profile it. Will be fun.
// the gpu calls themselves are negligible
// so possible all that cpu memcpying would be
// expensive? No clue. Have a crack.
// also do the blur properly.
// basically make render_opengl very good

Pass_List :: struct {
	first : *Pass;
	last : *Pass;
	count : u32;
	
	gen : u64;
	last_gen : u64;
	
	scissor_stack : struct {
		top : *Scissor_Node;
	}
}

Scissor_Node :: struct {
	next : *Scissor_Node;
	v : RectF32;
}

push_voxel :: (list :*Pass_List) {
	pass := list.last;
	
	if !pass || pass.kind != .Voxel || (list.gen != list.last_gen){
		pass = push_pass(list, .Voxel);
	}
}

push_scissor :: (list : *Pass_List, v : RectF32) {
	node : *Scissor_Node = xx tpush_struct(Scissor_Node);
	node.v = v;
	node.next = list.scissor_stack.top;
	list.scissor_stack.top = node;
	list.gen += 1;
}

pop_scissor :: (list : *Pass_List) {
	list.scissor_stack.top = list.scissor_stack.top.next;
	list.gen += 1;
}

push_batch :: (list : *BatchList, cap : s64) -> *Batch {
	out : *Batch = talloc(size_of(Batch));
	<< out = .{};
	
	if !out {
		i := 1;
	};
	
	if !list.first {
		list.last = out;
		list.first = out;
	}
	else {
		list.last.next = out;
		list.last = out;		
	}
	
	out.cap = cap;
	out.base = talloc(size_of(u8) * cap);
	list.count+=1;
	
	return out;
}

null_scissor_node : Scissor_Node = .{
	v = .{.{0, 0}, .{1920, 1051}}
};

ooga := 0;

push_pass :: (list : *Pass_List, kind : Pass_Kind) -> *Pass{
	out : *Pass = talloc(size_of(Pass));
	<< out = .{};
	out.kind = kind;
	
	if list.last {
		list.last.next = out;
		list.last = out;
	} else {
		list.last = out;
		list.first = out;
		//list.scissor_stack.top = *null_scissor_node;
	}
	
	list.count += 1;
	
	return out;
}

push_rect2_impl :: (kind : Pass_Kind, list : *Pass_List, dst : RectF32, color : Vector4) -> *Rect2 {
	pass := list.last;
	
	if !pass || pass.kind != kind || (list.gen != list.last_gen){
		pass = push_pass(list, kind);
		
		// set state params
		pass.scissor = list.scissor_stack.top.v;
		list.last_gen = list.gen;
	}
	
	batches := *pass.batches;
	batch := batches.last;
	
	if !batch || (batch.cap < batch.size + size_of(Rect2)) {
		batch = push_batch(batches, xx MB(1));
	}
	
	out :*Rect2= xx (batch.base + batch.size);
	out.dst = dst;
	out.src = rectF32(0, 0, 1, 1);
	out.fade[Corner_00] = color;
	out.fade[Corner_01] = color;
	out.fade[Corner_10] = color;
	out.fade[Corner_11] = color;
	out.tex_id = get_white_square().U64[1];
	
	// NOTE(mizu): figure out why there is a 1px ghost outline even when thickness is 0f
	out.border_color = color;
	out.radius = 0; 
	out.border_thickness = 0;
	
	batch.count+=1;
	batch.size += size_of(Rect2);
	
	return out;
}

push_rect2 :: (list : *Pass_List, dst : RectF32, color : Vector4) -> *Rect2 {	
	return push_rect2_impl(.UI, list, dst, color);
}

push_sprite :: (list : *Pass_List, dst : RectF32, color : Vector4) -> *Rect2 {	
	return push_rect2_impl(.Sprite, list, dst, color);
}

push_beam :: (list : *Pass_List, pos : Vector2) {
	pass := list.last;
	
	if !pass || pass.kind != .Beam {
		pass = push_pass(list, .Beam);
	}
	
	pass.beam_pos = pos;
}

begin_water :: (list : *Pass_List) {
	pass := list.last;
	
	if !pass || pass.kind != .Begin_Water {
		pass = push_pass(list, .Begin_Water);
	}
}

end_water :: (list : *Pass_List) {
	pass := list.last;
	
	if !pass || pass.kind != .End_Water {
		pass = push_pass(list, .End_Water);
	}
}

Glyph :: struct {
	uv : Vector2;
	size : Vector2;
	offset : Vector2;
	advance : Vector2;
};

Font :: struct {
	size : int;
	glyphs : [128]Glyph;
	img : Handle;
	line_height : s32;
	ascent : s32;
	descent : s32;
	
	using bmp : Bitmap;
	bmp.w = 128;
	bmp.h = 128;
	bmp.n = 4;
};

push_text :: (list : *Pass_List, font : Font, text : string, _pos : Vector2, size : float32, color := Vector4.{1, 1, 1, 1}) {
	
	pos := _pos;
	pos.y += (font.ascent + font.descent) * size;
	
	origin := pos;
	
	ext : RectF32;
	
	index := 0;
	for c : text {
		defer index += 1;
		
		if c == #char "\n" {
			pos.x = origin.x;
			pos.y += font.line_height * size;
			continue;
		}
		
		glyph := font.glyphs[xx c];
		defer pos.x += glyph.advance.x * size;
		
		if c == #char " " {
			continue;
		}
		
		dst : RectF32;
		dst.min.x = pos.x + glyph.offset.x * size;
		dst.min.y = pos.y - glyph.offset.y * size;
		
		dst.max.x = dst.min.x + glyph.size.x * size;
		dst.max.y = dst.min.y + glyph.size.y * size;
		
		if(index == 0) {
			ext.min.x = dst.min.x;
			ext.min.y = dst.min.y;
		}
		
		ext.min.y = min(ext.min.y, dst.min.y);
		ext.min.x = min(ext.min.x, dst.min.x);
		ext.max.y = max(ext.max.y, dst.max.y);
		ext.max.x = dst.max.x;
		
		src : RectF32;
		src.min.x = glyph.uv.x / font.bmp.w;
		src.max.y = glyph.uv.y / font.bmp.h;
		src.max.x = src.min.x + glyph.size.x / font.bmp.w;
		src.min.y = src.max.y + glyph.size.y / font.bmp.h;
		
		// glyph rect
		ifx 0 {
			push_rect2(list, dst, .{0, 0, 1, 1});
		}
		
		rect2 := push_rect2(list, dst, color);
		rect2.tex_id = font.img.U64[1];
		rect2.src = src;
	}
	// text rect 
	ifx 0 {
		push_rect2(list, ext, .{0, 0, 0, 0.7});
	}
}

get_text_rect :: (font : Font, text : string, _pos : Vector2, size : float32) -> RectF32{
	pos := _pos;
	
	pos.y += (font.ascent + font.descent) * size;
	
	origin := pos;
	
	ext : RectF32;
	max_width : float32;
	index := 0;
	for c : text {
		defer index += 1;
		
		if c == #char "\n" {
			pos.x = origin.x;
			pos.y += font.line_height * size;
			continue;
		}
		
		glyph := font.glyphs[xx c];
		defer pos.x += glyph.advance.x * size;
		
		if c == #char " " {
			ext.max.x += glyph.advance.x * size;
			max_width += glyph.advance.x * size;
			continue;
		}
		
		dst : RectF32;
		dst.min.x = pos.x + glyph.offset.x * size;
		dst.min.y = pos.y - glyph.offset.y * size;
		
		dst.max.x = dst.min.x + glyph.size.x * size;
		dst.max.y = dst.min.y + glyph.size.y * size;
		
		if(index == 0) {
			ext.min.x = dst.min.x;
			ext.min.y = dst.min.y;
		}
		
		ext.min.y = min(ext.min.y, dst.min.y);
		ext.max.y = max(ext.max.y, dst.max.y);
		
		ext.min.x = min(ext.min.x, dst.min.x);
		ext.max.x = dst.max.x;
		max_width = max(max_width, ext.max.x);
	}
	
	ext.max.x = max_width;
	
	return ext;
}

