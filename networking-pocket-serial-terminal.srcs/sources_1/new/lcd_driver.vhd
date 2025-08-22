--------------------------------------------------------------------------------
-- 4.3" 480x272 TFT (NV3047) - DE Mode Driver (PLL-based pixel clock)
-- - HSYNC/VSYNC held low (DE mode)
-- - DE asserted slightly before/after active window (lead/trail margins)
-- - Pixel clock provided externally on dclk_in (from PLL/MMCM)
-- - Full-screen color cycle for quick bring-up
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lcd_driver_de_nv3047 is
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
    DE_TRAIL_PIX     : integer := 1;

    -- Color dwell (frames per color)
    FRAMES_PER_COLOR : integer := 90
  );
  port (
    red          : out std_logic_vector(7 downto 0);
    green        : out std_logic_vector(7 downto 0);
    blue         : out std_logic_vector(7 downto 0);
    enable       : out std_logic;    -- DISP (assert per power-up sequence on real HW)
    clk          : out std_logic;    -- DCLK to panel (buffered dclk_in)
    hsync        : out std_logic;    -- held LOW in DE mode
    vsync        : out std_logic;    -- held LOW in DE mode
    data_enable  : out std_logic;    -- DE (active high during visible region ± margins)
    backlight    : out std_logic;
    master_clock : in  std_logic;    -- unused in this version, but can gate enable
    dclk_in      : in  std_logic     -- pixel clock from PLL
  );
end lcd_driver_de_nv3047;

architecture Behavioral of lcd_driver_de_nv3047 is
  -- Totals and active window placement
  constant H_TOTAL        : integer := H_ACTIVE + H_FP + H_SYNC_DUMMY + H_BP;
  constant V_TOTAL        : integer := V_ACTIVE + V_FP + V_SYNC_DUMMY + V_BP;
  constant H_ACTIVE_START : integer := H_FP + H_SYNC_DUMMY + H_BP;                 -- first active x
  constant H_ACTIVE_END   : integer := H_ACTIVE_START + H_ACTIVE - 1;              -- last active x
  constant V_ACTIVE_START : integer := V_FP + V_SYNC_DUMMY + V_BP;                 -- first active y
  constant V_ACTIVE_END   : integer := V_ACTIVE_START + V_ACTIVE - 1;              -- last active y

  -- Signals
  signal x          : integer := 0;  -- 0 .. H_TOTAL-1
  signal y          : integer := 0;  -- 0 .. V_TOTAL-1

  signal de_sig     : std_logic := '0';
  signal r_sig      : std_logic_vector(7 downto 0) := (others => '0');
  signal g_sig      : std_logic_vector(7 downto 0) := (others => '0');
  signal b_sig      : std_logic_vector(7 downto 0) := (others => '0');

  signal frame_cnt  : integer := 0;
  signal color_sel  : integer := 0;  -- 0:R,1:G,2:B,3:W,4:K
begin
  -- Panel pins
  clk         <= dclk_in;   -- forward PLL pixel clock directly
  hsync       <= '0';       -- DE mode: keep LOW
  vsync       <= '0';       -- DE mode: keep LOW
  data_enable <= de_sig;
  red         <= r_sig;
  green       <= g_sig;
  blue        <= b_sig;
  enable      <= '1';       -- assert (panel enable) once power-up timing is OK
  backlight   <= '1';

  ----------------------------------------------------------------
  -- Main raster process: runs on PLL pixel clock
  ----------------------------------------------------------------
  process(dclk_in)
    variable r_next, g_next, b_next : std_logic_vector(7 downto 0);
    variable de_start_x : integer;
    variable de_end_x   : integer;
    variable de_start_y : integer;
    variable de_end_y   : integer;
  begin
    if rising_edge(dclk_in) then
      -- Compute DE window with lead/trail (clamped)
      de_start_x := H_ACTIVE_START - DE_LEAD_PIX; if de_start_x < 0 then de_start_x := 0; end if;
      de_end_x   := H_ACTIVE_END   + DE_TRAIL_PIX; if de_end_x > (H_TOTAL-1) then de_end_x := H_TOTAL-1; end if;
      de_start_y := V_ACTIVE_START;  -- no vertical lead
      de_end_y   := V_ACTIVE_END;

      ----------------------------------------------------------------
      -- Raster counters (advance at pixel rate)
      ----------------------------------------------------------------
      if x = H_TOTAL - 1 then
        x <= 0;
        if y = V_TOTAL - 1 then
          y <= 0;

          -- End of frame: rotate solid colors
          frame_cnt <= frame_cnt + 1;
          if frame_cnt >= FRAMES_PER_COLOR then
            frame_cnt <= 0;
            if color_sel = 4 then color_sel <= 0; else color_sel <= color_sel + 1; end if;
          end if;

        else
          y <= y + 1;
        end if;
      else
        x <= x + 1;
      end if;

      ----------------------------------------------------------------
      -- DE generation
      ----------------------------------------------------------------
      if (x >= de_start_x) and (x <= de_end_x) and
         (y >= de_start_y) and (y <= de_end_y) then
        de_sig <= '1';
      else
        de_sig <= '0';
      end if;

      ----------------------------------------------------------------
      -- RGB drive: ONLY during true active region
      ----------------------------------------------------------------
      if (x >= H_ACTIVE_START) and (x <= H_ACTIVE_END) and
         (y >= V_ACTIVE_START) and (y <= V_ACTIVE_END) then
        case color_sel is
          when 0 => r_next := x"FF"; g_next := x"00"; b_next := x"00"; -- Red
          when 1 => r_next := x"00"; g_next := x"FF"; b_next := x"00"; -- Green
          when 2 => r_next := x"00"; g_next := x"00"; b_next := x"FF"; -- Blue
          when 3 => r_next := x"FF"; g_next := x"FF"; b_next := x"FF"; -- White
          when others => r_next := (others => '0'); g_next := (others => '0'); b_next := (others => '0'); -- Black
        end case;
      else
        r_next := (others => '0');
        g_next := (others => '0');
        b_next := (others => '0');
      end if;

      -- Register outputs
      r_sig <= r_next;
      g_sig <= g_next;
      b_sig <= b_next;
    end if;
  end process;
end Behavioral;
