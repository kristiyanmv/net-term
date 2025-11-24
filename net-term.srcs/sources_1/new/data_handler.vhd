----------------------------------------------------------------------------------
-- data_handler_keyboard.vhd
-- Keyboard-only version for FPGA terminal text BRAM
-- Writes to bottom line (row 16) and handles backspace/enter
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_handler is
    Port (
        clk            : in  std_logic;
        reset          : in  std_logic;

        -- keyboard input
        ascii_new      : in  std_logic;
        ascii_code     : in  std_logic_vector(6 downto 0);

        -- BRAM interface
        bram_addra     : out std_logic_vector(4 downto 0);   -- 17 rows
        bram_dina      : out std_logic_vector(479 downto 0); -- 60 chars * 8 bits
        bram_douta     : in  std_logic_vector(479 downto 0);
        bram_ena       : out std_logic;
        bram_wea       : out std_logic
      
    );
end data_handler;

architecture Behavioral of data_handler is

    --------------------------------------------------------------------
    -- FSM states
    --------------------------------------------------------------------
    type state_t is (IDLE, INPUT_CHAR, DELETE_CHAR, ENTER, SCROLL, SCROLL_CLEAR,BRAM_WRITE);
    signal state : state_t := IDLE;

    --------------------------------------------------------------------
    -- Cursor and buffer
    --------------------------------------------------------------------
    signal cursor_col : integer range 0 to 60 := 0;
    signal row_buf    : std_logic_vector(479 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- Synchronizers and edge detection
    --------------------------------------------------------------------
    signal ascii_sync1, ascii_sync2 : std_logic := '0';
    signal ascii_fall_detected      : std_logic := '0';

    --------------------------------------------------------------------
    -- BRAM control
    --------------------------------------------------------------------
    signal write_req : std_logic := '0';
    signal addra_reg : std_logic_vector(4 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    bram_ena  <= '1';
    bram_wea  <= write_req;
    bram_dina <= row_buf;
    bram_addra <= addra_reg;

    --------------------------------------------------------------------
    -- ASCII input synchronizer and falling-edge detector
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            ascii_sync1 <= ascii_new;
            ascii_sync2 <= ascii_sync1;
            ascii_fall_detected <= ascii_sync2 and not ascii_sync1;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Main FSM
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset='1' then
                state <= IDLE;
                cursor_col <= 0;
                row_buf <= (others => '0');
           
                addra_reg <= "10000"; -- row 16
            else
                -- default BRAM write off
              
                addra_reg <= "10000"; -- bottom line

                case state is

                    when IDLE =>
                        if ascii_fall_detected='1' then
                            -- check key
                            if ascii_code="0001101" then      -- Enter
                                state <= ENTER;
                            elsif ascii_code="0001000" then   -- Backspace
                                state <= DELETE_CHAR;
                            else
                                state <= INPUT_CHAR;
                            end if;
                        end if;

                    when INPUT_CHAR =>
                        if cursor_col < 60 then
                            -- insert character into local buffer
                            row_buf((479 - cursor_col*8) downto (472 - cursor_col*8)) <= '0' & ascii_code;
                            cursor_col <= cursor_col + 1;
                            write_req <= '1';  -- write updated row to BRAM
                            state <= BRAM_WRITE;
                            else 
                            state <= IDLE;
                        end if;
                        

                    when DELETE_CHAR =>
                        if cursor_col > 0 then
                            cursor_col <= cursor_col - 1;
                            row_buf((479 - cursor_col*8) downto (472 - cursor_col*8)) <= (others => '0');
                            write_req <= '1';  -- write updated row to BRAM
                            state <= BRAM_WRITE;
                        
                      else   state <= IDLE;
                      end if;

                    when ENTER =>
                        -- write current bottom line
                        state <= SCROLL;

                    when SCROLL =>
                        -- shift rows 1..16 → 0..15
                        -- this part needs access to BRAM, can be done by top-level process or BRAM controller
                        -- for keyboard-only simulation we can just clear bottom line
                        row_buf <= (others => '0');
                        cursor_col <= 0;
                        state <= IDLE;
                        
                        when  BRAM_WRITE =>
                        write_req <='0';
                        state <= IDLE;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
