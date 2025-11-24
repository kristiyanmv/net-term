----------------------------------------------------------------------------------
-- Frame Builder (FSM Version)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_builder is
    Port (
        clk            : in  std_logic;

        -- Framebuffer BRAM (write port)
        fb_ram_clk     : out std_logic;
        fb_ram_addr    : out std_logic_vector(11 downto 0);
        fb_ram_dout    : out std_logic_vector(31 downto 0);
        fb_ram_ena     : out std_logic;
        fb_ram_wea     : out std_logic;                       -- *** NEW ***

        -- Font BRAM (read-only)
        font_bram_clk  : out std_logic;
        font_addr      : out std_logic_vector(9 downto 0);
        font_dout      : in  std_logic_vector(7 downto 0);
        font_ena       : out std_logic;

        -- Text BRAM (read-only)
        text_bram_addr : out std_logic_vector(4 downto 0);
        text_bram_dout : in  std_logic_vector(479 downto 0);
        text_bram_ena  : out std_logic
    );
end frame_builder;

architecture Behavioral of frame_builder is

    -- Constants
    constant CHAR_W    : integer := 8;
    constant CHAR_H    : integer := 16;
    constant COLS      : integer := 60;
    constant ROWS      : integer := 17;
    constant FB_WORDS  : integer := 4080;

    -- FSM states
    type state_t is (
        IDLE,
        FETCH_CHAR,
        FETCH_FONT,
        WRITE_BIT,
        NEXT_PIXEL
    );
    signal state : state_t := IDLE;

    -- Raster counters
    signal x_cnt : integer range 0 to 479 := 0;
    signal y_cnt : integer range 0 to 271 := 0;

    -- Character indices
    signal char_col : integer range 0 to COLS-1 := 0;
    signal char_row : integer range 0 to ROWS-1 := 0;
    signal char_x   : integer range 0 to CHAR_W-1 := 0;
    signal char_y   : integer range 0 to CHAR_H-1 := 0;

    -- Character & font registers
    signal current_char   : std_logic_vector(7 downto 0) := (others=>'0');
    signal font_row_index : integer range 0 to 7 := 0;
    signal font_data_reg  : std_logic_vector(7 downto 0) := (others=>'0');

    -- Framebuffer assembly
    signal fb_word       : std_logic_vector(31 downto 0) := (others=>'0');
    signal fb_bit_index  : integer range 0 to 31 := 0;
    signal fb_addr_cnt   : integer range 0 to FB_WORDS-1 := 0;

begin

    font_bram_clk <= clk;
    fb_ram_clk    <= clk;
    text_bram_ena <= '1';
    font_ena      <= '1';
    fb_ram_ena    <= '1';

    -------------------------------------------------------------------------
    -- MAIN FSM
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then

            fb_ram_wea <= '0';   -- default

            case state is

                ----------------------------------------------------------------------
                -- Start of frame
                ----------------------------------------------------------------------
                when IDLE =>
                    x_cnt <= 0;
                    y_cnt <= 0;
                    fb_addr_cnt <= 0;
                    fb_bit_index <= 0;
                    fb_word <= (others=>'0');
                    state <= FETCH_CHAR;

                ----------------------------------------------------------------------
                -- Read character from Text BRAM
                ----------------------------------------------------------------------
                when FETCH_CHAR =>
                    char_col <= x_cnt / CHAR_W;
                    char_x   <= x_cnt mod CHAR_W;

                    char_row <= y_cnt / CHAR_H;
                    char_y   <= y_cnt mod CHAR_H;

                    text_bram_addr <= std_logic_vector(to_unsigned(char_row, 5));

                    current_char <= text_bram_dout(char_col*8 + 7 downto char_col*8);

                    font_row_index <= char_y;

                    state <= FETCH_FONT;

                ----------------------------------------------------------------------
                -- Issue font BRAM address, latch previous data
                ----------------------------------------------------------------------
                when FETCH_FONT =>
                    font_addr <= std_logic_vector(
                        to_unsigned(
                            to_integer(unsigned(current_char)) * CHAR_H + font_row_index, 10
                        )
                    );

                    font_data_reg <= font_dout;

                    state <= WRITE_BIT;

                ----------------------------------------------------------------------
                -- Write single pixel bit into 32-bit word
                ----------------------------------------------------------------------
                when WRITE_BIT =>

                    fb_word(fb_bit_index) <= font_data_reg(7 - char_x);

                    if fb_bit_index = 31 then
                        fb_ram_addr <= std_logic_vector(to_unsigned(fb_addr_cnt, 12));
                        fb_ram_dout <= fb_word;

                        fb_ram_wea <= '1';       -- *** WRITE ENABLE ***

                        fb_addr_cnt <= fb_addr_cnt + 1;
                        fb_bit_index <= 0;
                        fb_word <= (others=>'0');
                    else
                        fb_bit_index <= fb_bit_index + 1;
                    end if;

                    state <= NEXT_PIXEL;

                ----------------------------------------------------------------------
                -- Step raster
                ----------------------------------------------------------------------
                when NEXT_PIXEL =>

                    if x_cnt = 479 then
                        x_cnt <= 0;
                        if y_cnt = 271 then
                            y_cnt <= 0;
                            state <= IDLE;
                        else
                            y_cnt <= y_cnt + 1;
                            state <= FETCH_CHAR;
                        end if;
                    else
                        x_cnt <= x_cnt + 1;
                        state <= FETCH_CHAR;
                    end if;

            end case;
        end if;
    end process;

end Behavioral;
