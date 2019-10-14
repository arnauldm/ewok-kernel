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

with soc.rcc.default;

package body soc.usart.interfaces
   with spark_mode => on
is

   procedure configure
     (usart_id : in  t_usart_id;
      baudrate : in  unsigned_32;
      data_len : in  t_data_len;
      parity   : in  t_parity;
      stop     : in  t_stop_bits;
      success  : out boolean)
   is

      procedure do_configure
        (usart       : in out t_usart_peripheral;
         APB_clock   : in     unsigned_32;
         success     : out    boolean)
      with
         pre =>
           (APB_clock > 0 and APB_clock <= 84_000_000) and
           (baudrate >= 2400 and baudrate <= 115_200)
      is
         mantissa    : unsigned_32;
         fraction    : unsigned_32;
      begin
         usart.CR1.UE     := true; -- USART enable
         usart.CR1.TE     := true; -- Transmitter enable
         -- The kernel does not attempt to receive any char from its
         -- console
         usart.CR1.RE     := false; -- Receiver enable

         -- Configuring the baud rate is a tricky part. See RM0090 p. 982-983
         -- for further informations
         mantissa    := APB_clock / (16 * baudrate);
         fraction    := ((APB_clock * 25) / (4 * baudrate)) - mantissa * 100;
         fraction    := (fraction * 16) / 100;

         if fraction > 16#F# or mantissa > 16#FFF# then
            success := false;
            return;
         else
            usart.BRR.DIV_MANTISSA   := bits_12 (mantissa);
            usart.BRR.DIV_FRACTION   := bits_4  (fraction);
         end if;


         usart.CR1.M      := data_len;
         usart.CR2.STOP   := stop;

         usart.CR1.PCE := true;    -- Parity control enable
         usart.CR1.PS  := parity;

         -- No flow control
         usart.CR3.RTSE := false;
         usart.CR3.CTSE := false;

         success := true;
      end do_configure;

   begin

      case usart_id is
         when ID_USART1 =>
            do_configure (USART1, soc.rcc.default.CLOCK_APB2, success);
         when ID_UART4 =>
            do_configure (UART4, soc.rcc.default.CLOCK_APB1, success);
         when ID_USART6 =>
            do_configure (USART6, soc.rcc.default.CLOCK_APB2, success);
      end case;

   end configure;


   procedure transmit
     (usart_id : in  t_usart_id;
      data     : in  bits_9)
   is
   begin
      case usart_id is
         when ID_USART1 => soc.usart.transmit (USART1, data);
         when ID_UART4  => soc.usart.transmit (UART4,  data);
         when ID_USART6 => soc.usart.transmit (USART6, data);
      end case;
   end transmit;

end soc.usart.interfaces;
