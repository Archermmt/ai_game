extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var views:Dictionary={};var passed=true
	for name in ["harbor","orbit","house","shore","whole","sunset"]:
		var before=Image.load_from_file("res://snapshots/art_i6/instancing_off/"+name+".png");var after=Image.load_from_file("res://snapshots/art_i6/instancing_on/"+name+".png")
		if before==null or after==null or before.get_size()!=after.get_size():push_error("Missing or mismatched parity images");quit(1);return
		var sum=0.0;var changed=0;var pixels=before.get_width()*before.get_height()
		for y in range(before.get_height()):
			for x in range(before.get_width()):
				var a=before.get_pixel(x,y);var b=after.get_pixel(x,y);var d=Vector3(absf(a.r-b.r),absf(a.g-b.g),absf(a.b-b.b));sum+=(d.x+d.y+d.z)/3
				if maxf(d.x,maxf(d.y,d.z))>2.0/255.0+0.000001:changed+=1
		var mean=sum/pixels;var fraction=float(changed)/pixels;var okay=mean<0.001 and fraction<0.005;passed=passed and okay
		views[name]={"mean_rgb_error":mean,"changed_fraction_gt_2_255":fraction,"passed":okay}
	var report={"renderer":"gl_compatibility","scope":"Frozen bay six views, same world/clock; not animation or target-device acceptance","mean_error_limit":0.001,"changed_fraction_limit":0.005,"views":views,"passed":passed}
	var f=FileAccess.open("res://docs/reports/art_i6/instancing_parity.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("PASS instance pixels" if passed else "FAIL instance pixels");quit(0 if passed else 1)
