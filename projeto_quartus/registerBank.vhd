library ieee;
use ieee.numeric_bit.all;

entity registerBank is
generic(
    SIZE : natural := 8;  -- bit paridade + palavra 8b
    LENGTH : natural := 32 -- posicoes do banco
);
port(
    clock, reset , RW : in bit; -- Read 1 Write 0
    serial_in : in bit_vector(SIZE-1 downto 0);
    data_out : out bit_vector(SIZE-1 downto 0);
    endereco : in natural;
    full : out bit
);
end registerBank;

architecture behavioral of registerBank is

    type bench is array (natural range<>) of bit_vector(SIZE-1 downto 0);
    signal adress : bench(0 to LENGTH-1);

    signal elementos : natural := 0;
    signal index : natural := 0;
    signal full_s : bit := '0';
	 
	 signal temp : bit_vector(SIZE-1 downto 0);

begin
	
	temp <= (others =>'0');

    storageProc : process(clock, reset)
    begin

        if (reset = '1') then 
            elementos <= 0;
            full_s <= '0';
            index <= 0;
            adress <= (others => temp);
        elsif rising_edge(clock) and RW = '0' then

            adress(index) <= serial_in; 

            if index = LENGTH-1 and elementos = SIZE-1 then --SIZE-1 porque elementos so atualiza no final da execucao do process
                full_s <= '1';
            else
                full_s <= '0';
                if elementos = SIZE-1 and index < LENGTH-1 then 
                    index <= index + 1; --SIZE-1 porque elementos so atualiza no final da execucao do process
                    elementos <= 0;
                elsif elementos < SIZE then
                    elementos <= elementos + 1;
                end if;
            end if;
        
        

        end if;
    end process storageProc;

    data_out <= adress(index);
    full <= full_s;

end behavioral;
