import struct
import os
import logging
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import *

@cocotb.test()
async def test_range(dut):
    # Run the clock
    cocotb.start_soon(Clock(dut.clock, 10, units="ns").start())

    # Since our circuit is on the rising edge,
    # we can feed inputs on the falling edge
    # This makes things easier to read and visualize
    await FallingEdge(dut.clock)

    # Reset the DUT
    dut.reset.value = True
    await FallingEdge(dut.clock)
    await FallingEdge(dut.clock)
    dut.reset.value = False
    a = ''
    b = ''
    op = ''

    # generate input and get golden result
    for i in range(10):
        j = random.randint(0,1)
        k = random.randint(0,1)
        a += str(j)
        b += str(k)
    op = random.choice(['0001', '0010', '0100', '1000'])
    # print("in1 = ", a)
    # print("in2 = ", b)
    # print("op = ", op)

    # hardcode input
    # a = "1101011111"
    # b = "0011110001"
    # op = "0100"

    #golden_result = ieee_754_32bit_operation_final(a, b, op)

    # feed in data
    # feed in1 in 1 cycle    
    value = 0
    for j in range(10):
        value |= int(a[9-j]) << (j+2)
    value |= 0 << 1
    value |= 1 << 0
    dut.inp.value = value
    await FallingEdge(dut.clock)

    # feed in2 in 1 cycle
    value = 0
    for j in range(10):
        value |= int(b[9-j]) << (j+2)
    value |= 1 << 1
    value |= 0 << 0
    dut.inp.value = value
    await FallingEdge(dut.clock)

    # feed op in 1 cycle
    value = 0
    for j in range(4):
        value |= int(op[3-j]) << (j+2)
    value |= 1 << 1
    value |= 1 << 0
    dut.inp.value = value
    await FallingEdge(dut.clock)
    dut.inp.value = 0b000000000000

    # assert correct input feeding
    print("received in1 = ", dut.in1.num1.value, bits_to_float(str(dut.in1.num1.value)))
    print("received in2 = ", dut.in1.num2.value, bits_to_float(str(dut.in1.num2.value)))
    print("received op = ", dut.in1.op.value)
    print("signal = ", dut.in1.start.value)
    # assert binary32_to_float(a) == binary32_to_float(str(dut.in1.num1.value))
    # assert binary32_to_float(b) == binary32_to_float(str(dut.in1.num2.value))
    # assert op == str(dut.in1.op.value)
    # assert dut.in1.start.value == 1

    # print("golden result = ", golden_result)
    print("calculated result = ", dut.y.value, bits_to_float(str(dut.y.value)))
    await FallingEdge(dut.clock)
    print("final result = ", dut.out.value, bits_to_float(str(dut.out.value)))
    
def bits_to_float(bits):
    # Ensure the bits string is exactly 10 bits long
    if len(bits) != 10:
        raise ValueError("Input string must be exactly 10 bits long.")
    
    if bits[1:5] == "00000":
        return 0
    
    # Parse the sign bit (S)
    sign_bit = int(bits[0], 2)
    
    # Parse the exponent bits (E), interpreting as unsigned integer
    exponent_bits = int(bits[1:5], 2)
    
    # Parse the significand bits (M), interpreting as unsigned integer
    significand_bits = int(bits[5:], 2)
    
    # Compute the sign factor (-1)^S
    sign = (-1)**sign_bit
    
    # Compute the true exponent (E - bias)
    bias = 7
    exponent = exponent_bits - bias
    
    # Compute the mantissa (1.M). The significand_bits need to be shifted into the fraction part
    mantissa = 1 + significand_bits / 2**5
    
    # Compute the final value
    value = sign * mantissa * (2 ** exponent)
    return value




def float_to_binary32(value):
    """Convert a floating-point number to a 32-bit binary string."""
    [d] = struct.unpack(">I", struct.pack(">f", value))
    return '{:032b}'.format(d)

def binary32_to_float(binary_str):
    """Convert a 32-bit binary string to a floating-point number."""
    return struct.unpack('>f', struct.pack('>I', int(binary_str, 2)))[0]

def ieee_754_32bit_operation_final(num1, num2, operator):
    """Perform arithmetic on two 32-bit IEEE 754 floating point numbers with proper handling."""
    # Convert the numbers to 32-bit binary strings
    # bin_num1 = float_to_binary32(num1)
    # bin_num2 = float_to_binary32(num2)
    
    # Convert binary strings back to floats
    num1_conv = binary32_to_float(num1)
    num2_conv = binary32_to_float(num2)

    # Perform the specified operation
    if operator == '0001':  # Addition
        result = num1_conv + num2_conv
    elif operator == '0010':  # Subtraction
        result = num1_conv - num2_conv
    elif operator == '0100':  # Multiplication
        result = num1_conv * num2_conv
    elif operator == '1000':  # Division
        result = num1_conv / num2_conv if num2_conv != 0 else float('inf')  # Handle division by zero

    # Convert the result back to a 32-bit binary string to check for overflow and denormalized result
    result_bin = float_to_binary32(result)

    # Convert the binary string back to a float for the final result and handle overflow and denormalization
    result_float = binary32_to_float(result_bin)
    if result_float == float('inf') or result_float == float('-inf'):
        return result_float  # Explicitly handle overflow
    
    if result_bin[1:9] == '00000000':  # Explicitly handle denormalized result
        return 0.0
    
    return [result_bin, result_float]

# Test the function with specific values for multiplication
# final_test_result = ieee_754_32bit_operation_final(0.00196, 1, '1000')
# print(final_test_result)
