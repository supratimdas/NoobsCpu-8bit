import ctypes
import time
import numpy as np
import matplotlib.pyplot as plt
import threading

fb_2d_64x64 = np.random.rand(64,64)
# Load the shared memory library
myLib = ctypes.CDLL("./libshared_util.so")
myLib.init_shared_memory()

while True:
    myLib.read_updated_shared_memory()
    ram = (ctypes.c_uint8 * (ctypes.c_int.in_dll(myLib,"size")).value).in_dll(myLib, "shared_memory")
    # Convert the ctypes array to a NumPy array
    np_ram = np.ctypeslib.as_array(ram)
    # get frame_buffer
    fb_linear = np_ram[8:8+512]
    fb_byte_map = fb_linear.reshape(64,8)
    #print(fb_linear)
    #fb_2d_64x64 = fb_linear.reshape(64,64)
    ## Display the 2D array using Matplotlib
    for x in range(0,64):
        for y1 in range(0,8):
            for y2 in range(0,8):
                y=y1*8+y2
                fb_2d_64x64[x][y] = 255 if ((fb_byte_map[x][y1] & (1<<y2)) > 0) else 0

    plt.imshow(fb_2d_64x64, cmap='viridis')
    plt.colorbar()
    plt.pause(0.1)  # Pause for a short time to allow the plot to update
    plt.clf()  # Clear the plot for the next iteration
    #time.sleep(1)
