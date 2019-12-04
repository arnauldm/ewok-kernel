with ewok.sched;
with ewok.debug;
with soc.usart;
with m4.scb;

package ewok.tasks.debug
   with spark_mode => on
is
   procedure crashdump
     (frame_a  : in  ewok.t_stack_frame_access)
      with
         global =>
#if CONFIG_KERNEL_SERIAL
           (input  =>
              (tasks_list,
               ewok.sched.current_task_id,
               ewok.debug.kernel_usart_id),
            in_out =>
              (m4.scb.SCB,
               soc.usart.USART1,
               soc.usart.UART4,
               soc.usart.USART6));
#else
           (input  =>
              (tasks_list,
               ewok.sched.current_task_id,
               ewok.interrupts.interrupt_table,
               ewok.devices.registered_device),
            in_out =>
              (m4.scb.SCB));
#end if;

end ewok.tasks.debug;
