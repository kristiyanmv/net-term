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
        bram_dina      : out std_logic_vector(479 downto 0); -- 60 chars * 8 bits
        bram_douta     : in  std_logic_vector(479 downto 0);
        bram_ena       : out std_logic;
        bram_wea       : out std_logic;
        -- UART signals
        -- UART RX input
        uart_rx_valid : in  std_logic;
        uart_rx_data  : in  std_logic_vector(7 downto 0);

        -- UART TX output
        uart_tx_start : out std_logic;
        uart_tx_data  : out std_logic_vector(7 downto 0);
        uart_tx_ready  : in  std_logic
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
    signal addra_reg   : std_logic_vector(4 downto 0) := (others => '0');
    signal bram_dina_sig : std_logic_vector(479 downto 0) := (others => '0');
    signal bram_wea_sig  : std_logic := '0';
    
      --------------------------------------------------------------------
    -- UART control (internal signals)
    --------------------------------------------------------------------
    signal uart_tx_ena : std_logic :='0';
    signal uart_idx  : integer range 0 to 60 := 0;
    signal uart_row  : std_logic_vector(479 downto 0);

    signal uart_rx_sync1,uart_rx_sync2 : std_logic :='0';
    signal uart_rx_rise_detected : std_logic :='0';
    signal uart_rx_valid_prev : std_logic := '0';
    signal uart_rx_rise       : std_logic := '0';
    --------------------------------------------------------------------
    -- Scroll helpers
    --------------------------------------------------------------------
    signal scroll_idx  : integer range 1 to 16 := 1; -- iterate 1..16
    signal data_buf   : std_logic_vector(7 downto 0);
    signal is_uart : std_logic := '0';
begin

    --------------------------------------------------------------------
    -- Drive BRAM outputs from internal signals
    --------------------------------------------------------------------
    bram_ena  <= '1';
    bram_wea  <= bram_wea_sig;
    bram_dina <= bram_dina_sig;
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
        -- variable for immediate sampling of bram_douta so we can use it same-cycle
        variable v_sampled_row : std_logic_vector(479 downto 0);
    begin
        if rising_edge(clk) then
            -- default outputs each cycle
            bram_wea_sig <= '0';
            bram_dina_sig <= row_buf;   -- default to bottom-line buffer

            if reset = '1' then
                state <= IDLE;
                cursor_col <= 0;
                row_buf <= (others => '0');
                scroll_idx <= 1;
            else
                case state is

                    when IDLE =>
                                addra_reg <= "10000";       -- default address = bottom row (16)
                                uart_tx_start <= '0'; --stop uart tx
                        if ascii_fall_detected = '1' then
                        data_buf <= '0' & ascii_code;
                      
                            if ascii_code = "0001101" then      -- Enter
                                state <= ENTER;
                                 uart_tx_ena <= '1';
                            elsif ascii_code = "0001000" then   -- Backspace
                                state <= DELETE_CHAR;
                            else
                                state <= INPUT_CHAR;
                            end if;
                      elsif uart_rx_valid = '1'then
                          -- new UART data received
                          data_buf <= uart_rx_data;
                          uart_tx_ena <= '0';
                          if uart_rx_data = x"0D" then      -- Enter
                                state <= ENTER;
                            else
                                state <= INPUT_CHAR;
                            end if;
                         
                        end if;
                      
                            

                    when INPUT_CHAR =>
                        if cursor_col < 60 then
                            -- pack 7-bit ascii + leading zero into 8 bits at cursor
                            row_buf((479 - cursor_col*8) downto (472 - cursor_col*8)) <= data_buf;
                            cursor_col <= cursor_col + 1;
                            -- request write of bottom line
                            addra_reg <= "10000";
                            bram_dina_sig <= row_buf;
                            bram_wea_sig <= '1';
                            state <= BRAM_WRITE;
                        else
                            state <= IDLE;
                        end if;

                    when DELETE_CHAR =>
                        if cursor_col > 0 then
                            cursor_col <= cursor_col - 1;
                            row_buf((479 - cursor_col*8) downto (472 - cursor_col*8)) <= (others => '0');
                            addra_reg <= "10000";
                            bram_dina_sig <= row_buf;
                            bram_wea_sig <= '1';
                            state <= BRAM_WRITE;
                        else
                            state <= IDLE;
                        end if;

                    when BRAM_WRITE =>
                        -- write strobe was asserted previous cycle; clear and return
                        bram_wea_sig <= '0';
                        if uart_tx_ena = '1' then
                        state <= UART_PREPARE;
                        uart_tx_ena <='0';
                        else 
                        state <= IDLE;
                        end if;

                    when ENTER =>
                        -- start scroll: copy rows 1..16 -> 0..15
                        scroll_idx <= 1;
                        addra_reg <= std_logic_vector(to_unsigned(scroll_idx, 5));
                        state <= SCROLL_READ1;

                    -- set address for row(scroll_idx); bram_douta will be valid after 2 cycles
                    when SCROLL_READ1 =>
                        addra_reg <= std_logic_vector(to_unsigned(scroll_idx, 5));
                        -- wait1
                        state <= SCROLL_READ2;

                    -- wait cycle 2
                    when SCROLL_READ2 =>
                        -- do nothing, another wait
                        state <= SCROLL_READ3;
                        
                    -- wait cycle 3
                    when SCROLL_READ3 =>
                        -- do nothing, another wait
                        state <= SCROLL_SAMPLE;

                    -- sample bram_douta (now valid after 2 cycles), write into address scroll_idx-1
                    when SCROLL_SAMPLE =>
                        -- sample into variable so we can immediately use it as bram_dina_sig
                        v_sampled_row := bram_douta;
                        -- write sampled row into address scroll_idx - 1
                        addra_reg <= std_logic_vector(to_unsigned(scroll_idx - 1, 5));
                        bram_dina_sig <= v_sampled_row;
                        bram_wea_sig <= '1';
                        -- advance
                        if scroll_idx < 16 then
                            scroll_idx <= scroll_idx + 1;
                            state <= SCROLL_READ1; -- next iteration
                        else
                            -- all rows copied, now write current bottom buffer into row 16
                            state <= SCROLL_WRITE_BOTTOM;
                        end if;

                    when SCROLL_WRITE_BOTTOM =>
                        addra_reg <= "10000";      -- bottom row index 16
                        bram_dina_sig <= row_buf;
                        bram_wea_sig <= '1';
                        -- clear buffer and cursor after write completes
                        row_buf <= (others => '0');
                        cursor_col <= 0;
                        state <= BRAM_WRITE;
                        
                        
                   when UART_PREPARE =>
                        -- read row 15 (the old row 16 after scrolling)
                     addra_reg    <= "01111";  -- binary for 15
                     bram_wea_sig <= '0';      -- read
                     uart_idx     <= 0;
                     state        <= UART_READ1;
                     
                    when UART_READ1 =>
                    state <= UART_READ2;
                    
                     when UART_READ2 =>
                    state <= UART_READ3;
                    
                     when UART_READ3 =>
                    state <= UART_SEND_CHAR;
                    
                  when UART_SEND_CHAR =>
                    -- capture full row
                 uart_row <= bram_douta;
                 uart_tx_data <= uart_row(479 downto 472);  -- first char    
                     uart_tx_start <= '1';
                     state         <= UART_WAIT_TX;

                when UART_WAIT_TX =>

                  if uart_tx_ready = '1' then
                     if uart_idx <= 59 then
                           uart_idx <= uart_idx + 1;
                            uart_tx_data <= uart_row(479 - uart_idx*8 downto 472 - uart_idx*8);
                      else
                          state <= UART_SEND_CR;  -- send cr/lf
                      end if;
                   end if;
                   when UART_SEND_CR =>
                      
                       if uart_tx_ready = '0' then
                          uart_tx_data <= x"0D"; -- CR
                         
                          state <= UART_SEND_LF;
                       end if;

                   when UART_SEND_LF =>
                      
                      if uart_tx_ready = '1' then
                         uart_tx_data <= x"0A"; -- LF
                       state <= IDLE;  -- complete
                       end if;
                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;