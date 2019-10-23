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

with ewok.tasks;        use ewok.tasks;
with ewok.tasks_shared;
with ewok.devices;
with ewok.mpu.allocator;
with ewok.exti;
with ewok.interrupts;
with ewok.gpio;
with ewok.dma;
with soc.rcc;
with soc.exti;
with soc.nvic;
with soc.syscfg;
with m4.mpu;
with m4.scb;
with applications;

package ewok.syscalls.init
   with spark_mode => on
is

   procedure svc_register_device
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (in_out =>
              (tasks_list,
               ewok.devices.registered_device,
               ewok.exti.exti_line_registered,
               ewok.interrupts.interrupt_table,
               ewok.mpu.allocator.regions_pool,
               ewok.gpio.gpio_points,
               m4.mpu.MPU,
               soc.exti.EXTI,
               soc.syscfg.syscfg));

   procedure svc_init_done
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      mode        : in  ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input => ewok.dma.registered_dma,
            in_out =>
              (tasks_list,
               ewok.devices.registered_device,
               m4.scb.SCB,
               soc.rcc.RCC,
               soc.exti.EXTI,
               soc.nvic.NVIC));

   procedure svc_get_taskid
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global => (in_out => tasks_list);

end ewok.syscalls.init;
