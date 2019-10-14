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

package body soc.usart
   with spark_mode => on
is

   procedure transmit
     (usart : in out t_USART_peripheral;
      data  : in     bits_9)
   is
      exit_cond : boolean;
   begin
      loop
         exit_cond := usart.SR.TXE;
         exit when exit_cond;
      end loop;
      usart.DR := t_USART_DR (data);
   end transmit;


   procedure receive
     (usart : in out t_USART_peripheral;
      data  : out    bits_9)
   is
      pragma unmodified (usart);
      exit_cond : boolean;
   begin
      loop
         exit_cond := usart.SR.RXNE;
         exit when exit_cond;
      end loop;
      data := bits_9 (usart.DR);
   end receive;


end soc.usart;
