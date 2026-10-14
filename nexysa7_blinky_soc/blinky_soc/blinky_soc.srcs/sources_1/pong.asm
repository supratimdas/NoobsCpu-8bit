##NOOBS PONG for the Nexys A7 blinky_soc (VGA character display, 30 rows;
##court width set by the layout block in .data, currently 35 columns)
##
##needs the blinky_soc.v with the PROG char-path fix, clear-status readback at 102,
##and the push button register at 106
##
##memory mapped IO
##  100 LED     : toggled once per game tick (heartbeat)
##  102 VGA ctrl: write 1 = clear screen, 2 = PROG (row/col/char addressing)
##                read  = {4'b0, mode[1:0], cleared, clear_in_progress}
##  103 VGA row, 104 VGA col, 105 VGA char (PROG mode, one store per char)
##  106 buttons : 0 = none, 1 = up, 2 = down
##
##screen layout (W = SCREEN_W)
##  row 0      : player score (col 2), title, cpu score (col CSCORE_COL)
##  row 1, 29  : walls, cols 0..W-1
##  rows 2..28 : playfield, net at col NET_COL on even rows
##  col 1      : player paddle, col RP_COL : cpu paddle (4 rows tall, top row 2..25)
##
##ISA notes
##  flags are cleared by every JMP/CALL/RET, so recompute them before each conditional branch
##  plain JMP/CALL are conditional on leftover CR bits, so always use JMPNC/CALLNC
##  SUB sets OVF on borrow, so "SUB/SUBI then JMPOVF" is an unsigned less-than
##
##keep .data below address 100 (IO space starts there, data labels start at 8)
.data
##layout columns, for a 30 / 35 / 40 column court
##  SCREEN_W   30 / 35 / 40   wall length
##  RP_COL     28 / 33 / 38   cpu paddle column (player paddle is col 1)
##  NET_COL    15 / 17 / 20   net column, also where the ball is served from
##  CSCORE_COL 27 / 32 / 37   cpu score column (player score is col 2)
##  TITLE_COL  10 / 12 / 15   "NOOBS PONG"
##  PROMPT_COL  8 / 11 / 13   "PRESS UP/DOWN"
##  MSG_COL    11 / 13 / 16   "YOU WIN!" / "CPU WINS"
    SCREEN_W:35
    RP_COL:33
    NET_COL:17
    CSCORE_COL:32
    TITLE_COL:12
    PROMPT_COL:11
    MSG_COL:13
    BALL_X:17
    BALL_Y:15
    BALL_DX:1
    BALL_DY:1
    NEW_X:0
    NEW_Y:0
    LP_Y:13
    RP_Y:13
    CUR_Y:0
    CUR_COL:0
    P_SCORE:48
    C_SCORE:48
    GAME_OVER:0
    TICK:0
    LED_STATE:0
##BALL_SLOPE 0 = 45 degrees, 2 = shallow (vertical step on every other move);
##BALL_PHASE toggles 0/2 on every ball move
    BALL_SLOPE:0
    BALL_PHASE:0
##tuning knobs
##  frame delay = FRAME_OUTER x FRAME_INNER inner loop iterations of 6 cpu cycles;
##  at cpu_clk = 100MHz/64 = 1.5625MHz, 31 x 250 gives a ~30ms tick
##  POINT_PAUSE = frames to pause after a point (twice that after game over)
##  ball moves when (TICK & BALL_MASK) == 0
##  cpu paddle moves when AI_ACC += AI_SPEED carries, i.e. AI_SPEED/256 rows per tick
##  (the ball moves 0.5 rows per tick vertically, so 128 = as fast as the ball);
##  it only tracks a ball heading its way from column AI_REACT_COL onwards
##  (lower AI_REACT_COL or higher AI_SPEED = harder)
    FRAME_OUTER:31
    FRAME_INNER:250
    POINT_PAUSE:40
    BALL_MASK:1
    AI_SPEED:128
    AI_REACT_COL:22
    AI_ACC:0
##glyphs from the font rom: 8 = solid box, 7 = bullet, 22 = thick bar, 58 = ':'
    PADDLE_CH:8
    BALL_CH:7
    WALL_CH:22
    NET_CH:58
##strings (offsets from S_TITLE are used by PRINT_STR)
##  S_TITLE  offset 0  "NOOBS PONG"
##  S_PRESS  offset 11 "PRESS UP/DOWN"
##  S_YOUWIN offset 25 "YOU WIN!"
##  S_CPUWIN offset 34 "CPU WINS"
    S_TITLE:78,79,79,66,83,32,80,79,78,71,0
    S_PRESS:80,82,69,83,83,32,85,80,47,68,79,87,78,0
    S_YOUWIN:89,79,85,32,87,73,78,33,0
    S_CPUWIN:67,80,85,32,87,73,78,83,0

.code
##---------------------------------------------------------------------------
## (re)start: reset state, draw the board, wait for a button
##---------------------------------------------------------------------------
START:      XOR     R0,R0
            STORE   R0,GAME_OVER
            ADDI    R1,R0,48
            STORE   R1,P_SCORE
            STORE   R1,C_SCORE
            ADDI    R1,R0,13
            STORE   R1,LP_Y
            STORE   R1,RP_Y
            LOAD    R1,NET_COL
            STORE   R1,BALL_X
            ADDI    R1,R0,15
            STORE   R1,BALL_Y
            ADDI    R1,R0,1
            STORE   R1,BALL_DX
            STORE   R1,BALL_DY
##clear screen: request it, poll the "cleared" status bit, then PROG mode
            XOR     R0,R0
            ADDI    R0,R0,1
            STORE   R0,102
CLR_POLL:   LOAD    R0,102
            ANDI    R0,R0,2
            JMPZ    CLR_POLL
            XOR     R0,R0
            ADDI    R0,R0,2
            STORE   R0,102
##title and scores
            XOR     R1,R1
            LOAD    R2,TITLE_COL
            XOR     R3,R3
            CALLNC  PRINT_STR
            CALLNC  DRAW_SCORES
##walls
            XOR     R1,R1
            ADDI    R1,R1,1
            XOR     R2,R2
            LOAD    R3,SCREEN_W
            LOAD    R0,WALL_CH
            CALLNC  FILL
            XOR     R1,R1
            ADDI    R1,R1,29
            XOR     R2,R2
            LOAD    R3,SCREEN_W
            LOAD    R0,WALL_CH
            CALLNC  FILL
##paddles and prompt
            LOAD    R1,LP_Y
            XOR     R2,R2
            ADDI    R2,R2,1
            CALLNC  DRAW_PADDLE
            LOAD    R1,RP_Y
            LOAD    R2,RP_COL
            CALLNC  DRAW_PADDLE
            XOR     R1,R1
            ADDI    R1,R1,10
            LOAD    R2,PROMPT_COL
            ADDI    R3,R1,1
            CALLNC  PRINT_STR
##wait for all buttons released, then for a press (TICK spins meanwhile as a random seed)
WAIT_REL:   LOAD    R0,106
            ORI     R0,R0,0
            JMPNZ   WAIT_REL
WAIT_PRESS: LOAD    R0,TICK
            ADDI    R0,R0,1
            STORE   R0,TICK
            LOAD    R0,106
            ORI     R0,R0,0
            JMPZ    WAIT_PRESS
##erase the prompt, draw net and ball
            XOR     R1,R1
            ADDI    R1,R1,10
            LOAD    R2,PROMPT_COL
            ADDI    R3,R1,3
            XOR     R0,R0
            ADDI    R0,R0,32
            CALLNC  FILL
            CALLNC  DRAW_NET
            CALLNC  SERVE

##---------------------------------------------------------------------------
## main loop, one iteration per tick
##---------------------------------------------------------------------------
GAME_LOOP:  LOAD    R0,LED_STATE
            XORI    R0,R0,1
            STORE   R0,LED_STATE
            STORE   R0,100
            CALLNC  PLAYER_MOVE
            LOAD    R0,TICK
            ADDI    R0,R0,1
            STORE   R0,TICK
            LOAD    R1,BALL_MASK
            AND     R0,R1
            CALLZ   BALL_MOVE
            LOAD    R0,GAME_OVER
            ORI     R0,R0,0
            JMPNZ   GAME_END
            LOAD    R0,AI_ACC
            LOAD    R1,AI_SPEED
            ADD     R0,R1
            STORE   R0,AI_ACC
            CALLOVF AI_MOVE
            LOAD    R0,FRAME_OUTER
            LOAD    R2,FRAME_INNER
            CALLNC  DELAY
            JMPNC   GAME_LOOP

GAME_END:   XOR     R1,R1
            ADDI    R1,R1,12
            LOAD    R2,MSG_COL
            ADDI    R3,R1,13
            LOAD    R0,P_SCORE
            SUBI    R0,R0,57
            JMPZ    SHOW_RESULT
            XOR     R3,R3
            ADDI    R3,R3,34
SHOW_RESULT: CALLNC PRINT_STR
            CALLNC  POINT_DELAY
            CALLNC  POINT_DELAY
            JMPNC   START

##---------------------------------------------------------------------------
## player paddle: read buttons at 106
##---------------------------------------------------------------------------
PLAYER_MOVE: LOAD   R0,106
            SUBI    R1,R0,1
            JMPZ    PLAYER_UP
            SUBI    R1,R0,2
            JMPZ    PLAYER_DOWN
            RET
PLAYER_UP:  CALLNC  SEL_LEFT
            CALLNC  PADDLE_UP
            LOAD    R0,CUR_Y
            STORE   R0,LP_Y
            RET
PLAYER_DOWN: CALLNC SEL_LEFT
            CALLNC  PADDLE_DOWN
            LOAD    R0,CUR_Y
            STORE   R0,LP_Y
            RET
SEL_LEFT:   LOAD    R0,LP_Y
            STORE   R0,CUR_Y
            XOR     R0,R0
            ADDI    R0,R0,1
            STORE   R0,CUR_COL
            RET

##---------------------------------------------------------------------------
## cpu paddle: keep the ball between its 2nd and 3rd row, but only react
## once the ball is heading right and has reached AI_REACT_COL
##---------------------------------------------------------------------------
AI_MOVE:    LOAD    R0,BALL_DX
            SUBI    R0,R0,1
            JMPNZ   AI_RET
            LOAD    R0,BALL_X
            LOAD    R1,AI_REACT_COL
            SUB     R0,R1
            JMPOVF  AI_RET
            LOAD    R0,RP_Y
            STORE   R0,CUR_Y
            LOAD    R0,RP_COL
            STORE   R0,CUR_COL
##up if BALL_Y < RP_Y+1
            LOAD    R0,BALL_Y
            LOAD    R1,RP_Y
            ADDI    R1,R1,1
            SUB     R0,R1
            JMPOVF  AI_UP
##down if RP_Y+2 < BALL_Y
            LOAD    R0,RP_Y
            ADDI    R0,R0,2
            LOAD    R1,BALL_Y
            SUB     R0,R1
            JMPOVF  AI_DOWN
AI_RET:     RET
AI_UP:      CALLNC  PADDLE_UP
            JMPNC   AI_SAVE
AI_DOWN:    CALLNC  PADDLE_DOWN
AI_SAVE:    LOAD    R0,CUR_Y
            STORE   R0,RP_Y
            RET

##---------------------------------------------------------------------------
## move paddle described by CUR_Y (top row) / CUR_COL by one row
##---------------------------------------------------------------------------
PADDLE_UP:  LOAD    R1,CUR_Y
            SUBI    R0,R1,2
            JMPZ    PADDLE_RET
            ADDI    R1,R1,3
            LOAD    R2,CUR_COL
            XOR     R0,R0
            ADDI    R0,R0,32
            CALLNC  PUT_CHAR
            LOAD    R1,CUR_Y
            SUBI    R1,R1,1
            STORE   R1,CUR_Y
            LOAD    R0,PADDLE_CH
            CALLNC  PUT_CHAR
PADDLE_RET: RET

PADDLE_DOWN: LOAD   R1,CUR_Y
            SUBI    R0,R1,25
            JMPZ    PADDLE_RET
            LOAD    R2,CUR_COL
            XOR     R0,R0
            ADDI    R0,R0,32
            CALLNC  PUT_CHAR
            ADDI    R1,R1,1
            STORE   R1,CUR_Y
            ADDI    R1,R1,3
            LOAD    R0,PADDLE_CH
            CALLNC  PUT_CHAR
            RET

##---------------------------------------------------------------------------
## ball
##---------------------------------------------------------------------------
BALL_MOVE:  LOAD    R0,BALL_PHASE
            XORI    R0,R0,2
            STORE   R0,BALL_PHASE
            LOAD    R1,BALL_Y
            LOAD    R3,BALL_SLOPE
            AND     R0,R3
            JMPNZ   Y_OK
            LOAD    R3,BALL_DY
            ADD     R1,R3
            SUBI    R0,R1,1
            JMPZ    BOUNCE_Y
            SUBI    R0,R1,29
            JMPNZ   Y_OK
##hit a wall: dy = -dy (1 <-> 255) and recompute
BOUNCE_Y:   XORI    R3,R3,0xFE
            STORE   R3,BALL_DY
            LOAD    R1,BALL_Y
            ADD     R1,R3
Y_OK:       STORE   R1,NEW_Y
            LOAD    R2,BALL_X
            LOAD    R3,BALL_DX
            ADD     R2,R3
            SUBI    R0,R2,1
            JMPZ    AT_LEFT
            LOAD    R0,RP_COL
            SUB     R0,R2
            JMPZ    AT_RIGHT
            JMPNC   MOVE_TO

##ball reaches a paddle column: hit if 0 <= NEW_Y - paddle_top < 4
AT_LEFT:    LOAD    R0,NEW_Y
            LOAD    R1,LP_Y
            SUB     R0,R1
            SUBI    R1,R0,4
            JMPOVF  HIT_PADDLE
            LOAD    R0,C_SCORE
            ADDI    R0,R0,1
            STORE   R0,C_SCORE
            JMPNC   POINT

AT_RIGHT:   LOAD    R0,NEW_Y
            LOAD    R1,RP_Y
            SUB     R0,R1
            SUBI    R1,R0,4
            JMPOVF  HIT_PADDLE
            LOAD    R0,P_SCORE
            ADDI    R0,R0,1
            STORE   R0,P_SCORE
            JMPNC   POINT

##R0 = hit offset 0..3: top half sends the ball up (dy=255), bottom half down (dy=1);
##the outer rows (0, 3) give 45 degrees, the inner rows (1, 2) a shallow angle
HIT_PADDLE: ADDI    R1,R0,1
            ANDI    R1,R1,2
            STORE   R1,BALL_SLOPE
            ANDI    R0,R0,2
            SUBI    R0,R0,1
            STORE   R0,BALL_DY
            LOAD    R0,BALL_DX
            XORI    R0,R0,0xFE
            STORE   R0,BALL_DX
            LOAD    R2,BALL_X
            ADD     R2,R0

##move the ball to (NEW_Y, R2)
MOVE_TO:    STORE   R2,NEW_X
            CALLNC  ERASE_BALL
            LOAD    R1,NEW_Y
            STORE   R1,BALL_Y
            LOAD    R2,NEW_X
            STORE   R2,BALL_X
            LOAD    R0,BALL_CH
            CALLNC  PUT_CHAR
            RET

##somebody scored: update scores, game over at 9, else re-serve from the centre
POINT:      CALLNC  ERASE_BALL
            CALLNC  DRAW_SCORES
            LOAD    R0,P_SCORE
            SUBI    R0,R0,57
            JMPZ    SET_GAME_OVER
            LOAD    R0,C_SCORE
            SUBI    R0,R0,57
            JMPZ    SET_GAME_OVER
            LOAD    R0,NET_COL
            STORE   R0,BALL_X
            XOR     R0,R0
            ADDI    R0,R0,15
            STORE   R0,BALL_Y
            CALLNC  POINT_DELAY
            CALLNC  SERVE
            RET
SET_GAME_OVER: XOR  R0,R0
            ADDI    R0,R0,1
            STORE   R0,GAME_OVER
            RET

##serve at 45 degrees, dy from a TICK bit, and draw the ball at (BALL_Y, BALL_X)
SERVE:      XOR     R0,R0
            STORE   R0,BALL_SLOPE
            LOAD    R0,TICK
            ANDI    R0,R0,2
            SUBI    R0,R0,1
            STORE   R0,BALL_DY
            LOAD    R1,BALL_Y
            LOAD    R2,BALL_X
            LOAD    R0,BALL_CH
            CALLNC  PUT_CHAR
            RET

##erase the ball, restoring the net if it was on a net cell
ERASE_BALL: LOAD    R1,BALL_Y
            LOAD    R2,BALL_X
            XOR     R0,R0
            ADDI    R0,R0,32
            LOAD    R3,NET_COL
            SUB     R3,R2
            JMPNZ   ERASE_PUT
            ANDI    R3,R1,1
            JMPNZ   ERASE_PUT
            LOAD    R0,NET_CH
ERASE_PUT:  CALLNC  PUT_CHAR
            RET

##---------------------------------------------------------------------------
## drawing helpers (VGA must be in PROG mode)
##---------------------------------------------------------------------------
##PUT_CHAR: R0 char at (R1 row, R2 col); preserves all registers
PUT_CHAR:   STORE   R1,103
            STORE   R2,104
            STORE   R0,105
            RET

##FILL: R3 copies of R0 from (R1, R2) rightwards; clobbers R2, R3
FILL:       CALLNC  PUT_CHAR
            ADDI    R2,R2,1
            SUBI    R3,R3,1
            JMPNZ   FILL
            RET

##PRINT_STR: zero-terminated string at S_TITLE+R3 to (R1, R2); clobbers R0, R2, R3
PRINT_STR:  SET_ADR_MODE
            LOAD    R0,S_TITLE
            RST_ADR_MODE
            ORI     R0,R0,0
            JMPZ    PRINT_DONE
            CALLNC  PUT_CHAR
            ADDI    R2,R2,1
            ADDI    R3,R3,1
            JMPNC   PRINT_STR
PRINT_DONE: RET

##DRAW_PADDLE: 4 cells from (R1, R2) downwards; clobbers R0, R1, R3
DRAW_PADDLE: LOAD   R0,PADDLE_CH
            XOR     R3,R3
            ADDI    R3,R3,4
DRAW_PAD_LP: CALLNC PUT_CHAR
            ADDI    R1,R1,1
            SUBI    R3,R3,1
            JMPNZ   DRAW_PAD_LP
            RET

##DRAW_NET: NET_CH at col 20 on rows 2,4,..,28; clobbers R0, R1, R2, R3
DRAW_NET:   LOAD    R0,NET_CH
            XOR     R1,R1
            ADDI    R1,R1,2
            LOAD    R2,NET_COL
NET_LP:     CALLNC  PUT_CHAR
            ADDI    R1,R1,2
            SUBI    R3,R1,30
            JMPNZ   NET_LP
            RET

##DRAW_SCORES: clobbers R0, R1, R2
DRAW_SCORES: XOR    R1,R1
            ADDI    R2,R1,2
            LOAD    R0,P_SCORE
            CALLNC  PUT_CHAR
            LOAD    R2,CSCORE_COL
            LOAD    R0,C_SCORE
            CALLNC  PUT_CHAR
            RET

##---------------------------------------------------------------------------
## delays
##---------------------------------------------------------------------------
##DELAY: R0 x R2 inner iterations (0 means 256); clobbers R0, R1
DELAY:      XOR     R1,R1
            ADD     R1,R2
DELAY_IN:   SUBI    R1,R1,1
            JMPNZ   DELAY_IN
            SUBI    R0,R0,1
            JMPNZ   DELAY
            RET

##POINT_DELAY: POINT_PAUSE frame delays; clobbers R0..R3
POINT_DELAY: LOAD   R3,POINT_PAUSE
POINT_DLY_LP: LOAD  R0,FRAME_OUTER
            LOAD    R2,FRAME_INNER
            CALLNC  DELAY
            SUBI    R3,R3,1
            JMPNZ   POINT_DLY_LP
            RET
