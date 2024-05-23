library ieee;
use ieee.numeric_bit.all;

entity projeto_Radio_Transmissao is
port(
	CLOCK_50  : in bit;
	GPIO_0_D0 : in bit;
	GPIO_0_D1 : out bit;
	GPIO_0_D2 : in bit -- reset
);
end projeto_Radio_Transmissao;

architecture estrutural of projeto_Radio_Transmissao is
	
	component serial_in is
	generic(
		POLARITY : boolean := TRUE;
		WIDTH : natural := 8 ;
		PARITY : natural := 1 ;
		CLOCK_MUL: positive := 4
	);
	port(
		clock, reset, serial_data : in bit;
		done , parity_bit : out bit;
		parallel_data : out bit_vector(WIDTH-1 downto 0)
	);
	end component;

	component serial_out is
	generic(
        POLARITY: boolean := TRUE;
        WIDTH: natural := 8; --era 7
        PARITY: natural := 1;
        STOP_BITS: natural := 1
    );
    port(
        clock, reset, tx_go: in bit;
        tx_done: out bit;
        data: in bit_vector(WIDTH-1 downto 0);
        serial_o: out bit
    );
	end component;

	component divisorClock is
	generic (n : integer := 13; --numero de bits
				m : integer := 5208 --valor do reset (5208*2 ondas de subida do clock para gerar o clock serial)
				); 
	port(
		clock : in bit;
		reset : in bit;
		passe : out bit_vector(n-1 downto 0);
		serialClock : out bit
	);
	end component;

	component registerBank is
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
	end component;

	--TOP LEVEL
	signal clock : bit;
	signal reset : bit;
	signal serial_data_in : bit;
	signal serial_data_out : bit;

	--COMUNICACAO
	signal clock_si, reset_si, serial_data_si : bit;
	signal done_si , parity_bit_si : bit;
	signal parallel_data_si : bit_vector(7 downto 0); -- 1 byte + paridade

	signal clock_so, reset_so, tx_go_so : bit;
    signal tx_done_so : bit;
    signal data_so : bit_vector(7 downto 0); -- 1 byte + paridade
    signal serial_o_so : bit;

	--DIVISOR 9600
	signal clock_divisor9600 : bit;
	signal reset_divisor9600 : bit;
	signal serialClock_divisor9600 : bit;

	--DIVISOR 19200
	signal clock_divisor38400 : bit;
	signal reset_divisor38400 : bit;
	signal serialClock_divisor38400 : bit;

	-- REGISTER BANK
	signal clock_rb, reset_rb, RW_rb : bit; -- Read 1 Write 0
	signal serial_in_rb : bit_vector(7 downto 0);
	signal data_out_rb : bit_vector(7 downto 0);
	signal endereco_rb : natural;
	signal full_rb : bit;

	--MAQUINA DE ESTADOS
	type state is (I, RX, S, TX, P, D);
	signal EA : state := I;
	signal PE : state;
	
	signal recomecar, receba, armazene, transmita, proximo, pronto : bit := '0';
	signal contadorLeitura : natural := 0;
	signal contadorEscrita : natural := 0;

begin

-- MAPEAMENTO

	--COMUNICACAO
	xSerial_in : serial_in port map(clock_si, reset_si, serial_data_si,
											  done_si, parity_bit_si,
											  parallel_data_si);

	xSerial_out : serial_out port map(clock_so, reset_so, tx_go_so,
												 tx_done_so,
												 data_so,
												 serial_o_so);

	--DIVISORES
	xDivisorClock4800 : divisorClock port map(clock_divisor9600,
											  reset_divisor9600,
											  open,
											  serialClock_divisor9600);
	
	xDivisorClock19200 : divisorClock port map(clock_divisor38400,
											   reset_divisor38400,
											   open,
											   serialClock_divisor38400);
	
	--REGISTER BANK
	xShiftRegister_generic : registerBank port map(clock_rb, reset_rb, RW_rb,
												   serial_in_rb,
												   data_out_rb,
												   endereco_rb,
												   full_rb);

--CONEXOES

	-- TOP LEVEL
	clock <= CLOCK_50;
	reset <= GPIO_0_D2;
	serial_data_in <= GPIO_0_D0;
	GPIO_0_D1 <= serial_data_out;
	
	-- DIVISOR 9600
	clock_divisor9600 <= CLOCK_50;
	reset_divisor9600 <= reset;

	-- DIVISOR 38400
	clock_divisor38400 <= CLOCK_50;
	reset_divisor38400 <= reset;

	-- SERIAL IN
	clock_si <= serialClock_divisor38400;
	reset_si <= reset;
	-- start_si
	serial_data_si <= serial_data_in;

	-- REGISTER BANK
	clock_rb <= serialClock_divisor38400;
	reset_rb <= reset;
	-- RW_rb
	serial_in_rb <= parallel_data_si;
	-- endereco_rb

	-- SERIAL OUT
	clock_so <= serialClock_divisor9600;
	reset_so <= reset;
	-- tx_go_so
	data_so <= data_out_rb;
	serial_data_out <= serial_o_so;

-- MAQUINA DE ESTADOS
	
	-- FLUXO DE ESTADOS

	FSM : process(serialClock_divisor38400, reset)
	begin
		if (reset = '1') then
			EA <= I;
		elsif (rising_edge(serialClock_divisor38400)) then
			EA <= PE;
		end if;
	end process FSM;

	PE <= I when EA = D and recomecar = '1' else
		  RX when EA = I and receba = '1'else
		  S when EA = RX and armazene = '1' else
		  TX when EA = RX and transmita = '1' else
		  P when EA = TX and proximo = '1' else
		  D when EA = TX and pronto = '1';
	
	-- FUNCOES DOS SINAIS DE CONTROLE
	
	restart : process(serialClock_divisor38400, reset, serial_data_in, EA)
	begin
		if (reset = '1') then
			recomecar <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = D) then	-- fica apenas um ciclo no estado de Done
				recomecar <= '1';
			else
				recomecar <= '0';
			end if;
		end if;
	end process restart;

	receive : process(serialClock_divisor38400, reset, serial_data_in, EA)
	begin
		if (reset = '1') then
			receba <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = I and serial_data_in = '0') or (EA = S) then-- assumindo start bit em baixo, e so fica 1 clock em Store
				receba <= '1';
			else
				receba <= '0';
			end if;
		end if;
	end process receive;

	store : process(serialClock_divisor38400, reset, done_si, EA)
	begin
		if (reset = '1') then
			armazene <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = RX and done_si = '1') then -- recepcao de 1 byte concluida
				armazene <= '1';
			else
				armazene <= '0';
			end if;
		end if;
	end process store;

	transmit : process(serialClock_divisor38400, reset, full_rb, EA)
	begin
		if (reset = '1') then
			transmita <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = RX and full_rb = '1') or (EA = P) then -- fica apenas 1 clock em Proximo
				transmita <= '1';
			else 
				transmita <= '0';
			end if;
		end if;
	end process transmit;

	following : process(serialClock_divisor38400, reset, tx_done_so, EA)
	begin
		if (reset = '1') then
			proximo <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = TX and tx_done_so = '1') then -- recepcao de 1 byte concluida
				proximo <= '1';
			else
				proximo <= '0';
			end if;
		end if;
	end process following;

	contagemLeitura : process(serialClock_divisor38400, reset, done_si, EA)
	begin
		if(reset = '1') then
			contadorLeitura <= 0;
		elsif(rising_edge(serialClock_divisor38400)) then
			if(EA = RX and done_si = '1') then
				if (contadorLeitura < 32) then -- apenas para evitar overflow
					contadorLeitura <= contadorLeitura + 1;
				end if;
			else
				contadorLeitura <= 0;
			end if;
		end if;
	end process contagemLeitura;

	contagemEscrita : process(serialClock_divisor38400, reset, tx_done_so, EA)
	begin
		if(reset = '1') then
			contadorEscrita <= 0;
		elsif(rising_edge(serialClock_divisor38400)) then
			if(EA = TX and tx_done_so = '1') then
				if (contadorEscrita < 32) then -- apenas para evitar overflow
					contadorEscrita <= contadorEscrita + 1;
				end if;
			else
				contadorEscrita <= 0;
			end if;
		end if;
	end process contagemEscrita;

	ready : process(serialClock_divisor38400, reset, serial_data_in, EA)
	begin
		if (reset = '1') then
			pronto <= '0';
		elsif(rising_edge(serialClock_divisor38400)) then
			if (EA = TX and contadorEscrita = 32) then
				pronto <= '1';
			else 
				pronto <= '0';
			end if;
		end if;
	end process ready;

	-- FUNCOES DOS SINAIS DE EXCITACAO
	
	with EA select
	RW_rb <= '0' when S, -- write
			 '1' when others; --read
	
	with EA select
	tx_go_so <= '1' when TX,
				'0' when others;
	
	with EA select
	endereco_rb <= contadorLeitura when RX|S,
						contadorEscrita when TX|P,
						0 when others;
	
end estrutural;


	