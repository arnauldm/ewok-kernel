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

with ada.unchecked_conversion;
with soc.interrupts;
with ewok.tasks_shared;
with ewok.devices_shared;

package ewok.interrupts
   with spark_mode => on
is

   type t_handler_type is (DEFAULT_HANDLER, TASK_SWITCH_HANDLER);

   type t_interrupt_cell is record
      task_id        : ewok.tasks_shared.t_task_id;
      device_id      : ewok.devices_shared.t_device_id;
      handler        : system_address;
      handler_type   : t_handler_type;
   end record;

   interrupt_table :
      array (soc.interrupts.t_interrupt) of t_interrupt_cell :=
        (others =>
           (task_id      => ewok.tasks_shared.ID_UNUSED,
            device_id    => ewok.devices_shared.ID_DEV_UNUSED,
            handler      => 0,
            handler_type => DEFAULT_HANDLER));


   function is_interrupt_already_used
     (interrupt : soc.interrupts.t_interrupt) return boolean;

   procedure set_interrupt_handler
     (interrupt      : in  soc.interrupts.t_interrupt;
      handler_type   : in  t_handler_type;
      handler        : in  system_address;
      task_id        : in  ewok.tasks_shared.t_task_id;
      device_id      : in  ewok.devices_shared.t_device_id)
      with pre => handler /= 0;

   procedure reset_interrupt_handler
     (interrupt   : in  soc.interrupts.t_interrupt;
      task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id);

   function get_device_from_interrupt
     (interrupt : soc.interrupts.t_interrupt)
      return ewok.devices_shared.t_device_id
      with inline_always;

end ewok.interrupts;
