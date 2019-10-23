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
with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.sched;
with ewok.exported.sleep; use ewok.exported.sleep;

package body ewok.syscalls.sleep
   with spark_mode => on
is

   package TSK renames ewok.tasks;

   procedure svc_sleep
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
      sleep_time : constant unsigned_32 := params(1);

      sleep_mode : constant t_sleep_mode
         with import, address => params(2)'address;
   begin

      if mode = TASK_MODE_ISRTHREAD then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      pragma warnings (off, "attribute Valid is assumed to return True");

      if not sleep_mode'valid then
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      if TSK.is_ipc_waiting (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_BUSY);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      ewok.sleep.do_sleeping (caller_id, milliseconds (sleep_time), sleep_mode);

      -- Note: state set by ewok.sleep.sleeping procedure
      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.sched.request_schedule;

   end svc_sleep;

end ewok.syscalls.sleep;

