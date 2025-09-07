----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/12/2025 07:09:02 PM
-- Design Name: 
-- Module Name: keyboard_handler - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity keyboard_handler is
    Port ( 
           clk        : in  std_logic;
           reset_n    : in  std_logic :='1';
           ascii_code : in  std_logic_vector(6 downto 0); -- 7-bit ASCII
           ascii_new  : in  std_logic;
           uart_tx    : out std_logic_vector(7 downto 0); -- UART still 8-bit
           uart_send  : out std_logic;
           uart_ready : in  std_logic
    );
end keyboard_handler;

architecture Behavioral of keyboard_handler is

    -- Buffer for storing characters
    type uart_data is array (0 to 127) of std_logic_vector(7 downto 0);
    signal data       : uart_data := (others => (others => '0'));
    
    signal iterator   : integer range 0 to 127 := 0;
    signal length     : integer range 0 to 127 := 0;
    
    -- Edge detection for ascii_new
    signal ascii_new_d : std_logic := '0';

    -- State machine
    type state_t is (IDLE, SEND, WAIT_READY, DONE);
    signal state : state_t := IDLE;

begin

    -- Detect rising edge of ascii_new
    process(clk)
    begin
        if rising_edge(clk) then
            ascii_new_d <= ascii_new;
        end if;
    end process;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            data      <= (others => (others => '0'));
            iterator  <= 0;
            length    <= 0;
            state     <= IDLE;
            uart_tx   <= (others => '0');
            uart_send <= '0';
        
        elsif rising_edge(clk) then
            uart_send <= '0'; -- default, only high for 1 clock when sending

            case state is
                ------------------------------------------------
                -- Waiting for new ASCII input
                ------------------------------------------------
                when IDLE =>
                    if ascii_new_d = '0' and ascii_new = '1' then -- rising edge
                        if ascii_code = "0001101" then -- 0x0D in 7-bit binary
                            -- Enter pressed, start sending buffer
                            iterator <= 0;
                            state    <= SEND;
                        else
                            -- Store character in buffer (pad to 8-bit)
                            if length < 128 then
                                data(length) <= '0' & ascii_code; -- MSB = 0
                                length       <= length + 1;
                            end if;
                        end if;
                    end if;

                ------------------------------------------------
                -- Output current byte to UART
                ------------------------------------------------
                when SEND =>
                    uart_tx   <= data(iterator);
                    uart_send <= '1';
                    state     <= WAIT_READY;

                ------------------------------------------------
                -- Wait for UART to signal it's ready for next byte
                ------------------------------------------------
                when WAIT_READY =>
                    if uart_ready = '1' then
                        if iterator + 1 < length then
                            iterator <= iterator + 1;
                            state    <= SEND;
                        else
                            state <= DONE;
                        end if;
                    end if;

                ------------------------------------------------
                -- Clear buffer after sending
                ------------------------------------------------
                when DONE =>
                    length <= 0;
                    state  <= IDLE;
            end case;
        end if;
    end process;

end Behavioral;