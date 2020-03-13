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

with system;

with ewok.sanitize;
with ewok.debug;

package body ewok.syscalls.log
   with spark_mode => on
is

   procedure svc_log
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      params      : in  t_parameters;
      mode        : in  ewok.tasks_shared.t_task_mode)
   is
      -- Message size
      size  : positive
         with import, address => params(1)'address;

      -- Message address
      msg_address : constant system.address := to_address (params(2));

   begin

      if size >= 512 then
         ewok.tasks.set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      if not ewok.sanitize.is_range_in_data_slot
              (to_system_address (msg_address),
               unsigned_32 (size),
               caller_id,
               mode)
      then
         ewok.tasks.set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      declare
         -- Message
         msg_size : constant positive := size;
         msg      : string (1 .. msg_size)
            with address => msg_address;
      begin
         pragma DEBUG (debug.log
           (ewok.tasks.tasks_list(caller_id).name & " " & msg & ASCII.CR,
            false));
      end;

      ewok.tasks.set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_log;


end ewok.syscalls.log;
