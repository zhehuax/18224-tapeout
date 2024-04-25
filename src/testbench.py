import struct
import os
import logging
import random
import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import *

@cocotb.test()
async def fpu_test_repeat_1000(dut):
    # Run the clock
    cocotb.start_soon(Clock(dut.clock, 10, units="ns").start())

    # Since our circuit is on the rising edge,
    # we can feed inputs on the falling edge
    # This makes things easier to read and visualize
    for repeat in range(1000):
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
        for i in range(16):
            j = random.randint(0,1)
            k = random.randint(0,1)
            a += str(j)
            b += str(k)
        op = random.choice(['0001', '0010', '0100'])

        # feed in data
        # feed in1 in 2 cycle   
        for i in range(2): 
            value = 0
            for j in range(8):
                value |= int(a[15-(j+i*8)]) << (j+2)
            value |= 0 << 1
            value |= 1 << 0
            dut.inp.value = value
            await FallingEdge(dut.clock)

        # feed in2 in 1 cycle
        for i in range(2):
            value = 0
            for j in range(8):
                value |= int(b[15-(j+i*8)]) << (j+2)
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

        # print input feeding and result
        a_value = binary_to_float16(a)
        b_value = binary_to_float16(b)
        print("in1 = ", a, "value: ", a_value)
        print("in2 = ", b, "value: ", b_value)
        print("op = ", op)
        print("received in1 = ", dut.in1.num1.value, binary_to_float16(str(dut.in1.num1.value)))
        print("received in2 = ", dut.in1.num2.value, binary_to_float16(str(dut.in1.num2.value)))
        print("received op = ", dut.in1.op.value)
        print("signal = ", dut.in1.start.value)
        print("calculated result = ", dut.y.value, binary_to_float16(str(dut.y.value)))
        await FallingEdge(dut.clock)
        out_first_half = str(dut.out.value)
        await FallingEdge(dut.clock)
        out_second_half = str(dut.out.value)
        out = str(out_first_half[:8]) + str(out_second_half[:8])
        print("final result = ", binary_to_float16(out))

        # print golden result
        golden_result = ''
        if (op=='0001'):
            golden_result = float_to_binary16(a_value+b_value)
        elif (op=='0010'):
            golden_result = float_to_binary16(a_value-b_value)
        else:
            golden_result = float_to_binary16(a_value*b_value)
        print("golden result", golden_result)

        # check calculation correctness
            # nan
        if ((a[1:6] == '11111' and a[6:16] != '0000000000') or (b[1:6] == '11111' and b[6:16] != '0000000000')): 
            assert out == "1111111111111111"
            # both denormal
        elif (a[1:6] == '00000' and b[1:6] == '00000' and op != '0100'):
            assert out == '0000000000000000'
            # a denormal add
        elif (a[1:6] == '00000' and op == '0001'):
            assert out == b
            # a denoarmal sub
        elif (a[1:6] == '00000' and op == '0010'):
            assert (out[0] != b[0] and out[1:16] == b[1:16])
            # b denormal add
        elif (b[1:6] == '00000' and op == '0001'):
            assert out == a
            # b denormal sub
        elif (b[1:6] == '00000' and op == '0010'):
            assert (out[0] != a[0] and out[1:16] == a[1:16])
            # denormal mult
        elif ((a[1:6] == '00000' or b[1:6] == '00000') and op == '0100'):
            assert out == '0000000000000000'
            # denormal result
        elif (golden_result[1:6] == '00000'):
            assert (out[1:16] == '000000000000000')
            # normal case
        else:
            assert (out == golden_result) or (abs(binary_to_float16(out)-binary_to_float16(golden_result))<abs(binary_to_float16(out))/100)



def binary_to_float16(binary_str):
    if len(binary_str) != 16 or any(c not in '01' for c in binary_str):
        print("Error: Input must be a 16-bit binary string.")
        return None
    
    # Convert binary string to an integer
    int_rep = int(binary_str, 2)
    
    # Pack integer as a single two-byte integer (half-precision float), using little endian
    binary_rep = struct.pack('<H', int_rep)
    
    # Convert binary data to float16
    return np.frombuffer(binary_rep, dtype=np.float16)[0]

def float_to_binary16(number):
    # Ensure the input is a numpy float16
    float16_number = np.float16(number)
    
    # Convert float16 to bytes using little-endian format
    bytes_rep = struct.pack('<e', float16_number)
    
    # Convert bytes to integer
    int_rep = int.from_bytes(bytes_rep, 'little')
    
    # Format integer to binary string padded to 16 bits
    binary_string = format(int_rep, '016b')
    return binary_string
