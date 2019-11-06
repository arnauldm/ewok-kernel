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


with applications;      use applications; -- generated
with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.tasks;
with ewok.devices_shared;
with ewok.devices;
with ewok.mpu;
with ewok.mpu.allocator;
with m4.mpu;
with soc.devmap; use type soc.devmap.t_periph_id;

#if CONFIG_KERNEL_SERIAL
with ewok.debug;
with soc.usart;
#end if;

package ewok.memory
   with spark_mode => on
is

   -- Initialize the memory backend
   procedure init
     (success : out boolean);

   -- Map task's code and data sections
   procedure map_code_and_data
     (id : in  t_real_task_id)
      with
         inline,
         global => (input  => ewok.tasks.tasks_list,
                    in_out => (m4.mpu.MPU));

   -- Unmap the overall userspace content
   procedure unmap_user_code_and_data
      with inline;

   -- Return true if there is enough space in memory
   -- to map another element to the currently scheduled task
   function device_can_be_mapped return boolean
      with inline;

   -- Map/unmap a device into memory
   procedure map_device
     (dev_id   : in  ewok.devices_shared.t_registered_device_id;
      success  : out boolean)
      with
         pre =>
            ewok.devices.registered_device(dev_id).periph_id
               /= soc.devmap.NO_PERIPH;

   procedure unmap_device
     (dev_id   : in  ewok.devices_shared.t_registered_device_id)
      with inline;

   procedure unmap_all_devices
      with
         inline,
         global => (in_out => m4.mpu.MPU,
                    output => ewok.mpu.allocator.regions_pool);

   -- Map the whole task (code, data and related devices) in memory
   procedure map_task (id : in t_task_id)
      with
         inline,
#if CONFIG_KERNEL_SERIAL
         pre    => id in applications.t_real_task_id'range or
                   id = ID_SOFTIRQ or
                   id = ID_KERNEL,
         global => (input  => (ewok.tasks.tasks_list,
                               ewok.devices.registered_device,
                               ewok.debug.kernel_usart_id),
                    in_out => (m4.mpu.MPU,
                               soc.usart.USART1,
                               soc.usart.UART4,
                               soc.usart.USART6),
                    output => ewok.mpu.allocator.regions_pool);
#else
         pre    => id in applications.t_real_task_id'range or
                   id = ID_SOFTIRQ or
                   id = ID_KERNEL,
         global => (input  => (ewok.tasks.tasks_list,
                               ewok.devices.registered_device),
                    in_out => (m4.mpu.MPU,
                               m4.scb.SCB),
                    output => ewok.mpu.allocator.regions_pool);
#end if;

end ewok.memory;
