----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/28/2025 08:34:50 AM
-- Design Name: 
-- Module Name: ps_2_tb - Behavioral
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

entity ps_2_tb is
 --   Port ( 
end ps_2_tb;

architecture Behavioral of ps_2_tb is
           signal ascii_trig : std_logic := '0';
           signal ascii_symbol : std_logic_vector(6 downto 0) := (others => '0');
           signal entity_ps2_clk :  STD_LOGIC :='1'; 
           signal entity_ps2_data :  STD_LOGIC :='1';
           signal entity_clk : std_logic :='1';
begin
entity_clk <= not entity_clk after 10ns;
ps2_inst: entity work.ps2_keyboard_to_ascii(behavior)
port map(
            clk => entity_clk,
            ps2_clk => entity_ps2_clk,
            ps2_data => entity_ps2_data,
            ascii_new => ascii_trig,
            ascii_code => ascii_symbol);
stimulus:process 
procedure ps2_send_byte(signal ps2_data  : inout std_logic;
                        signal ps2_clock : inout std_logic;
                        data_byte        : in  std_logic_vector(7 downto 0)) is
    variable parity : std_logic := '1'; -- Odd parity
begin
    -- Start bit
    ps2_data <= '0';
    wait for 50 us;  -- Wait before first clock
    for i in 0 to 10 loop
        ps2_clock <= '0';  -- Clock low
        wait for 20 us;

        case i is
            when 0 =>
                ps2_data <= '0'; -- Start bit
            when 1 to 8 =>
                ps2_data <= data_byte(i-1);
                if data_byte(i-1) = '1' then
                    parity := not parity;
                end if;
            when 9 =>
                ps2_data <= parity; -- Parity bit
            when 10 =>
                ps2_data <= '1'; -- Stop bit
        end case;

        ps2_clock <= '1';  -- Clock high
        wait for 20 us;
    end loop;

    -- Return to idle state
    ps2_data <= '1';
    ps2_clock <= '1';
end procedure;
begin
 wait for 10us;
 --ps2_send_byte(entity_ps2_data, entity_ps2_clk, x"F0");
ps2_send_byte(entity_ps2_data, entity_ps2_clk, x"1C");
 wait;
 
end process stimulus;
end Behavioral;
