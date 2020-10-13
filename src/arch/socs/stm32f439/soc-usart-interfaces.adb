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

package body soc.usart.interfaces
   with spark_mode => off
is

   procedure configure
     (usart_id : in  t_usart_id;
      baudrate : in  unsigned_32;
      data_len : in  t_data_len;
      parity   : in  t_parity_bit;
      stop     : in  t_stop_bits;
      success  : out boolean)
   is
      usart    : t_USART_peripheral_access;
   begin

      case usart_id is
         when ID_USART1 => usart := USART1'access;
         when ID_UART4  => usart := UART4'access;
         when ID_USART6 => usart := USART6'access;
      end case;

      usart.all.CR1.UE     := true; -- USART enable
      usart.all.CR1.TE     := true; -- Transmitter enable
      -- The kernel does not attempt to receive any char from its
      -- console
      usart.all.CR1.RE     := false; -- Receiver enable

      set_baudrate (usart, baudrate);

      usart.all.CR1.M      := data_len;
      usart.all.CR2.STOP   := stop;


      case parity is
         -- Parity control disable
         when PARITY_BIT_NONE => usart.CR1.PCE := false;

         -- Parity control enable
         when PARITY_BIT_EVEN => usart.CR1.PS  := PARITY_EVEN;
                                 usart.CR1.PCE := true;

         when PARITY_BIT_ODD  => usart.CR1.PS  := PARITY_ODD;
                                 usart.CR1.PCE := true;
      end case;

      -- No flow control
      usart.all.CR3.RTSE := false;
      usart.all.CR3.CTSE := false;

      success := true;
      return;
   end configure;


   procedure transmit
     (usart_id : in  t_usart_id;
      data     : in  bits_9)
   is
   begin
      case usart_id is
         when ID_USART1 => soc.usart.transmit (USART1'access, data);
         when ID_UART4  => soc.usart.transmit (UART4'access, data);
         when ID_USART6 => soc.usart.transmit (USART6'access, data);
      end case;
   end transmit;

end soc.usart.interfaces;
