library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_driver_de_nv3047_with_bram is
  generic (
    H_ACTIVE    : integer := 480;
    V_ACTIVE    : integer := 272;
    H_FP        : integer := 2;
    H_SYNC_DUMMY: integer := 0;
    H_BP        : integer := 43;
    V_FP        : integer := 8;
    V_SYNC_DUMMY: integer := 0;
    V_BP        : integer := 6;
    DE_LEAD_PIX : integer := 1;
    DE_TRAIL_PIX: integer := 1
  );
  port (
    red          : out std_logic_vector(7 downto 0);
    green        : out std_logic_vector(7 downto 0);
    blue         : out std_logic_vector(7 downto 0);
    enable       : out std_logic;
    clk          : out std_logic;
    hsync        : out std_logic;
    vsync        : out std_logic;
    data_enable  : out std_logic;
    backlight    : out std_logic;

    master_clock : in  std_logic;
    dclk_in      : in  std_logic;

    fb_addra     : out std_logic_vector(11 downto 0);
    bram_douta   : in  std_logic_vector(31 downto 0);
    bram_enable  : out std_logic := '1'
  );
end lcd_driver_de_nv3047_with_bram;

architecture Behavioral of lcd_driver_de_nv3047_with_bram is

  constant H_TOTAL        : integer := H_ACTIVE + H_FP + H_SYNC_DUMMY + H_BP;
  constant V_TOTAL        : integer := V_ACTIVE + V_FP + V_SYNC_DUMMY + V_BP;
  constant H_ACTIVE_START : integer := H_FP + H_SYNC_DUMMY + H_BP;
  constant H_ACTIVE_END   : integer := H_ACTIVE_START + H_ACTIVE - 1;
  constant V_ACTIVE_START : integer := V_FP + V_SYNC_DUMMY + V_BP;
  constant V_ACTIVE_END   : integer := V_ACTIVE_START + V_ACTIVE - 1;

  constant WORD_PIXELS    : integer := 32;
  constant TOTAL_PIX      : integer := H_ACTIVE * V_ACTIVE;
  constant WORD_COUNT     : integer := TOTAL_PIX / WORD_PIXELS;

  signal x_cnt : integer range 0 to H_TOTAL-1 := 0;
  signal y_cnt : integer range 0 to V_TOTAL-1 := 0;
  signal de_sig : std_logic := '0';

  signal addr_req        : unsigned(11 downto 0) := (others=>'0');
  signal addr_pipe1      : unsigned(11 downto 0) := (others=>'0');
  signal addr_pipe2      : unsigned(11 downto 0) := (others=>'0');

  signal bitpos_req      : integer range 0 to 31 := 0;
  signal bitpos_pipe1    : integer range 0 to 31 := 0;
  signal bitpos_pipe2    : integer range 0 to 31 := 0;

  signal shift_reg1      : std_logic_vector(31 downto 0) := (others=>'0');
  signal shift_reg2      : std_logic_vector(31 downto 0) := (others=>'0');
  signal pixel_bit       : std_logic := '0';

  signal r_reg, g_reg, b_reg : std_logic_vector(7 downto 0) := (others=>'0');

begin

  clk         <= dclk_in;
  hsync       <= '0';
  vsync       <= '0';
  data_enable <= de_sig;
  red         <= r_reg;
  green       <= g_reg;
  blue        <= b_reg;
  enable      <= '1';
  backlight   <= '1';

  bram_enable <= '1';

  ----------------------------------------------------------------
  -- Compute requested BRAM address for the current pixel
  ----------------------------------------------------------------
  process(x_cnt, y_cnt)
    variable x_active, y_active, pixel_index, word_addr_int : integer;
  begin
    if (x_cnt >= H_ACTIVE_START) and (x_cnt <= H_ACTIVE_END) and
       (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) then
      x_active := x_cnt - H_ACTIVE_START;
      y_active := y_cnt - V_ACTIVE_START;
      pixel_index := y_active * H_ACTIVE + x_active;
      word_addr_int := pixel_index / WORD_PIXELS;
      addr_req <= to_unsigned(word_addr_int, addr_req'length);
      bitpos_req <= pixel_index mod WORD_PIXELS;
    else
      addr_req <= addr_req;
      bitpos_req <= 0;
    end if;
  end process;

  ----------------------------------------------------------------
  -- Raster counters, DE generation, and BRAM 2-stage pipeline
  ----------------------------------------------------------------
  process(dclk_in)
    variable de_start_x : integer := H_ACTIVE_START - DE_LEAD_PIX;
    variable de_end_x   : integer := H_ACTIVE_END + DE_TRAIL_PIX;
  begin
    if rising_edge(dclk_in) then
      -- advance raster counters
      if x_cnt = H_TOTAL-1 then
        x_cnt <= 0;
        if y_cnt = V_TOTAL-1 then
          y_cnt <= 0;
        else
          y_cnt <= y_cnt + 1;
        end if;
      else
        x_cnt <= x_cnt + 1;
      end if;

      -- DE
      if de_start_x < 0 then de_start_x := 0; end if;
      if de_end_x > H_TOTAL-1 then de_end_x := H_TOTAL-1; end if;
      if (x_cnt >= de_start_x) and (x_cnt <= de_end_x) and
         (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) then
        de_sig <= '1';
      else
        de_sig <= '0';
      end if;

      -- 2-stage BRAM pipeline
      addr_pipe1 <= addr_req;
      addr_pipe2 <= addr_pipe1;
      fb_addra <= std_logic_vector(addr_pipe2);

      shift_reg1 <= bram_douta;
      shift_reg2 <= shift_reg1;

      bitpos_pipe1 <= bitpos_req;
      bitpos_pipe2 <= bitpos_pipe1;

      pixel_bit <= shift_reg2(bitpos_pipe2);

      -- RGB expansion
      if (x_cnt >= H_ACTIVE_START) and (x_cnt <= H_ACTIVE_END) and
         (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) and (de_sig='1') then
        if pixel_bit='1' then
          r_reg <= x"FF"; g_reg <= x"FF"; b_reg <= x"FF";
        else
          r_reg <= (others=>'0'); g_reg <= (others=>'0'); b_reg <= (others=>'0');
        end if;
      else
        r_reg <= (others=>'0'); g_reg <= (others=>'0'); b_reg <= (others=>'0');
      end if;

    end if;
  end process;

end Behavioral;
