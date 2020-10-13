
package soc.usart.interfaces
   with spark_mode => on
is

   type t_usart_id is (ID_USART1, ID_UART4, ID_USART6);

   type t_parity_bit is (PARITY_BIT_NONE, PARITY_BIT_EVEN, PARITY_BIT_ODD);

   procedure configure
     (usart_id : in  t_usart_id;
      baudrate : in  unsigned_32;
      data_len : in  t_data_len;
      parity   : in  t_parity_bit;
      stop     : in  t_stop_bits;
      success  : out boolean)
      with
         pre => (baudrate >= 2400 and baudrate <= 115_200);

   procedure transmit
     (usart_id : in  t_usart_id;
      data     : in  bits_9);

end soc.usart.interfaces;
