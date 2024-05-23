library IEEE;
use IEEE.numeric_bit.all;

--formato carry ripple adder

entity somador is
  generic(n : integer := 8); -- Quantidade de bits das entradas e saída
  port (
    -- Entrdas
    a, b        :   in  bit_vector(n - 1 downto 0);
    carry_in    :   in  bit;

    -- Saídas
    s           :   out bit_vector(n - 1 downto 0);
    carry_out   :   out bit
  );
end entity;

architecture arch_somador of somador is

signal c : bit_vector(n downto 0);

begin
	c(0) <= carry_in;
	gen : for j in 0 to (n - 1) generate
		 s(j) <= a(j) xor b(j) xor c(j);
		 c(j+1) <= (a(j) and b(j)) or (a(j) and c(j)) or (b(j) and c(j));
	end generate gen ;
	
	carry_out <= c(n);

end architecture;