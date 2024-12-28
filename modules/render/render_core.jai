Corner_00 :: 0;
Corner_01 :: 1;
Corner_10 :: 2;
Corner_11 :: 3;
Corner_COUNT :: 4;

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

Batch :: struct {
	base : *u8;
	count : u32;
	size : u32;
	cap : u32;
	next : *Batch;
};

BatchList :: struct {
	first : *Batch;
	last : *Batch;
	count : u32;
};

push_batch :: (list : *BatchList, cap : u32) -> *Batch {
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

push_rect2 :: (list : *BatchList, dst : RectF32, color : Vector4) -> *Rect2 {	
	batch := list.last;
	
	if !batch || (batch.cap < batch.size + size_of(Rect2)) {
		batch = push_batch(list, 1024);
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

push_text :: (list : *BatchList, font : Font, text : string, _pos : Vector2, size : float32, color := Vector4.{1, 1, 1, 1}) {
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
		push_rect2(list, ext, .{1, 0, 0, 0.7});
	}
}

get_text_rect:: (font : Font, text : string, _pos : Vector2, size : float32) -> RectF32{
	pos := _pos;
	pos.y += (font.ascent + font.descent) * size;
	
	origin := pos;
	
	ext : RectF32;
	
	index := 0;
	for c : text {
		defer index += 1;
		
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
		
		pos.x += glyph.advance.x * size;
	}
	
	return ext;
}