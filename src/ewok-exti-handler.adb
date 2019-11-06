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

with soc.gpio;             use soc.gpio;
with soc.exti;             use soc.exti;
with soc.syscfg;
with soc.nvic;
with soc.interrupts;
with ewok.exported.gpios;  use type ewok.exported.gpios.t_interface_gpio_exti_lock;
with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.gpio;
with ewok.isr;
with ewok.debug;

package body ewok.exti.handler
   with spark_mode => on
is

   procedure handle_line
     (line        : in  soc.exti.t_exti_line_index;
      interrupt   : in  soc.interrupts.t_interrupt)
   is
      ref         : ewok.exported.gpios.t_gpio_ref;
      gpio_config : ewok.exported.gpios.t_gpio_config;
      task_id     : ewok.tasks_shared.t_task_id;
   begin

      -- Clear the EXTI pending bit for this line
      soc.exti.clear_pending (line);

      -- Retrieve the configured GPIO point associated to this line
      ref.pin  := t_gpio_pin_index'val (t_exti_line_index'pos (line));
      soc.syscfg.get_exti_port
        (ref.pin,   -- input
         ref.port); -- output

      -- Is the GPIO handled by a user task ?
      if not ewok.gpio.is_used (ref) then
         soc.nvic.clear_pending_irq (soc.nvic.to_irq_number (interrupt));
         pragma DEBUG (debug.log (debug.ERROR, "unable to find GPIO informations for port" &
            t_gpio_port_index'image (ref.port) & ", pin" &
            t_gpio_pin_index'image (ref.pin)));
      else
         task_id  := ewok.gpio.get_task_id (ref);

         if task_id = ID_UNUSED then
            raise program_error;
         end if;

         -- Retrieving the GPIO configuration associated to that GPIO point.
         -- Permit to get the "real" user ISR.
         gpio_config := ewok.gpio.get_config (ref);

         ewok.isr.postpone_isr
           (interrupt, gpio_config.exti_handler, task_id);

         -- if the EXTI line is configured as lockable by the kernel, the
         -- EXTI line is disabled here, and must be unabled later by the
         -- userspace using gpio_unlock_exti(). This permit to support
         -- external devices that generates regular EXTI events which are
         -- not correctly filtered
         if gpio_config.exti_lock = ewok.exported.gpios.GPIO_EXTI_LOCKED then
            ewok.exti.disable(ref);
         end if;
      end if;

   end handle_line;


   procedure exti_handler
     (frame_a : in ewok.t_stack_frame_access)
   is
      pragma unreferenced (frame_a);
      intr  : soc.interrupts.t_interrupt;
      ok    : boolean;
   begin

      intr := soc.interrupts.get_interrupt;

      case intr is
         when soc.interrupts.INT_EXTI0 =>
            handle_line (0, intr);

         when soc.interrupts.INT_EXTI1 =>
            handle_line (1, intr);

         when soc.interrupts.INT_EXTI2 =>
            handle_line (2, intr);

         when soc.interrupts.INT_EXTI3 =>
            handle_line (3, intr);

         when soc.interrupts.INT_EXTI4 =>
            handle_line (4, intr);

         when soc.interrupts.INT_EXTI9_5     =>

            for line in t_exti_line_index range 5 .. 9 loop
               soc.exti.is_line_pending (line, ok);
               if ok then
                  handle_line (line, intr);
               end if;
            end loop;

         when soc.interrupts.INT_EXTI15_10   =>

            for line in t_exti_line_index range 10 .. 15 loop
               soc.exti.is_line_pending (line, ok);
               if ok then
                  handle_line (line, intr);
               end if;
            end loop;

         when others => raise program_error;
      end case;

   end exti_handler;

end ewok.exti.handler;
