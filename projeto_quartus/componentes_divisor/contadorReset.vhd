library IEEE;
use IEEE.numeric_bit.all;

entity contador_reset is
	generic(n : integer := 13; --indica o tamanho do contador(13)
			m : integer := 5208 --valor de reset (corresponde a metade da onda desejada, nesse caso a onda desejada tem periodo de 5208*2 vezes mais)
	);
    port (
      clock, reset    :   in    bit;
      valor       :   out   bit_vector(n - 1 downto 0)
    );
end entity;

architecture arch_contador_reset of contador_reset is

--somador

component somador is
  generic(n : integer := 8); -- Quantidade de bits das entradas e saída
  port (
    -- Entrdas
    a, b        :   in  bit_vector(n - 1 downto 0);
    carry_in    :   in  bit;

    -- Saídas
    s           :   out bit_vector(n - 1 downto 0);
    carry_out   :   out bit
  );
end component;


--registrador com enable

component registrador is
	generic(
		n	:	integer := 8						-- Data width
	);
	port(
		clock		:	in	bit;						-- Clock signal
		reset		:	in	bit;						-- Reset signal
		data	  	:	in	bit_vector(n - 1 downto 0);	-- input data
		q		    :	out	bit_vector(n - 1 downto 0)	-- output data
	);
end component;

   signal dado, valor_temp :   bit_vector(n-1 downto 0) := (others=> '0');
	signal reiniciar: bit := '0';

begin
	--Para esse caso o contador conta de 0 a 5207 e reseta em 5208.	
	--indicio de reset
	
	reiniciar <= '1' when ((unsigned(valor_temp) = m) or reset = '1') else
				 '0';

    -- Somador
	S: somador generic map(n)
	port map(valor_temp,(others=>'0'),'1',dado,open);
	
	--Registrador
    R: registrador generic map(n)  
    port map(clock,reiniciar,dado,valor_temp);
		
	valor <= valor_temp;
	 
end architecture;