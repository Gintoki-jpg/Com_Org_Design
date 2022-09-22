library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity controller_interrupt is
    port (
        --��λ�źţ��͵�ƽ��Ч
        CLR : in STD_LOGIC;
        --����ģʽ:��д�Ĵ���/RAM��ִ�г���
        SWA, SWB, SWC : in STD_LOGIC;
        --ָ��
        IR7, IR6, IR5, IR4 : in STD_LOGIC;
        --��������:W1(ʼ����Ч)��W2(��SHORT=TRUEʱ������)��W3(LONG=TUREʱ�Ž���)
        --T3��ÿ���������ڵ����һ��ʱ������
        W1, W2, W3, T3 : in STD_LOGIC;
        --��λ�����ʶ
        C, Z : in STD_LOGIC;
        --�жϱ�ʶ
        PULSE : in STD_LOGIC;
        --ALU����ģʽ
        S : out STD_LOGIC_VECTOR(3 downto 0);
        --SEL3-0��(3,2)ΪALU��˿�MUX���룬Ҳ�� DBUS2REGISTER ��Ƭѡ�ź�.(1,0)ΪALU�Ҷ˿�MUX����
        SEL_L, SEL_R : out STD_LOGIC_VECTOR(1 downto 0);
        --д�Ĵ���ʹ��
        DRW : out STD_LOGIC;
        --���Ĵ���ʹ��
        MEMW : out STD_LOGIC;
        --PCINC��PC������PCADD��+offset
        PCINC, PCADD : out STD_LOGIC;
        --дPC,AR,IR�ͱ�־�Ĵ���ʹ��
        LPC, LAR, LIR, LDZ, LDC : out STD_LOGIC;
        --AR����
        ARINC : out STD_LOGIC;
        --ֹͣ����ʱ���ź�
        STP : out STD_LOGIC;
        --�������̨ģʽ
        SELCTL : out STD_LOGIC;
        --74181��λ�����ź�
        CIN : out STD_LOGIC;
        --����ģʽ:M=0Ϊ�������㣻M=1Ϊ�߼�����
        M : out STD_LOGIC;
        --����ʹ��
        ABUS, SBUS, MBUS : out STD_LOGIC;
        --����ָ�������л�������������SHORT=TRUEʱW2��������LONG=TUREʱ�Ż����W3
        SHORT, LONG : out STD_LOGIC
    );
end controller_interrupt;

architecture struct of controller_interrupt is
    signal SW : STD_LOGIC_VECTOR(2 downto 0);
    signal IR : STD_LOGIC_VECTOR(3 downto 0);
    signal ST0, SST0 : STD_LOGIC;
    signal EN_INT, IS_INT : STD_LOGIC; --EN_INT: �ж������־, IS_INT: �Ƿ����ж��б�ʶ
    signal INT_FLAG, INT_FFLAG : STD_LOGIC_VECTOR(1 downto 0); --�ϵ㱣����ϵ�ָ��������ڱ�־
    signal RUN_SAVE, C_RUN_SAVE : STD_LOGIC; --����ϵ㱣������־
    signal RUN_RET, C_RUN_RET : STD_LOGIC; --����ϵ�ָ������־
begin
    SW <= SWC & SWB & SWA;
    IR <= IR7 & IR6 & IR5 & IR4;

    process (W3, W2, W1, T3, SW, IR, CLR, PULSE)
    begin

        S <= "0000";
        SEL_L <= "00";
        SEL_R <= "00";
        DRW <= '0';
        MEMW <= '0';
        PCINC <= '0';
        LPC <= '0';
        LAR <= '0';
        LIR <= '0';
        LDZ <= '0';
        LDC <= '0';
        ARINC <= '0';
        STP <= '0';
        PCADD <= '0';
        SELCTL <= '0';
        CIN <= '0';
        M <= '0';
        MEMW <= '0';
        ABUS <= '0';
        SBUS <= '0';
        MBUS <= '0';
        SHORT <= '0';
        LONG <= '0';

        if CLR = '0' then
            ST0 <= '0';
            SST0 <= '0';
            EN_INT <= '0';
            IS_INT <= '0';
            INT_FLAG <= "00";
            INT_FFLAG <= "00";
            RUN_SAVE <= '0';
            C_RUN_SAVE <= '0';
            RUN_RET <= '0';
            C_RUN_RET <= '0';
           
        elsif falling_edge(T3) then
            ST0 <= SST0;
            INT_FLAG <= INT_FFLAG;
            RUN_SAVE <= C_RUN_SAVE;
            RUN_RET <= C_RUN_RET;
        end if;
        
        if PULSE = '1' and EN_INT = '1' then
            IS_INT <= '1';
            STP <= '1';
        end if;
        
        case SW is
            when "001" => --д�洢��
                SBUS <= '1';
                STP <= '1';
                SHORT <= '1';
                SELCTL <= '1';
                LAR <= not ST0;
                MEMW <= ST0;
                ARINC <= ST0;
                if ST0 <= '0' then
                    SST0 <= '1';
                end if;
            when "010" => --���洢��   
                SHORT <= '1';
                STP <= '1';
                SELCTL <= '1';
                SBUS <= not ST0;
                LAR <= not ST0;
                MBUS <= ST0;
                ARINC <= ST0;
                if ST0 <= '0' then
                    SST0 <= '1';
                end if;
            when "011" => --д�Ĵ���
                SBUS <= '1';
                SEL_L(1) <= ST0; --SEL3
                SEL_L(0) <= W2; --SEL2
                SEL_R(1) <= (not ST0 and W1) or (ST0 and W2); --SEL1
                SEL_R(0) <= W1; --SEL0
                if ST0 <= '0' and W2 = '1' then
                    SST0 <= '1';
                end if;
                SELCTL <= '1';
                DRW <= '1';
                STP <= '1';
            when "100" => --���Ĵ���
                SEL_L(1) <= W2;
                SEL_L(0) <= '0';
                SEL_R(1) <= W2;
                SEL_R(0) <= '1';
                SELCTL <= '1';
                STP <= '1';
            when "000" => --ȡָ & �ж�
                if RUN_SAVE = '1' then --Save break point.
                    case INT_FLAG is
                        when "00" =>
                            STP <= '1';
                            SBUS <= W1;
                            LAR <= W1;
                            M <= W2;
                            S <= W2 & W2 & W2 & W2;
                            ABUS <= W2;
                            MEMW <= W2;
                            SELCTL <= W2;
                            SEL_L <= W2 & W2;
                            ARINC <= W2;
                            if W2 = '1' then
                                INT_FFLAG <= "01";
                            else
                                INT_FFLAG <= "00";
                            end if;
                        when "01" =>
                            LONG <= W2;
                            STP <= '1';
                            M <= W1 or W2 or W3;
                            S <= "1111";
                            ABUS <= '1';
                            MEMW <= '1';
                            SELCTL <= '1';
                            SEL_L <= W3 & W2;
                            ARINC <= '1';
                            if W3 = '1' then
                                INT_FFLAG <= "10";
                            end if;
                        when "10" =>
                            STP <= '1';
                            MBUS <= '1';
                            DRW <= W1;
                            SELCTL <= W1;
                            SEL_L <= W1 & W1;
                            LPC <= W2;
                            if W2 = '1' then
                                INT_FFLAG <= "00";
                                IS_INT <= '0';
                                C_RUN_SAVE <= '0';
                            end if;
                        when others => null;
                    end case;
                
                elsif RUN_RET = '1' then 
                    case INT_FLAG is
                        when "00" =>
                            C_RUN_RET <= '1';
                            STP <= '1';
                            M <= W1;
                            S <= W1 & W1 & W1 & W1;
                            ABUS <= W1;
                            SELCTL <= W1;
                            SEL_L <= W1 & W1;
                            LAR <= W1 or W2;
                            MBUS <= W2;
                            if W2 = '1' then
                                INT_FFLAG <= "01";
                            else
                                INT_FFLAG <= "00";
                            end if;
                        when "01" =>
                            C_RUN_RET <= '1';
                            STP <= '1';
                            MBUS <= W1 or W2;
                            DRW <= W1;
                            SELCTL <= W1;
                            SEL_L <= W1 & W1;
                            LPC <= W2;
                            ARINC <= W2;
                            if W2 = '1' then
                                INT_FFLAG <= "10";
                            else
                                INT_FFLAG <= "01";
                            end if;
                        when "10" =>
                            C_RUN_RET <= W1 or W2;
                            STP <= '1';
                            MBUS <= '1';
                            LONG <= '1';
                            DRW <= '1';
                            SELCTL <= '1';
                            SEL_L <= W3 & W2;
                            ARINC <= W1 or W2;
                            LIR <= W3;
                            PCINC <= W3;
                            if W3 = '1' then
                                EN_INT <= '1';
                                INT_FFLAG <= "00";
                                C_RUN_RET <= '0';
                            else
                                INT_FFLAG <= "10";
                            end if;
                        when others => null;
                    end case;
                    
                else
                    if ST0 = '0' then
                       
                        LPC <= W1;
                        SBUS <= W1 or W2;
                        STP <= W1 or W2;
                        DRW <= W2;
                        SELCTL <= W2;
                        SEL_L <= W2 & W2;
                        if ST0 <= '0' and W2 = '1'then
                            SST0 <= '1';
                        end if;
                    else
                     
                        if W1 = '1' then
                            S <= not W1 & not W1 & not W1 & not W1;
                            M <= not W1;
                            CIN <= not W1;
                            ABUS <= W1;
                            DRW <= W1;
                            SELCTL <= W1;
                            SEL_L <= W1 & W1;
                            LIR <= W1;
                            PCINC <= W1;
                        else
                          
                            case IR is
                                when "0000" => --NOP
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0001" => --ADD
                                    S <= W2 & not W2 & not W2 & W2;
                                    M <= not W2;
                                    CIN <= W2;
                                    ABUS <= W2;
                                    DRW <= W2;
                                    LDZ <= W2;
                                    LDC <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0010" => --SUB
                                    S <= not W2 & W2 & W2 & not W2;
                                    M <= W2;
                                    CIN <= W2;
                                    ABUS <= W2;
                                    DRW <= W2;
                                    LDZ <= W2;
                                    LDC <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0011" => --AND
                                    M <= W2;
                                    S <= W2 & not W2 & W2 & W2;
                                    ABUS <= W2;
                                    DRW <= W2;
                                    LDZ <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0100" => --INC
                                    S <= not W2 & not W2 & not W2 & not W2;
                                    M <= not W2;
                                    ABUS <= W2;
                                    CIN <= not W2;
                                    DRW <= W2;
                                    LDZ <= W2;
                                    LDC <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0101" => --LD
                                    LONG <= W2;
                                    S <= W2 & not W2 & W2 & not W2;
                                    M <= W2;
                                    ABUS <= W2;
                                    LAR <= W2;
                                    MBUS <= W3;
                                    DRW <= W3;
                                    if IS_INT = '1' and W3 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0110" => --ST
                                    LONG <= W2;
                                    M <= W2 or W3;
                                    if W2 = '1' then
                                        S <= "1111";
                                    elsif W3 = '1' then
                                        S <= "1010";
                                    end if;
                                    ABUS <= W2 or W3;
                                    LAR <= W2;
                                    MEMW <= W3;
                                    if IS_INT = '1' and W3 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "0111" => --JC
                                    if C = '0' then
                                        if IS_INT = '1' and W2 = '1' then
                                            C_RUN_SAVE <= '1';
                                        end if;
                                    else
                                        LONG <= W2;
                                        M <= W2 or W3;
                                        if W2 = '1' or W3 = '1' then
                                            S <= "1111";
                                        end if;
                                        ABUS <= W2;
                                        LPC <= W2;
                                        SELCTL <= W3;
                                        SEL_L <= W3 & W3;
                                        DRW <= W3;
                                        if IS_INT = '1' and W3 = '1' then
                                            C_RUN_SAVE <= '1';
                                        end if;
                                    end if;
                                when "1000" => --JZ
                                    if Z = '0' then
                                        if IS_INT = '1' and W2 = '1' then
                                            C_RUN_SAVE <= '1';
                                        end if;
                                    else
                                        LONG <= W2;
                                        M <= W2 or W3;
                                        if W2 = '1' or W3 = '1' then
                                            S <= "1111";
                                        end if;
                                        ABUS <= W2;
                                        LPC <= W2;
                                        SELCTL <= W3;
                                        SEL_L <= W3 & W3;
                                        DRW <= W3;
                                        if IS_INT = '1' and W3 = '1' then
                                            C_RUN_SAVE <= '1';
                                        end if;
                                    end if;
                                when "1001" => --JMP
                                    LONG <= W2;
                                    M <= W2 or W3;
                                    if w2 = '1' or W3 = '1' then
                                        S <= "1010";
                                    end if;
                                    ABUS <= W2 or W3;
                                    LPC <= W2;
                                    DRW <= W3;
                                    if IS_INT = '1' and W3 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "1010" => --EI
                                    EN_INT <= '1';
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1'; --Set RUN_SAVE to '1' while falling edge of T3
                                    end if;
                                when "1011" => --DI
                                    EN_INT <= '0';
                                when "1100" => --OR
                                    M <= W2;
                                    S <= W2 & W2 & W2 & not W2;
                                    ABUS <= W2;
                                    DRW <= W2;
                                    LDC <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "1101" => --OUT
                                    M <= W2;
                                    S <= W2 & not W2 & W2 & not W2;
                                    ABUS <= W2;
                                    SHORT <= W2;
                                    if IS_INT = '1' and W2 = '1' then
                                        C_RUN_SAVE <= '1';
                                    end if;
                                when "1110" => --STP
                                    STP <= W2;
                                when "1111" => --IRET
                                    STP <= W2;
                                    if W2 = '1' then
                                        C_RUN_RET <= '1'; 
                                    end if;
                                when others => null;
                            end case;
                          
                        end if;
                    end if;
                   
                end if;
          
            when others => null;
        end case;
      
    end process;
end struct;