.data
    SRC0: 0x0f
    SRC1: 0x12
    DST: 0x00
.code
    LOAD    R0,SRC0
    LOAD    R1,SRC1
    ADD     R0,R1
    STORE   R0,DST
    HALT
