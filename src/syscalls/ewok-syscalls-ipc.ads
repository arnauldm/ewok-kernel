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


with ewok.tasks;
with ewok.tasks_shared;
with ewok.sleep;
with ewok.ipc;
with applications;
with m4.mpu;
with m4.systick;


package ewok.syscalls.ipc
   with spark_mode => on
is

   procedure svc_ipc_do_recv
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      blocking    : in boolean;
      mode        : in ewok.tasks_shared.t_task_mode)
   with
      pre => caller_id in applications.t_real_task_id,
      global =>
        (in_out => (ewok.tasks.tasks_list,
                    ewok.ipc.ipc_endpoints,
                    m4.mpu.MPU));

   procedure svc_ipc_do_send
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      blocking    : in boolean;
      mode        : in ewok.tasks_shared.t_task_mode)
   with
      pre => caller_id in applications.t_real_task_id,
      global =>
        (input  => (ewok.sleep.awakening_time,
                    m4.systick.ticks),
         in_out => (ewok.tasks.tasks_list,
                    ewok.ipc.ipc_endpoints,
                    m4.mpu.MPU));

end ewok.syscalls.ipc;
