extends RefCounted
## Small injectable filesystem boundary for failure/recovery tests.
func write_temp(path:String,text:String) -> Error:
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(text);file.flush();var error=file.get_error();file.close();return error
func copy(source:String,destination:String) -> Error:return DirAccess.copy_absolute(source,destination)
func replace(source:String,destination:String) -> Error:return DirAccess.rename_absolute(source,destination)
