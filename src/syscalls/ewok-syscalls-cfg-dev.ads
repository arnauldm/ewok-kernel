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
with ewok.tasks;        use ewok.tasks;
with ewok.devices;
with ewok.gpio;
with ewok.exti;
with ewok.mpu.allocator;
with ewok.interrupts;
with applications;
with m4.mpu;
with soc.rcc;
with soc.exti;
with soc.nvic;

package ewok.syscalls.cfg.dev
   with spark_mode => on
is

   procedure svc_dev_map
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in out t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (in_out =>
              (tasks_list,
               ewok.devices.registered_device,
               m4.mpu.MPU,
               soc.rcc.RCC,
               soc.exti.EXTI,
               soc.nvic.NVIC,
               ewok.mpu.allocator.regions_pool));

   procedure svc_dev_unmap
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in out t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
               ewok.devices.registered_device,
            in_out =>
              (tasks_list,
               m4.mpu.MPU,
               ewok.mpu.allocator.regions_pool));

   procedure svc_dev_release
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in out t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre =>
#if SPARK
            caller_id in applications.t_real_task_id and then
           (ewok.tasks.tasks_list(caller_id).num_devs =
               ewok.tasks.count_used (ewok.tasks.tasks_list(caller_id).devices)),
#else
            caller_id in applications.t_real_task_id,
#end if;
         global =>
           (in_out =>
              (tasks_list,
               ewok.devices.registered_device,
               m4.mpu.MPU,
               soc.exti.EXTI,
               ewok.gpio.gpio_points,
               ewok.interrupts.interrupt_table,
               ewok.exti.exti_line_registered,
               ewok.mpu.allocator.regions_pool));


end ewok.syscalls.cfg.dev;
