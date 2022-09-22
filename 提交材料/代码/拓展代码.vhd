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
				--控制只产生额外的W3和控制只产生W1
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
		M, PCADD, SELCTL, STOP: OUT STD_LOGIC 
				--最后一条端口声明语句没有分号
				--M：ALU运算模式，控制算术运算还是逻辑运算，M=0为算术运算，M=1为逻辑运算
				--SELCTL:进入控制台模式,当它为1时，TEC-8实验系统处于实验台状态，当它为0时，TEC-8实验系统处于运行程序状态
				--PCADD：用于加“偏移量”生成新的PC地址
				--STOP：停止产生时钟脉冲	
		);
END JIZU;
									--结构体：描述系统内部的结构和行为，在结构体描述中，具体给出了输入、输出信号之间的逻辑关系
ARCHITECTURE ARC OF JIZU IS 		--结构体定义 ARCHITECTUR 结构体名 OF 实体名 IS
	SIGNAL ST0,SST0: STD_LOGIC; 	--信号声明，ST0是标志符号，用于区分一个控制台模式的不同阶段，SST0用于修改ST0
BEGIN 								--BEGIN到END之间是功能描述语句，具体描述结构体的功能和行为
	PROCESS(SWCBA, W, CLR, T3,IR) 	--PROCESS进程语句，进程语句定义顺序语句模块，用于将从外部获得的信号值或内部的运算数据向其他的信号进行赋值
									--PROCESS(敏感信号参数表)，一个进程可以有多个敏感信号，任何一个敏感信号发生变化都会激活进程
	BEGIN 							--进程中定义的都是顺序语句模块，BEGIN是语法规范，不能不写
									--信号初始化
			SEL <= "0000";
			MBUS <= '0';
			DRW <= '0';
			SBUS <= '0';
			STOP <= '0';
			LAR <= '0';
			ARINC <= '0';
			LDZ <= '0';
			LDC <= '0';
			CIN <= '0';
			S <= "0000";
			M <= '0';
			ABUS <= '0';
			PCINC <= '0';
			LPC <= '0';
			PCADD <= '0';
			SELCTL <= '0';
			MEMW <= '0';
			LIR <= '0';
			SHORT <= '0';
			LONG <= '0';
		--如果按下CLR则将ST0置为0，否则直接进入主程序，此处因为CLR是低电平有效
		--如果不执行CLR也就是CLR是‘1’的时候同样需要将所有的elements 置为0，除了SST0和ST0	
		IF(CLR = '0') THEN  
			ST0 <= '0';
			SST0 <= '0';
		ELSE
			--进入主程序
			--主程序的第一部分，如果 SST0 为 1，则在 T3 下降沿对 ST0 的值做出修改
			--采用T3时刻下降沿置数，保证程序按照正常逻辑进行执行
			IF (T3'EVENT AND T3 = '0') THEN 
				IF SST0 = '1' THEN
					ST0 <= SST0 ;
				END IF;
			END IF;
			--CASE语句属于流程控制语句，通过判断SWC SWB SWA ，执行读存储器、写存储器、读寄存器、写寄存器、执行程序（取指令）
			CASE SWCBA IS
			WHEN "000" =>
				--取指令
				IF(ST0 = '0') THEN
					SBUS <= W(1);
					LPC <= W(1);
					STOP <= W(1);
					SELCTL <= W(1);
					SHORT <= W(1);
					SST0 <= W(1);
				ELSE
					--运行程序状态，此时不受实验台状态的影响
					LIR <= W(1);
					PCINC <= W(1);	
					CASE IR IS
					WHEN "0001" =>--ADD
					--对于执行程序部分，通过 case 来判断 IR7~IR4来执行不同的指令
						S <= W(2) & '0' & '0' & W(2);
						CIN <= W(2);
						ABUS <= W(2);
						DRW <= W(2);
						LDZ <= W(2);
						LDC <= W(2);
					WHEN "0010" =>--SUB
						S <= '0' & W(2) & W(2) & '0';
						ABUS <= W(2);
						DRW <= W(2);
						LDZ <= W(2);
						LDC <= W(2);										
					WHEN "0011" =>--AND
						M <= W(2);
						S <= W(2) & '0' & W(2) & W(2);
						ABUS <= W(2);
						DRW <= W(2);
						LDZ <= W(2);
					WHEN "0100" =>--INC
						S <= "0000";
						ABUS <= W(2); 
						DRW <= W(2);
						LDZ <= W(2);
						LDC <= W(2);
					WHEN "0101" =>--LD 针对某些需要在三个节拍电位中执行的如LD ST指令，在执行到W2节拍电位时需要将LONG输出信号置‘1’保证指令能够完整地运行完毕
						M <= W(2);
						S <= W(2) & '0' & W(2) & '0';
						ABUS <= W(2);
						LAR <= W(2);
						LONG <= W(2);
						DRW <= W(3);
						MBUS <= W(3);
					WHEN "0110" =>--ST
						M <= W(2) OR W(3);
						S <=  (W(2) OR W(3)) & W(2) & ( W(2) OR W(3) ) & W(2);
						ABUS <= W(2) OR W(3);
						LAR <= W(2);
						LONG <=W(2);
						MEMW <= W(3);
					WHEN "0111" =>--JC
						PCADD <= W(2) AND C;
					WHEN "1000" =>--JZ
						PCADD <= W(2) AND Z;
					WHEN "1001" =>--JMP
						M <= W(2);
						S <= W(2) & W(2) & W(2) & W(2);
						ABUS <= W(2);
						LPC <= W(2);					
					WHEN "1010" =>--OUT
						M <= W(2);
						S <= W(2) & (NOT W(2)) & W(2) & (NOT W(2));
						ABUS <= W(2);
					WHEN "1011" =>--OR
						M <= W(2);
						S <= W(2) & W(2) & W(2) & (NOT W(2));
						ABUS <= W(2);
						DRW <= W(2);
						LDZ <= W(2);
					WHEN "1100" =>--NOT
						M <= W(2);
						S <= (NOT W(2)) & (NOT W(2)) & (NOT W(2)) & (NOT W(2));
						ABUS <= W(2);
						DRW <= W(2);
						LDZ <= W(2);
					when "1101" => --XOR
						M <= W(2);
						S <= (NOT W(2)) & W(2) & W(2) & (NOT W(2));
						ABUS <= W(2);
						LDZ <= W(2);
						DRW <= W(2);
					WHEN "1110" =>--STP
						STOP <= W(2);
					--当CASE语句的选择无法覆盖到所有的情况时，要使用OTHERS指定未能列出的其他所有情况的输出值
					--ADDED IRS 此处还可继续增加拓展指令，只要合理即可
					WHEN OTHERS =>  
						NULL;
					END CASE;
				END IF;	
					
			WHEN "001" =>
				--写存储器
				LAR <= W(1) AND NOT ST0;
				MEMW <= W(1) AND ST0;
				ARINC <= W(1) AND ST0;
				SBUS <= W(1);
				STOP <= W(1);
				SHORT <= W(1);
				SELCTL <= W(1);
				SST0 <= W(1);	
				
			WHEN "010" =>
				--读存储器，同样存在初始读操作模式和循环读操作模式
				SBUS <= W(1) AND NOT ST0;
				LAR <= W(1) AND NOT ST0;
				SST0 <= W(1) AND NOT ST0;
				MBUS <= W(1) AND ST0;
				ARINC <= W(1) AND ST0;
				STOP <= W(1);
				--因为读操作为短操作，所以需要在W1节拍结束后置SHORT有效位‘1’以终止W2节拍脉冲的产生
				SHORT <= W(1); 
				SELCTL <= W(1);
				
			WHEN "100" =>
				--读寄存器在实际操作中只需要按两次QD即可，需要两个节拍脉冲即W1和W2
				SEL(3) <= W(2);
				SEL(2) <= '0';
				SEL(1) <= W(2);
				SEL(0) <= W(1) OR W(2);
				SELCTL <= W(1) OR W(2);
				STOP <= W(1) OR W(2);
				
			WHEN "011" =>
				--写寄存器，写操作分为两个部分：初始进入初始写操作和循环写操作
				SBUS <= W(1) OR W(2);
				SELCTL <= W(1) OR W(2);
				DRW <= W(1) OR W(2);
				STOP <= W(1) OR W(2);
				SST0 <= NOT ST0 AND W(2);
				SEL(3) <= ST0;
				SEL(2) <= W(2);
				SEL(1) <= (NOT ST0 AND W(1)) OR (ST0 AND W(2));
				SEL(0) <= W(1);
				
			WHEN OTHERS => 
				NULL;
			END CASE;
		END IF;
	END PROCESS;
END ARC;
