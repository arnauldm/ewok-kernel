--
-- Copyright 2018 The wookey project team <wookey@ssi.gouv.fr>
--   - Ryad     Benadjila
--   - Arnauld  Michelizza
--   - Mathieu  Renard
--   - Philippe Thierry
--   - Philippe Trebuchet
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--     Unless required by applicable law or agreed to in writing, software
--     distributed under the License is distributed on an "AS IS" BASIS,
--     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--     See the License for the specific language governing permissions and
--     limitations under the License.
--
--


with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.devices_shared;  use ewok.devices_shared;
with ewok.exported;
with ewok.exported.gpios;
with ewok.gpio;

with soc.gpio;
with soc.usart;            use soc.usart;
with soc.rcc;
with soc.devmap;

#if CONFIG_KERNEL_PANIC_WIPE
with soc;
with soc.layout; use soc.layout;
#end if;

#if not CONFIG_KERNEL_PANIC_FREEZE
with m4;
with m4.scb;
#end if;


package body ewok.debug
   with spark_mode => on
is

   TX_pin_config     : ewok.exported.gpios.t_gpio_config;

   USART1_TX_pin_config : constant ewok.exported.gpios.t_gpio_config :=
     (settings => ewok.exported.gpios.t_gpio_settings'(others => true),
      kref     => ewok.exported.gpios.t_gpio_ref'
        (pin   => 6,
         port  => soc.gpio.GPIO_PB),
      mode     => ewok.exported.gpios.GPIO_AF,
      pupd     => ewok.exported.gpios.GPIO_PULLUP,
      otype    => ewok.exported.gpios.GPIO_PUSH_PULL,
      ospeed   => ewok.exported.gpios.GPIO_HIGH_SPEED,
      af       => ewok.exported.gpios.GPIO_AF_USART1,
      bsr_r    => 0,
      bsr_s    => 0,
      lck      => 0,
      exti_trigger   => ewok.exported.gpios.GPIO_EXTI_TRIGGER_NONE,
      exti_lock      => ewok.exported.gpios.GPIO_EXTI_UNLOCKED,
      exti_handler   => 16#0000_0000#);

   USART4_TX_pin_config : constant ewok.exported.gpios.t_gpio_config :=
     (settings => ewok.exported.gpios.t_gpio_settings'(others => true),
#if CONFIG_WOOKEY
      kref     => ewok.exported.gpios.t_gpio_ref'
        (pin   => 0,
         port  => soc.gpio.GPIO_PA),
#else
      kref     => ewok.exported.gpios.t_gpio_ref'
        (pin   => 6,
         port  => soc.gpio.GPIO_PB),
#end if;
      mode     => ewok.exported.gpios.GPIO_AF,
      pupd     => ewok.exported.gpios.GPIO_PULLUP,
      otype    => ewok.exported.gpios.GPIO_PUSH_PULL,
      ospeed   => ewok.exported.gpios.GPIO_HIGH_SPEED,
      af       => ewok.exported.gpios.GPIO_AF_UART4,
      bsr_r    => 0,
      bsr_s    => 0,
      lck      => 0,
      exti_trigger   => ewok.exported.gpios.GPIO_EXTI_TRIGGER_NONE,
      exti_lock      => ewok.exported.gpios.GPIO_EXTI_UNLOCKED,
      exti_handler   => 16#0000_0000#);

   USART6_TX_pin_config : constant ewok.exported.gpios.t_gpio_config :=
     (settings => ewok.exported.gpios.t_gpio_settings'(others => true),
      kref     => ewok.exported.gpios.t_gpio_ref'
        (pin   => 6,
         port  => soc.gpio.GPIO_PC),
      mode     => ewok.exported.gpios.GPIO_AF,
      pupd     => ewok.exported.gpios.GPIO_PULLUP,
      otype    => ewok.exported.gpios.GPIO_PUSH_PULL,
      ospeed   => ewok.exported.gpios.GPIO_HIGH_SPEED,
      af       => ewok.exported.gpios.GPIO_AF_USART6,
      bsr_r    => 0,
      bsr_s    => 0,
      lck      => 0,
      exti_trigger   => ewok.exported.gpios.GPIO_EXTI_TRIGGER_NONE,
      exti_lock      => ewok.exported.gpios.GPIO_EXTI_UNLOCKED,
      exti_handler   => 16#0000_0000#);


   procedure init
     (usart : in soc.usart.interfaces.t_usart_id)
   is
      ok             : boolean;
   begin

      kernel_usart_id := usart;

      case usart is
         when soc.usart.interfaces.ID_USART1 =>
            TX_pin_config     := USART1_TX_pin_config;
         when soc.usart.interfaces.ID_UART4 =>
            TX_pin_config     := USART4_TX_pin_config;
         when soc.usart.interfaces.ID_USART6 =>
            TX_pin_config     := USART6_TX_pin_config;
      end case;

      ewok.gpio.register (ID_KERNEL, ID_DEV_UNUSED, TX_pin_config, ok);
      if not ok then
         raise program_error;
      end if;

      ewok.gpio.config (TX_pin_config);

      case kernel_usart_id is
         when soc.usart.interfaces.ID_USART1 => soc.rcc.enable_clock (soc.devmap.USART1);
         when soc.usart.interfaces.ID_UART4  => soc.rcc.enable_clock (soc.devmap.UART4);
         when soc.usart.interfaces.ID_USART6 => soc.rcc.enable_clock (soc.devmap.USART6);
      end case;

      soc.usart.interfaces.configure
        (kernel_usart_id, 115_200, DATA_9BITS, PARITY_ODD, STOP_1, ok);
      if not ok then
         raise program_error;
      end if;

      log (INFO,
         "EwoK: USART" & soc.usart.interfaces.t_usart_id'image (usart) &
         " initialized");
      newline;

   end init;


   procedure putc (c : character)
   is
   begin
#if CONFIG_KERNEL_SERIAL
      soc.usart.interfaces.transmit (kernel_usart_id, character'pos (c));
#else
      null;
#end if;
   end putc;


   procedure put (s : string)
   is
   begin
      for i in s'range loop
         putc (s(i));
      end loop;
   end put;


   procedure newline
   is
   begin
      put (ASCII.CR & ASCII.LF);
   end newline;


   procedure log (s : string; nl : boolean := true)
   is
   begin
      put (s);
      if nl then
         newline;
      end if;
   end log;


   procedure log (level : t_level; s : string)
   is
   begin
      case level is
         when DEBUG           => put (BG_COLOR_ORANGE);
         when INFO            => put (BG_COLOR_BLUE);
         when WARNING         => put (BG_COLOR_ORANGE);
         when ERROR .. ALERT  => put (BG_COLOR_RED);
      end case;
      put (s);
      put (BG_COLOR_BLACK);
   end log;


   procedure alert (s : string)
   is
   begin
      put (BG_COLOR_RED);
      put (s);
      put (BG_COLOR_BLACK);
   end alert;


   procedure panic (s : string)
   is
   begin
      put (BG_COLOR_RED & "panic: ");
      put (s);
      put (BG_COLOR_BLACK);
      newline;

#if CONFIG_KERNEL_PANIC_FREEZE
      loop null; end loop;
#end if;

#if CONFIG_KERNEL_PANIC_REBOOT
      m4.scb.reset;
#end if;

#if CONFIG_KERNEL_PANIC_WIPE
      declare
         sram : array (0 .. soc.layout.USER_RAM_SIZE) of types.byte
            with address => to_address(USER_RAM_BASE);
      begin
         -- Wiping the user applications in RAM before reseting. Kernel data
         -- and bss are not cleared because the are in use and there should
         -- be no sensible content in kernel data (secrets are hold by user tasks).
         -- TODO: Clearing IPC content
         sram := (others => 0);
         m4.scb.reset;
      end;
#end if;
   end panic;

end ewok.debug;
