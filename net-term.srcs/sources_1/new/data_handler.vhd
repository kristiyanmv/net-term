-- filepath: c:\Users\Kris\Documents\Masters\net-term\net-term.srcs\sources_1\new\data_handler.vhd
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
        bram_addra     : out std_logic_vector(4 downto 0);   -- 17 rows (0..16)
        bram_dina      : out std_logic_vector(479 downto 0);
        bram_douta     : in  std_logic_vector(479 downto 0);
        bram_wea       : out std_logic;
        bram_ena       : out std_logic;

        -- UART RX input
        uart_rx_valid  : in  std_logic;
        uart_rx_data   : in  std_logic_vector(7 downto 0);

        -- UART TX output
        uart_tx_ready  : in  std_logic;
        uart_tx_start  : out std_logic;
        uart_tx_data   : out std_logic_vector(7 downto 0)
    );
end data_handler;

architecture Behavioral of data_handler is

    --------------------------------------------------------------------
    -- FSM states
    --------------------------------------------------------------------
    type state_t is (
        IDLE,
        INPUT_CHAR,
        DELETE_CHAR,
        ENTER,
        SCROLL_READ1,   -- assert address (cycle 0)
        SCROLL_READ2,   -- wait (cycle 1)
        SCROLL_READ3,
        SCROLL_SAMPLE,  -- sample bram_douta (cycle 2) and write to i-1
        SCROLL_WRITE_BOTTOM,
        BRAM_WRITE,
        UART_PREPARE,
        UART_READ1,
        UART_READ2,
        UART_READ3,
        UART_LOAD_ROW,
        UART_LOAD_CHAR,
        UART_SEND_CHAR,
        UART_WAIT_TX,
        UART_SEND_CR,
        UART_SEND_LF
    );
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
    -- BRAM control (internal signals)
    --------------------------------------------------------------------
    signal addra_reg     : std_logic_vector(4 downto 0) := (others => '0');
    signal bram_dina_sig : std_logic_vector(479 downto 0) := (others => '0');
    signal bram_wea_sig  : std_logic := '0';

    --------------------------------------------------------------------
    -- UART control (internal signals)
    --------------------------------------------------------------------
    signal uart_tx_ena : std_logic := '0';
    signal uart_idx    : integer range 0 to 63 := 0;
    signal uart_row    : std_logic_vector(479 downto 0);
    signal uart_byte   : std_logic_vector(7 downto 0) := x"00";

    --------------------------------------------------------------------
    -- Scroll control
    --------------------------------------------------------------------
    signal scroll_idx  : integer range 1 to 16 := 1; -- iterate 1..16

    --------------------------------------------------------------------
    -- Data buffer
    --------------------------------------------------------------------
    signal data_buf    : std_logic_vector(7 downto 0) := (others => '0');

    -- is_uart='1' means the current bottom-line content was last produced by UART
    -- (e.g. prompt without CR). We should not treat it as user input.
    signal is_uart : std_logic := '0';

    -- When a keyboard key arrives right after a UART prompt (no CR), we scroll the prompt up
    -- and replay the key on a clean input line.
    signal pending_valid : std_logic := '0';
    signal pending_buf   : std_logic_vector(7 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Drive BRAM outputs from internal signals
    --------------------------------------------------------------------
    bram_ena   <= '1';
    bram_wea   <= bram_wea_sig;
    bram_dina  <= bram_dina_sig;
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
        -- variable for immediate row edits (and for sampling bram_douta)
        variable v_sampled_row : std_logic_vector(479 downto 0);
        variable v_col_clear   : integer range 0 to 60;
    begin
        if rising_edge(clk) then
            -- default outputs each cycle
            bram_wea_sig  <= '0';
            bram_dina_sig <= row_buf;   -- default to bottom-line buffer

            if reset = '1' then
                state         <= IDLE;
                cursor_col    <= 0;
                row_buf       <= (others => '0');
                scroll_idx    <= 1;
                is_uart       <= '0';
                pending_valid <= '0';
                pending_buf   <= (others => '0');

                uart_tx_start <= '0';
                uart_tx_ena   <= '0';
                uart_tx_data  <= x"00";
                uart_idx      <= 0;
                uart_byte     <= x"00";
                addra_reg     <= (others => '0');

            else
                case state is

                    when IDLE =>
                        addra_reg     <= "10000";       -- default address = bottom row (16)
                        uart_tx_start <= '0';           -- stop UART TX
                        uart_tx_ena   <= '0';
                        uart_byte     <= x"00";

                        if ascii_fall_detected = '1' then
                            -- Keyboard input
                            if is_uart = '1' then
                                -- If the last visible bottom line came from UART (e.g. "Login:" prompt without CR),
                                -- scroll it up and clear the input line, then replay this key.
                                pending_valid <= '1';
                                pending_buf   <= '0' & ascii_code;
                                is_uart       <= '0';
                                uart_tx_ena   <= '0';  -- never transmit the prompt line
                                state         <= ENTER;
                            else
                                is_uart  <= '0';
                                data_buf <= '0' & ascii_code;

                                if ascii_code = "0001101" then      -- Enter
                                    state       <= ENTER;
                                    uart_tx_ena <= '1';
                                elsif ascii_code = "0001000" then   -- Backspace
                                    state <= DELETE_CHAR;
                                else
                                    state <= INPUT_CHAR;
                                end if;
                            end if;

                        elsif uart_rx_valid = '1' then
                            -- UART RX character goes to the display bottom line
                            data_buf    <= uart_rx_data;
                            uart_tx_ena <= '0';
                            uart_byte   <= x"00";

                            if uart_rx_data = x"0D" then      -- CR => new line (scroll)
                                is_uart <= '0';
                                state   <= ENTER;
                            else
                                is_uart <= '1';
                                state   <= INPUT_CHAR;
                            end if;
                        end if;


                    when INPUT_CHAR =>
                        if cursor_col < 60 then
                            -- Update local row image and also drive bram_dina_sig with the UPDATED value
                            v_sampled_row := row_buf;
                            v_sampled_row((479 - cursor_col*8) downto (472 - cursor_col*8)) := data_buf;
                            row_buf <= v_sampled_row;
                            cursor_col <= cursor_col + 1;

                            -- request write of bottom line
                            addra_reg     <= "10000";
                            bram_dina_sig <= v_sampled_row;
                            bram_wea_sig  <= '1';
                            state         <= BRAM_WRITE;
                        else
                            state <= IDLE;
                        end if;


                    when DELETE_CHAR =>
                        if cursor_col > 0 then
                            -- Clear previous character (cursor points to next insert position)
                            v_col_clear   := cursor_col - 1;
                            v_sampled_row := row_buf;
                            v_sampled_row((479 - v_col_clear*8) downto (472 - v_col_clear*8)) := (others => '0');
                            row_buf <= v_sampled_row;
                            cursor_col <= v_col_clear;

                            addra_reg     <= "10000";
                            bram_dina_sig <= v_sampled_row;
                            bram_wea_sig  <= '1';
                            state         <= BRAM_WRITE;
                        else
                            state <= IDLE;
                        end if;


                    when BRAM_WRITE =>
                        -- BRAM write occurs on this cycle (wea was asserted previous cycle).
                        bram_wea_sig <= '0';

                        -- If we had to scroll a UART prompt up, replay the first key now on the clean line.
                        if pending_valid = '1' then
                            pending_valid <= '0';
                            data_buf      <= pending_buf;

                            if pending_buf = x"0D" then        -- Enter
                                state       <= ENTER;
                                uart_tx_ena <= '1';
                            elsif pending_buf = x"08" then     -- Backspace
                                state <= DELETE_CHAR;
                            else
                                state <= INPUT_CHAR;
                            end if;

                        elsif uart_tx_ena = '1' then
                            state      <= UART_PREPARE;
                            uart_tx_ena <= '0';
                        else
                            state <= IDLE;
                        end if;


                    when ENTER =>
                        -- start scroll: copy rows 1..16 -> 0..15
                        scroll_idx <= 1;
                        addra_reg  <= std_logic_vector(to_unsigned(scroll_idx, 5));
                        state      <= SCROLL_READ1;


                    -- set address for row(scroll_idx); bram_douta will be valid after 2 cycles
                    when SCROLL_READ1 =>
                        addra_reg <= std_logic_vector(to_unsigned(scroll_idx, 5));
                        state     <= SCROLL_READ2;

                    when SCROLL_READ2 =>
                        state <= SCROLL_READ3;

                    when SCROLL_READ3 =>
                        state <= SCROLL_SAMPLE;

                    -- sample bram_douta (now valid after 2 cycles), write into address scroll_idx-1
                    when SCROLL_SAMPLE =>
                        v_sampled_row := bram_douta;
                        addra_reg      <= std_logic_vector(to_unsigned(scroll_idx - 1, 5));
                        bram_dina_sig  <= v_sampled_row;
                        bram_wea_sig   <= '1';

                        if scroll_idx < 16 then
                            scroll_idx <= scroll_idx + 1;
                            state      <= SCROLL_READ1;
                        else
                            state <= SCROLL_WRITE_BOTTOM;
                        end if;


                    when SCROLL_WRITE_BOTTOM =>
                        -- Clear bottom row in BRAM and clear the local input buffer.
                        addra_reg <= "10000";      -- bottom row index 16
                        v_sampled_row := (others => '0');
                        row_buf       <= v_sampled_row;
                        bram_dina_sig  <= v_sampled_row;
                        bram_wea_sig   <= '1';
                        cursor_col     <= 0;
                        is_uart        <= '0';
                        state          <= BRAM_WRITE;


                    when UART_PREPARE =>
                        -- read row 15 (the old row 16 after scrolling)
                        addra_reg    <= "01111";  -- 15
                        bram_wea_sig <= '0';      -- read
                        uart_idx     <= 0;
                        state        <= UART_READ1;

                    when UART_READ1 =>
                        state <= UART_READ2;

                    when UART_READ2 =>
                        state <= UART_READ3;

                    when UART_READ3 =>
                        state <= UART_LOAD_ROW;

                    when UART_LOAD_ROW =>
                        uart_row <= bram_douta;
                        state    <= UART_LOAD_CHAR;

                    when UART_LOAD_CHAR =>
                        uart_tx_start <= '0';

                        if uart_idx <= 60 then
                            uart_byte <= uart_row(479 - uart_idx*8 downto 472 - uart_idx*8);
                            uart_idx  <= uart_idx + 1;
                            state     <= UART_SEND_CHAR;
                        elsif uart_idx = 61 then
                            uart_byte <= x"0D";
                            uart_idx  <= uart_idx + 1;
                            state     <= UART_SEND_CHAR;
                        elsif uart_idx = 62 then
                            uart_byte <= x"0A";
                            uart_idx  <= uart_idx + 1;
                            state     <= UART_SEND_CHAR;
                        else
                            state <= IDLE;
                        end if;

                    when UART_SEND_CHAR =>
                        if uart_byte /= x"00" then
                            uart_tx_data <= uart_byte;
                            state        <= UART_WAIT_TX;
                        else
                            state <= UART_LOAD_CHAR;
                        end if;

                    when UART_WAIT_TX =>
                        if uart_tx_ready = '1' then
                            uart_tx_start <= '1';
                            state         <= UART_LOAD_CHAR;
                        end if;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
