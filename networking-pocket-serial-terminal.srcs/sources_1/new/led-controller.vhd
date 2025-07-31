----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/31/2025 01:27:44 PM
-- Design Name: 
-- Module Name: led-controller - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_controller is
    Port ( new_character : in STD_LOGIC;
           ascii_code : in STD_LOGIC_VECTOR (6 downto 0);
           led1 : out STD_LOGIC;
           led2 : out STD_LOGIC);
end led_controller;

architecture Behavioral of led_controller is
signal led1_state : std_logic := '0';
signal led2_state : std_logic := '0';

begin
led1 <=led1_state;
led2 <=led2_state;
process (new_character)
begin 
if falling_edge(new_character) then 
case ascii_code is 
when x"61" => led1_state <= not led1_state;
when x"73" => led2_state <= not led2_state;
when others => led1_state <= '0'; led2_state <='0';
end case;
end if;
end process;

end Behavioral;
