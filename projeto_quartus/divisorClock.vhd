library IEEE;
use IEEE.numeric_bit.all;

entity divisorClock is
	generic (n : integer := 13; --numero de bits
			 m : integer := 5208 --valor do reset (5208*2 ondas de subida do clock para gerar o clock serial)
			 ); 
	port(
		clock : in bit;
		reset : in bit;
		passe : out bit_vector(n-1 downto 0);
		serialClock : out bit
	);
end entity;

architecture arch_divisorClock of divisorClock is

component contador_reset is
	generic(n : integer := 13; --indica o tamanho do contador(3 bits)
			m : integer := 5208 --valor de reset
	);
    port (
      clock, reset    :   in    bit;
      valor       :   out   bit_vector(n - 1 downto 0)
    );
end component;

signal valor : bit_vector(n-1 downto 0) := (others => '0'); -- para contar ate o valor 5208 e vindo da metade de 10416 usado na divisao por 50Mhz para dar 4800,3 bits/s
signal enable : bit := '0';
signal q : bit := '0';
signal c_inverso : bit := '0';

begin	
	
	c_inverso <= not clock;
	c : contador_reset generic map(n,m) port map(C_inverso,reset,valor);
	passe <= valor;
	
	enable <= '1' when unsigned(valor) = (m-1) else
			    '0';
	
	process(clock)
	begin
		if enable = '1' then
			if (rising_edge(clock)) then
				q <= not q;
			end if;
		end if;
	end process;

	serialClock <= q;

end architecture;





