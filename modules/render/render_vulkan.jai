#import "mizu_base";
#import "Vulkan";
os :: #import "os";
#import "Basic";
#import "SDL";

State :: struct {
	arena : Arena;
	instance : VkInstance;
};

state : *State;

vk_assert :: (res : VkResult) {
	if(res != .SUCCESS)
	{
		print("VkResult is not great success; code: %d\n", res);
		assert(xx 0);
	}
}

init :: (win : os.Handle) {
	
	arena := arena_init();
	state = arena_push(arena, State, 1);
	state.arena = arena;
	
	res : VkResult = .ERROR_INITIALIZATION_FAILED;
	
	// instance creation
	{
		version : u32;
		
		vkEnumerateInstanceVersion(*version);
		
		print("\nInstance Version: %.%.%\n\n" ,VK_VERSION_MAJOR(version) ,VK_VERSION_MINOR(version), VK_VERSION_PATCH(version));
		
		validation_layers : []*u8 = .["VK_LAYER_KHRONOS_validation"];
		
		user_extentions : []*u8 = .[VK_KHR_SURFACE_EXTENSION_NAME, VK_EXT_DEBUG_UTILS_EXTENSION_NAME, VK_KHR_WIN32_SURFACE_EXTENSION_NAME];
		
		
		app_info : VkApplicationInfo = .{
			sType = .APPLICATION_INFO,
			pNext = xx 0,
			pApplicationName = "Alfia",
			applicationVersion = 1,
			pEngineName = "Saoirse",
			engineVersion = 1,
			apiVersion = VK_API_VERSION_1_2
		};
		
		inst_info :VkInstanceCreateInfo = .{
			sType = .INSTANCE_CREATE_INFO,
			pNext = xx 0,
			pApplicationInfo = *app_info,
			enabledLayerCount = xx validation_layers.count,
			ppEnabledLayerNames = validation_layers.data,
			enabledExtensionCount = xx user_extentions.count,
			ppEnabledExtensionNames = user_extentions.data
		};
		
		res = vkCreateInstance(*inst_info, xx 0, *state.instance);
		
		vk_assert(res);
	}
	
	{
		
		
	}
	
}