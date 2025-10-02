--------------------------------------------------------------------------------
-- lcd_driver_de_nv3047_with_bram.vhd
-- 4.3" 480x272 TFT (NV3047) - DE Mode Driver (monochrome framebuffer)
-- - Reads 32 bits from BRAM (1 bit per pixel) and expands to RGB
-- - BRAM: 32-bit wide, depth 4080 words (addresses 0..4079)
-- - Port A of BRAM is used for display, clka => dclk_in, ena tied high
-- - Handles BRAM synchronous read latency with a one-cycle pipeline
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_driver_de_nv3047_with_bram is
  generic (
    -- Active resolution
    H_ACTIVE         : integer := 480;
    V_ACTIVE         : integer := 272;

    -- Typical porches (for DE alignment only, not real syncs)
    H_FP             : integer := 2;
    H_SYNC_DUMMY     : integer := 0;
    H_BP             : integer := 43;
    V_FP             : integer := 8;
    V_SYNC_DUMMY     : integer := 0;
    V_BP             : integer := 6;

    -- DE margins (in pixels/lines): DE goes high 'lead' before active, low 'trail' after
    DE_LEAD_PIX      : integer := 1;
    DE_TRAIL_PIX     : integer := 1
  );
  port (
    -- LCD interface
    red          : out std_logic_vector(7 downto 0);
    green        : out std_logic_vector(7 downto 0);
    blue         : out std_logic_vector(7 downto 0);
    enable       : out std_logic;    -- DISP
    clk          : out std_logic;    -- DCLK to panel (buffered dclk_in)
    hsync        : out std_logic;    -- held LOW in DE mode
    vsync        : out std_logic;    -- held LOW in DE mode
    data_enable  : out std_logic;    -- DE (active high during visible region ± margins)
    backlight    : out std_logic;

    -- Clock
    master_clock : in  std_logic;    -- unused here
    dclk_in      : in  std_logic;

    -- BRAM Port A (display side)
    -- Connect these to the generated Block Memory Generator IP port A:
    --    clka -> dclk_in
    --    ena  -> '1'
    --    wea  -> "0000"
    --    addra -> fb_addra
    --    douta -> bram_douta
    fb_addra     : out std_logic_vector(11 downto 0);  -- address driven to BRAM port A (0..4079)
    bram_douta   : in  std_logic_vector(31 downto 0) ;  -- data returned from BRAM port A (synchronous)
    bram_enable : out std_logic :='1'
  );
end lcd_driver_de_nv3047_with_bram;

architecture Behavioral of lcd_driver_de_nv3047_with_bram is

  -- Timing constants and derived values
  constant H_TOTAL        : integer := H_ACTIVE + H_FP + H_SYNC_DUMMY + H_BP;
  constant V_TOTAL        : integer := V_ACTIVE + V_FP + V_SYNC_DUMMY + V_BP;
  constant H_ACTIVE_START : integer := H_FP + H_SYNC_DUMMY + H_BP;               -- first active x
  constant H_ACTIVE_END   : integer := H_ACTIVE_START + H_ACTIVE - 1;            -- last active x
  constant V_ACTIVE_START : integer := V_FP + V_SYNC_DUMMY + V_BP;               -- first active y
  constant V_ACTIVE_END   : integer := V_ACTIVE_START + V_ACTIVE - 1;            -- last active y

  -- Framebuffer geometry
  constant WORD_PIXELS    : integer := 32;
  constant TOTAL_PIX      : integer := H_ACTIVE * V_ACTIVE;                     -- 480*272 = 130560
  constant WORD_COUNT     : integer := TOTAL_PIX / WORD_PIXELS;                 -- 4080 words

  -- Raster counters
  signal x_cnt : integer range 0 to H_TOTAL-1 := 0;
  signal y_cnt : integer range 0 to V_TOTAL-1 := 0;

  -- DE signal
  signal de_sig : std_logic := '0';

  -- BRAM address request pipeline:
  -- We compute the desired word address for the *current* active pixel (addr_req),
  -- register it into addr_req_reg, drive it to the BRAM (fb_addra <= addr_req_reg),
  -- then bram_douta will be valid next cycle and we capture into shift_reg.
  signal addr_req       : unsigned(11 downto 0) := (others => '0'); -- combinationally computed
  signal addr_req_reg   : unsigned(11 downto 0) := (others => '0'); -- registered -> driven to BRAM
  signal bitpos_req     : integer range 0 to 31 := 0;               -- bit position within the word for the *current* pixel
  signal bitpos_reg     : integer range 0 to 31 := 0;               -- registered (aligned to shift_reg)

  -- Word shift register (holds 32 pixels that map to the current displayed word)
  signal shift_reg      : std_logic_vector(31 downto 0) := (others => '0');

  -- Output pixel (pipelined)
  signal pixel_bit      : std_logic := '0';

  -- RGB output registers (pipelined by one clock)
  signal r_reg, g_reg, b_reg : std_logic_vector(7 downto 0) := (others => '0');

begin

  -- Panel pins
  clk         <= dclk_in;
  hsync       <= '0'; -- DE mode: held low
  vsync       <= '0'; -- DE mode: held low
  data_enable <= de_sig;
  red         <= r_reg;
  green       <= g_reg;
  blue        <= b_reg;
  enable      <= '1';
  backlight   <= '1';

  ----------------------------------------------------------------
  -- Compute requested BRAM address (combinational) for the current pixel.
  -- Address = floor( ( (y_active * H_ACTIVE) + x_active ) / 32 )
  -- bitpos  = (x_active mod 32)
  -- When outside active area we keep addr_req stable (avoid rough toggles).
  ----------------------------------------------------------------
  compute_addr : process(x_cnt, y_cnt)
    variable x_active, y_active : integer;
    variable pixel_index        : integer;
    variable word_addr_int      : integer;
  begin
    if (x_cnt >= H_ACTIVE_START) and (x_cnt <= H_ACTIVE_END) and
       (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) then
      x_active := x_cnt - H_ACTIVE_START;
      y_active := y_cnt - V_ACTIVE_START;
      pixel_index := y_active * H_ACTIVE + x_active; -- linear pixel index in visible window
      word_addr_int := pixel_index / WORD_PIXELS;    -- integer division
      addr_req <= to_unsigned(word_addr_int, addr_req'length);
      bitpos_req <= pixel_index mod WORD_PIXELS;
    else
      -- Outside active area: keep previous request (avoid address churn). We'll output black.
      addr_req <= addr_req;     -- no change
      bitpos_req <= 0;
    end if;
  end process compute_addr;

  ----------------------------------------------------------------
  -- Main raster: advance x/y counters on pixel clock, manage DE
  -- We also implement the BRAM pipeline:
  --  - Register addr_req -> addr_req_reg (this drives BRAM addra)
  --  - Capture bram_douta into shift_reg (valid for addr_req_reg from previous cycle)
  --  - Capture bitpos_req -> bitpos_reg so we index the correct bit in shift_reg
  --  - pixel_bit <= shift_reg(bitpos_reg)
  -- Note: bram_douta is a BRAM synchronous output that becomes valid one cycle after addra changes.
  ----------------------------------------------------------------
  process(dclk_in)
   variable de_start_x : integer := H_ACTIVE_START - DE_LEAD_PIX;
   variable de_end_x   : integer := H_ACTIVE_END   + DE_TRAIL_PIX;
  begin
    if rising_edge(dclk_in) then

      -- advance raster counters
      if x_cnt = H_TOTAL - 1 then
        x_cnt <= 0;
        if y_cnt = V_TOTAL - 1 then
          y_cnt <= 0;
        else
          y_cnt <= y_cnt + 1;
        end if;
      else
        x_cnt <= x_cnt + 1;
      end if;

      -- DE generation with lead/trail margins
     
      if de_start_x < 0 then de_start_x := 0; end if;
      if de_end_x > H_TOTAL-1 then de_end_x := H_TOTAL-1; end if;

      if (x_cnt >= de_start_x) and (x_cnt <= de_end_x) and
         (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) then
        de_sig <= '1';
      else
        de_sig <= '0';
      end if;

      ----------------------------------------------------------------
      -- BRAM pipeline registers
      ----------------------------------------------------------------
      -- 1) drive BRAM address with the registered request (addr_req_reg)
      addr_req_reg <= addr_req;

      -- expose address externally so the top-level can wire it to BRAM port A
      fb_addra <= std_logic_vector(addr_req_reg);

      -- 2) capture BRAM synchronous output into the shift register
      --    bram_douta corresponds to the address that was on addra in the previous cycle
      shift_reg <= bram_douta;

      -- 3) register the bit position so it lines up with the loaded shift_reg
      bitpos_reg <= bitpos_req;

      -- 4) produce pixel bit from registered shift_reg/bitpos_reg
      --    Note: bitpos_reg corresponds to the pixel index associated with the loaded word.
      pixel_bit <= shift_reg(bitpos_reg);

      ----------------------------------------------------------------
      -- RGB expansion and output (monochrome -> 0xFF or 0x00)
      -- Only output valid color during true active window (H_ACTIVE_START..H_ACTIVE_END, V_ACTIVE_START..V_ACTIVE_END).
      -- Because BRAM read is pipelined, the pixel_bit used here is aligned with the output clock.
      ----------------------------------------------------------------
      if (x_cnt >= H_ACTIVE_START) and (x_cnt <= H_ACTIVE_END) and
         (y_cnt >= V_ACTIVE_START) and (y_cnt <= V_ACTIVE_END) and (de_sig = '1') then
        if pixel_bit = '1' then
          r_reg <= x"FF";
          g_reg <= x"FF";
          b_reg <= x"FF";
        else
          r_reg <= (others => '0');
          g_reg <= (others => '0');
          b_reg <= (others => '0');
        end if;
      else
        -- outside active region: output black
        r_reg <= (others => '0');
        g_reg <= (others => '0');
        b_reg <= (others => '0');
      end if;

    end if; -- rising_edge
  end process;

end Behavioral;
