----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/13/2025 12:16:15 PM
-- Design Name: 
-- Module Name: uart_sending_tb - Behavioral
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

entity uart_sending_tb is
--  Port ( );
end uart_sending_tb;

architecture Behavioral of uart_sending_tb is
signal ascii_new : std_logic:='0'; 
signal ascii_code : std_logic_vector ( 6 downto 0);
signal clock_50mhz : std_logic :='1';
signal uart_ready : std_logic :='1';
signal uart_send : std_logic;
signal uart_tx : std_logic_vector(7 downto 0);

begin
clock_50mhz <= not clock_50mhz after 10ns;
kb_handler_inst: entity work.keyboard_handler(Behavioral)
port map( 
clk => clock_50mhz,
ascii_code => ascii_code,
ascii_new => ascii_new,
uart_tx => uart_tx,
uart_ready => uart_ready,
uart_send => uart_send,
reset_n => '1');


stimulus:process
procedure sendingdata(signal ascii_code : out std_logic_vector(6 downto 0);
                      signal ascii_new : out std_logic) is
                      begin 
        ascii_code <= "1100001";
        ascii_new <= '1';
        wait for 10us;
        ascii_new <='0';
        wait for 10us;
        ascii_code <= "1100001";
        ascii_new <= '1';
             wait for 10us;
        ascii_new <='0';
        wait for 10us;
        ascii_code <= "1100001";
        ascii_new <= '1';
             wait for 10us;
        ascii_new <='0';
        wait for 10us;
        ascii_code <= "1100001";
        ascii_new <= '1';
             wait for 10us;
        ascii_new <='0';
        wait for 10us;
        ascii_code <= "0001101";
        ascii_new <= '1';
             wait for 10us;
        ascii_new <='0';
        wait for 10us;
        end procedure;
        begin 
        wait for 10us;
        sendingdata(ascii_code,ascii_new);
        wait;
        end process stimulus;
       
end Behavioral;
