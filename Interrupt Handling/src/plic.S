.section .text
.align 2
.globl _start

# --------------------------------------------------------------------------------------------------------------
# Constants and Register Definitions
# --------------------------------------------------------------------------------------------------------------

# GPIO control register base address and offsets

GPIO_BASE                   = 0x10012000        # GPIO base address
GPIO_OUTPUT_ENABLE          = 0x08              # GPIO output enable register (set pins as output)
GPIO_OUTPUT_VAL             = 0x0C              # GPIO output data register (write pin states)
GPIO_INPUT_ENABLE           = 0x04              # GPIO input enable register (set pins as input)
GPIO_INPUT_VAL              = 0x00              # GPIO input data register (read pin states)
GPIO_FALL_INTERRUPT_ENABLE  = 0x20              # Falling edge interrupt enable register offset
GPIO_FALL_INTERRUPT_PENDING = 0x24              # Falling edge interrupt pending register offset

# PLIC control register base address and offsets
PLIC_BASE                   = 0x0C000000        # PLIC base address
PLIC_ENABLE                 = 0x2000            # PLIC interrupt enable register offset
PLIC_PRIORITY               = 0x0004            # PLIC priority register offset
PLIC_THRESHOLD              = 0x200000          # PLIC threshold register offset 
                                                # (absolute addr = 0x0C200000, base + offset)
PLIC_CLAIM                  = 0x200004          # PLIC claim/complete register offset
PLIC_INT_PEND               = 0x1000            # PLIC interrupt pending register offset

# Define the GPIO Input and Output Pins
GPIO_LEDBAR_PINS            = 0x00FC0C00        # LED bar pins (8)
GPIO_SW_1                   = 0x00001000        # S1 / PB1
GPIO_SW_2                   = 0x00002000        # S2 / PB2
GPIO_ALL_PBS                = 0x00003000        # All pushbuttons

# Variables for Pushbutton S1
S1_GPIO_PIN                 = 12                # S1 pushbutton pin number (active low)
S1_IRQ                      = 12                # IRQ (Interrupt Request) number for GPIO pin 12
S1_PLIC_ID                  = 20                # PLIC interrupt source ID for GPIO pin 12 (12 + 8 = 20)
S1_PRIORITY                 = 7                 # Interrupt priority for S1 (0 = lowest, 7 = highest)


_start:

# Set up mtvec with the address of the interrupt vector (S1_interrupt)
      la t0, S1_interrupt                 # Load the address of the interrupt handler 'S1_interrupt' into t0
                                          # S1_interrupt represents the Interrupt Service Routine (ISR) found at the bottom of the code
      csrw mtvec, t0                      # csrw: CSR write,  writes the value in register t0 (which is the 
                                          # address of the interrupt handler) to the mtvec register.                        
                                          # Set the mtvec register to th e address in t0 (S1_interrupt)
# Enable "External" machine interrupts in the mie register
      li t0, (1 << 11)                    # Set bit 11 to "1" and write it to t0
                                          # This bit (bit 11) corresponds to the external interrupt enable
      csrs mie, t0                        # csrs: CSR Set, it performs a bitwise OR between the current 
                                          # value of mie and the value in t0
                                          # Set bit 11 in the mie register (enable external interrupts)
# mtvec: Machine Trap Vector register, it stores the address of the interrupt handler
# directing the processor to jump to this address, S1_interrupt, when an interrupt occurs.

# Enable global machine interrupts (MIE, bit 3 of mstatus)
      csrr t0, mstatus                    # read the value of the mstatus into t0
      li t1, (1 << 3)                     # Set MIE (Machine Interrupt Enable)
                                          # (1<<3): this instruction puts "1" at the 3rd bit 
      or t0, t0, t1                       # add t0 "mstatus" to t1, where we actually are setting bit 3 to "1"
                                          # This sets the 3rd bit (MIE) in t0 without modifying other bits
      csrw mstatus, t0                    # Write the modified value in t0 back to the mstatus register

# ------------------------------Configure SW1 as an input------------------------------

la s0, GPIO_BASE                # Load base adress to s0
li s1, GPIO_SW_1                # load bit mask for push button 1 to s1
sw s1, GPIO_INPUT_ENABLE(s0)    # store bit mask at input enable address


# -----------------------Configure GPIO LEDs pins as an output-------------------------

li s1, GPIO_LEDBAR_PINS        # Load bit mask for all LED bar pins to s1
sw s1, GPIO_OUTPUT_ENABLE(s0)  # Store bit mask at the output enable address


# ----------------------------Turn Off all LEDs in LED Bar-----------------------------

sw x0, GPIO_OUTPUT_VAL(s0)    # turn off all leds

# ------------Enable Falling edge for S1: Remember S1 is a GPIO and not PLIC-----------

li s1, GPIO_SW_1                        # load bit mask for push button 1 to s1
la s0,GPIO_BASE                         # load base address to s0
lw s9, GPIO_FALL_INTERRUPT_ENABLE(s0)   # load bits at fall interrupt enable pin to s9
or s1,s1,s9                             # set bit 12 (push button 1) to 1
sw s1, GPIO_FALL_INTERRUPT_ENABLE(s0)   # store bit mask at fall interrupt enable pin


# ----------------------------Enable PLIC for S1 interrupt-----------------------------

li t1, PLIC_BASE + PLIC_ENABLE      # load PLIC enable address to t1
li s11, 0x100000                    # load bit mask for bit 20 (push button 1 interrupt ID)
sw s11,0(t1)                        # store bit mask at PLIC enable

# ----------------Set PLIC priority for S1 interrupt to 7 "Highest Priority"-----------
# -----------The address is calculated according to: PLIC_BASE + 4 × S1_PLIC_ID--------

li t1, PLIC_BASE                    # load PLIC base address to t1
li s11, (4*S1_PLIC_ID)              # calculate offset based on PLIC ID
add t1,t1,s11                       # add offset to base address
lw t5, 0(t1)                        # load bits stored at PLIC interrupt priority register for s1
li s11,S1_PRIORITY                  # load 7 to s11
or s11,s11,t5                       # set bit 0 to 2 to 111, which is 7 in decimal
sw s11, 0(t1)                       # store bit mask at PLIC interrupt priority register for s1

# -------------------------------Set PLIC threshold to 6-------------------------------

li t1, PLIC_BASE + PLIC_THRESHOLD     # Address of PLIC threshold register
lw t5, 0(t1)                          # load bits stored at PLIC threshold register to t5
li s11,6                              # load 6 to s11
or s11,s11,t5                         # set bit 0 to 2 to 6
sw s11, 0(t1)                         # store bit mask at PLIC threshold register

# Initialize pseudo-random generator and countdown timer
      li a7, 0xABCD                       # Seed value for PRNG
      li a4, 0                            # Countdown timer value


main_program:                             
# -------------------Flashing the LEDS at a rate of 10 Hz (0.1 seconds)----------------

    # Toggle LEDs using XOR
    lw t2, GPIO_OUTPUT_VAL(s0)       # Load current LED state
    li t3, GPIO_LEDBAR_PINS         # Bitmask for all LED bar pins
    xor t2, t2, t3                   # Flip LED1 bit
    sw t2, GPIO_OUTPUT_VAL(s0)       # Write back toggled value

    # Delay loop (~500 ms)
    li t4, 0x3d0900         # 4,000,000 iterations for 0.5 sec at CPU CLOCK 16 MHz
    jal ra, flash_delay     # jump to delay

next:
    jal RandomNum           # keep generating random numbers until interrupt is called
    j main_program          # repeat if s1 not pressed

.align 2
# Interrupt Service Routine (ISR) for S1 interrupt
S1_interrupt:

# -------------------------- Acknowledge Interrupt in PLIC --------------------------
    li t1, PLIC_BASE + PLIC_CLAIM         # Address of PLIC claim/complete register
    lw t5, 0(t1)                          # Read Interrupt ID from claim register

Scale:
    li s11,200                            # loading 200 into s11
    remu a4,a7,s11                        # remainder of random num / 200 is stored in a4
    addi a4,a4,50                         # add 50 to a4

Countdown:
    mv s7, a4       # copy a4 value into s7
    li s8, 0        # repeats until a4 is less than 0

    binary_counter:
    addi sp,sp,-4          # saving re used registers to the stack
    sw ra, 0(sp)            # saving return address

    blt s7,s8, clear       # branch back to clear to end interrupt
    add s5,s7,x0            # copyin the counter value into s5
    slli s5, s5, 10         # shifting s5 by 10 to isolate bits
    li s2, 0xC00            # bit mask to isolate for led 0 and 1
    and s2, s5,s2           # isolated led bits
    slli s5,s5,6            # shifting s5 by 6 more to isolate rest of the led bits
    li s3, 0xFC0000         # bit mask for leds 23 - 18
    and s3,s5,s3            # isolated led bits
    li s5,0                 # to store final led values
    or s5, s2,s3            # final led values from s2 and s3 into s5
    sw s5, GPIO_OUTPUT_VAL(s0) # lighting the leds
    li s5, 8000000           # delay counter value for 1 second
    jal ra, binary_counter_delay # jumping to delay
    addi s7,s7,-10            # decrementing counter

    sw ra, 0(sp)            # restoring return address
    addi sp,sp, 4          # restoring saved registers
    j binary_counter        # jumping back if a4 is not less than 0
      
clear:
    li a4,0                                 # setting counter value to 0
    sw x0, GPIO_OUTPUT_VAL(s0)              # turning off all leds

    la s0,GPIO_BASE                         # load gpio base address
    li s1, GPIO_SW_1                        # load bit mask for push button 1 to s1
    lw s9, GPIO_FALL_INTERRUPT_PENDING(s0)  # load bits at fall interrupt pending to s9
    or s9,s1,s9                             # setting bit 12 to 1 to preserve other bits
    sw s9, GPIO_FALL_INTERRUPT_PENDING(s0)  # clearing the pending bit

    li t1, PLIC_BASE + PLIC_CLAIM           
    sw t5, 0(t1)                          # Write it back to complete the interrupt


# ----------------------------- Restore Registers & Return --------------------------
end_interrupt:
    mret                                 # Return from interrupt



RandomNum:
      # to optimize the code, we use the same registers used before (t1 and t3)
      addi sp, sp, -16                      # Decrement stack pointer to make space for saved registers.
      sw t1, 0(sp)                          # Store register t1 in the stack at offset 0.
      sw t3, 4(sp)                          # Store register t3 in the stack at offset 4.
      sw ra, 8(sp)                          # Store return address (ra) in the stack at offset 8.
      
      # Start random number generation by manipulating the bits of a7.
      li s4, 0x8000                         # Load the value 0x8000 (32,768) into register s4.
      and t1, a7, s4                        # Mask the lower 16 bits of a7 by performing an AND with 0x8000. Store the result in t1.
      li s4, 0x2000                         # Load the value 0x2000 (8,192) into register s4.
      and t3, a7, s4                        # Mask the lower 16 bits of a7 by performing an AND with 0x2000. Store the result in t3
      slli t3, t3, 2                        # Shift the bits of t3 left by 2, effectively multiplying t3 by 4.
      xor t3, t1, t3                        # Perform an XOR operation between t1 and t3, and store the result in t3.
      li s4, 0x1000                         # Load the value 0x1000 (4,096) into register s4.
      and t1, a7, s4                        # Mask a7 using t0 and store the result in t1.
      slli t1, t1, 3                        # Shift t1 left by 3 (multiply by 8).
      xor t3, t3, t1                        # XOR t1 with t3 and store the result back in t3.
      andi t1, a7, 0x0400                   # Perform an AND operation with 0x0400 to extract a specific bit pattern from a7.
      slli t1, t1, 5                        # Shift the bits of t1 left by 5.
      xor t3, t3, t1                        # XOR t3 with t1 and store the result back in t3.
      srli t3, t3, 15                       # Shift the bits of t3 right by 15 (to normalize the value).
      slli a7, a7, 1                        # Shift the bits of a7 left by 1, effectively multiplying by 2.
      or a7, a7, t3                         # Perform a logical OR between a7 and t3, and store the result in a7.

      # Restore the saved registers from the stack to their original values.
      lw t1, 0(sp)                              # Load the value of t1 back from the stack.
      lw t3, 4(sp)                              # Load the value of t3 back from the stack.
      lw ra, 8(sp)                              # Load the return address (ra) back from the stack.
      addi sp, sp, 16                           # Restore the stack pointer by adding 16.
      ret                                       # Return from the subroutine, passing the generated random number in a7.
      

flash_delay:
    addi t4, t4, -1   # Decrement the delay counter t4
    bnez t4, flash_delay  # If t4 is not zero, repeat the delay loop
    # Repeat
    j next

binary_counter_delay:
    addi s5,s5,-1
    bnez s5, binary_counter_delay
    ret