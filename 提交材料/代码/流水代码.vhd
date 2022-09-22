library ieee;	--程序包调用说明
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
				--实体：描述所设计的系统的外部接口信号，定义电路设计中所有的输入和输出端口
ENTITY JIZU IS 	--实体名必须与VHDL程序的文件名称相同
				--端口声明 端口名1：端口方向 端口类型；
	PORT( 		
		SWCBA : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
				--模式开关值，即控制台方式控制信号
		IR : IN STD_LOGIC_VECTOR(7 DOWNTO 4);
				--INSTRUCTION 即指令操作码
		W : IN STD_LOGIC_VECTOR(3 DOWNTO 1);
		CLR: IN STD_LOGIC;
				--复位信号，低电平有效
		C, Z:IN STD_LOGIC;
				--标志寄存器，保存进位信号C和得零信号Z
		T3, QD : IN STD_LOGIC;
				--T3定界，只需要使用T3下降沿即可，简单来说就是每个机器周期的最后一个时钟周期
				--QD是指Wi的节拍电位产生器

		S : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
				--ALU运算模式（与M搭配）
		SEL : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); 
				--SEL3, SEL2, SEL1, SEL0 片选灯，即寄存器选择向量
				--(3,2)为ALU左端口MUX输入，也是 DBUS2REGISTER 的片选信号；(1,0)为ALU右端口MUX输入
		LDZ, LDC : OUT STD_LOGIC;
				--修改标志寄存器C,Z
				--LDZ：当它为1时，若运算结果为0则在T3上升沿将1写入Z标志寄存器；若运算结果不为0则将0写入Z标志寄存器
				--LDC：当它为1时，在T3的上升沿将运算得到的进位保存到C标志寄存器
		LAR, LIR : OUT STD_LOGIC;
				-- Load IR or AR
				--LAR：当它为1时，在T3的上升沿，将数据总线DBUS上的D7D0写入地址寄存器AR
				--LIR：当它为1时，在T3的上升沿将从双端口RAM的右端口读出的指令INS7~INS0写入指令寄存器IR。读出的存储器单元由PC7~PC0指定
		CIN, LPC : OUT STD_LOGIC;
				--LPC：载入 PC，当它为1时，在T3的上升沿，将数据总线DBUS上的D7~D0写入程序计数器PC
				--CIN：控制低位进位输入
		LONG, SHORT : OUT STD_LOGIC;
				--控制只产生额外的W(3)和控制只产生W(1)
		SBUS, MBUS, ABUS : OUT STD_LOGIC;
				--总线控制使能
				--ABUS：当它为1时，将开关数据送到数据总线DBUS；当它为0时，禁止开关数据送数据总线DBUS
				--SBUS：当它为1时，数据开关SD7~SD0的数送数据总线DBUS
				--MBUS：当它为1时，将双端口RAM的左端口数据送到数据总线DBUS
		ARINC, PCINC : OUT STD_LOGIC;
				--ARINC：AR++
				--PCINC：PC++
		DRW, MEMW : OUT STD_LOGIC;
				--写寄存器使能，写存储器使能
				--DRW：为1时，在T3上升沿对RD1、RD0选中的寄存器进行写操作，将数据总线DBUS上的数D7~D0写入选定的寄存器
		M, PCADD, SELCTL, STP: OUT STD_LOGIC 
				--最后一条端口声明语句没有分号
				--M：ALU运算模式，控制算术运算还是逻辑运算，M=0为算术运算，M=1为逻辑运算
				--SELCTL:进入控制台模式,当它为1时，TEC-8实验系统处于实验台状态，当它为0时，TEC-8实验系统处于运行程序状态
				--PCADD：用于加“偏移量”生成新的PC地址
				--STOP：停止产生时钟脉冲
					
		);
END JIZU;
									--结构体：描述系统内部的结构和行为，在结构体描述中，具体给出了输入、输出信号之间的逻辑关系


architecture struct of JIZU is
    --定义信号
    signal ST0, SST0 : STD_LOGIC;
begin
    process (W, T3, SWCBA, IR, CLR)
    begin
        S <= "0000";
        SEL <= "0000";
        DRW <= '0';
        MEMW <= '0';
        PCINC <= '0';
        PCADD <= '0';
        LPC <= '0';
        LAR <= '0';
        LIR <= '0';
        LDZ <= '0';
        LDC <= '0';
        ARINC <= '0';
        STP <= '0';
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
        elsif falling_edge(T3) then
            if SST0 = '1' then
                ST0 <= '1';
            end if;
        end if;

        case SWCBA is
            when "001" => --写存储器
                LAR <= W(1) AND NOT ST0;
				MEMW <= W(1) AND ST0;
				ARINC <= W(1) AND ST0;
				SBUS <= W(1);
				STOP <= W(1);
				SHORT <= W(1);
				SELCTL <= W(1);
                SST0 <= W(1) AND NOT ST0;
            when "010" => --读存储器   
				SBUS <= W(1) AND NOT ST0;
				LAR <= W(1) AND NOT ST0;
				MBUS <= W(1) AND ST0;
				ARINC <= W(1) AND ST0;
				STOP <= W(1);
				SHORT <= W(1); 
				SELCTL <= W(1);
                SST0 <= W(1) AND NOT ST0;
            when "011" => --写寄存器
                SBUS <= W(1) or W(2);
                SEL(3) <= ST0; --SEL3
                SEL(2) <= W(2); --SEL2
                SEL(1) <= (not ST0 and W(1)) or (ST0 and W(2)); --SEL1
                SEL(0) <= W(1); --SEL0
                SST0 <= W(1) AND NOT ST0;
                SELCTL <= W(1) or W(2);
                DRW <= W(1) or W(2);
                STP <= W(1) or W(2);
            when "100" => --读寄存器
                SEL(3) <= W(2);
                SEL(2) <= '0';
                SEL(1) <= W(2);
                SEL(0) <= W(1) or W(2);
                SELCTL <= W(1) or W(2);
                STP <= W(1) or W(2);
            when "000" => --取指
                if ST0 = '0' then
                    LPC <= W(1);
                    SBUS <= W(1);
                    STP <= W(1) or W(2);
                    LIR <= W(2);
                    PCINC <= W(2);
                    SST0 <= W(1) AND NOT ST0;
                else
                    case IR is
                        when "0000" => --NOP
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        when "0001" => --ADD
                            S <= "1001";
                            M <= not W(1);
                            CIN <= W(1);
                            ABUS <= W(1);
                            DRW <= W(1);
                            LDZ <= W(1);
                            LDC <= W(1);
                            LIR <= W(2);
                            PCINC <= W(2);
                            --SHORT <= W(1);
                        when "0010" => --SUB
                            S <= "0110";
                            M <= '0';
                            CIN <= '0';
                            ABUS <= W(1);
                            DRW <= W(1);
                            LDZ <= W(1);
                            LDC <= W(1);
                            LIR <= W(2);
                            PCINC <= W(2);
                            --SHORT <= W(1);
                        when "0011" => --AND
                            M <= W(1);
                            S <= "1011";
                            ABUS <= W(1);
                            DRW <= W(1);
                            LDZ <= W(1);
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        when "0100" => --INC
                            S <= "0000";
                            M <= not W(1);
                            ABUS <= W(1);
                            CIN <= not W(1);
                            DRW <= W(1);
                            LDZ <= W(1);
                            LDC <= W(1);
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        when "0101" => --LD
                            S <= "1010";
                            M <= W(1);
                            ABUS <= W(1);
                            LAR <= W(1);
                            MBUS <= W(2);
                            DRW <= W(2);
                            LONG <= '1';
                            LIR <= W(3);
                            PCINC <= W(3);
                        when "0110" => --ST
                            M <= W(1) or W(2);
                            if W(1) = '1' then
                                S <= "1111";
                            elsif W(2) = '1' then
                                S <= "1010";
                            end if;
                            ABUS <= W(1) or W(2);
                            LAR <= W(1);
                            MEMW <= W(2);
                            LIR <= W(2);
                            PCINC <= W(2);
                        when "0111" => --JC
                            if C = '0' then
                                LIR <= W(1);
                                PCINC <= W(1);
                                SHORT <= W(1);
                            else
                                PCADD <= W(1);
                                LIR <= W(3);
                                LONG <= '1';
                                PCINC <= W(3);
                            end if;
                        when "1000" => --JZ
                            if Z = '0' then
                                LIR <= W(1);
                                PCINC <= W(1);
                                SHORT <= W(1);
                            else
                                PCADD <= W(1);
                                LIR <= W(3);
                                LONG <= '1';
                                PCINC <= W(3);
                            end if;
                        when "1001" => --JMP
                            M <= W(1);
                            S <= "1111";
                            ABUS <= W(1);
                            LPC <= W(1);
                            LIR <= W(2);
                            PCINC <= W(2);
                        when "1010" => --MOV
                            M <= W(1);
                            S <= "1010";
                            ABUS <= W(1);
                            DRW <= W(1);
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        
                        when "1100" => --OR
                            M <= W(1);
                            S <= "1110";
                            ABUS <= W(1);
                            DRW <= W(1);
                            LDC <= W(1);
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        when "1101" => --OUT
                            M <= W(1);
                            S <= "1010";
                            ABUS <= W(1);
                            LIR <= W(1);
                            PCINC <= W(1);
                            SHORT <= W(1);
                        when "1110" => --STP
                            STP <= W(1);
                        
                        when others => null;
                    end case;
                end if;
            when others => null;
        end case;
    end process;
end struct;