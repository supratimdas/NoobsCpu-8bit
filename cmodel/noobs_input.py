import ctypes
import time
import numpy as np
import matplotlib.pyplot as plt
import threading

# Load the shared memory library
myLib = ctypes.CDLL("./libshared_util.so")
myLib.init_shared_memory()

while True:
    ##myLib.update_shared_memory(ctypes.c_uint8(int(np.random.rand(1)*200)),ctypes.c_uint8(int(np.random.rand(1)*200)),ctypes.c_uint8(int(np.random.rand(1)*200)))
    myLib.update_shared_memory(
        ctypes.c_uint8(int(np.random.rand(1)[0] * 200)),
        ctypes.c_uint8(int(np.random.rand(1)[0] * 200)),
        ctypes.c_uint8(int(np.random.rand(1)[0] * 200))
    )
    time.sleep(5)
