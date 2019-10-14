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

with system;      use system;
with soc.rcc;


package body soc.exti
   with spark_mode => on
is

   procedure init
   is
   begin
      for line in t_exti_line_index'range loop
         clear_pending(line);
         disable(line);
      end loop;
      soc.rcc.RCC.APB2ENR.SYSCFGEN := true;
   end init;


   procedure is_line_pending
     (line     : in  t_exti_line_index;
      pending  : out boolean)
   is
      request : t_request;
   begin
      request := EXTI.PR.line(line);
      if request = PENDING_REQUEST then
         pending := true;
      else
         pending := false;
      end if;
   end is_line_pending;


   procedure clear_pending
     (line : in t_exti_line_index)
   is
      pending_exti : t_requests;
   begin
      pending_exti         := EXTI.PR.line;
      pending_exti(line)   := CLEAR_REQUEST;
      EXTI.PR.line         := pending_exti;
   end clear_pending;


   procedure enable
     (line : in t_exti_line_index)
   is
      intr_mask : t_masks;
   begin
      intr_mask         := EXTI.IMR.line;
      intr_mask(line)   := NOT_MASKED; -- interrupt is unmasked
      EXTI.IMR.line     := intr_mask;
   end enable;


   procedure disable
     (line : in t_exti_line_index)
   is
      intr_mask : t_masks;
   begin
      intr_mask         := EXTI.IMR.line;
      intr_mask(line)   := MASKED; -- interrupt is masked
      EXTI.IMR.line     := intr_mask;
   end disable;


   procedure is_enabled
     (line     : in t_exti_line_index;
      enabled  : out boolean)
   is
      mask : t_mask;
   begin
      mask := EXTI.IMR.line(line);
      if mask = NOT_MASKED then
         enabled := true;
      else
         enabled := false;
      end if;
   end;

end soc.exti;
