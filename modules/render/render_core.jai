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

TexParams :: enum {
	LINEAR;
	NEAREST;
}

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

Beam :: struct {
	offset : Vector2;
	pad : [2]float;
}

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
}

Pass :: struct {
	next : *Pass;
	kind : Pass_Kind;
	batches : BatchList;
	beam : Beam;
}

Pass_List :: struct {
	first : *Pass;
	last : *Pass;
	count : u32;
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
	}
	
	list.count += 1;
	
	return out;
}

push_rect2_impl :: (kind : Pass_Kind, list : *Pass_List, dst : RectF32, color : Vector4) -> *Rect2 {
	pass := list.last;
	
	if !pass || pass.kind != kind {
		pass = push_pass(list, kind);
	}
	
	batches := *pass.batches;
	batch := batches.last;
	
	if !batch || (batch.cap < batch.size + size_of(Rect2)) {
		batch = push_batch(batches, xx MB(1));
		// set state params
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

push_beam :: (list : *Pass_List) {
	pass := list.last;
	
	if !pass || pass.kind != .Beam {
		pass = push_pass(list, .Beam);
	}
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
	bmp.w = 512;
	bmp.h = 512;
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
		
		pos.x += glyph.advance.x * size;
		
	}
	
	ext.max.x = max_width;
	
	return ext;
}