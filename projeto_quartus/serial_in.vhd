library ieee;
use ieee.NUMERIC_BIT.all;

entity serial_in is
	generic (
	POLARITY: boolean := TRUE;
	WIDTH: natural := 8 ;
	PARITY: natural := 1 ;
	CLOCK_MUL: positive := 4
	);

	port (
		 clock, reset, serial_data: in bit;
		 done, parity_bit: out bit;
		 parallel_data: out bit_vector(WIDTH - 1 downto 0)
	);
	end serial_in;


architecture behavioral of serial_in is
    type state_t is (idle_s, start_bit_s, data_bits_s, parity_s, stop_bit_s);
    signal curr_state_r: state_t := idle_s;

    signal rx_data_sample_r: bit := '0';
    signal rx_data_r: bit := '0';

    signal clk_count_r: unsigned(1 downto 0) := "00";
    signal bit_index_r: integer range 0 to 7 := 0;
    signal rx_parallel_data_r: bit_vector(7 downto 0) := (others => '0');
    signal done_r: bit := '0';
 
begin

sample_p : process (clock)
begin
    if rising_edge(clock) then
        rx_data_sample_r <= serial_data;
        rx_data_r   <= rx_data_sample_r;
    end if;
end process sample_p;

clk_proc : process(clock,curr_state_r)
begin
	if rising_edge(clock) then
		if curr_state_r = idle_s then
			clk_count_r <= "00";
		else
			clk_count_r <= clk_count_r + 1;
		end if;
	end if;
end process;

uart_rx_p : process (clock)
begin
    if rising_edge(clock) then
        if reset = '1' then
            curr_state_r <= idle_s;
        else 
            case curr_state_r is
    
            -- valor inicial 
                when idle_s =>
                    done_r <= '0';
                    bit_index_r <= 0;
            
                    if rx_data_r = '0' then        -- se start bit é detectado
                        curr_state_r <= start_bit_s; -- vai para o proximo estado
                    end if;
                -- verifica se o start bit continua em baixo
                when start_bit_s =>
                    if clk_count_r = 2 then  
                        if rx_data_r = '0' then                   -- se o start bit continuar em zero                     -- vai para o proximo estado 
                            curr_state_r <= data_bits_s;
                        else
                            curr_state_r <= idle_s;
                        end if;
                    end if;
        
                
                -- espera 4 ciclos de clock para coletar o dado serial
                when data_bits_s =>
                    if clk_count_r = 2 then
                        rx_parallel_data_r(bit_index_r) <= rx_data_r;  -- grava bit recebido no vetor de dados
                        
                        -- verifica se ja recebeu todos os 8 bits de dados
                        -- caso sim, pula para o proximo estado
                        if bit_index_r < 7 then
                            bit_index_r <= bit_index_r + 1;
                        else
                            bit_index_r <= 0;
                            curr_state_r <= parity_s;
                        end if;
                    end if;
        

                when parity_s =>
                    -- aguarda 4 ciclos de clock para o fim do parity bit
                    if clk_count_r = 2 then
								parity_bit <= rx_data_r;
                        curr_state_r <= stop_bit_s;
                    end if;
        
                -- Recebe os stop bits.  Stop bit = 1
                when stop_bit_s =>
                    -- sinaliza done_r como alto e pula para o proximo estado
                    if clk_count_r = 2 then
                        done_r     <= '1';
                        curr_state_r   <= idle_s;
                    end if;
            end case;
        end if;
    end if;
end process uart_rx_p;
 
done <= done_r;
parallel_data <= rx_parallel_data_r;
 
end behavioral;