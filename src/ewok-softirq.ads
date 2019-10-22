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


with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.tasks;
with ewok.interrupts;
with ewok.devices;
with ewok.debug;
with soc.interrupts;
with m4.scb;
with soc.usart;
with rings;

package ewok.softirq
  with spark_mode => on
is

   type t_isr_parameters is record
      handler         : system_address             := 0;
      interrupt       : soc.interrupts.t_interrupt := soc.interrupts.INT_NONE;
      posthook_status : unsigned_32                := 0;
      posthook_data   : unsigned_32                := 0;
   end record;

   type t_isr_request is record
      caller_id   : ewok.tasks_shared.t_task_id    := ID_UNUSED;
      params      : t_isr_parameters               := (others => <>);
   end record;

   -- softirq input queue depth. Can be configured depending
   -- on the devices behavior (IRQ bursts)
   -- defaulting to 20 (see Kconfig)
   MAX_QUEUE_SIZE : constant := $CONFIG_KERNEL_SOFTIRQ_QUEUE_DEPTH;

   previous_isr_owner : t_task_id := ID_UNUSED;

   package p_isr_requests is new rings
     (t_isr_request, MAX_QUEUE_SIZE, t_isr_request'(others => <>));
   use p_isr_requests;

   isr_queue      : p_isr_requests.ring;

   procedure init;

   procedure push_isr
     (task_id     : in  ewok.tasks_shared.t_task_id;
      params      : in  t_isr_parameters);

   procedure isr_handler (req : in  t_isr_request)
      with
         global =>
           (input  =>
              (ewok.interrupts.interrupt_table,
               ewok.devices.registered_device),
            in_out =>
              (ewok.tasks.tasks_list,
               previous_isr_owner));

   procedure main_task
      with
         global =>
           (input  =>
              (ewok.interrupts.interrupt_table,
               ewok.devices.registered_device,
               ewok.debug.kernel_usart_id),
            in_out =>
              (ewok.tasks.tasks_list,
               isr_queue,
               previous_isr_owner,
               m4.scb.SCB,
               soc.usart.usart1,
               soc.usart.uart4,
               soc.usart.usart6));

end ewok.softirq;
