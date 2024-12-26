#if OS == .WINDOWS #import "Windows";

#import "Basic";
#import "Compiler";
#import "File";

build :: () {
	options := get_build_options();
	args := options.compile_time_command_line;
	print("args: %\n", args);
	
	if !args {
		w := compiler_create_workspace("winter");
		target_options := get_build_options(w);
		target_options.output_executable_name = "winter";
		target_options.output_path = ".build/";
		set_build_options(target_options, w);
		
		add_build_file("src/main.jai", w);

		#if OS == .WINDOWS
			file_link(".build/SDL2.dll", "bin/SDL2.dll");
	}
	
	for args {
		if it == "clean" {
			delete_directory(".build/");
		}
	}
	
	set_build_options_dc(.{do_output=false});
}

#run build();