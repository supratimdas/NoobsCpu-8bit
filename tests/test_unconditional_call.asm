.data
    SRC: 0x55
    DST: 0x00
.code
    LOAD    R0,SRC
    CALL    STORE_DST
    ORI     R0,R0,0xaa
    STORE   R0,0xf
    HALT
 

STORE_DST:  STORE R0,DST
            RET
