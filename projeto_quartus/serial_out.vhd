library ieee;
use ieee.numeric_bit.all;

entity serial_out is
    generic(
        POLARITY: boolean := TRUE;
        WIDTH: natural := 8; -- era 7
        PARITY: natural := 1;
        STOP_BITS: natural := 1
    );
    port(
        clock, reset, tx_go: in bit;
        tx_done: out bit;
        data: in bit_vector(WIDTH-1 downto 0);
        serial_o: out bit
    ) ;
end serial_out;

architecture arch of serial_out is

    type estado_t is (R, S, T0, T1, P0, P1, D, E); --Rest, Start, Transmission, Parity, Delay, End
    signal PE : estado_t;
    signal EA : estado_t := R; --R estado inicial da FSM

    signal b, fim, par, delay : bit;
    --signal fim_nat : natural;
    --signal data_s : bit_vector(WIDTH-1 downto 0) := (others => '0'); --default

    component contador6B is -- logica decrescente, porem com saida crescente (vector das saidas inversoras)
        port(
            clk, reset_c : in bit;
            step : out bit_vector(5 downto 0); -- para o banco de registradores
            done : out bit  -- 1 apenas quando contagem termina
        );
    end component;

    signal contador_step : bit_vector(5 downto 0);
    --signal currentStep : integer;
    signal reset_c : bit; --ativa em baixo


begin

    xContador6B : contador6B port map(clock, reset_c, contador_step, open);

    sincrono : process(clock, reset)
    begin
        if (reset = '1') then EA <= R;
        elsif (clock'event and clock = '1') then EA <= PE;
        end if;
    end process sincrono;

    PE <= R when  (tx_go = '0' and EA = R) else
          S  when ((tx_go = '1' and EA = R) or (tx_go = '1' and EA = E)) else
          T0 when ((b = '0' and EA = S) or (b = '0' and fim = '0' and EA = T0) or (b = '0' and fim = '0' and EA = T1)) else
          T1 when ((b = '1' and EA = S) or (b = '1' and fim = '0' and EA = T0) or (b = '1' and fim = '0' and EA = T1)) else
          P0 when ((par = '0' and fim = '1' and EA = T0) or (par = '0' and fim = '1' and EA = T1)) else
          P1 when ((par = '1' and fim = '1' and EA = T1) or (par = '1' and fim = '1' and EA = T0)) else
          D  when ((EA = P0) or (EA = P1) or (delay = '1' and EA = D)) else
          E  when ((delay = '0' and EA = D) or (tx_go = '0' and EA = E));
    
    with EA select
    tx_done <= '1' when D|E,
               '0' when others;

    with EA select
    serial_o <= '1' when R|T1|P1|D|E,
                '0' when others;

    with EA select
    reset_c <= '0' when P0|P1|S,
               '1' when others;

    bProc : process(contador_step, reset_c) 
    begin
        for i in 0 to WIDTH loop
        	if reset_c = '0' then b <= data(0); --passo -1 do clock
            elsif to_integer(unsigned(contador_step)) + 1 = i then
                if i < data'length then
                	b <= data(i);
                end if;
            end if;
        end loop;
    end process bProc;
        
    --currentStep <= to_integer(unsigned(contador_step));
    --b <= data(currentStep mod WIDTH);

    delayProc : process(reset_c)
    begin
        if reset_c = '1' then delay <= '0';
        else delay <= '1';
        end if;
    end process delayProc;

    --with currentStep select
    --delay <= '0' when 3,
    --         '1' when others;

    fimProc : process(contador_step)
    begin
        if to_integer(unsigned(contador_step)) + 1 = WIDTH then
            fim <= '1';
        else fim <= '0';
        end if;
    end process fimProc;

    -- fim_nat <= WIDTH - currentStep;
    -- with fim_nat select
    -- fim <= '1' when 0,
    --        '0' when others;

    parProc : process(data)
        
        variable paridadeBit : bit;
        
    begin
        paridadeBit := '0';
        L_Parity : for k in 0 to data'length - 1 loop
            paridadeBit := paridadeBit xor data(k);
        end loop L_Parity;
        
        par <= not(paridadeBit); --paridade impar
    end process parProc;
end arch;

entity contador6B is -- logica decrescente, porem com saida crescente (vector das saidas inversoras)
    port(
        clk, reset_c : in bit;
        step : out bit_vector(5 downto 0); -- para o banco de registradores
        done : out bit  -- 1 apenas quando contagem termina
    );
    end contador6B;
    
    architecture estrutural of contador6B is
    
        component flipflopD is
            port(
                D, clk, reset : in  bit; -- set e reset ativos em baixo
                Q, Q_L        : out bit
            );
            end component;
        
        signal Q_s   : bit_vector(5 downto 0);
        signal Q_L_s : bit_vector(5 downto 0);
    
    begin
    
        xFFD_0 : flipflopD port map(Q_L_s(0), clk     , reset_c, Q_s(0), Q_L_s(0));
        xFFD_1 : flipflopD port map(Q_L_s(1), Q_L_s(0), reset_c, Q_s(1), Q_L_s(1));
        xFFD_2 : flipflopD port map(Q_L_s(2), Q_L_s(1), reset_c, Q_s(2), Q_L_s(2)); 
        xFFD_3 : flipflopD port map(Q_L_s(3), Q_L_s(2), reset_c, Q_s(3), Q_L_s(3));
        xFFD_4 : flipflopD port map(Q_L_s(4), Q_L_s(3), reset_c, Q_s(4), Q_L_s(4));
        xFFD_5 : flipflopD port map(Q_L_s(5), Q_L_s(4), reset_c, Q_s(5), Q_L_s(5));
    
        step <= Q_s;
        done <= Q_s(5) and Q_s(4) and Q_s(3) and Q_s(2) and Q_s(1) and Q_s(0); 
    
    end estrutural;
    
entity flipflopD is
port(
    D, clk, reset : in  bit;
    Q, Q_L        : out bit
);
end flipflopD;

architecture arch of flipflopD is

    signal qi : bit;

begin

    process(clk, reset)
    begin
        if reset = '0' then qi <= '0'; -- assíncrono, reset baixo
        elsif (clk'event and clk = '1') then -- borda de subida do clock
            qi <= D; 
        end if;
    end process;

    Q <= qi;
    Q_L <= not qi;

end arch;