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
	
	// device selection
	{
		count : u32 = 0;
		res = vkEnumeratePhysicalDevices(state.instance, *count, xx 0);
		
		//phys_devices : [count]VkPhysicalDevice;
		//phys_devices : *VkPhysicalDevice = push_temp
		
		phys_devices := talloc_array(VkPhysicalDevice, count);
		features := talloc_array(VkPhysicalDeviceFeatures2, count);
		
		res = vkEnumeratePhysicalDevices(state.instance, *count, xx phys_devices.data);
		
		GpuState :: struct {
			discrete : bool;
			good : bool;
		};
		
		gpus := talloc_array(GpuState, count);
		
		for i : 0 .. count - 1{
			// we care for
			//dyn rendering, sync2, bda and descr indexing
			
			descr_indexing : VkPhysicalDeviceDescriptorIndexingFeaturesEXT = .{
				sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES_EXT
			};
			
			dyn_ren : VkPhysicalDeviceDynamicRenderingFeaturesKHR = .{
				sType = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
				pNext = *descr_indexing
			};
			
			sync2 : VkPhysicalDeviceSynchronization2FeaturesKHR = .{
				sType = .PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR,
				pNext = *dyn_ren
			};
			
			vk12_feat : VkPhysicalDeviceVulkan12Features = .{
				sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
				pNext = *sync2
			};
			
			features[i].sType = .PHYSICAL_DEVICE_FEATURES_2;
			features[i].pNext = *vk12_feat;
			
			props : VkPhysicalDeviceProperties;
			vkGetPhysicalDeviceProperties(phys_devices[i], *props);
			
			// print gpu details
			print("--------index %d--------\n", i);
			print("Name: %s\n",props.deviceName);
			print("Driver Version: %u.%u.%u\n",
						VK_VERSION_MAJOR(props.driverVersion),
						VK_VERSION_MINOR(props.driverVersion),
						VK_VERSION_PATCH(props.driverVersion));
			
			print("Api Version: %u.%u.%u\n",
						VK_VERSION_MAJOR(props.apiVersion),
						VK_VERSION_MINOR(props.apiVersion),
						VK_VERSION_PATCH(props.apiVersion));
			print("------------------------\n\n");
			
			vkGetPhysicalDeviceFeatures2(phys_devices[i], *features[i]);
			
			if (dyn_ren.dynamicRendering && sync2.synchronization2 && vk12_feat.bufferDeviceAddress && vk12_feat.descriptorIndexing && descr_indexing.descriptorBindingSampledImageUpdateAfterBind)
			{
				gpus[i].good = 1;
			}
			
			if(props.deviceType == .DISCRETE_GPU)
			{
				gpus[i].discrete = 1;
			}
		}
		
		print("Selected GPU\n");
		found_gpu := false;
		
		for i : 0 .. count - 1 {
			print("=========\n");
			print("index: %d\n", i);
			print("discrete: %d\n", gpus[i].discrete);
			print("good: %d\n", gpus[i].good);
			print("========\n");
			
			if gpus[i].discrete && gpus[i].good {
				found_gpu = 1;
				r_vulkan_state.phys_device = phys_devices[i];
				break;
			}
		}
		
		if !found_gpu {
			for i : 0 .. count - 1 {
				if(gpus[i].good) {
					found_gpu = 1;
					r_vulkan_state.phys_device = phys_devices[i];
					break;
				}
			}
		}
		
		if !found_gpu {
			print("Quitting. No good gpu\n");
			assert(xx 0);
		}
	}
	
	
}