import ctypes
import time
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
import threading

h_wid=24
v_wid=16
NUM_BYTES = 48

fb_2d = np.random.rand(v_wid,h_wid)
# Load the shared memory library
myLib = ctypes.CDLL("./libshared_util.so")
myLib.init_shared_memory()

while True:
    myLib.read_updated_shared_memory()
    ram = (ctypes.c_uint8 * (ctypes.c_int.in_dll(myLib,"size")).value).in_dll(myLib, "shared_memory")
    # Convert the ctypes array to a NumPy array
    np_ram = np.ctypeslib.as_array(ram)
    # get frame_buffer
    fb_linear = np_ram[8:8+NUM_BYTES]
    fb_byte_map = fb_linear.reshape(v_wid,int(h_wid/8))
    #print(fb_byte_map)
    #fb_2d = fb_linear.reshape(64,64)
    ## Display the 2D array using Matplotlib
    for x in range(0,v_wid):
        for y1 in range(0,int(h_wid/8)):
            for y2 in range(0,8):
                y=((y1*8)+y2)
                fb_2d[x][y] = ((fb_byte_map[x][y1] & (1<<(7-y2))) > 0)

    plt.imshow(fb_2d, cmap='viridis')
    plt.colorbar()
    plt.pause(0.1)  # Pause for a short time to allow the plot to update
    plt.clf()  # Clear the plot for the next iteration
    #print(fb_byte_map)
    #print(fb_2d)
    exit
    #time.sleep(1)
