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

package body ewok.interrupts
   with spark_mode => on
is

   function is_interrupt_already_used
     (interrupt : soc.interrupts.t_interrupt) return boolean
   is
   begin
      return interrupt_table(interrupt).task_id /= ewok.tasks_shared.ID_UNUSED;
   end is_interrupt_already_used;


   procedure set_interrupt_handler
     (interrupt      : in  soc.interrupts.t_interrupt;
      handler_type   : in  t_handler_type;
      handler        : in  system_address;
      task_id        : in  ewok.tasks_shared.t_task_id;
      device_id      : in  ewok.devices_shared.t_device_id)
   is
   begin
      interrupt_table(interrupt) :=
        (task_id, device_id, handler, handler_type);
   end set_interrupt_handler;


   procedure reset_interrupt_handler
     (interrupt   : in  soc.interrupts.t_interrupt;
      task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id)
   is
   begin

      if interrupt_table(interrupt).task_id   /= task_id   or
         interrupt_table(interrupt).device_id /= device_id
      then
         raise program_error;
      end if;

      interrupt_table(interrupt).handler        := 0;
      interrupt_table(interrupt).handler_type   := DEFAULT_HANDLER;
      interrupt_table(interrupt).task_id        := ID_UNUSED;
      interrupt_table(interrupt).device_id      := ID_DEV_UNUSED;

   end reset_interrupt_handler;


   function get_device_from_interrupt
     (interrupt : soc.interrupts.t_interrupt)
      return ewok.devices_shared.t_device_id
   is
   begin
      return interrupt_table(interrupt).device_id;
   end get_device_from_interrupt;


end ewok.interrupts;
