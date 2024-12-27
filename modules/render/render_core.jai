Corner_00 :: 0;
Corner_01 :: 1;
Corner_10 :: 2;
Corner_11 :: 3;
Corner_COUNT :: 4;

Handle :: struct {
	U32 : [2]u32;
	U64 : [2]u64;
};

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

push_rect2 :: (list : *BatchList, dst : RectF32, color : Vector4) -> Rect2 {	
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