----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/12/2025 07:23:53 PM
-- Design Name: 
-- Module Name: data_handler_tester - Behavioral
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

entity data_handler_tester is
--  Port ( );
end data_handler_tester;

architecture Behavioral of data_handler_tester is
signal e_clk : std_logic := '1';
signal ascii_code : std_logic_vector(6 downto 0) := (others => '0');
signal ascii_new : std_logic := '1';
signal e_reset: std_logic :='0';
signal e_uart_rx_new: std_logic :='0';
signal e_uart_rx_data: std_logic_vector(7 downto 0) := (others =>'0');
signal e_bram_douta:std_logic_vector(479 downto 0) :=(others => '0');

begin
e_clk <= not e_clk after 10ns;
data_handler_inst: entity work.data_handler(Behavioral)
port map(
    clk => e_clk,
    ascii_code => ascii_code,
    ascii_new => ascii_new,
    reset => e_reset,
    bram_douta => e_bram_douta
);
stimulus : process
begin
    -------------------------------------------------------------------
    -- Send 'a' (ASCII 97 = 0x61 = "1100001")
    -------------------------------------------------------------------
    ascii_code <= "1100001";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';
    wait for 100 ns;

    -------------------------------------------------------------------
    -- Send 'b' (ASCII 98 = 0x62 = "1100010")
    -------------------------------------------------------------------
    ascii_code <= "1100010";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';
    wait for 100 ns;

    -------------------------------------------------------------------
    -- Send 'c' (ASCII 99 = 0x63 = "1100011")
    -------------------------------------------------------------------
    ascii_code <= "1100011";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';
    wait for 100 ns;

    -------------------------------------------------------------------
    -- Send 'd' (ASCII 100 = 0x64 = "1100100")
    -------------------------------------------------------------------
    ascii_code <= "1100100";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';
    wait for 100 ns;

    -------------------------------------------------------------------
    -- Send 'e' (ASCII 101 = 0x65 = "1100101")
    -------------------------------------------------------------------
    ascii_code <= "1100101";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';
    wait for 100 ns;

    -------------------------------------------------------------------
    -- Send Enter (ASCII 13 = 0x0D = "0001101")
    -------------------------------------------------------------------
    ascii_code <= "0001101";
    ascii_new  <= '1';
    wait for 20 ns;
    ascii_new  <= '0';

    -------------------------------------------------------------------
    -- Wait some time to observe results
    -------------------------------------------------------------------
    wait for 500 ns;

    wait; -- end simulation
end process stimulus;

end Behavioral;
