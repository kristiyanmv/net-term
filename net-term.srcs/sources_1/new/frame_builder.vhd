-- filepath: c:\Users\Kris\Documents\Masters\net-term\net-term.srcs\sources_1\new\frame_builder.vhd
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
        fb_ram_wea     : out std_logic;

        -- Font BRAM (read-only)
        font_bram_clk  : out std_logic;
        font_addr      : out std_logic_vector(10 downto 0);
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
    constant WORDS_PER_LINE : integer := 480 / 32;  -- = 15

    -- FSM states
    type state_t is (
        IDLE,
        FETCH_CHAR,
        WAIT_T1,
        WAIT_T2,
        SAMPLE_CHAR,
        REQUEST_FONT,
        WAIT_F1,
        WAIT_F2,
        SAMPLE_FONT,
        WRITE_BIT,
        NEXT_PIXEL
    );
    signal state : state_t := IDLE;

    -- Raster counters
    signal x_cnt : integer range 0 to 479 := 0;
    signal y_cnt : integer range 0 to 271 := 0;

    -- Character indices (kept for visibility across cycles)
    signal char_col : integer range 0 to COLS-1 := 0;
    signal char_row : integer range 0 to ROWS-1 := 0;
    signal char_x   : integer range 0 to CHAR_W-1 := 0;
    signal char_y   : integer range 0 to CHAR_H-1 := 0;

    -- Character & font registers
    signal current_char   : std_logic_vector(7 downto 0) := (others=>'0');
    signal font_row_index : integer range 0 to CHAR_H-1 := 0;
    signal font_data_reg  : std_logic_vector(7 downto 0) := (others=>'0');

    -- control
    signal font_fetch_req : std_logic := '0';

    -- Framebuffer assembly
    signal fb_word       : std_logic_vector(31 downto 0) := (others=>'0');
    signal fb_bit_index  : integer range 0 to 31 := 0;
    signal fb_word_index : integer range 0 to WORDS_PER_LINE-1 := 0;

    -- stable/driven outputs for BRAM (probe-friendly)
    signal fb_ram_dout_sig : std_logic_vector(31 downto 0) := (others => '0');
    signal fb_ram_wea_sig  : std_logic := '0';

begin

    -- drive entity ports from internal signals
    fb_ram_dout <= fb_ram_dout_sig;
    fb_ram_wea  <= fb_ram_wea_sig;

    font_bram_clk <= clk;
    fb_ram_clk    <= clk;
    text_bram_ena <= '1';
    font_ena      <= '1';
    fb_ram_ena    <= '1';

    -------------------------------------------------------------------------
    -- MAIN FSM
    -------------------------------------------------------------------------
    process(clk)
        -- local/temporary variables for same-cycle computations
        variable v_char   : unsigned(7 downto 0);
        variable v_addr   : integer;
        variable v_col    : integer;
        variable v_row    : integer;
        variable v_x      : integer;
        variable v_y      : integer;
        variable v_fb_word : std_logic_vector(31 downto 0);
        variable v_line_base : integer;
        variable v_addr_index: integer;
         variable v_char_byte    : integer;
        variable v_bit_in_byte  : integer;
        variable v_target_bit   : integer;
    begin
        if rising_edge(clk) then

            -- defaults for driven outputs (stabilize nets)
            fb_ram_wea_sig <= '0';
            fb_ram_dout_sig <= fb_ram_dout_sig;

            -- start local copy from the signal
            v_fb_word := fb_word;

            case state is

                when IDLE =>
                    x_cnt <= 0;
                    y_cnt <= 0;
                    fb_bit_index <= 0;
                    fb_word_index <= 0;
                    fb_word <= (others=>'0');
                    font_fetch_req <= '0';
                    state <= FETCH_CHAR;

                -- compute character indices and drive text BRAM addr immediately
                when FETCH_CHAR =>
                    v_col := x_cnt / CHAR_W;
                    v_x   := x_cnt mod CHAR_W;
                    v_row := y_cnt / CHAR_H;
                    v_y   := y_cnt mod CHAR_H;

                    -- update visible indices for downstream cycles
                    char_col <= v_col;
                    char_x   <= v_x;
                    char_row <= v_row;
                    char_y   <= v_y;

                    -- drive text address now (must be stable for two cycles)
                    text_bram_addr <= std_logic_vector(to_unsigned(v_row, text_bram_addr'length));
                    font_row_index <= v_y;

                    state <= WAIT_T1;

                when WAIT_T1 =>
                    -- hold address one more cycle
                    state <= WAIT_T2;

                when WAIT_T2 =>
                    -- after second wait, sample next cycle
                    state <= SAMPLE_CHAR;

                -- sample text BRAM output (after 2-cycle latency)
                when SAMPLE_CHAR =>
                    -- extract 8-bit char from packed 480-bit word
                    v_char := unsigned(text_bram_dout(char_col*8 + 7 downto char_col*8));
                    current_char <= std_logic_vector(v_char);

                    -- printable check: fetch font only for > 0x20
                    if to_integer(v_char) > 16#20# then
                        v_addr := to_integer(v_char) * CHAR_H + font_row_index;
                        font_addr <= std_logic_vector(to_unsigned(v_addr, font_addr'length));
                        font_fetch_req <= '1';
                        state <= WAIT_F1;
                    else
                        -- skip font BRAM, provide blank row
                        font_data_reg <= (others => '0');
                        font_fetch_req <= '0';
                        state <= WRITE_BIT;
                    end if;

                when WAIT_F1 =>
                    state <= WAIT_F2;

                when WAIT_F2 =>
                    state <= SAMPLE_FONT;

                -- sample font BRAM output (after 2-cycle latency)
                when SAMPLE_FONT =>
                    font_data_reg <= font_dout;
                    font_fetch_req <= '0';
                    state <= WRITE_BIT;

                -- assemble bits into 32-bit word; when full, write with reversed word order per line
                when WRITE_BIT =>
                    -- compute byte/bit indices for current fb_bit_index
                    v_char_byte   := fb_bit_index / 8;         -- 0..3
                    v_bit_in_byte := fb_bit_index mod 8;       -- 0..7

                    -- place the byte into the reversed byte slot but keep intra-byte bit order
                    -- target byte index = (3 - v_char_byte)
                    v_target_bit := (3 - v_char_byte) * 8 + v_bit_in_byte;

                    -- write the specific bit from font_data_reg into the target bit position
                    v_fb_word(v_target_bit) := font_data_reg(7 - v_bit_in_byte);

                    -- update the signal copy for future cycles
                    fb_word <= v_fb_word;

                    if fb_bit_index = 31 then
                        -- compute line base and reversed index (Option A)
                        v_line_base := y_cnt * WORDS_PER_LINE;
                        v_addr_index := v_line_base + (WORDS_PER_LINE - 1 - fb_word_index);

                        fb_ram_dout_sig <= v_fb_word;
                        fb_ram_addr <= std_logic_vector(to_unsigned(v_addr_index, fb_ram_addr'length));
                        fb_ram_wea_sig <= '1';

                        -- advance word index in current line
                        if fb_word_index = WORDS_PER_LINE - 1 then
                            fb_word_index <= 0;
                        else
                            fb_word_index <= fb_word_index + 1;
                        end if;

                        fb_bit_index <= 0;
                        fb_word <= (others=>'0'); -- clear for next word (scheduled)
                    else
                        fb_bit_index <= fb_bit_index + 1;
                    end if;

                    state <= NEXT_PIXEL;

                -- advance pixel counters and reset per-line state when needed
                when NEXT_PIXEL =>
                    if x_cnt = 479 then
                        x_cnt <= 0;
                        if y_cnt = 271 then
                            y_cnt <= 0;
                            fb_word_index <= 0;
                            state <= IDLE;
                        else
                            y_cnt <= y_cnt + 1;
                            fb_word_index <= 0; -- reset at start of new scanline
                            state <= FETCH_CHAR;
                        end if;
                    else
                        x_cnt <= x_cnt + 1;
                        state <= FETCH_CHAR;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;