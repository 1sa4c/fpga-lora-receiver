library IEEE;
use IEEE.numeric_bit.all;

entity registrador is
	generic(
		n	:	integer := 8						-- Data width
	);
	port(
		clock		:	in	bit;						-- Clock signal
		reset		:	in	bit;						-- Reset signal
		data	  	:	in	bit_vector(n - 1 downto 0);	-- input data
		q		    :	out	bit_vector(n - 1 downto 0)	-- output data
	);
end entity;

architecture arch_registrador of registrador is
begin
	
	process(reset, clock)
	begin
		-- Reset if rst = 0
		if reset = '1' then
			q <= (others => '0');
		elsif rising_edge(clock) then -- register data on rising edge of clk
			q <= data;
		end if;
	end process;
	
end architecture; 