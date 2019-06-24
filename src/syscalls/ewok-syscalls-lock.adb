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


package body ewok.syscalls.lock
   with spark_mode => off
is

   procedure svc_lock_enter
     (caller_id   : in ewok.tasks_shared.t_task_id;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
   begin
      if mode = TASK_MODE_ISRTHREAD then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         return;
      end if;
      set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_LOCKED);
   end svc_lock_enter;


   procedure svc_lock_exit
     (caller_id   : in ewok.tasks_shared.t_task_id;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
   begin
      if mode = TASK_MODE_ISRTHREAD then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         return;
      end if;
      set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
      -- When unlocking a task, it is highly probable that an ISR is
      -- waiting and need to be executed.
      ewok.sched.request_schedule;
   end svc_lock_exit;

end ewok.syscalls.lock;