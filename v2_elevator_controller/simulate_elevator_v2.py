#!/usr/bin/env python3
"""
基于FPGA的6层电梯控制器仿真脚本 (V2)
模拟Verilog设计的逻辑行为，用于验证设计正确性
功能：支持按键呼梯、串口模式切换（自动/手动/消防/检修）
"""
import time
import sys

class ElevatorState:
    IDLE = 0
    UP = 1
    DOWN = 2
    OPEN_DOOR = 3
    CLOSE_DOOR = 4
    PROMPT = 5
    NAMES = {0: "IDLE", 1: "UP", 2: "DOWN", 3: "OPEN_DOOR", 4: "CLOSE_DOOR", 5: "PROMPT"}

class ElevatorMode:
    AUTO = 0
    MANUAL = 1
    FIRE = 2
    CHECK = 3
    NAMES = {0: "AUTO", 1: "MANUAL", 2: "FIRE", 3: "CHECK"}

class ElevatorSim:
    def __init__(self):
        self.reset()
        
    def reset(self):
        self.current_floor = 0  # 0-5 对应 1-6楼
        self.target_floor = 0
        self.state = ElevatorState.IDLE
        self.mode = ElevatorMode.AUTO
        self.door_open = False
        self.call_register = 6 * [False]
        self.delay_cnt = 0
        self.dir = 0 # 0: None, 1: Up, 2: Down
        self.buzzer = False
        
        self.floor_sensor = [False] * 6
        self.floor_sensor[0] = True # Start at floor 1
        print("=== System Reset (Mode: AUTO, Floor: 1) ===")
        self.print_status()

    def set_key_valid(self, index):
        print(f">>> Key Pressed: {index}")
        if self.mode == ElevatorMode.AUTO:
            if 0 <= index <= 5:
                self.call_register[index] = True
        elif self.mode == ElevatorMode.MANUAL:
            if index == 6: # Door Open
                self.state = ElevatorState.OPEN_DOOR
                self.delay_cnt = 0
                print("   [CMD] Manual Open Door")
            elif index == 7: # Door Close
                self.state = ElevatorState.CLOSE_DOOR
                self.delay_cnt = 0
                print("   [CMD] Manual Close Door")

    def set_mode(self, mode_cmd):
        print(f">>> UART Command: Switch to {ElevatorMode.NAMES[mode_cmd]}")
        self.mode = mode_cmd
        if mode_cmd == ElevatorMode.FIRE:
            self.call_register = 6 * [False]
            self.target_floor = 0
            if self.current_floor != 0:
                self.dir = 2 # Down
                self.state = ElevatorState.DOWN
            else:
                self.state = ElevatorState.OPEN_DOOR

    def set_floor_sensor(self, floor_index):
        # In real HW, sensors are updated by motor. Here we simulate it reaching floor
        self.floor_sensor = [False] * 6
        self.floor_sensor[floor_index] = True
        self.current_floor = floor_index
        print(f"   [SENSOR] Arrived at Floor {floor_index + 1}")

    def clock_tick(self):
        self.buzzer = False
        
        # Mode Logic
        if self.mode == ElevatorMode.FIRE:
            if self.state == ElevatorState.IDLE:
                if self.current_floor != 0:
                    self.state = ElevatorState.DOWN
                    self.dir = 2
                else:
                    self.state = ElevatorState.OPEN_DOOR
            # Force target floor logic is handled in transition
            return # Fire mode overrides normal logic

        # State Machine
        if self.state == ElevatorState.IDLE:
            # Check calls (Simplified scheduler for sim)
            has_call = any(self.call_register)
            if has_call:
                # Find target floor
                if self.call_register[self.current_floor]:
                    self.target_floor = self.current_floor
                    self.state = ElevatorState.OPEN_DOOR
                else:
                    # Find nearest call
                    if any(self.call_register[i] for i in range(self.current_floor + 1, 6)):
                        self.dir = 1
                        self.target_floor = max(i for i, x in enumerate(self.call_register) if x and i > self.current_floor)
                        self.state = ElevatorState.UP
                    elif any(self.call_register[i] for i in range(0, self.current_floor)):
                        self.dir = 2
                        self.target_floor = min(i for i, x in enumerate(self.call_register) if x and i < self.current_floor)
                        self.state = ElevatorState.DOWN
        
        elif self.state == ElevatorState.UP:
            # Check if we reached target
            if self.current_floor == self.target_floor:
                if self.call_register[self.current_floor]:
                    self.state = ElevatorState.PROMPT
                    self.delay_cnt = 0
                else:
                    self.dir = 0
                    self.state = ElevatorState.IDLE
            # If we pass the target (due to sensor simulation), handle it
            elif self.current_floor > self.target_floor:
                if self.call_register[self.current_floor]:
                    self.state = ElevatorState.PROMPT
                    self.delay_cnt = 0
                else:
                    self.dir = 0
                    self.state = ElevatorState.IDLE
            
        elif self.state == ElevatorState.DOWN:
            if self.current_floor == self.target_floor:
                if self.call_register[self.current_floor]:
                    self.state = ElevatorState.PROMPT
                    self.delay_cnt = 0
                else:
                    self.dir = 0
                    self.state = ElevatorState.IDLE
            elif self.current_floor < self.target_floor:
                if self.call_register[self.current_floor]:
                    self.state = ElevatorState.PROMPT
                    self.delay_cnt = 0
                else:
                    self.dir = 0
                    self.state = ElevatorState.IDLE

        elif self.state == ElevatorState.PROMPT:
            self.buzzer = True
            self.delay_cnt += 1
            if self.delay_cnt >= 5: # 1 sec
                self.state = ElevatorState.OPEN_DOOR
                self.delay_cnt = 0

        elif self.state == ElevatorState.OPEN_DOOR:
            self.door_open = True
            self.call_register[self.current_floor] = False # Clear call
            self.delay_cnt += 1
            if self.delay_cnt >= 10: # 3 secs
                self.state = ElevatorState.CLOSE_DOOR
                self.delay_cnt = 0

        elif self.state == ElevatorState.CLOSE_DOOR:
            self.door_open = False
            self.delay_cnt += 1
            if self.delay_cnt >= 6: # 2 secs
                self.state = ElevatorState.IDLE
                self.delay_cnt = 0
                # Update target based on remaining calls
                if any(self.call_register[i] for i in range(self.current_floor + 1, 6)):
                    self.target_floor = max(i for i, x in enumerate(self.call_register) if x and i > self.current_floor)
                elif any(self.call_register[i] for i in range(0, self.current_floor)):
                    self.target_floor = min(i for i, x in enumerate(self.call_register) if x and i < self.current_floor)

    def print_status(self):
        floor_str = "".join([f"[{i+1}]" if i == self.current_floor else f" {i+1} " for i in range(6)])
        state_str = ElevatorState.NAMES[self.state]
        mode_str = ElevatorMode.NAMES[self.mode]
        dir_str = "UP" if self.dir == 1 else ("DOWN" if self.dir == 2 else "---")
        print(f"Floor: {floor_str} | Dir: {dir_str:4s} | State: {state_str:10s} | Mode: {mode_str}")

def run_v2_test():
    sim = ElevatorSim()
    
    # Test 1: Auto Mode - Call from 4
    print("\n--- Test 1: Auto Mode (Call Floor 4) ---")
    sim.set_key_valid(3) # Press 4
    # Simulate motor movement
    for i in range(4): # 4 to 6 is limit, simulate movement up
        sim.set_floor_sensor(sim.current_floor + 1)
        sim.clock_tick()
        sim.print_status()
        time.sleep(0.1)

    # Test 2: UART Switch to Fire Mode
    print("\n--- Test 2: Switch to FIRE Mode ---")
    sim.set_mode(ElevatorMode.FIRE)
    
    # Simulate return to floor 1
    while sim.current_floor > 0:
        sim.clock_tick()
        sim.set_floor_sensor(sim.current_floor - 1)
        sim.print_status()
        time.sleep(0.1)
    
    # Wait for door open logic
    for _ in range(20): sim.clock_tick(); time.sleep(0.1)

    # Test 3: Switch to Manual Mode
    print("\n--- Test 3: Switch to MANUAL Mode ---")
    sim.set_mode(ElevatorMode.MANUAL)
    
    # Manually open door
    sim.set_key_valid(6) # Open
    for _ in range(15): sim.clock_tick(); time.sleep(0.1)
    
    # Manually close door
    sim.set_key_valid(7) # Close
    for _ in range(15): sim.clock_tick(); time.sleep(0.1)

if __name__ == "__main__":
    run_v2_test()
