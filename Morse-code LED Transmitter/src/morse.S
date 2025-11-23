# ---------------------------- DATA SECTION -------------------------
.section .rodata          # Read-only data section for constants / lookup tables
.align 2                  # Align to 4-byte boundary (2^2 = 4)

# Input string (Message) to be sent / converted to Morse code
InputLUT:
    .asciz "EA"        # Null-terminated string

# Morse Code Look-Up Table
# Each character is mapped to a 16-bit pattern for the Morse LED display

.align 2                  # Align to 4-byte boundary (2^2 = 4)
MorseLUT:
    .half 0x17, 0x1D5, 0x75D, 0x75       # A, B, C, D
    .half 0x1, 0x15D, 0x1DD, 0x55        # E, F, G, H
    .half 0x5, 0x1777, 0x1D7, 0x175      # I, J, K, L
    .half 0x77, 0x1D, 0x777, 0x5DD       # M, N, O, P
    .half 0x1DD7, 0x5D, 0x15, 0x7        # Q, R, S, T
    .half 0x57, 0x157, 0x177, 0x757      # U, V, W, X
    .half 0x1D77, 0x775                  # Y, Z


# ---------------------------- CODE SECTION -------------------------
.section .text                               # Begin code section
.globl _start                                # Entry point
.align  2                                    # Align to 4-byte boundary

_start:
    # GPIO Control Registers Memory Mapping
    # Referring to lab manual or SiFive FE310-G002 Manual v1p5
    .equ GPIO_BASE_CTRL_ADDR,   0x10012000      # Base address for GPIO control registers
    .equ GPIO_OUTPUT_EN,        0x08            # Offset to enable GPIO outputs
    .equ GPIO_OUTPUT_VAL,       0x0C            # Offset to write GPIO outputs

    # LED Pin Masks
    .equ GPIO_7SEGLED_PINS, 0x0000023F          # Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,  0x00fc0c00          # LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS, 0x00fc0e3f          # All LED Pins (15)
    .equ GPIO_LEDBAR_LED_7, 0x00800000          # LEDBAR LED7 (Bit 23)

    # Initialize GPIO outputs

    la t0, GPIO_BASE_CTRL_ADDR      # Load base adress to t0
    li t1, GPIO_ALL_LED_PINS        # Load bit mask for all LEDs to t1
    sw t1, GPIO_OUTPUT_EN(t0)       # Store bit mask at the output enable address

# ---------------------------- MAIN LOOP -----------------------------
# Initialize pointer and start processing each character of the input string
InputPointer:
    la s1, InputLUT                             # Load address of input string into s1
    la t1, MorseLUT                             # Load the base address of morse code table

# Process each character in the input string
NextChar:
    lb a0, 0(s1)                               # Load next character into a0 (unsigned)
    addi s1, s1, 1                              # Increment pointer to next character
    snez a1, a0                                 # Set a1 = 1 if a0 != 0 (not null)
    bnez a1, CHAR2MORSE                         # If character valid, convert to Morse
    sw x0, GPIO_OUTPUT_VAL(t0)                  //turned off LED before delay
    li a7, 0xf42400                             // number of delay loop iterations for long delay
    jal ra, long_delay                               # If null terminator reached, wait 3.5 sec
    j InputPointer                              # Restart from first character

# ---------------------------- SUBROUTINES ---------------------------
# Converts an ASCII uppercase letter (A-Z) into its Morse pattern and Flash the LED according to the pattern
CHAR2MORSE:

    # ------------------1. CHAR2MORSE: Lookup Morse pattern from ASCII---------------------
    # ------------------2. PROCESSCHAR: Flash the LED according to the pattern-------------

    # Input: a0 = ASCII character. Store Output in a1 = Morse code pattern
    # Index into MorseLUT must be by steps of 2 bytes 
    # Example layout in MorseLUT:
    # 0000 0000 | 0000 0000 | 0000 0000 | 0000 0000 
    #       B (2 Bytes)     |        A (2 bytes)

    # 1. look up ascii in the table and get the
    # 2. flash the LED
    addi a1, a0, -0x41                          // store letter index to a1
    slli a1, a1, 1                              // multiply the letter index by 2
    add a1, a1, t1                              // add offset to MorseLUT base address
    lhu a2, 0(a1)                               // load morse code into a2
    slli a2,a2,16                               // shifting by 16 to eliminate 0s
    li t2, 16                                   // stopping condition for count_loop
    li a3,0                                     // loop counter - counts number of zeroes
    li t5,0x80000000                            // loading bitmask for MSB in t5
    // naturally falling into count_loop

count_loop: //loop to remove and count the number of leading zeroes
    and t4,a2,t5                                //extracting MSB
    sub a4,t2,a3                                //for PROCESSCHAR, subtracting no. of zeroes from 16 to get no. of bits in a2
    bnez t4, PROCESSCHAR                        //if MSB is 1 stop loop, and start flashing led pattern
    bge a3, t2, NextChar                        //if a3>=16 go to NextChar
    slli a2,a2,1                                //shift left by 1 to extract next bit
    addi a3,a3,1                                //incrementing loop counter
    j count_loop                                //continue looping until MSB is 1

PROCESSCHAR: //Flash the LED according to the pattern
    beqz a4, medium_delay                       //if loop counter is zero, delay = 1.5 secs
    li t5,0x80000000                            //loading bitmask for MSB in t5
    and t4,a2,t5                                //extracting MSB
    slli a2,a2,1                                //shift left by 1 bit
    addi a4,a4,-1                               //decrement loop counter
    beqz t4, LED_OFF                            //if MSB is 0, LED_OFF is called
    bnez t4, LED_ON                             //if MSB 1 is 1, LED_ON is called
    
# ---------------------------- LED CONTROL ---------------------------
# Turn On LED7
LED_ON:
    li t2, GPIO_LEDBAR_LED_7                    //loading address of led 7 into t2
    sw t2, GPIO_OUTPUT_VAL(t0)                 //turning led 7 on
    li a5, 0x3d0900                             //number of delay loop iterations for short delay
    jal ra, short_delay                         //jump to short delay
    j PROCESSCHAR                               //jump to PROCESSCHAR

# Turn LED7 off
LED_OFF:
    sw x0, GPIO_OUTPUT_VAL(t0)                    //turning led 7 off
    li a5, 0x3d0900                             //number of delay loop iterations for short delay
    jal ra, short_delay                         //jump to short delay
    j PROCESSCHAR                               //jump to PROCESSCHAR
    
# ---------------------------- DELAY ROUTINES -----------------------


short_delay: //0.5 seconds delay
    addi a5,a5,-1                               //decrementing delay loop counter
    bnez a5,short_delay                          //looping back to short delay if a5!=0
    ret                                         //after a5==0,return

medium_delay: //1.5 seconds delay
    sw x0, GPIO_OUTPUT_VAL(t0)                       //turning led 7 off after each character
    li a5, 0x3d0900                                 //number of delay loop iterations for short delay
    jal ra, short_delay                             //jump to short delay
    li a5, 0x3d0900
    jal ra, short_delay
    li a5, 0x3d0900
    jal ra, short_delay
    j NextChar                               //jump to NextChar

long_delay: //3.5 seconds delay
    addi a7,a7,-1                               //decrementing delay loop counter
    bnez a7,long_delay                           //looping back to short delay if a7!=0
    ret                                         //after a7==0,return

End:
    .end
