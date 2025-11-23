# ------------------------------------------------------------------
# Student Information
# ------------------------------------------------------------------
# Lab number            : 3
# Group number          : 39
# Section number        : 202
# Student-1 name        : Victoria Gao
# Student-2 name        : Arushi Basu
# ------------------------------------------------------------------
# -------------- YOUR CODE MUST BE WELL COMMENTED ------------------
# -------------- YOU MAY REMOVE UNNECESSARY COMMENTS ---------------
# ------------------------------------------------------------------

.section .text
.align 2
.globl _start

_start:
# GPIO Control Registers Memory Mapping
    # Refer to lab manual or SiFive FE310-G002 Manual v1p5

    # Define the GPIO control register base address and offsets
    # (Output enable, output value, input enable, input value, etc.)
    # -----------------------------write the instructions here-----------------------------
    .equ GPIO_BASE_CTRL_ADDR,   0x10012000      # Base address for GPIO control registers
    .equ GPIO_OUTPUT_EN,        0x08            # Offset to enable GPIO outputs
    .equ GPIO_INPUT_EN,        0x04            # Offset to enable GPIO outputs
    .equ GPIO_OUTPUT_VAL,       0x0C            # Offset to write GPIO outputs
    .equ GPIO_INPUT_VAL,       0x00             # Offset to read GPIO inputs

    # Define GPIO Pin Mapping for LEDs (8 LEDs in LED bar, LED6)
    # Optional: you may also configure the 7-segment display pins
    # -----------------------------write the instructions here-----------------------------
     # LED Pin Masks
    .equ GPIO_7SEGLED_PINS, 0x0000023F          # Seven Segment LED Display Pins (7)
    .equ GPIO_ALL_LED_PINS, 0x00fc0e3f          # All LED Pins (15)
    .equ GPIO_LEDBAR_PINS,  0x00fc0c00          # LED Bar Pins (8)
    .equ GPIO_LEDBAR_LED_6, 0x00400000          # LED 6
   
    # Configure the GPIO Outputs for all LEDs
    # -----------------------------write the instructions here-----------------------------
    la t0, GPIO_BASE_CTRL_ADDR      # Load base adress to t0
    li t1, GPIO_ALL_LED_PINS        # Load bit mask for all LEDs to t1
    sw t1, GPIO_OUTPUT_EN(t0)       # Store bit mask at the output enable address

    # Define GPIO Pin Mapping for Pushbuttons (S1, S2, and both)
    # -----------------------------write the instructions here-----------------------------
    .equ GPIO_PUSHBUTTON_1, 0x00001000          # PUSH BUTTON 1
    .equ GPIO_PUSHBUTTON_2, 0x00002000          # PUSH BUTTON 2
    .equ GPIO_PUSHBUTTONS, 0x00003000          # BOTH PUSH BUTTONS

    # Configure the GPIO Inputs for the pushbuttons used (S1, S2, or both)
    # -----------------------------write the instructions here-----------------------------
    li t1, GPIO_PUSHBUTTONS         # load bit mask for both push buttons to t1
    sw t1, GPIO_INPUT_EN(t0)        # store bit mask at input enable address

    # Turn off all LEDs
    # -----------------------------write the instructions here-----------------------------
    li t1, GPIO_ALL_LED_PINS      # Load bit mask for all LEDs to t1
    sw x0, GPIO_OUTPUT_VAL(t0)    # Store bit mask at the output value address

# ----------------------Initialize the pseudo-random number generator-----------------------
InitRandomNum:
    # Sets a7 to a 16-bit non-zero value; only the PRNG subroutine should modify a7
    li a7, 0xABCD

# 237 ms - average reaction time for Arushi

# -------------------Task 1: LED Binary Counter and GPIO Verification----------------------
    Task_1:
    # -----------------------------write the instructions here-----------------------------
    li s0, 0            # counter
    li s1, 0x100        # OxFF + 1

    binary_counter:
    addi sp,sp,-12          # saving re used registers to the stack
    sw s2, 0(sp)
    sw s3, 4(sp)
    sw s5, 8(sp)
   
    li s6, GPIO_PUSHBUTTON_2    # storing push button 2 mask
    lw s7, GPIO_INPUT_VAL(t0)   # reading input values
    and s6,s6,s7                # checking if push button's pressed
    beqz s6,Task_2              # if yes, start Task 2

    bge s0,s1, Task_1       # branch back to task 1 to repeat the binary counter
    add s5,s0,x0            # copyin the counter value into s5
    slli s5, s5, 10         # shifting s5 by 10 to isolate bits
    li s2, 0xC00            # bit mask to isolate for led 0 and 1
    and s2, s5,s2           # isolated led bits
    slli s5,s5,6            # shifting s5 by 6 more to isolate rest of the led bits
    li s3, 0xFC0000         # bit mask for leds 23 - 18
    and s3,s5,s3            # isolated led bits
    li s5,0                 # to store final led values
    or s5, s2,s3            # final led values from s2 and s3 into s5
    sw s5, GPIO_OUTPUT_VAL(t0) # lighting the leds
    li s5, 800000           # delay counter value for 0.1 seconds
    jal ra, binary_counter_delay # jumping to delay
    addi s0,s0,1            # incrementing counter
    lw s2, 0(sp)
    lw s3, 4(sp)
    lw s5, 8(sp)
    addi sp,sp, 12          # restoring saved registers
    j binary_counter        # jumping back

# ----------------------------------Task 2: Reflex Meter-----------------------------------
Task_2:
    # -----------------------------write the instructions here-----------------------------
    sw x0, GPIO_OUTPUT_VAL(t0)      # turning off LEDs
    jal ra, RandomNum               # generating random number
    jal ra, Scale                   # scaling the random number for a delay between 2-10 seconds
    li t4,0x320                     # calculating delay loop counter value
    mul t2,t2,t4                    # delay loop counter value
    jal ra, prng_delay              # pseudo random delay

reflex_led:
    li t4, GPIO_LEDBAR_LED_6        # storing LED 6 mask
    sw t4, GPIO_OUTPUT_VAL(t0)      # writing to output values
    li t4, GPIO_PUSHBUTTON_1        # storing push button 1 mask
    addi a0,x0,0                    # counter for timer
    jal ra, timer                   # starting timer after LED 6 is on
   
flash:
    li a2,0                         # counter for number of times we shifted by 8 bits
    # a2 is also used to calculate shift value
    li a3,4                         # condition to stop shifting
    flash_loop:
        addi sp,sp,-12                  # saving re used registers to the stack
        sw s2, 0(sp)
        sw s3, 4(sp)
        sw s5, 8(sp)
        
        li t5,0x02625A00                # value for 5 second delay
        bge a2,a3, long_delay           # stop shifting right when reached most significant 8 bits, start 5 sec delay
        li a1,255                       # bit mask for LSB 8 bits
        li a5,8                         # shift right value by 8
        and a1,a1,a0                    # extract least significant 8 bits
        srl a0,a0,a5                    # shift right for least significant 8 bit chunks

        # for gpio ouput value led placement
        slli a1,a1,10                   # shifting s5 by 10 to isolate bits
        li s2, 0xC00                    # bit mask to isolate for led 0 and 1
        and s2, a1,s2                   # isolated led bits
        slli a1,a1,6                    # shifting s5 by 6 more to isolate rest of the led bits
        li s3, 0xFC0000                 # bit mask for leds 24 - 18
        and s3, a1,s3                   # isolated led bits
        li s5,0                         # to store final led values
        or s5, s2,s3                    # final led values from s2 and s3 into s5 for gpio
        sw s5, GPIO_OUTPUT_VAL(t0)      # lighting the leds
        li t5, 0xF42400                 # value for 2 second delay between each 8 bit chunk
        jal ra, flash_delay             # start 2 sec delay
        addi a2,a2,1                    # increment counter of shifting by 8
        lw s2, 0(sp)
        lw s3, 4(sp)
        lw s5, 8(sp)
        addi sp,sp, 12                  # restoring saved registers
        j flash_loop                    # repeat until all 32 bits have been displayed


# ----------------------------------------Scaling-------------------------------------------
# Scaling the randum number generated (a7) between 2 and 10 sec
Scale:
    mv t2, a7           # copy random number into a0
    li t4, 255          # max 8 bit - 1 - bit mask
    and t2, t2, t4      # using least significant 8 bits from random number generated
    li t4,400           # 400 allows us to scale up the random number up till 100,000 cycles +-5%
    mul t2,t2,t4        # random num * 400
    li t4, 19000        # 19000 because +-5% of 20000 cycles
    blt t2,t4,Task_2    # if resulting num < 19000, generate a new random number
    ret                 # return if random number fulfils conditions

timer:
    lw t2, GPIO_INPUT_VAL(t0)       # reading input values
    and t2,t2,t4                    # checking if push button's pressed
    beqz t2,flash                   # if yes, display the timer in 8 bit chunks
    li t5,800                       # value for 0.1m sec delay
    jal ra, timer_delay             # start 0.1 m sec delay
    addi a0,a0,1                    # add 1 every time timer_delay is called
    j timer                         # repeat until push button is pressed

# -------------------------Pseudo-Random Number Generator------------------------------
# Register a7 will hold the generated random number
# You may read this register anywhere in your program.
# Important: Only this subroutine should write to a7.
RandomNum:
    addi sp, sp, -16
    sw ra, 12(sp)                  # Save return address

    li s4, 0x8000                  # Select bit 15 of a7
    and t1, a7, s4                 # Extract bit 15

    li s4, 0x2000                  # Select bit 13 of a7
    and t3, a7, s4                 # Extract bit 13

    slli t3, t3, 2                 # Shift extracted bit 13 left by 2
    xor t3, t1, t3                 # Combine with extracted bit 15

    li s4, 0x1000                  # Select bit 12 of a7
    and t1, a7, s4                 # Extract bit 12

    slli t1, t1, 3                 # Shift extracted bit 12 left by 3
    xor t3, t3, t1                 # Combine with previous result

    andi t1, a7, 0x0400            # Select bit 10 of a7
    slli t1, t1, 5                 # Shift bit 10 left by 5
    xor t3, t3, t1                 # Combine with previous result

    srli t3, t3, 15                # Shift result right by 15
    slli a7, a7, 1                 # Shift a7 left by 1
    or a7, a7, t3                  # Update a7 with new pseudo-random value

    lw ra, 12(sp)                  # Restore return address
    addi sp, sp, 16                # Restore stack pointer
    ret                             # Return from subroutine

# ---------------------------- DELAY ROUTINES -----------------------
# Create as much as you need.
# Delays
binary_counter_delay:
addi s5,s5,-1
bnez s5, binary_counter_delay
ret

prng_delay:
addi t2,t2,-1
bnez t2,prng_delay
ret

timer_delay:
addi t5,t5,-1
bnez t5,timer_delay
ret

flash_delay:
addi t5,t5,-1
bnez t5,flash_delay
ret

long_delay:
addi t5,t5,-1
bnez t5,long_delay
j reflex_led

End:
    .end

; Answer the following questions (as comments at the end of your code):
; a. Prove that the time for the pseudorandom number is within ± 5% of the specified time
; (2 to 10 seconds).
; The range of random number stored at a7 is 1-65535. However, we want the number of cycles to be in the range of 20000-100000.
; We scale the range by doing the following:
; 1. Extract the least significant 8 bits of the random number.
;     This gives a value between 1 and 255.
; 2. Create a new random number by multiplying the extracted number by 400
;     This produces values between 400 and 102,000.
; 3. If the random number is less than 19000, generate a new random number
; 4. Repeat until we find a random number within the range of 20000-100000

; Proof:
; Upper bound: The extracted number can be 255 at most, the maximum possible scaled value is 255 * 400 = 102,000.
; The upper bound of the valid range (100,000) with +5% tolerance is 100,000 × (1 + 5%) = 105,000.
; Since 102,000 < 105,000, the scaled random number is guaranteed to less than +5% of the upper bound.
; Lower bound: Since we discard values that are less than 19000, the scaled random number is guaranteed to more than
; -5% of the lower bound.
; So our total range is 19000 - 102000 which uses values between 48 - 255 after extracting the first 8 bits of the random value generated.


; b. If a 32-bit register is counting user reaction time in 0.1 milliseconds increments, what
; is the maximum amount of time which can be stored in
; i. 8 bits
; max amount of time in binary = 1111 1111
; 255*0.1ms = 25.5 ms = 0.0255 s
; ii. 16-bits
; max amount of time in binary = 1111 1111 1111 1111
; 65535*0.1ms = 6553.5 ms = 6.5535 s
; iii. 24-bits
; max amount of time in binary = 1111 1111 1111 1111 1111 1111
; 16777215*0.1ms = 1677721.5 ms = 1677.7215 s
; iv. and 32-bits?
; max amount of time in binary = 1111 1111 1111 1111 1111 1111 1111 1111
; 4294967295*0.1ms = 429496729.5 ms = 429496.7295 s


; c. Considering typical human reaction time, which size would be the best for this task
; (8, 16, 24, or 32 bits)?
; 16-bits with a maximum reaction time of 6.5535s would be the best for this task because it minimizes memory usage while
; storing typical reaction time. 8-bits with 0.0255s will be too short, and 24-bits with 1677.7215s will be too long.